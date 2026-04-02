import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/online_rooms_repository.dart';
import '../data/supabase_config.dart';
import '../domain/online_room.dart';

final onlineRoomsRepositoryProvider = Provider<OnlineRoomsRepository>((ref) {
  return OnlineRoomsRepository(SupabaseConfig.client);
});

final onlineRoomProvider =
    StreamProvider.family<OnlineRoom?, String>((ref, roomId) {
  final repository = ref.watch(onlineRoomsRepositoryProvider);
  return repository.watchRoom(roomId);
});

final onlineRoomPlayersProvider =
    StreamProvider.family<List<OnlineRoomPlayer>, String>((ref, roomId) {
  final repository = ref.watch(onlineRoomsRepositoryProvider);
  return repository.watchRoomPlayers(roomId);
});
