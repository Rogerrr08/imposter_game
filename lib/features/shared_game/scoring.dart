import '../../models/game_state.dart';

// ─── Express mode ───

/// Civiles ganan en Express: +3 si votó correctamente a un impostor, +1 si no votó mal.
List<GamePlayer> applyExpressCivilWinScoring(List<GamePlayer> players) {
  return players.map((player) {
    if (player.role != PlayerRole.civil) return player;
    if (player.votedIncorrectly) return player;
    if (player.votedImpostorCorrectly) {
      return player.copyWith(points: player.points + 3);
    }
    return player.copyWith(points: player.points + 1);
  }).toList();
}

/// Impostores sobreviven en Express: +5 si no fue eliminado, +1 si fue eliminado (sin fallo de adivinanza).
List<GamePlayer> applyExpressImpostorSurvivalScoring(List<GamePlayer> players) {
  return players.map((player) {
    if (player.role != PlayerRole.impostor) return player;
    if (player.eliminatedByFailedGuess) return player;
    if (player.isEliminated) {
      return player.copyWith(points: player.points + 1);
    }
    return player.copyWith(points: player.points + 5);
  }).toList();
}

// ─── Classic mode: per-elimination ───

/// Un civil fue eliminado: -1 a civiles que votaron por él, y se marcan como votedIncorrectly.
List<GamePlayer> applyClassicCivilEliminationScoring(
  List<GamePlayer> players,
  Map<String, String> votes,
  String eliminatedCivilName,
) {
  final penalizedVoters = votes.entries
      .where((entry) => entry.value == eliminatedCivilName)
      .map((entry) => entry.key)
      .toSet();

  return players.map((player) {
    if (player.role == PlayerRole.civil &&
        penalizedVoters.contains(player.name)) {
      return player.copyWith(
        points: player.points - 1,
        votedIncorrectly: true,
      );
    }
    return player;
  }).toList();
}

/// Un impostor fue eliminado: +2 a civiles que votaron por él.
List<GamePlayer> applyClassicImpostorEliminationScoring(
  List<GamePlayer> players,
  Map<String, String> votes,
  String eliminatedImpostorName,
) {
  final rewardedVoters = votes.entries
      .where((entry) => entry.value == eliminatedImpostorName)
      .map((entry) => entry.key)
      .toSet();

  return players.map((player) {
    if (player.role == PlayerRole.civil &&
        rewardedVoters.contains(player.name)) {
      return player.copyWith(points: player.points + 2);
    }
    return player;
  }).toList();
}

// ─── Classic mode: end-of-game ───

/// Civiles ganan en Clásico: +2 a civiles que nunca votaron mal.
List<GamePlayer> applyClassicCivilWinScoring(List<GamePlayer> players) {
  return players.map((player) {
    if (player.role != PlayerRole.civil) return player;
    if (player.votedIncorrectly) return player;
    return player.copyWith(points: player.points + 2);
  }).toList();
}

/// Impostores ganan en Clásico: +5 si no fue eliminado, +1 si fue eliminado (sin fallo).
List<GamePlayer> applyClassicImpostorWinScoring(List<GamePlayer> players) {
  return players.map((player) {
    if (player.role != PlayerRole.impostor) return player;
    if (player.isEliminated) {
      if (player.eliminatedByFailedGuess) return player;
      return player.copyWith(points: player.points + 1);
    }
    return player.copyWith(points: player.points + 5);
  }).toList();
}
