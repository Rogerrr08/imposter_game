# 04 — Componentes y consistencia de UI

> Auditoría para rebrand. Fecha: 2026-06-19.
> Alcance: `lib/screens/` (LOCAL) y `lib/features/online/presentation/` (ONLINE).
> Herramienta base: `lib/theme/app_theme.dart` (tokens disponibles).
> **Restricción dura:** solo presentación/componentes — cero cambios de lógica.

---

## 0 · Resumen cuantitativo de inconsistencias

| Métrica | Valor |
|---|---|
| `BorderRadius.circular(N)` distintos | **14** valores (2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 28, 999) |
| Ocurrencias totales de `BorderRadius.circular` | **160** |
| `fontSize:` distintos (fuera del tema) | **22** valores (10 – 120) |
| Valores de opacidad (`withValues(alpha:)`) distintos | **30** valores (0.05 – 1.0) |
| `_badge()` definido N veces en archivos distintos | **5** copias idénticas |
| `_buildErrorState` / `_buildLoadingState` / `_buildCenteredMessage` duplicados | **4** variantes sin extrae |
| `CircularProgressIndicator` instanciados inline | **39** ocurrencias |
| `boxShadow:` declarados fuera del tema | **10** ocurrencias |
| Tamaños de fuente micro (10, 11, 12.5 px) | **25** usos |
| Colores hardcoded `Color(0x...)` fuera de `app_theme.dart` | **2 archivos** (gold/silver/bronze duplicados) |

---

## 1 · Catálogo de patrones repetidos

### 1.1 Badge / Pill

Patrón: `Container` con `padding(h:8-12, v:2-6)`, `BorderRadius.circular(999)`, `color.withValues(alpha:0.12)`, `Text(fontSize:10-12, w700)`.

Encontrado en (con variaciones de padding/fontSize que divergen):
- `lib/features/online/presentation/widgets/lobby_code_card.dart:141` — pad h:10/v:6, fs:12
- `lib/features/online/presentation/widgets/lobby_players_section.dart:183` — pad h:10/v:6, fs:12
- `lib/features/online/presentation/widgets/match_results_phase.dart:1052` — pad h:10/v:4, fs:11
- `lib/features/online/presentation/widgets/role_reveal_phase.dart:447` — pad h:12/v:6, fs:13
- `lib/features/online/presentation/widgets/impostor_guess_phase.dart:454` — pad h:10/v:4 (inferir)

Además badges **inline** (sin helper) en:
- `match_results_phase.dart:717` — role badge h:8/v:2, fs:10, `BorderRadius.circular(999)`
- `match_results_phase.dart:853` — late joiner badge h:8/v:2, fs:10
- `voting_phase.dart:283` — role badge h:6/v:1, `BorderRadius.circular(6)` ← rompe el patrón pill

**5 métodos `_badge()` con firmas idénticas, 3+ variantes de sizing sin justificación.**

---

### 1.2 Card de contenido (icon + title + subtitle)

Patrón: `Container(padding, decoration(color, borderRadius, border), Column[icon_container, Text(title,w800), Text(subtitle)])`.

- `online_home_screen.dart:332` — `_buildActionCard()` — radio **22**, padding **18**
- `room_lobby_screen.dart:224` — `_buildReadyCard()` — radio **22**, padding **18**
- `room_lobby_screen.dart:303` — match-in-progress banner — radio **22**, padding **18**
- `online_home_screen.dart:252` — `_buildHero()` — radio **24**, padding **20**
- `lobby_code_card.dart:21` — radio **28**, padding fromLTRB(20,22,20,20)

**Cinco cards "icon + título + subtítulo" con radios distintos: 22, 22, 22, 24, 28.**

En LOCAL:
- `game_results_screen.dart:85` — `_buildSpotlightSection()` — radio **24**, padding **18**
- `vote_screen.dart:655` — confirm card — radio **24**, padding **28**

**Total: 7 cards del mismo patrón visual con 5 radios distintos (18, 22, 24, 26, 28).**

---

### 1.3 Estado vacío / error / carga (Empty/Error/Loading states)

Patrón centrado: icon grande (48–58px) + título (fs:18, w800) + subtítulo (fs:14, h:1.45) ± botón.

**4 implementaciones independientes sin componente compartido:**

| Archivo | Método | Radio badge | Icono size | FS título |
|---|---|---|---|---|
| `online_home_screen.dart:404` | `_buildLoadingState` | — | — | 18 |
| `online_home_screen.dart:441` | `_buildErrorState` | — | 58 | 18 |
| `create_room_screen.dart:259` | `_buildErrorState` | — | ~48 | 18 |
| `room_lobby_screen.dart:459` | `_buildCenteredMessage` | — | 56 | 18 |

En LOCAL, mismo patrón pero implementado directo en `build()` de `rankings_screen.dart:117`.

---

### 1.4 Fila de jugador (avatar + nombre + badge de rol/estado)

Dos versiones con divergencias visibles:

**LOCAL** (`game_results_screen.dart:456` `_buildRankedPlayerCard`):
- `BorderRadius.circular(12)`, padding `h:14/v:12`, avatar ausente (solo texto+role badge rectangular `BorderRadius.circular(6)`)

**ONLINE** (`match_results_phase.dart:635` `_buildPlayerRow`):
- `BorderRadius.circular(16)`, padding `h:16/v:14`, `PlayerAvatar` size:36, role badge pill `BorderRadius.circular(999)`

**Local usa radios rect (6, 12); online usa pills (999, 16).** Distinción visual no intencional.

---

### 1.5 Avatar de jugador

`PlayerAvatar` existe como widget en `lib/features/online/presentation/widgets/player_avatar.dart`.

En LOCAL no existe equivalente: los jugadores locales nunca tienen avatar, solo texto. El componente podría unificarse para ambos modos con `avatarUrl: null` en local.

---

### 1.6 Botón de acción principal a pantalla completa (fullscreen CTA)

Patrón: `SizedBox(width: double.infinity, child: ElevatedButton(..., padding: EdgeInsets.symmetric(vertical: V)))`.

Valores de `vertical` observados: **14, 16, 17, 18** — sin regla. Ejemplo directo:
- `home_screen.dart:138` — v:18, fs:18
- `home_screen.dart:148` — v:18, fs:18
- `home_screen.dart:206` — v:16, fs:17 ← mismo pantalla, botón "Jugar en línea" diverge
- `match_results_phase.dart:467` — v:16
- `role_reveal_phase.dart:417` — v:18
- `vote_screen.dart:393` — v:18

---

### 1.7 Resultado a pantalla completa (winner announcement)

LOCAL (`game_results_screen.dart:111` `_buildResultHeader`):
- Imagen 188×188, título fs:**36**, w900, sin card contenedora

ONLINE (`match_results_phase.dart:302`):
- Imagen 120×120, título fs:**24**, w900, dentro de `Container` card con borde

**Mismo concepto "quién ganó" pero tamaño de imagen y tipografía distintos (36 vs 24).**

---

### 1.8 Reveal de palabra secreta

LOCAL (`game_results_screen.dart:160` `_buildWordReveal`):
- `BorderRadius.circular(18)`, padding v:22/h:20, fs:**38** (palabra)

ONLINE (`role_reveal_phase.dart:370` `_buildWordCard`):
- `BorderRadius.circular(24)`, padding all:24, fs:**32** (palabra)

**Misma card, radios 18 vs 24, tamaños de fuente 38 vs 32.**

---

### 1.9 Headers de sección

LOCAL: `SectionHeader` widget en `lib/screens/game_setup/widgets/section_header.dart` — icon + Text(fs:16, w700).

ONLINE: `LobbyPlayersSection` **importa y usa** `SectionHeader` — bien.

Pero `match_results_phase.dart:387` define el header inline con Text(fs:16, w800) — sin importar `SectionHeader`.

---

### 1.10 Dialogo de confirmación

Patrón: `AlertDialog(title Text(w700), content Text, actions[TextButton("Cancelar"), ElevatedButton])`.

Aparece en: `room_lobby_screen.dart:422`, `lobby_players_section.dart:244`, `match_results_phase.dart:941`, `match_results_phase.dart:992`, `game_results_screen.dart:625`, `game_results_screen.dart:680`, `vote_screen.dart:167`.

**7 diálogos de confirmación hardcodeados con la misma estructura.**

---

## 2 · Diagnóstico de inconsistencias concretas

### 2.1 Caos de BorderRadius (P0)

14 valores distintos para lo que son conceptualmente 3 casos:

| Caso semántico | Valores usados | Valor correcto propuesto |
|---|---|---|
| Card/contenedor principal | 16, 18, 20, 22, 24, 28 | 1 token `kRadiusCard` |
| Input / chip secundario | 12, 14 | 1 token `kRadiusInput` |
| Pill / badge | 999 | 1 token `kRadiusPill` |
| Micro / tag role | 6, 8, 10 | unificar con `kRadiusPill` |
| Botón primario | 16 (via tema) | ya en `ThemeData` |

La divergencia más grave: `_buildRankedPlayerCard` LOCAL usa `borderRadius: BorderRadius.circular(12)` y el role badge usa `.circular(6)`, mientras ONLINE usa `.circular(16)` y `.circular(999)` → misma pantalla conceptual, look completamente distinto.

### 2.2 Escala tipográfica ad-hoc (P0)

22 valores de `fontSize` distintos. La escala implícita tiene brechas irracionales: 10, 11, 12, 12.5, 13, 14, 15, 16, 17, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 42, 120.

Problemas concretos:
- `fontSize: 12.5` en `lib/screens/game_play/game_play_screen.dart` — valor flotante sin precedente
- `fontSize: 120` — solo en timer countdown (aceptable como excepción)
- Los badges de rol oscilan entre fs:10 y fs:13 según el archivo, sin regla

Una escala neón fiesta debería tener como máximo 8 steps: 10, 12, 14, 16, 18, 22, 28, 36.

### 2.3 Opacidades fractales (P1)

30 valores distintos de `withValues(alpha:...)`. Ejemplos de lo redundante:
- `0.10` y `0.10` y `0.1` (mismo valor, formato distinto → 3 entradas en el grep)
- `0.09`, `0.08`, `0.06`, `0.05` — diferencias imperceptibles para el ojo humano
- `0.82` usado exactamente una vez (`game_results_screen.dart:264`)
- `0.38` usado exactamente una vez (`match_results_phase.dart`)

Propuesta: 6 niveles semánticos (`alpha.faint=0.06`, `alpha.subtle=0.12`, `alpha.soft=0.2`, `alpha.medium=0.35`, `alpha.strong=0.5`, `alpha.opaque=0.75`).

### 2.4 Colores hardcodeados duplicados (P1)

Oro/plata/bronce definidos dos veces con los mismos valores hex:
- `lib/screens/rankings/rankings_screen.dart:23-25` — constantes `_goldColor`, `_silverColor`, `_bronzeColor`
- `lib/features/online/presentation/widgets/match_results_phase.dart:643-647` — inline `Color(0xFFFFD700)` etc.

Estos deberían ser `AppTheme.goldColor`, `AppTheme.silverColor`, `AppTheme.bronzeColor`.

### 2.5 Divergencia local ↔ online en pantallas equivalentes (P0)

| Pantalla | LOCAL | ONLINE | Diferencia |
|---|---|---|---|
| Resultado ganador | Imagen 188px, fs:36 | Imagen 120px, fs:24 | -68px, -12pt |
| Ranking jugadores | Radius:12, badge rect:6 | Radius:16, badge pill:999 | dos lenguajes visuales |
| Reveal palabra | Radius:18, fs:38 | Radius:24, fs:32 | inconsistente |
| CTA botón principal | vertical:16–18 sin regla | vertical:16–18 sin regla | ambos caóticos |
| Role reveal | Panel deslizable (swipe) | Animación secuencial | OK — diferencia intencional |

### 2.6 Padding de pantalla inconsistente (P1)

Márgenes horizontales de pantalla: 16, 20, 24, 32 px usados sin criterio.
- `home_screen.dart:71` — `EdgeInsets.symmetric(horizontal: 32)` ← valor ancho
- `online_home_screen.dart:220` — `EdgeInsets.fromLTRB(24, 8, 24, 32)`
- `room_lobby_screen.dart:140` — `EdgeInsets.fromLTRB(20, 8, 20, 24)`
- `game_results_screen.dart:28` — `EdgeInsets.all(24)`

Propuesta: 1 token `kScreenPadding = EdgeInsets.symmetric(horizontal: 20)`.

### 2.7 Sombras improvisadas (P2)

10 declaraciones `boxShadow` fuera del tema. Cada una usa un `blurRadius` y `offset` distintos:
- `game_results_screen.dart:95` — blur:24, offset(0,10), alpha:0.06
- `lobby_code_card.dart:31` — blur:18, offset(0,8), alpha:0.07
- `role_reveal_phase.dart:167` — blur:24/48, spread:4/8 (glow neón — excepción aceptable)
- `match_results_phase.dart:417` — blur:16, offset(0,-4), alpha:0.09

Las primeras 3 deberían unificarse en `AppTheme.cardShadow`.

### 2.8 `fontFamily: 'Nunito'` inline (ya registrado en CLAUDE.md, P2)

`grep` confirma 0 ocurrencias en `lib/features/online/` (ya corregido o nunca estuvo ahí según baseline). Solo presentes en `app_theme.dart` (correcto). No es deuda activa.

---

## 3 · Kit de componentes compartido propuesto — `lib/widgets/`

### Tokens a agregar en `AppTheme` primero

```dart
// Radios
static const kRadiusPill   = 999.0;
static const kRadiusCard   = 20.0;   // único radio para cards principales
static const kRadiusInput  = 14.0;   // inputs + chips secundarios
static const kRadiusMicro  = 6.0;    // solo tags muy pequeños (< 10px font)

// Padding
static const kScreenH      = 20.0;   // margen horizontal de pantalla

// Sombra estándar de card
static List<BoxShadow> cardShadow = [
  BoxShadow(color: Colors.black.withValues(alpha:0.07), blurRadius:16, offset: Offset(0,6)),
];

// Opacidades semánticas
static const aSurface = 0.08;   // fondo tintado suave
static const aBorder  = 0.15;   // bordes suaves
static const aSoft    = 0.25;   // elementos hover/selected suave
static const aMedium  = 0.45;   // disabled, muted
static const aStrong  = 0.75;   // overlay semitransparente

// Escala tipográfica (8 steps)
// xs=10, sm=12, base=14, md=16, lg=18, xl=22, 2xl=28, 3xl=36

// Colores medallas
static const goldColor   = Color(0xFFFFD700);
static const silverColor = Color(0xFFC0C0C0);
static const bronzeColor = Color(0xFFCD7F32);
```

---

### Componentes a extraer (ordenados por P0 → P2)

#### P0 — Bloquean la coherencia visual del rebrand

**`AppBadge`** — `lib/widgets/app_badge.dart`
- Reemplaza los 5+ métodos `_badge()` duplicados y los badges inline
- Props: `label`, `color`, variante `size` (sm/md)
- Consume: `kRadiusPill`, escala xs/sm

```dart
// Ejemplo de API
AppBadge(label: 'Impostor', color: AppTheme.secondaryColor)
AppBadge(label: 'Host', color: AppTheme.primaryColor, size: AppBadgeSize.sm)
```

**`AppCard`** — `lib/widgets/app_card.dart`
- Contenedor estándar: `color`, `borderRadius: kRadiusCard`, `Border`, `BoxShadow` opcionales
- Reemplaza las 7+ instancias inline de `Container(decoration: BoxDecoration(...))`
- Variantes: `AppCard.tinted(accentColor)` para cards coloreadas según equipo/rol

**`ActionCard`** — `lib/widgets/action_card.dart`
- Card con icon-container circular + título + subtítulo + botón
- Reemplaza `_buildActionCard` en `online_home_screen`, `_buildReadyCard` en `room_lobby_screen`, y similares en LOCAL
- Props: `icon`, `title`, `description`, `accentColor`, child `Widget? action`

**`AppEmptyState`** — `lib/widgets/app_empty_state.dart`
- Unifica los 4+ `_buildLoadingState` / `_buildErrorState` / `_buildCenteredMessage`
- Props: `icon` (opcional), `title`, `subtitle`, `action` (Widget? opcional)
- Variantes: `.loading(title, subtitle)`, `.error(...)`, `.info(...)`

**`PlayerRow`** — `lib/widgets/player_row.dart`
- Fila avatar+nombre+badges; unifica LOCAL y ONLINE
- Props: `displayName`, `avatarUrl?`, `role?`, `points?`, `position?`, `isCurrentUser`, `isEliminated`
- Internamente usa `PlayerAvatar` (ya existe en online; mover a `lib/widgets/`)
- Resuelve divergencia local(rect badges, radius:12) vs online(pills, radius:16)

---

#### P1 — Importantes para coherencia cross-pantalla

**`ResultHero`** — `lib/widgets/result_hero.dart`
- Encabezado fullscreen de resultado: imagen + título ganador + subtítulo
- Unifica `_buildResultHeader` (LOCAL, 188px/fs:36) con el winner block de ONLINE (120px/fs:24)
- Props: `imagePath`, `title`, `subtitle`, `accentColor`, `imageSize` (default único)

**`SecretWordCard`** — `lib/widgets/secret_word_card.dart`
- Card de revelación de palabra: label "La palabra era" + word display grande + badge de categoría
- Unifica LOCAL `_buildWordReveal` (radius:18, fs:38) con ONLINE `_buildWordCard` (radius:24, fs:32)

**`ConfirmDialog`** — `lib/widgets/confirm_dialog.dart`
- Reemplaza los 7 `showDialog(AlertDialog(...))` con la misma estructura
- Props: `title`, `content`, `confirmLabel`, `confirmColor`, `onConfirm`

**`FullWidthButton`** — `lib/widgets/full_width_button.dart` (o como extensión de ElevatedButton)
- Wrapper: `SizedBox(width: double.infinity, child: ElevatedButton(padding: EdgeInsets.symmetric(vertical: 18), ...))`
- Fija el padding vertical en 18 para CTA primarios, elimina los 16/17/18 ad-hoc

**`SectionHeader`** — ya existe en `lib/screens/game_setup/widgets/section_header.dart`
- **MOVER** a `lib/widgets/section_header.dart` (actualmente solo accesible desde LOCAL)
- `match_results_phase.dart:387` ya lo necesita pero no lo puede importar fácilmente

---

#### P2 — Calidad y mantenibilidad

**`PlayerAvatar`** — **MOVER** de `lib/features/online/presentation/widgets/` a `lib/widgets/`
- Único componente de avatar, usado en online; futuro uso en local posible

**`StatusDot`** — `lib/widgets/status_dot.dart`
- El dot de conexión 8×8 px en `lobby_players_section.dart:134` aparece 2+ veces
- Props: `isConnected`, `size` (default 8)

**`AppProgressBar`** — `lib/widgets/app_progress_bar.dart`
- Wrapper de `LinearProgressIndicator` con `ClipRRect(borderRadius: kRadiusPill)` consistente
- Visto en `lobby_code_card.dart:101` y `role_reveal_screen.dart:187` con radios distintos (999 vs 8)

**`WaitingSpinner`** — `lib/widgets/waiting_spinner.dart`
- Los 39 `CircularProgressIndicator` inline deberían reducirse con un wrapper que fije `color: AppTheme.primaryColor`; en contextos de botón, el spinner blanco size:18-22/stroke:2

---

## 4 · Mapa de migración por archivo

### lib/screens/ (LOCAL)

| Archivo | Componentes a usar |
|---|---|
| `home_screen.dart` | `FullWidthButton` |
| `game_results_screen.dart` | `ResultHero`, `SecretWordCard`, `PlayerRow`, `AppCard`, `ConfirmDialog` |
| `game_play/role_reveal_screen.dart` | `AppCard` (word card inline) |
| `game_play/vote_screen.dart` | `AppCard`, `ConfirmDialog`, `FullWidthButton` |
| `rankings/rankings_screen.dart` | `PlayerRow`, `AppEmptyState`; mover `_goldColor` → `AppTheme.goldColor` |

### lib/features/online/presentation/ (ONLINE)

| Archivo | Componentes a usar |
|---|---|
| `online_home_screen.dart` | `ActionCard`, `AppEmptyState`, `AppBadge` (chip del perfil) |
| `room_lobby_screen.dart` | `ActionCard`, `AppEmptyState`, `ConfirmDialog` |
| `widgets/match_results_phase.dart` | `ResultHero`, `SecretWordCard`, `PlayerRow`, `AppBadge`, `ConfirmDialog`; mover `Color(0xFFFFD700)` → `AppTheme.goldColor` |
| `widgets/role_reveal_phase.dart` | `AppCard` (word card), `AppBadge`, `FullWidthButton` |
| `widgets/voting_phase.dart` | `AppBadge`, `FullWidthButton` |
| `widgets/lobby_code_card.dart` | `AppBadge`, `AppProgressBar` |
| `widgets/lobby_players_section.dart` | `PlayerRow`, `AppBadge`, `ConfirmDialog`, `StatusDot` |
| `create_room_screen.dart` | `AppEmptyState` |
| `widgets/player_avatar.dart` | **MOVER** a `lib/widgets/` |

---

## 5 · Hallazgos priorizados

### P0 — Rompen la coherencia visual del rebrand

| # | Hallazgo | Archivo:línea representativa |
|---|---|---|
| P0-1 | 6 radios distintos para "card principal" (16–28) — sensación vibe coded | `online_home_screen.dart:346` (22) vs `lobby_code_card.dart:27` (28) |
| P0-2 | Mismo pattern "ganador" con imagen 188px/fs:36 LOCAL y 120px/fs:24 ONLINE | `game_results_screen.dart:125` vs `match_results_phase.dart:329` |
| P0-3 | `_badge()` copiado 5 veces con sizing divergente (pad h:8–12, fs:10–13) | `role_reveal_phase.dart:447` vs `match_results_phase.dart:1052` |
| P0-4 | Role badge en LOCAL usa `BorderRadius.circular(6)` (rectangular), ONLINE usa `999` (pill) | `game_results_screen.dart:401` vs `match_results_phase.dart:719` |
| P0-5 | 4 implementaciones de empty/error/loading sin componente base | `online_home_screen.dart:404, 441` + `room_lobby_screen.dart:459` + `create_room_screen.dart:259` |

### P1 — Debilitan la consistencia entre pantallas

| # | Hallazgo | Archivo:línea representativa |
|---|---|---|
| P1-1 | 22 valores de `fontSize` distintos; 25 usos de micro-font (10–12 px) | grep-wide |
| P1-2 | 30 valores de opacidad distintos; varios idénticos con formato diferente (0.1 vs 0.10) | grep-wide |
| P1-3 | `Color(0xFFFFD700)` etc. duplicado en `rankings_screen.dart:23` y `match_results_phase.dart:643` | ambos archivos |
| P1-4 | Padding de pantalla 16/20/24/32 sin regla; CTA vertical 14/16/17/18 | `home_screen.dart:71` vs `room_lobby_screen.dart:140` |
| P1-5 | 7 diálogos de confirmación con estructura idéntica sin abstracción | `room_lobby_screen.dart:422`, `match_results_phase.dart:941`, … |
| P1-6 | `SecretWordCard` fs:38 LOCAL vs fs:32 ONLINE; radios 18 vs 24 | `game_results_screen.dart:188` vs `role_reveal_phase.dart:398` |
| P1-7 | `SectionHeader` atrapado en `lib/screens/game_setup/widgets/` — ONLINE lo importa cruzando feature boundaries | `lobby_players_section.dart:4` import path |

### P2 — Deuda técnica / mantenibilidad

| # | Hallazgo | Archivo:línea representativa |
|---|---|---|
| P2-1 | 10 `boxShadow` con valores distintos; debería existir `AppTheme.cardShadow` | `game_results_screen.dart:95`, `lobby_code_card.dart:31` |
| P2-2 | 39 `CircularProgressIndicator` inline, color repetido en cada uno | grep-wide |
| P2-3 | `PlayerAvatar` en feature-local, no en `lib/widgets/` — imposible reusar en LOCAL sin cross-feature import | `lib/features/online/presentation/widgets/player_avatar.dart` |
| P2-4 | `LinearProgressIndicator` wrapeado con `ClipRRect` radius 999 en un lugar y 8 en otro | `lobby_code_card.dart:101` vs `role_reveal_screen.dart:187` |
| P2-5 | Dot de status 8×8 duplicado en `lobby_players_section.dart` y potencialmente en otras partes | `lobby_players_section.dart:134` |

---

## 6 · Orden de implementación recomendado

```
Sprint 1 (tokens + extracciones zero-risk)
  → Agregar tokens a AppTheme (radios, opacidades, colores medalla)
  → Mover PlayerAvatar a lib/widgets/
  → Mover SectionHeader a lib/widgets/
  → Crear AppBadge (reemplaza 5 métodos _badge idénticos)
  → Crear ConfirmDialog (reemplaza 7 AlertDialog idénticos)

Sprint 2 (componentes estructurales)
  → Crear AppEmptyState (consolida 4+ variantes)
  → Crear AppCard (consolida 7+ Container/BoxDecoration)
  → Crear FullWidthButton (fija CTA padding)

Sprint 3 (pantallas de resultado — máxima visibilidad rebrand)
  → Crear ResultHero (unifica LOCAL 188px/36pt + ONLINE 120px/24pt)
  → Crear SecretWordCard (unifica local radius:18/fs:38 + online radius:24/fs:32)
  → Crear PlayerRow (unifica local badge-rect + online badge-pill)

Sprint 4 (integración ONLINE)
  → Migrar widgets/match_results_phase.dart a componentes
  → Migrar online_home_screen.dart → ActionCard

Sprint 5 (integración LOCAL)
  → Migrar game_results_screen.dart a componentes
  → Migrar vote_screen.dart dialogs → ConfirmDialog
```

---

*Este documento no contiene cambios de código en la app. Es solo el plano de componentes para el rebrand.*
