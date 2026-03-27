import '../data/word_bank.dart';

enum PlayerRole { civil, impostor }

enum GamePhase { setup, roleReveal, playing, voting, results }

class GamePlayer {
  final String name;
  final PlayerRole role;
  final String? hint;
  bool isEliminated;
  int points;
  /// Whether this civil correctly voted an impostor at least once.
  bool votedImpostorCorrectly;

  GamePlayer({
    required this.name,
    required this.role,
    this.hint,
    this.isEliminated = false,
    this.points = 0,
    this.votedImpostorCorrectly = false,
  });
}

class GameConfig {
  final List<String> playerNames;
  final int impostorCount;
  final bool hintsEnabled;
  final int durationSeconds;
  final WordCategory category;
  final int? groupId;

  const GameConfig({
    required this.playerNames,
    required this.impostorCount,
    required this.hintsEnabled,
    required this.durationSeconds,
    required this.category,
    this.groupId,
  });
}

class ActiveGame {
  static const int maxLives = 3;

  final GameConfig config;
  final String secretWord;
  final List<String> wordHints;
  final List<GamePlayer> players;
  GamePhase phase;
  int currentRevealIndex;
  int timeRemainingSeconds;
  bool civilsWon;
  bool impostorGuessedWord;

  /// Incorrect votes remaining. Civils lose if this reaches 0.
  int livesRemaining;

  /// Name of the impostor who guessed the word (for scoring).
  String? impostorWhoGuessed;

  ActiveGame({
    required this.config,
    required this.secretWord,
    required this.wordHints,
    required this.players,
    this.phase = GamePhase.setup,
    this.currentRevealIndex = 0,
    int? timeRemainingSeconds,
    this.civilsWon = false,
    this.impostorGuessedWord = false,
    this.livesRemaining = maxLives,
    this.impostorWhoGuessed,
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
}
