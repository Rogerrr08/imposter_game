# Yeison Impostor — Guía del proyecto

Party game "el impostor" (estilo Spyfall) en español. Dos modos: **local**
(pass-the-phone, 100% offline) y **online** (multijugador con Supabase).
Publicado en Google Play como proyecto personal. UI en español; comentarios
de código en español.

## Stack

- **Flutter** + **Riverpod** (`flutter_riverpod` ^3.3.1) + **go_router** ^17
- **Drift** (SQLite) para persistencia local — codegen con `build_runner`
- **Supabase** (`supabase_flutter` ^2.12.2) para online: auth anónima,
  Postgres + RPCs, Realtime (Broadcast from Database), Storage (avatares)
- `wakelock_plus` mantiene la pantalla encendida en toda la app
- Dart SDK `^3.11.4`

## Mapa del repo (dónde vive cada cosa)

```
lib/
  main.dart            # bootstrap: tema antes del 1er frame, wakelock, Supabase lazy
  data/word_bank.dart  # selección de palabra (shuffle-bag + soft-decay anti-repetición)
  data/word_bank/categories/*.dart   # 6 categorías × 75 palabras
  database/database.dart             # Drift: tablas, DAOs, migraciones (schemaVersion)
  database/daos/                     # GroupDao, GameDao (parte en database.dart)
  models/              # game_state.dart (ActiveGame), action_reveal.dart, etc.
  providers/           # game_provider (motor local), theme_provider, database_provider
  router/app_router.dart
  theme/app_theme.dart # AppTheme: 2 paletas (claro/oscuro), tematiza todo
  screens/             # MODO LOCAL (pass-the-phone)
    home/ game_setup/ game_play/ game_results/ groups/ rankings/
  features/online/     # MODO ONLINE (feature-first)
    domain/            # OnlineMatch, OnlineRoom (modelos + fromMap)
    data/              # repos, supabase_config, online_match_channel, online_room_channel
    application/       # providers Riverpod + room_lobby_notifier
    presentation/      # pantallas online + widgets/ (fases del match)
queries/               # SQL de Supabase (01..15), se ejecutan MANUALMENTE en el dashboard
assets/images/*.webp   # ilustraciones (player_civil/impostor, *_guess, tie_after_voting)
docs/                  # planes de refactor + progress logs + auditorías
android/app/build.gradle.kts  # renombra el APK a yeison-impostor-v{version}-{buildType}.apk
```

## Arquitectura online realtime (la parte compleja)

Migrado a **Broadcast from Database** (no Postgres Changes). Triggers en
Postgres publican deltas vía `realtime.send()` a canales privados:
- `match:<id>` → eventos `match-updated`, `player-updated`, `clue-added`, `vote-added`
- `room:<id>` → `room-updated`, `player-joined/left/updated`

Cliente: `OnlineMatchChannel` / `OnlineRoomChannel` ([data/](lib/features/online/data/))
hacen **snapshot + deltas**: al conectar llaman un RPC de snapshot
(`get_match_snapshot`) y luego aplican deltas en memoria, emitiendo por
streams. Los `StreamProvider` en [application/](lib/features/online/application/)
consumen esos streams (la UI no cambió de interfaz).
`MyMatchState` (rol/palabra secreta) viene aparte por RPC `get_my_match_state`.

Estado del refactor y pendientes: ver [docs/online-multiplayer-progress.md](docs/online-multiplayer-progress.md).
SQL `14-realtime-remove-publication.sql` se ejecuta SOLO cuando todos los
clientes estén en la versión nueva.

## Convenciones

- **Colores/estilos**: usar `AppTheme.xxx` ([theme/app_theme.dart](lib/theme/app_theme.dart)).
  El `ThemeData` ya aplica la fuente **Nunito** global → NO repetir
  `fontFamily: 'Nunito'` inline (deuda: los archivos de `features/online/`
  todavía lo tienen; `lib/screens/` ya se limpió).
- **Versión**: se cambia en `pubspec.yaml` (`version: X.Y.Z+build`) y en
  [lib/providers/app_info_provider.dart](lib/providers/app_info_provider.dart)
  (label del footer). El nombre del APK sale de `pubspec.yaml` automáticamente.
- **Anti-repetición de palabras**: local en tabla Drift `word_history`,
  online en `match_word_history` (Supabase). Misma lógica (N=35, hard-floor
  10 + soft-decay). Ver [lib/data/word_bank.dart](lib/data/word_bank.dart).
- **Riverpod**: preferir `select()` para evitar rebuilds; canales online son
  `autoDispose.family` y se limpian con `removeChannel` en dispose.
- Lints: `prefer_const_constructors` activado en `analysis_options.yaml`.

## Comandos

```bash
flutter analyze                       # baseline ~27 issues pre-existentes (info/warn)
flutter build apk --release           # → build/app/outputs/flutter-apk/yeison-impostor-v{version}-release.apk
dart run build_runner build --delete-conflicting-outputs   # regen Drift tras tocar tablas
dart format <archivo>                 # formatear
```

## Gotchas importantes

- **SQL no se aplica solo**: los archivos en `queries/` se ejecutan a mano en
  el SQL Editor de Supabase. Al crear una tabla nueva en `public`, agregar
  GRANTs explícitos (cambio de Supabase: desde oct-2026 las tablas nuevas no
  se exponen al Data API sin GRANT).
- **Web (GitHub Pages) se despliega solo** en push a `main` — NO incluir
  `flutter build web` en pasos de release manuales.
- **`flutter analyze` baseline ~27 issues** son pre-existentes (deprecations,
  unnecessary_underscores). Al verificar un cambio, comparar contra ese
  baseline, no contra 0.
- Muchos archivos de `features/online/` no están formateados (tienen el
  `fontFamily` inline). `dart format` sobre ellos genera diffs grandes — tenerlo
  en cuenta al editar para no ensuciar commits.
- Migraciones Drift: subir `schemaVersion` y agregar el bloque en
  `onUpgrade` + (defensivo) `CREATE TABLE IF NOT EXISTS` en `beforeOpen`.

## Docs de referencia

- [docs/online-realtime-refactor-plan.md](docs/online-realtime-refactor-plan.md) — plan realtime
- [docs/online-multiplayer-progress.md](docs/online-multiplayer-progress.md) — progress log online
- [docs/local-performance-refactor-plan.md](docs/local-performance-refactor-plan.md) — perf local
- [docs/ui-ux-audit.md](docs/ui-ux-audit.md) — auditoría UX/UI (hallazgos priorizados)
