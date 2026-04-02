import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/word_bank.dart';
import '../../../models/game_state.dart';
import '../domain/online_room.dart';

class OnlineRoomsRepository {
  OnlineRoomsRepository(this._client);

  final SupabaseClient _client;
  final Random _random = Random.secure();

  Future<String> createPrivateRoom({
    required String displayName,
  }) async {
    for (int attempt = 0; attempt < 12; attempt++) {
      try {
        final roomId = await _client.rpc(
          'create_private_room',
          params: {
            'input_display_name': displayName.trim(),
            'input_code': _generateRoomCode(),
            'input_game_mode': GameMode.classic.name,
            'input_categories': WordCategory.values
                .map((category) => category.name)
                .toList(),
            'input_hints_enabled': true,
            'input_impostor_count': 1,
            'input_duration_seconds': 120,
            'input_min_players': 4,
            'input_max_players': 8,
          },
        );

        return roomId as String;
      } on PostgrestException catch (error) {
        if (error.code != '23505' || attempt == 11) {
          rethrow;
        }
      }
    }

    throw Exception('No se pudo generar un codigo unico de sala.');
  }

  Future<String> joinPrivateRoom({
    required String code,
    required String displayName,
  }) async {
    final roomId = await _client.rpc(
      'join_private_room',
      params: {
        'input_code': code.trim().toUpperCase(),
        'input_display_name': displayName.trim(),
      },
    );

    return roomId as String;
  }

  Future<void> setReady({
    required String roomId,
    required bool isReady,
  }) async {
    await _client.rpc(
      'set_room_ready',
      params: {
        'input_room_id': roomId,
        'input_is_ready': isReady,
      },
    );
  }

  Future<void> updateRoomConfig({
    required String roomId,
    required List<WordCategory> categories,
    required bool hintsEnabled,
    required int impostorCount,
    required int durationSeconds,
  }) async {
    await _client.rpc(
      'update_room_config',
      params: {
        'input_room_id': roomId,
        'input_categories': categories
            .map((category) => category.name)
            .toList(),
        'input_hints_enabled': hintsEnabled,
        'input_impostor_count': impostorCount,
        'input_duration_seconds': durationSeconds,
      },
    );
  }

  Future<void> leaveRoom(String roomId) async {
    await _client.rpc(
      'leave_room',
      params: {
        'input_room_id': roomId,
      },
    );
  }

  Stream<OnlineRoom?> watchRoom(String roomId) {
    return _client
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((rows) {
          if (rows.isEmpty) return null;
          return OnlineRoom.fromMap(rows.first);
        });
  }

  Stream<List<OnlineRoomPlayer>> watchRoomPlayers(String roomId) {
    return _client
        .from('room_players')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .map(
          (rows) => rows
              .map((row) => OnlineRoomPlayer.fromMap(row))
              .toList()
            ..sort((a, b) => a.seatOrder.compareTo(b.seatOrder)),
        );
  }

  String _generateRoomCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(
      6,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }
}
