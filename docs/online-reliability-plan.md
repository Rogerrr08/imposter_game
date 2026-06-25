# Plan de confiabilidad del modo online (v2)

> Objetivo: que el modo **online** se sienta una app de primera —sin lag, sin
> pantallas que no deben salir, sin desync, con turnos/timer correctos,
> espectador robusto, y presencia (conexión/desconexión) en tiempo real—
> **sin reescribir el motor de juego** (sigue en Postgres) ni tocar el modo local.
>
> Basado en la auditoría del 2026-06-22 (ver el análisis en el historial de chat).
> SQL se aplica **a mano** en el SQL Editor de Supabase (convención del repo).
> Tablas/columnas nuevas en `public` requieren GRANT explícito.

## Principio rector

**El servidor es la única fuente de verdad; el cliente es un renderizador
delgado del estado del servidor + un fallback de polling.** Hoy el cliente hace
trabajo que es del servidor: corre timers locales, infiere transiciones de fase
`prev→next`, decide timeouts, e infiere presencia. Eso es la causa raíz de casi
todo. El norte de este plan es mover esa autoridad al servidor.

Reglas concretas que vamos a cumplir al terminar:
1. **La fase y el turno se renderizan SIEMPRE desde el stream del match**
   (`onlineMatchProvider`), nunca desde el RPC `get_my_match_state`.
2. **El RPC `get_my_match_state` se usa solo para el secreto inmutable**
   (rol/palabra/pista/seat). Lo que cambia (eliminado/puntos/fase/turno) sale de
   los streams.
3. **El timer sale de un timestamp del servidor** (`turn_ends_at`), no de un
   contador local.
4. **La presencia sale de Supabase Realtime Presence** (evento `leave`), no del
   cron + flag.

## Estrategia de trabajo

- **Branch:** `feature/online-reliability-v2` desde `main` (que ya tiene el rebrand).
- **Pruebas multi-cliente:** cada fase se valida con **2–3 navegadores/dispositivos
  a la vez** (host + 2 jugadores), simulando: refrescar a mitad de turno,
  cerrar pestaña, segundo plano, unirse a mitad de partida, el host se va.
- **SQL incremental:** un archivo nuevo `queries/16-online-reliability.sql` con
  cada cambio idempotente (`alter table ... add column if not exists`,
  `create or replace function ...`), aplicado a mano. No tocar los `01..15`
  salvo que el cambio sea sobre una función que ya viva ahí (entonces
  `create or replace` también en el `16`).
- **Versionado:** al cerrar, bump a `3.1.0` (online es el cambio mayor) en
  `pubspec.yaml` + `app_info_provider.dart` + tag.
- **Progreso:** registrar avance en `docs/online-multiplayer-progress.md`.

## Mapa de archivos afectados

Cliente:
- `lib/features/online/application/online_match_provider.dart` — providers (split identidad vs progreso).
- `lib/features/online/presentation/online_match_screen.dart` — orquestador (fase desde stream, holds resilientes).
- `lib/features/online/presentation/widgets/clue_writing_phase.dart` — turno único + timer por timestamp.
- `lib/features/online/data/online_match_channel.dart` — Presence + polling fallback.
- `lib/features/online/application/match_heartbeat_provider.dart` — heartbeat + presence.
- `lib/features/online/presentation/widgets/match_results_phase.dart` — espectador sin `delay(300ms)`.
- `lib/features/online/domain/online_match.dart` — nuevos campos (`turn_ends_at`).
- (auxiliares) `voting_phase.dart`, `vote_result_phase.dart`, `role_reveal_phase.dart` — adaptar a la nueva firma identidad+stream.

SQL:
- `queries/16-online-reliability.sql` (nuevo) — `turn_ends_at`, `server_now()`,
  `get_spectator_snapshot`, ajustes a `start_match`/avance de turno/timeout.

---

## Fase 0 — Auditoría de lo aplicado + cazar el crash  ·  riesgo bajo · ½ día

**Por qué primero:** es gratis y puede explicar la mitad de los síntomas (si un
trigger/cron/RLS no quedó aplicado, nada de eso funciona, sin importar el código).

**Acciones**
1. **Verificar el SQL aplicado en Supabase** (SQL Editor):
   - `select jobname, schedule, active from cron.job;` → deben estar
     `check-player-heartbeats` (`* * * * *`), `cleanup-orphaned-matches`
     (`*/5 * * * *`), `cleanup-expired-private-rooms` (`0 * * * *`).
   - `select extname from pg_extension where extname='pg_cron';` → debe existir.
   - Verificar funciones: `get_match_snapshot`, `get_my_match_state`,
     `check_player_heartbeats`, `resolve_votes`, `calculate_match_scores`,
     `submit_clue`, `skip_clue_turn`, `start_match`.
   - Verificar triggers de broadcast (`12-realtime-triggers.sql`) en `matches`,
     `match_players`, `match_clues`, `match_votes`, `rooms`, `room_players`.
   - Verificar RLS de espectador (`08-spectator-rls.sql`) y de `realtime.messages`
     (`11-realtime-authorization.sql`).
   - Confirmar columnas: `room_players.last_seen_at`, `is_connected`.
2. **Cazar el `LateInitializationError`:** correr el build web **en debug**
   (`flutter run -d chrome`) y reproducir; en debug el nombre del campo `late`
   NO está minificado → se ve el campo real. Arreglar esa inicialización.
   (Independiente del backend; probablemente en un provider/fase.)

**Verificación:** las 3 filas de cron existen y `active=true`; las funciones y
triggers existen; el crash se reproduce en debug y se identifica el campo.

**Riesgo/rollback:** nulo (solo lectura + un fix puntual).

---

## Fase 1 — Una sola fuente de verdad (fase/turno desde el stream)  ·  riesgo medio-alto · 2–3 días

**Síntomas que resuelve:** desync, "pantallas que no deben salir", "es mi turno
pero no es", y buena parte del lag.

**Idea:** separar **identidad secreta** (inmutable por partida) de **progreso**
(en vivo). Hoy `MyMatchState` mezcla ambos y se refresca a mano con `invalidate`.

**Cambios cliente**
1. **Nuevo provider de identidad** en `online_match_provider.dart`:
   ```
   // One-shot, NO se invalida durante la partida.
   final myIdentityProvider = FutureProvider.autoDispose.family<MyIdentity, String>(...)
   // MyIdentity = { myPlayerId, myRole, myHint, mySeatOrder, word? }
   ```
   Sale de `get_my_match_state` pero quedándonos **solo** con los campos
   inmutables. (La palabra para civiles es fija; para impostor es null hasta que
   lo eliminan — ese caso se cubre derivando del stream del match, como ya se hace.)
2. **Derivar el progreso de los streams** (no del RPC):
   - Fase / turno / ronda / `state_version` → de `onlineMatchProvider` (`OnlineMatch`).
   - Mi estado vivo (`isEliminated`, `points`, `roleConfirmed`, `isConnected`) →
     buscando mi `OnlineMatchPlayer` por `myPlayerId` en `onlineMatchPlayersProvider`.
3. **Refactor `online_match_screen._buildMatchContent`**: tomar `phase` de
   `match.currentPhase` (stream). Las pantallas de fase reciben
   `(identity + match + players)` en vez de `MyMatchState`.
4. **Eliminar los `ref.invalidate(myMatchStateProvider)`** de transición de fase
   (`online_match_screen.dart` L123/L274, `clue_writing_phase.dart` L109). Ya no
   hacen falta: la fase viene del stream y la identidad no cambia. (Esto también
   mata el round-trip que causa lag.)
5. **`clue_writing_phase`**: una sola fuente de turno. `_isMyTurn` y el jugador
   mostrado se calculan ambos desde `match.currentTurnIndex` (stream) comparando
   contra `identity.mySeatOrder`.

**Verificación (multi-cliente):** con 3 navegadores, avanzar fases y turnos;
ningún cliente debe quedar en una pantalla vieja; "tu turno" coincide en todos;
refrescar un cliente a mitad de fase lo deja en la fase correcta al instante.

**Riesgo/rollback:** toca el orquestador (corazón del online). Mitigar haciéndolo
en commits chicos por pantalla y probando multi-cliente en cada uno. Rollback =
revertir la rama.

---

## Fase 2 — Timer sincronizado por timestamp del servidor  ·  riesgo medio · 1–2 días

**Síntomas que resuelve:** "5s en vez de 30", relojes distintos entre jugadores,
y se salta a las personas.

**Cambios SQL (`16-online-reliability.sql`)**
1. `alter table public.matches add column if not exists turn_ends_at timestamptz;`
2. En cada avance de turno (dentro de `submit_clue`, `skip_clue_turn`,
   `start_match` al entrar a `clue_writing`, y el reinicio de turnos por ronda):
   `turn_ends_at = timezone('utc', now()) + interval '30 seconds'`.
   (Hacer el 30 configurable luego con `matches.turn_seconds`; por ahora constante.)
3. **RPC de hora del servidor** para corregir skew de reloj:
   `create function public.server_now() returns timestamptz ... select timezone('utc', now());`
   con GRANT a `authenticated`.
4. Incluir `turn_ends_at` en `get_match_snapshot` (`13`) y en el broadcast de
   `match-updated` (trigger `12`).

**Cambios cliente**
1. `OnlineMatch.fromMap`: parsear `turn_ends_at` (DateTime?).
2. **Offset de reloj:** al conectar el canal, llamar `server_now()` una vez y
   guardar `serverOffset = serverNow - clientNow` (restando ~RTT/2). Re-medir en
   cada `resync`.
3. `clue_writing_phase`: el contador deja de ser autoritativo. Calcula
   `secondsLeft = max(0, turn_ends_at - (DateTime.now() + serverOffset))`. El
   `Timer.periodic(1s)` queda **solo para refrescar el número en pantalla**; la
   verdad es el timestamp (así reconectar/re-render recomputa bien).
4. **Timeout autoritativo:** cuando `secondsLeft<=0`, **solo el jugador del turno
   actual** auto-envía/saltea. Quitar el "cualquier jugador puede disparar skip"
   de `_handleTimeout`. (Backstop opcional en servidor: un sweep que avanza turnos
   con `turn_ends_at < now()`, disparable por cualquier `submit/skip` o por cron.)

**Verificación:** los 3 clientes muestran el mismo número (±1s); un cliente que
entra/refresca a mitad de turno ve el tiempo restante correcto; nadie salta el
turno antes de que el timestamp venza.

**Riesgo/rollback:** medio. La columna es aditiva (no rompe clientes viejos).

---

## Fase 3 — Presencia en vivo durante la partida  ·  riesgo medio · 1–2 días

**Síntomas que resuelve:** "no lo saca de la sala" (tardaba 90–150s), indicador
de desconectado lento, y limpieza para la próxima partida.

**Idea:** usar **Supabase Realtime Presence** durante el match (hoy solo en el
lobby). Presence emite `leave` al caerse el socket → detección en ~12s, sin cron.

**Cambios cliente**
1. En `OnlineMatchChannel` (o un canal `match-presence:<id>`): al suscribir,
   `channel.track({ user_id, player_id })`; manejar `onPresenceSync/Join/Leave`.
2. Exponer un stream "conectados ahora" (set de user_ids presentes) desde el canal.
3. La UI (puntito de desconectado en `clue_writing_phase`, lobby, etc.) usa ese
   set **en vivo**, en lugar de esperar `is_connected` de la BD.
4. Seguir llamando `setPlayerConnected` (mantiene la BD para el cron/cleanup) y
   bajar el heartbeat de 60s → **30s** en `match_heartbeat_provider.dart`.

**Cambios SQL (opcional, refuerzo)**
- Mantener el cron como backstop. Si se quiere que Presence escriba la BD,
  un endpoint/trigger que reciba el `leave`; pero con el set en vivo en el
  cliente alcanza para la UX. El cron sigue cancelando/reasignando.

**Verificación:** cerrar una pestaña → en los otros clientes el jugador aparece
"desconectado" en pocos segundos (no en ~2 min). Reabrir → vuelve a conectado.

**Riesgo/rollback:** medio. Presence es aditivo; si falla, la BD+cron siguen
siendo el fallback.

---

## Fase 4 — Espectador robusto + reingreso/mid-join + próxima partida  ·  riesgo medio · 1–2 días

**Síntomas que resuelve:** "el espectador se quedó cargando, nunca entró", y
"si alguien se reconecta o se une a mitad no aparece y no sirve para la próxima".

**Cambios SQL**
1. `create function public.get_spectator_snapshot(input_match_id uuid)` → devuelve
   match + jugadores **públicos** (sin rol/palabra) para miembros de la sala que
   NO son jugadores del match. GRANT a `authenticated`. (Alternativa: asegurar que
   `get_match_snapshot` sea seguro para espectadores vía RLS de `08`.)
2. Revisar `start_match`: armar `match_players` desde los **miembros conectados
   actuales** de la sala (para que reconectados/tardíos tengan asiento la próxima).

**Cambios cliente**
1. **Detección de espectador explícita** en `online_match_screen`: en vez de
   `myStateAsync.hasError && match != null`, determinar espectador con "soy
   miembro de la sala pero mi `userId` no está en `match_players`" (del stream).
   No depender de un error de RPC ni de que el stream venga no-nulo.
2. **`match_results_phase._loadScoresForSpectator`**: reemplazar el
   `Future.delayed(300ms)` + lectura única por **esperar el dato** (escuchar el
   stream hasta no-vacío, con timeout + 1 reintento). Evita el "cargando" eterno.
3. Resetear `_isLateJoinSpectator` de forma limpia entre partidas (no solo en
   `didUpdateWidget`): cuando entro a un match donde sí soy jugador, dejar de ser
   espectador.

**Verificación:** un amigo que entra a mitad de partida ve "Espectando" sin
quedarse en spinner; al empezar la próxima, juega normal. Un jugador que refresca
vuelve a su rol/estado correcto.

**Riesgo/rollback:** medio. RPC nuevo es aditivo.

---

## Fase 5 — Fallback de polling + holds resilientes  ·  riesgo bajo-medio · 1 día

**Síntomas que resuelve:** desync residual cuando el socket muere en silencio
(web, segundo plano), y holds que no aparecen a quien se perdió el `prev`.

**Cambios cliente**
1. En `OnlineMatchChannel`: además del `resync()` en `resumed`, agregar un
   **poll de snapshot** liviano cada 3–5s **solo cuando la pestaña está visible**,
   y en `visibilitychange` (web). Es la red de seguridad: si se perdió un delta,
   el poll lo corrige en segundos. Para un juego por turnos la latencia es trivial.
2. **Holds derivados del servidor:** los intermedios (vote_result, reveal
   countdown, impostor hold) hoy se disparan al observar `prev→next`. Hacerlos
   derivables de la fase + un timestamp del servidor (p. ej. `phase_ends_at`), o
   al menos tolerar que un cliente que se perdió el `prev` los muestre/saltee sin
   romper la sincronía.

**Verificación:** matar el WiFi 5s a mitad de fase y reactivarlo → el cliente se
re-sincroniza solo en segundos. Un cliente que entra tarde no queda atrapado en
un hold ajeno.

**Riesgo/rollback:** bajo (el poll es aditivo y best-effort).

---

## Fase 6 — Pulido, verificación y cierre  ·  riesgo bajo · 1 día

1. **Matriz de prueba multi-cliente** (ver "Definición de hecho").
2. Limpiar logs/manejo de errores; mensajes claros al usuario.
3. Bump a `3.1.0` (pubspec + app_info + tag) y release notes.
4. Registrar en `docs/online-multiplayer-progress.md`.

---

## Resumen por fase

| Fase | Resuelve | Riesgo | Esfuerzo | Depende de |
|---|---|---|---|---|
| 0 Auditoría SQL + crash | "no pasa nada" oculto + crash | Bajo | ½ día | — |
| 1 Fuente única (stream) | desync, turno, lag | Medio-alto | 2–3 días | 0 |
| 2 Timer por timestamp | 5s/30s, saltos | Medio | 1–2 días | 1 |
| 3 Presence en vivo | desconexión lenta | Medio | 1–2 días | 0 |
| 4 Espectador + reingreso | espectador colgado | Medio | 1–2 días | 1 |
| 5 Polling + holds | desync residual | Bajo-medio | 1 día | 1 |
| 6 Pulido + release | — | Bajo | 1 día | todas |

Ruta crítica: **0 → 1 → 2** es lo que más cambia la sensación. **3** se puede
hacer en paralelo a 1 (es independiente). 4 y 5 después de 1.

## Definición de "hecho" (matriz de prueba con 3 clientes)

- [ ] Avanzar toda una partida: ningún cliente queda en pantalla vieja.
- [ ] "Tu turno" y el timer coinciden en los 3 (±1s).
- [ ] Refrescar un cliente a mitad de turno → vuelve a la fase/turno/tiempo correctos.
- [ ] Cerrar una pestaña → "desconectado" aparece en los otros en pocos segundos.
- [ ] Un jugador se une a mitad → "Espectando" sin spinner eterno; juega la próxima.
- [ ] El host se va → se reasigna host o se cancela con mensaje claro.
- [ ] Matar el WiFi 5s → el cliente se re-sincroniza solo.
- [ ] Cero `LateInitializationError` en consola web.

## Anexo — nuevos artefactos de servidor

- Columna: `matches.turn_ends_at timestamptz` (y futuro `matches.turn_seconds int`).
- RPCs nuevos: `server_now()`, `get_spectator_snapshot(uuid)`.
- Ajustes: `submit_clue` / `skip_clue_turn` / `start_match` setean `turn_ends_at`;
  `get_match_snapshot` y el trigger `match-updated` incluyen `turn_ends_at`.
- Todo en `queries/16-online-reliability.sql`, idempotente, con GRANTs.
