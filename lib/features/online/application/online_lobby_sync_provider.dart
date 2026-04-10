import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/word_bank.dart';
import '../data/online_rooms_repository.dart';
import '../data/supabase_config.dart';
import 'online_auth_provider.dart';
import 'online_rooms_provider.dart';

final onlineLobbySyncProvider =
    Provider.autoDispose.family<OnlineLobbySyncController?, String>((
  ref,
  roomId,
) {
  final profile = ref.watch(onlineProfileProvider).asData?.value;
  if (profile == null || !profile.hasDisplayName) {
    return null;
  }

  final repository = ref.read(onlineRoomsRepositoryProvider);

  final controller = OnlineLobbySyncController(
    ref: ref,
    client: SupabaseConfig.client,
    repository: repository,
    roomId: roomId,
    userId: profile.id,
    displayName: profile.displayName!,
  )..start();

  ref.onDispose(() {
    unawaited(controller.dispose());
  });

  return controller;
});

class OnlineLobbySyncController {
  OnlineLobbySyncController({
    required this.ref,
    required this.client,
    required this.repository,
    required this.roomId,
    required this.userId,
    required this.displayName,
  });

  final Ref ref;
  final SupabaseClient client;
  final OnlineRoomsRepository repository;
  final String roomId;
  final String userId;
  final String displayName;

  RealtimeChannel? _channel;
  bool _started = false;
  bool _subscribed = false;
  bool _disposed = false;

  void start() {
    if (_started || _disposed) return;
    _started = true;

    final channel = client.channel(
      'room-lobby:$roomId',
      opts: RealtimeChannelConfig(
        key: userId,
      ),
    );

    channel
        .onPresenceSync((_) => _invalidatePlayers())
        .onPresenceJoin((_) => _invalidatePlayers())
        .onPresenceLeave((_) => _invalidatePlayers())
        .onBroadcast(
          event: 'config-updated',
          callback: (_) => _invalidateRoom(),
        )
        .onBroadcast(
          event: 'ready-updated',
          callback: (_) => _invalidatePlayers(),
        )
        .subscribe((status, error) async {
      if (_disposed) return;

      if (status == RealtimeSubscribeStatus.subscribed) {
        _subscribed = true;
        await channel.track({
          'user_id': userId,
          'display_name': displayName,
          'online_at': DateTime.now().toIso8601String(),
        });
        unawaited(_setConnected(true));
        _invalidateRoom();
        _invalidatePlayers();
        return;
      }

      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.closed ||
          status == RealtimeSubscribeStatus.timedOut) {
        _subscribed = false;
        _invalidateRoom();
        _invalidatePlayers();
      }
    });

    _channel = channel;
  }

  Future<void> broadcastConfigUpdated({
    required List<WordCategory> categories,
    required bool hintsEnabled,
    required int impostorCount,
    required int durationSeconds,
  }) async {
    final channel = _channel;
    if (_disposed || !_subscribed || channel == null) return;

    await channel.sendBroadcastMessage(
      event: 'config-updated',
      payload: {
        'room_id': roomId,
        'user_id': userId,
        'categories': categories.map((category) => category.name).toList(),
        'hints_enabled': hintsEnabled,
        'impostor_count': impostorCount,
        'duration_seconds': durationSeconds,
        'changed_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> broadcastReadyUpdated({
    required bool isReady,
  }) async {
    final channel = _channel;
    if (_disposed || !_subscribed || channel == null) return;

    await channel.sendBroadcastMessage(
      event: 'ready-updated',
      payload: {
        'room_id': roomId,
        'user_id': userId,
        'is_ready': isReady,
        'changed_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await _setConnected(false);

    final channel = _channel;
    if (channel == null) return;

    try {
      await channel.untrack();
    } catch (_) {}

    try {
      await client.removeChannel(channel);
    } catch (_) {}
  }

  Future<void> _setConnected(bool connected) async {
    try {
      await repository.setPlayerConnected(
        roomId: roomId,
        connected: connected,
      );
    } catch (_) {
      // Best-effort — don't block on connection status updates
    }
  }

  void _invalidateRoom() {
    if (_disposed) return;
    ref.invalidate(onlineRoomProvider(roomId));
  }

  void _invalidatePlayers() {
    if (_disposed) return;
    ref.invalidate(onlineRoomPlayersProvider(roomId));
  }
}
