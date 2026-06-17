import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/online_room.dart';

/// Canal Realtime unificado por sala. Reemplaza los streams de
/// `rooms` y `room_players` por un único canal privado `room:<id>` que
/// recibe deltas vía broadcast desde triggers en la base de datos.
///
/// El canal de presence (lobby) sigue viviendo en `OnlineLobbySyncController`
/// con su propio topic separado — esa pieza ya está y no se toca aquí.
class OnlineRoomChannel {
  OnlineRoomChannel(this._client, this.roomId);

  final SupabaseClient _client;
  final String roomId;

  RealtimeChannel? _channel;
  bool _started = false;
  bool _disposed = false;
  bool _resyncing = false;

  OnlineRoom? _room;
  final Map<String, OnlineRoomPlayer> _players = {};

  final _roomCtrl = StreamController<OnlineRoom?>.broadcast();
  final _playersCtrl = StreamController<List<OnlineRoomPlayer>>.broadcast();

  Stream<OnlineRoom?> watchRoom() async* {
    yield _room;
    yield* _roomCtrl.stream;
  }

  Stream<List<OnlineRoomPlayer>> watchPlayers() async* {
    yield _sortedPlayers();
    yield* _playersCtrl.stream;
  }

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;

    await _loadSnapshot();
    if (_disposed) return;

    _channel = _subscribeChannel();
  }

  /// Crea y suscribe una nueva instancia del canal broadcast privado.
  /// `subscribe()` solo puede llamarse una vez por instancia (lanza si no),
  /// por eso para reconectar hay que crear una nueva — ver [resync].
  RealtimeChannel _subscribeChannel() {
    final channel = _client.channel(
      'room:$roomId',
      opts: const RealtimeChannelConfig(private: true),
    );

    channel
        .onBroadcast(event: 'room-updated', callback: _onRoomUpdated)
        .onBroadcast(event: 'player-joined', callback: _onPlayerUpserted)
        .onBroadcast(event: 'player-updated', callback: _onPlayerUpserted)
        .onBroadcast(event: 'player-left', callback: _onPlayerLeft)
        .subscribe((status, error) async {
          if (_disposed) return;
          if (status == RealtimeSubscribeStatus.subscribed) {
            // Reconnects: re-cargar snapshot para recuperar deltas perdidos.
            await _loadSnapshot();
          }
        });

    return channel;
  }

  /// Reconciliación forzada tras un posible corte silencioso del socket
  /// (la app vuelve de segundo plano y el WebSocket murió sin detectarse).
  /// Recarga el snapshot por HTTPS y recrea el canal subyacente para forzar
  /// una reconexión limpia. Idempotente mientras hay un resync en curso.
  Future<void> resync() async {
    if (_disposed || !_started || _resyncing) return;
    _resyncing = true;
    try {
      await _loadSnapshot();
      if (_disposed) return;

      final old = _channel;
      _channel = null;
      if (old != null) {
        try {
          await _client.removeChannel(old);
        } catch (_) {}
      }
      if (_disposed) return;
      _channel = _subscribeChannel();
    } finally {
      _resyncing = false;
    }
  }

  Future<void> _loadSnapshot() async {
    try {
      final roomRows = await _client
          .from('rooms')
          .select()
          .eq('id', roomId)
          .limit(1);

      if (_disposed) return;

      _room = roomRows.isEmpty ? null : OnlineRoom.fromMap(roomRows.first);

      final playerRows = await _client
          .from('room_players')
          .select()
          .eq('room_id', roomId);

      if (_disposed) return;

      _players
        ..clear()
        ..addEntries(
          playerRows.map((row) {
            final p = OnlineRoomPlayer.fromMap(row);
            return MapEntry(p.id, p);
          }),
        );

      _emitRoom();
      _emitPlayers();
    } catch (_) {
      // Best-effort: el siguiente broadcast cubrirá el gap.
    }
  }

  void _onRoomUpdated(Map<String, dynamic> envelope) {
    final data = _extractPayload(envelope);
    if (data == null) return;
    _room = OnlineRoom.fromMap(data);
    _emitRoom();
  }

  void _onPlayerUpserted(Map<String, dynamic> envelope) {
    final data = _extractPayload(envelope);
    if (data == null) return;
    final p = OnlineRoomPlayer.fromMap(data);
    _players[p.id] = p;
    _emitPlayers();
  }

  void _onPlayerLeft(Map<String, dynamic> envelope) {
    final data = _extractPayload(envelope);
    if (data == null) return;
    final id = data['id'] as String?;
    if (id == null) return;
    _players.remove(id);
    _emitPlayers();
  }

  Map<String, dynamic>? _extractPayload(Map<String, dynamic> envelope) {
    final inner = envelope['payload'];
    if (inner is Map<String, dynamic>) return inner;
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return null;
  }

  List<OnlineRoomPlayer> _sortedPlayers() =>
      _players.values.toList()
        ..sort((a, b) => a.seatOrder.compareTo(b.seatOrder));

  void _emitRoom() {
    if (_disposed || _roomCtrl.isClosed) return;
    _roomCtrl.add(_room);
  }

  void _emitPlayers() {
    if (_disposed || _playersCtrl.isClosed) return;
    _playersCtrl.add(_sortedPlayers());
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await _client.removeChannel(channel);
      } catch (_) {}
    }

    await _roomCtrl.close();
    await _playersCtrl.close();
  }
}
