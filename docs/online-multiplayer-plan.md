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
5. **Perfiles avanzados** — avatares, estad\u00edsticas online, historial

---

## C\u00f3mo retomar este plan

Cuando quieras empezar, pide directamente:

- `Empecemos Fase 1 del plan online`
- `Configuremos Supabase`
- `Creemos el lobby de sala privada`
- `Implementemos el motor de juego online`

La implementaci\u00f3n puede continuar fase por fase desde cualquier punto.
