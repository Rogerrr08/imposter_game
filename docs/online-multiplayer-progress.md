# Registro de avance del modo online

Historial cronológico de los cambios más relevantes del modo online.
El plan vigente está en [online-multiplayer-plan.md](online-multiplayer-plan.md).

---

## 2026-04-19 — Plan de optimización local/offline

Creado [local-performance-refactor-plan.md](local-performance-refactor-plan.md).

Audit del modo local (Flutter + Drift + Riverpod, sin Supabase) con un
experto en rendimiento móvil. Hallazgos principales:
- Timer del gameplay reconstruye toda la pantalla cada segundo (no usa `select`)
- `_updatePlayerStats` hace 4×N upserts secuenciales (sin `batch()`)
- Assets sin `cacheWidth/Height` ni `precacheImage`
- Flash light→dark al cold-start por `DarkModeNotifier` async
- 412 apariciones de `TextStyle(fontFamily: 'Nunito')` duplicando el theme
- `Future.delayed(100ms)` + Supabase init bloquean cold-start
- N+1 DELETEs en `deleteGroup`, `trimGameHistory`, etc.

Plan en 6 fases (A-F), release objetivo v2.2.0.

---

## 2026-04-19 — Plan de refactor Realtime

Creado [online-realtime-refactor-plan.md](online-realtime-refactor-plan.md).

**Problema:** síntomas reportados en producción de v2.1.0 (contador 0/0
jugadores, pistas que no propagan a algunos clientes, reconexiones
innecesarias).

**Causa raíz:** uso excesivo de `ref.invalidate(...)` sobre `StreamProvider`s
de Postgres Changes, que reabre suscripciones WebSocket y vacía el estado
temporalmente. Combinado con 5 streams por partida (matches, match_players,
match_clues, match_votes + presence), amplifica el problema.

**Propuesta:** migrar a **Broadcast from Database** (patrón oficial
recomendado por Supabase para multiplayer). Un único canal privado
`match:{matchId}` por partida, con deltas publicados desde triggers en
Postgres vía `realtime.send()`.

Objetivo de release: **v2.2.0**.

El plan incluye:
- Fase 0: fixes puntuales que ya resuelven ~80% de los síntomas (pueden ir como hotfix v2.1.1).
- Fase 1: triggers SQL + RLS sobre `realtime.messages`.
- Fase 2: cliente Flutter con `OnlineMatchChannel` unificado + snapshot RPC.
- Fase 3: limpieza (quitar tablas del publication, heartbeat a 60s).

---

## 2026-04-27 — Refactor Realtime: Fase 0 implementada

Rama `refactor/online_mode`. Versión bumpeada a `2.2.0+5` ([pubspec.yaml](../pubspec.yaml), [app_info_provider.dart](../lib/providers/app_info_provider.dart)). Cambios sin tocar la arquitectura realtime — son los "wins" del audit que resuelven ~80% de los síntomas reportados:

- **0.1** — `queries/10-realtime-refactor-indexes.sql` creado con 4 índices compuestos: `match_clues(match_id, round_number)`, `match_votes(match_id, round_number, is_tiebreak)`, `match_players(match_id, seat_order)` y `matches(room_id, status) WHERE status = 'active'`. Reduce latencia de `submit_clue`, `resolve_votes` y `getActiveMatchForRoom`. **Pendiente ejecutar en Supabase.**
- **0.2.a** — `online_match_screen.dart`: eliminado `ref.invalidate(onlineMatchPlayersProvider(...))` que se disparaba en cada cambio de fase. El stream ya refleja los cambios; invalidar reabría la suscripción WebSocket y dejaba "0/0" momentáneo.
- **0.2.b** — `online_lobby_sync_provider.dart`: eliminados los `_invalidatePlayers()` de los callbacks `onPresenceSync/Join/Leave`. Con N jugadores, un solo join amplificaba a O(N²) refetches. Los `invalidate` en los `onBroadcast` (`config-updated`, `ready-updated`) se mantienen — esos son cambios reales que sí ameritan refetch.
- **0.2.c** — `clue_writing_phase.dart`: eliminado el `Future.microtask(() => invalidate(...))` que corría en cada rebuild mientras todas las pistas estuvieran enviadas. Causaba reabrir streams y latencia adicional al transicionar a voting.
- **0.3** — `player_avatar.dart`: agregados `memCacheWidth`/`memCacheHeight` en el `CachedNetworkImage`, escalados por `MediaQuery.devicePixelRatioOf(context)`. Antes se decodificaba la imagen 256×256 incluso para slots de 24-48px. Ahorro estimado: 4-6 MB RAM con 8 jugadores visibles.

Verificación: `flutter analyze` → 27 issues (mismos que baseline; 0 nuevos). Pendiente smoke test multi-cliente.

---

## 2026-04-27 — Refactor Realtime: Fase 1 (backend SQL)

Tres archivos SQL nuevos que habilitan **Broadcast from Database**. **Ejecutar en orden y antes de tocar el cliente** (ya pueden coexistir con el modo Postgres Changes actual — los triggers solo agregan eventos, no cambian la lectura existente):

- **1.1 — [queries/11-realtime-authorization.sql](../queries/11-realtime-authorization.sql)** — Policies sobre `realtime.messages` para canales privados:
  - `authenticated_read_match_room_broadcast` (SELECT): solo `is_match_player(<uuid>)` o `is_room_member(<uuid>)` reciben mensajes según el topic (`match:<id>` o `room:<id>`).
  - `authenticated_write_match_room_broadcast` (INSERT): misma regla. Los triggers usan `SECURITY DEFINER` y bypassean RLS, así que esta policy solo aplica a broadcasts manuales del cliente.
- **1.2 — [queries/12-realtime-triggers.sql](../queries/12-realtime-triggers.sql)** — 3 funciones + 6 triggers `AFTER INSERT/UPDATE/DELETE`:
  - `broadcast_matches_change()` → `match-updated` con `to_jsonb(new)`.
  - `broadcast_match_change()` → `player-updated` (campos explícitos, incluye `op = tg_op`), `clue-added` (`to_jsonb(new)`), `vote-added` (sin `target_player_id` por seguridad).
  - `broadcast_room_change()` → `room-updated`, `player-joined` / `player-left` / `player-updated`.
  - Triggers attachados a las 6 tablas relevantes (`matches`, `match_players`, `match_clues`, `match_votes`, `rooms`, `room_players`).
- **1.3 — [queries/13-match-snapshot-rpc.sql](../queries/13-match-snapshot-rpc.sql)** — RPC `get_match_snapshot(input_match_id uuid)` que retorna `{match, players[], clues[], votes[]}` como JSON único. El cliente la llamará al abrir el canal y al reconectar, para reconciliar deltas perdidos. Aplica el mismo filtro de `target_player_id` que el trigger de votos. Validación de membresía explícita (`is_match_player`).

**Estado:** archivos SQL listos en `queries/`, **pendientes ejecutar en Supabase**. Ejecutar en orden 11 → 12 → 13. El cliente sigue corriendo sobre Postgres Changes (sin cambios), así que ejecutar estos SQLs es no-op en producción hasta que el cliente migre (Fase 2). Se puede medir en Supabase Realtime Inspector que los broadcasts ya se están emitiendo.

> **Update 2026-04-27:** Tras revisar el uso real, se mantiene `target_player_id` en el payload de `vote-added` y en `get_match_snapshot`. La UI de [voting_phase.dart](../lib/features/online/presentation/widgets/voting_phase.dart) cuenta votos por target en tiempo real (`votesByTarget`) durante la fase de votación, así que ocultarlo rompía la UI. La RLS actual de `match_votes` ya expone el campo a todos los miembros del match — no se gana privacidad ocultándolo. **Re-ejecutar 12 y 13 si ya se habían corrido antes de este cambio.**

---

## 2026-04-27 — Refactor Realtime: Fase 2 (cliente unificado)

Migración del cliente Flutter a los canales Broadcast. **Sin tocar la API que consumen las pantallas** (los `StreamProvider`s mantienen su nombre y forma) — solo cambia la fuente de los datos.

- **2.1 — [online_match_channel.dart](../lib/features/online/data/online_match_channel.dart)** (nuevo): `OnlineMatchChannel` con patrón snapshot+deltas:
  - `start()` carga snapshot vía `get_match_snapshot` RPC, luego suscribe al canal privado `match:<id>`.
  - Mantiene estado en memoria (`Map<String, OnlineMatchPlayer> _players`, etc.) y emite por 4 streams broadcast (`watchMatch`, `watchPlayers`, `watchClues`, `watchVotes`).
  - En reconnect (`closed → subscribed`), re-carga el snapshot para reconciliar deltas perdidos.
  - Anti-stale: deltas de `match-updated` con `state_version` anterior al actual se ignoran.
  - Maneja el envoltorio de Supabase Realtime (`{event, type, payload: {...}}`) extrayendo el inner via `_extractPayload`.
- **2.2 — [online_room_channel.dart](../lib/features/online/data/online_room_channel.dart)** (nuevo): equivalente para `room:<id>`. Como no hay RPC de snapshot para rooms, hace fetch directo a `rooms` y `room_players` (la primera vez y en reconnects). Emite `watchRoom` y `watchPlayers`.
- **2.3 — [online_match_provider.dart](../lib/features/online/application/online_match_provider.dart)**: nuevo `onlineMatchChannelProvider` (autoDispose+family) que crea/disposes el canal. Los `StreamProvider`s existentes (`onlineMatchProvider`, `onlineMatchPlayersProvider`, `onlineMatchCluesProvider`, `onlineMatchVotesProvider`) ahora consumen del canal.
- **2.4 — [online_rooms_provider.dart](../lib/features/online/application/online_rooms_provider.dart)**: análogo para `OnlineRoomChannel`. `onlineRoomProvider` y `onlineRoomPlayersProvider` consumen del canal.

**Decisión de diseño:** se mantienen 2 canales separados para el lobby (`room:<id>` para broadcasts BD vía `OnlineRoomChannel`, y `room-lobby:<id>` para presence vía el `OnlineLobbySyncController` existente). El plan sugería combinarlos en un único canal pero requiere refactor invasivo del controller; se difiere para una iteración posterior. Conteo de WS:
- En partida activa: 2 (`match:<id>` + `room:<id>`)
- En lobby: 2 (`room:<id>` + `room-lobby:<id>`)
- Antes: 5–7 según pantalla. La métrica principal (eliminar el flapping de "0/0" por reapertura de streams) se cumple.

**Repositorios:** los métodos `watchMatch`, `watchMatchPlayers`, `watchMatchClues`, `watchMatchVotes` en [online_match_repository.dart](../lib/features/online/data/online_match_repository.dart) y `watchRoom`, `watchRoomPlayers` en [online_rooms_repository.dart](../lib/features/online/data/online_rooms_repository.dart) **se conservan por ahora** — ya no son consumidos por los providers, pero se borran formalmente en Fase 3. Esto deja una salida rápida si se detecta un bug (revertir el provider para apuntar al repository directo).

Verificación: `flutter analyze` → 27 issues (mismos baseline; 0 nuevos). Smoke test multi-cliente pendiente.

---

## 2026-04-27 — Refactor Realtime: Fase 3 (limpieza)

Cierre del refactor — quitar el código obsoleto y reducir carga residual:

- **3.1 — [online_match_repository.dart](../lib/features/online/data/online_match_repository.dart) y [online_rooms_repository.dart](../lib/features/online/data/online_rooms_repository.dart)**: eliminados los métodos `watchMatch`, `watchMatchPlayers`, `watchMatchClues`, `watchMatchVotes` (en match) y `watchRoom`, `watchRoomPlayers` (en rooms). Estos eran los `stream()` sobre tablas que ya no se consumen. También se quita el import de `online_room.dart` en el repository de rooms (ya no usa el dominio para watch).
- **3.2 — [queries/14-realtime-remove-publication.sql](../queries/14-realtime-remove-publication.sql)** (nuevo): `alter publication supabase_realtime drop table` para `matches`, `match_players`, `match_clues`, `match_votes`, `rooms`, `room_players`. **No ejecutar todavía** — debe correrse solo cuando toda la base instalada esté en ≥ v2.2.0 (sino los clientes viejos pierden sus suscripciones de Postgres Changes y se quedan sin datos). Reversible con `add table` si hace falta rollback.
- **3.3 — [match_heartbeat_provider.dart](../lib/features/online/application/match_heartbeat_provider.dart)**: intervalo del heartbeat de **30 s → 60 s**. El presence channel del lobby ya detecta desconexiones en tiempo real; el heartbeat en BD solo sirve como fallback para reconexión tras cerrar la app, así que 60 s reduce a la mitad la carga de RPCs sin afectar UX.

Verificación: `flutter analyze` → 27 issues (mismos baseline; 0 nuevos).

**Estado del refactor Realtime:** Fases 0, 1, 2 y 3 implementadas y verificadas. Pendientes:
1. Re-ejecutar `12-realtime-triggers.sql` y `13-match-snapshot-rpc.sql` en Supabase (cambio en payload de votos).
2. Smoke test multi-cliente del nuevo path.
3. Cuando v2.2.0 esté en producción y todos los clientes actualizados → ejecutar `14-realtime-remove-publication.sql`.

---

## Histórico anterior

El historial previo (Fase 1 a Fase 7 del plan original: auth anónima, salas,
matches, scoring, reconexión, RLS, avatares, edición de perfil, modo oscuro
persistente) se implementó durante versiones v1.x → v2.1.0 y está reflejado
en el git log y en las release notes del proyecto.
