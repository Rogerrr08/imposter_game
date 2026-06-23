# Yeison Impostor — Release v3.0.0

> **Fecha:** 2026-06-22
> **Build:** `3.0.0+7`
> **Compatibilidad:** Android, iOS, Web

La versión **3.0.0** es un **rebrand visual completo**: el app pasa de "funciona
bien" a sentirse un producto de fiesta. Estilo neón nocturno (modo oscuro por
defecto), un sistema visual consistente, pantallas clave rediseñadas, y "juice"
(hápticos, animaciones, suspenso) en los momentos importantes — **sin tocar la
lógica del juego**. Esta release también incluye las mejoras de palabras y de
confiabilidad online que venían cocinándose desde la 2.2.0.

---

## 🎨 Rebrand visual (lo principal)

### Identidad neón
- **Paleta "Neón Undercover"** con glow de color real (cyan/magenta/violeta/
  ámbar): sombras de color, profundidad y capas de fondo bien diferenciadas.
- **Modo oscuro por defecto** para usuarios nuevos. El modo claro "Fiesta
  Sospechosa" sigue disponible.
- **Sistema visual consistente**: una sola escala de radios, espaciado de 4px,
  escala tipográfica y pesos de fuente Nunito reales (SemiBold→Black).

### Pantallas rediseñadas
- **Home** con *spotlight* neón detrás del logo y jerarquía de botones clara.
- **Votación (Express)**: se elige tocando **chips** de jugadores, ya no se
  escribe el nombre.
- **Resultados unificados** local ↔ online: mismo hero de ganador, misma card de
  palabra secreta y mismas filas de ranking con medallas oro/plata/bronce.
  Botón **"Ver ranking"** para saltar al ranking del grupo.
- **Cómo jugar**: de 8 a **3 páginas** (Qué es / Cómo se juega / Puntos), con
  *spotlight* detrás del logo.
- **Revelar rol**: ilustración enmarcada con glow y la palabra secreta en la
  card compartida.
- **Jugar en línea**: carga "transparente" con *skeleton* (silueta del lobby) en
  vez de una sucesión de spinners.

### Navegación más simple
- Nueva pantalla de **Ajustes** (tema, cómo jugar, versión).
- Se eliminaron 3 pantallas de transición muertas (RoundStart, CreateRoom,
  ClassicImpostorChoice → ahora acciones directas / bottom sheet). 20 → 16 rutas.

### Motion, juice y tono de fiesta
- **Hápticos** al revelar el rol, al votar y en el clímax del resultado.
- **Entrada animada** y golpe de **celebración** al llegar a los resultados.
- **Suspenso del action-reveal sin "%"**: el ojo crece y brilla, sin barra de
  porcentaje.
- **Copy de fiesta**: "¡Otra ronda!" y corrección de tildes/signos en votación y
  lobby.

---

## 🃏 Palabras y pistas

- **Anti-repetición de palabras** (local y online): no se repite una palabra
  hasta haber pasado por un buen tramo de la categoría (shuffle-bag con
  soft-decay, estilo "no me repitas la misma canción").
- **Pistas recalibradas**: más difíciles, ambiguas y en **español neutro
  latinoamericano** (sin regionalismos). Una pista ayuda a reconocer la palabra
  sin regalarla, y todas tienen un nivel parejo de dificultad.

---

## 🎮 Cambio de juego — Express local

- **Las vidas dejan de mostrarse durante la votación y el reveal.** El contador
  filtraba el rol del eliminado (si las vidas no bajaban, era impostor; si
  bajaban, era civil). **La mecánica no cambia**: las vidas se siguen contando y
  los civiles pierden si se agotan.

---

## 🌐 Modo online — Confiabilidad

- **Resincronización de los canales realtime al volver del segundo plano**, para
  evitar quedar con estado viejo tras minimizar el app.
- Limpieza de invalidaciones redundantes de providers online.
- Correcciones de ortografía en lobby y fases online.

---

## 🧱 Bajo el capó (sin impacto visual)

- **Kit de componentes compartido** en `lib/widgets/`: `AppBadge`,
  `FullWidthButton`, `ResultHero`, `SecretWordCard`, `PlayerRow`,
  `NeonSpotlight`, `SkeletonBox`, `AppEmptyState`. Mata duplicación entre local
  y online.
- **Batería de regresión visual** (9 *golden tests*) para detectar cambios
  visuales no intencionales: home/settings/cómo-jugar en oscuro y claro,
  galería del kit, componentes de resultado y estado vacío.
- Baseline de `flutter analyze` reducido (se eliminaron imports muertos).

---

## 📦 Información del paquete

- **Android (`yeison-impostor-v3.0.0-release.apk`):** instalación directa.
- **versionCode:** 7
- **versionName:** 3.0.0
- **Web:** se despliega solo en push a `main` (GitHub Pages).

---

## ⚠️ Notas de upgrade

- **No hay migración de datos en cliente**: la BD local de Drift mantiene el
  mismo schema; los grupos, rankings e historial se conservan.
- El rebrand es **solo de presentación**: el motor del juego (fases, puntajes,
  anti-repetición, canales online) no cambió, así que las partidas y los
  puntajes funcionan igual.

---

## 🙏 Créditos
Rebrand visual y release asistidos con Claude Code.
