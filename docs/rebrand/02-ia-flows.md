# 02 — Arquitectura de Información y Flujos de Navegación
## Rebrand "Yeison Impostor" — Vibra Neón Fiesta Nocturna

**Fecha:** 2026-06-19
**Autor:** Agente IA/UX (análisis de rebrand)
**Restricción dura:** No se modifica la lógica del juego ni la capa de datos (Riverpod / Drift / Supabase). Solo IA y flujos de UI/navegación.

---

## 1. Inventario de pantallas + mapa de navegación actual

### Sitemap actual

```
/ (HomeScreen)
├── /how-to-play             ← HowToPlayScreen (8 páginas onboarding)
│
├── ── MODO LOCAL ──
├── /setup                   ← GameSetupScreen (configura partida; recibe groupId opcional)
│   └── /role-reveal         ← RoleRevealScreen (desliza para ver rol, N jugadores)
│       └── /round-start     ← RoundStartScreen (splash 2 s automático)
│           └── /play        ← GamePlayScreen (timer + botones votar/adivinar)
│               ├── /vote    ← VoteScreen (Express: 3 pasos nombre→target→confirmar;
│               │              Clásico: votación anónima por turnos)
│               │   └── /action-reveal  ← ActionRevealScreen (suspenso + resultado)
│               │       ├── [continúa /play si hay más rondas]
│               │       └── /classic-impostor-choice  ← (¿quiere adivinar?)
│               │           └── /impostor-guess ← ImpostorGuessScreen
│               │               └── /action-reveal → /results
│               └── /impostor-guess  ← ImpostorGuessScreen (Express: desde /play)
│                   └── /action-reveal → /results o regresa a /play
│
├── /results                 ← GameResultsScreen
│   ├── "Jugar de nuevo" → /setup (mismo groupId)
│   └── "Ir al inicio / Volver al grupo" → / o /groups/:id
│
├── /groups                  ← GroupsScreen (lista de grupos)
│   └── /groups/:id          ← GroupDetailScreen
│       ├── Iniciar partida  → /setup?groupId=:id
│       └── /rankings/:id    ← RankingsScreen
│           └── /history/:id ← GameHistoryScreen
│
└── ── MODO ONLINE ──
/online                      ← OnlineHomeScreen (requiere auth anónima + profile)
│   ├── /online/display-name ← DisplayNameScreen (nombre + avatar; solo 1ª vez o editar)
│   ├── /online/create-room  ← CreateRoomScreen (crea sala → va al lobby)
│   ├── /online/join-room    ← JoinRoomScreen (ingresa código de 6 chars)
│   └── /online/room/:roomId ← RoomLobbyScreen (lobby: código, config, jugadores, start)
│       └── /online/match/:matchId ← OnlineMatchScreen (todas las fases en un widget)
│           └── [match results dentro del mismo widget, botón "Volver a jugar"]
```

### Rutas registradas en `app_router.dart`

| Ruta | Widget | Notas |
|------|--------|-------|
| `/` | HomeScreen | initial route |
| `/how-to-play` | HowToPlayScreen | 8-page PageView |
| `/setup` | GameSetupScreen | extra: groupId? |
| `/role-reveal` | RoleRevealScreen | |
| `/round-start` | RoundStartScreen | auto-avanza a /play en 2 s |
| `/play` | GamePlayScreen | timer loop |
| `/vote` | VoteScreen | Express y Clásico en mismo widget |
| `/action-reveal` | ActionRevealScreen | extra: ActionRevealData |
| `/classic-impostor-choice` | ClassicImpostorChoiceScreen | |
| `/impostor-guess` | ImpostorGuessScreen | |
| `/results` | GameResultsScreen | |
| `/online` | OnlineHomeScreen | |
| `/online/create-room` | CreateRoomScreen | |
| `/online/join-room` | JoinRoomScreen | |
| `/online/room/:roomId` | RoomLobbyScreen | |
| `/online/match/:matchId` | OnlineMatchScreen | |
| `/online/display-name` | DisplayNameScreen | |
| `/groups` | GroupsScreen | |
| `/groups/:id` | GroupDetailScreen | |
| `/rankings/:groupId` | RankingsScreen | |
| `/history/:groupId` | GameHistoryScreen | |

**Total actual: 20 rutas / ~18 pantallas lógicas distintas.**

---

## 2. Diagnóstico de fricción y problemas de IA

### 2.1 Contador de toques para empezar a jugar (principio Jackbox)

**Modo local — partida rápida nueva (primera vez):**
1. Abrir la app → HomeScreen
2. "Juego rápido" (loading 400 ms)
3. GameSetupScreen — añadir jugadores uno por uno + configurar
4. "Comenzar" (loading 400 ms)
5. RoleRevealScreen — N pases de celular × (deslizar + tocar "Siguiente")
6. RoundStartScreen — espera 2 s automática
7. GamePlayScreen

**Mínimo 4 toques de nav + N×2 gestos (deslizar+boton) antes de jugar.** En grupos de 6 son 16 acciones solo para la fase de revelación.

**Modo online — primera vez:**
1. HomeScreen → "Jugar en línea" (loading lazy Supabase)
2. OnlineHomeScreen (loading auth anon + profile check)
3. DisplayNameScreen (solo primera vez) — escribir nombre + guardar
4. OnlineHomeScreen (de vuelta)
5. "Crear sala" → CreateRoomScreen
6. (auto-redirect) → RoomLobbyScreen
7. Esperar jugadores + configurar + "Iniciar"
8. OnlineMatchScreen

**7–8 pantallas / acciones antes de poder jugar online, incluyendo la pantalla de display-name que interrumpe el flujo.**

### 2.2 Problemas de IA detectados

#### P0 — Crítico

**P0-A Cambio de tema huérfano (home_screen.dart:54–63)**
El toggle claro/oscuro vive como un `IconButton` flotante suelto en la esquina superior derecha del HomeScreen. No hay pantalla de Ajustes. No hay acceso al tema desde ninguna otra pantalla del flujo (setup, gameplay, online). Es inconsistente, invisible para usuarios nuevos y queda atrapado detrás del flujo de juego.

**P0-B Interrupciones de loading en flujo online (online_home_screen.dart:119–214)**
El OnlineHomeScreen tiene 5 estados de carga encadenados (sesión → profile → active room). Cada uno muestra su propio spinner con texto diferente. El usuario no sabe cuánto falta ni puede cancelar. El flujo de "primera vez" además redirige silenciosamente a DisplayNameScreen desde el interior de los listeners del OnlineHomeScreen, creando una transición sin back navigation clara.

**P0-C VoteScreen: modo Express requiere escribir nombres (vote_screen.dart:411–501)**
En Express el votante debe escribir su propio nombre (campo de texto autocomplete) y luego el nombre del objetivo. En una fiesta nocturna con personas no familiarizadas con la app, este flujo rompe la dinámica. No hay selección visual de avatares/chips.

#### P1 — Importante

**P1-A Falta pantalla de Ajustes**
No existe `/settings`. El tema, y en el futuro otras preferencias (idioma, sonido) no tienen un hogar. Esto es una ausencia notoria para el rebrand.

**P1-B RoundStartScreen es un splash de 2 s innecesario (round_start_screen.dart:22–23)**
Es una pantalla de un solo propósito que auto-avanza sin interacción. La información que muestra ("Empieza: Jugador X") podría mostrarse como un toast/banner en GamePlayScreen al entrar.

**P1-C Onboarding de 8 páginas — muy largo, oculto y sin contextualización en el momento de uso**
HowToPlayScreen tiene 8 páginas lineales que explican todos los modos. La mayoría de jugadores en una fiesta no las van a leer antes de jugar. El botón "Cómo jugar" es un TextButton pequeño casi invisible al pie del HomeScreen. Las páginas 3 y 4 (Express), 5 y 6 (Clásico) y 7 y 8 (Online con puntos) son demasiadas. Los puntos son complejos para leer antes de haber jugado.

**P1-D Inconsistencia Local vs Online en nomenclatura y flujos de resultado**
- Local usa `/action-reveal` como pantalla de transición dramática (con barra de auto-avance); Online tiene el resultado inline en `OnlineMatchScreen` mediante `MatchResultsPhase`. El jugador que juega ambos modos experimenta dos flujos de "revelar resultado" completamente diferentes.
- En Local el impostor adivina desde una pantalla dedicada (`/impostor-guess`). En Online es una `ImpostorGuessPhase` dentro del match. La separación es correcta técnicamente pero la experiencia visual puede unificarse.

**P1-E CreateRoomScreen casi vacía — paso redundante**
`CreateRoomScreen` (create_room_screen.dart) carga el perfil y llama `createPrivateRoom()` automáticamente. No hay nada que configurar aquí. Redirige inmediatamente al lobby. Es una pantalla de transición disfrazada de pantalla real. El loading aquí interrumpe sin dar valor.

**P1-F GroupsScreen y GroupDetailScreen son accesibles solo desde Home**
Los grupos son la funcionalidad que más fideliza (historial + rankings). Sin embargo, desde el resultado de una partida de grupo el usuario va a `/groups/:id` pero no puede navegar al ranking directamente. Hay que ir: Resultados → Home → Grupos → GrupoDetalle → Rankings.

#### P2 — Menor

**P2-A No hay estado vacío atractivo para la primera apertura**
La primera vez que se abre la app (sin grupos guardados) el HomeScreen muestra los mismos 3 botones que siempre. No hay ningún gancho onboarding contextual (p. ej. "Crea tu primer grupo" o "¿Primera vez? Cómo jugar →").

**P2-B ClassicImpostorChoiceScreen: pantalla completa para una decisión binaria**
La pregunta "¿quieres intentar adivinar la palabra?" podría ser un modal/bottom sheet en lugar de una ruta de pantalla completa con navegación.

**P2-C Rankings y GameHistory no tienen acceso desde HomeScreen directamente**
Solo se llega a ellos desde `GroupDetailScreen`. No hay sección de "Estadísticas" o "Historial" accesible fuera del contexto de grupo.

**P2-D La pantalla de resultados local no tiene botón "Ver ranking del grupo"**
`GameResultsScreen` tiene "Jugar de nuevo" y "Ir al inicio/Volver al grupo". Falta acceso directo a rankings para aprovechar el momentum post-partida.

---

## 3. Propuesta de IA rediseñada (profunda)

### 3.1 Principios del rediseño

1. **Neón fiesta nocturna → acción directa.** Cada pantalla debe tener un único propósito. Cero pantallas de transición sin interacción.
2. **Jackbox mínimo.** Partida local nueva en máximo 3 toques. Online en máximo 5 toques (excluyendo esperar jugadores).
3. **Ajustes como ciudadano de primera clase.** Tema y futuras preferencias tienen su pantalla.
4. **Onboarding contextual.** Instrucciones embebidas en el flujo (tooltips, banners in-context) en lugar de manual de 8 páginas.
5. **Consistencia Local / Online.** El lenguaje visual y las transiciones dramáticas deben ser iguales en ambos modos.

---

### 3.2 Sitemap propuesto

```
/ (HomeScreen — rediseñado)
│
├── /settings                ← [NUEVA] AjustesScreen
│
├── /how-to-play             ← [REDUCIDA] OnboardingScreen (3 páginas max)
│
├── ── MODO LOCAL ──
│
├── /setup                   ← GameSetupScreen [MANTENIDA, refactor UI]
│   └── /role-reveal         ← RoleRevealScreen [MANTENIDA]
│       └── /play            ← GamePlayScreen [FUSIONA RoundStartScreen]
│           ├── /vote        ← VoteScreen [REFACTOR VISUAL → chips en lugar de texto]
│           │   └── /action-reveal  ← ActionRevealScreen [MANTENIDA]
│           │       ├── → /play
│           │       └── → /impostor-guess  [FUSIONA ClassicImpostorChoiceScreen]
│           └── /impostor-guess  ← ImpostorGuessScreen [MANTENIDA, recibe parámetro de modo]
│               └── /action-reveal → /results
│
├── /results                 ← GameResultsScreen [REFACTOR: add "Ver ranking"]
│   ├── "Jugar de nuevo"   → /setup
│   ├── "Ver ranking"      → /rankings/:groupId  (si es partida de grupo)
│   └── "Inicio"           → /
│
├── /grupos                  ← GroupsScreen [RENOMBRADA ruta, misma lógica]
│   └── /grupos/:id          ← GroupDetailScreen
│       ├── "Iniciar"      → /setup?groupId=:id
│       └── /rankings/:id   ← RankingsScreen
│           └── /history/:id ← GameHistoryScreen
│
└── ── MODO ONLINE ──
│
/online                      ← OnlineHomeScreen [REDISEÑADA: flujo de auth transparente]
│   ├── /online/perfil       ← [RENOMBRADA] DisplayNameScreen
│   │                           (accesible desde Settings y desde Online Home chip)
│   ├── /online/join-room    ← JoinRoomScreen [MANTENIDA]
│   └── /online/room/:roomId ← RoomLobbyScreen [FUSIONA CreateRoomScreen]
│       └── /online/match/:matchId ← OnlineMatchScreen [MANTENIDA]
```

**Total propuesto: 16 rutas / ~16 pantallas lógicas** (−4 rutas vs actual: elimina `/round-start`, `/classic-impostor-choice`, `/online/create-room`; añade `/settings`, `/online/perfil`).

---

### 3.3 Diagrama de flujo — Arranque / Home

```
[App abre]
    │
    ▼
[HomeScreen]
    │
    ├─ (ícono ajustes — esquina sup. der.) ──────────────────► [AjustesScreen]
    │                                                               │ tema claro/oscuro
    │                                                               │ sonido ON/OFF (futuro)
    │                                                               └─ ◄ back
    │
    ├─ [JUEGO RÁPIDO]  ──────────────────────────────────────► [GameSetupScreen]
    │
    ├─ [MIS GRUPOS]    ──────────────────────────────────────► [GroupsScreen]
    │
    ├─ [JUGAR EN LÍNEA] ─────────────────────────────────────► [OnlineHomeScreen]
    │
    └─ (link pequeño "Cómo jugar") ──────────────────────────► [OnboardingScreen]
```

**Cambio:** El `IconButton` de tema pasa a ser el ícono de Settings (engranaje). El Footer mantiene la versión. El área de botones es idéntica pero el toggle flotante desaparece.

---

### 3.4 Diagrama de flujo — Onboarding

```
[OnboardingScreen] — 3 páginas máximo
    │
    ├── Pág 1: "¿Qué es Impostor?" (concepto + física del celular)
    ├── Pág 2: "Modos de juego" (Express vs Clásico, puntos resumidos en tabla)
    └── Pág 3: "Online" (sala privada, flujo básico)
                │
                └── [¡A jugar!] → HomeScreen
```

**Cambio:** Reducir de 8 a 3 páginas. Eliminar las páginas de scoring detallado — esa información pasa a estar en AjustesScreen → "Reglas y puntuación" (sección colapsable) y en el propio GameSetupScreen (tooltip "?" junto al selector de modo).

---

### 3.5 Diagrama de flujo — AjustesScreen (NUEVA)

```
[AjustesScreen]  /settings
    │
    ├── APARIENCIA
    │   └── Tema: [Claro ●  Oscuro]  (toggle switch)
    │
    ├── JUEGO
    │   └── Sonido / haptics: ON / OFF  (placeholder para futuro)
    │
    ├── PERFIL ONLINE  (visible solo si hay sesión)
    │   └── → /online/perfil  (DisplayNameScreen)
    │
    └── INFO
        ├── Cómo jugar       → /how-to-play
        ├── Reglas y puntos  (ExpansionTile inline — no navega)
        └── Versión X.Y.Z
```

---

### 3.6 Diagrama de flujo — Flujo LOCAL completo

```
[HomeScreen]
    │ "Juego rápido" (loading 400ms)
    ▼
[GameSetupScreen]
    │ Añade jugadores, elige modo/categorías/timer
    │ "Comenzar" (loading 400ms)
    ▼
[RoleRevealScreen]  ← sin cambios de lógica
    │ N jugadores × (deslizar + "Siguiente")
    │ Último jugador: "Empezar Juego"
    ▼
[GamePlayScreen]  ← ELIMINA RoundStartScreen
    │   Al entrar: muestra banner animado
    │   "Empieza: {jugador}" durante 2 s (sin bloquear)
    │
    ├── [Votar]
    │     ▼
    │   [VoteScreen — REFACTORIZADA]
    │     Express: lista de chips visuales (avatares coloreados)
    │     Step 1: ¿Quién vota? → tap chip del votante
    │     Step 2: ¿A quién? → tap chip del objetivo
    │     Step 3: Confirmar
    │       ▼
    │     [ActionRevealScreen]  ← sin cambios
    │       │
    │       ├── Si votaron mal → back a /play
    │       ├── Si impostor eliminado (Clásico):
    │       │     BottomSheet "¿{nombre} quiere adivinar?"  [SÍ] / [NO]
    │       │     (ELIMINA ClassicImpostorChoiceScreen)
    │       │         ▼ SÍ
    │       │       [ImpostorGuessScreen]
    │       │         ▼
    │       │       [ActionRevealScreen] → /results o /play
    │       └── Si juego terminó → /results
    │
    └── [Adivinar] (Express)
          ▼
        [ImpostorGuessScreen]  ← sin cambios de lógica
          ▼
        [ActionRevealScreen] → /results o /play
```

**Eliminaciones en flujo local:**
- `RoundStartScreen` → fusionado como banner en `GamePlayScreen`
- `ClassicImpostorChoiceScreen` → fusionado como `BottomSheet` dentro de `ActionRevealScreen`

---

### 3.7 Diagrama de flujo — Flujo ONLINE

```
[HomeScreen]
    │ "Jugar en línea" (loading lazy Supabase)
    ▼
[OnlineHomeScreen — REDISEÑADA]
    │
    │   ESTADO INICIAL (carga transparente):
    │   Pantalla ya muestra layout con skeleton/shimmer
    │   mientras hace auth anónima + carga profile en background.
    │   Si no tiene nombre → banner amarillo "Completa tu perfil"
    │   con CTA → /online/perfil  (no redirige sola)
    │
    │   Una vez lista:
    │   ┌─────────────────────────────────┐
    │   │  [chip: Avatar + Nombre  ✏]     │
    │   │                                 │
    │   │  [CREAR SALA]                   │
    │   │  [UNIRSE CON CÓDIGO]            │
    │   └─────────────────────────────────┘
    │
    ├── "CREAR SALA"
    │     │  (acción directa, sin pantalla intermedia)
    │     │  Muestra loading inline en el botón
    │     ▼
    │   [RoomLobbyScreen]  ← ELIMINA CreateRoomScreen
    │   (el host ve: código, config, jugadores, botón "Iniciar")
    │     ▼
    │   [OnlineMatchScreen]
    │     (todas las fases: role reveal, clues, voting, results)
    │     └── "Volver a jugar" → nuevo match en mismo lobby
    │
    └── "UNIRSE CON CÓDIGO"
          ▼
        [JoinRoomScreen]  ← sin cambios
          ▼
        [RoomLobbyScreen]
          ▼
        [OnlineMatchScreen]
```

**Eliminación clave:** `CreateRoomScreen` se elimina. La acción "Crear sala" llama al repo directamente desde el botón del `OnlineHomeScreen` con loading en el botón, igual que lo hacía `CreateRoomScreen` pero sin cambiar de ruta. Al completar, navega directo a `/online/room/:id`.

---

## 4. Tabla pantalla actual → propuesta

| Pantalla actual | Ruta actual | Acción propuesta | Ruta propuesta | Motivo |
|----------------|-------------|-----------------|----------------|--------|
| HomeScreen | `/` | REDISEÑAR | `/` | Mover toggle tema a Settings; sin cambios estructurales |
| HowToPlayScreen | `/how-to-play` | REDISEÑAR | `/how-to-play` | Reducir de 8 a 3 páginas; scoring a Settings |
| — (no existe) | — | CREAR | `/settings` | Tema + futuras prefs + reglas; hogar del toggle |
| GameSetupScreen | `/setup` | MANTENER | `/setup` | Funcional; mejoras de UI son cosméticas |
| RoleRevealScreen | `/role-reveal` | MANTENER | `/role-reveal` | El deslizar-para-revelar es un gesto de fiesta único |
| RoundStartScreen | `/round-start` | ELIMINAR | — | Fusionada como banner en GamePlayScreen |
| GamePlayScreen | `/play` | MANTENER + absorbe splash | `/play` | Añadir banner "Empieza: X" al montar |
| VoteScreen | `/vote` | REDISEÑAR | `/vote` | Reemplazar texto autocomplete por chips visuales |
| ActionRevealScreen | `/action-reveal` | MANTENER | `/action-reveal` | Dramático, funciona bien |
| ClassicImpostorChoiceScreen | `/classic-impostor-choice` | ELIMINAR | — | Fusionada como BottomSheet en ActionRevealScreen |
| ImpostorGuessScreen | `/impostor-guess` | MANTENER | `/impostor-guess` | Recibe parámetro de modo para unificar lógica |
| GameResultsScreen | `/results` | REDISEÑAR | `/results` | Añadir CTA "Ver ranking del grupo" |
| GroupsScreen | `/groups` | MANTENER | `/groups` | OK |
| GroupDetailScreen | `/groups/:id` | MANTENER | `/groups/:id` | OK |
| RankingsScreen | `/rankings/:id` | MANTENER | `/rankings/:id` | OK |
| GameHistoryScreen | `/history/:id` | MANTENER | `/history/:id` | OK |
| OnlineHomeScreen | `/online` | REDISEÑAR | `/online` | Auth transparente + skeleton; "Crear sala" acción directa |
| DisplayNameScreen | `/online/display-name` | RENOMBRAR + REUBICAR | `/online/perfil` | Accesible desde Settings y desde chip en OnlineHome |
| CreateRoomScreen | `/online/create-room` | ELIMINAR | — | Era una pantalla de transición disfrazada |
| JoinRoomScreen | `/online/join-room` | MANTENER | `/online/join-room` | OK |
| RoomLobbyScreen | `/online/room/:id` | MANTENER | `/online/room/:id` | Absorbe el rol de CreateRoomScreen |
| OnlineMatchScreen | `/online/match/:id` | MANTENER | `/online/match/:id` | Compleja internamente pero funciona |

**Resumen de acciones:**
- MANTENER: 10 pantallas
- REDISEÑAR (UI/IA, sin tocar lógica): 5 pantallas (Home, HowToPlay, VoteScreen, GameResults, OnlineHome)
- CREAR: 1 pantalla nueva (Settings)
- ELIMINAR: 3 pantallas (RoundStart, ClassicImpostorChoice, CreateRoom)
- RENOMBRAR/REUBICAR: 1 pantalla (DisplayName)

---

## 5. Hallazgos priorizados con referencias de archivo

### P0 — Bloqueadores de UX

| ID | Descripción | Archivo:línea | Acción |
|----|-------------|---------------|--------|
| P0-A | Toggle de tema huérfano en HomeScreen, sin pantalla de Ajustes | `home_screen.dart:54–63` | Crear `/settings`, mover toggle |
| P0-B | Flujo de auth online: 5 estados de carga encadenados sin skeleton, la redirección a display-name es silenciosa | `online_home_screen.dart:119–214` | Rediseñar OnlineHomeScreen con carga transparente (skeleton) y banner contextual |
| P0-C | VoteScreen Express: autocomplete de texto para seleccionar jugadores es lento y propenso a errores en fiesta | `vote_screen.dart:411–501` | Reemplazar por chips visuales tap-to-select |

### P1 — Importantes

| ID | Descripción | Archivo:línea | Acción |
|----|-------------|---------------|--------|
| P1-A | Falta pantalla de Ajustes (no hay ningún archivo) | — | CREAR `/settings` |
| P1-B | RoundStartScreen es splash de 2 s sin interacción — paso muerto | `round_start_screen.dart:22–23` | ELIMINAR, fusionar banner en GamePlayScreen |
| P1-C | HowToPlayScreen tiene 8 páginas; "Cómo jugar" es TextButton invisible | `how_to_play_screen.dart:83` (totalPages=8), `home_screen.dart:223–229` | Reducir a 3 páginas; scoring → Settings |
| P1-D | CreateRoomScreen es pantalla vacía que auto-redirige (paso redundante) | `create_room_screen.dart:20–46` | ELIMINAR; acción directa desde OnlineHome |
| P1-E | GameResultsScreen no ofrece ir directamente al ranking del grupo | `game_results_screen.dart:46–74` | Añadir CTA "Ver ranking" |
| P1-F | ClassicImpostorChoiceScreen: pantalla completa para decisión binaria | `classic_impostor_choice_screen.dart:27–` | Convertir en BottomSheet dentro de ActionRevealScreen |

### P2 — Menores / Futuros

| ID | Descripción | Archivo:línea | Acción |
|----|-------------|---------------|--------|
| P2-A | Sin estado vacío atractivo en primera apertura | `home_screen.dart` | Añadir hint contextual si no hay grupos guardados |
| P2-B | Rankings/Historial no accesibles desde Home directamente | `app_router.dart:133–146` | Considerar acceso directo desde Home o Settings |
| P2-C | DisplayNameScreen: ruta semánticamente incorrecta (`/online/display-name`) | `app_router.dart:117–119` | Renombrar a `/online/perfil` |
| P2-D | VoteScreen Clásico mezcla votación normal y desempate en el mismo widget con lógica condicional compleja | `vote_screen.dart:213–409` | Separar en subvistas claras (sin cambiar lógica) |

---

## 6. Notas de implementación para el rebrand

### Lo que NO se toca (restricción dura)
- Lógica de `gameProvider` (Riverpod / Drift)
- Lógica de `onlineMatchChannel` / `onlineRoomChannel` (Supabase)
- Fases del juego: rol → pistas → votación → resultado → adivinanza
- Cálculo de puntos
- Anti-repetición de palabras (`word_bank.dart`, tabla `word_history`)

### Orden de implementación sugerido (de menor a mayor riesgo)

1. **AjustesScreen** (nueva, cero riesgo — solo mueve el `isDarkModeProvider.notifier.toggle()` que ya existe)
2. **Eliminar RoundStartScreen** (bajo riesgo — añadir `postFrameCallback` en `GamePlayScreen.initState` para mostrar banner 2 s)
3. **Fusionar ClassicImpostorChoiceScreen como BottomSheet** (medio — cambiar la navegación en `action_reveal_screen.dart:86–89` de `context.go('/classic-impostor-choice')` a `showModalBottomSheet`)
4. **Eliminar CreateRoomScreen** (medio — mover el `createPrivateRoom()` al botón de OnlineHomeScreen)
5. **Rediseñar VoteScreen** (chips visuales) — alto impacto en partidas
6. **Rediseñar OnlineHomeScreen** (skeleton + carga transparente)
7. **Reducir HowToPlayScreen** a 3 páginas

### Consideraciones de navegación go_router
- Al eliminar `/round-start`, verificar que `RoleRevealScreen._nextPlayer()` (`role_reveal_screen.dart:85`) cambie `context.go('/round-start')` por `context.go('/play')` y llame al notifier `startPlaying()` antes de navegar.
- Al eliminar `/classic-impostor-choice`, el `BottomSheet` puede llamar directamente a la navegación `context.push('/impostor-guess')` o `context.go('/play')` sin registrar una nueva ruta.
- Al eliminar `/online/create-room`, el botón "Crear sala" en `OnlineHomeScreen` llama directamente `onlineRoomsRepositoryProvider.createPrivateRoom(...)` con loading en el propio botón, exactamente como lo hacía `create_room_screen.dart:20–46`.
