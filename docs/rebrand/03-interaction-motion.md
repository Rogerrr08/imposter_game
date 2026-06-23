# 03 — Interacción & Motion: Auditoría y Lenguaje "Neón Fiesta"

> Rebrand Yeison Impostor — Fase de diseño de interacción  
> Fecha: 2026-06-19  
> Restricción: solo animación/feedback/hápticos — lógica intacta.

---

## 1. Catálogo del motion actual

### Lo que ya existe (puntos de partida)

| Archivo | Mecanismo | Qué hace | Calidad actual |
|---|---|---|---|
| `lib/router/app_router.dart:154–178` | `FadeTransition` + `SlideTransition` (Offset 0.03, 260 ms, `easeOutCubic`) | Transición global entre pantallas | Funcional pero muy sutil. El deslizamiento de 3% es imperceptible en fiesta. |
| `lib/screens/home/home_screen.dart:73–82` | `TweenAnimationBuilder<double>` (520 ms, `easeOutCubic`, fade + translate 24 px abajo→arriba) | Entrada del home: logo + botones suben con fade | Correcto pero suave. Sin carácter festivo. |
| `lib/screens/game_play/role_reveal_screen.dart:25–75` | `AnimationController` (350 ms, `easeOut`) + drag manual | Panel de color se desliza arriba con el dedo para revelar el rol | El mejor momento interactivo del modo local. Sólido. Falta: sin feedback háptico al revelar, sin "pop" al destapar el rol. |
| `lib/screens/game_play/round_start_screen.dart:100–116` | `TweenAnimationBuilder<double>` (2 s, barra lineal) | Barra de progreso antes de empezar la ronda | Completamente plano. No hay aceleración ni énfasis en el nombre del jugador. |
| `lib/screens/game_play/action_reveal_screen.dart:36–53` | `AnimationController` (2.2 s lineal) + barra de progreso | Suspenso antes de mostrar resultado de voto/adivinanza | El porcentaje (`0%→100%`) mata el suspenso. La barra lineal es aburrida. |
| `lib/screens/game_play/action_reveal_screen.dart:397–448` | `AnimatedBuilder` sobre `_autoAdvanceController` (4 s) | Barra que se vacía como timer para avanzar automático | Buena idea. Visualmente plana: sin glow ni color dramático. |
| `lib/features/online/presentation/widgets/role_reveal_phase.dart:35–112` | Secuencia de 3 s con 5 fases: shimmer → scale (`elasticOut`) → glow → slide text → fade card | Revelar rol online con drama | El mejor bloque de motion de la app. `elasticOut` ya es juicioso. Falta: háptico en el momento `iconScale` llega a 1.0. |
| `lib/features/online/presentation/widgets/role_reveal_phase.dart:468–527` (`_PulsingDots`) | `sin(t * π)` escala/opacidad en 3 puntos desfasados 0.2 | "Esperando a los demás" | Bonito pero pequeño. No roba foco suficiente en modo fiesta. |
| `lib/features/online/presentation/widgets/reveal_countdown.dart:37–65` | `TweenSequence` (0.5→1.25→1.0 en 500 ms) + pulso de opacidad en título | Cuenta regresiva 3-2-1 con número grande y glow radial | Tiene potencial. El glow radial (alpha 0.20/0.05) es muy tímido. Los puntos indicadores son estáticos. |
| `lib/features/online/presentation/widgets/impostor_result_hold.dart:83–93` | `AnimationController` linear depleting sobre `LinearProgressIndicator` | Barra de tiempo mientras se muestra resultado impostor | Sin dramatismo. La imagen central no tiene ninguna animación. |
| `lib/features/online/presentation/widgets/impostor_choice_phase.dart:225–232` | `Transform.scale` con pulso ±8% (`repeat reverse`, 1.2 s) | Imagen impostor pulsando mientras decide | Correcto pero insignificante (8%). Para modo fiesta el pulso debería ser de glow, no solo escala. |
| `lib/features/online/presentation/widgets/vote_result_phase.dart:196–215` | `AnimatedBuilder` → `LinearProgressIndicator` depletando (3 s) | Barra de tiempo tras resolución de votos | Igual que `impostor_result_hold`: funcional, sin drama. |
| `lib/features/online/presentation/widgets/connection_status_banner.dart:49–58` | `FadeTransition` opacity 0.3→1.0 en punto amarillo | Indicador "Reconectando..." | Correcto para su propósito. |
| `lib/screens/game_setup/widgets/shake_widget.dart` | `repeat(reverse:true)`, rotate ±0.02 rad, 80 ms | Agitar icono en setup | Útil como micro-feedback pero muy pequeño para fiesta. |

### Lo que NO existe hoy (gaps críticos)

1. **Cero hápticos** — `HapticFeedback` no aparece en ningún archivo de `lib/`.
2. **Sin animación de entrada en results** (`game_results_screen.dart` es un `ConsumerWidget` estático).
3. **Sin efecto al completar el drag** en `role_reveal_screen.dart` — el rol aparece estáticamente al soltar.
4. **Sin transición temática** entre pantallas clímax (reveal → play, vote → action_reveal).
5. **Sin partículas, confetti ni efectos de victoria/derrota** en resultados.
6. **Sin glow en botones** — todos usan `elevation: 0` o 6 simple, sin blur neón.
7. **El modo lobby online** (`room_lobby_screen.dart`) — sin motion mientras se espera.
8. **`action_reveal_screen.dart` vista resultado** — imagen del personaje aparece sin animación (sin scale-in, sin fade).

---

## 2. Lenguaje de Motion "Neón Fiesta"

### 2.1 Tokens de motion (definir en `AppTheme`)

```dart
// Duraciones
static const Duration motionInstant   = Duration(milliseconds: 80);   // micro-feedback
static const Duration motionFast      = Duration(milliseconds: 200);   // botones, hovers
static const Duration motionStandard  = Duration(milliseconds: 350);   // transiciones UI normales
static const Duration motionDramatic  = Duration(milliseconds: 600);   // reveals, entradas clímax
static const Duration motionSuspense  = Duration(milliseconds: 1800);  // cuenta atrás, suspenso

// Curvas
static const Curve curveSnap       = Curves.easeOutBack;       // botones press: rebote corto
static const Curve curveRevel      = Curves.elasticOut;        // scale-in clímax
static const Curve curveSmooth     = Curves.easeOutCubic;      // transiciones de pantalla
static const Curve curveTension    = Curves.easeInCubic;       // carga de suspenso (aceleración)

// Glow (oscuro)  — valores de blurRadius para BoxShadow sobre color de acento
static const double glowTight  = 12.0;   // botón en reposo con borde neón
static const double glowMedium = 28.0;   // botón pressed / elemento activo
static const double glowBlast  = 60.0;   // clímax (reveal, victoria)
```

### 2.2 Transiciones entre pantallas

| Ruta origen → destino | Propuesta neón fiesta |
|---|---|
| Cualquier → cualquier (ruta normal) | Mantener fade+slide actual pero aumentar slide a `Offset(0.06, 0)` y duración a 300 ms. |
| `role_reveal` → `round_start` | **Scale + fade**: nueva pantalla hace `scale 0.92→1.0` con `elasticOut` 500 ms. Comunica "el juego empieza YA". |
| `action_reveal` → `results` | **Slide vertical hacia arriba** (Offset 0, -0.08 → 0) con fade. Sensación de ascender al podio. |
| Cualquier → `role_reveal` (local) | `SlideTransition` desde abajo (`Offset(0, 0.12) → 0`) para que el panel de color "suba" naturalmente. |

### 2.3 Feedback de botones (press / glow)

Todos los `ElevatedButton` primarios deben usar `InkWell` + `GestureDetector` o `AnimatedScale` para:

1. **Press scale**: `0.96` en `onTapDown`, vuelta a `1.0` con `easeOutBack` 200 ms.
2. **Glow en reposo** (modo oscuro): `BoxDecoration` con `boxShadow` usando color primario, `blurRadius: glowTight`, alpha 0.45.
3. **Glow pressed**: `blurRadius: glowMedium`, alpha 0.7 durante 80 ms, vuelve a tight.
4. **Botón desactivado**: sin glow, sin escala, color reducido (ya existe).

Implementación sugerida: un `NeonButton` widget wrapper reutilizable, ~60 líneas.

### 2.4 Momentos clímax — especificación por escena

#### A. Revelar Rol (LOCAL) — `role_reveal_screen.dart`

- **Drag → umbral -40 px**: `HapticFeedback.mediumImpact()` en ese instante exacto (hoy: cero feedback).
- **Al completar drag** (panel libre del campo visual): `HapticFeedback.heavyImpact()` + la imagen del rol (civil/impostor) hace **scale 0→1.15→1.0** con `elasticOut` 500 ms.
- **Texto del rol** ("CIVIL" / "IMPOSTOR"): aparece con `Opacity 0→1` + ligero `shimmer` de 300 ms en el color del rol.
- **Impostor**: añadir glow `blurRadius: glowBlast` en color `secondaryColor` detrás de la imagen, que se desvanece en 800 ms.

#### B. Revelar Rol (ONLINE) — `role_reveal_phase.dart`

Ya tiene la secuencia más completa. Mejoras:
- Cuando `_iconScale` alcanza 1.0 (intervalo `[0.35, 0.6]`, ~1050 ms): `HapticFeedback.heavyImpact()`.
- **Si es impostor**: en el momento del glow pico (`_iconGlow` = 0.7), añadir un segundo `BoxShadow` de color `secondaryColor` con `blurRadius: glowBlast` (hoy el glow existe pero es moderado — 24/48 blur — ampliar a 48/80).
- Shimmer de texto ya está bien — solo ampliar la velocidad de 1500 ms a 900 ms para que sea más enérgico.

#### C. Cuenta Regresiva (ONLINE) — `reveal_countdown.dart`

- Cada cambio de número (`_current--`): `HapticFeedback.lightImpact()`.
- Último número (1): `HapticFeedback.heavyImpact()`.
- El glow radial (hoy alpha 0.20) → subir a **0.45** interior, **0.15** medio en modo oscuro.
- Los dots indicadores: cuando se iluminan, hacer `scale 1.0→1.5→1.0` con `elasticOut` 400 ms (hoy son estáticos).
- Fondo: en `_current == 1` cambiar `backgroundColor` con `AnimatedContainer` a un tinte del color de acento (alpha 0.08) — tensión visual.

#### D. Suspenso antes de resultado (LOCAL) — `action_reveal_screen.dart`

- Reemplazar la barra lineal de 2.2 s + porcentaje por una **animación de 3 puntos pulsantes** más dramática (similar a `_PulsingDots` pero con color primary y más grandes: 16 px, glow).
- El texto "Revelando resultado..." debería hacer shimmer (reutilizar `_buildShimmerText` de `role_reveal_phase.dart`).
- Quitar el porcentaje (`_controller.value * 100`) — rompe la ilusión de suspenso.

#### E. Resultado de Acción — `action_reveal_screen.dart` (`_buildResultView`)

- La imagen del resultado (civil_correct_guess, etc.) hoy aparece sin animación: añadir **scale 0→1.1→1.0** con `elasticOut` 550 ms + `HapticFeedback.heavyImpact()` al mostrarse.
- Si es victoria de civiles: añadir **confetti** simple (paquete `confetti` ~2 KB) o partículas CSS-style con `CustomPainter` (≤50 líneas).
- El título del resultado ("¡Era impostor!") hace `scale 1.2→1.0` con `easeOutBack` 300 ms — "stamp" effect.

#### F. Impostor decidiendo — `impostor_choice_phase.dart` (vista de espera)

- El pulso actual (±8%) es muy tímido. Propuesta: mantener escala pero añadir **glow pulsante** en `BoxDecoration` sobre la imagen con `color: secondaryColor`, `blurRadius` oscilando entre 0 y 32.
- `_pulseController` (1.2 s) es correcto; solo mover el efecto a glow en lugar de escala.

#### G. Resultado de Votación — `vote_result_phase.dart`

- La tarjeta de resolución (`_buildResolutionCard`) aparece estáticamente. Animarla: **slide desde abajo** (Offset(0, 0.15) → 0) + fade, 400 ms, `easeOutCubic`.
- Si es "¡Era Impostor!": `HapticFeedback.heavyImpact()` al mostrarse la tarjeta.
- Si es "Era Civil": `HapticFeedback.mediumImpact()` + `vibrate` doble (200 ms pausa 100 ms 200 ms) — indica error.
- Las barras de voto individuales (`_buildVotesBreakdown`) deben animarse: `width 0 → fracción` con `TweenAnimationBuilder` a 600 ms staggered por índice (+80 ms por item).

#### H. Victoria / Derrota — `game_results_screen.dart`

Actualmente es completamente estático (sin ningún `AnimationController`). Es el momento de mayor impacto emocional y tiene cero juice.

- Al entrar en la pantalla: `staggered entrance` — cada sección (`_buildResultHeader`, `_buildSpotlightSection`, podio) entra con fade + slide en cascada (0 ms, 120 ms, 240 ms, 360 ms).
- Si civiles ganan: **confetti** + `HapticFeedback.heavyImpact()` al cargar.
- Si impostor gana: flash de fondo `secondaryColor` alpha 0.12 que se desvanece en 800 ms + `HapticFeedback.vibrate()`.
- Puntos del jugador: contador animado (número sube de 0 al valor final en 800 ms, `easeOutCubic`).

#### I. Lobby de espera (ONLINE) — `room_lobby_screen.dart`

- Los avatares de jugadores que se unen deben entrar con **scale 0→1** + `elasticOut` 400 ms (entrada en sala = "¡llegó alguien!").
- Añadir `HapticFeedback.lightImpact()` cada vez que un jugador nuevo aparece en la lista (comparar count anterior vs nuevo).

### 2.5 Estados de espera (Lobby / "Esperando a los demás")

- `_PulsingDots` ya es correcto para espera pasiva. Para el rebrand: aumentar dots de 10 px a 14 px, añadir `boxShadow` de glow en el color de acento.
- `CircularProgressIndicator` (varios usos) → reemplazar con versión custom: aro de neón con `color: primaryColor`, `strokeWidth: 3`, envuelto en `BoxDecoration` circular con `boxShadow glowTight`.
- "Contando votos..." (`vote_result_phase.dart:169`) → reemplazar `CircularProgressIndicator` básico por los `_PulsingDots` + texto shimmer.

### 2.6 Hápticos — mapa completo

> Hoy: 0 usos de `HapticFeedback` en toda la app.

```
Evento                          | Patrón háptico
────────────────────────────────|──────────────────────────────────
Drag umbral -40 px (reveal)     | mediumImpact
Rol revelado (drag o animate)   | heavyImpact
Número de cuenta atrás cambia   | lightImpact
Último número (1)               | heavyImpact
Resultado de acción: victoria   | heavyImpact
Resultado de acción: derrota    | selectionClick + pausa + selectionClick
Era Impostor (result card)      | heavyImpact
Era Civil eliminado             | mediumImpact × 2 (200 ms intervalo)
Victoria de civiles (results)   | heavyImpact
Victoria impostor               | vibrate()
Jugador nuevo en lobby          | lightImpact
Botón primario press            | selectionClick
Botón destructivo (eliminar)    | mediumImpact
Error de validación (shake)     | mediumImpact (ya hay ShakeWidget, sumar háptico)
```

---

## 3. Priorización — Dónde el "juice" da más retorno con menos esfuerzo

### P0 — Máximo impacto, mínimo código (≤1 hora cada uno)

| # | Qué | Archivo(s) | Implementación |
|---|---|---|---|
| P0-1 | **Háptico en drag de reveal local** | `role_reveal_screen.dart:59` | 1 línea: `HapticFeedback.mediumImpact()` en el if `_hasRevealed`. |
| P0-2 | **Háptico en reveal online** | `role_reveal_phase.dart` — cuando `_iconScale` llega a 1 | Listener en `_sequenceController` a valor ~0.6: `HapticFeedback.heavyImpact()`. |
| P0-3 | **Háptico en cuenta atrás** | `reveal_countdown.dart:56–64` | En el `Timer.periodic` callback antes del `setState`: `HapticFeedback.lightImpact()` + heavy en 1. |
| P0-4 | **Scale-in en imagen de resultado** | `action_reveal_screen.dart:193–218` | Envolver imagen en `TweenAnimationBuilder<double>(0→1, 550ms, elasticOut)` + `Transform.scale`. |
| P0-5 | **Glow en botón primario** (solo modo oscuro) | `app_theme.dart:180–196` | Añadir `shadowColor` y `elevation: 8` al `ElevatedButtonTheme` oscuro — Flutter en M3 usa `shadowColor` para el halo. |
| P0-6 | **Háptico en result card (voting)** | `vote_result_phase.dart:\_buildResolutionCard` | Al construirse si `isImpostor`: `HapticFeedback.heavyImpact()` en `initState` con delay 400 ms (cuando la card sería visible). |

### P1 — Alto impacto, esfuerzo medio (≤3 horas cada uno)

| # | Qué | Archivo(s) | Implementación |
|---|---|---|---|
| P1-1 | **Staggered entrance en game_results** | `game_results_screen.dart` | Convertir a `StatefulWidget`, añadir `AnimationController` staggered, `FadeTransition` + `SlideTransition` por sección. |
| P1-2 | **Barras de voto animadas** | `action_reveal_screen.dart:\_buildVoteTallies` | `TweenAnimationBuilder` por fila con delay `i * 80 ms`. |
| P1-3 | **Glow pulsante en impostor choice** | `impostor_choice_phase.dart:225–232` | Cambiar el `Transform.scale` por `BoxDecoration` animado con `blurRadius` oscilante. |
| P1-4 | **Suspenso action reveal rediseñado** | `action_reveal_screen.dart:\_buildLoadingView` | Reemplazar barra + porcentaje por `_PulsingDots` grande (20 px, glow) + texto shimmer reutilizado. |
| P1-5 | **Entrada de avatares en lobby** | `room_lobby_screen.dart` (players list) | `AnimatedList` o `TweenAnimationBuilder` con `elasticOut` por cada nuevo item + `HapticFeedback.lightImpact()`. |
| P1-6 | **Transición clímax role→round-start** | `app_router.dart` + `round_start_screen.dart` | Cambiar `_buildPage` a función que acepte transición custom; ruta `/round-start` usa scale + fade. |

### P2 — Pulido fiesta, esfuerzo mayor (≥4 horas)

| # | Qué | Implementación |
|---|---|---|
| P2-1 | **Confetti en victoria** | Paquete `confetti` ó `CustomPainter` 50 líneas. Lanzar en `game_results_screen` y `vote_result_phase` cuando `isGameOver && winner == 'civils'`. |
| P2-2 | **NeonButton widget** | Wrapper reutilizable con press scale + glow animado. Reemplaza todos los `ElevatedButton` primarios. |
| P2-3 | **Flash de fondo en victory/defeat** | `AnimatedContainer` en el `Scaffold` de results que va de color de victoria/derrota alpha 0 → 0.12 → 0 en 800 ms. |
| P2-4 | **Contador de puntos animado** | En `_buildPointsSummary` de results: número sube 0 → valor real con `TweenAnimationBuilder<int>` 800 ms `easeOutCubic`. |
| P2-5 | **Shimmer en texto "la palabra es"** | Reutilizar `_buildShimmerText` de `role_reveal_phase.dart` en la tarjeta de palabra del reveal local. |
| P2-6 | **Glow radial en countdown reforzado** | `reveal_countdown.dart`: subir alpha interior a 0.45, dots con scale-in al iluminarse. |

---

## Notas de implementación

- **Hápticos en iOS/Android**: `HapticFeedback` de `package:flutter/services.dart` — sin dependencias extra. En web/desktop son no-ops silenciosos.
- **Curva `elasticOut`**: ya usada en `role_reveal_phase.dart:70` — es la curva definitoria del estilo "fiesta". Estandarizarla en todos los reveals.
- **`_PulsingDots`** en `role_reveal_phase.dart:468` es reutilizable — extraerla a `lib/widgets/pulsing_dots.dart`.
- **Glow en botones M3**: en `ThemeData(useMaterial3: true)`, el `ElevatedButton` solo muestra shadow si `elevation > 0` Y se pasa `shadowColor`. Hoy `elevation: 0` elimina todo halo. En modo oscuro elevar a `elevation: 4` con `shadowColor: primaryColor.withOpacity(0.5)`.
- **No tocar** `ShakeWidget` — ya cumple su función. Solo añadir el háptico correspondiente en quien lo usa.
