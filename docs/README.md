# Versionado del proyecto

## Objetivo

Definir una regla simple y estable para versionar `Imposter Game` de forma consistente entre Flutter, Android e iOS.

## Origen de verdad

La versión oficial del proyecto se define solo en:

[`pubspec.yaml`](../pubspec.yaml)

Formato:

```yaml
version: major.minor.patch+build
```

Ejemplo:

```yaml
version: 1.0.0+1
```

Representación estándar dentro de la app:

```text
v1.0.0 (1)
```

## Cómo se alinea con Android e iOS

- Flutter:
  usa `version: major.minor.patch+build`
- Android:
  `versionName = major.minor.patch`
  `versionCode = build`
- iOS:
  `CFBundleShortVersionString = major.minor.patch`
  `CFBundleVersion = build`

## Reglas obligatorias

- `major.minor.patch` debe contener solo números y puntos.
- `build` debe ser entero positivo.
- Cada build distribuido debe subir el número de `build`.
- No se deben usar sufijos como `-beta`, `-rc` o texto libre en `pubspec.yaml` porque iOS impone formato numérico.
- Si se necesita distinguir una prerelease, eso se documenta en Git, branches o release notes, no en el campo `version`.

## Cuándo subir PATCH

Sube `patch` cuando el cambio no rompe compatibilidad y no cambia el alcance funcional del producto.

Ejemplos:

- corrección de bugs
- mejoras de fluidez
- ajustes visuales
- refactors internos
- documentación
- mejoras de rendimiento

Ejemplo:

- `1.0.0+7` -> `1.0.1+8`

## Cuándo subir MINOR

Sube `minor` cuando agregas funcionalidad nueva compatible con lo anterior.

Ejemplos:

- nueva pantalla
- nuevo flujo jugable
- nuevas reglas opcionales
- nuevas estadísticas
- nuevas notificaciones

Ejemplo:

- `1.2.4+18` -> `1.3.0+19`

## Cuándo subir MAJOR

Sube `major` cuando cambias el contrato del producto o introduces ruptura importante.

Ejemplos:

- cambio fuerte en las reglas base del juego
- migración de datos no compatible
- rediseño del flujo principal que invalida comportamiento anterior
- cambio de compatibilidad de plataformas o de estructura de persistencia con migración obligatoria

Ejemplo:

- `1.9.3+42` -> `2.0.0+43`

## Regla práctica de release

Antes de cerrar una release:

1. decidir si el cambio es `patch`, `minor` o `major`
2. actualizar `pubspec.yaml`
3. subir siempre el `build`
4. validar que Android e iOS lean la misma versión
5. verificar que la app muestre el texto estándar `vX.Y.Z (build)`

## Ejemplos rápidos

- bugfix pequeño:
  `1.0.0+1` -> `1.0.1+2`
- feature compatible:
  `1.0.1+2` -> `1.1.0+3`
- cambio rompiente:
  `1.1.0+3` -> `2.0.0+4`
