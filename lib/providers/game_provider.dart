import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/word_bank.dart';
import '../database/database.dart';
import '../models/quick_game_preset.dart';
import '../models/game_state.dart';
import '../utils/text_normalize.dart';
import 'database_provider.dart';

final gameProvider = NotifierProvider<GameNotifier, ActiveGame?>(
  GameNotifier.new,
);

final lastQuickGamePresetProvider =
    NotifierProvider<QuickGamePresetNotifier, QuickGamePreset?>(
  QuickGamePresetNotifier.new,
);

final lastGroupGamePresetsProvider =
    NotifierProvider<GroupGamePresetNotifier, Map<int, QuickGamePreset>>(
  GroupGamePresetNotifier.new,
);

class GameNotifier extends Notifier<ActiveGame?> {
  final _random = Random();

  // Shuffle bag for impostor selection: keyed by sorted player names,
  // each bag contains player names that haven't been impostor yet.
  static final Map<String, List<String>> _impostorBags = {};
  static final _staticRandom = Random();

  @override
  ActiveGame? build() => null;

  /// Pick impostors using a shuffle bag so every player gets a turn
  /// before anyone repeats.
  static List<String> _pickImpostorsFromBag(
    List<String> playerNames,
    int count,
  ) {
    final sorted = List<String>.from(playerNames)..sort();
    final bagKey = sorted.join('|');

    final bag = _impostorBags.putIfAbsent(bagKey, () => <String>[]);

    final picked = <String>[];
    for (int i = 0; i < count; i++) {
      if (bag.isEmpty) {
        // Refill with all players, minus anyone already picked this round
        bag.addAll(sorted.where((n) => !picked.contains(n)));
        bag.shuffle(_staticRandom);
      }
      if (bag.isNotEmpty) {
        picked.add(bag.removeLast());
      }
    }
    return picked;
  }

  void startNewGame(GameConfig config) {
    final wordEntry = WordBank.getRandomWordFromCategories(config.categories);

    final impostorNames = _pickImpostorsFromBag(
      config.playerNames,
      config.impostorCount,
    );

    final availableHints = WordBank.getHardHints(
      wordEntry,
      count: config.impostorCount,
    );

    int hintIndex = 0;
    final players = <GamePlayer>[];
    for (final name in config.playerNames) {
      final isImpostor = impostorNames.contains(name);
      String? hint;

      if (isImpostor && config.hintsEnabled && availableHints.isNotEmpty) {
        hint = availableHints[hintIndex % availableHints.length];
        hintIndex++;
      }

      players.add(
        GamePlayer(
          name: name,
          role: isImpostor ? PlayerRole.impostor : PlayerRole.civil,
          hint: hint,
        ),
      );
    }

    final startingPlayerName = _determineStartingPlayerName(
      players,
      hintsEnabled: config.hintsEnabled,
    );

    state = ActiveGame(
      config: config,
      secretWord: wordEntry.word,
      wordCategory: wordEntry.category,
      wordHints: wordEntry.hints,
      players: players,
      startingPlayerName: startingPlayerName,
      phase: GamePhase.roleReveal,
      currentRevealIndex: 0,
      timeRemainingSeconds: config.durationSeconds,
    );
  }

  void nextReveal() {
    if (state == null) return;
    final game = state!;
    if (game.currentRevealIndex >= game.players.length - 1) return;

    state = _copyGame(
      game,
      phase: GamePhase.roleReveal,
      currentRevealIndex: game.currentRevealIndex + 1,
    );
  }

  void startPlaying() {
    if (state == null) return;
    state = _copyGame(state!, phase: GamePhase.playing);
  }

  void tick() {
    if (state == null) return;
    final game = state!;
    if (game.phase != GamePhase.playing || game.timeRemainingSeconds <= 0) {
      return;
    }

    state = _copyGame(
      game,
      phase: GamePhase.playing,
      timeRemainingSeconds: game.timeRemainingSeconds - 1,
    );
  }

  void timeUp() {
    if (state == null) return;
    final game = state!;
    final scoredPlayers = _applyImpostorSurvivalScoring(game.players);
    _finishGame(
      civilsWon: false,
      impostorGuessedWord: false,
      players: scoredPlayers,
    );
  }

  bool eliminatePlayer(String playerName, {String? votedBy}) {
    if (state == null) return false;
    final game = state!;

    final player = game.players.firstWhere((entry) => entry.name == playerName);
    if (player.isEliminated) {
      return player.role == PlayerRole.impostor;
    }

    final wasImpostor = player.role == PlayerRole.impostor;
    var newLives = game.livesRemaining;

    // Build updated player list
    final updatedPlayers = game.players.map((p) {
      if (wasImpostor) {
        if (p.name == playerName) {
          return p.copyWith(isEliminated: true);
        }
        if (p.name == votedBy && p.role == PlayerRole.civil) {
          return p.copyWith(votedImpostorCorrectly: true);
        }
      } else {
        if (p.name == votedBy &&
            p.role == PlayerRole.civil &&
            !p.isEliminated) {
          return p.copyWith(isEliminated: true, votedIncorrectly: true);
        }
      }
      return p;
    }).toList();

    if (!wasImpostor) {
      newLives = max(0, newLives - 1);
    }

    // Build a temporary game to check win conditions
    final updatedGame = _copyGame(
      game,
      phase: GamePhase.playing,
      players: updatedPlayers,
      livesRemaining: newLives,
    );

    if (updatedGame.allImpostorsFound) {
      final scoredPlayers = _applyCivilWinScoring(updatedPlayers);
      _finishGame(
        civilsWon: true,
        impostorGuessedWord: false,
        players: scoredPlayers,
        livesRemaining: newLives,
      );
    } else if (updatedGame.impostorsWinByNumbers || updatedGame.noLivesLeft) {
      final scoredPlayers = _applyImpostorSurvivalScoring(updatedPlayers);
      _finishGame(
        civilsWon: false,
        impostorGuessedWord: false,
        players: scoredPlayers,
        livesRemaining: newLives,
      );
    } else {
      state = updatedGame;
    }

    return wasImpostor;
  }

  bool impostorGuess(String guess, {String? guessedBy}) {
    if (state == null || guessedBy == null) return false;
    final game = state!;

    final guessingImpostor = _findPlayerByName(game.activeImpostors, guessedBy);
    if (guessingImpostor == null) return false;

    if (_matchesSecretWord(guess, game.secretWord)) {
      final scoredPlayers = game.players.map((p) {
        if (p.role == PlayerRole.impostor) {
          return p.copyWith(points: p.points + (p.name == guessedBy ? 3 : 1));
        }
        return p;
      }).toList();

      _finishGame(
        civilsWon: false,
        impostorGuessedWord: true,
        guesser: guessedBy,
        players: scoredPlayers,
      );
      return true;
    }

    // Failed guess — eliminate the guesser
    final updatedPlayers = game.players.map((p) {
      if (p.name == guessedBy) {
        return p.copyWith(isEliminated: true, eliminatedByFailedGuess: true);
      }
      return p;
    }).toList();

    final updatedGame = _copyGame(
      game,
      phase: GamePhase.playing,
      players: updatedPlayers,
    );

    if (updatedGame.allImpostorsFound) {
      final scoredPlayers = _applyCivilWinScoring(updatedPlayers);
      _finishGame(
        civilsWon: true,
        impostorGuessedWord: false,
        players: scoredPlayers,
      );
    } else if (updatedGame.impostorsWinByNumbers || updatedGame.noLivesLeft) {
      final scoredPlayers = _applyImpostorSurvivalScoring(updatedPlayers);
      _finishGame(
        civilsWon: false,
        impostorGuessedWord: false,
        players: scoredPlayers,
      );
    } else {
      state = updatedGame;
    }

    return false;
  }

  List<GamePlayer> _applyCivilWinScoring(List<GamePlayer> players) {
    return players.map((player) {
      if (player.role != PlayerRole.civil) return player;
      if (player.votedIncorrectly) return player;
      if (player.votedImpostorCorrectly) {
        return player.copyWith(points: player.points + 3);
      }
      return player.copyWith(points: player.points + 1);
    }).toList();
  }

  List<GamePlayer> _applyImpostorSurvivalScoring(List<GamePlayer> players) {
    return players.map((player) {
      if (player.role != PlayerRole.impostor) return player;
      if (player.eliminatedByFailedGuess) return player;
      if (player.isEliminated) {
        return player.copyWith(points: player.points + 1);
      }
      return player.copyWith(points: player.points + 5);
    }).toList();
  }

  Future<void> _finishGame({
    required bool civilsWon,
    required bool impostorGuessedWord,
    String? guesser,
    List<GamePlayer>? players,
    int? livesRemaining,
  }) async {
    if (state == null) return;
    final game = state!;

    state = _copyGame(
      game,
      phase: GamePhase.results,
      players: players,
      civilsWon: civilsWon,
      impostorGuessedWord: impostorGuessedWord,
      impostorWhoGuessed: guesser,
      livesRemaining: livesRemaining,
    );

    await _saveGameToDatabase(civilsWon, impostorGuessedWord);
  }

  Future<void> _saveGameToDatabase(
    bool civilsWon,
    bool impostorGuessedWord,
  ) async {
    if (state == null) return;
    final game = state!;

    try {
      final db = ref.read(databaseProvider);
      final gameDao = GameDao(db);

      final gameId = await gameDao.saveGame(
        groupId: game.config.groupId,
        category: game.wordCategory.name,
        word: game.secretWord,
        duration: game.config.durationSeconds,
        impostorCount: game.config.impostorCount,
        hintsEnabled: game.config.hintsEnabled,
        civilsWon: civilsWon,
        impostorGuessedWord: impostorGuessedWord,
        playerResults: game.players
            .map(
              (player) => GamePlayerEntry(
                playerName: player.name,
                wasImpostor: player.role == PlayerRole.impostor,
                points: player.points,
                wasEliminated: player.isEliminated,
              ),
            )
            .toList(),
      );

      state = _copyGame(game, savedGameId: gameId);
    } catch (_) {
      // Persistence should not block the game flow.
    }
  }

  /// Override result: impostor guessed correctly (synonym/manual consensus).
  /// Resets all points and applies impostor-guess scoring, then re-saves.
  Future<void> overrideImpostorGuessedCorrectly(String impostorName) async {
    if (state == null) return;
    final game = state!;

    final oldPlayerResults = game.players
        .map((p) => GamePlayerEntry(
              playerName: p.name,
              wasImpostor: p.role == PlayerRole.impostor,
              points: p.points,
              wasEliminated: p.isEliminated,
            ))
        .toList();

    // Reset all points to 0, then apply impostor guess scoring
    final scoredPlayers = game.players.map((p) {
      final base = p.copyWith(points: 0);
      if (base.role == PlayerRole.impostor) {
        return base.copyWith(points: base.name == impostorName ? 3 : 1);
      }
      return base;
    }).toList();

    state = _copyGame(
      game,
      players: scoredPlayers,
      civilsWon: false,
      impostorGuessedWord: true,
      impostorWhoGuessed: impostorName,
    );

    try {
      final db = ref.read(databaseProvider);
      final gameDao = GameDao(db);

      final newPlayerResults = scoredPlayers
          .map((p) => GamePlayerEntry(
                playerName: p.name,
                wasImpostor: p.role == PlayerRole.impostor,
                points: p.points,
                wasEliminated: p.isEliminated,
              ))
          .toList();

      if (game.savedGameId != null && game.config.groupId != null) {
        final newId = await gameDao.replaceGameResult(
          oldGameId: game.savedGameId!,
          groupId: game.config.groupId,
          category: game.wordCategory.name,
          word: game.secretWord,
          duration: game.config.durationSeconds,
          impostorCount: game.config.impostorCount,
          hintsEnabled: game.config.hintsEnabled,
          newCivilsWon: false,
          newImpostorGuessedWord: true,
          oldCivilsWon: game.civilsWon,
          oldPlayerResults: oldPlayerResults,
          newPlayerResults: newPlayerResults,
        );
        state = _copyGame(state!, savedGameId: newId);
      } else {
        await _saveGameToDatabase(false, true);
      }
    } catch (_) {
      // Persistence should not block UI
    }
  }

  void clearGame() {
    state = null;
  }

  GamePlayer? _findPlayerByName(List<GamePlayer> players, String? name) {
    if (name == null) return null;

    for (final player in players) {
      if (player.name == name) {
        return player;
      }
    }

    return null;
  }

  ActiveGame _copyGame(
    ActiveGame game, {
    List<GamePlayer>? players,
    GamePhase? phase,
    int? currentRevealIndex,
    int? timeRemainingSeconds,
    bool? civilsWon,
    bool? impostorGuessedWord,
    int? livesRemaining,
    String? impostorWhoGuessed,
    int? savedGameId,
  }) {
    return ActiveGame(
      config: game.config,
      secretWord: game.secretWord,
      wordCategory: game.wordCategory,
      wordHints: game.wordHints,
      players: players ?? game.players,
      startingPlayerName: game.startingPlayerName,
      phase: phase ?? game.phase,
      currentRevealIndex: currentRevealIndex ?? game.currentRevealIndex,
      timeRemainingSeconds:
          timeRemainingSeconds ?? game.timeRemainingSeconds,
      civilsWon: civilsWon ?? game.civilsWon,
      impostorGuessedWord:
          impostorGuessedWord ?? game.impostorGuessedWord,
      livesRemaining: livesRemaining ?? game.livesRemaining,
      impostorWhoGuessed: impostorWhoGuessed ?? game.impostorWhoGuessed,
      savedGameId: savedGameId ?? game.savedGameId,
    );
  }

  bool _matchesSecretWord(String guess, String secretWord) {
    final normalizedGuess = normalizeText(guess);
    final normalizedSecret = normalizeText(secretWord);

    if (normalizedGuess == normalizedSecret) {
      return true;
    }

    if (!_canMatchBySurname(secretWord)) {
      return false;
    }

    final secretTokens = normalizedSecret
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();

    if (secretTokens.length < 2) {
      return false;
    }

    return normalizedGuess == secretTokens.last;
  }

  bool _canMatchBySurname(String secretWord) {
    final normalizedSecret = normalizeText(secretWord);

    for (final allowedWord in _surnameMatchAllowedWords) {
      if (normalizeText(allowedWord) == normalizedSecret) {
        return true;
      }
    }

    return false;
  }

  String? _determineStartingPlayerName(
    List<GamePlayer> players, {
    required bool hintsEnabled,
  }) {
    if (players.isEmpty) return null;

    final randomStartingIndex = _random.nextInt(players.length);
    final randomStartingPlayer = players[randomStartingIndex];

    if (hintsEnabled) {
      return randomStartingPlayer.name;
    }

    if (randomStartingPlayer.role == PlayerRole.civil) {
      return randomStartingPlayer.name;
    }

    for (int offset = 1; offset < players.length; offset++) {
      final candidateIndex =
          (randomStartingIndex - offset + players.length) % players.length;
      final candidate = players[candidateIndex];

      if (candidate.role == PlayerRole.civil) {
        return candidate.name;
      }
    }

    return randomStartingPlayer.name;
  }
}

const Set<String> _surnameMatchAllowedWords = {
  'Harry Potter',
  'Mickey Mouse',
  'Darth Vader',
  'Taylor Swift',
  'Indiana Jones',
  'Buzz Lightyear',
  'Lionel Messi',
  'LeBron James',
  'Usain Bolt',
  'Michael Jordan',
  'Cristiano Ronaldo',
  'Serena Williams',
  'Rafael Nadal',
  'Tiger Woods',
  'Simone Biles',
  'Kylian Mbappé',
  'Mike Tyson',
  'Lewis Hamilton',
  'Stephen Curry',
  'Zinedine Zidane',
  'Roger Federer',
  'Muhammad Ali',
  'Erling Haaland',
};

final rankingsProvider =
    FutureProvider.family<List<PlayerRanking>, ({int groupId, String? category})>(
  (ref, params) async {
    final db = ref.read(databaseProvider);
    final gameDao = GameDao(db);

    if (params.category != null) {
      return gameDao.getRankingForGroupByCategory(
        params.groupId,
        params.category!,
      );
    }

    return gameDao.getRankingForGroup(params.groupId);
  },
);

final gameHistoryProvider = FutureProvider.family<
    List<GameWithPlayers>,
    ({int groupId, String? category})>((ref, params) async {
  final db = ref.read(databaseProvider);
  final gameDao = GameDao(db);

  final games = params.category != null
      ? await gameDao.getGamesForGroupByCategory(
          params.groupId,
          params.category!,
        )
      : await gameDao.getGamesForGroup(params.groupId);

  final detailsList = await gameDao.getGamesWithPlayers(games);

  return detailsList
      .map((details) => GameWithPlayers(
            game: details.game,
            players: details.players
                .map((player) => GamePlayer2(
                      playerName: player.playerName,
                      wasImpostor: player.wasImpostor,
                      points: player.points,
                      wasEliminated: player.wasEliminated,
                    ))
                .toList(),
          ))
      .toList();
});

final rankingCategoryFilterProvider =
    NotifierProvider<CategoryFilterNotifier, String?>(
  CategoryFilterNotifier.new,
);

final historyCategoryFilterProvider =
    NotifierProvider<CategoryFilterNotifier, String?>(
  CategoryFilterNotifier.new,
);

class CategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setCategory(String? category) {
    state = category;
  }
}

class QuickGamePresetNotifier extends Notifier<QuickGamePreset?> {
  @override
  QuickGamePreset? build() => null;

  void save(QuickGamePreset preset) {
    state = preset;
  }

  void clear() {
    state = null;
  }
}

class GroupGamePresetNotifier extends Notifier<Map<int, QuickGamePreset>> {
  @override
  Map<int, QuickGamePreset> build() => <int, QuickGamePreset>{};

  QuickGamePreset? getForGroup(int groupId) => state[groupId];

  void saveForGroup(int groupId, QuickGamePreset preset) {
    state = {
      ...state,
      groupId: preset,
    };
  }

  void clearForGroup(int groupId) {
    final next = Map<int, QuickGamePreset>.from(state);
    next.remove(groupId);
    state = next;
  }
}

class GameWithPlayers {
  final Game game;
  final List<GamePlayer2> players;

  GameWithPlayers({required this.game, required this.players});
}

class GamePlayer2 {
  final String playerName;
  final bool wasImpostor;
  final int points;
  final bool wasEliminated;

  GamePlayer2({
    required this.playerName,
    required this.wasImpostor,
    required this.points,
    required this.wasEliminated,
  });
}
