import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/word_bank.dart';
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

  final controller = OnlineLobbySyncController(
    ref: ref,
    client: SupabaseConfig.client,
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
    required this.roomId,
    required this.userId,
    required this.displayName,
  });

  final Ref ref;
  final SupabaseClient client;
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

    final channel = _channel;
    if (channel == null) return;

    try {
      await channel.untrack();
    } catch (_) {}

    try {
      await client.removeChannel(channel);
    } catch (_) {}
  }

  void _invalidateRoom() {
    ref.invalidate(onlineRoomProvider(roomId));
  }

  void _invalidatePlayers() {
    ref.invalidate(onlineRoomPlayersProvider(roomId));
  }
}
