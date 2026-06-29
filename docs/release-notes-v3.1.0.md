# Yeison Impostor — Release v3.1.0

> **Fecha:** 2026-06-29
> **Build:** `3.1.0+8`
> **Compatibilidad:** Android, iOS, Web

La versión **3.1.0** es una **reescritura de la confiabilidad del modo online**.
Tras jugar partidas reales con amigos aparecieron varios problemas de
sincronización (desync, turnos equivocados, el timer que mostraba menos tiempo,
espectadores que se quedaban cargando, desconexiones que tardaban en notarse).
Esta versión los ataca de raíz, moviendo la autoridad del estado al servidor y
agregando redes de seguridad. **El modo local no cambia.**

---

## 🌐 Modo online — Confiabilidad

### Se acabó la desincronización entre jugadores
Antes, cada cliente armaba su propia idea de "en qué fase vamos" y "de quién es
el turno" a partir de un snapshot que se refrescaba a mano. Si se perdía un
evento, ese jugador quedaba mirando una pantalla vieja, o le decía "es tu turno"
cuando no lo era. Ahora la **fase y el turno se leen siempre del flujo en vivo**
(una sola fuente de verdad): todos ven lo mismo, y refrescar a mitad de partida
te deja exactamente donde corresponde.

### El temporizador del turno ahora es igual para todos
El contador de cada turno lo llevaba cada celular por su cuenta, así que a uno le
aparecían 30 segundos y a otro 5. Ahora el **servidor marca cuándo termina el
turno** y cada cliente calcula los segundos restantes desde esa marca (con
corrección del desfase de relojes). Resultado: **el mismo número en todas las
pantallas**, y quien se reconecta ve el tiempo correcto al instante.

### Ya no se saltan turnos
Cuando se agotaba el tiempo, varios celulares intentaban "saltar" el turno a la
vez y el juego avanzaba de más, salteando personas. Ahora el avance está
**protegido en el servidor**: aunque varios lo intenten, el turno avanza una sola
vez.

### Detección de desconexión en segundos
Si alguien se iba (cerraba la app, perdía señal), tardaba **1-2 minutos** en
aparecer como desconectado. Ahora, con **presencia en vivo**, los demás lo ven
desconectado en **~12 segundos**.

### Espectadores y unirse a mitad de partida
Un amigo que entraba con la partida ya empezada **se quedaba cargando para
siempre** (el servidor no lo dejaba ver la partida si no era jugador). Ahora
**cualquier miembro de la sala puede espectar** la partida en curso, y juega
normalmente en la siguiente ronda.

### Red de seguridad anti-desync
Como respaldo, cada cliente **reconcilia su estado cada pocos segundos**. Si por
algún motivo se pierde un evento con la conexión "viva" (típico en el navegador
o al volver de segundo plano), el estado se corrige solo en segundos — sin
retroceder nunca a una pantalla anterior.

---

## 🔒 Seguridad y base de datos

Auditoría completa del proyecto Supabase (sin errores). Hardening aplicado:
- **`search_path` fijo** en las funciones que faltaban (evita un vector de
  secuestro en funciones con privilegios).
- **Funciones internas** (triggers, limpieza, heartbeats) ya **no son
  ejecutables por los clientes** (solo el sistema las llama).
- **Índices** agregados para las claves foráneas que no los tenían.

---

## 🧱 Bajo el capó

- Nueva columna `matches.turn_ends_at` + trigger que la estampa al iniciar cada
  turno; RPC `server_now()` para sincronizar relojes.
- `skip_clue_turn` con *compare-and-swap* (idempotente por turno).
- Presencia en vivo vía Supabase Realtime Presence (canal dedicado por partida).
- `get_match_snapshot` y la autorización de Realtime abiertas a miembros de la
  sala (espectadores).
- Migraciones SQL: `queries/16` (timer), `17` (hardening), `18` (espectador).

---

## 📦 Información del paquete

- **Android (`yeison-impostor-v3.1.0-release.apk`):** instalación directa.
- **versionCode:** 8
- **versionName:** 3.1.0
- **Web:** se despliega solo en push a `main` (GitHub Pages).

---

## ⚠️ Notas de upgrade

- **Las migraciones SQL ya están aplicadas en Supabase** (`queries/16`, `17`,
  `18`). Son **compatibles hacia atrás**: la versión 3.0.0 sigue funcionando
  contra la base actualizada (las columnas nuevas son aditivas y la firma vieja
  de `skip_clue_turn` se conservó), así que no hay que apurar la actualización de
  todos los clientes.
- **No hay migración de datos en cliente**: la BD local de Drift mantiene el
  mismo schema; grupos, rankings e historial se conservan.

---

## 🙏 Créditos
Refactor de confiabilidad online auditado y aplicado (incl. base de datos) con
Claude Code.
