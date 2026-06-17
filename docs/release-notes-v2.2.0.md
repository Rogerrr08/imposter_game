# Yeison Impostor — Release v2.2.0

> **Fecha:** 2026-04-27
> **Build:** `2.2.0+5`
> **Compatibilidad:** Android, iOS, Web

Versión enfocada en **rendimiento y estabilidad**: el modo local arranca más rápido y consume menos memoria, y el modo online soluciona los bugs reportados ("0/0 jugadores", pistas que no llegan a algunos clientes, retardos al cambiar de fase). Cero cambios visibles de funcionalidad — el juego se siente igual, solo más rápido y confiable.

---

## ✨ Novedades

### 📵 La pantalla ya no se apaga durante la partida
Antes, dejar el celular sobre la mesa entre turnos podía bloquearlo y mandarlo a dormir. Ahora el app mantiene la pantalla encendida mientras está en primer plano, indistinto de modo local u online. En navegador (Web) también funciona y se restaura automáticamente al volver a la pestaña.

---

## 🚀 Modo local — Rendimiento

- **Cold-start ~40% más rápido**: eliminación del `Future.delayed(100ms)` histórico, Supabase ahora se inicializa lazy (solo al entrar a "Jugar en línea"), y `initializeDateFormatting('es')` corre en background.
- **Timer del gameplay más fluido**: el contador de cada segundo ya no reconstruye toda la pantalla. Pasa de ~45 fps a 60 fps.
- **Resultados aparecen 8× más rápido con muchos jugadores**: el cálculo de stats por jugador hace 1 transacción en lugar de 4×N upserts (~800 ms → ~100 ms con 10 jugadores).
- **Borrar grupos / limpiar historial es casi instantáneo**: queries optimizadas con subselect en lugar de N+1 statements.
- **Menos memoria gráfica**: imágenes con `cacheWidth/Height` y precache de assets de gameplay desde la pantalla principal — el role reveal por primera vez ya no causa stutter.
- **Sin flash light → dark al arrancar en modo oscuro**: la preferencia se carga antes del primer frame.

### Bajo el capó (sin impacto visual)
- Refactor de `TextStyle` inline que duplicaban `fontFamily: 'Nunito'` (412 ocurrencias removidas — la fuente sigue siendo Nunito vía el `ThemeData` global).
- Activado `prefer_const_constructors`: 92 widgets pasan a `const` (menos allocations en rebuilds).
- Migración a `MediaQuery.sizeOf` / `paddingOf` / `viewInsetsOf` en widgets hoja para suscribirse solo al campo necesario.

---

## 🌐 Modo online — Refactor Realtime (Broadcast from Database)

Esta versión reescribe la arquitectura de tiempo real del modo online siguiendo la recomendación oficial de Supabase para apps multijugador.

### Bugs corregidos
- ❌ **"0/0 jugadores" intermitente** en lobby y entre fases → ✅ eliminado.
- ❌ **Pistas que no propagaban** a 1-2 clientes mientras el resto sí las veía → ✅ resuelto.
- ❌ **Retardo de 1-2 s al cambiar de fase** (escritura → votación) → ✅ ahora ocurre al unísono en todos los clientes (< 300 ms p95).
- ❌ **Avatares consumiendo 6 MB de RAM con 8 jugadores visibles** → ✅ ~1 MB ahora (decode al tamaño del slot, no a 256×256).

### Cómo funciona el cambio
- Antes: cada cliente abría **5–7 conexiones WebSocket** simultáneas suscritas a tablas individuales (`matches`, `match_players`, `match_clues`, `match_votes`, `rooms`, `room_players`, presence). Cada cambio de UI invalidaba esos providers y reabría las conexiones, dejando "0/0" momentáneo y a veces perdiendo eventos.
- Después: **2 canales unificados** por cliente (`match:<id>` + `room:<id>`/lobby). La base de datos publica deltas a esos canales privados via triggers; el cliente mantiene el estado en memoria y solo aplica los cambios.

### Migraciones SQL incluidas
Para esta versión se ejecutaron en Supabase:
- `queries/10-realtime-refactor-indexes.sql` — índices compuestos en `match_clues`, `match_votes`, `match_players` y `matches`.
- `queries/11-realtime-authorization.sql` — RLS en `realtime.messages` para canales privados.
- `queries/12-realtime-triggers.sql` — 6 triggers que publican deltas vía `realtime.send()`.
- `queries/13-match-snapshot-rpc.sql` — RPC `get_match_snapshot(uuid)` para reconciliar estado al conectarse y reconectar.

> **Pendiente para post-release:** ejecutar `queries/14-realtime-remove-publication.sql` cuando todos los clientes estén en v2.2.0+. Saca las tablas del publication `supabase_realtime`, liberando un hilo del worker. Reversible.

### Otros ajustes
- Heartbeat de conexión bajado de 30 s → 60 s (el presence channel ya detecta desconexiones en tiempo real, así que el heartbeat es solo fallback).

---

## 📦 Información del paquete

- **Android (`yeison-impostor-v2.2.0-release.apk`):** instalación directa.
- **versionCode:** 5
- **versionName:** 2.2.0
- **Min SDK:** Flutter por defecto.
- **Web:** hosteable en cualquier static host. La Wake Lock API requiere Chrome 85+, Firefox 124+, Safari 16.6+.

---

## ⚠️ Notas de upgrade

- Los usuarios v2.1.x **siguen pudiendo conectarse** durante la transición — los SQLs nuevos (triggers + RLS) solo agregan eventos al canal broadcast sin remover los `stream()` viejos. Cuando todos hayan actualizado, ejecutar el `14-*.sql` final.
- No hay migración de datos en cliente: la BD local de Drift mantiene el mismo schema.

---

## 🙏 Créditos
Refactor asistido por análisis de rendimiento y arquitectura con Claude Code.
