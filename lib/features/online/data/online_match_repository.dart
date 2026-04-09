import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/word_bank.dart';
import '../domain/online_match.dart';
import '../domain/online_room.dart';

class OnlineMatchRepository {
  OnlineMatchRepository(this._client);

  final SupabaseClient _client;
  final Random _random = Random.secure();

  /// Start a match. Called by the host.
  /// Picks a word, assigns impostor indices, and calls the RPC.
  Future<String> startMatch({
    required OnlineRoom room,
    required List<OnlineRoomPlayer> players,
  }) async {
    // 1. Pick word from the room's configured categories
    final wordEntry = WordBank.getRandomWordFromCategories(room.categories);

    // 2. Pick impostor indices (0-based, referencing seat_order - 1)
    final indices = List.generate(players.length, (i) => i)..shuffle(_random);
    final impostorIndices = indices.take(room.impostorCount).toList();

    // 3. Get hints using the same logic as local game
    final hints = WordBank.getHardHints(
      wordEntry,
      count: room.impostorCount,
    );

    try {
      final matchId = await _client.rpc(
        'start_match',
        params: {
          'input_room_id': room.id,
          'input_word': wordEntry.word,
          'input_category': wordEntry.category.name,
          'input_hints': hints,
          'input_impostor_indices': impostorIndices,
        },
      );

      return matchId as String;
    } on PostgrestException catch (error) {
      throw Exception(_friendlyMessage(error));
    }
  }

  /// Get the current player's match state (role, word, etc.)
  Future<MyMatchState> getMyMatchState(String matchId) async {
    try {
      final result = await _client.rpc(
        'get_my_match_state',
        params: {'input_match_id': matchId},
      );

      return MyMatchState.fromMap(result as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw Exception(_friendlyMessage(error));
    }
  }

  /// Watch match state changes via Realtime stream.
  Stream<OnlineMatch?> watchMatch(String matchId) {
    return _client
        .from('matches')
        .stream(primaryKey: ['id'])
        .eq('id', matchId)
        .map((rows) {
          if (rows.isEmpty) return null;
          return OnlineMatch.fromMap(rows.first);
        });
  }

  /// Watch match players via Realtime stream.
  Stream<List<OnlineMatchPlayer>> watchMatchPlayers(String matchId) {
    return _client
        .from('match_players')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .map(
          (rows) => rows
              .map((row) => OnlineMatchPlayer.fromMap(row))
              .toList()
            ..sort((a, b) => a.seatOrder.compareTo(b.seatOrder)),
        );
  }

  /// Abandon match: marks player as eliminated, may cancel the match.
  /// Returns true if the match was cancelled.
  Future<bool> abandonMatch(String matchId) async {
    try {
      final result = await _client.rpc(
        'abandon_match',
        params: {'input_match_id': matchId},
      );

      final data = result as Map<String, dynamic>;
      return data['cancelled'] as bool? ?? false;
    } on PostgrestException catch (error) {
      throw Exception(_friendlyMessage(error));
    }
  }

  /// Confirm role reveal. When all players confirm, phase advances to clue_writing.
  Future<bool> confirmRoleReveal(String matchId) async {
    try {
      final result = await _client.rpc(
        'confirm_role_reveal',
        params: {'input_match_id': matchId},
      );

      final data = result as Map<String, dynamic>;
      return data['phase_advanced'] as bool? ?? false;
    } on PostgrestException catch (error) {
      throw Exception(_friendlyMessage(error));
    }
  }

  /// Submit a clue for the current turn.
  Future<String> submitClue({
    required String matchId,
    required String clue,
  }) async {
    try {
      final result = await _client.rpc(
        'submit_clue',
        params: {
          'input_match_id': matchId,
          'input_clue': clue,
        },
      );

      final data = result as Map<String, dynamic>;
      return data['next_phase'] as String? ?? 'clue_writing';
    } on PostgrestException catch (error) {
      throw Exception(_friendlyMessage(error));
    }
  }

  /// Skip the current clue turn (timeout expired).
  Future<void> skipClueTurn(String matchId) async {
    try {
      await _client.rpc(
        'skip_clue_turn',
        params: {'input_match_id': matchId},
      );
    } on PostgrestException catch (error) {
      throw Exception(_friendlyMessage(error));
    }
  }

  /// Watch match clues via Realtime stream.
  Stream<List<OnlineMatchClue>> watchMatchClues(String matchId) {
    return _client
        .from('match_clues')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .map(
          (rows) => rows
              .map((row) => OnlineMatchClue.fromMap(row))
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        );
  }

  /// Submit a vote for a target player.
  Future<Map<String, dynamic>> submitVote({
    required String matchId,
    required String targetPlayerId,
  }) async {
    try {
      final result = await _client.rpc(
        'submit_vote',
        params: {
          'input_match_id': matchId,
          'input_target_player_id': targetPlayerId,
        },
      );
      return result as Map<String, dynamic>;
    } on PostgrestException catch (error) {
      throw Exception(_friendlyMessage(error));
    }
  }

  /// Resolve votes after all players have voted.
  Future<VoteResolutionResult> resolveVotes(String matchId) async {
    try {
      final result = await _client.rpc(
        'resolve_votes',
        params: {'input_match_id': matchId},
      );
      return VoteResolutionResult.fromMap(result as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw Exception(_friendlyMessage(error));
    }
  }

  /// Impostor makes their choice: 'guess' or 'skip'.
  Future<Map<String, dynamic>> impostorMakeChoice({
    required String matchId,
    required String choice,
  }) async {
    try {
      final result = await _client.rpc(
        'impostor_make_choice',
        params: {
          'input_match_id': matchId,
          'input_choice': choice,
        },
      );
      return result as Map<String, dynamic>;
    } on PostgrestException catch (error) {
      throw Exception(_friendlyMessage(error));
    }
  }

  /// Override match result to give victory to an impostor.
  Future<MatchScoresResult> overrideImpostorVictory({
    required String matchId,
    required String impostorPlayerId,
  }) async {
    try {
      final result = await _client.rpc(
        'override_impostor_victory',
        params: {
          'input_match_id': matchId,
          'input_impostor_player_id': impostorPlayerId,
        },
      );
      return MatchScoresResult.fromMap(result as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw Exception(_friendlyMessage(error));
    }
  }

  /// Submit an impostor's guess for the secret word.
  Future<ImpostorGuessResult> submitImpostorGuess({
    required String matchId,
    required String guess,
  }) async {
    try {
      final result = await _client.rpc(
        'submit_impostor_guess',
        params: {
          'input_match_id': matchId,
          'input_guess': guess,
        },
      );
      return ImpostorGuessResult.fromMap(result as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw Exception(_friendlyMessage(error));
    }
  }

  /// Skip the impostor's guess opportunity.
  Future<ImpostorGuessResult> skipImpostorGuess(String matchId) async {
    try {
      final result = await _client.rpc(
        'skip_impostor_guess',
        params: {'input_match_id': matchId},
      );
      return ImpostorGuessResult.fromMap(result as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw Exception(_friendlyMessage(error));
    }
  }

  /// Calculate final match scores.
  Future<MatchScoresResult> calculateMatchScores(String matchId) async {
    try {
      final result = await _client.rpc(
        'calculate_match_scores',
        params: {'input_match_id': matchId},
      );
      return MatchScoresResult.fromMap(result as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw Exception(_friendlyMessage(error));
    }
  }

  /// Watch match votes via Realtime stream.
  Stream<List<OnlineMatchVote>> watchMatchVotes(String matchId) {
    return _client
        .from('match_votes')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .map(
          (rows) => rows
              .map((row) => OnlineMatchVote.fromMap(row))
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        );
  }

  /// Find the active match for a room (if any).
  Future<String?> getActiveMatchForRoom(String roomId) async {
    try {
      final rows = await _client
          .from('matches')
          .select('id')
          .eq('room_id', roomId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1);

      if (rows.isEmpty) return null;
      return rows.first['id'] as String;
    } catch (_) {
      return null;
    }
  }

  String _friendlyMessage(PostgrestException error) {
    final message = error.message.trim();
    if (message.isNotEmpty) return message;
    return 'Ocurrio un error inesperado en la partida online.';
  }
}
