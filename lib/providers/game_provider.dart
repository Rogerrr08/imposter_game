import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/word_bank.dart';
import '../database/database.dart';
import '../models/game_state.dart';
import '../models/quick_game_preset.dart';
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
  final _random = Random.secure();

  @override
  ActiveGame? build() => null;

  void startNewGame(GameConfig config) {
    final wordEntry = WordBank.getRandomWordFromCategories(config.categories);

    final shuffledNames = List<String>.from(config.playerNames)
      ..shuffle(_random);
    final impostorNames = shuffledNames.take(config.impostorCount).toSet();

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
    final game = state!;
    state = _copyGame(
      game,
      phase: GamePhase.playing,
      classicVotes: const {},
      classicVotingOrder: const [],
      classicVotingIndex: 0,
      classicTieCandidates: const [],
      clearPendingClassicGuesserName: true,
      clearLastEliminatedState: true,
    );
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

    if (game.isClassicMode) {
      final updatedGame = _copyGame(
        game,
        phase: GamePhase.playing,
        clearPendingClassicGuesserName: true,
      );
      _finishClassicImpostorWin(updatedGame.players, updatedGame);
      return;
    }

    final scoredPlayers = _applyExpressImpostorSurvivalScoring(game.players);
    final updatedGame = _copyGame(game, players: scoredPlayers);
    _finishGame(
      baseGame: updatedGame,
      civilsWon: false,
      impostorGuessedWord: false,
      players: scoredPlayers,
    );
  }

  bool eliminatePlayer(String playerName, {String? votedBy}) {
    if (state == null) return false;
    final game = state!;

    if (game.isClassicMode) {
      return false;
    }

    final player = game.players.firstWhere((entry) => entry.name == playerName);
    if (player.isEliminated) {
      return player.role == PlayerRole.impostor;
    }

    final wasImpostor = player.role == PlayerRole.impostor;
    var newLives = game.livesRemaining;

    final updatedPlayers = game.players.map((p) {
      if (wasImpostor) {
        if (p.name == playerName) {
          return p.copyWith(isEliminated: true);
        }
        if (p.name == votedBy && p.role == PlayerRole.civil) {
          return p.copyWith(votedImpostorCorrectly: true);
        }
      } else {
        if (p.name == votedBy && p.role == PlayerRole.civil && !p.isEliminated) {
          return p.copyWith(isEliminated: true, votedIncorrectly: true);
        }
      }
      return p;
    }).toList();

    if (!wasImpostor) {
      newLives = max(0, newLives - 1);
    }

    final updatedGame = _copyGame(
      game,
      phase: GamePhase.playing,
      players: updatedPlayers,
      livesRemaining: newLives,
    );

    if (updatedGame.allImpostorsFound) {
      final scoredPlayers = _applyExpressCivilWinScoring(updatedPlayers);
      final scoredGame = _copyGame(
        updatedGame,
        players: scoredPlayers,
        livesRemaining: newLives,
      );
      _finishGame(
        baseGame: scoredGame,
        civilsWon: true,
        impostorGuessedWord: false,
        players: scoredPlayers,
        livesRemaining: newLives,
      );
    } else if (updatedGame.impostorsWinByNumbers || updatedGame.noLivesLeft) {
      final scoredPlayers = _applyExpressImpostorSurvivalScoring(updatedPlayers);
      final scoredGame = _copyGame(
        updatedGame,
        players: scoredPlayers,
        livesRemaining: newLives,
      );
      _finishGame(
        baseGame: scoredGame,
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

  void startVotingRound() {
    if (state == null) return;
    final game = state!;

    if (game.isClassicMode) {
      final votingOrder = game.activePlayers.map((player) => player.name).toList();
      state = _copyGame(
        game,
        phase: GamePhase.voting,
        classicVotes: const {},
        classicVotingOrder: votingOrder,
        classicVotingIndex: 0,
        classicTieCandidates: const [],
        clearPendingClassicGuesserName: true,
        clearLastEliminatedState: true,
      );
      return;
    }

    state = _copyGame(game, phase: GamePhase.voting);
  }

  bool submitClassicVote({
    required String voterName,
    required String targetName,
  }) {
    if (state == null) return false;
    final game = state!;
    if (!game.isClassicMode || game.phase != GamePhase.voting) {
      return false;
    }

    final currentVoter = game.currentClassicVoterName;
    if (currentVoter == null || currentVoter != voterName) {
      return false;
    }

    if (voterName == targetName) return false;

    final voter = _findPlayerByName(game.activePlayers, voterName);
    final target = _findPlayerByName(game.activePlayers, targetName);
    if (voter == null || target == null) return false;

    final nextVotes = Map<String, String>.from(game.classicVotes);
    nextVotes[voterName] = targetName;

    if (nextVotes.length < game.classicVotingOrder.length) {
      state = _copyGame(
        game,
        classicVotes: nextVotes,
        classicVotingIndex: game.classicVotingIndex + 1,
        clearLastEliminatedState: true,
      );
      return true;
    }

    _resolveClassicVotes(game, nextVotes);
    return true;
  }

  bool resolveClassicTie(String targetName) {
    if (state == null) return false;
    final game = state!;
    if (!game.isClassicMode || game.classicTieCandidates.isEmpty) {
      return false;
    }
    if (!game.classicTieCandidates.contains(targetName)) {
      return false;
    }

    _resolveClassicElimination(game, targetName, game.classicVotes);
    return true;
  }

  bool impostorGuess(String guess, {String? guessedBy}) {
    if (state == null) return false;
    final game = state!;

    if (game.isClassicMode) {
      final classicGuesser = game.pendingClassicGuesserName;
      if (classicGuesser == null) return false;

      if (_matchesSecretWord(guess, game.secretWord)) {
        final scoredPlayers = game.players.map((player) {
          if (player.role != PlayerRole.impostor) return player;
          if (player.name == classicGuesser) {
            return player.copyWith(points: player.points + 3);
          }
          return player.copyWith(points: player.points + 1);
        }).toList();

        final updatedGame = _copyGame(
          game,
          players: scoredPlayers,
          clearPendingClassicGuesserName: true,
        );

        _finishGame(
          baseGame: updatedGame,
          civilsWon: false,
          impostorGuessedWord: true,
          guesser: classicGuesser,
          players: scoredPlayers,
        );
        return true;
      }

      final updatedPlayers = game.players.map((player) {
        if (player.name == classicGuesser) {
          return player.copyWith(eliminatedByFailedGuess: true);
        }
        return player;
      }).toList();

      final updatedGame = _copyGame(
        game,
        players: updatedPlayers,
        clearPendingClassicGuesserName: true,
      );

      if (updatedGame.allImpostorsFound) {
        _finishClassicCivilWin(updatedPlayers, updatedGame);
      } else if (updatedGame.impostorsWinByNumbers) {
        _finishClassicImpostorWin(updatedPlayers, updatedGame);
      } else {
        state = updatedGame;
      }

      return false;
    }

    if (guessedBy == null) return false;
    final guessingImpostor = _findPlayerByName(game.activeImpostors, guessedBy);
    if (guessingImpostor == null) return false;

    if (_matchesSecretWord(guess, game.secretWord)) {
      final scoredPlayers = game.players.map((player) {
        if (player.role == PlayerRole.impostor) {
          return player.copyWith(points: player.points + (player.name == guessedBy ? 3 : 1));
        }
        return player;
      }).toList();

      final updatedGame = _copyGame(game, players: scoredPlayers);
      _finishGame(
        baseGame: updatedGame,
        civilsWon: false,
        impostorGuessedWord: true,
        guesser: guessedBy,
        players: scoredPlayers,
      );
      return true;
    }

    final updatedPlayers = game.players.map((player) {
      if (player.name == guessedBy) {
        return player.copyWith(
          isEliminated: true,
          eliminatedByFailedGuess: true,
        );
      }
      return player;
    }).toList();

    final updatedGame = _copyGame(
      game,
      phase: GamePhase.playing,
      players: updatedPlayers,
    );

    if (updatedGame.allImpostorsFound) {
      final scoredPlayers = _applyExpressCivilWinScoring(updatedPlayers);
      final scoredGame = _copyGame(updatedGame, players: scoredPlayers);
      _finishGame(
        baseGame: scoredGame,
        civilsWon: true,
        impostorGuessedWord: false,
        players: scoredPlayers,
      );
    } else if (updatedGame.impostorsWinByNumbers || updatedGame.noLivesLeft) {
      final scoredPlayers = _applyExpressImpostorSurvivalScoring(updatedPlayers);
      final scoredGame = _copyGame(updatedGame, players: scoredPlayers);
      _finishGame(
        baseGame: scoredGame,
        civilsWon: false,
        impostorGuessedWord: false,
        players: scoredPlayers,
      );
    } else {
      state = updatedGame;
    }

    return false;
  }

  void skipClassicImpostorGuess() {
    if (state == null) return;
    final game = state!;
    if (!game.isClassicMode || game.pendingClassicGuesserName == null) {
      return;
    }

    final updatedGame = _copyGame(game, clearPendingClassicGuesserName: true);

    if (updatedGame.allImpostorsFound) {
      _finishClassicCivilWin(updatedGame.players, updatedGame);
    } else if (updatedGame.impostorsWinByNumbers) {
      _finishClassicImpostorWin(updatedGame.players, updatedGame);
    } else {
      state = updatedGame;
    }
  }

  List<GamePlayer> _applyExpressCivilWinScoring(List<GamePlayer> players) {
    return players.map((player) {
      if (player.role != PlayerRole.civil) return player;
      if (player.votedIncorrectly) return player;
      if (player.votedImpostorCorrectly) {
        return player.copyWith(points: player.points + 3);
      }
      return player.copyWith(points: player.points + 1);
    }).toList();
  }

  List<GamePlayer> _applyExpressImpostorSurvivalScoring(List<GamePlayer> players) {
    return players.map((player) {
      if (player.role != PlayerRole.impostor) return player;
      if (player.eliminatedByFailedGuess) return player;
      if (player.isEliminated) {
        return player.copyWith(points: player.points + 1);
      }
      return player.copyWith(points: player.points + 5);
    }).toList();
  }

  List<GamePlayer> _applyClassicCivilEliminationScoring(
    List<GamePlayer> players,
    Map<String, String> votes,
    String eliminatedCivilName,
  ) {
    final penalizedVoters = votes.entries
        .where((entry) => entry.value == eliminatedCivilName)
        .map((entry) => entry.key)
        .toSet();

    return players.map((player) {
      if (player.role == PlayerRole.civil && penalizedVoters.contains(player.name)) {
        return player.copyWith(
          points: player.points - 1,
          votedIncorrectly: true,
        );
      }
      return player;
    }).toList();
  }

  List<GamePlayer> _applyClassicImpostorEliminationScoring(
    List<GamePlayer> players,
    Map<String, String> votes,
    String eliminatedImpostorName,
  ) {
    final rewardedVoters = votes.entries
        .where((entry) => entry.value == eliminatedImpostorName)
        .map((entry) => entry.key)
        .toSet();

    return players.map((player) {
      if (player.role == PlayerRole.civil && rewardedVoters.contains(player.name)) {
        return player.copyWith(points: player.points + 2);
      }
      return player;
    }).toList();
  }

  List<GamePlayer> _applyClassicCivilWinScoring(List<GamePlayer> players) {
    return players.map((player) {
      if (player.role != PlayerRole.civil) return player;
      if (player.votedIncorrectly) return player;
      return player.copyWith(points: player.points + 2);
    }).toList();
  }

  List<GamePlayer> _applyClassicImpostorWinScoring(List<GamePlayer> players) {
    return players.map((player) {
      if (player.role != PlayerRole.impostor) return player;
      if (player.isEliminated) {
        if (player.eliminatedByFailedGuess) {
          return player;
        }
        return player.copyWith(points: player.points + 1);
      }
      return player.copyWith(points: player.points + 5);
    }).toList();
  }

  void _resolveClassicVotes(ActiveGame game, Map<String, String> votes) {
    final counts = <String, int>{};
    for (final target in votes.values) {
      counts[target] = (counts[target] ?? 0) + 1;
    }

    if (counts.isEmpty) return;

    final maxVotes = counts.values.reduce(max);
    final tiedCandidates = counts.entries
        .where((entry) => entry.value == maxVotes)
        .map((entry) => entry.key)
        .toList();

    if (tiedCandidates.length > 1) {
      state = _copyGame(
        game,
        classicVotes: votes,
        classicTieCandidates: tiedCandidates,
        phase: GamePhase.voting,
      );
      return;
    }

    _resolveClassicElimination(game, tiedCandidates.first, votes);
  }

  void _resolveClassicElimination(
    ActiveGame game,
    String eliminatedName,
    Map<String, String> votes,
  ) {
    final eliminatedPlayer = _findPlayerByName(game.players, eliminatedName);
    if (eliminatedPlayer == null) return;

    final tallies = <String, int>{};
    for (final target in votes.values) {
      tallies[target] = (tallies[target] ?? 0) + 1;
    }

    var updatedPlayers = game.players.map((player) {
      if (player.name == eliminatedName) {
        return player.copyWith(isEliminated: true);
      }
      return player;
    }).toList();

    if (eliminatedPlayer.role == PlayerRole.impostor) {
      updatedPlayers = _applyClassicImpostorEliminationScoring(
        updatedPlayers,
        votes,
        eliminatedName,
      );

      state = _copyGame(
        game,
        players: updatedPlayers,
        phase: GamePhase.playing,
        classicVotes: const {},
        classicVotingOrder: const [],
        classicVotingIndex: 0,
        classicTieCandidates: const [],
        pendingClassicGuesserName: eliminatedName,
        lastEliminatedPlayerName: eliminatedName,
        lastEliminatedWasImpostor: true,
        lastVoteTallies: tallies,
      );
      return;
    }

    updatedPlayers = _applyClassicCivilEliminationScoring(
      updatedPlayers,
      votes,
      eliminatedName,
    );

    final updatedGame = _copyGame(
      game,
      players: updatedPlayers,
      phase: GamePhase.playing,
      classicVotes: const {},
      classicVotingOrder: const [],
      classicVotingIndex: 0,
      classicTieCandidates: const [],
      clearPendingClassicGuesserName: true,
      lastEliminatedPlayerName: eliminatedName,
      lastEliminatedWasImpostor: false,
      lastVoteTallies: tallies,
    );

    if (updatedGame.impostorsWinByNumbers) {
      _finishClassicImpostorWin(updatedPlayers, updatedGame);
      return;
    }

    state = updatedGame;
  }

  void _finishClassicCivilWin(
    List<GamePlayer> players,
    ActiveGame baseGame,
  ) {
    final scoredPlayers = _applyClassicCivilWinScoring(players);
    final scoredGame = _copyGame(baseGame, players: scoredPlayers);
    _finishGame(
      baseGame: scoredGame,
      civilsWon: true,
      impostorGuessedWord: false,
      players: scoredPlayers,
      clearPendingClassicGuesserName: true,
    );
  }

  void _finishClassicImpostorWin(
    List<GamePlayer> players,
    ActiveGame baseGame,
  ) {
    final scoredPlayers = _applyClassicImpostorWinScoring(players);
    final scoredGame = _copyGame(baseGame, players: scoredPlayers);
    _finishGame(
      baseGame: scoredGame,
      civilsWon: false,
      impostorGuessedWord: false,
      players: scoredPlayers,
      clearPendingClassicGuesserName: true,
    );
  }

  Future<void> _finishGame({
    required ActiveGame baseGame,
    required bool civilsWon,
    required bool impostorGuessedWord,
    String? guesser,
    List<GamePlayer>? players,
    int? livesRemaining,
    bool clearPendingClassicGuesserName = false,
  }) async {
    if (state == null) return;

    state = _copyGame(
      baseGame,
      phase: GamePhase.results,
      players: players,
      civilsWon: civilsWon,
      impostorGuessedWord: impostorGuessedWord,
      impostorWhoGuessed: guesser,
      livesRemaining: livesRemaining,
      classicVotes: const {},
      classicVotingOrder: const [],
      classicVotingIndex: 0,
      classicTieCandidates: const [],
      clearPendingClassicGuesserName: clearPendingClassicGuesserName,
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
        mode: game.config.mode.name,
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
      // Ignore persistence failures during gameplay.
    }
  }

  Future<void> overrideImpostorGuessedCorrectly(String impostorName) async {
    if (state == null) return;
    final game = state!;

    final oldPlayerResults = game.players
        .map(
          (player) => GamePlayerEntry(
            playerName: player.name,
            wasImpostor: player.role == PlayerRole.impostor,
            points: player.points,
            wasEliminated: player.isEliminated,
          ),
        )
        .toList();

    final scoredPlayers = game.players.map((player) {
      final base = player.copyWith(points: 0);
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
      clearPendingClassicGuesserName: true,
    );

    try {
      final db = ref.read(databaseProvider);
      final gameDao = GameDao(db);

      final newPlayerResults = scoredPlayers
          .map(
            (player) => GamePlayerEntry(
              playerName: player.name,
              wasImpostor: player.role == PlayerRole.impostor,
              points: player.points,
              wasEliminated: player.isEliminated,
            ),
          )
          .toList();

      if (game.savedGameId != null && game.config.groupId != null) {
        final newId = await gameDao.replaceGameResult(
          oldGameId: game.savedGameId!,
          groupId: game.config.groupId,
          mode: game.config.mode.name,
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
      // Ignore persistence failures.
    }
  }

  void clearGame() {
    state = null;
  }

  GamePlayer? _findPlayerByName(List<GamePlayer> players, String? name) {
    if (name == null) return null;
    for (final player in players) {
      if (player.name == name) return player;
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
    Map<String, String>? classicVotes,
    List<String>? classicVotingOrder,
    int? classicVotingIndex,
    List<String>? classicTieCandidates,
    String? pendingClassicGuesserName,
    bool clearPendingClassicGuesserName = false,
    String? lastEliminatedPlayerName,
    bool? lastEliminatedWasImpostor,
    bool clearLastEliminatedState = false,
    Map<String, int>? lastVoteTallies,
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
      timeRemainingSeconds: timeRemainingSeconds ?? game.timeRemainingSeconds,
      civilsWon: civilsWon ?? game.civilsWon,
      impostorGuessedWord: impostorGuessedWord ?? game.impostorGuessedWord,
      livesRemaining: livesRemaining ?? game.livesRemaining,
      impostorWhoGuessed: impostorWhoGuessed ?? game.impostorWhoGuessed,
      savedGameId: savedGameId ?? game.savedGameId,
      classicVotes: classicVotes ?? game.classicVotes,
      classicVotingOrder: classicVotingOrder ?? game.classicVotingOrder,
      classicVotingIndex: classicVotingIndex ?? game.classicVotingIndex,
      classicTieCandidates: classicTieCandidates ?? game.classicTieCandidates,
      pendingClassicGuesserName: clearPendingClassicGuesserName
          ? null
          : (pendingClassicGuesserName ?? game.pendingClassicGuesserName),
      lastEliminatedPlayerName: clearLastEliminatedState
          ? null
          : (lastEliminatedPlayerName ?? game.lastEliminatedPlayerName),
      lastEliminatedWasImpostor: clearLastEliminatedState
          ? null
          : (lastEliminatedWasImpostor ?? game.lastEliminatedWasImpostor),
      lastVoteTallies: lastVoteTallies ?? game.lastVoteTallies,
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

    final shuffled = List<GamePlayer>.from(players)..shuffle(_random);

    if (hintsEnabled) {
      return shuffled.first.name;
    }

    // Prefer a civil to start when hints are off
    final civil = shuffled.where((p) => p.role == PlayerRole.civil).firstOrNull;
    return (civil ?? shuffled.first).name;
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
  'Kylian Mbappe',
  'Mike Tyson',
  'Lewis Hamilton',
  'Stephen Curry',
  'Zinedine Zidane',
  'Roger Federer',
  'Muhammad Ali',
  'Erling Haaland',
};

final rankingsProvider = FutureProvider.family<
    List<PlayerRanking>,
    ({int groupId, String? category, GameMode? mode})>((ref, params) async {
  final db = ref.read(databaseProvider);
  final gameDao = GameDao(db);

  return gameDao.getRankingForGroupFiltered(
    params.groupId,
    category: params.category,
    mode: params.mode,
  );
});

final gameHistoryProvider = FutureProvider.family<
    List<GameWithPlayers>,
    ({int groupId, String? category, GameMode? mode})>((ref, params) async {
  final db = ref.read(databaseProvider);
  final gameDao = GameDao(db);

  final games = await gameDao.getGamesForGroupFiltered(
    params.groupId,
    category: params.category,
    mode: params.mode,
  );

  final detailsList = await gameDao.getGamesWithPlayers(games);

  return detailsList
      .map(
        (details) => GameWithPlayers(
          game: details.game,
          players: details.players
              .map(
                (player) => GamePlayer2(
                  playerName: player.playerName,
                  wasImpostor: player.wasImpostor,
                  points: player.points,
                  wasEliminated: player.wasEliminated,
                ),
              )
              .toList(),
        ),
      )
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

final rankingGameModeFilterProvider =
    NotifierProvider<GameModeFilterNotifier, GameMode?>(
  GameModeFilterNotifier.new,
);

final historyGameModeFilterProvider =
    NotifierProvider<GameModeFilterNotifier, GameMode?>(
  GameModeFilterNotifier.new,
);

class CategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setCategory(String? category) {
    state = category;
  }
}

class GameModeFilterNotifier extends Notifier<GameMode?> {
  @override
  GameMode? build() => null;

  void setMode(GameMode? mode) {
    state = mode;
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
