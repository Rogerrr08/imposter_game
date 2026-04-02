# Yeison Impostor — Plan de modo online (MVP reducido)

## Prop\u00f3sito

Agregar juego en l\u00ednea a **Yeison Impostor** sin romper el modo local actual.

La app mantendr\u00e1 dos experiencias separadas:

- `Local`: el flujo presencial actual, en un solo dispositivo.
- `En l\u00ednea`: partidas sincronizadas entre varios tel\u00e9fonos.

## Alcance del MVP

El primer entregable online incluye **\u00fanicamente**:

- **Sala privada** con c\u00f3digo de invitaci\u00f3n
- **Modo Cl\u00e1sico** (turnos de palabra escrita + votaci\u00f3n an\u00f3nima)
- **Auth an\u00f3nima** con display name
- **4-8 jugadores** por sala
- **Reconexi\u00f3n b\u00e1sica** desde el d\u00eda 1
- **Seguridad (RLS)** desde el d\u00eda 1

### Fuera del MVP

Estas funcionalidades se postergan para fases futuras:

- Modo Express online (requiere concurrencia y action locks)
- Partida r\u00e1pida / matchmaking
- Sala de grupo online (requiere identidad real y membres\u00eda)
- Chat o voz integrados (los jugadores usan WhatsApp/Discord aparte)
- Moderaci\u00f3n avanzada de contenido

## Restricciones y decisiones

- El modo local debe mantenerse intacto.
- Idioma inicial: solo espa\u00f1ol.
- Sin manejo de regiones.
- Las pistas se escriben, no se dicen por voz.
- Backend autoritativo: el cliente no decide roles, palabras, votos, ni resultados.
- Local usa Drift, online usa Supabase. No comparten persistencia.
- Ya existe organizaci\u00f3n en Supabase.

---

## Arquitectura

### Cliente Flutter

Separaci\u00f3n clara entre dominios:

```
lib/
\u251c\u2500\u2500 ...                          # (c\u00f3digo local existente, sin cambios)
\u251c\u2500\u2500 features/
\u2502   \u251c\u2500\u2500 shared_game/            # Reglas puras reutilizables (scoring, validaciones)
\u2502   \u2514\u2500\u2500 online/
\u2502       \u251c\u2500\u2500 domain/             # Modelos online (Room, OnlineMatch, OnlinePlayer)
\u2502       \u251c\u2500\u2500 data/               # Repositorios Supabase (rooms, matches, realtime)
\u2502       \u251c\u2500\u2500 application/        # Providers / notifiers online
\u2502       \u2514\u2500\u2500 presentation/       # Pantallas: lobby, gameplay online, resultados online
```

### Backend (Supabase)

- **Auth**: identidad an\u00f3nima con display name
- **Postgres**: persistencia de salas, partidas, votos, pistas
- **Realtime**: presencia en sala + eventos de match
- **Edge Functions**: l\u00f3gica autoritativa de juego
- **RLS**: seguridad desde el d\u00eda 1 en todas las tablas

---

## Esquema de datos

### `profiles`

| Campo | Tipo |
|---|---|
| id | uuid PK |
| created_at | timestamptz |
| display_name | text |
| avatar_seed | text nullable |

### `rooms`

| Campo | Tipo |
|---|---|
| id | uuid PK |
| code | text unique (6 caracteres) |
| host_user_id | uuid FK profiles |
| status | text (`waiting`, `playing`, `finished`) |
| game_mode | text (`classic`) |
| categories | text[] |
| hints_enabled | bool |
| impostor_count | int |
| duration_seconds | int |
| min_players | int default 4 |
| max_players | int default 8 |
| created_at | timestamptz |
| started_at | timestamptz nullable |

**RLS**: solo miembros de la sala pueden leer. Solo el host puede actualizar configuraci\u00f3n.

### `room_players`

| Campo | Tipo |
|---|---|
| id | uuid PK |
| room_id | uuid FK rooms |
| user_id | uuid FK profiles |
| display_name | text |
| seat_order | int |
| is_host | bool |
| is_ready | bool |
| is_connected | bool |
| last_seen_at | timestamptz |
| joined_at | timestamptz |

**RLS**: solo miembros de la sala pueden leer. Cada usuario solo puede modificar su propio registro.

### `matches`

| Campo | Tipo |
|---|---|
| id | uuid PK |
| room_id | uuid FK rooms |
| status | text (`active`, `finished`, `cancelled`) |
| word | text |
| category | text |
| hints_enabled | bool |
| impostor_count | int |
| duration_seconds | int |
| current_phase | text |
| current_round | int |
| current_turn_index | int |
| starting_player_id | uuid |
| state_version | int |
| created_at | timestamptz |
| updated_at | timestamptz |

**RLS**: solo jugadores del match pueden leer. Solo Edge Functions pueden escribir.

**Nota**: `word` solo se env\u00eda a civiles v\u00eda Edge Function, nunca expuesto directamente al impostor.

### `match_players`

| Campo | Tipo |
|---|---|
| id | uuid PK |
| match_id | uuid FK matches |
| user_id | uuid FK profiles |
| display_name | text |
| seat_order | int |
| role | text (`civil`, `impostor`) |
| hint | text nullable |
| is_eliminated | bool |
| points | int |
| voted_incorrectly | bool |
| eliminated_by_failed_guess | bool |

**RLS**: cada jugador solo puede ver su propio `role`. Todos ven los dem\u00e1s campos.

### `match_clues`

| Campo | Tipo |
|---|---|
| id | uuid PK |
| match_id | uuid FK matches |
| round_number | int |
| player_id | uuid FK match_players |
| turn_order | int |
| clue | text |
| created_at | timestamptz |

### `match_votes`

| Campo | Tipo |
|---|---|
| id | uuid PK |
| match_id | uuid FK matches |
| round_number | int |
| voter_id | uuid FK match_players |
| target_player_id | uuid FK match_players |
| is_tiebreak | bool |
| created_at | timestamptz |

### `room_events` (auditor\u00eda)

| Campo | Tipo |
|---|---|
| id | uuid PK |
| room_id | uuid FK rooms |
| match_id | uuid nullable |
| event_type | text |
| payload | jsonb |
| created_at | timestamptz |

---

## Edge Functions (MVP)

### Sala

| Funci\u00f3n | Descripci\u00f3n |
|---|---|
| `create-room` | Crea sala privada, genera c\u00f3digo de 6 caracteres |
| `join-room` | Valida c\u00f3digo, agrega jugador, verifica l\u00edmite |
| `leave-room` | Remueve jugador, reasigna host si es necesario |
| `start-match` | Valida m\u00ednimo de jugadores, asigna roles/palabra, crea match |

### Juego (Cl\u00e1sico)

| Funci\u00f3n | Descripci\u00f3n |
|---|---|
| `submit-clue` | Valida turno, registra pista, avanza turno |
| `start-voting` | Abre votaci\u00f3n tras completar ronda de pistas |
| `submit-vote` | Registra voto, valida que no vote por s\u00ed mismo |
| `resolve-vote` | Cuenta votos, resuelve empate o elimina jugador |
| `submit-guess` | Impostor eliminado intenta adivinar la palabra |
| `skip-guess` | Impostor eliminado renuncia a adivinar |

Cada Edge Function debe:
1. Verificar auth del usuario
2. Verificar `state_version` (optimistic locking)
3. Validar que la acci\u00f3n corresponde a la fase actual
4. Ejecutar l\u00f3gica de negocio
5. Actualizar estado + incrementar `state_version`
6. Retornar resultado

---

## Realtime

### Canales

- `room:{roomId}` — Presence (qui\u00e9n est\u00e1 conectado) + Broadcast (eventos de lobby)
- `match:{matchId}` — `postgres_changes` en `matches` y `match_players` para sincronizar estado

### Reconexi\u00f3n (integrada desde d\u00eda 1)

- Al reconectar, el cliente consulta el estado actual del match v\u00eda REST
- Compara `state_version` local vs servidor
- Si difieren, reemplaza estado local completo (snapshot)
- Actualiza `is_connected` y `last_seen_at` en `room_players`
- UI muestra indicador "Reconectando..." durante el proceso

### Heartbeat

- El cliente env\u00eda heartbeat cada 30s v\u00eda Presence
- Si un jugador no responde en 90s, se marca como desconectado
- La partida contin\u00faa (no se pausa por un jugador desconectado)
- Si es su turno, se salta autom\u00e1ticamente tras timeout de 60s

---

## Experiencia del producto

### Pantalla inicial

Nuevo selector en el home:

- **Jugar local** \u2192 flujos actuales (sin cambios)
- **Jugar en l\u00ednea** \u2192 secci\u00f3n online

### Flujo online (MVP)

```
Jugar en l\u00ednea
  \u251c\u2500\u2500 Crear sala \u2192 Lobby (compartir c\u00f3digo) \u2192 Configurar \u2192 Iniciar partida
  \u2514\u2500\u2500 Unirse por c\u00f3digo \u2192 Lobby (esperar) \u2192 Partida inicia
```

### Lobby

- Muestra jugadores conectados con indicador de presencia
- Host configura: categor\u00edas, pistas s\u00ed/no, n\u00famero de impostores, duraci\u00f3n
- Jugadores marcan "Listo"
- Host puede iniciar cuando hay 4+ jugadores listos

### Gameplay Cl\u00e1sico online

1. **Reveal privado**: cada jugador ve su rol y palabra (si es civil) en su tel\u00e9fono
2. **Ronda de pistas**: un jugador a la vez escribe su pista. Los dem\u00e1s ven qui\u00e9n est\u00e1 escribiendo + temporizador
3. **Votaci\u00f3n**: todos votan simult\u00e1neamente desde su tel\u00e9fono. Resultados se revelan cuando todos votaron
4. **Eliminaci\u00f3n**: se muestra qui\u00e9n fue eliminado y su rol
5. **Adivinanza**: si el eliminado era impostor, decide si arriesga adivinar
6. **Resultados**: ranking + puntuaci\u00f3n + opci\u00f3n de revancha

---

## Fases de implementaci\u00f3n

### Fase 1: Preparaci\u00f3n de arquitectura

**Objetivo**: preparar la app para soportar online sin tocar el modo local.

**Tareas**:
- Crear estructura de carpetas `features/shared_game/` y `features/online/`
- Extraer reglas puras reutilizables (scoring, validaci\u00f3n de votos) a `shared_game/`
- Agregar selector "Local / En l\u00ednea" en el home
- Crear navegaci\u00f3n base a secci\u00f3n online (pantallas placeholder)

**Criterio de salida**: la app local funciona id\u00e9ntica. Existe la entrada a "En l\u00ednea" con pantalla placeholder.

---

### Fase 2: Supabase + Auth + Seguridad base

**Objetivo**: conectar con Supabase, obtener identidad, definir seguridad.

**Tareas**:
- Agregar `supabase_flutter` al proyecto
- Configurar URL y anon key (variables de entorno, no hardcoded)
- Auth an\u00f3nima autom\u00e1tica al entrar a secci\u00f3n online
- Crear tabla `profiles` con trigger on auth.users insert
- Pantalla de "display name" (obligatorio antes de crear/unirse a sala)
- **Definir RLS en `profiles`** desde el inicio

**Criterio de salida**: el usuario entra a "En l\u00ednea", se autentica an\u00f3nimamente, elige nombre, tiene perfil en Supabase.

---

### Fase 3: Lobby y sala privada

**Objetivo**: crear y unirse a salas privadas con c\u00f3digo.

**Tareas**:
- Crear tablas `rooms` y `room_players` **con RLS**
- Edge Functions: `create-room`, `join-room`, `leave-room`
- UI: crear sala, compartir c\u00f3digo, unirse por c\u00f3digo
- Lobby en tiempo real con Presence (jugadores conectados)
- Ready/unready
- Host puede configurar partida y lanzar cuando 4+ listos
- Reconexi\u00f3n b\u00e1sica al lobby (rejoin si la app se cierra y reabre)

**Criterio de salida**: varios tel\u00e9fonos entran a la misma sala, se ven en tiempo real, el host puede configurar.

---

### Fase 4: Motor de juego autoritativo

**Objetivo**: iniciar partidas online seguras y consistentes.

**Tareas**:
- Crear tablas `matches`, `match_players`, `match_clues`, `match_votes` **con RLS**
- Edge Function `start-match`: asigna roles, palabra, pistas, orden, jugador inicial
- Env\u00edo seguro de rol/palabra a cada cliente (el impostor nunca recibe la palabra)
- Versionado de estado con `state_version` (optimistic locking)
- Sincronizaci\u00f3n de estado v\u00eda Realtime (`postgres_changes` en `matches`)
- Pantalla de reveal de rol (cada jugador ve lo suyo)
- Reconexi\u00f3n: snapshot de estado al reconectar

**Criterio de salida**: todos los clientes reciben su rol y la partida arranca sincronizada. Si un jugador reconecta, recupera el estado correcto.

---

### Fase 5: Gameplay Cl\u00e1sico completo

**Objetivo**: partida cl\u00e1sica online jugable de principio a fin.

**Tareas**:
- Turno de pista escrita: `submit-clue`, `advance-turn` (con timeout de 60s por turno)
- Historial de pistas visible para todos
- Votaci\u00f3n simult\u00e1nea: `start-voting`, `submit-vote`
- Resoluci\u00f3n: `resolve-vote` (empates, segunda votaci\u00f3n)
- Eliminaci\u00f3n + reveal de rol
- Adivinanza del impostor: `submit-guess`, `skip-guess`
- Puntuaci\u00f3n (reutilizar reglas de `shared_game/`)
- Detecci\u00f3n de fin de partida (todos impostores eliminados, o impostores ganan por n\u00fameros)
- Pantalla de resultados online
- Opci\u00f3n "Revancha" (crea nuevo match en la misma sala)
- Tabla `room_events` para auditor\u00eda b\u00e1sica

**Criterio de salida**: se puede jugar una partida cl\u00e1sica online completa entre 4-8 jugadores con resultados correctos.

---

### Fase 6: Pulido y pruebas

**Objetivo**: experiencia lista para pruebas reales.

**Tareas**:
- Heartbeat + manejo de desconexiones durante partida (saltar turno, marcar desconectado)
- UI de estados de espera (esperando a que X escriba, esperando votos, reconectando...)
- Manejo de abandono del host (reasignar o cancelar)
- Filtro b\u00e1sico de palabras ofensivas en pistas y display names
- Cleanup de salas y matches hu\u00e9rfanos (cron job o Edge Function programada)
- Pruebas con m\u00faltiples dispositivos reales
- Pruebas de reconexi\u00f3n (modo avi\u00f3n, cambio de red, app en background)

**Criterio de salida**: la experiencia es estable y jugable con usuarios reales.

---

## Riesgos principales

| Riesgo | Mitigaci\u00f3n |
|---|---|
| Mezclar providers locales con online | Estructura de carpetas separada, no compartir estado |
| Dejar decisiones cr\u00edticas en el cliente | Todo pasa por Edge Functions, `state_version` en cada acci\u00f3n |
| Latencia de Edge Functions (cold starts) | Aceptable para Cl\u00e1sico (turnos lentos). No intentar Express hasta validar |
| Jugador desconectado bloquea la partida | Timeout de 60s por turno + salto autom\u00e1tico |
| Contenido ofensivo en pistas/nombres | Filtro b\u00e1sico de palabras + longitud m\u00e1xima |
| L\u00edmites de Supabase free (200 conexiones) | Suficiente para MVP. Migrar a Pro ($25/mes) si crece |

---

## Fases futuras (post-MVP)

Estas fases se implementar\u00e1n solo despu\u00e9s de validar el MVP con usuarios reales:

1. **Modo Express online** — requiere action locks, pausa global, resoluci\u00f3n de concurrencia
2. **Matchmaking** — cola autom\u00e1tica, emparejamiento por preferencias
3. **Sala de grupo online** — requiere auth real (email/Google), membres\u00eda, permisos
4. **Chat en sala** — mensajes de texto en el lobby y durante discusi\u00f3n
5. **Perfiles avanzados**:
   - Avatares generados con `avatar_seed` (campo ya existe en `profiles`) usando DiceBear o Multiavatar — cada seed produce un avatar \u00fanico y consistente sin necesidad de subir foto
   - Estad\u00edsticas online (partidas jugadas, victorias, racha)
   - Historial de partidas online

---

## C\u00f3mo retomar este plan

Cuando quieras empezar, pide directamente:

- `Empecemos Fase 1 del plan online`
- `Configuremos Supabase`
- `Creemos el lobby de sala privada`
- `Implementemos el motor de juego online`

La implementaci\u00f3n puede continuar fase por fase desde cualquier punto.

---

## Registro de avance

### 2026-04-02 — Fase 1: completada

**Estado**: completada \u2705

**Completado**:
- [x] Estructura de carpetas creada:
  - `lib/features/shared_game/`
  - `lib/features/online/domain/`
  - `lib/features/online/data/`
  - `lib/features/online/application/`
  - `lib/features/online/presentation/`
- [x] Selector "Local / En l\u00ednea" agregado al home (`lib/screens/home/home_screen.dart`)
  - Botones locales existentes se mantienen intactos
  - Nuevo divider visual + bot\u00f3n "Jugar en l\u00ednea" navega a `/online`
- [x] Pantalla placeholder online creada (`lib/features/online/presentation/online_home_screen.dart`)
  - Muestra "Pr\u00f3ximamente" con preview de features del MVP
- [x] Ruta `/online` agregada al router (`lib/router/app_router.dart`)
- [x] Extracci\u00f3n de reglas puras a `shared_game/`:
  - `lib/features/shared_game/scoring.dart` — 6 funciones de puntuaci\u00f3n (Express + Cl\u00e1sico)
  - `lib/features/shared_game/vote_resolution.dart` — conteo de votos, detecci\u00f3n de empates, clase `VoteResult`
  - `lib/features/shared_game/word_matching.dart` — matching de palabra secreta + lista de apellidos permitidos
- [x] `game_provider.dart` actualizado: usa `scoring.*`, `votes.*`, `word_matching.*` v\u00eda imports con alias. Se eliminaron ~90 l\u00edneas de c\u00f3digo duplicado.
- [x] `flutter analyze` sin errores nuevos. App local funciona id\u00e9ntica.

**Notas**:
- Las condiciones de victoria (`allImpostorsFound`, `impostorsWinByNumbers`, `gameOver`) se mantienen como getters en `ActiveGame` (modelo). Ya son puras y no necesitan extracci\u00f3n.
- `text_normalize.dart` se mantiene en `lib/utils/` ya que es un utilitario general. `word_matching.dart` lo importa internamente.
- Pr\u00f3ximo paso: Fase 2 (Supabase + Auth + Seguridad base).

### 2026-04-02 — Fase 2: completada (Supabase + Auth + Seguridad)

**Estado**: completada \u2705

**Configuraci\u00f3n de Supabase (dashboard)**:
- [x] Proyecto creado: `ImpostorApp` en `us-east-2` (Ohio)
- [x] Anonymous Sign-ins habilitado en Authentication → Providers
- [x] Tabla `profiles` creada con RLS habilitado:
  - Pol\u00edticas: select/update/insert restringidos a `auth.uid() = id`
  - Trigger `on_auth_user_created`: crea perfil autom\u00e1ticamente al registrarse

**C\u00f3digo Flutter**:
- [x] `supabase_flutter` agregado como dependencia
- [x] `lib/features/online/data/supabase_config.dart` — URL + anon key via `String.fromEnvironment`, m\u00e9todo `initialize()`, accessor `client`
- [x] `lib/main.dart` — llama `SupabaseConfig.initialize()` antes de `runApp`
- [x] `lib/features/online/application/online_auth_provider.dart` — `onlineAuthProvider` (stream de sesi\u00f3n), `onlineProfileProvider` (AsyncNotifier con `signInAnonymously()` y `updateDisplayName()`)
- [x] `lib/features/online/presentation/display_name_screen.dart` — pantalla para elegir nombre (validaci\u00f3n 2-20 chars, guarda en Supabase, navega a `/online`)
- [x] `lib/features/online/presentation/online_home_screen.dart` — refactorizado: auth autom\u00e1tica al entrar, redirecci\u00f3n a display-name si falta nombre, estados de loading/error/conectado, pill con nombre del usuario
- [x] Ruta `/online/display-name` agregada al router
- [x] `flutter analyze` sin errores.

**Flujo implementado**:
1. Usuario toca "Jugar en l\u00ednea" en el home
2. `OnlineHomeScreen` verifica sesi\u00f3n → si no hay, hace `signInAnonymously()`
3. Si no tiene display name → redirige a `/online/display-name`
4. Usuario escribe su nombre → se guarda en `profiles` → vuelve a `/online`
5. Hub online muestra nombre del usuario + features pr\u00f3ximamente

**Pr\u00f3ximo paso**: Fase 3 (Lobby y sala privada).

### 2026-04-02 â€” Ajuste de estabilidad en Fase 2: restauraci\u00f3n de sesi\u00f3n an\u00f3nima

**Estado**: completado \u2705

**Problema detectado**:
- En el mismo dispositivo, al cerrar y volver a abrir la app, `OnlineHomeScreen` pod\u00eda disparar `signInAnonymously()` demasiado pronto.
- Eso ocurr\u00eda porque la pantalla tomaba un `null` transitorio del perfil como si no existiera sesi\u00f3n.
- Resultado: se creaban usuarios an\u00f3nimos nuevos y filas duplicadas en `profiles` para la misma persona.

**Correcci\u00f3n aplicada**:
- [x] `onlineProfileProvider` ahora depende del estado real de `onlineAuthProvider`
- [x] Se espera a que Supabase termine de restaurar la sesi\u00f3n antes de decidir si hace falta crear una nueva
- [x] `online_home_screen.dart` ya no crea sesi\u00f3n an\u00f3nima solo por ver un `null` temporal del perfil
- [x] `updateDisplayName()` ahora usa `upsert` por `id`
- [x] Si existe sesi\u00f3n pero la fila de `profiles` a\u00fan no aparece, el provider devuelve un perfil temporal con el mismo `id`

**Resultado esperado**:
- En el mismo celular, cerrar y volver a abrir la app debe reutilizar el mismo `user.id`
- Ya no deber\u00edan generarse nuevos registros en `profiles` por una restauraci\u00f3n tard\u00eda de sesi\u00f3n

**Nota de proceso**:
- A partir de aqu\u00ed, todo avance relacionado con el modo online debe quedar documentado al final de esta secci\u00f3n `Registro de avance`.

**Compatibilidad**:
- [x] Ajuste adicional en `online_home_screen.dart` para compatibilidad con Riverpod `3.2.1`
- [x] Se reemplaz\u00f3 el uso de `valueOrNull` por `asData?.value`

### 2026-04-02 - Fase 3: arranque de salas privadas (slice 1)

**Estado**: en progreso 🟡

**Completado**:
- [x] Modelo `OnlineRoom` y `OnlineRoomPlayer` creado en `lib/features/online/domain/online_room.dart`
- [x] Repositorio base `OnlineRoomsRepository` creado en `lib/features/online/data/online_rooms_repository.dart`
  - `createPrivateRoom()`
  - `joinPrivateRoom()`
  - `leaveRoom()`
  - `setReady()`
  - `updateRoomConfig()`
  - streams para sala y jugadores
- [x] Providers online para sala y jugadores:
  - `onlineRoomsRepositoryProvider`
  - `onlineRoomProvider`
  - `onlineRoomPlayersProvider`
- [x] Pantallas nuevas del slice inicial de lobby:
  - `lib/features/online/presentation/online_home_screen.dart`
  - `lib/features/online/presentation/create_room_screen.dart`
  - `lib/features/online/presentation/join_room_screen.dart`
  - `lib/features/online/presentation/room_lobby_screen.dart`
- [x] Rutas agregadas:
  - `/online/create-room`
  - `/online/join-room`
  - `/online/room/:roomId`
- [x] Script SQL inicial documentado en `docs/supabase-phase3-private-rooms.sql`
  - crea `rooms`
  - crea `room_players`
  - agrega indices
  - agrega RLS base de lectura para miembros
  - agrega funciones SQL (`rpc`) para crear/unirse/salir y mutar configuracion

**Alcance real de este slice**:
- Ya se puede entrar al hub online, crear sala privada, unirse por codigo y ver un lobby compartido por tablas/streams.
- El host ya puede ajustar configuracion basica del lobby y los jugadores pueden marcarse como listos.
- Las mutaciones del lobby quedaron preparadas para pasar por funciones SQL (`rpc`) en lugar de inserts/updates directos desde Flutter.

**Pendiente del resto de Fase 3**:
- [ ] Aplicar el SQL en Supabase
- [ ] Realtime Presence real para conectados/desconectados
- [ ] Rejoin automatico del lobby al cerrar y abrir la app
- [ ] Migrar este bootstrap de funciones SQL a Edge Functions cuando empecemos el match autoritativo
- [ ] Boton real de iniciar partida con validaciones del host

**Nota tecnica**:
- Este primer slice de Fase 3 ya evita el problema de RLS al unirse por codigo usando funciones SQL seguras (`rpc`) para crear/unirse/salir y mutar configuracion.
- Flutter escucha streams sobre `rooms` y `room_players` solo despues de que el usuario ya es miembro de la sala.
- La unicidad del codigo de sala se apoya en la restriccion `unique` de la base de datos; el cliente reintenta si se da una colision.
- La logica autoritativa de inicio de partida sigue pendiente y se movera a Edge Functions en los siguientes pasos.

### 2026-04-02 - Ajuste de Fase 3: correccion de RLS en lectura de lobby

**Estado**: completado ✅

**Problema detectado**:
- La sala se creaba correctamente y tambien se insertaba la fila en `room_players`
- Pero al entrar al lobby, las lecturas `GET /rooms` y `GET /room_players` devolvian `500`
- La causa era una recursion de RLS: la policy de `room_players` se consultaba a si misma para validar membresia

**Correccion aplicada**:
- [x] `docs/supabase-phase3-private-rooms.sql` ahora crea la funcion `public.is_room_member(uuid)`
- [x] Las policies de lectura de `rooms` y `room_players` ahora usan esa funcion `security definer`
- [x] Se mantiene el enfoque de `rpc` para mutaciones y RLS para lecturas

**Accion requerida para seguir probando**:
- Volver a ejecutar el script actualizado `docs/supabase-phase3-private-rooms.sql` en Supabase
- Luego repetir la prueba de crear sala y entrar al lobby

### 2026-04-02 - Ajuste de Fase 3: tarjeta de listo del host

**Estado**: completado ✅

**Problema detectado**:
- El host seguia viendo el boton `Quitar` dentro de su tarjeta de estado personal en el lobby
- Ese CTA no era necesario en este slice y se sentia roto o confuso

**Correccion aplicada**:
- [x] `lib/features/online/presentation/room_lobby_screen.dart` ya no muestra el boton `Listo/Quitar` cuando el jugador actual es el host
- [x] El host mantiene visible su tarjeta de estado, pero sin CTA de ready/unready

### 2026-04-02 - Ajuste de Fase 3: estabilidad del lobby y back nativo

**Estado**: completado ✅

**Problemas detectados**:
- El lobby podia parpadear al refrescarse despues de cambios de configuracion
- La duracion online no estaba alineada con el mismo rango del modo local
- El back nativo del dispositivo cerraba la app en vez de abrir confirmacion para salir de la sala

**Correccion aplicada**:
- [x] `lib/features/online/presentation/room_lobby_screen.dart` ahora conserva el ultimo estado conocido del lobby mientras los streams se recargan, reduciendo el efecto de refresh visual
- [x] La configuracion de duracion online se alineo con local:
  - presets de `1, 2, 3, 5, 10 y 15 min`
  - slider desde `60s` hasta `900s`
- [x] El lobby ahora intercepta el back nativo con `PopScope` y usa el mismo modal de confirmacion para salir de la sala

### 2026-04-02 - Ajuste de Fase 3: sincronizacion del lobby y refresh de acciones

**Estado**: completado âœ…

**Problemas detectados**:
- Un jugador podia unirse y no aparecer enseguida en la vista del host
- El boton `Listo` podia no reflejar el cambio de inmediato
- Los cambios del host en la configuracion del lobby dependian por completo de la propagacion remota

**Correccion aplicada**:
- [x] `docs/supabase-phase3-private-rooms.sql` ahora agrega `rooms` y `room_players` a la publicacion `supabase_realtime`
- [x] Se establecio `replica identity full` en ambas tablas para mejorar la emision de cambios
- [x] `lib/features/online/presentation/room_lobby_screen.dart` ahora invalida `onlineRoomProvider` y `onlineRoomPlayersProvider` despues de:
  - marcar listo / quitar listo
  - cambiar categorias
  - cambiar pistas
  - cambiar cantidad de impostores
  - cambiar duracion
- [x] Se unifico el manejo del back del lobby en un helper comun para que la flecha superior y el back nativo sigan exactamente la misma ruta de confirmacion

**Accion requerida para seguir probando**:
- Volver a ejecutar `docs/supabase-phase3-private-rooms.sql` en Supabase para que `rooms` y `room_players` queden publicados en Realtime

### 2026-04-02 - Ajuste de Fase 3: configuracion optimista del host en el lobby

**Estado**: completado âœ…

**Problema detectado**:
- La configuracion del lobby se sentia lenta porque el host esperaba el round-trip a Supabase para ver cada cambio aplicado
- El look and feel se degradaba cuando se tocaban categorias, pistas, impostores o duracion

**Correccion aplicada**:
- [x] `lib/features/online/presentation/room_lobby_screen.dart` ahora mantiene una copia local optimista de la configuracion del lobby para el host
- [x] Los cambios del host se reflejan de inmediato en pantalla y luego se sincronizan en segundo plano con Supabase
- [x] La sincronizacion se hace con debounce corto para evitar rafagas de escrituras, especialmente con el slider
- [x] Se agrego un indicador visual de `Sincronizando cambios...` mientras hay escritura pendiente o en vuelo
- [x] Se dejo un refresh periodico liviano del lobby como red de seguridad mientras terminamos la migracion a Presence/Broadcast real

**Decision tecnica vigente**:
- Para el lobby online, lo correcto es separar:
  - experiencia instantanea del host (estado local optimista)
  - persistencia autoritativa (Postgres / RPC)
  - sincronizacion visible para otros jugadores
- En el siguiente bloque de Fase 3 conviene mover la presencia de jugadores y los cambios efimeros del lobby hacia Presence/Broadcast, dejando Postgres como fuente autoritativa y de recuperacion

### 2026-04-02 - Refinamiento de Fase 3: reconciliacion optimista sin rollback visual

**Estado**: completado âœ…

**Problema detectado**:
- El host ya veia los cambios al instante, pero la UI podia volver momentaneamente al valor anterior antes de asentarse en el nuevo
- El ejemplo reportado fue la duracion: `2 min -> 10 min -> 2 min -> 10 min`

**Correccion aplicada**:
- [x] `lib/features/online/presentation/room_lobby_screen.dart` ahora mantiene la configuracion optimista del host hasta que el estado remoto confirme exactamente esos mismos valores
- [x] Los snapshots viejos del servidor ya no pisan la configuracion local pendiente de confirmacion
- [x] El refresh periodico del lobby se mantiene solo sobre la lista de jugadores como red de seguridad, no sobre la configuracion del room

**Resultado esperado**:
- Para el host, cambiar configuracion debe sentirse como una pantalla local: seleccion inmediata, sin rebotes visuales al valor anterior

### 2026-04-02 - Ajuste de Fase 3: sincronizacion visible para participantes

**Estado**: completado âœ…

**Problema detectado**:
- Al refinar la experiencia optimista del host, los participantes dejaron de ver en su lobby los cambios de configuracion hechos por el host
- El label `Sincronizando cambios...` tambien agregaba ruido visual innecesario

**Correccion aplicada**:
- [x] `lib/features/online/presentation/room_lobby_screen.dart` vuelve a refrescar tanto `onlineRoomProvider` como `onlineRoomPlayersProvider` en el polling ligero del lobby
- [x] El intervalo del refresh de seguridad del lobby se ajusto a `1s` para que los participantes vean antes los cambios del host
- [x] Se elimino el label visual `Sincronizando cambios...`

**Decision tecnica vigente**:
- Este polling ligero sigue siendo una solucion transitoria para el lobby
- La direccion correcta del siguiente bloque sigue siendo migrar presencia y cambios efimeros del lobby hacia `Presence/Broadcast`, dejando Postgres como fuente autoritativa y de recuperacion

### 2026-04-02 - Migracion parcial de Fase 3: Presence y Broadcast para el lobby

**Estado**: completado âœ…

**Objetivo**:
- Dejar de depender del polling como mecanismo principal de sincronizacion del lobby
- Mantener Postgres como fuente autoritativa, pero usar Realtime como capa de senales de bajo atraso

**Correccion aplicada**:
- [x] Se creo `lib/features/online/application/online_lobby_sync_provider.dart`
- [x] El lobby ahora abre un canal realtime `room-lobby:<roomId>`
- [x] `Presence` se usa para detectar entradas y salidas del lobby e invalidar la lista de jugadores
- [x] `Broadcast` se usa para:
  - propagar cambios de configuracion del host
  - propagar cambios de `Listo / Quitar listo`
- [x] `lib/features/online/presentation/room_lobby_screen.dart` ya no usa polling periodico del lobby
- [x] El estado optimista del host se mantiene, pero los demas participantes reciben las senales del canal para refrescar su vista sin depender de refresh constante

**Arquitectura vigente del lobby**:
- UI del host: optimista y local
- Realtime:
  - `Presence` para membresia / conectados
  - `Broadcast` para eventos efimeros del lobby
- Postgres / RPC:
  - fuente autoritativa
  - persistencia
  - recuperacion al recargar o reconectar

### 2026-04-02 - Hardening de Fase 3: TTL de salas privadas

**Estado**: completado âœ…

**Objetivo**:
- Evitar que `rooms` y `room_players` acumulen basura de lobbies abandonados o pruebas viejas

**Correccion aplicada**:
- [x] `docs/supabase-phase3-private-rooms.sql` ahora agrega `expires_at` a `rooms`
- [x] `docs/supabase-phase3-private-rooms.sql` ahora agrega `expires_at` a `room_players`
- [x] La expiracion queda fijada a `1 dia` desde la creacion de la sala
- [x] `room_players.expires_at` se alinea con la expiracion de su `room`
- [x] Se agrego la funcion `public.cleanup_expired_private_rooms()`
- [x] Se programo un job con `pg_cron` para ejecutar la limpieza cada hora
- [x] Al borrar una `room`, sus `room_players` se eliminan por cascada

**Decision tecnica**:
- El TTL no se resuelve solo con un campo en la tabla
- La solucion correcta es:
  - guardar `expires_at`
  - indexarlo
  - ejecutar una limpieza programada

**Accion requerida**:
- Re-ejecutar `docs/supabase-phase3-private-rooms.sql` en Supabase para crear las columnas nuevas y el job de limpieza
