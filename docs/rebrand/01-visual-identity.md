# Rebrand Visual Identity — Yeison Impostor
## "Neon Fiesta Nocturna" Design System v1.0

> Auditoría + propuesta de tokens lista para implementar en `app_theme.dart`.
> Autor: auditoría de identidad visual, junio 2026.
> Alcance: SOLO sistema visual. Cero cambios a lógica de juego.

---

## 1. Diagnóstico — Identidad actual

### 1.1 Paleta

El tema oscuro "Neon Undercover" (`app_theme.dart` líneas 17–26) ya tiene instintos correctos:
cyan primario `#00D1FF`, magenta secundario `#FF2D7B`, fondo casi negro `#0A0A12`.
Pero hay cuatro problemas estructurales:

| Hallazgo | Archivo:línea | Severidad |
|----------|--------------|-----------|
| **P0 — Sin glow/sombra de color.** Todos los `boxShadow` usan `Colors.black` o `color.withValues(alpha: 0.35)`. Un neón sin glow es solo texto de colores, no luz. | `app_theme.dart:246`, `role_reveal_screen.dart:212-219`, `game_results_screen.dart:93-100` | P0 |
| **P0 — Elevation = 0 en todo.** `ElevatedButton` y `Card` tienen `elevation: 0`. Los botones primarios se ven planos; en modo dark parecen rectangulos sin volumen. | `app_theme.dart:183, 243` | P0 |
| **P1 — Capas de fondo sin profundidad.** Solo hay dos pasos de oscuridad: `#0A0A12` (fondo) → `#12121E` (superficie) → `#1A1A2E` (card). La diferencia entre surface y card es insignificante (8 pasos de luminosidad). Las cards flotan sin contraste sobre la superficie. | `app_theme.dart:19-21` | P1 |
| **P1 — Violeta ausente en UI principal.** `#A855F7` aparece en `darkPanelColors` (role reveal) pero nunca como token semántico. El trio cyan/violeta/magenta existe en panelColors pero se desconecta del resto del sistema. | `app_theme.dart:35-39` | P1 |
| **P1 — Inconsistencia de radios.** Se usan 8, 10, 12, 14, 16, 18, 20, 22, 24 px de borderRadius en distintos widgets. No hay escala. | `app_theme.dart:189,222,247,257,293`, múltiples screens | P1 |
| **P1 — OutlinedButton.side demasiado tenue.** El borde del botón online/grupos usa `textSecondary` al 22% de opacidad (`app_theme.dart:200`). En dark mode sobre `#0A0A12` casi desaparece. | `app_theme.dart:200` | P1 |
| **P2 — Tipografía: solo un peso de Nunito cargado.** `pubspec.yaml` línea 85 declara únicamente `Nunito-Regular.ttf`. Todo el peso visual lo hace Flutter interpolando sintéticamente los pesos 700/800/900, lo que produce texto pesado pero con rendering inconsistente entre plataformas. | `pubspec.yaml:83-86` | P2 |
| **P2 — Sin iconografía personalizada.** Se usan exclusivamente `Icons.*` de Material Design: `play_arrow_rounded`, `group`, `wifi_rounded`, `help_outline`. Coherentes pero genéricos; no refuerzan la identidad neón/fiesta. | `home_screen.dart:134,149,201,223` | P2 |
| **P2 — Ilustraciones con fondo blanco.** `player_civil.webp`, `civil_correct_guess.webp`, etc. tienen fondo blanco opaco. Sobre `#0A0A12` producen un recuadro blanco visible que rompe la inmersión oscura. Solo `app_logo.webp` y `app_logo_no_bg.webp` tienen fondo negro/transparente. | Todos los `.webp` de resultado | P2 |
| **P2 — Espaciado improvisado.** Se mezclan 4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 28, 32, 40 px. Sin escala de 4 px consistente aplicada. | Múltiples screens | P2 |

### 1.2 Tipografía

- Familia: **Nunito** — excelente elección. Redonda, legible, juvenil. CONSERVAR.
- Pesos efectivos disponibles: solo Regular (400) → Flutter sintetiza 700/800/900.
- La pantalla home usa `fontWeight: w900, letterSpacing: 6` en "YEISON" — funciona bien como logotipo pero se vería mejor con la fuente real ExtraBold/Black.
- No existe escala tipográfica declarada: cada pantalla define `fontSize` ad-hoc (12, 13, 14, 15, 16, 17, 18, 20, 26, 28, 32, 36, 38, 42 px).

### 1.3 Ilustraciones

Los personajes (Yeison) son de estilo cartoon / comic con:
- Paleta: rojos oscuros (`#8B1A1A` aprox.), negros, blancos, outline negro grueso.
- Expresividad alta: pulgar arriba, brazos cruzados, lupa, máscara de esquí — narrativa de roles muy clara.
- Problema principal: fondo blanco sólido en la mayoría. Solución: necesitan `BoxDecoration` con `borderRadius` para enmarcar en card oscura, O regenerarse/recortarse con fondo transparente.
- El rojo-naranja de los personajes (`~#C1350A`) choca con el cyan `#00D1FF` del tema. En la propuesta de rebrand se puede capitalizar ese choque como acento "civil warm" intencionado.

### 1.4 Logo

`app_logo.webp` — cara de Yeison sobre fondo negro con halo rojo. Ya encaja en modo oscuro. `app_logo_no_bg.webp` — sin fondo. El logo se usa como imagen de "cover" en la pantalla de rol reveal (paneles de colores) — funciona bien.

---

## 2. Propuesta — Design System "Neon Fiesta Nocturna"

### 2.1 Filosofía de capas

El sistema se basa en tres capas de oscuridad + luz neón emergente, como un escenario de night-club: el suelo es casi negro, los focos son cyan/magenta/violeta, y los personajes (ilustraciones) viven en el centro de esa luz.

```
  [ Glow / Neón ]   ← acentos vibrantes, efectos de luz
  [ Superficie ]    ← cards, inputs, paneles
  [ Base ]          ← scaffold, fondo general
  [ Abismo ]        ← detrás de modales, overlays oscuros
```

---

### 2.2 Tokens de color — tabla lista para `app_theme.dart`

#### 2.2.1 Capas de fondo (reemplaza `_darkBackground/Surface/Card`)

| Token | Nombre semántico | Hex propuesto | Actual |
|-------|-----------------|---------------|--------|
| `neonBg0` | Abismo (overlay/modal) | `#04040A` | — |
| `neonBg1` | Background (scaffold) | `#08080F` | `#0A0A12` |
| `neonBg2` | Surface (inputs, track) | `#0F0F1C` | `#12121E` |
| `neonBg3` | Card (containers) | `#16162A` | `#1A1A2E` |
| `neonBg4` | Card elevada (dialogs, bottom sheets) | `#1E1E36` | — |

Diferencia entre pasos: ~7 pasos de valor L* en Oklab para que cada capa sea perceptualmente distinta.

#### 2.2.2 Acentos neón (reemplaza `_darkPrimary/Secondary` y expande)

| Token | Nombre | Hex | Uso |
|-------|--------|-----|-----|
| `neonCyan` | Primario | `#00E5FF` | Botón CTA principal, focus ring, progress bar, rol CIVIL |
| `neonMagenta` | Secundario | `#FF1A75` | Rol IMPOSTOR, alertas destructivas, botón impostor-override |
| `neonViolet` | Terciario | `#BF5FFF` | Panel de jugador #2, elementos de lobby online, chips de sala |
| `neonGreen` | Éxito | `#00FF87` | Victoria civiles, puntos positivos, estado "listo" en lobby |
| `neonAmber` | Advertencia / Palabra secreta | `#FFD000` | Reveal de palabra, hints del impostor, timer urgente |
| `neonRed` | Error / Vida perdida | `#FF3D5A` | Errores de red, civil pierde vida, puntos negativos |
| `neonWhite` | Texto primario | `#F0F0FF` | Texto sobre fondos oscuros |
| `neonMuted` | Texto secundario | `#6060A0` | Labels, subtítulos, placeholders |

#### 2.2.3 Colores semánticos de rol

| Token | Hex | Contexto |
|-------|-----|---------|
| `roleCivil` | `#00E5FF` (= neonCyan) | Badge CIVIL, borde de word card, progress de rol reveal |
| `roleImpostor` | `#FF1A75` (= neonMagenta) | Badge IMPOSTOR, borde de hint card, panel impostor |
| `roleTie` | `#BF5FFF` (= neonViolet) | Pantalla de empate |
| `roleNeutral` | `#FFD000` (= neonAmber) | Reveal de palabra (neutral entre los dos bandos) |

#### 2.2.4 Panel colors (role reveal — reemplaza `darkPanelColors`)

Actualmente 3 colores. Propuesta: 4 para cubrir partidas de hasta 20 jugadores con más variedad:

| Posición | Token | Hex |
|---------|-------|-----|
| 0 | neonCyan | `#00E5FF` |
| 1 | neonViolet | `#BF5FFF` |
| 2 | neonMagenta | `#FF1A75` |
| 3 | neonAmber | `#FFD000` |

---

### 2.3 Tokens de glow / sombra (lo que falta totalmente)

El corazón del rebrand es el **color glow**. Reemplaza `boxShadow: [BoxShadow(color: Colors.black...)]` en botones, cards y paneles:

| Token | Aplicación | Valor sugerido |
|-------|-----------|----------------|
| `glowCyan` | Botón primario, focus, rol CIVIL | `BoxShadow(color: Color(0xFF00E5FF).withValues(alpha: 0.35), blurRadius: 24, spreadRadius: -4)` |
| `glowMagenta` | Botón impostor, badge impostor | `BoxShadow(color: Color(0xFF FF1A75).withValues(alpha: 0.35), blurRadius: 20, spreadRadius: -4)` |
| `glowViolet` | Cards online, lobby code | `BoxShadow(color: Color(0xFFBF5FFF).withValues(alpha: 0.28), blurRadius: 18, spreadRadius: -4)` |
| `glowAmber` | Word reveal card, MVP card | `BoxShadow(color: Color(0xFFFFD000).withValues(alpha: 0.30), blurRadius: 20, spreadRadius: -4)` |
| `glowPanel` | Cover panel en role reveal | `BoxShadow(color: panelColor.withValues(alpha: 0.50), blurRadius: 32, offset: Offset(0, 12))` — reemplaza la línea actual con alpha 0.35 |

**Regla de uso:** solo el elemento de mayor jerarquía en pantalla recibe glow. No apilar glows en elementos de la misma sección.

---

### 2.4 Escala tipográfica

CONSERVAR Nunito. Agregar pesos faltantes al `pubspec.yaml`.

#### 2.4.1 Fuentes a declarar en `pubspec.yaml`

```yaml
fonts:
  - family: Nunito
    fonts:
      - asset: assets/fonts/Nunito-Regular.ttf        # weight: 400
      - asset: assets/fonts/Nunito-SemiBold.ttf       # weight: 600
      - asset: assets/fonts/Nunito-Bold.ttf           # weight: 700
      - asset: assets/fonts/Nunito-ExtraBold.ttf      # weight: 800
      - asset: assets/fonts/Nunito-Black.ttf          # weight: 900
```

Los archivos están disponibles en Google Fonts (OFL). Descarga los TTF y ubícalos en `assets/fonts/`.

#### 2.4.2 Escala de tamaños (reemplaza ad-hoc)

| Token | px | Peso | Uso típico |
|-------|----|------|-----------|
| `display1` | 42 | 900 | "YEISON" en home, título de victoria |
| `display2` | 36 | 900 | "¡Civiles Ganan!" |
| `heading1` | 28 | 800 | Título de pantalla, "Yeison Impostor online" |
| `heading2` | 22 | 800 | Nombre de jugador en role reveal |
| `heading3` | 18 | 700 | Botón principal, subtítulo de sección |
| `body1` | 16 | 600 | Texto de card, descripción de acción |
| `body2` | 14 | 400 | Subtítulos secundarios, body largo |
| `caption` | 12 | 600 | Badges de rol (CIVIL/IMPOSTOR), labels de categoría |
| `overline` | 11 | 700 | "La Palabra Secreta", etiquetas en mayúsculas con letterSpacing 2 |

---

### 2.5 Escala de radios (reemplaza mezcla actual)

| Token | px | Uso |
|-------|----|-----|
| `r4` | 4 | Chips pequeños, badges de rol inline |
| `r8` | 8 | Progress bar, indicadores pequeños |
| `r12` | 12 | Cards secundarias, snackbars |
| `r16` | 16 | Botones, inputs, cards estándar |
| `r20` | 20 | Cards hero, dialogs |
| `r24` | 24 | Paneles grandes, bottom sheets |
| `rFull` | 999 | Chips pill, avatares, separadores "o" |

Regla: usar solo estos valores. Eliminar 10, 14, 18, 22 que aparecen actualmente.

---

### 2.6 Escala de espaciado (sistema de 4 px)

| Token | px |
|-------|----|
| `sp4` | 4 |
| `sp8` | 8 |
| `sp12` | 12 |
| `sp16` | 16 |
| `sp20` | 20 |
| `sp24` | 24 |
| `sp32` | 32 |
| `sp40` | 40 |
| `sp48` | 48 |

Eliminar: 6, 10, 14, 18, 28 px que aparecen ad-hoc. Redondear al más cercano de la escala.

---

### 2.7 Elevación / profundidad

`useMaterial3: true` tiene elevación semántica vía `surfaceTint`. En el tema oscuro propuesto, se desactiva `surfaceTintColor: Colors.transparent` (ya está en AppBar y Dialog) y se reemplaza por **glow de color** en elementos interactivos, más **variación de capa** en elementos estáticos.

| Nivel | Elemento | Implementación |
|-------|---------|----------------|
| 0 | Scaffold background | `neonBg1` sin sombra |
| 1 | Cards informativas | `neonBg3` + borde `neonMuted` al 15% |
| 2 | Cards interactivas (botones de acción) | `neonBg3` + borde acento al 20% + glow suave |
| 3 | Botón CTA / panel role reveal | glow color completo (ver §2.3) |
| 4 | Dialogs / bottom sheets | `neonBg4` + glow violeta suave al 20% |

---

### 2.8 Tema oscuro actualizado — resumen de cambios en `app_theme.dart`

```dart
// ─── Neon Fiesta Nocturna (dark) — tokens propuestos ───
static const _darkPrimary    = Color(0xFF00E5FF);  // era 0xFF00D1FF — más brillante
static const _darkSecondary  = Color(0xFFFF1A75);  // era 0xFFFF2D7B — más saturado
static const _darkBackground = Color(0xFF08080F);  // era 0xFF0A0A12 — más profundo
static const _darkSurface    = Color(0xFF0F0F1C);  // era 0xFF12121E
static const _darkCard       = Color(0xFF16162A);  // era 0xFF1A1A2E
static const _darkCardElevated = Color(0xFF1E1E36); // NUEVO
static const _darkSuccess    = Color(0xFF00FF87);  // era 0xFF39FF8E — más verde-puro
static const _darkWarning    = Color(0xFFFFD000);  // era 0xFFFFD166 — más saturado
static const _darkError      = Color(0xFFFF3D5A);  // era 0xFFFF6B8A — más intenso
static const _darkViolet     = Color(0xFFBF5FFF);  // NUEVO token
static const _darkTextPrimary   = Color(0xFFF0F0FF); // era 0xFFEAEAFF
static const _darkTextSecondary = Color(0xFF6060A0); // era 0xFF7B7BA0 — más azulado

static const darkPanelColors = [
  Color(0xFF00E5FF), // cyan
  Color(0xFFBF5FFF), // violeta (reemplaza posición 1)
  Color(0xFFFF1A75), // magenta
  Color(0xFFFFD000), // amber — NUEVO (4to panel)
];
```

---

## 3. Iconografía y uso de ilustraciones en clave neón

### 3.1 Iconografía Material

Corto plazo: mantener `Icons.*` Material. Mejoras inmediatas sin cambiar código:
- Reemplazar `Icons.play_arrow_rounded` → `Icons.sports_esports_rounded` en "Juego rápido" (refuerza vibra gamer).
- Reemplazar `Icons.help_outline` → `Icons.quiz_rounded` en "Cómo jugar".
- Agregar `Icons.bolt_rounded` o `Icons.nightlife` como acento decorativo en header de OnlineHome.

Largo plazo (P2): considerar un set de iconos neón SVG custom para los 6-8 iconos más vistos (play, grupos, online, ayuda, impostor, civil). Aislar en `lib/theme/app_icons.dart`.

### 3.2 Ilustraciones existentes

**Problema principal:** fondo blanco en `civil_correct_guess.webp`, `civil_lose_life.webp`, `impostor_correct_guess.webp`, `impostor_failed_guess.webp`, `tie_after_voting.webp`. Player civil/impostor también tienen fondo blanco.

**Solución de corto plazo (sin regenerar assets):**
```dart
// Envolver la imagen en un Container con gradiente oscuro
Container(
  decoration: BoxDecoration(
    gradient: RadialGradient(
      colors: [neonBg3, neonBg1],
      radius: 0.7,
    ),
    borderRadius: BorderRadius.circular(r20),
  ),
  child: Image.asset('assets/images/civil_correct_guess.webp'),
)
```
Esto oculta el blanco con un fondo de tarjeta oscura, creando un "halo de escenario".

**Solución de largo plazo (P1):** regenerar los 7 assets con fondo transparente (PNG) o fondo `#08080F` para que encajen directamente. El estilo cartoon rojo/negro de Yeison ya encaja con la paleta neón — su outline negro y los rojos oscuros crean un contraste bienvenido contra el cyan.

**Uso de glow con ilustraciones:**
En `game_results_screen.dart` (`_buildResultHeader`), el personaje aparece sin contexto visual. Propuesta: agregar un `BoxDecoration` con `neonBg3` y `glowCyan` (civil win) o `glowMagenta` (impostor win) detrás de la imagen, creando un "spotlight" de neón:

```dart
Container(
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    boxShadow: [
      BoxShadow(
        color: (civilsWon ? neonCyan : neonMagenta).withValues(alpha: 0.40),
        blurRadius: 60,
        spreadRadius: 10,
      ),
    ],
  ),
  child: Image.asset(...),
)
```

### 3.3 Logo

`app_logo_no_bg.webp` ya funciona bien en dark. Para reforzar la identidad neón, se puede agregar un `ColorFiltered` o `ShaderMask` con gradiente cyan→violeta sobre el logo en la pantalla home, sin modificar el asset.

---

## 4. Evolución de "Neon Undercover" a identidad primaria

### 4.1 Nombre

**Conservar "Neon Undercover"** como nombre del tema en el código (`isDark ? 'Neon Undercover' : 'Fiesta Sospechosa'`). Es parte de la personalidad del producto.

### 4.2 Modo claro

El modo claro "Fiesta Sospechosa" tiene su propia identidad (crema/índigo) y tiene usuarios que lo prefieren. No se toca en este rebrand — solo se refina "Neon Undercover" y se convierte en la experiencia primaria/por defecto.

Acción: cambiar el valor por defecto de `isDarkModeProvider` a `true` (si no lo es ya), para que los nuevos usuarios aterricen en el modo neón desde el primer launch.

### 4.3 Hoja de ruta de implementación

| Fase | Alcance | Esfuerzo |
|------|---------|---------|
| **Fase A** | Actualizar tokens de color en `app_theme.dart` (§2.2 + §2.8) | Bajo — 1 archivo |
| **Fase B** | Agregar glow a botones CTA y paneles role reveal | Medio — `_buildTheme` + `role_reveal_screen.dart` |
| **Fase C** | Homogeneizar radios a escala r4-r24 | Medio — recorrer todos los screens |
| **Fase D** | Agregar pesos Nunito al pubspec + descargar fuentes | Bajo — 1 archivo + assets |
| **Fase E** | Fix de ilustraciones (container oscuro o regenerar) | Bajo-Medio |
| **Fase F** | Escala tipográfica declarada en `_buildTheme` | Medio |
| **Fase G** | Glow contextual en pantallas de resultado y lobby | Alto |

---

## 5. Hallazgos priorizados — lista consolidada

### P0 — Bloqueantes de identidad neón

1. **Sin glow de color en ningún elemento.** El sistema actual no tiene efectos de luz. Sin glow, el "neón" es solo texto coloreado. Implementar al menos en: botón CTA primario + paneles de role reveal + card de palabra secreta.
   - Archivo: `app_theme.dart:183` (elevatedButton), `role_reveal_screen.dart:201-219` (boxShadow del panel).

2. **Elevation: 0 en botones.** Con `elevation: 0` + fondo plano, los botones se mimetizan con la superficie en dark mode.
   - Archivo: `app_theme.dart:183`.

### P1 — Inconsistencias que debilitan el sistema

3. **Escala de radios sin definir.** 9 valores distintos de borderRadius sin patrón.
   - Archivo: `app_theme.dart:189,219,222,247,257,293`.

4. **Violeta `#A855F7` en panelColors pero no en tokens de uso general.** El tercer acento neón existe pero está desconectado del sistema.
   - Archivo: `app_theme.dart:37`.

5. **OutlinedButton border casi invisible en dark.** `textSecondary` al 22% sobre `#0A0A12` es imperceptible.
   - Archivo: `app_theme.dart:200`.

6. **Capas de fondo sin contraste perceptible.** Surface y Card son indistinguibles en pantalla.
   - Archivo: `app_theme.dart:20-21`.

### P2 — Mejoras de calidad

7. **Solo Nunito-Regular declarado.** Pesos 700-900 son sintéticos.
   - Archivo: `pubspec.yaml:83-86`.

8. **Ilustraciones con fondo blanco.** Rompen la inmersión oscura.
   - Assets: `civil_correct_guess.webp`, `civil_lose_life.webp`, `impostor_correct_guess.webp`, `impostor_failed_guess.webp`, `tie_after_voting.webp`, `player_civil.webp`, `player_impostor.webp`.

9. **Espaciado ad-hoc.** ~14 valores distintos sin escala.
   - Múltiples screens.

10. **Iconografía genérica.** Material Icons sin personalización.
    - `home_screen.dart:134,149,201,223`.

---

## 6. Tokens completos — tabla de referencia para implementación

### Color tokens (dark theme)

```dart
// ── Backgrounds ──
static const neonBg0 = Color(0xFF04040A);
static const neonBg1 = Color(0xFF08080F);   // scaffold
static const neonBg2 = Color(0xFF0F0F1C);   // surface
static const neonBg3 = Color(0xFF16162A);   // card
static const neonBg4 = Color(0xFF1E1E36);   // card elevada / dialog

// ── Acentos neón ──
static const neonCyan    = Color(0xFF00E5FF);  // primary
static const neonMagenta = Color(0xFFFF1A75);  // secondary / impostor
static const neonViolet  = Color(0xFFBF5FFF);  // tertiary / online
static const neonGreen   = Color(0xFF00FF87);  // success / civiles ganan
static const neonAmber   = Color(0xFFFFD000);  // warning / palabra secreta
static const neonRed     = Color(0xFFFF3D5A);  // error / vida perdida

// ── Texto ──
static const neonTextPrimary   = Color(0xFFF0F0FF);
static const neonTextSecondary = Color(0xFF6060A0);

// ── Paneles (role reveal) ──
static const neonPanelColors = [
  Color(0xFF00E5FF),  // cyan
  Color(0xFFBF5FFF),  // violeta
  Color(0xFFFF1A75),  // magenta
  Color(0xFFFFD000),  // amber
];
```

### Glow shadows (helper — agregar como static List<BoxShadow>)

```dart
static List<BoxShadow> glowCyan(double intensity) => [
  BoxShadow(
    color: Color(0xFF00E5FF).withValues(alpha: 0.35 * intensity),
    blurRadius: 24, spreadRadius: -4,
  ),
];
static List<BoxShadow> glowMagenta(double intensity) => [
  BoxShadow(
    color: Color(0xFFFF1A75).withValues(alpha: 0.35 * intensity),
    blurRadius: 20, spreadRadius: -4,
  ),
];
static List<BoxShadow> glowAmber(double intensity) => [
  BoxShadow(
    color: Color(0xFFFFD000).withValues(alpha: 0.30 * intensity),
    blurRadius: 20, spreadRadius: -4,
  ),
];
static List<BoxShadow> glowPanel(Color color) => [
  BoxShadow(
    color: color.withValues(alpha: 0.50),
    blurRadius: 32, offset: Offset(0, 12),
  ),
];
```

### Border radius tokens

```dart
static const r4   = 4.0;
static const r8   = 8.0;
static const r12  = 12.0;
static const r16  = 16.0;
static const r20  = 20.0;
static const r24  = 24.0;
static const rFull = 999.0;
```

### Spacing tokens

```dart
static const sp4  = 4.0;
static const sp8  = 8.0;
static const sp12 = 12.0;
static const sp16 = 16.0;
static const sp20 = 20.0;
static const sp24 = 24.0;
static const sp32 = 32.0;
static const sp40 = 40.0;
static const sp48 = 48.0;
```

---

*Fin del informe. Siguiente paso: Fase A — actualizar tokens de color en `app_theme.dart`.*
