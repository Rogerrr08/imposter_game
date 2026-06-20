# Plan maestro de rebrand — Yeison Impostor

> Consolidación de las 5 evaluaciones expertas (`docs/rebrand/01..05`).
> Dirección fijada por el dueño: **neón fiesta nocturna · rediseño profundo ·
> conservar nombre "Yeison Impostor" + logos**. Branch: `feature/visual-rebrand`.
> **Restricción dura:** NO se toca la lógica del juego (Riverpod/Drift/Supabase/
> fases/puntajes/anti-repetición). Solo presentación, IA, flujos y sistema visual.

## Norte (qué estamos persiguiendo)
App de **fiesta** que se sienta producto, no improvisada. Principios Jackbox:
el objetivo es que el grupo se ría · fricción casi cero · estilo visual
distintivo y **consistente**. Hoy la app "funciona como app pero falla como
experiencia de fiesta" (informe 05): le falta luz (neón sin glow), consistencia
(14 radios distintos), y momentos con "jugo".

## Diagnóstico convergente (lo que los 5 coinciden)
1. **El "neón" no tiene luz.** Cero `boxShadow` de color, `elevation: 0`, capas
   de fondo indistinguibles. Es texto de colores, no un night-club. *(01)*
2. **Se ve "vibe coded" por inconsistencia.** 160 `BorderRadius` con 14 valores,
   22 tamaños de fuente, 30 opacidades, badges copiados 5×, pantalla de ganador
   distinta en local vs online. *(04)*
3. **Demasiada fricción para jugar.** 8 pasos a la primera ronda; pantallas de
   transición muertas (RoundStart, CreateRoom); falta pantalla de Ajustes
   (el toggle de tema vive suelto). *(02, 05)*
4. **Los momentos clímax están planos.** Reveal de rol sin animación, resultados
   estáticos, cero hápticos en toda la app, suspenso roto por un "23%". *(03, 05)*
5. **Copy de "wizard", no de fiesta** + errores de ortografía en votación/lobby,
   y los hints (lo más gracioso) enterrados al fondo de resultados. *(05)*

## Roadmap por olas (cada ola es revisable y se re-renderiza con el harness)

### Ola 0 — Fundación visual (design system)  ·  riesgo bajo · impacto máximo
Reescribe los tokens en `app_theme.dart`: paleta neón (5 capas de fondo + 6
acentos), **glow de color** (cyan/magenta/violeta/ámbar), escala de radios
(r4–r24 + rFull), espaciado de 4px, escala tipográfica, `elevation`/profundidad,
default a modo oscuro. → *Esto solo flipea ~80% del vibe (informe 01).* Fuente: **01**.

### Ola 1 — Kit de componentes compartido (`lib/widgets/`)  ·  riesgo bajo-medio
Extraer los componentes que hoy están duplicados/divergentes: `AppCard`,
`AppBadge`, `ActionCard`, `AppEmptyState`, `PlayerRow` (P0); `ResultHero`,
`SecretWordCard`, `ConfirmDialog`, `FullWidthButton`, `NeonButton` (P1). Unifica
local↔online y mata la causa raíz del "vibe coded". Fuente: **04**.

### Ola 2 — Reestructuración de IA / navegación (profunda)  ·  riesgo medio
- **Crear `/settings`** (hogar del tema + reglas/puntos + perfil online).
- **Eliminar** `RoundStartScreen` (→ banner en GamePlay), `CreateRoomScreen`
  (→ acción directa desde OnlineHome), `ClassicImpostorChoiceScreen` (→ bottom
  sheet en ActionReveal).
- **OnlineHome** con carga transparente (skeleton) en vez de 5 spinners.
- Renombrar DisplayName → `/online/perfil`. 20 rutas → 16. Fuente: **02**.

### Ola 3 — Rediseño de pantallas clave (con tokens + kit)  ·  riesgo medio
Home, **VoteScreen → chips visuales** (no escribir nombres), GameResults
(+ "Ver ranking", hints arriba), OnlineHome, role reveal, how-to-play (8→3
páginas), "spotlight" neón detrás de las ilustraciones. Fuentes: **01, 02, 04, 05**.

Progreso:
- **[HECHO] 3a — VoteScreen Express con chips tocables** (antes campo de texto).
  Nuevo `_PlayerChip`. La lógica de voto no cambió.
- **[HECHO] 3b — Resultados local↔online unificados.** Componentes compartidos
  `ResultHero` / `SecretWordCard` / `PlayerRow` en `lib/widgets/`; cableados en
  `game_results_screen` (local) y `match_results_phase` (online). Golden de
  preview `result_components_dark`.
- **[HECHO] 3c — how-to-play 8→3 páginas + spotlight neón.** Onboarding corto
  (Qué es / Cómo se juega / Puntos). Nuevo `NeonSpotlight` (lib/widgets/) detrás
  del logo. Tablas de puntaje detalladas por modo se quitaron (van al jugar; a
  futuro podrían vivir en una sección "Reglas" de Ajustes — informe 02).
- **[HECHO] 3d — Home con spotlight neón** detrás del logo (NeonSpotlight),
  ajuste de tamaño/espaciado. CTA "Juego rápido" primario con glow.
- **[HECHO] 3e — role reveal payoff.** Ilustración del rol enmarcada + glow;
  civil reusa `SecretWordCard`; pista de impostor en `_buildImpostorHintCard`.
  La mecánica de deslizar-para-revelar no se tocó.
- **[HECHO] 3f — OnlineHome carga transparente (skeleton).** Nuevo `SkeletonBox`
  reemplaza los 5+ spinners del flujo auth→perfil→sala; glow neón en hero + CTA.
- **[HECHO] 3g — botón "Ver ranking"** en GameResults local (push a /rankings,
  solo si la partida es de un grupo).

**Ola 3 COMPLETA.** Componentes nuevos en `lib/widgets/`: `ResultHero`,
`SecretWordCard`, `PlayerRow`, `NeonSpotlight`, `SkeletonBox` (+ `AppBadge`,
`FullWidthButton` de Ola 1).

### Ola 4 — Motion, juice y tono de fiesta  ·  riesgo bajo-medio
Tokens de motion (4 duraciones, 4 curvas, 3 glows), **hápticos** en reveal/
countdown/votación/resultado, animación de entrada en resultados, suspenso de
action-reveal sin "%", celebración de victoria, y **copy de fiesta** (¡Otra
ronda!, ¡Revancha!) + fix de ortografía. Fuentes: **03, 05**.

Progreso:
- **[HECHO] 4a — hápticos** en role reveal (umbral), votación (chip) y
  action-reveal (clímax). `HapticFeedback`.
- **[HECHO] 4b — copy de fiesta + ortografía.** "Jugar de nuevo"/"Volver a
  jugar" → "¡Otra ronda!"; tildes/signos en votación y lobby online.
- Pendiente: animación de entrada en resultados + celebración de victoria,
  suspenso de action-reveal sin "%".

### Ola 5 — Pulido  ·  riesgo bajo
Iconografía con más carácter, regenerar/recortar ilustraciones con fondo
transparente, casos borde, y batería de capturas de regresión visual.

## Decisiones (resueltas por el dueño, 2026-06-19)
- **Pesos de fuente Nunito → el dueño agrega los TTF.** Descargará
  SemiBold(600)/Bold(700)/ExtraBold(800)/Black(900) de Google Fonts (OFL) a
  `assets/fonts/`. Yo los cableo en `pubspec.yaml` cuando estén.
- **Ilustraciones con fondo blanco → enmarcar en card oscura + glow** (sin tocar
  assets). Regeneración con fondo transparente queda para más adelante (opcional).
- **Default a modo oscuro:** nuevos usuarios aterrizan en neón. (Recomendado, a
  confirmar al implementar.)
- **Modo claro "Fiesta Sospechosa":** no se toca (alternativa secundaria).
- **Arranque:** el dueño revisa el plan + informes antes de iniciar la Ola 0.

## Pedidos extra (durante el rebrand)

- **[HECHO] Ocultar las vidas en Express LOCAL** (sin cambiar la mecánica). El
  contador de vidas se mostraba y **filtraba información**: tras un voto, si las
  vidas NO bajaban, los civiles deducían que el eliminado era impostor (adivinó
  mal); si bajaban, era civil. Eso les daba una pista que no deberían tener.
  - **Decisión:** votación y reveal eran los **únicos** momentos donde se veían
    las vidas → se ocultan ahí (no hizo falta esconderlas "por completo").
  - **Qué se hizo:** se quitaron los corazones en `vote_screen.dart`
    (`_buildStepView`, Express) y en `action_reveal_screen.dart` (reveal de
    voto), y se eliminó el sufijo "N vidas restantes" del subtítulo del reveal.
  - **Qué NO cambió:** la mecánica intacta — las vidas se cuentan internamente
    y los civiles **pierden si se agotan**. El modo clásico no se tocó (no usa
    vidas).

## Lo que NO se toca
`gameProvider`/`game_provider.dart`, canales online (Supabase), máquina de
fases, cálculo de puntos, `word_bank.dart`/anti-repetición. Las fases del juego
siguen existiendo; solo cambia cómo se presentan/agrupan.
