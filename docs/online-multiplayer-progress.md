# Yeison Impostor - Registro de avance online

Este documento concentra el historial de implementacion del modo online.

Plan principal:
- `docs/online-multiplayer-plan.md`

## Registro de avance

### 2026-04-02 â€” Fase 1: completada

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
  - `lib/features/shared_game/scoring.dart` â€” 6 funciones de puntuaci\u00f3n (Express + Cl\u00e1sico)
  - `lib/features/shared_game/vote_resolution.dart` â€” conteo de votos, detecci\u00f3n de empates, clase `VoteResult`
  - `lib/features/shared_game/word_matching.dart` â€” matching de palabra secreta + lista de apellidos permitidos
- [x] `game_provider.dart` actualizado: usa `scoring.*`, `votes.*`, `word_matching.*` v\u00eda imports con alias. Se eliminaron ~90 l\u00edneas de c\u00f3digo duplicado.
- [x] `flutter analyze` sin errores nuevos. App local funciona id\u00e9ntica.

**Notas**:
- Las condiciones de victoria (`allImpostorsFound`, `impostorsWinByNumbers`, `gameOver`) se mantienen como getters en `ActiveGame` (modelo). Ya son puras y no necesitan extracci\u00f3n.
- `text_normalize.dart` se mantiene en `lib/utils/` ya que es un utilitario general. `word_matching.dart` lo importa internamente.
- Pr\u00f3ximo paso: Fase 2 (Supabase + Auth + Seguridad base).

### 2026-04-02 â€” Fase 2: completada (Supabase + Auth + Seguridad)

**Estado**: completada \u2705

**Configuraci\u00f3n de Supabase (dashboard)**:
- [x] Proyecto creado: `ImpostorApp` en `us-east-2` (Ohio)
- [x] Anonymous Sign-ins habilitado en Authentication â†’ Providers
- [x] Tabla `profiles` creada con RLS habilitado:
  - Pol\u00edticas: select/update/insert restringidos a `auth.uid() = id`
  - Trigger `on_auth_user_created`: crea perfil autom\u00e1ticamente al registrarse

**C\u00f3digo Flutter**:
- [x] `supabase_flutter` agregado como dependencia
- [x] `lib/features/online/data/supabase_config.dart` â€” URL + anon key via `String.fromEnvironment`, m\u00e9todo `initialize()`, accessor `client`
- [x] `lib/main.dart` â€” llama `SupabaseConfig.initialize()` antes de `runApp`
- [x] `lib/features/online/application/online_auth_provider.dart` â€” `onlineAuthProvider` (stream de sesi\u00f3n), `onlineProfileProvider` (AsyncNotifier con `signInAnonymously()` y `updateDisplayName()`)
- [x] `lib/features/online/presentation/display_name_screen.dart` â€” pantalla para elegir nombre (validaci\u00f3n 2-20 chars, guarda en Supabase, navega a `/online`)
- [x] `lib/features/online/presentation/online_home_screen.dart` â€” refactorizado: auth autom\u00e1tica al entrar, redirecci\u00f3n a display-name si falta nombre, estados de loading/error/conectado, pill con nombre del usuario
- [x] Ruta `/online/display-name` agregada al router
- [x] `flutter analyze` sin errores.

**Flujo implementado**:
1. Usuario toca "Jugar en l\u00ednea" en el home
2. `OnlineHomeScreen` verifica sesi\u00f3n â†’ si no hay, hace `signInAnonymously()`
3. Si no tiene display name â†’ redirige a `/online/display-name`
4. Usuario escribe su nombre â†’ se guarda en `profiles` â†’ vuelve a `/online`
5. Hub online muestra nombre del usuario + features pr\u00f3ximamente

**Pr\u00f3ximo paso**: Fase 3 (Lobby y sala privada).

### 2026-04-02 Ã¢â‚¬â€ Ajuste de estabilidad en Fase 2: restauraci\u00f3n de sesi\u00f3n an\u00f3nima

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

**Estado**: en progreso ðŸŸ¡

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

**Estado**: completado âœ…

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

**Estado**: completado âœ…

**Problema detectado**:
- El host seguia viendo el boton `Quitar` dentro de su tarjeta de estado personal en el lobby
- Ese CTA no era necesario en este slice y se sentia roto o confuso

**Correccion aplicada**:
- [x] `lib/features/online/presentation/room_lobby_screen.dart` ya no muestra el boton `Listo/Quitar` cuando el jugador actual es el host
- [x] El host mantiene visible su tarjeta de estado, pero sin CTA de ready/unready

### 2026-04-02 - Ajuste de Fase 3: estabilidad del lobby y back nativo

**Estado**: completado âœ…

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

**Estado**: completado Ã¢Å“â€¦

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

**Estado**: completado Ã¢Å“â€¦

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

**Estado**: completado Ã¢Å“â€¦

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

**Estado**: completado Ã¢Å“â€¦

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

**Estado**: completado Ã¢Å“â€¦

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

**Estado**: completado Ã¢Å“â€¦

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

### 2026-04-02 - Refactor visual de Fase 3: lobby privado alineado con el juego local

**Estado**: completado ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦

**Objetivo**:
- Hacer que las pantallas del lobby privado se sientan parte natural de `Yeison Impostor`
- Alinear host y participantes con el mismo lenguaje visual del setup y gameplay local

**Cambios aplicados**:
- [x] `lib/features/online/presentation/room_lobby_screen.dart` ahora usa una cabecera hero con codigo de sala, progreso de listos y chips de estado al estilo del juego local
- [x] La configuracion del lobby se rediseÃƒÂ±o para reutilizar el mismo vocabulario visual del setup local:
  - `CategorySection`
  - `ImpostorCountSection`
  - `HintsToggle`
  - `TimerSection`
- [x] La lista de jugadores se rehizo con tarjetas mÃƒÂ¡s cercanas al look del resto de la app, incluyendo badges de `Host`, `Listo` y `Tu`
- [x] La acciÃƒÂ³n inferior del lobby ahora se presenta como CTA fija tipo setup/gameplay:
  - host: estado de inicio online prÃƒÂ³ximamente
  - participante: `Estoy listo / Quitar listo`

**Decision de UX**:
- El host conserva experiencia optimista/local en la configuracion
- Los participantes ven una versiÃƒÂ³n visualmente consistente de esa configuracion, pero en modo solo lectura
- El lobby deja de sentirse como una pantalla administrativa separada y pasa a verse como parte del flujo principal del juego

### 2026-04-02 - Ajuste UX de Fase 3: mensajes limpios de errores online

**Estado**: completado ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦

**Problema detectado**:
- Algunas pantallas online estaban mostrando texto crudo de Supabase como `PostgrestException(...)`
- Eso exponia detalles tecnicos innecesarios a la UI

**Correccion aplicada**:
- [x] `lib/features/online/data/online_rooms_repository.dart` ahora traduce los `PostgrestException` a mensajes amigables antes de propagarlos
- [x] Crear sala, unirse por codigo, marcar listo, actualizar configuracion y salir de sala ya devuelven solo la descripcion funcional del error

**Resultado esperado**:
- Cuando falle un join por codigo inexistente o un RPC similar, la pantalla debe mostrar solo el mensaje legible
- Ejemplo: `No existe una sala con ese codigo`

### 2026-04-02 - Mantenimiento de documentacion: registro separado del plan principal

**Estado**: completado

**Cambio aplicado**:
- [x] El historial detallado del modo online se movio a `docs/online-multiplayer-progress.md`
- [x] `docs/online-multiplayer-plan.md` queda como hoja de ruta principal y este archivo pasa a ser el changelog oficial

### 2026-04-02 - Refactor arquitectonico de Fase 3: extraccion de RoomLobbyNotifier

**Estado**: completado

**Problema detectado**:
- `room_lobby_screen.dart` tenia 1236 lineas con 14 flags de estado mutable manejados con `setState`
- Logica de negocio (sync optimista, debounce, ready, leave) mezclada con UI
- Triple `.when()` anidado en el metodo `build`
- Modelos de dominio sin `==`/`hashCode`, causando rebuilds innecesarios

**Cambios aplicados**:
- [x] `lib/features/online/domain/online_room.dart`:
  - `OnlineRoom` y `OnlineRoomPlayer` ahora tienen `==` y `hashCode`
  - `_parseGameMode` default corregido de `express` a `classic` (alineado con schema SQL)
- [x] Nuevo `lib/features/online/application/room_lobby_notifier.dart`:
  - `RoomLobbyState` inmutable con `copyWith`
  - `RoomLobbyNotifier` como `AsyncNotifier` con family provider
  - Combina los 3 streams (profile, room, players) en un solo estado
  - Maneja: `toggleReady()`, `updateConfig()`, `leaveRoom()`
  - Timer de debounce interno (220ms) para config sync
  - Reconciliacion optimista (`_roomMatchesDraft`, `_sameCategories`)
- [x] `lib/features/online/presentation/room_lobby_screen.dart` refactorizado:
  - De `ConsumerStatefulWidget` (1236 lineas) a `ConsumerWidget` (~290 lineas)
  - Un solo `.when()` en el build
  - Errores propagados via `ref.listen` + snackbar
  - Acciones delegadas al notifier
- [x] Widgets extraidos a `lib/features/online/presentation/widgets/`:
  - `lobby_code_card.dart` — cabecera hero con codigo, badges, progreso
  - `lobby_config_card.dart` — configuracion reutilizando widgets del setup local
  - `lobby_players_section.dart` — lista de jugadores con tiles
  - `lobby_start_bar.dart` — barra inferior con CTA de listo/inicio
- [x] `docs/supabase-phase3-private-rooms.sql`:
  - `join_private_room`: agregado `FOR UPDATE` al SELECT de la sala para prevenir race condition en joins concurrentes
  - `set_room_ready`: agregado guard `AND EXISTS (... status = 'waiting')` para evitar cambios en salas que ya arrancaron
- [x] `flutter analyze` sin errores nuevos

**Resultado**:
- El lobby screen paso de ~1236 lineas a ~290 lineas
- Toda la logica de negocio vive en el notifier, testeable de forma independiente
- Los widgets extraidos son reutilizables y auto-contenidos
- Los modelos con `==`/`hashCode` evitan rebuilds innecesarios de los streams

**Accion requerida**:
- Re-ejecutar las funciones `join_private_room` y `set_room_ready` del SQL actualizado en Supabase

### 2026-04-02 - Cierre de Fase 3: Presence sync + rejoin automatico

**Estado**: completado

**Objetivo**:
- Cerrar los dos items pendientes de Fase 3 antes de pasar a Fase 4

**Cambios aplicados**:

*Presence -> is_connected*:
- [x] Nueva funcion SQL `set_player_connected(room_id, connected)` en `docs/supabase-phase3-private-rooms.sql`
  - Actualiza `is_connected` y `last_seen_at` para el jugador actual en la sala
- [x] `OnlineRoomsRepository` — nuevo metodo `setPlayerConnected()`
- [x] `OnlineLobbySyncController` ahora:
  - Llama `setPlayerConnected(true)` al suscribirse al canal Realtime
  - Llama `setPlayerConnected(false)` al hacer dispose (salir del lobby o cerrar app)
  - El indicador de conexion en la lista de jugadores ahora refleja el estado real en DB

*Rejoin automatico al lobby*:
- [x] Nueva funcion SQL `get_my_active_room()` en `docs/supabase-phase3-private-rooms.sql`
  - Busca la sala mas reciente del usuario con status `waiting` o `playing`
- [x] `OnlineRoomsRepository` — nuevo metodo `getMyActiveRoom()`
- [x] Nuevo `myActiveRoomProvider` en `online_rooms_provider.dart`
- [x] `OnlineHomeScreen` ahora consulta `myActiveRoomProvider` al cargar
  - Si hay sala activa, redirige automaticamente a `/online/room/:roomId`
  - Si no hay, muestra el hub normal (crear/unirse)
- [x] `flutter analyze` sin errores nuevos

**Accion requerida**:
- Ejecutar las funciones `set_player_connected` y `get_my_active_room` en Supabase

---

## Estado de la Fase 3: COMPLETADA

Todos los items de la Fase 3 estan implementados:
- [x] Tablas `rooms` y `room_players` con RLS
- [x] RPCs: create, join, leave, ready, config, connection status, active room
- [x] UI: crear sala, unirse por codigo, lobby completo
- [x] Realtime: Presence + Broadcast para sincronizacion
- [x] Configuracion optimista del host con debounce
- [x] TTL de salas + limpieza por pg_cron
- [x] Presencia real (is_connected via Presence events)
- [x] Rejoin automatico al lobby
- [x] Refactor arquitectonico (RoomLobbyNotifier + widgets extraidos)
- [x] Race condition fixes en SQL

**Proximo paso**: Fase 4 slice 2 (pantalla de reveal de rol + Realtime sync del match + reconexion)

### 2026-04-03 - Fase 4 slice 1: esquema de match + start-match + boton de inicio

**Estado**: completado

**Objetivo**:
- Crear la infraestructura de base de datos y codigo Flutter necesaria para iniciar partidas online desde el lobby

**Cambios aplicados**:

*SQL — nuevo archivo `docs/supabase-phase4-match-engine.sql`*:
- [x] Tabla `matches`: estado de la partida, fase actual, ronda, turno, state_version (optimistic locking)
- [x] Tabla `match_players`: rol, hint, eliminacion, puntos por jugador
- [x] Tabla `match_clues`: pistas por ronda y turno
- [x] Tabla `match_votes`: votos por ronda, soporte para desempate
- [x] Indices en las 4 tablas
- [x] RLS habilitado en las 4 tablas con helper `is_match_player()`
- [x] Realtime habilitado para `matches` y `match_players` con `replica identity full`
- [x] RPC `start_match`: recibe word/category/hints/impostor_indices desde Flutter, valida permisos del host, cuenta de jugadores listos, crea match + match_players, asigna roles/hints, elige starting player (civil), transiciona room a `playing`
- [x] RPC `get_my_match_state`: devuelve el estado del match desde la perspectiva del jugador actual (rol propio, hint propia, palabra solo para civiles)
- [x] Grants para authenticated

*Modelos Dart — nuevo `lib/features/online/domain/online_match.dart`*:
- [x] `OnlineMatch` con `fromMap`, `==`/`hashCode`
- [x] `OnlineMatchPlayer` con `fromMap`, `==`/`hashCode`, getters `isImpostor`/`isCivil`
- [x] `MyMatchState` — vista personalizada del match por jugador (palabra null para impostores)
- [x] Enums `OnlineMatchStatus` y `OnlineMatchPhase` con parsing bidireccional

*Repository — nuevo `lib/features/online/data/online_match_repository.dart`*:
- [x] `startMatch()`: elige palabra aleatoria (WordBank), genera impostor indices, calcula hints, llama RPC
- [x] `getMyMatchState()`: llama RPC y parsea `MyMatchState`
- [x] `watchMatch()` / `watchMatchPlayers()`: streams Realtime
- [x] `getActiveMatchForRoom()`: busca match activo por room ID

*Providers — nuevo `lib/features/online/application/online_match_provider.dart`*:
- [x] `onlineMatchRepositoryProvider`
- [x] `onlineMatchProvider` (StreamProvider.family)
- [x] `onlineMatchPlayersProvider` (StreamProvider.family)
- [x] `myMatchStateProvider` (FutureProvider.autoDispose.family)

*Lobby — boton de inicio*:
- [x] `RoomLobbyNotifier` — nuevo metodo `startMatch()` con flag `isStarting`
- [x] `LobbyStartBar` — boton del host ahora dice "Iniciar partida" cuando hay suficientes jugadores listos, con loading state y spinner
- [x] Navegacion al match pendiente (TODO) hasta que exista la pantalla de juego

*Correccion local — bug de pistas repetidas*:
- [x] `WordBank.getHardHints()` ya no repite pistas cuando hay 3 o menos impostores (usa las 3 hints completas en vez de skip(1))

- [x] `flutter analyze` sin errores nuevos

**Accion requerida**:
- Ejecutar `docs/supabase-phase4-match-engine.sql` completo en Supabase

**Pendiente para slice 2** (proxima sesion):
- [x] Pantalla de reveal de rol (cada jugador ve su rol/palabra en su telefono)
- [x] Realtime sync del match via `postgres_changes`
- [x] Reconexion: snapshot de estado al reconectar
- [x] Navegacion real desde lobby a match screen

### 2026-04-03 - Fase 4 slice 2: pantalla de match + navegacion + reconexion

**Estado**: completado

**Objetivo**:
- Completar el flujo end-to-end: lobby -> start match -> role reveal en cada dispositivo
- Reconexion automatica a match activo

**Cambios aplicados**:

*Pantalla de match — nuevo `lib/features/online/presentation/online_match_screen.dart`*:
- [x] Pantalla `OnlineMatchScreen` con routing por matchId
- [x] Role reveal: diferencia visual entre Civil (primaryColor) e Impostor (secondaryColor)
  - Civiles ven la palabra secreta + categoria
  - Impostores ven su pista (o "Sin pista" si hints deshabilitadas) + categoria
  - Badges con info del match (cantidad de impostores, duracion)
  - Textos contextuales de estrategia para cada rol
  - Boton "Entendido" (pendiente conexion a avance de fase en Fase 5)
- [x] Placeholder para fases futuras (clue_writing, voting, etc.)
- [x] Manejo de error de carga

*Ruta — actualizado `lib/router/app_router.dart`*:
- [x] Nueva ruta `/online/match/:matchId` -> `OnlineMatchScreen`

*Navegacion lobby -> match*:
- [x] Host: al iniciar partida exitosamente, navega a `/online/match/$matchId`
- [x] Participantes: listener en el lobby detecta transicion de room `waiting` -> `playing`, busca match activo, y navega automaticamente
- [x] `room_lobby_screen.dart` — nuevo metodo `_navigateToActiveMatch` que consulta `getActiveMatchForRoom`

*Reconexion a match activo*:
- [x] `online_home_screen.dart` — `_resolveActiveRoomRedirect` ahora:
  - Si la sala activa tiene un match en curso -> navega directo a `/online/match/$matchId`
  - Si no tiene match (solo lobby) -> navega al lobby como antes
- [x] Flujo: abrir app -> /online -> detecta sala activa -> detecta match activo -> role reveal

*Realtime sync*:
- [x] `onlineMatchProvider` (StreamProvider) escucha cambios en tabla `matches` via Realtime
- [x] `onlineMatchPlayersProvider` (StreamProvider) escucha cambios en `match_players`
- [x] Tablas ya estan en `supabase_realtime` publication con `replica identity full` (del slice 1)

- [x] `flutter analyze` sin errores nuevos

**Pendiente de pulido visual** (pase posterior a Fase 5):
- [ ] Role reveal: animacion de suspense (scale-up 0.8->1.0 + fade-in 300ms)
- [ ] Role reveal: delay de 1s con "Revelando tu rol..." antes de mostrar contenido (shimmer/pulse en borde del card)
- [ ] Role reveal: glow animado en borde del card con color del rol (green civil, coral impostor)
- [ ] Role reveal: boton "Entendido" aparece con fade-in despues de la animacion
- [ ] Role reveal: skip animaciones si es reconexion (mostrar rol inmediato + toast "Reconectado")
- [ ] Role reveal: estado "Esperando a los demas..." si el jugador ya confirmo
- [ ] Revision de ortografia general (tildes, mayusculas, textos consistentes)
- [ ] Categorias mostradas en mayusculas donde corresponda
- [ ] Uso de imagenes/assets existentes en pantallas online (assets/)
- [ ] Clue writing: lista de orden de turnos con estados (done/current/pending) en el estado de espera
- [ ] Clue writing: pulsing dots en "Esperando a [nombre]..." para feedback de liveness
- [ ] Clue writing: auto-focus del TextField al entrar en tu turno
- [ ] Clue writing: ancho maximo 480px centrado para web (responsive)
- [ ] Voting: grid de 2 columnas para los jugadores votables en vez de lista vertical
- [ ] Voting: vote map visual con flechas (avatar -> arrow -> target) en resultado
- [ ] Voting: badge "Tu voto" sobre el jugador elegido en estado de espera
- [ ] Voting: pulsing dots en el contador de votos mientras se espera
- [ ] Limpieza de matches: agregar ON DELETE CASCADE en `matches.room_id` para que al borrar una sala se eliminen matches, match_players, match_clues y match_votes asociados

**Proximo paso**: Fase 5 (Gameplay Clasico completo — pistas, votacion, resultados)

### 2026-04-03 - Modal de sala activa (UX improvement)

**Estado**: completado ✅

**Problema detectado**:
- Cuando un usuario ya tenia una sala activa (waiting/playing), se le redirigía automaticamente sin opción de salir
- El usuario queria poder elegir entre continuar en la sala o salir y empezar de nuevo

**Implementacion**:
- [x] `lib/features/online/presentation/widgets/active_room_dialog.dart` — nuevo dialog con:
  - Deteccion automatica de estado (lobby abierto vs partida en curso)
  - Icono y textos contextuales segun estado
  - Boton "Continuar" (primario) para volver a la sala/partida
  - Boton "Salir" con patron "tap again to confirm" para evitar salidas accidentales
- [x] `lib/features/online/presentation/online_home_screen.dart` — `_resolveActiveRoomRedirect` ahora muestra el dialog en vez de redirigir automaticamente
  - "Continuar" navega al lobby o match segun corresponda
  - "Salir" llama `leaveRoom` y refresca el estado
  - Dismiss (back) permite quedarse en home sin redireccion

### 2026-04-03 - Kick player (host-only)

**Estado**: completado ✅

**Implementacion**:
- [x] `docs/supabase-phase3-private-rooms.sql` — nueva funcion `kick_player(room_id, target_user_id)`:
  - Solo el host puede expulsar, solo en status `waiting`
  - Valida que el target no sea el host mismo
  - Elimina la fila de `room_players`
- [x] `lib/features/online/data/online_rooms_repository.dart` — metodo `kickPlayer()`
- [x] `lib/features/online/application/room_lobby_notifier.dart` — metodo `kickPlayer()` expuesto al UI
- [x] `lib/features/online/presentation/widgets/lobby_players_section.dart` — boton "Expulsar" visible solo para el host en jugadores no-host, con modal de confirmacion

### 2026-04-03 - Back nativo protegido en pantallas online

**Estado**: completado ✅

**Problema**: el back nativo del dispositivo sacaba por completo de la partida online sin confirmacion.

**Correccion**:
- [x] `lib/features/online/presentation/online_match_screen.dart` — `PopScope(canPop: false)` + modal de confirmacion "Salir de la partida" antes de volver a `/online`
- [x] Se agrego boton de back en el AppBar del match screen (antes no tenia)
- [x] El lobby ya tenia `PopScope` con confirmacion (sin cambios)

### 2026-04-03 - Logica de abandono en partida (sin timeout de gracia)

**Estado**: completado ✅

**Escenarios cubiertos**:
1. Salida intencional (confirma modal "Salir") -> llama `abandon_match` RPC -> navega a home
2. Cierre de app / background -> `WidgetsBindingObserver.didChangeAppLifecycleState` llama `abandon_match` automaticamente
3. Los jugadores restantes detectan via Realtime:
   - Si la partida fue cancelada -> pantalla "Partida cancelada" + boton "Volver al inicio"
   - Si un jugador fue eliminado -> `state_version` sube, UI refleja el cambio
4. Reconexion post-eliminacion -> match screen muestra pantalla "Fuiste eliminado" + boton "Volver al inicio"

**SQL**:
- [x] `docs/supabase-phase4-match-engine.sql` — nueva funcion `abandon_match(match_id)`:
  - Marca al jugador como `is_eliminated = true`
  - Verifica viabilidad: < 3 activos, o 0 impostores, o 0 civiles -> cancela la partida
  - Si cancela: `matches.status = 'cancelled'`, `rooms.status = 'waiting'`
  - Si no cancela: solo incrementa `state_version` para notificar via Realtime
  - Retorna `{ cancelled: bool }`

**Dart**:
- [x] `lib/features/online/data/online_match_repository.dart` — metodo `abandonMatch(matchId)`
- [x] `lib/features/online/presentation/online_match_screen.dart`:
  - Convertido de `ConsumerWidget` a `ConsumerStatefulWidget`
  - `WidgetsBindingObserver` para detectar `paused`/`detached` -> abandon automatico
  - `ref.listen` en `onlineMatchProvider` para detectar `cancelled` via Realtime
  - `ref.listen` en `myMatchStateProvider` para detectar auto-eliminacion
  - Pantallas dedicadas: `_buildCancelled()` y `_buildEliminated()` con boton de salida
  - Modal de confirmacion actualizado con texto informativo sobre consecuencias

### 2026-04-03 - Fase 5 Slice 1: Confirmacion de rol + escritura de pistas

**Estado**: completado ✅

**SQL** (`docs/supabase-phase5-slice1-clues.sql` — nuevo archivo):
- [x] `alter table match_players add column role_confirmed boolean`
- [x] Realtime habilitado para `match_clues`
- [x] RLS insert policy para `match_clues`
- [x] RPC `confirm_role_reveal(match_id)`:
  - Marca al jugador como `role_confirmed = true`
  - Cuando todos los activos confirman -> avanza a fase `clue_writing`
  - `current_turn_index` se setea al `seat_order` del `starting_player`
- [x] RPC `submit_clue(match_id, clue)`:
  - Valida turno, max 50 chars, no duplicados
  - Inserta en `match_clues`, avanza `current_turn_index` al siguiente activo
  - Si era el ultimo -> avanza a fase `voting`
- [x] RPC `skip_clue_turn(match_id)`:
  - Salta turno actual (timeout o skip manual)
  - Misma logica de avance que `submit_clue`

**Domain**:
- [x] `OnlineMatchClue` — nuevo modelo con `fromMap`, `==`, `hashCode`
- [x] `OnlineMatchPlayer.roleConfirmed` — campo agregado

**Repository**:
- [x] `confirmRoleReveal()`, `submitClue()`, `skipClueTurn()`, `watchMatchClues()`

**Providers**:
- [x] `onlineMatchCluesProvider` — StreamProvider.family para clues via Realtime

**UI**:
- [x] Boton "Entendido" en role reveal ahora llama `confirm_role_reveal` RPC
- [x] Estado "Esperando a los demas..." despues de confirmar
- [x] `lib/features/online/presentation/widgets/clue_writing_phase.dart` — nuevo widget:
  - Header con indicador de turno + timer de 30s (colores dinamicos: normal/warning/error)
  - Recordatorio de rol (palabra para civiles, pista para impostores)
  - Lista de pistas ya escritas (avatar + nombre + pista)
  - Input de pista (TextField + boton enviar) cuando es tu turno
  - Estado de espera "Esperando a [nombre]..." cuando no es tu turno
  - Timeout auto-skip cuando el timer llega a 0
- [x] Match screen: `_buildClueWriting()` redirige al widget

### 2026-04-03 - Fase 5 Slice 2: Votacion + resolucion + eliminacion

**Estado**: completado ✅

**SQL** (`docs/supabase-phase5-slice2-voting.sql` — nuevo archivo):
- [x] Realtime habilitado para `match_votes`
- [x] RLS insert policy para `match_votes`
- [x] RPC `submit_vote(match_id, target_player_id)`:
  - Votacion simultanea (no secuencial)
  - Valida: no self-vote, no eliminados, no duplicado en ronda
  - Cuando todos votan -> avanza a fase `vote_result`
  - Soporta tiebreaker (segunda ronda de votos)
- [x] RPC `resolve_votes(match_id)`:
  - Cuenta votos, detecta empate vs eliminacion
  - Si empate (primera ronda): vuelve a `voting` para tiebreaker
  - Si empate en tiebreaker: elimina al primero (no loops infinitos)
  - Elimina jugador, revela rol, marca voted_incorrectly si votaron civil
  - Chequea condiciones de fin: 0 impostores = civiles ganan, impostores >= civiles = impostores ganan
  - Si impostor eliminado y quedan mas: avanza a `impostor_guess`
  - Si civil eliminado: avanza a siguiente ronda de `clue_writing`
  - Si game over: `status = finished`, room vuelve a `waiting`

**Domain**:
- [x] `OnlineMatchVote` — modelo con `fromMap`, `==`, `hashCode`
- [x] `VoteResolutionResult` — resultado del RPC con getters: `isTie`, `isGameOver`, etc.

**Repository**:
- [x] `submitVote()`, `resolveVotes()`, `watchMatchVotes()`

**Providers**:
- [x] `onlineMatchVotesProvider` — StreamProvider.family via Realtime

**UI**:
- [x] `lib/features/online/presentation/widgets/voting_phase.dart`:
  - Header con titulo + contador de votos (X/N)
  - Referencia de pistas de la ronda (ExpansionTile con chips)
  - Grid de jugadores votables con seleccion + boton confirmar
  - Estado post-voto: tu eleccion + lista de quien ya voto (sin revelar a quien)
- [x] `lib/features/online/presentation/widgets/vote_result_phase.dart`:
  - Resolucion automatica via RPC al entrar en la fase
  - Desglose de votos (quien voto por quien)
  - Card de resultado: empate (warning), eliminacion (con reveal de rol), game over (con ganador)
  - Texto informativo sobre la siguiente fase
- [x] Match screen: refresh de `myMatchState` automatico cuando Realtime detecta cambio de fase/version
- [x] `flutter analyze` sin errores nuevos

**Proximo paso**: Fase 5 Slice 3 (Adivinanza del impostor + pantalla de resultados finales + revancha)

### 2026-04-04 - Hotfix: ambiguedad SQL is_tiebreak + transicion lenta clue_writing→voting

**Estado**: completado ✅

**SQL** (`docs/supabase-phase5-slice2-voting.sql`):
- [x] Variable local `is_tiebreak` renombrada a `v_is_tiebreak` en `submit_vote` y `resolve_votes` para evitar ambiguedad con la columna `match_votes.is_tiebreak`
- [x] Todas las referencias a columna calificadas con alias `mv.`

**UI** (`lib/features/online/presentation/widgets/clue_writing_phase.dart`):
- [x] Flag `_myClueWritten` previene que el jugador vea el input de nuevo despues de enviar su pista
- [x] Cuando `submitClue` retorna `next_phase: 'voting'`, se hace `ref.invalidate` inmediato de `myMatchStateProvider` y `onlineMatchProvider` para transicion instantanea sin esperar Realtime

**Accion requerida**: Re-ejecutar las funciones `submit_vote` y `resolve_votes` de `docs/supabase-phase5-slice2-voting.sql` en Supabase SQL Editor

### 2026-04-05 - Fase 5 Slice 3: Adivinanza del impostor + resultados + revancha

**Estado**: completado ✅

**SQL** (`docs/supabase-phase5-slice3-guess.sql` — nuevo archivo):
- [x] RPC `submit_impostor_guess(match_id, guess)`:
  - Solo el impostor eliminado puede adivinar
  - Comparacion normalizada (lowercase + trim)
  - Si acierta: impostores ganan, match finaliza
  - Si falla: marca `eliminated_by_failed_guess`, chequea condiciones de fin
  - Si quedan impostores activos: continua a siguiente ronda de clue_writing
- [x] RPC `skip_impostor_guess(match_id)`:
  - El impostor eliminado decide no adivinar
  - Misma logica de continuacion/fin que el fallo
- [x] RPC `calculate_match_scores(match_id)`:
  - Calcula puntuacion final al terminar la partida
  - Civil win: +2 a civiles sin voto incorrecto, +1 a impostores eliminados (sin fallo de guess)
  - Impostor win: +5 si no eliminado, +1 si eliminado (sin fallo de guess)
  - Retorna ranking ordenado por puntos
- [x] Nota: la revancha no necesita RPC nuevo — el host vuelve al lobby y usa `start_match` existente

**Domain** (`lib/features/online/domain/online_match.dart`):
- [x] `ImpostorGuessResult` — resultado del RPC de adivinanza
- [x] `MatchScoresResult` — resultado del calculo de puntuacion
- [x] `PlayerScore` — modelo de puntuacion individual por jugador

**Repository** (`lib/features/online/data/online_match_repository.dart`):
- [x] `submitImpostorGuess()`, `skipImpostorGuess()`, `calculateMatchScores()`

**UI**:
- [x] `lib/features/online/presentation/widgets/impostor_guess_phase.dart`:
  - Vista dual: el impostor eliminado ve input de guess, los demas ven pantalla de espera
  - Timer de 30 segundos con colores degradados
  - Recordatorio de categoria y pista del impostor
  - Boton "Confirmar" + boton "Pasar" (outline)
  - Warning informativo sobre consecuencias
  - Auto-skip al terminar el timer
- [x] `lib/features/online/presentation/widgets/match_results_phase.dart`:
  - Anuncio del ganador con icono y color (civiles = verde, impostores = rojo)
  - Palabra secreta revelada con categoria
  - Ranking de jugadores con posicion, avatar, nombre, rol, puntos
  - Medallas para top 3, fila del usuario actual resaltada
  - Eliminados con strikethrough
  - Boton "Revancha" (solo host) → vuelve al lobby
  - Boton "Volver al inicio" / "Volver al lobby" segun si es host o no
- [x] `online_match_screen.dart`: phases `impostorGuess` y `finished` conectadas
- [x] Eliminado `_buildPhasePlaceholder` (ya no hay fases sin implementar)

**Fix adicional** (`docs/supabase-phase4-match-engine.sql`):
- [x] `get_my_match_state` ahora revela la palabra a impostores cuando `status = 'finished'` (antes solo civiles la recibían)

**Accion requerida**: Ejecutar en Supabase SQL Editor:
1. Las funciones `submit_vote` y `resolve_votes` de `docs/supabase-phase5-slice2-voting.sql`
2. Todo `docs/supabase-phase5-slice3-guess.sql`
3. La funcion `get_my_match_state` de `docs/supabase-phase4-match-engine.sql` (fix para revelar palabra al terminar)

### 2026-04-05 - Hotfix batch: correcciones post-pruebas de Fase 5

**Estado**: completado ✅

**Voting** (`voting_phase.dart`):
- [x] Reset de `_hasVoted` via `didUpdateWidget` cuando la fase vuelve a voting (fix desempate)
- [x] En desempate, solo se muestran como opciones los jugadores que empataron

**Vote result** (`vote_result_phase.dart`):
- [x] Barra de depletacion de 3 segundos (`LinearProgressIndicator` animada) antes de auto-transicion
- [x] Error "No es la fase de resultado" ignorado si otro cliente ya resolvio (fix error del host)

**Eliminated screen** (`online_match_screen.dart`):
- [x] Texto cambiado de "inactividad o desconexion" a "Los demas jugadores votaron para eliminarte"
- [x] Jugadores eliminados que siguen en la app ven la pantalla de resultados cuando la partida termina
- [x] Icono cambiado a `how_to_vote_rounded`
- [x] Spinner de espera mientras la partida continua

**Clue list** (`clue_writing_phase.dart`):
- [x] Orden invertido: la pista mas reciente aparece primero (cronologico, no por jugador)

**Scoring** (`supabase-phase5-slice3-guess.sql`):
- [x] `calculate_match_scores` ahora es idempotente (chequea si ya hay puntos > 0 antes de aplicar)

**Results screen** (`match_results_phase.dart`):
- [x] Emoji de medalla reemplazado por circulos con numeros y colores (oro/plata/bronce)
- [x] Boton unificado: "Volver a la sala" lleva directamente al lobby de la sala (sin modal de confirmacion)
- [x] Removido boton de "Revancha" separado — el host simplemente inicia otra partida desde el lobby

**Accion requerida**: Re-ejecutar `calculate_match_scores` de `docs/supabase-phase5-slice3-guess.sql` en Supabase

**Proximo paso**: Continuar pruebas end-to-end

### 2026-04-05 - Hotfix: resolve_votes idempotente + impostor guess visible

**Estado**: completado ✅

**SQL** (`docs/supabase-phase5-slice2-voting.sql`):
- [x] `resolve_votes` ahora es idempotente: si otro cliente ya resolvio y la fase avanzo, computa el resultado en modo read-only desde los votos y jugadores existentes en vez de lanzar excepcion
  - Detecta el round de votos mas reciente y si hubo tiebreak
  - Reconstruye el resultado (tie, game_over, impostor_eliminated, civil_eliminated) segun el estado actual del match
  - Esto garantiza que TODOS los clientes reciban el JSON de resultado para mostrar la pantalla de vote_result por 3 segundos locales

**UI** (`vote_result_phase.dart`):
- [x] Removido el catch especial para "No es la fase de resultado" (ya no ocurre, el RPC siempre retorna resultado)

**UI** (`online_match_screen.dart` — ya aplicado en hotfix anterior):
- [x] Impostores eliminados ahora ven la fase `impostor_guess` en vez de la pantalla de "Fuiste eliminado"

**Accion requerida**: Re-ejecutar la funcion `resolve_votes` de `docs/supabase-phase5-slice2-voting.sql` en Supabase SQL Editor
