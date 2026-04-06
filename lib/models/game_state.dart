import '../data/word_bank.dart';

enum PlayerRole { civil, impostor }

enum GamePhase { setup, roleReveal, playing, voting, results }

enum GameMode {
  express,
  classic;

  String get displayName => switch (this) {
        GameMode.express => '\u26A1 Modo Express',
        GameMode.classic => '\u{1F3DB}\uFE0F Modo Cl\u00E1sico',
      };

  String get subtitle => switch (this) {
        GameMode.express => 'Votaci\u00F3n directa, vidas y ritmo r\u00E1pido',
        GameMode.classic => 'Votaci\u00F3n an\u00F3nima por rondas y reglas tradicionales',
      };
}

class GamePlayer {
  final String name;
  final PlayerRole role;
  final String? hint;
  final bool isEliminated;
  final int points;
  final bool votedImpostorCorrectly;
  final bool votedIncorrectly;
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
      votedImpostorCorrectly:
          votedImpostorCorrectly ?? this.votedImpostorCorrectly,
      votedIncorrectly: votedIncorrectly ?? this.votedIncorrectly,
      eliminatedByFailedGuess:
          eliminatedByFailedGuess ?? this.eliminatedByFailedGuess,
    );
  }
}

class GameConfig {
  final List<String> playerNames;
  final int impostorCount;
  final bool hintsEnabled;
  final int durationSeconds;
  final List<WordCategory> categories;
  final GameMode mode;
  final int? groupId;

  const GameConfig({
    required this.playerNames,
    required this.impostorCount,
    required this.hintsEnabled,
    required this.durationSeconds,
    required this.categories,
    this.mode = GameMode.express,
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
  final int livesRemaining;
  final String? impostorWhoGuessed;
  final int? savedGameId;

  final Map<String, String> classicVotes;
  final List<String> classicVotingOrder;
  final int classicVotingIndex;
  final List<String> classicTieCandidates;
  final String? pendingClassicGuesserName;
  final String? lastEliminatedPlayerName;
  final bool? lastEliminatedWasImpostor;
  final Map<String, int> lastVoteTallies;

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
    this.classicVotes = const {},
    this.classicVotingOrder = const [],
    this.classicVotingIndex = 0,
    this.classicTieCandidates = const [],
    this.pendingClassicGuesserName,
    this.lastEliminatedPlayerName,
    this.lastEliminatedWasImpostor,
    this.lastVoteTallies = const {},
  }) : timeRemainingSeconds = timeRemainingSeconds ?? config.durationSeconds;

  bool get isClassicMode => config.mode == GameMode.classic;
  bool get isExpressMode => config.mode == GameMode.express;

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

  bool get awaitingClassicGuessDecision =>
      isClassicMode && pendingClassicGuesserName != null;

  bool get gameOver {
    if (isClassicMode) {
      if (awaitingClassicGuessDecision) return false;
      return allImpostorsFound || impostorsWinByNumbers || phase == GamePhase.results;
    }
    return allImpostorsFound || impostorsWinByNumbers || noLivesLeft;
  }

  bool get shouldShowStartingPlayer =>
      startingPlayerName != null &&
      players.every((player) => !player.isEliminated);

  String? get currentClassicVoterName {
    if (!isClassicMode) return null;
    if (classicVotingIndex < 0 || classicVotingIndex >= classicVotingOrder.length) {
      return null;
    }
    return classicVotingOrder[classicVotingIndex];
  }
}
