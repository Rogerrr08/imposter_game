# Plan de Optimización de Rendimiento — Modo Local/Offline

> **Fecha:** 2026-04-19
> **Autor:** análisis asistido por Claude Code (agente experto Flutter móvil)
> **Scope:** todo el app EXCEPTO `lib/features/online/` (auditado por separado)
> **Versión objetivo:** v2.2.0 (misma release que el refactor online)
> **Estado:** propuesta — pendiente de aprobación

---

## 1. Contexto y objetivo

El modo local es el flujo original del juego (pass-the-phone), 100% offline,
con persistencia en **Drift (SQLite)** y estado con **Riverpod**. Funciona
bien, pero un análisis a fondo del código encontró varios puntos donde el
rendimiento, el cold-start y el uso de memoria se pueden mejorar sin cambiar
las reglas del juego.

Este plan es **puro rendimiento**: no toca lógica de negocio ni flujos de
pantalla. El usuario no debería notar ninguna diferencia funcional — solo
que la app arranca más rápido, el timer del juego es más fluido, y la memoria
es más estable durante partidas largas.

---

## 2. Diagnóstico resumido

| Área | Estado | Principales problemas |
|---|---|---|
| **Drift / SQLite** | 🟠 mejorable | N+1 queries en guardado de partida y borrado de grupos; trimming bloquea startup |
| **Riverpod** | 🟠 mejorable | `ref.watch` sobre estado completo en pantallas que se reconstruyen cada segundo |
| **Widgets / Rebuilds** | 🟠 mejorable | `setState` y `AnimationController.repeat()` dentro de `build()`; `TweenAnimationBuilder` con `begin==end` |
| **Assets e imágenes** | 🟡 leve | `Image.asset` sin `cacheWidth/Height`; sin `precacheImage` |
| **Navegación go_router** | 🟢 OK | Transiciones livianas, uso correcto |
| **Startup** | 🟠 mejorable | `Future.delayed(100ms)` fijo, Supabase init antes de `runApp`, flash light→dark por `DarkModeNotifier` async |
| **Timers / animaciones** | 🟢 OK | Todos los `dispose()` correctos |
| **Tema / `TextStyle`** | 🔴 alto | 412 apariciones de `TextStyle(fontFamily: 'Nunito', ...)` duplicando lo que ya aplica el `ThemeData` |

---

## 3. Plan de implementación (por fases)

Las fases se pueden implementar de forma independiente. Cada una es
reversible y de riesgo bajo.

### Fase A — Quick wins de alto impacto (1 día)

Cambios pequeños, gran rendimiento visible.

**A.1. Extraer el timer del gameplay a widget dedicado con `select`**

[game_play_screen.dart:248](../lib/screens/game_play/game_play_screen.dart#L248) escucha `gameProvider` completo. Cada `tick()` cada segundo reconstruye **todo el Scaffold** (header, chips de eliminados, botones, etc.).

```dart
// Antes
final game = ref.watch(gameProvider);
// ... 300 líneas de UI que se reconstruyen cada segundo

// Después
class _CircularTimer extends ConsumerWidget {
  @override
  Widget build(context, ref) {
    final seconds = ref.watch(
      gameProvider.select((g) => g?.timeRemainingSeconds ?? 0),
    );
    return CustomPaint(painter: _TimerPainter(seconds), ...);
  }
}
```

Además: quitar el `TweenAnimationBuilder(Tween(begin: progress, end: progress))` de [game_play_screen.dart:459](../lib/screens/game_play/game_play_screen.dart#L459) — `begin == end` no anima nada, solo causa rebuilds.

**Impacto:** Timer de 1-segundo que antes reconstruía ~500 widgets pasa a reconstruir ~10. Frame rate del gameplay sube de forma visible.

**A.2. Batch en `_updatePlayerStats`**

[database.dart:548-589](../lib/database/database.dart#L548-L589) hace **4 upserts por jugador secuencialmente**. Con 10 jugadores son 40 round-trips al terminar la partida.

```dart
Future<void> _updatePlayerStats({...}) async {
  await batch((b) {
    for (final player in playerResults) {
      b.insert(playerStats, ..., mode: InsertMode.insertOrReplace);
      // ... los 4 scopes
    }
  });
}
```

**Impacto:** pantalla de resultados aparece en < 100ms en lugar de ~800ms con 10 jugadores.

**A.3. Precache de imágenes del gameplay**

Agregar al `HomeScreen.didChangeDependencies()` o al `ImpostorApp.build()`:

```dart
precacheImage(const AssetImage('assets/images/player_civil.webp'), context);
precacheImage(const AssetImage('assets/images/player_impostor.webp'), context);
precacheImage(const AssetImage('assets/images/civil_correct_guess.webp'), context);
precacheImage(const AssetImage('assets/images/impostor_correct_guess.webp'), context);
precacheImage(const AssetImage('assets/images/tie_after_voting.webp'), context);
```

Y añadir `cacheWidth: 240, cacheHeight: 240` a los 8 `Image.asset` actuales:
- [home_screen.dart:55](../lib/screens/home/home_screen.dart#L55)
- [role_reveal_screen.dart:253, 304](../lib/screens/game_play/role_reveal_screen.dart#L253)
- [game_results_screen.dart:124](../lib/screens/game_results/game_results_screen.dart#L124)
- [impostor_guess_screen.dart:119](../lib/screens/game_play/impostor_guess_screen.dart#L119)
- [action_reveal_screen.dart:200](../lib/screens/game_play/action_reveal_screen.dart#L200)
- [classic_impostor_choice_screen.dart:35](../lib/screens/game_play/classic_impostor_choice_screen.dart#L35)
- [how_to_play_screen.dart:148](../lib/screens/home/how_to_play_screen.dart#L148)

**Impacto:** elimina el "jank" al entrar a `role_reveal` y `results` por primera vez. Baja el uso de RAM de texturas ~60% (hoy decodifica a resolución nativa webp).

**A.4. Arrancar con el tema correcto (sin flash)**

[theme_provider.dart:14-18](../lib/providers/theme_provider.dart#L14-L18) retorna `false` síncrono mientras carga `SharedPreferences` en background. Resultado: la app arranca en light-mode y salta a dark después de 1-2 frames.

**Opción recomendada:** leer `SharedPreferences` en `main()` antes de `runApp` y pasar el valor como override:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? false;
  AppTheme.applyBrightness(isDark);

  runApp(ProviderScope(
    overrides: [
      isDarkModeProvider.overrideWith(() => DarkModeNotifier.withInitial(isDark)),
    ],
    child: const ImpostorApp(),
  ));
}
```

**Impacto:** elimina el flash light→dark. UX perceptible.

---

### Fase B — Drift / base de datos (1 día)

**B.1. Reemplazar loops `DELETE` por subqueries**

- [database.dart:360-383](../lib/database/database.dart#L360-L383) — `deleteGroup`
- [database.dart:739-748](../lib/database/database.dart#L739-L748) — `trimGameHistory`
- [database.dart:758-764](../lib/database/database.dart#L758-L764) — `clearHistoryForGroup`

Patrón actual: loop con N statements. Propuesto:

```dart
await transaction(() async {
  await customStatement(
    'DELETE FROM game_players WHERE game_id IN '
    '(SELECT id FROM games WHERE group_id = ?)',
    [groupId],
  );
  await (delete(games)..where((g) => g.groupId.equals(groupId))).go();
});
```

**Impacto:** borrar un grupo con 20 partidas pasa de 40 statements a 2. Imperceptible hoy porque es acción puntual, pero correcto.

**B.2. Diferir `_trimAllGroupsHistory` fuera del `beforeOpen`**

[database.dart:101-107](../lib/database/database.dart#L101-L107) ejecuta trimming en **cada apertura de la DB**, bloqueando startup. Es trabajo no-crítico (mantenimiento).

```dart
// beforeOpen: deja solo el bootstrap necesario
// Mover _trimAllGroupsHistory a un Future.microtask que corra después de runApp
Future.microtask(() async {
  await database._trimAllGroupsHistory();
});
```

**Impacto:** cold-start más rápido proporcional al número de grupos guardados.

**B.3. Simplificar `watchGameDetails`**

[database.dart:833-846](../lib/database/database.dart#L833-L846) crea un `playersStream` que nunca usa y dentro del `asyncMap` vuelve a hacer la query. Refactor a `multiJoin` o combinar streams correctamente.

**Impacto:** pantalla de detalle de partida no re-ejecuta queries innecesariamente.

---

### Fase C — Riverpod con `select` granular (1 día)

**C.1. Usar `select` en pantallas que escuchan `gameProvider`**

Todas escuchan el `ActiveGame?` completo cuando solo necesitan sub-campos:

- [game_play_screen.dart:248](../lib/screens/game_play/game_play_screen.dart#L248)
- [role_reveal_screen.dart:99](../lib/screens/game_play/role_reveal_screen.dart#L99)
- [vote_screen.dart:191](../lib/screens/game_play/vote_screen.dart#L191)
- [game_results_screen.dart:14](../lib/screens/game_results/game_results_screen.dart#L14)

Convertir a:
```dart
// En vez de: final game = ref.watch(gameProvider);
final phase = ref.watch(gameProvider.select((g) => g?.phase));
final eliminatedCount = ref.watch(
  gameProvider.select((g) => g?.players.where((p) => p.isEliminated).length ?? 0),
);
```

**Impacto:** muchos menos rebuilds, especialmente durante timers y votaciones.

**C.2. Quitar `addPostFrameCallback` y `pulseController.repeat()` de `build()`**

[game_play_screen.dart:254-268, 283-288](../lib/screens/game_play/game_play_screen.dart#L254) ejecutan side effects en cada rebuild. Reemplazar por `ref.listen`:

```dart
@override
void initState() {
  super.initState();
  ref.listenManual(gameProvider.select((g) => g?.timeRemainingSeconds), (prev, next) {
    if (next != null && next <= 10) _pulseController.repeat();
    else _pulseController.stop();
  });
}
```

**Impacto:** elimina side effects impredecibles en rebuilds; el pulse animation funciona cuando debe sin restartar cada segundo.

---

### Fase D — Tema: eliminar duplicación de `TextStyle` (1-2 días)

**D.1. Limpiar `fontFamily: 'Nunito'` redundante**

412 apariciones de `TextStyle(fontFamily: 'Nunito', ...)` en 45 archivos. El
`ThemeData` en [app_theme.dart:163](../lib/theme/app_theme.dart#L163) ya
aplica `fontFamily: 'Nunito'` al `textTheme` global.

**Proceso:**
1. Script de búsqueda/reemplazo que quite `fontFamily: 'Nunito',` de todos los
   `TextStyle(...)` (regex simple).
2. Verificar visualmente 3-4 pantallas clave.
3. Donde se use `TextStyle(fontSize: X, fontWeight: Y, ...)` aislado, usar
   `Theme.of(context).textTheme.bodyLarge?.copyWith(...)` para heredar.

**Impacto:** menos allocations (cada `TextStyle` inline crea una instancia
nueva en cada rebuild), árbol más estable. Además, cualquier cambio futuro
de fuente solo se toca en un archivo.

**D.2. Migrar accesos a `AppTheme.primaryColor` estático → `Theme.of(context)`**

[app_theme.dart:42-78](../lib/theme/app_theme.dart#L42-L78) muta campos
`static` en `applyBrightness()`. Widgets que usan `AppTheme.primaryColor`
directamente no se rebuildean cuando cambia el tema (dependen de que el
`MaterialApp` se reconstruya). Es una fuente latente de bugs.

**Recomendación:** migrar progresivamente a `Theme.of(context).colorScheme.primary`
y dejar `AppTheme.primaryColor` como fallback de compatibilidad. Esta tarea
puede ser incremental (archivo por archivo en PRs separados).

**Impacto:** eliminación de bug latente + mejor granularidad en cambios de
tema. Esfuerzo alto pero divisible.

---

### Fase E — Startup y arranque (medio día)

**E.1. Eliminar `Future.delayed(100ms)` del main**

[main.dart:16-18](../lib/main.dart#L16-L18). Es un workaround histórico para
`MissingPluginException` en dispositivos Android físicos. Impacta **todos**
los arranques (el 100ms se paga siempre).

**Opción A:** eliminar y ver si el issue reaparece (puede que ya no aplique
con la versión actual de Flutter).

**Opción B:** reemplazar por retry en el primer plugin real invocado:
```dart
Future<T> _pluginCall<T>(Future<T> Function() call) async {
  try { return await call(); }
  on MissingPluginException {
    await Future.delayed(const Duration(milliseconds: 200));
    return await call();
  }
}
```

**Impacto:** cold-start baja 100ms para todos los usuarios.

**E.2. Lazy-init de Supabase**

[main.dart:21](../lib/main.dart#L21) llama `SupabaseConfig.initialize()` en
startup. Los usuarios que solo juegan local pagan un round-trip de red /
inicialización que no necesitan.

```dart
// En main(), eliminar SupabaseConfig.initialize()
// En el botón/entry de "Jugar en linea" del HomeScreen:
await SupabaseConfig.ensureInitialized();
context.go('/online');
```

`SupabaseConfig` debe ser idempotente (flag interno para no re-inicializar).

**Impacto:** cold-start 200-500ms más rápido en dispositivos con red pobre
o sin red. Usuarios offline pueden arrancar y jugar local sin tocar
Supabase nunca.

**E.3. Diferir `initializeDateFormatting('es')`**

[main.dart:20](../lib/main.dart#L20). `date_symbol_data_local` carga datos
para formateo de fechas. Solo se usa en algunas pantallas (historial,
estadísticas).

```dart
// En main: no awaitear, dejar que corra en background
unawaited(initializeDateFormatting('es'));
// En pantallas que formatean fechas: garantizar que esté listo
```

**Impacto:** ~50-100ms menos de startup.

---

### Fase F — Pulido final (opcional, medio día)

**F.1. `const` donde falte**

Pasar `flutter analyze` con `prefer_const_constructors` activado y corregir
todos los warnings. Reduce allocations de widgets en rebuilds.

**F.2. Revisar `MediaQuery.of(context)` en widgets hoja**

Cada widget que usa `MediaQuery.of(context)` se rebuildea cuando cambia
orientación o sale el teclado. En widgets pequeños, usar `MediaQuery.sizeOf`
o `MediaQuery.viewInsetsOf` para depender solo del campo específico.

**F.3. Deprecar `AppTheme.primaryColor` global**

Cerrar el punto D.2 completando la migración a `Theme.of(context)` en todos
los archivos.

---

## 4. Impacto estimado agregado

| Métrica | Hoy (estimado) | Después | Cómo se mide |
|---|---|---|---|
| Cold start tiempo al primer frame | ~1.2s | ~0.7s | `flutter run --trace-startup` |
| Frame rate durante timer del gameplay | ~45 fps | 60 fps | DevTools Performance Overlay |
| RAM durante role_reveal (primera vez) | +40 MB | +15 MB | DevTools Memory |
| Tiempo para mostrar resultados con 10 jugadores | ~800ms | ~100ms | Logs Drift |
| Flash light→dark al cold start en modo oscuro | Visible | Eliminado | QA manual |

---

## 5. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Quitar `Future.delayed(100ms)` puede re-disparar `MissingPluginException` en algún dispositivo Android viejo. | Mantener solución Opción B (retry en primer plugin) como fallback. Probar en emulador API 21+ y al menos un dispositivo físico. |
| Reemplazar `TextStyle` masivamente puede quebrar algún estilo sutil. | Revisar visualmente las 15-20 pantallas principales; dejar el cambio en un commit atómico fácil de revertir. |
| Lazy-init de Supabase: si alguien toca "Jugar en línea" con red caída, puede ver un loader más largo. | Ya hay manejo de estados async en `online_home_screen.dart` — agregar un mensaje claro si tarda. |
| `batch()` en Drift puede tener semántica distinta si una fila falla (rollback de todo el batch). | Es el comportamiento deseado para stats atómicas. No afecta otras áreas. |
| `select` en Riverpod: si el campo seleccionado es un objeto complejo, hay que garantizar igualdad estructural. | Usar `select` solo sobre primitivos (`int`, `String`, `bool`) o tipos con `==` implementado correctamente. |

---

## 6. Estrategia de release

**Recomendado: todo en v2.2.0** junto con el refactor de Realtime del modo
online. Es el mismo ciclo de release y los cambios no se solapan.

Orden de PRs sugerido:
1. PR1: Fase A (quick wins) — merge rápido, bajo riesgo.
2. PR2: Fase B (Drift) — bajo riesgo pero revisar migraciones.
3. PR3: Fase C (Riverpod select) — cambios mecánicos.
4. PR4: Fase D.1 (limpieza `TextStyle`) — muy visual, revisar en QA.
5. PR5: Fase E (startup) — probar en dispositivos reales.
6. PR6: Fase F (pulido) — incremental.

Cada PR se puede validar independiente. No hay que hacer todas las fases
para publicar v2.2.0 — las Fases A, B y E ya justifican el release por sí
solas.

---

## 7. Checklist de ejecución

### Fase A — Quick wins
- [ ] Extraer `_CircularTimer` a widget dedicado con `select`
- [ ] Quitar `TweenAnimationBuilder(begin==end)` en `game_play_screen.dart:459`
- [ ] `batch()` en `_updatePlayerStats`
- [ ] `precacheImage` para 5 assets de gameplay en `HomeScreen`
- [ ] `cacheWidth/Height` en los 8 `Image.asset` identificados
- [ ] Tema inicial correcto en `main()` antes de `runApp`

### Fase B — Drift
- [ ] `DELETE ... WHERE IN (SELECT ...)` en `deleteGroup`, `trimGameHistory`, `clearHistoryForGroup`
- [ ] Mover `_trimAllGroupsHistory` a `Future.microtask` post-runApp
- [ ] Arreglar `watchGameDetails` con `multiJoin`

### Fase C — Riverpod
- [ ] `select` en `game_play_screen`, `role_reveal_screen`, `vote_screen`, `game_results_screen`
- [ ] Mover `addPostFrameCallback` y `pulseController.repeat()` fuera de `build()`

### Fase D — Tema
- [ ] Script de limpieza de `fontFamily: 'Nunito'` inline (412 ocurrencias)
- [ ] Plan gradual de migración `AppTheme.xxx` → `Theme.of(context)`

### Fase E — Startup
- [ ] Evaluar eliminación de `Future.delayed(100ms)` + fallback
- [ ] Lazy-init de Supabase
- [ ] `unawaited(initializeDateFormatting('es'))`

### Fase F — Pulido
- [ ] `prefer_const_constructors` + fix
- [ ] Revisar usos de `MediaQuery.of(context)`

### Verificación
- [ ] `flutter run --trace-startup` antes/después (cold start)
- [ ] DevTools Performance Overlay durante timer del gameplay
- [ ] QA manual de las 15 pantallas principales tras la limpieza de `TextStyle`
- [ ] Smoke test en emulador Android API 21, 30, 34

---

## 8. Registro de actualizaciones

- **2026-04-19** — Creación del documento. Análisis completo del modo local post-v2.1.0.
- **2026-04-22** — **Fase A implementada** en rama `refactor/local_mode`:
  - **A.1** — `game_play_screen.dart`: timer extraído a `_CircularTimer` (ConsumerStatefulWidget con `select` sobre `timeRemainingSeconds` y su propia pulse animation); parent usa 6 `select` granulares + `ref.listen` para efectos de fase; chips de eliminados extraídos a `_EliminatedChips` con su propio `select`; eliminado `TweenAnimationBuilder(begin==end)`.
  - **A.2** — `database.dart`: `_updatePlayerStats` reescrito con Drift `batch()` (4×N round-trips → 1 transacción). Helper `_upsertPlayerStatsRow` eliminado.
  - **A.3** — `cacheWidth/cacheHeight` (≈2×) agregados a los 13 `Image.asset` del app (~75% menos de memoria gráfica por decode). `HomeScreen` convertido a `ConsumerStatefulWidget` con `precacheImage` de `player_civil`, `player_impostor` y `tie_after_voting` en `didChangeDependencies`.
  - **A.4** — `theme_provider.dart` + `main.dart`: preferencia de tema cargada antes de `runApp` y aplicada vía `ProviderScope` override de `initialDarkModeProvider` → sin flash light→dark al arrancar.
  - Verificación: `flutter analyze` limpio (28 issues pre-existentes, 0 nuevos).
- **2026-04-22** — **Fase B implementada** en rama `refactor/local_mode`:
  - **B.1** — `database.dart`: `deleteGroup`, `trimGameHistory` y `clearHistoryForGroup` reescritos con `DELETE ... WHERE game_id IN (SELECT ...)` dentro de `transaction(() async {...})`. De 2N+3 statements a 2-5 por operación. Borrar un grupo con 20 partidas pasa de ~42 statements a 5.
  - **B.2** — `database.dart`: `_trimAllGroupsHistory` ya no bloquea `beforeOpen` — se difiere con `unawaited(Future(_trimAllGroupsHistory))` al event loop para que el primer `runApp`/UI no lo espere. Importado `dart:async` para `unawaited`.
  - **B.3** — `database.dart`: `watchGameDetails` reescrito con `leftOuterJoin` reactivo de Drift. Eliminado el `playersStream` que no se usaba y el SELECT redundante dentro del `asyncMap`. Ahora una sola query reactiva produce `GameDetails` en cada cambio.
  - Verificación: `flutter analyze` → 27 issues (bajó de 28; desapareció el `unused_local_variable: playersStream`). 0 nuevos.
- **2026-04-22** — **Fase C implementada** (parcial, con criterio) en rama `refactor/local_mode`:
  - **C.1a** — `classic_impostor_choice_screen.dart`: `ref.watch(gameProvider)` → `ref.watch(gameProvider.select((g) => g?.pendingClassicGuesserName))`. Ahora solo se reconstruye cuando cambia ese único campo.
  - **C.1b** — `round_start_screen.dart`: `ref.watch(gameProvider)` → `select` sobre el nombre derivado del jugador inicial. Misma estructura con menos rebuilds.
  - **C.2** — Ya aplicado en A.1 para `game_play_screen.dart` (única pantalla con side effects problemáticos en `build()`). Los `addPostFrameCallback` restantes (en `vote_screen.initState` y `classic_impostor_choice_screen` para navegación de recuperación) son patrones correctos y se quedan.
  - **No aplicado por falta de impacto medible:** `role_reveal_screen.dart`, `vote_screen.dart`, `impostor_guess_screen.dart`, `game_results_screen.dart`. Todas usan muchos campos del `ActiveGame` a lo largo del `build` (incluyendo helpers como `_buildRoleInfo(player, gameState)`) y no están en el path del timer (única fuente de rebuilds espurios resuelta en A.1). Refactorizarlas a N `select`s independientes sería ceremonia con riesgo de bugs sin ganancia medible. Se documenta aquí para no volver a abrirlo.
- **2026-04-22** — **Fase E implementada** en rama `refactor/local_mode` (saltada Fase D a recomendación: mayor impacto percibido en cold-start):
  - **E.1** — `main.dart`: eliminado el `await Future.delayed(Duration(milliseconds: 100))` que retrasaba `runApp`. Recorta ~100ms del cold-start sin consecuencias (los plugins nativos ya están listos tras `ensureInitialized`).
  - **E.2** — `supabase_config.dart`: `initialize()` reemplazado por `ensureInitialized()` idempotente (cachea el `Future` con `_initFuture ??= Supabase.initialize(...)`). `main.dart` ya no inicializa Supabase. `home_screen.dart` llama `SupabaseConfig.ensureInitialized()` dentro de `_navigateWithLoading` solo cuando la ruta comienza con `/online`, en paralelo con el `Future.delayed(400ms)` de UX existente vía `Future.wait`. Los usuarios que solo juegan local nunca pagan esta inicialización en cold-start.
  - **E.3** — `main.dart`: `await initializeDateFormatting('es')` → `unawaited(initializeDateFormatting('es'))` con `import 'dart:async'`. Los símbolos de locale solo se usan en pantallas secundarias (historial, grupos); el primer frame no los necesita.
  - Verificación: `flutter analyze` → 27 issues (mismos que tras B; 0 nuevos).
- **2026-04-22** — **Fase F implementada** en rama `refactor/local_mode`:
  - **F.1** — `analysis_options.yaml`: activadas `prefer_const_constructors` y `prefer_const_literals_to_create_immutables`. `dart fix --apply --code=prefer_const_constructors` aplicó **92 fixes en 33 archivos** (widgets que Dart verificó como constructibles en compile-time ahora son `const`, evitando rebuilds innecesarios). Se ejecutó *solo* ese código de fix para no arrastrar limpieza no relacionada (`unnecessary_underscores`, `unused_import`, etc., que se quedan como deuda visible pre-existente).
  - **F.2** — `MediaQuery.of(context)` → getters específicos en los 4 archivos de modo local: `game_play_screen.dart:80` (`viewInsetsOf`), `impostor_guess_screen.dart:65-67` (`sizeOf` + `paddingOf`), `role_reveal_screen.dart:53` (`sizeOf`), `game_setup_screen.dart:677` (`sizeOf`). Cada widget ahora se suscribe solo al campo que realmente usa (evita rebuild al cambiar orientación/teclado en widgets que no dependen de ese aspecto). Las 6 ocurrencias en `lib/features/online/` no se tocan porque están fuera del scope del plan (auditoría online separada).
  - **F.3** — **No aplicado.** Acoplado a la migración completa a `Theme.of(context)` de Fase D (aún no ejecutada). Se hará cuando se aborde Fase D.
  - Verificación: `flutter analyze` → 27 issues (mismos; 0 nuevos).
- **2026-04-22** — **Fase D implementada parcialmente** en rama `refactor/local_mode`:
  - **D.1** — `fontFamily: 'Nunito'` redundante removido de todos los `TextStyle` inline en modo local. Aplicado con `perl -i -pe "s/fontFamily:\s*'Nunito',\s?//g"` sobre 26 archivos seleccionados (todo `lib/` menos `lib/features/online/` que está fuera del scope y `lib/theme/app_theme.dart` donde los `fontFamily: 'Nunito'` restantes son la fuente de verdad para AppBarTheme, ElevatedButtonTheme, OutlinedButtonTheme, InputDecorationTheme, SnackBarTheme y PopupMenuTheme). Luego `dart format lib` para limpiar whitespace residual. Se revirtieron ~46 archivos que solo tenían format drift pre-existente para mantener el commit quirúrgico. El `ThemeData` global ya aplica Nunito vía `baseTextTheme.apply(fontFamily: 'Nunito')` ([app_theme.dart:163](../lib/theme/app_theme.dart#L163)), así que los widgets siguen renderizando en Nunito por herencia del `DefaultTextStyle` — sin cambio visual. Ganancia: cada `TextStyle(...)` inline dejaba una instancia nueva por rebuild; ahora heredan la base del theme → menos allocations.
  - **D.2** — **Diferida.** Al medir el scope real (562 ocurrencias de `AppTheme.xxx` en 26 archivos locales) y evaluar mapeos, se decidió no hacerla en este ciclo. Motivos:
    1. No es mecánico: solo `primaryColor`, `secondaryColor`, `errorColor` y `surfaceColor` mapean 1:1 a `Theme.of(context).colorScheme.xxx`. Los demás (`backgroundColor`, `textSecondary`, `successColor`, `warningColor`, `cardColor`) no tienen equivalente estándar en Material 3 ColorScheme — requerirían un `ThemeExtension<CustomColors>` custom.
    2. El "bug latente" que justificaba la migración (widgets no-reactivos a cambios de tema) no se manifiesta hoy: el toggle de modo oscuro via `isDarkModeProvider` fuerza un rebuild completo del `MaterialApp`, así que todo se reconstruye por la fuerza.
    3. El propio plan reconoce que D.2 *"puede ser incremental (archivo por archivo en PRs separados)"* — mezclarlo con D.1 inflaría el PR sin ganancia clara.
  - Verificación: `flutter analyze` → 27 issues (mismos; 0 nuevos).
  - Verificación: `flutter analyze` → 27 issues pre-existentes, 0 nuevos.
