# Auditoría de Diseño UX/UI — Yeison Impostor

> Diagnóstico previo a publicación en Google Play. Revisión sistemática de las pantallas reales (modo LOCAL y ONLINE) más el tema. Fecha: 2026-06-06. Esto es un **diagnóstico**, no implementación.

---

## 1. Resumen ejecutivo

El **modo LOCAL está listo para tienda**: visualmente pulido, coherente, con ilustraciones propias, estados vacíos cuidados, animaciones con propósito y buen español. El **modo ONLINE funciona y tiene buena arquitectura de estados** (loading/error/empty/espectador/reconexión muy completos), pero **se nota como un módulo de segunda generación**: usa íconos genéricos de Material donde el local usa ilustraciones, repite `fontFamily: 'Nunito'` inline en cientos de sitios, y arrastra **textos sin tildes** ("adivino", "decidio", "Voto", "Tu") que delatan menor cuidado. Nada de esto es bloqueante técnico, pero **el contraste de calidad entre local y online es perceptible** para un usuario que juega ambos. Con ~1-2 días de pulido (quick wins) el online sube al nivel del local. **Veredicto: publicable, pero el online merece una pasada de consistencia visual y ortográfica antes de exponerlo como característica destacada.**

Transversalmente, hay **una deuda real de accesibilidad**: cero `Semantics`/`semanticLabel` en toda la app, varias fuentes pequeñas (10–12.5px), y dos pantallas con layout atado a `MediaQuery.of(context).size` que puede romperse con text scaling alto.

---

## 2. Fortalezas (qué está bien)

- **Sistema de tema sólido y bien pensado.** `app_theme.dart` define dos paletas completas (Fiesta Sospechosa / Neon Undercover), aplica `fontFamily: 'Nunito'` globalmente, y tematiza botones, inputs, cards, snackbars, switches, diálogos y bottom sheets. Radios (14–24), padding y elevaciones son consistentes. Hay accesores en runtime (`AppTheme.primaryColor`, etc.) que evitan leer `Theme.of` por todos lados.
- **Ilustraciones propias bien usadas en LOCAL.** `role_reveal_screen`, `action_reveal_screen` y `game_results` usan los `.webp` (`player_civil`, `player_impostor`, `civil_correct_guess`, `tie_after_voting`, etc.) con `cacheWidth/cacheHeight` correctos. Le da personalidad al juego.
- **Estados vacíos y de error cuidados.** Grupos, rankings, lista de jugadores y todas las pantallas de entrada online tienen empty/error states con ícono + título + subtítulo + CTA. Es de las cosas mejor resueltas del proyecto.
- **Onboarding completo.** `how_to_play_screen` tiene 8 páginas con concepto, setup, modos Express/Clásico/Online y desglose de puntajes, con indicadores de página animados y botón "Saltar". Muy por encima del promedio de un juego casual.
- **Microinteracciones con propósito.** El "desliza para revelar" del role reveal local, el shimmer + glow del role reveal online, las barras de auto-avance que se vacían, los `_PulsingDots` de espera — animaciones que comunican, no decorativas.
- **Robustez de flujo online.** Reconexión con detección de background >1s, banner de espectador, late-joiners en el ranking, retry con backoff en "volver a jugar", auto-skip de turnos de jugadores eliminados, manejo de empates/desempates. El flujo está pensado a fondo.
- **Performance consciente.** Precache de assets en home, `cacheWidth/Height` en imágenes, `memCacheWidth` en avatares de red, inicialización lazy de Supabase solo cuando se entra a online.

---

## 3. Hallazgos priorizados

> Severidad: **P0** bloquea/rompe · **P1** afecta percepción de calidad notablemente · **P2** pulido que suma · **P3** nice-to-have. Esfuerzo: **S** (<1h) · **M** (1-3h) · **L** (>3h).

| # | Sev | Pantalla / archivo:línea | Problema | Recomendación | Esf. |
|---|-----|--------------------------|----------|---------------|------|
| 1 | **P1** | `online/.../impostor_choice_phase.dart:245` · `impostor_guess_phase.dart:190,385` · `online_match_screen.dart:795` (espectador) · `impostor_result_hold.dart:60-68` | El impostor online y el espectador ven **íconos Material en círculos de color** (`Icons.psychology_rounded`, `hourglass_top_rounded`, `casino/shield/close_rounded`) mientras el LOCAL usa las ilustraciones `.webp`. Rompe la identidad visual justo en los momentos clímax del juego. | Reemplazar por las ilustraciones existentes: `player_impostor.webp` para choice/guess/waiting, `impostor_failed_guess.webp` para `wrong_guess`, `tie_after_voting`/`player_impostor` según corresponda. El `_buildImpostorView` ya usa la webp — extenderlo al resto. | M |
| 2 | **P1** | Todo `lib/features/online/**` (cientos de `TextStyle(fontFamily: 'Nunito', ...)`) | `fontFamily: 'Nunito'` **inline y redundante** (el `ThemeData` ya lo aplica). Además genera estilos inconsistentes y ruido que dificulta mantener. El local ya se limpió. | Borrar el `fontFamily:` inline y, donde aplique, derivar de `Theme.of(context).textTheme`. Hacerlo por archivo con find/replace cuidadoso. No cambia el render, sube mantenibilidad y coherencia. | M |
| 3 | **P1** | `online/.../impostor_result_hold.dart:61-67` ("decidio", "arriesgar!", "adivino mal!") · `match_results_phase.dart:326,943,958,1007` ("ganan!", "Que impostor adivino", "victoria", "recibira") · `vote_result_phase.dart:391` ("Empate!") · `voting_phase.dart:404,425` ("Voto", "(Tu)") | **Faltan tildes y signos de apertura** en muchos strings del online (decidió, arriesgar, adivinó, ganan, recibirá, votó, tú, ¡…!). El LOCAL sí usa acentos y `¡`/`¿`. Para un público hispanohablante esto se lee como descuido. | Corregir ortografía en todo `lib/features/online`. Añadir `¡`/`¿` de apertura. Es lo que más barato sube la percepción de calidad. | S |
| 4 | **P1** | Global (`grep Semantics` → 0 resultados en todo `lib/`) | **Cero accesibilidad semántica.** Botones-ícono sin label (toggle de tema, enviar pista, kick), imágenes sin `semanticLabel`, estados ("Tu turno", timers) no anunciados. TalkBack es casi inservible. | Añadir `Semantics`/`semanticLabel` a: IconButtons sin texto, ilustraciones de rol/resultado, y los contadores de progreso (votos, listos, timer). Empezar por home, role reveal y votación. | M |
| 5 | **P2** | `online/.../impostor_guess_phase.dart:143-146` · `display_name_screen.dart` | Uso de **`MediaQuery.of(context).size`/`.padding`** (rebuild completo) para calcular `minHeight`. Con text scaling alto el `IntrinsicHeight + ConstrainedBox` puede provocar overflow u órdenes de layout frágiles. | Migrar a `MediaQuery.sizeOf` / `.paddingOf` (ya usado en role_reveal y reorder sheet). Validar el guess screen con fuente del sistema al 130%. | S |
| 6 | **P2** | `home_screen.dart` (Column con `Spacer` flex sin scroll) | El home **no es scrollable**: en pantallas cortas o con text scaling grande, logo (240px) + título + 3 botones + divider + footer pueden no caber → overflow. | Envolver el contenido central en `SingleChildScrollView` o reducir el logo y permitir scroll cuando la altura sea insuficiente. | S |
| 7 | **P2** | `online_match_screen.dart:490-540` (`_detectImpostorTransition`) | La transición impostor_guess→finished con victoria de impostores **salta la pantalla intermedia "adivinó"** (hay un `return` que reconoce el problema en comentarios). El usuario pasa de votación a resultados sin ver el momento de la adivinanza correcta — anticlímax. | Mostrar un `ImpostorResultHold` de tipo "correct_guess" (con `impostor_correct_guess.webp`) también cuando ganan por adivinanza, no solo en `wrong_guess`. | M |
| 8 | **P2** | `vote_result_phase.dart:438-450` (selección de imagen por `viewerIsImpostor`) | La imagen de "alguien fue eliminado" depende del rol del espectador, lo cual es ingenioso, pero un **espectador late-join** (`isSpectator`) cae en la rama `viewerIsImpostor=false` y puede ver una imagen que no encaja con su perspectiva neutral. | Para espectadores neutrales usar una ilustración neutra (p.ej. `tie_after_voting` o role del eliminado), no la del bando civil. | S |
| 9 | **P2** | `how_to_play_screen.dart:74-83` orden de páginas | El array de páginas es Concepto→Setup→Express→**ExpressScoring**→Clásico→ClassicScoring→Online→OnlineScoring, pero los comentarios dicen "Page 3 Express / Page 4 Classic" y luego "Page 4 Express Scoring" — el **orden lógico está bien pero los rótulos de comentarios están desfasados** y Express queda separado de su scoring por una página. Menor, pero confunde al mantener. | Reordenar para que cada modo vaya seguido de su scoring (ya casi lo está) y corregir los comentarios `// Page N`. | S |
| 10 | **P2** | `action_reveal_screen.dart:144` ("lo que pasó") vs online | Buen detalle: el LOCAL tiene tildes correctas. Mantener ese estándar como "fuente de verdad" para el online (ver #3). | Definir el local como referencia de tono/ortografía. | — |
| 11 | **P3** | Densidad tipográfica: `how_to_play` `_scoreRow` 12.5px · `match_results` badges 10px · `vote_result` "Votaron:" 11px · varios 10px | Varias etiquetas a **10–12.5px**. En densidad alta y para usuarios mayores cuesta leer. Contraste suele ser ok (textSecondary), pero el tamaño está al límite inferior. | Subir mínimos a 11–13px donde sea texto informativo (no solo decorativo). Revisar contraste de `textSecondary @ alpha 0.3-0.5` contra fondo en modo claro. | M |
| 12 | **P3** | `online_match_screen.dart:431-438` `_showCancelledAndLeave` solo muestra snackbar | Cuando la partida se cancela por Realtime, se dispara un **snackbar pero no se navega** automáticamente; el usuario queda en una pantalla que luego renderiza `_buildCancelled`. Hay algo de doble feedback (snackbar + pantalla). | Unificar: o snackbar+auto-return, o solo la pantalla `_buildCancelled` con su botón. Evitar el snackbar redundante. | S |
| 13 | **P3** | `groups_screen.dart:242,416` `barrierColor: AppTheme.textSecondary` | El **barrier del loading es `textSecondary` opaco** (gris sólido), no un negro semitransparente como en home (`black @ 0.16`). El dim se ve plano/raro. | Usar `Colors.black.withValues(alpha: 0.16)` como en home para consistencia. | S |
| 14 | **P3** | `home_screen.dart:55-63` toggle de tema | El **cambio de tema vive solo como IconButton suelto** en la esquina del home. No hay pantalla de ajustes; un usuario no sabe que existe modo claro/oscuro hasta que lo descubre. | Aceptable para un proyecto personal, pero considerar un pequeño menú de ajustes (tema + cómo jugar + versión) a futuro. | M |
| 15 | **P3** | `rankings_screen.dart:295` una sola línea con 3 métricas separadas por `\|` | "Partidas: X \| Victorias civil: Y \| Victorias impostor: Z" en **12px en una sola línea** se trunca/aprieta en nombres largos o pantallas chicas. | Pasar a `Wrap` de chips o dos líneas. | S |
| 16 | **P3** | Touch targets: `game_setup_screen.dart:549` chips de jugador (`vertical: 8`) · `player_list.dart:170` close icon 18px · `how_to_play` close 28px container | Algunos targets quedan **por debajo de 48x48dp** (el GestureDetector de excluir/incluir jugador, la X de borrar jugador, el ícono de cerrar onboarding). Funcionan pero exigen puntería. | Garantizar 48x48 con padding o `SizedBox`/`InkWell` envolvente, especialmente en setup y player_list. | M |

---

## 4. Quick wins (bajo esfuerzo, alto impacto)

1. **Corregir tildes/ortografía en todo `lib/features/online`** (#3) — el cambio más barato que más sube la percepción de calidad. ~1h.
2. **Sustituir los íconos Material del impostor online por las `.webp` existentes** (#1) — los assets ya están, solo es cablearlos. Cierra la brecha visual local↔online en el momento más visible.
3. **Limpiar `fontFamily: 'Nunito'` inline** en online (#2) — find/replace por archivo, no cambia render.
4. **`MediaQuery.of` → `.sizeOf`/`.paddingOf`** en `impostor_guess_phase` y `display_name_screen` (#5).
5. **Home scrollable** para evitar overflow en pantallas cortas / fuentes grandes (#6).
6. **Unificar barrier color** de los loadings en `groups_screen` con el de home (#13).
7. **Imagen neutral para espectadores** en vote_result (#8).

---

## 5. Recomendaciones de mediano/largo plazo

- **Accesibilidad como tema de proyecto, no de pantalla** (#4, #11): añadir una capa de `Semantics` a los componentes reutilizables (`PlayerAvatar`, botones primarios, badges de estado) para cubrir TalkBack de un golpe; probar la app entera con text scaling 130–150% antes de cada release. Es lo único cercano a "bloqueante de calidad" que queda.
- **Cerrar el arco narrativo del impostor online** (#7): que la adivinanza correcta tenga su propia pantalla de celebración con `impostor_correct_guess.webp`, igual que el local. Hoy el clímax del bando impostor online se diluye.
- **Extraer un kit de componentes compartido**: hay mucha duplicación de "card con ícono + título + subtítulo", "badge pill", "botón de resultado a pantalla completa", "estado de espera con spinner + texto" entre local y online. Un paquete `lib/widgets/` común reduciría la divergencia de calidad entre módulos (que es la causa raíz de casi todos los hallazgos P1).
- **Pantalla de Ajustes** (#14): centralizar tema, cómo jugar, versión y (a futuro) idioma. Hace la app sentirse más "producto".
- **Pase de microcopy en español neutro/coloquial coherente**: el tono está bien, pero conviene fijar un único estándar (tildes, mayúsculas, signos de apertura) y aplicarlo. El local debe ser la fuente de verdad.
- **QA de layout en dispositivos reales pequeños** (≤5") y con fuente grande del sistema, especialmente role reveal online, impostor guess y match results (los que más contenido vertical apilan).

---

### Apéndice — Cobertura de la revisión

LOCAL leído: `home_screen`, `how_to_play_screen`, `game_setup_screen` + `player_list`/`start_button`, `role_reveal_screen`, `action_reveal_screen`, `groups_screen`, `rankings_screen`, `theme/app_theme.dart`. ONLINE leído: `online_home_screen`, `join_room_screen`, `room_lobby_screen`, `online_match_screen`, y widgets `role_reveal_phase`, `clue_writing_phase`, `voting_phase`, `vote_result_phase`, `match_results_phase`, `impostor_choice_phase`, `impostor_guess_phase`, `impostor_result_hold`, `player_avatar`. Búsquedas transversales: `Semantics`/`semanticLabel` (0 ocurrencias), `MediaQuery.of(context)` (2 archivos), `fontFamily: 'Nunito'` inline (predominante en todo online).
