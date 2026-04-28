import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/online_room_channel.dart';
import '../data/online_rooms_repository.dart';
import '../data/supabase_config.dart';
import '../domain/online_room.dart';

final onlineRoomsRepositoryProvider = Provider<OnlineRoomsRepository>((ref) {
  return OnlineRoomsRepository(SupabaseConfig.client);
});

/// Returns the room ID of the user's active room (waiting/playing), or null.
final myActiveRoomProvider = FutureProvider.autoDispose<String?>((ref) {
  final repository = ref.watch(onlineRoomsRepositoryProvider);
  return repository.getMyActiveRoom();
});

/// Canal unificado por sala (`room:<id>`). Reemplaza los `stream()` sobre
/// `rooms` y `room_players`. El canal de presence (lobby) sigue siendo
/// gestionado por `OnlineLobbySyncController` con su propio topic.
final onlineRoomChannelProvider =
    Provider.autoDispose.family<OnlineRoomChannel, String>((ref, roomId) {
  final channel = OnlineRoomChannel(SupabaseConfig.client, roomId);
  unawaited(channel.start());
  ref.onDispose(() {
    unawaited(channel.dispose());
  });
  return channel;
});

final onlineRoomProvider =
    StreamProvider.family<OnlineRoom?, String>((ref, roomId) {
  final channel = ref.watch(onlineRoomChannelProvider(roomId));
  return channel.watchRoom();
});

final onlineRoomPlayersProvider =
    StreamProvider.family<List<OnlineRoomPlayer>, String>((ref, roomId) {
  final channel = ref.watch(onlineRoomChannelProvider(roomId));
  return channel.watchPlayers();
});
