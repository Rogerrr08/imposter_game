# Imposter Game

App móvil en Flutter para jugar una variante social de impostor con palabra secreta, temporizador, grupos persistentes, historial y rankings.

## Estado actual

- Plataforma principal: Flutter
- Persistencia local: Drift
- Navegación: go_router
- Estado: Riverpod
- Notificaciones locales: aviso cuando falta 1 minuto para terminar la ronda

## Cómo correr el proyecto

```bash
flutter pub get
flutter run
```

Para release:

```bash
flutter run --release
```

## Versión

La versión fuente del proyecto vive en [pubspec.yaml](pubspec.yaml) con el formato:

```yaml
version: 1.0.0+1
```

- `1.0.0` es la versión visible para usuario.
- `1` es el número interno de build.
- En la app se muestra como `v1.0.0 (1)`.

## Reglas básicas del juego

- Se juega con 3 a 20 personas.
- Los civiles conocen la palabra secreta.
- Los impostores no conocen la palabra.
- El grupo debate antes de votar.
- Si el equipo civil falla demasiadas veces o los impostores sobreviven, pierden.

## Estructura mínima

- [lib/screens](lib/screens): pantallas principales
- [lib/providers](lib/providers): estado y acceso a datos
- [lib/database](lib/database): esquema y consultas Drift
- [docs/README.md](docs/README.md): estándar de versionado del proyecto

## Versionado del proyecto

Este proyecto usa un único origen de verdad para versión y build:

- `pubspec.yaml -> version: major.minor.patch+build`
- Android usa:
  `versionName = major.minor.patch`
  `versionCode = build`
- iOS usa:
  `CFBundleShortVersionString = major.minor.patch`
  `CFBundleVersion = build`

La guía completa está en [docs/README.md](docs/README.md).
