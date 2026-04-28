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

## Histórico anterior

El historial previo (Fase 1 a Fase 7 del plan original: auth anónima, salas,
matches, scoring, reconexión, RLS, avatares, edición de perfil, modo oscuro
persistente) se implementó durante versiones v1.x → v2.1.0 y está reflejado
en el git log y en las release notes del proyecto.
