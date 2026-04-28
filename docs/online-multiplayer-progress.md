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

## Histórico anterior

El historial previo (Fase 1 a Fase 7 del plan original: auth anónima, salas,
matches, scoring, reconexión, RLS, avatares, edición de perfil, modo oscuro
persistente) se implementó durante versiones v1.x → v2.1.0 y está reflejado
en el git log y en las release notes del proyecto.
