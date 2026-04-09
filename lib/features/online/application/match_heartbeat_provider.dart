import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'online_rooms_provider.dart';

/// Sends a heartbeat every 30 seconds to keep the player marked as connected.
/// Watch this provider from the match screen to keep it alive.
/// On dispose (leaving the match screen), the timer is cancelled.
final matchHeartbeatProvider =
    Provider.autoDispose.family<void, ({String roomId})>((ref, params) {
  final repository = ref.read(onlineRoomsRepositoryProvider);

  // Send initial heartbeat immediately
  repository
      .setPlayerConnected(roomId: params.roomId, connected: true)
      .catchError((_) {});

  final timer = Timer.periodic(const Duration(seconds: 30), (_) {
    repository
        .setPlayerConnected(roomId: params.roomId, connected: true)
        .catchError((_) {});
  });

  ref.onDispose(() {
    timer.cancel();
  });
});
