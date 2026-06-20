# Yeison Impostor — Party-Game UX Audit
## Evaluación de experiencia para el rebrand "Neón Fiesta Nocturna"

**Fecha:** 2026-06-19  
**Versión evaluada:** feature/online-reliability  
**Alcance:** LOCAL (`lib/screens/`) + ONLINE (`lib/features/online/presentation/`)  
**Marco:** The Jack Principles — el objetivo es que el grupo se ría, no ganar.  
**RESTRICCIÓN:** No se tocan reglas ni mecánicas. Solo presentación, ritmo percibido, copy y "juice".

---

## 1. FRICCIÓN PARA EMPEZAR A JUGAR

### Diagnóstico (hoy)

**Flujo LOCAL — pasos para la primera ronda:**

1. Abrir app → pantalla de inicio (520 ms de fade-in OK)
2. "Juego rápido" → spinner de 400 ms (inicialización Supabase lazy)
3. Setup screen → añadir jugadores **uno a uno** con teclado
4. Elegir categorías, modo, impostores, pistas, timer
5. Botón "Iniciar" → spinner 400 ms + inicio de juego
6. Role reveal — N pantallas (una por jugador)

**Total: mínimo 6 pasos antes de la primera carta. En un grupo de 6 personas son ~8 taps + escribir 6 nombres.**

**Flujo ONLINE — pasos adicionales:**

1. "Jugar en línea" → spinner + autenticación anónima (puede tardar 2-4 s en frío)
2. Pantalla Online Home → "Crear sala" o "Entrar con código"
3. Lobby: esperar a todos, marcar "Listo", host inicia
4. Match screen → role reveal

**Hallazgos críticos:**

- `game_setup_screen.dart:803-840` — La carga de jugadores es siempre manual en modo rápido; no hay botón "Juego en 1 tap" con el último preset activo.
- `home_screen.dart:267` — El spinner de 400 ms en "Juego rápido" es puro delay cosmético; se nota artificial en un contexto de fiesta donde todos están esperando.
- `how_to_play_screen.dart:16` — El onboarding tiene **8 páginas**. En la realidad de una fiesta nadie toca "¿Cómo jugar?" hasta que ya está jugando y no entiende algo.
- `online_home_screen.dart:141-211` — El flujo online encadena hasta **4 estados de carga** secuenciales (auth → profile → active-room check → content). Invisible al dev, fatal en fiesta.

### Recomendaciones

**P0 — Botón "Repetir partida" prominente en home:**  
Cuando exista un preset guardado reciente, mostrar un chip secundario en `home_screen.dart` debajo de "Juego rápido": "Repetir con [nombres]". Un tap, un spinner, ya. Costo cero de implementación —`lastQuickGamePresetProvider` ya existe.

**P0 — Reducer de setup para grupos frecuentes:**  
En modo grupo (que ya guarda preset con `lastGroupGamePresetsProvider`), que "Iniciar" en `group_detail_screen.dart` navegue directo a role reveal con la config anterior, sin pasar por setup completo. Añadir un "Editar" secundario para cambiar algo.

**P1 — Eliminar spinner cosmético de 400 ms en flujo local:**  
`home_screen.dart:266-270` — El delay es solo para Supabase lazy en rutas `/online`. Para `/setup` el `Future.delayed(400)` es puro latencia percibida sin beneficio. Quitarlo o reducirlo a 150 ms max.

**P1 — Colapsar los estados de carga online en uno solo:**  
`online_home_screen.dart:119-210` — Los 4 estados de carga waterfall son invisibles pero agregan 1-3 segundos. Unificar en un `FutureProvider` combinado que ejecute auth + perfil + active-room en paralelo y muestre un único spinner con mensaje "Conectando..."

**P2 — Onboarding de 8 páginas → resumen de 1 pantalla (cartel de fiesta):**  
`how_to_play_screen.dart:73-83` — En un contexto de fiesta el tutorial se lee antes de la primera partida, nunca después. Reducir a 1 pantalla tipo "cartel de instrucciones de bar": ícono grande + 3 reglas en negrita + botón "¡Empezar ya!". Las reglas de puntuación pueden quedar en una sección colapsable "Más detalles".

---

## 2. ENERGÍA SOCIAL

### Diagnóstico (hoy)

**Lobby LOCAL (Setup Screen):** Es un formulario de configuración. No hay nada que emocionalmente "caliente" al grupo antes de jugar. El color de fondo en modo oscuro (`#0A0A12`) con los neones ya existe pero está sub-explotado: los controles de setup son neutrales, no festivos.

**Lobby ONLINE (`room_lobby_screen.dart`):**  
- `room_lobby_screen.dart:62-78` — El AppBar dice "Lobby privado" + ícono de logout. Tono de reunión corporativa, no de fiesta.
- `room_lobby_screen.dart:190-280` — El "Ready card" es un contenedor informativo: texto plano sobre si el host o un jugador está listo. No hay animación cuando alguien se une, no hay avatar animado, no hay contador tipo "3 de 5 listos 🎉".
- `lobby_players_section.dart` (no leído en detalle pero inferido): La lista de jugadores llega en tiempo real pero sin ninguna animación de entrada. Alguien se une → aparece sin fanfarria.

**Role Reveal (`role_reveal_screen.dart`):**  
Este es el momento de mayor potencial de drama y risas en un juego social-deduction. Lo que existe hoy:
- `role_reveal_screen.dart:199-283` — Panel cover con color + nombre del jugador + logo. Drag up para revelar.
- `role_reveal_screen.dart:286-410` — La info revelada (CIVIL / IMPOSTOR + palabra) aparece sin animación al quitar el panel.
- No hay vibración háptica, no hay sonido (entendible), no hay animación de "zoom in" de la etiqueta IMPOSTOR.
- El texto "IMPOSTOR" (tamaño 32, color rojo) es la única señal de drama. Es suficiente para que el jugador entienda, pero no genera el momento "OMG" que define estos juegos.

**Debate / Juego activo (`game_play_screen.dart`):**  
- `game_play_screen.dart:311-403` — La pantalla durante el juego es: modo centrado, timer circular, chips de eliminados, dos botones (Votar / Adivinar). Correcta funcionalmente.
- El timer cambia de color a rojo con pulso a los 30s (`_CircularTimerState`). Buen toque.
- **Lo que falta:** no hay nada que recuerde la palabra secreta a los civiles durante el debate. En Spyfall el civil puede consultar la categoría. Aquí no hay referencia visual durante el debate (intencional como mecánica, pero vale revisar).
- El "Empieza: [nombre]" banner existe pero es un chip pequeño que desaparece si no se lee a tiempo.

**Votación (`vote_screen.dart`):**  
- El flujo de votación Express (2 pasos + confirmación) es correcto pero usa un autocomplete de texto. En una fiesta con teléfono pasando de mano, tipear el nombre propio y luego el sospechoso es más fricción que presionar un nombre en lista.
- La votación Clásica (`_buildClassicVoteScreen`) sí usa lista visual de nombres — correcto.
- La pantalla de "Confirmar voto" (`_buildConfirmView`, línea 638) es sobria y funcional pero no tiene tensión: solo "Confirmar Voto" en botón rojo.

**Eliminación / Action Reveal (`action_reveal_screen.dart`):**  
- `action_reveal_screen.dart:111-183` — La pantalla de suspenso es un progress bar de 2.2 segundos con texto "Revelando resultado..." y un ícono de ojo. Es el momento de más tensión del juego y está resuelto con un spinner glorificado.
- `action_reveal_screen.dart:186-293` — El resultado ("Era impostor!" / "Era inocente!") muestra imagen + texto grande + subtítulo. Las imágenes `.webp` ya existen (civil_correct_guess, civil_lose_life, etc.) — buen recurso visual, pero el reveal llega sin animación de entrada (no hay `AnimatedOpacity`, no hay `ScaleTransition`).
- El botón auto-avanza en 4 segundos con barra que se vacía — buena mecánica, pero se cancela sola sin que el grupo haya podido reaccionar juntos.

**Impostor adivina (`impostor_guess_screen.dart` — no leído en detalle):**  
- El flujo de guess es un momento de altísimo drama potencial ("¿será que sabe?") pero en `game_play_screen.dart:66-240` está protegido por un diálogo de verificación de pista ANTES de entrar a la pantalla. El grupo ve al jugador escribir en secreto y no sabe qué está pasando — tensión bien aprovechada. Pero el diálogo de verificación (`OJO: Escribe tu PISTA, NO la palabra...`) es confuso para jugadores nuevos.

**Resultados (`game_results_screen.dart`):**  
- `game_results_screen.dart:111-157` — Header: imagen (civil/impostor) + título grande + subtítulo. Funciona, pero el título "¡Civiles Ganan!" en font w900 es todo el "momento de celebración" que existe.
- No hay confetti, no hay animación de puntos que suben, no hay diferenciación entre una victoria aplastante y un final ajustado.
- `game_results_screen.dart:338-453` — El MVP card tiene una corona emoji y gradiente dorado. Bien. Pero los jugadores 2do en adelante son solo cards grises idénticas.
- `game_results_screen.dart:46-50` — "Jugar de nuevo" navega de vuelta a setup. No hay CTA de "Compartir" ni momento de screenshot.

### Recomendaciones por momento

**P0 — Role Reveal: añadir animación de entrada al reveal:**  
`role_reveal_screen.dart:286-410` — Cuando el panel sube y se revela el rol, el widget de info (`_buildRoleInfo`) aparece instantáneamente. Añadir un `ScaleTransition` + `FadeTransition` de 400 ms en el `_buildRoleInfo` trigger, condicionado a `_hasRevealed`. El texto "IMPOSTOR" debería hacer "zoom in" con rebote (`Curves.elasticOut`). Costo: ~20 líneas.

**P0 — Action Reveal: dar vida al momento de suspenso:**  
`action_reveal_screen.dart:111-183` — Reemplazar el progress bar por algo más dramático en clave fiesta: un contador regresivo con números grandes (3... 2... 1...) o una animación de "sobre que se abre". El cambio de color del fondo según resultado (verde/rojo) haría el reveal legible desde lejos sin leer texto.

**P1 — Votación Express: reemplazar autocomplete por lista de taps:**  
`vote_screen.dart:518-635` — El `Autocomplete` de texto en modo Express en un teléfono pasando de mano es fricción innecesaria. Reemplazar con `ListView` de chips de nombre (igual que el Clásico). El jugador ve todos los nombres, toca el suyo, toca el sospechoso. 3 taps vs tipear.

**P1 — Lobby online: hacer que las entradas de jugadores "anuncien":**  
`room_lobby_screen.dart:138-183` — Cuando llega un nuevo jugador via Realtime, la lista se actualiza pero sin ningún efecto visual ni copy social. Añadir una fila tipo "Juan se unió 🎉" que aparece 2 segundos y desaparece (similar a los toasts de Kahoot). No requiere cambio de estado —solo un `AnimatedList` con items auto-eliminables.

**P1 — Resultados: confetti o partículas en victoria de civiles:**  
`game_results_screen.dart:23-80` — El widget de resultados tiene un `SingleChildScrollView`. Añadir un overlay de confetti (`confetti` package o custom `CustomPainter` con partículas) que se dispara al montar la pantalla cuando `civilsWon == true`. Es el único momento del juego donde el triunfo es colectivo.

**P2 — Lobby online: contador de "X de N listos" con barra de progreso:**  
`room_lobby_screen.dart:190-280` — El "Ready card" muestra texto "Aun faltan 2 jugadores listos". Cambiar a un widget visual: barra de progreso + avatares con checkmark animado. El grupo puede ver en tiempo real cómo se llena la barra. Referencia: pantalla de "All Players Ready" de Jackbox.

**P2 — Resultados: botón "Captura de pantalla del momento":**  
`game_results_screen.dart:46-75` — Entre "Jugar de nuevo" y "Ir al inicio", añadir un botón "Compartir resultado" que genere un card con el ganador, la palabra secreta y el ranking top-3. Este es el momento más compartible del juego en redes.

---

## 3. ONBOARDING

### Diagnóstico (hoy)

- `how_to_play_screen.dart:73-83` — 8 páginas: concepto, setup, Express, Express scoring, Clásico, Clásico scoring, Online, Online scoring.
- Las páginas de scoring (4 y 6) son tablas de puntos densas. Nadie en una fiesta lee tablas de puntos antes de jugar.
- La navegación es lineal (Siguiente/Saltar) sin modo de búsqueda. Si alguien quiere recordar "¿cómo funciona la pista del impostor?", tiene que paginar 8 pantallas.
- No existe ningún onboarding contextual inline (tooltips dentro del juego que expliquen algo la primera vez).

### Recomendaciones

**P0 — Reducir a 3 páginas: Concepto + Flujo visual + Modos (con scoring colapsable):**  
Páginas actuales 2 (setup) y 4/6 (scoring) son para jugadores comprometidos. La fiesta no da tiempo para eso. Un tutorial debería responder "¿qué hago ahora?" en cada fase.

**P1 — Añadir tooltips contextuales la primera partida:**  
Primera vez en role reveal: pequeño banner "Desliza para ver tu rol secreto" (ya existe como texto pero sin animación de pulso para los que no leen). Primera vez en game_play: tooltip sobre el botón "Votar" explicando cuándo usarlo.

**P2 — Agregar modo "tutorial en vivo" opcional en setup:**  
Un toggle en `game_setup_screen.dart` "Modo tutorial (primera vez)" que activa tooltips contextuales en cada pantalla. Se desactiva automáticamente después de 1 partida completa.

---

## 4. CELEBRACIÓN / CIERRE Y REJUGABILIDAD

### Diagnóstico (hoy)

**Resultados LOCAL (`game_results_screen.dart`):**
- La pantalla de resultados es informativa y correcta pero emocionalmente plana. El MVP con corona es el único momento de celebración diferenciada.
- El botón "Jugar de nuevo" (`game_results_screen.dart:46`) lleva al mismo setup — buena rejugabilidad funcional.
- No hay estadísticas de partido ("el impostor engañó a X civiles", "X jugadores votaron bien").
- No hay momento de "debriefing social" guiado — el juego termina y la app te devuelve al formulario.

**Resultados ONLINE (`match_results_phase.dart`):**  
- `match_results_phase.dart:281-375` — La pantalla es más completa que la local: muestra guess attempts, ranking con medallas, y el flujo de "Volver a jugar".
- La sección de "Intentos de adivinanza" (`_buildGuessAttemptsCard`, línea 559) revela las palabras que el impostor intentó — momento muy divertido para debatir. Pero está enterrado bajo el ranking.
- El botón "Volver a jugar" requiere que TODOS presionen + el host espere para auto-iniciar. El UX de espera (`Esperando jugadores... (2/5)`) es correcto pero frío.

### Recomendaciones

**P0 — Elevar "Intentos de adivinanza" del impostor al top de resultados:**  
`match_results_phase.dart:378-380` — Este es el momento más gracioso y discutible ("¡dijo PIZZA!"). Moverlo antes del ranking, justo debajo del winner announcement. En local (`game_results_screen.dart:83-108`) hacer lo mismo con las hints de los impostores en `_buildImpostorHints`.

**P1 — Añadir 1 dato de resumen de partido ("datos de la partida"):**  
Debajo del word reveal, un mini-bloque de 2-3 stats: "Duró X minutos", "X votos correctos", "El impostor engañó a X personas". Son datos del estado existente en `ActiveGame` / `MatchScoresResult`, solo requieren formateo.

**P1 — Copy de "¿Otra ronda?" en clave fiesta:**  
`game_results_screen.dart:46` — Cambiar "Jugar de nuevo" por "¡Otra ronda!" (con exclamación). En online (`match_results_phase.dart:531`) "Volver a jugar" → "¡Revancha!". Son cambios de 1 línea con impacto de energía real.

**P2 — Pantalla de resultados con animación de entrada por secciones:**  
`game_results_screen.dart:23-80` — Los elementos de la pantalla de resultados (header, spotlight, ranking) aparecen todos a la vez como parte del scroll. Añadir un `AnimatedList` o `staggered` de entradas: primero el winner (con escala), luego la palabra (con fade), luego el ranking (slides desde abajo). 400-600 ms total. Referencia: cómo Kahoot revela el ranking.

---

## 5. TONO / COPY EN CLAVE FIESTA

### Diagnóstico (hoy)

El copy de la app es claro, neutro y correcto en español LatAm. Pero es **tono de producto de productividad**, no de juego de fiesta.

Ejemplos actuales que chocan con la vibra neón-fiesta:

| Pantalla | Copy actual | Problema |
|---|---|---|
| `home_screen.dart:135` | "Juego rápido" | Funcional, no festivo |
| `home_screen.dart:120` | "El juego de la palabra secreta" | Descriptor técnico |
| `room_lobby_screen.dart:67` | "Lobby privado" | Terminología gaming corporativa |
| `room_lobby_screen.dart:198` | "Tu sala ya está lista para configurarse" | Frase de wizard de software |
| `game_results_screen.dart:113` | "¡Civiles Ganan!" | Correcto, pero solitario |
| `vote_screen.dart:415` | "Quien esta votando?" (sin tilde) | Error ortográfico + tono frío |
| `vote_screen.dart:416` | "A quien eliminamos?" (sin tilde) | Error ortográfico |
| `action_reveal_screen.dart:137` | "Revelando resultado..." | Genérico |
| `action_reveal_screen.dart:459` | "¡Era impostor!" | Bien, pero el subtítulo es plano |

**Errores ortográficos encontrados (urgente, imagen de marca):**
- `vote_screen.dart:415` — "Quien esta votando?" → "¿Quién está votando?"
- `vote_screen.dart:416` — "A quien eliminamos?" → "¿A quién eliminamos?"
- `room_lobby_screen.dart:200` — "Marca cuando estes listo" → "Marca cuando estés listo"
- `room_lobby_screen.dart:207` — "Cuando lo confirmes con el boton inferior" → "botón"

### Recomendaciones

**P0 — Corregir errores ortográficos (imagen de marca):**  
Los 4 errores anteriores. Cambios de 1 línea cada uno.

**P1 — Revisión de tono en 5 puntos clave:**

| Pantalla / archivo | Copy actual | Propuesta neón-fiesta |
|---|---|---|
| `home_screen.dart:135` | "Juego rápido" | "¡Jugar ya!" |
| `home_screen.dart:120` | "El juego de la palabra secreta" | "El juego de las mentiras bien dichas" |
| `room_lobby_screen.dart:67` | "Lobby privado" | "Sala de [nombre del host]" o "Tu sala" |
| `action_reveal_screen.dart:137` | "Revelando resultado..." | "¿Quién estará mintiendo...?" |
| `game_results_screen.dart:113` en civiles | "¡Civiles Ganan!" | "¡Los civiles los cacharon!" |
| `game_results_screen.dart:113` en impostores | "¡Impostores Ganan!" | "¡El impostor se salió con la suya!" |

**P2 — Añadir frases de flavor al timer cuando llega a 0:**  
`game_play_screen.dart:39-47` — Cuando el tiempo se acaba (`timeUp()`), actualmente solo navega a resultados. En modo fiesta, antes de navegar: mostrar un "splash" de 1.5s con copy tipo "¡Se acabó el tiempo! ¿Quién es el impostor?" sobre fondo de color. Refuerza el drama.

---

## RESUMEN DE HALLAZGOS PRIORIZADOS

### P0 — Crítico (impacto directo en la experiencia de fiesta)

| ID | Hallazgo | Archivo(s) | Tipo |
|---|---|---|---|
| P0-1 | 8 pasos mínimos antes de la primera ronda en LOCAL | `home_screen.dart`, `game_setup_screen.dart` | Fricción |
| P0-2 | Botón "Repetir partida" con preset ausente en home | `home_screen.dart:128-145` | Fricción |
| P0-3 | Role reveal: sin animación al revelar IMPOSTOR/CIVIL | `role_reveal_screen.dart:286-410` | Energía social |
| P0-4 | Action reveal: spinner + progress bar para el momento de más drama | `action_reveal_screen.dart:111-183` | Energía social |
| P0-5 | Errores ortográficos en pantallas de votación y lobby | `vote_screen.dart:415-416`, `room_lobby_screen.dart:200,207` | Copy / imagen |
| P0-6 | Impostor hints/guess attempts enterrados bajo ranking en resultados | `game_results_screen.dart:83`, `match_results_phase.dart:378` | Cierre |

### P1 — Importante (degradan la vibra festiva)

| ID | Hallazgo | Archivo(s) | Tipo |
|---|---|---|---|
| P1-1 | Spinner cosmético de 400 ms innecesario en flujo local | `home_screen.dart:267` | Fricción |
| P1-2 | 4 estados de carga waterfall en online home | `online_home_screen.dart:119-210` | Fricción |
| P1-3 | Votación Express con autocomplete de teclado en lugar de lista de taps | `vote_screen.dart:518-635` | Fricción |
| P1-4 | Lobby online sin notificación de nuevos jugadores | `room_lobby_screen.dart:138-183` | Energía social |
| P1-5 | Sin confetti ni animación en pantalla de victoria | `game_results_screen.dart:23-80` | Celebración |
| P1-6 | Copy de "¡Otra ronda!" y "¡Revancha!" ausentes | `game_results_screen.dart:46`, `match_results_phase.dart:531` | Tono |
| P1-7 | Onboarding de 8 páginas ilegible en contexto de fiesta | `how_to_play_screen.dart:73-83` | Onboarding |
| P1-8 | Revisión de tono en 5 puntos de copy clave | `home_screen.dart`, `room_lobby_screen.dart`, `action_reveal_screen.dart` | Tono |

### P2 — Mejoras (polish adicional para el rebrand)

| ID | Hallazgo | Archivo(s) | Tipo |
|---|---|---|---|
| P2-1 | Sin stats de partida en resultados ("duró X min", "X votos acertados") | `game_results_screen.dart`, `match_results_phase.dart` | Celebración |
| P2-2 | Sin botón "Compartir resultado" / captura del momento | `game_results_screen.dart:46-75` | Rejugabilidad |
| P2-3 | Sin animación staggered en pantalla de resultados | `game_results_screen.dart:23-80` | Celebración |
| P2-4 | Lobby online sin barra de progreso de "X de N listos" visual | `room_lobby_screen.dart:190-280` | Energía social |
| P2-5 | Sin splash al terminar el tiempo | `game_play_screen.dart:39-47` | Energía social |
| P2-6 | Sin tooltips contextuales en primera partida | `role_reveal_screen.dart`, `game_play_screen.dart` | Onboarding |
| P2-7 | Modo tutorial en setup (primera vez) | `game_setup_screen.dart` | Onboarding |

---

## NOTAS SOBRE EL REBRAND VISUAL

La paleta oscura "Neon Undercover" (`app_theme.dart:18-26`) ya es 100% compatible con la vibra neón-fiesta nocturna:
- `_darkPrimary = Color(0xFF00D1FF)` — cyan eléctrico
- `_darkSecondary = Color(0xFFFF2D7B)` — magenta
- `_darkSuccess = Color(0xFF39FF8E)` — verde neón
- Background `#0A0A12` — negro profundo

**El problema no es la paleta: es que los colores solo aparecen como `withValues(alpha: 0.12)` en fondos de cards.** Para la vibra fiesta nocturna, los fondos deberían tener más presencia del color (gradientes sutiles, bordes con glow, no solo tint al 12 %).

Los `darkPanelColors` del role reveal (cyan, violeta, magenta) son el mejor ejemplo de cómo se ve cuando el color tiene protagonismo. Ese level de saturación debería extenderse a:
- El header de resultados (fondo degradado según ganador, no solo border)
- El botón "¡Otra ronda!" / "¡Revancha!" (neón puro, no pastel)
- El chip de "IMPOSTOR" en role reveal (glow border animado)
