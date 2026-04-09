enum OnlineMatchStatus {
  active,
  finished,
  cancelled;

  static OnlineMatchStatus fromValue(String value) {
    switch (value) {
      case 'finished':
        return OnlineMatchStatus.finished;
      case 'cancelled':
        return OnlineMatchStatus.cancelled;
      case 'active':
      default:
        return OnlineMatchStatus.active;
    }
  }
}

enum OnlineMatchPhase {
  roleReveal,
  clueWriting,
  voting,
  voteResult,
  impostorChoice,
  impostorGuess,
  finished;

  static OnlineMatchPhase fromValue(String value) {
    switch (value) {
      case 'clue_writing':
        return OnlineMatchPhase.clueWriting;
      case 'voting':
        return OnlineMatchPhase.voting;
      case 'vote_result':
        return OnlineMatchPhase.voteResult;
      case 'impostor_choice':
        return OnlineMatchPhase.impostorChoice;
      case 'impostor_guess':
        return OnlineMatchPhase.impostorGuess;
      case 'finished':
        return OnlineMatchPhase.finished;
      case 'role_reveal':
      default:
        return OnlineMatchPhase.roleReveal;
    }
  }

  String toValue() {
    switch (this) {
      case OnlineMatchPhase.roleReveal:
        return 'role_reveal';
      case OnlineMatchPhase.clueWriting:
        return 'clue_writing';
      case OnlineMatchPhase.voting:
        return 'voting';
      case OnlineMatchPhase.voteResult:
        return 'vote_result';
      case OnlineMatchPhase.impostorChoice:
        return 'impostor_choice';
      case OnlineMatchPhase.impostorGuess:
        return 'impostor_guess';
      case OnlineMatchPhase.finished:
        return 'finished';
    }
  }
}

class OnlineMatch {
  final String id;
  final String roomId;
  final OnlineMatchStatus status;
  final String category;
  final bool hintsEnabled;
  final int impostorCount;
  final int durationSeconds;
  final OnlineMatchPhase currentPhase;
  final int currentRound;
  final int currentTurnIndex;
  final String? startingPlayerId;
  final int stateVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OnlineMatch({
    required this.id,
    required this.roomId,
    required this.status,
    required this.category,
    required this.hintsEnabled,
    required this.impostorCount,
    required this.durationSeconds,
    required this.currentPhase,
    required this.currentRound,
    required this.currentTurnIndex,
    this.startingPlayerId,
    required this.stateVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OnlineMatch.fromMap(Map<String, dynamic> map) {
    return OnlineMatch(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      status: OnlineMatchStatus.fromValue(map['status'] as String? ?? 'active'),
      category: map['category'] as String,
      hintsEnabled: map['hints_enabled'] as bool? ?? true,
      impostorCount: map['impostor_count'] as int? ?? 1,
      durationSeconds: map['duration_seconds'] as int? ?? 120,
      currentPhase: OnlineMatchPhase.fromValue(
        map['current_phase'] as String? ?? 'role_reveal',
      ),
      currentRound: map['current_round'] as int? ?? 1,
      currentTurnIndex: map['current_turn_index'] as int? ?? 0,
      startingPlayerId: map['starting_player_id'] as String?,
      stateVersion: map['state_version'] as int? ?? 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnlineMatch &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          status == other.status &&
          currentPhase == other.currentPhase &&
          currentRound == other.currentRound &&
          currentTurnIndex == other.currentTurnIndex &&
          stateVersion == other.stateVersion;

  @override
  int get hashCode => Object.hash(
        id,
        status,
        currentPhase,
        currentRound,
        currentTurnIndex,
        stateVersion,
      );
}

class OnlineMatchPlayer {
  final String id;
  final String matchId;
  final String userId;
  final String displayName;
  final int seatOrder;
  final String role;
  final String? hint;
  final bool isEliminated;
  final int points;
  final bool votedIncorrectly;
  final bool eliminatedByFailedGuess;
  final bool roleConfirmed;
  final bool isConnected;
  final String? guessWord;

  const OnlineMatchPlayer({
    required this.id,
    required this.matchId,
    required this.userId,
    required this.displayName,
    required this.seatOrder,
    required this.role,
    this.hint,
    required this.isEliminated,
    required this.points,
    required this.votedIncorrectly,
    required this.eliminatedByFailedGuess,
    required this.roleConfirmed,
    required this.isConnected,
    this.guessWord,
  });

  bool get isImpostor => role == 'impostor';
  bool get isCivil => role == 'civil';

  factory OnlineMatchPlayer.fromMap(Map<String, dynamic> map) {
    return OnlineMatchPlayer(
      id: map['id'] as String,
      matchId: map['match_id'] as String,
      userId: map['user_id'] as String,
      displayName: map['display_name'] as String,
      seatOrder: map['seat_order'] as int? ?? 0,
      role: map['role'] as String? ?? 'civil',
      hint: map['hint'] as String?,
      isEliminated: map['is_eliminated'] as bool? ?? false,
      points: map['points'] as int? ?? 0,
      votedIncorrectly: map['voted_incorrectly'] as bool? ?? false,
      eliminatedByFailedGuess:
          map['eliminated_by_failed_guess'] as bool? ?? false,
      roleConfirmed: map['role_confirmed'] as bool? ?? false,
      isConnected: map['is_connected'] as bool? ?? true,
      guessWord: map['guess_word'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnlineMatchPlayer &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isEliminated == other.isEliminated &&
          points == other.points &&
          votedIncorrectly == other.votedIncorrectly &&
          eliminatedByFailedGuess == other.eliminatedByFailedGuess &&
          roleConfirmed == other.roleConfirmed &&
          isConnected == other.isConnected;

  @override
  int get hashCode => Object.hash(
        id,
        isEliminated,
        points,
        votedIncorrectly,
        eliminatedByFailedGuess,
        roleConfirmed,
        isConnected,
      );
}

/// The player's own view of the match, returned by get_my_match_state RPC.
/// Contains role and word (word is null for impostors).
class MyMatchState {
  final String matchId;
  final String roomId;
  final OnlineMatchStatus status;
  final String category;
  final bool hintsEnabled;
  final int impostorCount;
  final int durationSeconds;
  final OnlineMatchPhase currentPhase;
  final int currentRound;
  final int currentTurnIndex;
  final int stateVersion;
  // Player-specific
  final String myPlayerId;
  final String myRole;
  final String? myHint;
  final int mySeatOrder;
  final bool myIsEliminated;
  final int myPoints;
  final bool myRoleConfirmed;
  /// The secret word — null for impostors.
  final String? word;

  const MyMatchState({
    required this.matchId,
    required this.roomId,
    required this.status,
    required this.category,
    required this.hintsEnabled,
    required this.impostorCount,
    required this.durationSeconds,
    required this.currentPhase,
    required this.currentRound,
    required this.currentTurnIndex,
    required this.stateVersion,
    required this.myPlayerId,
    required this.myRole,
    this.myHint,
    required this.mySeatOrder,
    required this.myIsEliminated,
    required this.myPoints,
    required this.myRoleConfirmed,
    this.word,
  });

  bool get isImpostor => myRole == 'impostor';
  bool get isCivil => myRole == 'civil';

  factory MyMatchState.fromMap(Map<String, dynamic> map) {
    return MyMatchState(
      matchId: map['match_id'] as String,
      roomId: map['room_id'] as String,
      status: OnlineMatchStatus.fromValue(map['status'] as String? ?? 'active'),
      category: map['category'] as String,
      hintsEnabled: map['hints_enabled'] as bool? ?? true,
      impostorCount: map['impostor_count'] as int? ?? 1,
      durationSeconds: map['duration_seconds'] as int? ?? 120,
      currentPhase: OnlineMatchPhase.fromValue(
        map['current_phase'] as String? ?? 'role_reveal',
      ),
      currentRound: map['current_round'] as int? ?? 1,
      currentTurnIndex: map['current_turn_index'] as int? ?? 0,
      stateVersion: map['state_version'] as int? ?? 1,
      myPlayerId: map['my_player_id'] as String,
      myRole: map['my_role'] as String,
      myHint: map['my_hint'] as String?,
      mySeatOrder: map['my_seat_order'] as int? ?? 0,
      myIsEliminated: map['my_is_eliminated'] as bool? ?? false,
      myPoints: map['my_points'] as int? ?? 0,
      myRoleConfirmed: map['my_role_confirmed'] as bool? ?? false,
      word: map['word'] as String?,
    );
  }
}

class OnlineMatchClue {
  final String id;
  final String matchId;
  final int roundNumber;
  final String playerId;
  final int turnOrder;
  final String clue;
  final DateTime createdAt;

  const OnlineMatchClue({
    required this.id,
    required this.matchId,
    required this.roundNumber,
    required this.playerId,
    required this.turnOrder,
    required this.clue,
    required this.createdAt,
  });

  factory OnlineMatchClue.fromMap(Map<String, dynamic> map) {
    return OnlineMatchClue(
      id: map['id'] as String,
      matchId: map['match_id'] as String,
      roundNumber: map['round_number'] as int? ?? 1,
      playerId: map['player_id'] as String,
      turnOrder: map['turn_order'] as int? ?? 0,
      clue: map['clue'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnlineMatchClue &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class OnlineMatchVote {
  final String id;
  final String matchId;
  final int roundNumber;
  final String voterId;
  final String targetPlayerId;
  final bool isTiebreak;
  final DateTime createdAt;

  const OnlineMatchVote({
    required this.id,
    required this.matchId,
    required this.roundNumber,
    required this.voterId,
    required this.targetPlayerId,
    required this.isTiebreak,
    required this.createdAt,
  });

  factory OnlineMatchVote.fromMap(Map<String, dynamic> map) {
    return OnlineMatchVote(
      id: map['id'] as String,
      matchId: map['match_id'] as String,
      roundNumber: map['round_number'] as int? ?? 1,
      voterId: map['voter_id'] as String,
      targetPlayerId: map['target_player_id'] as String,
      isTiebreak: map['is_tiebreak'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnlineMatchVote &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Result returned by submit_impostor_guess or skip_impostor_guess RPC.
class ImpostorGuessResult {
  final bool? correct; // null for skip
  final String result; // 'game_over' or 'continue'
  final String? winner; // 'civils' or 'impostors'
  final String? guess;
  final String? word;
  final String? nextPhase;

  const ImpostorGuessResult({
    this.correct,
    required this.result,
    this.winner,
    this.guess,
    this.word,
    this.nextPhase,
  });

  bool get isGameOver => result == 'game_over';

  factory ImpostorGuessResult.fromMap(Map<String, dynamic> map) {
    return ImpostorGuessResult(
      correct: map['correct'] as bool?,
      result: map['result'] as String,
      winner: map['winner'] as String?,
      guess: map['guess'] as String?,
      word: map['word'] as String?,
      nextPhase: map['next_phase'] as String?,
    );
  }
}

/// Result returned by calculate_match_scores RPC.
class MatchScoresResult {
  final String winner;
  final String word;
  final String category;
  final List<PlayerScore> scores;

  const MatchScoresResult({
    required this.winner,
    required this.word,
    required this.category,
    required this.scores,
  });

  bool get civilsWon => winner == 'civils';
  bool get impostorsWon => winner == 'impostors';

  factory MatchScoresResult.fromMap(Map<String, dynamic> map) {
    final scoresList = (map['scores'] as List<dynamic>)
        .map((e) => PlayerScore.fromMap(e as Map<String, dynamic>))
        .toList();
    return MatchScoresResult(
      winner: map['winner'] as String,
      word: map['word'] as String,
      category: map['category'] as String,
      scores: scoresList,
    );
  }
}

class PlayerScore {
  final String playerId;
  final String userId;
  final String displayName;
  final String role;
  final int points;
  final bool isEliminated;
  final bool votedIncorrectly;
  final bool eliminatedByFailedGuess;
  final String? guessWord;

  const PlayerScore({
    required this.playerId,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.points,
    required this.isEliminated,
    required this.votedIncorrectly,
    required this.eliminatedByFailedGuess,
    this.guessWord,
  });

  bool get isImpostor => role == 'impostor';
  bool get isCivil => role == 'civil';

  factory PlayerScore.fromMap(Map<String, dynamic> map) {
    return PlayerScore(
      playerId: map['player_id'] as String,
      userId: map['user_id'] as String,
      displayName: map['display_name'] as String,
      role: map['role'] as String,
      points: map['points'] as int? ?? 0,
      isEliminated: map['is_eliminated'] as bool? ?? false,
      votedIncorrectly: map['voted_incorrectly'] as bool? ?? false,
      eliminatedByFailedGuess:
          map['eliminated_by_failed_guess'] as bool? ?? false,
      guessWord: map['guess_word'] as String?,
    );
  }
}

/// Result returned by resolve_votes RPC.
class VoteResolutionResult {
  final String result; // 'tie', 'game_over', 'impostor_eliminated', 'civil_eliminated'
  final String? eliminatedPlayerId;
  final String? eliminatedRole;
  final String? winner; // 'civils' or 'impostors'
  final String? nextPhase;
  final List<String>? tiedPlayerIds;
  final int? maxVotes;

  const VoteResolutionResult({
    required this.result,
    this.eliminatedPlayerId,
    this.eliminatedRole,
    this.winner,
    this.nextPhase,
    this.tiedPlayerIds,
    this.maxVotes,
  });

  bool get isTie => result == 'tie';
  bool get isGameOver => result == 'game_over';
  bool get isImpostorEliminated => result == 'impostor_eliminated';
  bool get isCivilEliminated => result == 'civil_eliminated';

  factory VoteResolutionResult.fromMap(Map<String, dynamic> map) {
    return VoteResolutionResult(
      result: map['result'] as String,
      eliminatedPlayerId: map['eliminated_player_id'] as String?,
      eliminatedRole: map['eliminated_role'] as String?,
      winner: map['winner'] as String?,
      nextPhase: map['next_phase'] as String?,
      tiedPlayerIds: (map['tied_player_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      maxVotes: map['max_votes'] as int?,
    );
  }
}
