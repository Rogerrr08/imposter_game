import '../data/word_bank.dart';

enum PlayerRole { civil, impostor }

enum GamePhase { setup, roleReveal, playing, voting, results }

class GamePlayer {
  final String name;
  final PlayerRole role;
  final String? hint;
  final bool isEliminated;
  final int points;
  /// Whether this civil correctly voted an impostor at least once.
  final bool votedImpostorCorrectly;
  /// Whether this civil voted incorrectly (voted a non-impostor).
  final bool votedIncorrectly;
  /// Whether this impostor was eliminated by a failed guess (not by vote).
  final bool eliminatedByFailedGuess;

  const GamePlayer({
    required this.name,
    required this.role,
    this.hint,
    this.isEliminated = false,
    this.points = 0,
    this.votedImpostorCorrectly = false,
    this.votedIncorrectly = false,
    this.eliminatedByFailedGuess = false,
  });

  GamePlayer copyWith({
    bool? isEliminated,
    int? points,
    bool? votedImpostorCorrectly,
    bool? votedIncorrectly,
    bool? eliminatedByFailedGuess,
  }) {
    return GamePlayer(
      name: name,
      role: role,
      hint: hint,
      isEliminated: isEliminated ?? this.isEliminated,
      points: points ?? this.points,
      votedImpostorCorrectly: votedImpostorCorrectly ?? this.votedImpostorCorrectly,
      votedIncorrectly: votedIncorrectly ?? this.votedIncorrectly,
      eliminatedByFailedGuess: eliminatedByFailedGuess ?? this.eliminatedByFailedGuess,
    );
  }
}

class GameConfig {
  final List<String> playerNames;
  final int impostorCount;
  final bool hintsEnabled;
  final int durationSeconds;
  final List<WordCategory> categories;
  final int? groupId;

  const GameConfig({
    required this.playerNames,
    required this.impostorCount,
    required this.hintsEnabled,
    required this.durationSeconds,
    required this.categories,
    this.groupId,
  });
}

class ActiveGame {
  static const int maxLives = 3;

  final GameConfig config;
  final String secretWord;
  final WordCategory wordCategory;
  final List<String> wordHints;
  final List<GamePlayer> players;
  final String? startingPlayerName;
  final GamePhase phase;
  final int currentRevealIndex;
  final int timeRemainingSeconds;
  final bool civilsWon;
  final bool impostorGuessedWord;

  /// Incorrect votes remaining. Civils lose if this reaches 0.
  final int livesRemaining;

  /// Name of the impostor who guessed the word (for scoring).
  final String? impostorWhoGuessed;

  /// Database ID of the saved game (for result overrides).
  final int? savedGameId;

  ActiveGame({
    required this.config,
    required this.secretWord,
    required this.wordCategory,
    required this.wordHints,
    required this.players,
    this.startingPlayerName,
    this.phase = GamePhase.setup,
    this.currentRevealIndex = 0,
    int? timeRemainingSeconds,
    this.civilsWon = false,
    this.impostorGuessedWord = false,
    this.livesRemaining = maxLives,
    this.impostorWhoGuessed,
    this.savedGameId,
  }) : timeRemainingSeconds = timeRemainingSeconds ?? config.durationSeconds;

  List<GamePlayer> get activePlayers =>
      players.where((p) => !p.isEliminated).toList();

  List<GamePlayer> get activeCivils =>
      activePlayers.where((p) => p.role == PlayerRole.civil).toList();

  List<GamePlayer> get impostors =>
      players.where((p) => p.role == PlayerRole.impostor).toList();

  List<GamePlayer> get activeImpostors =>
      activePlayers.where((p) => p.role == PlayerRole.impostor).toList();

  bool get allImpostorsFound => activeImpostors.isEmpty;

  bool get impostorsWinByNumbers =>
      activePlayers.length <= 2 && activeImpostors.isNotEmpty;

  bool get noLivesLeft => livesRemaining <= 0;

  bool get gameOver => allImpostorsFound || impostorsWinByNumbers || noLivesLeft;

  bool get shouldShowStartingPlayer =>
      startingPlayerName != null && players.every((player) => !player.isEliminated);
}
