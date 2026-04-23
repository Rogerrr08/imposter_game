# Plan de Refactorización Realtime — Modo Online

> **Fecha:** 2026-04-19
> **Autor:** análisis asistido por Claude Code
> **Versión objetivo:** v2.2.0
> **Estado:** propuesta — pendiente de aprobación

---

## 1. Contexto y problemas observados

Durante el uso real del modo online (v2.1.0) aparecieron síntomas que impactan
la jugabilidad:

- **Contador "X/Y jugadores" muestra 0/0** en múltiples pantallas de forma
  intermitente.
- **Las pistas no propagan** para algunos clientes: el resto de la sala las ve
  y sigue la partida, pero uno o dos dispositivos se quedan mostrando la
  pantalla de escritura.
- **Retardos visibles** al cambiar de fase (ej. `clue_writing → voting`).
- **Consumo de memoria elevado** tras varias rondas seguidas.

### Causa raíz estructural

El modo online abre **4–5 suscripciones WebSocket Realtime por cliente por
partida**, todas basadas en `stream()` sobre tablas (Postgres Changes):

| Stream | Archivo | Tabla |
|---|---|---|
| `onlineMatchProvider` | [online_match_repository.dart:67](../lib/features/online/data/online_match_repository.dart#L67) | `matches` |
| `onlineMatchPlayersProvider` | [online_match_repository.dart:79](../lib/features/online/data/online_match_repository.dart#L79) | `match_players` |
| `onlineMatchCluesProvider` | [online_match_repository.dart:162](../lib/features/online/data/online_match_repository.dart#L162) | `match_clues` |
| `onlineMatchVotesProvider` | [online_match_repository.dart:291](../lib/features/online/data/online_match_repository.dart#L291) | `match_votes` |
| `onlineRoomProvider` / `onlineRoomPlayersProvider` | [online_rooms_repository.dart](../lib/features/online/data/online_rooms_repository.dart) | `rooms`, `room_players` |
| Presence channel `room-lobby:{roomId}` | [online_lobby_sync_provider.dart:66](../lib/features/online/application/online_lobby_sync_provider.dart#L66) | — |

Sobre esta base, el código hace `ref.invalidate(...)` de forma agresiva en
múltiples lugares:

- [online_match_screen.dart:268-272](../lib/features/online/presentation/online_match_screen.dart#L268-L272) — invalida `myMatchStateProvider` **y** `onlineMatchPlayersProvider` en cada cambio de fase / `state_version`.
- [online_lobby_sync_provider.dart:74-76](../lib/features/online/application/online_lobby_sync_provider.dart#L74-L76) — invalida `onlineRoomProvider` y `onlineRoomPlayersProvider` en cada evento presence (`sync/join/leave`). Con N jugadores, un solo join amplifica a N×N refetches.
- [clue_writing_phase.dart:196-203](../lib/features/online/presentation/widgets/clue_writing_phase.dart#L196-L203) — `Future.microtask(() => ref.invalidate(...))` en cada rebuild cuando detecta todas las pistas.

**Invalidar un `StreamProvider` cierra y reabre la suscripción WebSocket.**
Durante la reconexión el valor es `AsyncData([])`, lo que explica el "0/0", y
pueden perderse eventos intermedios (causa raíz de las pistas que no llegan).

### Límites de Postgres Changes a escala

Según la documentación de Supabase, Postgres Changes procesa los cambios en un
**hilo único** para mantener el orden, lo que no escala con CPU y genera
latencia adicional por tabla suscrita. La recomendación oficial en 2025/2026 es
**Broadcast from Database** para casos con alta frecuencia de cambios, como un
juego multijugador. Ver sección 9 (referencias).

---

## 2. Objetivo del refactor

1. **Reducir a 1 suscripción WebSocket por partida** (además del presence del
   lobby) unificando todos los eventos de `match`, `match_players`,
   `match_clues` y `match_votes` en un único canal broadcast.
2. **Eliminar los `invalidate` redundantes** — el canal único se mantiene solo
   y no debe reabrirse por cambios de UI.
3. **Resolver los síntomas reportados** (contador 0/0, pistas perdidas).
4. **Mantener las mismas garantías** de integridad y seguridad (RLS) que hoy.
5. **No romper la experiencia del lobby** (presence sigue funcionando
   exactamente igual para detectar quién está conectado).

---

## 3. Arquitectura objetivo

### Antes (hoy)

```
Cliente ─┬─ WS1: postgres_changes(matches WHERE id=$matchId)
         ├─ WS2: postgres_changes(match_players WHERE match_id=$matchId)
         ├─ WS3: postgres_changes(match_clues WHERE match_id=$matchId)
         ├─ WS4: postgres_changes(match_votes WHERE match_id=$matchId)
         ├─ WS5: postgres_changes(rooms WHERE id=$roomId)          [en lobby]
         ├─ WS6: postgres_changes(room_players WHERE room_id=...) [en lobby]
         └─ WS7: presence channel 'room-lobby:$roomId'            [en lobby]
```

### Después

```
Cliente ─┬─ WS1: broadcast channel 'match:$matchId' (privado)
         │       └─ eventos: match-updated, player-updated,
         │                   clue-added, vote-added, phase-changed
         └─ WS2: presence channel 'room-lobby:$roomId'            [en lobby]
                 └─ broadcast adicional para eventos de lobby:
                    room-updated, players-changed
```

**Cambio clave:** en lugar de que cada cliente escuche a la base de datos, la
**base de datos publica deltas** a un canal privado por `match_id` (y otro por
`room_id` para el lobby). Los clientes aplican esos deltas a un estado local
en memoria sin volver a consultar Postgres.

### Eventos definidos

**Canal `match:{matchId}`** (privado, solo miembros del match):

| Evento | Payload | Trigger en |
|---|---|---|
| `match-updated` | `OnlineMatch` completo (JSON) | UPDATE `matches` |
| `player-updated` | `OnlineMatchPlayer` (JSON) | INSERT/UPDATE `match_players` |
| `clue-added` | `OnlineMatchClue` (JSON) | INSERT `match_clues` |
| `vote-added` | `OnlineMatchVote` (JSON) — sin revelar target a quien no debe | INSERT `match_votes` |

**Canal `room:{roomId}`** (privado, solo miembros de la sala):

| Evento | Payload | Trigger en |
|---|---|---|
| `room-updated` | `OnlineRoom` (JSON) | UPDATE `rooms` |
| `player-joined` / `player-left` / `player-updated` | `OnlineRoomPlayer` | INSERT/UPDATE/DELETE `room_players` |

Presence se mantiene sobre el mismo canal `room:{roomId}` (Supabase permite
combinar presence + broadcast en el mismo canal).

---

## 4. Plan de implementación (paso a paso)

### Fase 0 — Preparación (sin romper nada)

**0.1. Agregar índices SQL faltantes**

Archivo nuevo: `queries/10-realtime-refactor-indexes.sql`.

```sql
create index if not exists idx_match_clues_match_round
  on public.match_clues(match_id, round_number);
create index if not exists idx_match_votes_match_round
  on public.match_votes(match_id, round_number, is_tiebreak);
create index if not exists idx_match_players_match_seat
  on public.match_players(match_id, seat_order);
create index if not exists idx_matches_room_status
  on public.matches(room_id, status) where status = 'active';
```

Impacto inmediato: reduce latencia de `submit_clue`, `resolve_votes` y
`getActiveMatchForRoom`. Se puede ejecutar antes del resto y ya aporta.

**0.2. Quitar los tres `invalidate` más dañinos**

Cambios pequeños y seguros, se pueden mergear como hotfix incluso antes del
refactor grande (resuelven ~80% de los síntomas visibles):

- [online_match_screen.dart:272](../lib/features/online/presentation/online_match_screen.dart#L272): eliminar `ref.invalidate(onlineMatchPlayersProvider(...))`. El stream ya refleja los cambios.
- [online_lobby_sync_provider.dart:74-76](../lib/features/online/application/online_lobby_sync_provider.dart#L74-L76): quitar los `_invalidatePlayers()` y `_invalidateRoom()` dentro de los callbacks `onPresenceSync/Join/Leave`. Dejarlos solo en los `onBroadcast` de `config-updated` / `ready-updated`.
- [clue_writing_phase.dart:196-203](../lib/features/online/presentation/widgets/clue_writing_phase.dart#L196-L203): envolver el `Future.microtask(() => invalidate(...))` en un flag `_forcedRefreshForRound` para que sólo se dispare una vez por ronda. Mejor aún: eliminarlo y confiar en el stream (con los cambios de Fase 0.1 la latencia baja).

**0.3. Añadir `memCacheWidth/Height` a `PlayerAvatar`**

[player_avatar.dart:35](../lib/features/online/presentation/widgets/player_avatar.dart#L35):

```dart
CachedNetworkImage(
  imageUrl: avatarUrl!,
  width: size,
  height: size,
  memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
  memCacheHeight: (size * MediaQuery.devicePixelRatioOf(context)).round(),
  // ...
)
```

Evita decodificar imágenes 256×256 en todos los avatares pequeños (24–48px).
Ahorro estimado: 4–6 MB RAM con 8 jugadores visibles.

---

### Fase 1 — Backend: Broadcast from Database

**1.1. Habilitar Broadcast Authorization**

Archivo nuevo: `queries/11-realtime-authorization.sql`.

```sql
-- Política de lectura: solo miembros del match pueden recibir broadcasts
-- de canales 'match:<id>' y 'room:<id>'.
drop policy if exists "authenticated_read_match_broadcast" on realtime.messages;
create policy "authenticated_read_match_broadcast"
on realtime.messages
for select
to authenticated
using (
  (
    realtime.topic() like 'match:%'
    and public.is_match_player(
      substring(realtime.topic() from 7)::uuid
    )
  )
  or
  (
    realtime.topic() like 'room:%'
    and public.is_room_member(
      substring(realtime.topic() from 6)::uuid
    )
  )
);

-- Política de escritura: solo miembros pueden enviar broadcasts manuales
-- al canal. Los broadcasts desde triggers (realtime.send con SECURITY DEFINER)
-- no pasan por esta política.
drop policy if exists "authenticated_write_match_broadcast" on realtime.messages;
create policy "authenticated_write_match_broadcast"
on realtime.messages
for insert
to authenticated
with check (
  (
    realtime.topic() like 'match:%'
    and public.is_match_player(
      substring(realtime.topic() from 7)::uuid
    )
  )
  or
  (
    realtime.topic() like 'room:%'
    and public.is_room_member(
      substring(realtime.topic() from 6)::uuid
    )
  )
);
```

**1.2. Triggers para publicar deltas**

Archivo nuevo: `queries/12-realtime-triggers.sql`.

```sql
-- Trigger helper: publica el row completo en formato JSON al canal match:<id>
create or replace function public.broadcast_match_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match_id uuid;
  v_topic text;
  v_event text;
  v_payload jsonb;
begin
  v_match_id := coalesce(new.match_id, old.match_id);
  v_topic := 'match:' || v_match_id::text;

  case tg_table_name
    when 'match_players' then
      v_event := 'player-updated';
      v_payload := jsonb_build_object(
        'id', coalesce(new.id, old.id),
        'user_id', coalesce(new.user_id, old.user_id),
        'display_name', coalesce(new.display_name, old.display_name),
        'avatar_url', coalesce(new.avatar_url, old.avatar_url),
        'role', coalesce(new.role, old.role),
        'seat_order', coalesce(new.seat_order, old.seat_order),
        'is_eliminated', coalesce(new.is_eliminated, old.is_eliminated),
        'is_connected', coalesce(new.is_connected, old.is_connected),
        'role_confirmed', coalesce(new.role_confirmed, old.role_confirmed),
        'points', coalesce(new.points, old.points),
        'op', tg_op
      );
    when 'match_clues' then
      v_event := 'clue-added';
      v_payload := to_jsonb(new);
    when 'match_votes' then
      v_event := 'vote-added';
      v_payload := jsonb_build_object(
        'id', new.id,
        'match_id', new.match_id,
        'round_number', new.round_number,
        'voter_id', new.voter_id,
        'is_tiebreak', new.is_tiebreak,
        'created_at', new.created_at
        -- target_player_id NO se incluye: se revela solo al resolver votos
      );
  end case;

  perform realtime.send(v_payload, v_event, v_topic, true);  -- private=true
  return null;
end;
$$;

-- Trigger para matches (tabla padre, distinto shape)
create or replace function public.broadcast_matches_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic text;
begin
  v_topic := 'match:' || new.id::text;
  perform realtime.send(to_jsonb(new), 'match-updated', v_topic, true);
  return null;
end;
$$;

-- Attach triggers
drop trigger if exists tr_broadcast_matches on public.matches;
create trigger tr_broadcast_matches
  after update on public.matches
  for each row execute function public.broadcast_matches_change();

drop trigger if exists tr_broadcast_match_players on public.match_players;
create trigger tr_broadcast_match_players
  after insert or update on public.match_players
  for each row execute function public.broadcast_match_change();

drop trigger if exists tr_broadcast_match_clues on public.match_clues;
create trigger tr_broadcast_match_clues
  after insert on public.match_clues
  for each row execute function public.broadcast_match_change();

drop trigger if exists tr_broadcast_match_votes on public.match_votes;
create trigger tr_broadcast_match_votes
  after insert on public.match_votes
  for each row execute function public.broadcast_match_change();

-- Equivalente para rooms / room_players
create or replace function public.broadcast_room_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room_id uuid;
  v_topic text;
  v_event text;
  v_payload jsonb;
begin
  v_room_id := coalesce(
    case tg_table_name when 'rooms' then coalesce(new.id, old.id) else coalesce(new.room_id, old.room_id) end,
    null
  );
  v_topic := 'room:' || v_room_id::text;

  case tg_table_name
    when 'rooms' then
      v_event := 'room-updated';
      v_payload := to_jsonb(coalesce(new, old));
    when 'room_players' then
      if tg_op = 'DELETE' then
        v_event := 'player-left';
        v_payload := jsonb_build_object('id', old.id, 'user_id', old.user_id);
      elsif tg_op = 'INSERT' then
        v_event := 'player-joined';
        v_payload := to_jsonb(new);
      else
        v_event := 'player-updated';
        v_payload := to_jsonb(new);
      end if;
  end case;

  perform realtime.send(v_payload, v_event, v_topic, true);
  return null;
end;
$$;

drop trigger if exists tr_broadcast_rooms on public.rooms;
create trigger tr_broadcast_rooms
  after update on public.rooms
  for each row execute function public.broadcast_room_change();

drop trigger if exists tr_broadcast_room_players on public.room_players;
create trigger tr_broadcast_room_players
  after insert or update or delete on public.room_players
  for each row execute function public.broadcast_room_change();
```

**1.3. Quitar las tablas del publication `supabase_realtime`**

Una vez migrado todo al cliente, las tablas ya no necesitan estar en el
publication de Postgres Changes (libera un hilo del servidor). Archivo nuevo:
`queries/13-realtime-remove-publication.sql`. Ejecutar solo al final de la
migración, después de verificar que todos los clientes corren el nuevo código
(ver sección 6).

---

### Fase 2 — Cliente: canal unificado

**2.1. Nuevo archivo: `online_match_channel.dart`**

Ubicación: `lib/features/online/data/online_match_channel.dart`.

Responsabilidades:
- Abrir un único `RealtimeChannel` privado `match:{matchId}`.
- Escuchar los eventos `match-updated`, `player-updated`, `clue-added`,
  `vote-added`.
- Exponer **streams individuales** (`Stream<OnlineMatch?>`,
  `Stream<List<OnlineMatchPlayer>>`, etc.) construidos a partir del canal
  único, manteniendo la interfaz que ya consumen los providers.
- Hacer **fetch inicial** por RPC (una sola vez al conectar) y luego aplicar
  deltas en memoria.

Pseudocódigo:

```dart
class OnlineMatchChannel {
  OnlineMatchChannel(this._client, this._matchId);

  final SupabaseClient _client;
  final String _matchId;
  late final RealtimeChannel _channel;

  OnlineMatch? _match;
  final Map<String, OnlineMatchPlayer> _players = {};
  final Map<String, OnlineMatchClue> _clues = {};
  final Map<String, OnlineMatchVote> _votes = {};

  final _matchCtrl = StreamController<OnlineMatch?>.broadcast();
  final _playersCtrl = StreamController<List<OnlineMatchPlayer>>.broadcast();
  // ... idem clues, votes

  Future<void> start() async {
    // 1. Fetch inicial (snapshot)
    final snapshot = await _client.rpc('get_match_snapshot',
        params: {'input_match_id': _matchId});
    _applySnapshot(snapshot);

    // 2. Abrir canal privado
    _channel = _client.channel('match:$_matchId',
      opts: const RealtimeChannelConfig(private: true),
    );

    _channel
      ..onBroadcast(event: 'match-updated', callback: _onMatchUpdated)
      ..onBroadcast(event: 'player-updated', callback: _onPlayerUpdated)
      ..onBroadcast(event: 'clue-added', callback: _onClueAdded)
      ..onBroadcast(event: 'vote-added', callback: _onVoteAdded)
      ..subscribe();
  }

  void _onPlayerUpdated(Map<String, dynamic> payload) {
    final player = OnlineMatchPlayer.fromMap(payload['payload']);
    _players[player.id] = player;
    _playersCtrl.add(_players.values.toList()
      ..sort((a, b) => a.seatOrder.compareTo(b.seatOrder)));
  }
  // ... etc

  Stream<OnlineMatch?> watchMatch() => _matchCtrl.stream;
  Stream<List<OnlineMatchPlayer>> watchPlayers() => _playersCtrl.stream;
  // ...

  Future<void> dispose() async {
    await _client.removeChannel(_channel);
    await _matchCtrl.close();
    // ...
  }
}
```

**2.2. Nueva RPC `get_match_snapshot`**

Archivo nuevo o añadir a `queries/03-match-lifecycle.sql`:

```sql
create or replace function public.get_match_snapshot(input_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match jsonb;
  v_players jsonb;
  v_clues jsonb;
  v_votes jsonb;
begin
  if not public.is_match_player(input_match_id) then
    raise exception 'Not a member of this match';
  end if;

  select to_jsonb(m) into v_match
  from public.matches m where m.id = input_match_id;

  select coalesce(jsonb_agg(to_jsonb(mp)), '[]'::jsonb) into v_players
  from public.match_players mp where mp.match_id = input_match_id;

  select coalesce(jsonb_agg(to_jsonb(mc)), '[]'::jsonb) into v_clues
  from public.match_clues mc where mc.match_id = input_match_id;

  -- votos: solo sin target si aún no se han resuelto (depende de phase)
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', mv.id, 'round_number', mv.round_number,
      'voter_id', mv.voter_id, 'is_tiebreak', mv.is_tiebreak,
      'created_at', mv.created_at
    )
  ), '[]'::jsonb) into v_votes
  from public.match_votes mv where mv.match_id = input_match_id;

  return jsonb_build_object(
    'match', v_match,
    'players', v_players,
    'clues', v_clues,
    'votes', v_votes
  );
end;
$$;

grant execute on function public.get_match_snapshot(uuid) to authenticated;
```

**2.3. Integrar con Riverpod**

Nuevo provider que gestiona el ciclo de vida del canal:

```dart
final onlineMatchChannelProvider =
    Provider.autoDispose.family<OnlineMatchChannel, String>((ref, matchId) {
  final channel = OnlineMatchChannel(SupabaseConfig.client, matchId);
  channel.start();
  ref.onDispose(channel.dispose);
  return channel;
});
```

Los providers existentes se reescriben para **leer del canal**, no de
`repository.watchXxx`:

```dart
final onlineMatchProvider =
    StreamProvider.family<OnlineMatch?, String>((ref, matchId) {
  final channel = ref.watch(onlineMatchChannelProvider(matchId));
  return channel.watchMatch();
});

final onlineMatchPlayersProvider =
    StreamProvider.family<List<OnlineMatchPlayer>, String>((ref, matchId) {
  final channel = ref.watch(onlineMatchChannelProvider(matchId));
  return channel.watchPlayers();
});
// idem clues, votes
```

**Ventaja clave:** la API que consumen las pantallas no cambia. Solo el
origen de los datos.

**2.4. Equivalente para el lobby**

Refactor análogo para `room:{roomId}`:
- Extender `OnlineLobbySyncController` ([online_lobby_sync_provider.dart:40](../lib/features/online/application/online_lobby_sync_provider.dart#L40)) para que suscriba también a los broadcasts `room-updated` / `player-*`.
- Convertir los providers `onlineRoomProvider` y `onlineRoomPlayersProvider` a leer del mismo canal.
- Eliminar los `stream()` sobre `rooms` y `room_players` en el repositorio.

---

### Fase 3 — Limpieza

**3.1. Eliminar métodos obsoletos**

En `online_match_repository.dart`:
- Borrar `watchMatch`, `watchMatchPlayers`, `watchMatchClues`, `watchMatchVotes` (líneas 67, 79, 162, 291).

En `online_rooms_repository.dart`:
- Borrar los equivalentes de `watchRoom`, `watchRoomPlayers`.

**3.2. Sacar tablas del publication de Realtime**

Ejecutar `queries/13-realtime-remove-publication.sql`:

```sql
alter publication supabase_realtime drop table public.matches;
alter publication supabase_realtime drop table public.match_players;
alter publication supabase_realtime drop table public.match_clues;
alter publication supabase_realtime drop table public.match_votes;
alter publication supabase_realtime drop table public.rooms;
alter publication supabase_realtime drop table public.room_players;
```

**Importante:** hacerlo **después** de comprobar que toda la base instalada
corre ≥ v2.2.0. Si algún cliente viejo se conecta, se quedará sin datos en
las pantallas online (mitigable con un mínimo de versión exigido al conectar).

**3.3. Reducir frecuencia del heartbeat**

[match_heartbeat_provider.dart:19](../lib/features/online/application/match_heartbeat_provider.dart#L19): subir el intervalo de 30s a 60s. El presence channel del lobby ya detecta desconexiones en tiempo real, así que el heartbeat en DB sólo sirve como fallback para reconexión después de cerrar la app.

---

### Fase 4 — Verificación y observabilidad

**4.1. Métricas a monitorear**

- Número de conexiones WebSocket por cliente: **debe ser 2** máximo (match + lobby). Antes: hasta 7.
- Latencia entre `submit_clue` y `clue-added` recibido en otros clientes. Objetivo: < 300 ms p95.
- Errores en `realtime.messages` RLS (logs de Supabase).

**4.2. Escenarios de prueba**

1. Lobby con 8 jugadores, todos marcan ready → todos ven el contador `8/8` al instante.
2. Un jugador escribe la pista → los otros 7 la ven en < 500 ms.
3. Un jugador pierde la conexión 10 s y vuelve → recibe el estado actual por `get_match_snapshot` al reabrir el canal.
4. Durante una partida, cerrar y reabrir la app → no debe mostrar `0/0` en ningún momento.
5. Cambio de fase `clue_writing → voting` → el countdown sale en todos los clientes al unísono.

**4.3. Feature flag (opcional)**

Para una migración con red de seguridad, se puede añadir un provider
`useBroadcastChannelProvider` (bool) leído desde `shared_preferences` o de una
tabla `feature_flags` en Supabase. Si `false`, cae a los streams viejos (hay
que mantener ambos caminos durante una versión). Recomendado **solo si se
quiere lanzar gradualmente**; en un proyecto privado con pocos usuarios es
aceptable saltarse el flag y publicar directo.

---

## 5. Cambios puntuales de rendimiento incluidos

Estos son "wins" del audit que se implementan como parte del refactor:

| # | Archivo | Cambio | Fase |
|---|---|---|---|
| 1 | [player_avatar.dart:35](../lib/features/online/presentation/widgets/player_avatar.dart#L35) | `memCacheWidth/Height` en `CachedNetworkImage` | 0.3 |
| 2 | [online_match_screen.dart:272](../lib/features/online/presentation/online_match_screen.dart#L272) | Quitar `invalidate(onlineMatchPlayersProvider)` | 0.2 |
| 3 | [online_lobby_sync_provider.dart:74-76](../lib/features/online/application/online_lobby_sync_provider.dart#L74-L76) | Quitar `invalidate` en callbacks presence | 0.2 |
| 4 | [clue_writing_phase.dart:196-203](../lib/features/online/presentation/widgets/clue_writing_phase.dart#L196-L203) | Eliminar `Future.microtask(invalidate)` en rebuild | 0.2 |
| 5 | [room_lobby_notifier.dart](../lib/features/online/application/room_lobby_notifier.dart) | Dividir `build()` con `.select()` para no rebuildear en cada cambio menor | 2.4 |
| 6 | [match_results_phase.dart:193-196](../lib/features/online/presentation/widgets/match_results_phase.dart#L193-L196) | Usar `.select()` para contar players ready | 2.4 |
| 7 | [match_heartbeat_provider.dart:19](../lib/features/online/application/match_heartbeat_provider.dart#L19) | Intervalo de 30s → 60s | 3.3 |
| 8 | `queries/10-realtime-refactor-indexes.sql` | Índices compuestos (clues, votes, players, matches) | 0.1 |

---

## 6. Estrategia de release

**Opción A — Todo en una versión (recomendado para este proyecto):**

1. PR con todos los cambios (Fases 0 → 3).
2. Ejecutar SQL en orden: `10 → 11 → 12 → 13` (este último al final, en ventana de mantenimiento).
3. Publicar v2.2.0 como release único.
4. Forzar actualización con pantalla bloqueante si algún cliente < v2.2.0 intenta conectarse (leer `app_version` de los clientes via un header RPC y comparar contra un mínimo en una tabla `app_config`).

**Opción B — Gradual con feature flag:**

1. v2.1.1: Fase 0 completa (hotfix de los `invalidate` + índices + avatar cache). Sin romper nada.
2. v2.2.0: Fase 1 + Fase 2 detrás de feature flag.
3. v2.2.1: Activar flag por default. Fase 3.
4. v2.3.0: Remover código viejo y flag.

La Opción B es más prudente si hay usuarios jugando activamente. La Opción A
es más rápida y simple.

---

## 7. Impacto estimado

| Métrica | Hoy | Después |
|---|---|---|
| WebSockets por cliente durante partida | 5 (match+players+clues+votes+presence) | 2 (match broadcast + lobby presence) |
| Refetches en un join al lobby (8 jugadores) | O(N²) = 64 | 0 (deltas puros) |
| Latencia de propagación de una pista (p95) | 500–1500 ms (con reconexiones) | 100–300 ms |
| Memoria de imágenes avatar (8 jugadores) | ~6 MB | ~1 MB |
| Ocurrencia del bug "0/0 jugadores" | Frecuente | Eliminada (no hay invalidate que vacíe el stream) |

---

## 8. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| El snapshot inicial puede llegar *después* de un broadcast (race). | Usar un número de secuencia (`state_version` existente en `matches`). Si un broadcast trae `version < local`, ignorarlo. |
| Clientes vieja versión siguen conectados a Postgres Changes después de quitar el publication. | Hacer Fase 3.2 en una ventana de mantenimiento anunciada + forzar update. |
| Reconexión WebSocket pierde eventos entre desconexión y resuscripción. | Cada `subscribe` dispara un `get_match_snapshot` fresco antes de aplicar nuevos deltas. Patrón "snapshot + deltas" estándar. |
| Triggers con `SECURITY DEFINER` pueden impactar performance de INSERT/UPDATE. | Usar `realtime.send()` que es lightweight. Medir con `EXPLAIN ANALYZE` en los RPCs críticos (`submit_clue`, `submit_vote`, `resolve_votes`). |
| RLS en `realtime.messages` mal configurada → clientes no reciben nada. | Probar con logs de Supabase Realtime activos durante QA. Tener un endpoint RPC de fallback para debug (`get_match_snapshot` siempre funciona). |
| Triggers hacen flood si hay muchos UPDATE seguidos. | `realtime.send` es async y no bloquea. Monitorear con Supabase dashboard. |

---

## 9. Referencias

- [Supabase Realtime — Broadcast from Database (oficial)](https://supabase.com/blog/realtime-broadcast-from-database)
- [Supabase Realtime — Broadcast docs](https://supabase.com/docs/guides/realtime/broadcast)
- [Supabase Realtime — Authorization (RLS en `realtime.messages`)](https://supabase.com/docs/guides/realtime/authorization)
- [Supabase Realtime — Subscribing to Database Changes (comparativa vs broadcast)](https://supabase.com/docs/guides/realtime/subscribing-to-database-changes)
- [Realtime: Multiplayer Edition (blog GA)](https://supabase.com/blog/supabase-realtime-multiplayer-general-availability)

---

## 10. Checklist de ejecución

### Preparación
- [ ] Crear rama `feature/realtime-refactor`
- [ ] Aumentar versión a `2.2.0+5` en `pubspec.yaml` y `app_info_provider.dart`

### Fase 0 (puede ir como hotfix previo)
- [ ] `queries/10-realtime-refactor-indexes.sql` creado y ejecutado
- [ ] Quitar `invalidate` en `online_match_screen.dart:272`
- [ ] Quitar `invalidate` en `online_lobby_sync_provider.dart:74-76`
- [ ] Arreglar `clue_writing_phase.dart:196-203`
- [ ] `memCacheWidth/Height` en `player_avatar.dart`

### Fase 1 (backend)
- [ ] `queries/11-realtime-authorization.sql` creado y ejecutado
- [ ] `queries/12-realtime-triggers.sql` creado y ejecutado
- [ ] RPC `get_match_snapshot` creada

### Fase 2 (cliente)
- [ ] `online_match_channel.dart` implementado
- [ ] Providers redirigidos al canal
- [ ] Lobby equivalente implementado
- [ ] Tests manuales con 8 jugadores en emuladores

### Fase 3 (limpieza)
- [ ] Métodos `watchXxx` eliminados de los repositorios
- [ ] `queries/13-realtime-remove-publication.sql` ejecutado
- [ ] Heartbeat subido a 60s

### Verificación
- [ ] Ninguna pantalla muestra "0/0"
- [ ] Pistas propagan en < 500 ms a todos los clientes
- [ ] Cambio de fase unísono
- [ ] Avatares cargan sin lag visible

---

## Registro de actualizaciones de este plan

- **2026-04-19** — Creación del documento. Basado en audit de rendimiento post-v2.1.0 y síntomas reportados en producción (0/0 jugadores, pistas perdidas).
