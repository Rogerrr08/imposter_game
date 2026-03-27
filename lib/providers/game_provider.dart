import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/word_bank.dart';
import '../database/database.dart';
import '../models/game_state.dart';
import 'database_provider.dart';

final gameProvider = NotifierProvider<GameNotifier, ActiveGame?>(
  GameNotifier.new,
);

class GameNotifier extends Notifier<ActiveGame?> {
  final _random = Random();

  @override
  ActiveGame? build() => null;

  void startNewGame(GameConfig config) {
    final wordEntry = WordBank.getRandomWord(config.category);

    final players = <GamePlayer>[];
    final shuffledNames = List<String>.from(config.playerNames)
      ..shuffle(_random);

    // Assign impostors
    final impostorIndices = <int>{};
    while (impostorIndices.length < config.impostorCount) {
      impostorIndices.add(_random.nextInt(shuffledNames.length));
    }

    // Shuffle hints to assign different ones to impostors
    final availableHints = List<String>.from(wordEntry.hints)..shuffle(_random);

    for (int i = 0; i < shuffledNames.length; i++) {
      final isImpostor = impostorIndices.contains(i);
      String? hint;
      if (isImpostor && config.hintsEnabled && availableHints.isNotEmpty) {
        hint =
            availableHints[impostorIndices.toList().indexOf(i) %
                availableHints.length];
      }

      players.add(
        GamePlayer(
          name: shuffledNames[i],
          role: isImpostor ? PlayerRole.impostor : PlayerRole.civil,
          hint: hint,
        ),
      );
    }

    // Restore original order for reveal
    final orderedPlayers = config.playerNames.map((name) {
      return players.firstWhere((p) => p.name == name);
    }).toList();

    state = ActiveGame(
      config: config,
      secretWord: wordEntry.word,
      wordHints: wordEntry.hints,
      players: orderedPlayers,
      phase: GamePhase.roleReveal,
      currentRevealIndex: 0,
      timeRemainingSeconds: config.durationSeconds,
    );
  }

  void nextReveal() {
    if (state == null) return;
    final game = state!;
    if (game.currentRevealIndex < game.players.length - 1) {
      state = ActiveGame(
        config: game.config,
        secretWord: game.secretWord,
        wordHints: game.wordHints,
        players: game.players,
        phase: GamePhase.roleReveal,
        currentRevealIndex: game.currentRevealIndex + 1,
        timeRemainingSeconds: game.timeRemainingSeconds,
      );
    }
  }

  void startPlaying() {
    if (state == null) return;
    final game = state!;
    state = ActiveGame(
      config: game.config,
      secretWord: game.secretWord,
      wordHints: game.wordHints,
      players: game.players,
      phase: GamePhase.playing,
      currentRevealIndex: game.currentRevealIndex,
      timeRemainingSeconds: game.timeRemainingSeconds,
    );
  }

  void tick() {
    if (state == null) return;
    final game = state!;
    if (game.phase != GamePhase.playing) return;
    if (game.timeRemainingSeconds <= 0) return;

    state = ActiveGame(
      config: game.config,
      secretWord: game.secretWord,
      wordHints: game.wordHints,
      players: game.players,
      phase: GamePhase.playing,
      currentRevealIndex: game.currentRevealIndex,
      timeRemainingSeconds: game.timeRemainingSeconds - 1,
    );
  }

  void timeUp() {
    if (state == null) return;
    final game = state!;
    _applyImpostorSurvivalScoring(game);
    _finishGame(civilsWon: false, impostorGuessedWord: false);
  }

  /// Eliminates a player by vote. Returns true if they were an impostor.
  bool eliminatePlayer(String playerName, {String? votedBy}) {
    if (state == null) return false;
    final game = state!;

    final player = game.players.firstWhere((p) => p.name == playerName);
    player.isEliminated = true;
    final wasImpostor = player.role == PlayerRole.impostor;

    if (wasImpostor) {
      // Track who voted correctly
      if (votedBy != null) {
        final voter = game.players.firstWhere((p) => p.name == votedBy);
        voter.votedImpostorCorrectly = true;
      }
    } else {
      // Incorrect vote: lose a life
      game.livesRemaining--;
    }

    // Check game over conditions
    if (game.allImpostorsFound) {
      // Civils win! Score: voter who found impostor gets 3, others get 1
      _applyCivilWinScoring(game);
      _finishGame(civilsWon: true, impostorGuessedWord: false);
    } else if (game.impostorsWinByNumbers || game.noLivesLeft) {
      // Impostors win by survival/numbers/no lives
      _applyImpostorSurvivalScoring(game);
      _finishGame(civilsWon: false, impostorGuessedWord: false);
    } else {
      // Game continues
      _rebuildState(game);
    }

    return wasImpostor;
  }

  /// Impostor guesses the word. Returns true if correct.
  bool impostorGuess(String guess, {String? guessedBy}) {
    if (state == null) return false;
    final game = state!;

    if (guess.trim().toLowerCase() == game.secretWord.toLowerCase()) {
      // Impostor who guessed: 3 pts, other impostors: 1 pt
      for (final p in game.impostors) {
        if (guessedBy != null && p.name == guessedBy) {
          p.points += 3;
        } else {
          p.points += 1;
        }
      }
      _finishGame(
        civilsWon: false,
        impostorGuessedWord: true,
        guesser: guessedBy,
      );
      return true;
    }
    return false;
  }

  /// Civils win: voter who found impostor = 3 pts, other civils = 1 pt.
  void _applyCivilWinScoring(ActiveGame game) {
    for (final p in game.players) {
      if (p.role == PlayerRole.civil) {
        if (p.votedImpostorCorrectly) {
          p.points += 3;
        } else {
          p.points += 1;
        }
      }
      // Impostors get 0
    }
  }

  /// Impostors win by survival: surviving impostors = 5 pts, eliminated impostors = 3 pts.
  void _applyImpostorSurvivalScoring(ActiveGame game) {
    for (final p in game.impostors) {
      if (!p.isEliminated) {
        p.points += 5;
      } else {
        p.points += 3;
      }
    }
    // Civils get 0
  }

  void _rebuildState(ActiveGame game) {
    state = ActiveGame(
      config: game.config,
      secretWord: game.secretWord,
      wordHints: game.wordHints,
      players: game.players,
      phase: GamePhase.playing,
      currentRevealIndex: game.currentRevealIndex,
      timeRemainingSeconds: game.timeRemainingSeconds,
      livesRemaining: game.livesRemaining,
    );
  }

  void _finishGame({
    required bool civilsWon,
    required bool impostorGuessedWord,
    String? guesser,
  }) {
    if (state == null) return;
    final game = state!;

    state = ActiveGame(
      config: game.config,
      secretWord: game.secretWord,
      wordHints: game.wordHints,
      players: game.players,
      phase: GamePhase.results,
      currentRevealIndex: game.currentRevealIndex,
      timeRemainingSeconds: game.timeRemainingSeconds,
      civilsWon: civilsWon,
      impostorGuessedWord: impostorGuessedWord,
      livesRemaining: game.livesRemaining,
      impostorWhoGuessed: guesser,
    );

    _saveGameToDatabase(civilsWon, impostorGuessedWord);
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

      await gameDao.saveGame(
        groupId: game.config.groupId,
        category: game.config.category.name,
        word: game.secretWord,
        duration: game.config.durationSeconds,
        impostorCount: game.config.impostorCount,
        hintsEnabled: game.config.hintsEnabled,
        civilsWon: civilsWon,
        impostorGuessedWord: impostorGuessedWord,
        playerResults: game.players
            .map(
              (p) => GamePlayerEntry(
                playerName: p.name,
                wasImpostor: p.role == PlayerRole.impostor,
                points: p.points,
                wasEliminated: p.isEliminated,
              ),
            )
            .toList(),
      );
    } catch (e) {
      // Silently fail - game can still be played without persistence
    }
  }

  void clearGame() {
    state = null;
  }
}

// Rankings provider
final rankingsProvider =
    FutureProvider.family<
      List<PlayerRanking>,
      ({int groupId, String? category})
    >((ref, params) async {
      final db = ref.read(databaseProvider);
      final gameDao = GameDao(db);
      if (params.category != null) {
        return gameDao.getRankingForGroupByCategory(
          params.groupId,
          params.category!,
        );
      }
      return gameDao.getRankingForGroup(params.groupId);
    });

// Game history provider
final gameHistoryProvider =
    FutureProvider.family<
      List<GameWithPlayers>,
      ({int groupId, String? category})
    >((ref, params) async {
      final db = ref.read(databaseProvider);
      final gameDao = GameDao(db);

      List<Game> games;
      if (params.category != null) {
        games = await gameDao.getGamesForGroupByCategory(
          params.groupId,
          params.category!,
        );
      } else {
        games = await gameDao.getGamesForGroup(params.groupId);
      }

      final result = <GameWithPlayers>[];
      for (final game in games) {
        final details = await gameDao.getGameDetails(game.id);
        result.add(
          GameWithPlayers(
            game: details.game,
            players: details.players
                .map(
                  (p) => GamePlayer2(
                    playerName: p.playerName,
                    wasImpostor: p.wasImpostor,
                    points: p.points,
                    wasEliminated: p.wasEliminated,
                  ),
                )
                .toList(),
          ),
        );
      }
      return result;
    });

// Category filter
final rankingCategoryFilterProvider =
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

// Helper classes for game history
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
