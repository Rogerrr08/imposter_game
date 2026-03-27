import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/word_bank.dart';
import '../database/database.dart';
import '../models/quick_game_preset.dart';
import '../models/game_state.dart';
import 'database_provider.dart';

final gameProvider = NotifierProvider<GameNotifier, ActiveGame?>(
  GameNotifier.new,
);

final lastQuickGamePresetProvider =
    NotifierProvider<QuickGamePresetNotifier, QuickGamePreset?>(
  QuickGamePresetNotifier.new,
);

class GameNotifier extends Notifier<ActiveGame?> {
  final _random = Random();

  @override
  ActiveGame? build() => null;

  void startNewGame(GameConfig config) {
    if (config.groupId == null) {
      ref.read(lastQuickGamePresetProvider.notifier).save(
            QuickGamePreset(
        playerNames: List<String>.unmodifiable(config.playerNames),
        impostorCount: config.impostorCount,
        hintsEnabled: config.hintsEnabled,
        durationSeconds: config.durationSeconds,
        category: config.category,
            ),
          );
    }

    final wordEntry = WordBank.getRandomWord(config.category);

    final players = <GamePlayer>[];
    final shuffledNames = List<String>.from(config.playerNames)..shuffle(_random);

    final impostorIndices = <int>{};
    while (impostorIndices.length < config.impostorCount) {
      impostorIndices.add(_random.nextInt(shuffledNames.length));
    }

    final availableHints = WordBank.getHardHints(
      wordEntry,
      count: config.impostorCount,
    );

    for (int i = 0; i < shuffledNames.length; i++) {
      final isImpostor = impostorIndices.contains(i);
      String? hint;

      if (isImpostor && config.hintsEnabled && availableHints.isNotEmpty) {
        hint = availableHints[
            impostorIndices.toList().indexOf(i) % availableHints.length];
      }

      players.add(
        GamePlayer(
          name: shuffledNames[i],
          role: isImpostor ? PlayerRole.impostor : PlayerRole.civil,
          hint: hint,
        ),
      );
    }

    final orderedPlayers = config.playerNames.map((name) {
      return players.firstWhere((player) => player.name == name);
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
    _applyImpostorSurvivalScoring(game);
    _finishGame(civilsWon: false, impostorGuessedWord: false);
  }

  bool eliminatePlayer(String playerName, {String? votedBy}) {
    if (state == null) return false;
    final game = state!;

    final player = game.players.firstWhere((entry) => entry.name == playerName);
    if (player.isEliminated) {
      return player.role == PlayerRole.impostor;
    }

    final voter = _findPlayerByName(game.players, votedBy);

    final wasImpostor = player.role == PlayerRole.impostor;

    if (wasImpostor) {
      player.isEliminated = true;
      if (voter != null && voter.role == PlayerRole.civil) {
        voter.votedImpostorCorrectly = true;
      }
    } else {
      game.livesRemaining = max(0, game.livesRemaining - 1);

      if (voter != null &&
          voter.role == PlayerRole.civil &&
          !voter.isEliminated) {
        voter.isEliminated = true;
      }
    }

    if (game.allImpostorsFound) {
      _applyCivilWinScoring(game);
      _finishGame(civilsWon: true, impostorGuessedWord: false);
    } else if (game.impostorsWinByNumbers || game.noLivesLeft) {
      _applyImpostorSurvivalScoring(game);
      _finishGame(civilsWon: false, impostorGuessedWord: false);
    } else {
      _rebuildState(game);
    }

    return wasImpostor;
  }

  bool impostorGuess(String guess, {String? guessedBy}) {
    if (state == null || guessedBy == null) return false;
    final game = state!;

    final guessingImpostor = _findPlayerByName(game.activeImpostors, guessedBy);
    if (guessingImpostor == null) return false;

    if (_matchesSecretWord(guess, game.secretWord)) {
      for (final player in game.impostors) {
        if (player.name == guessedBy) {
          player.points += 3;
        } else {
          player.points += 1;
        }
      }

      _finishGame(
        civilsWon: false,
        impostorGuessedWord: true,
        guesser: guessedBy,
      );
      return true;
    }

    guessingImpostor.isEliminated = true;

    if (game.allImpostorsFound) {
      _applyCivilWinScoring(game);
      _finishGame(civilsWon: true, impostorGuessedWord: false);
    } else if (game.impostorsWinByNumbers || game.noLivesLeft) {
      _applyImpostorSurvivalScoring(game);
      _finishGame(civilsWon: false, impostorGuessedWord: false);
    } else {
      _rebuildState(game);
    }

    return false;
  }

  void _applyCivilWinScoring(ActiveGame game) {
    for (final player in game.players) {
      if (player.role != PlayerRole.civil) continue;

      if (player.votedImpostorCorrectly) {
        player.points += 3;
      } else {
        player.points += 1;
      }
    }
  }

  void _applyImpostorSurvivalScoring(ActiveGame game) {
    for (final player in game.impostors) {
      if (player.isEliminated) {
        player.points += 3;
      } else {
        player.points += 5;
      }
    }
  }

  void _rebuildState(ActiveGame game) {
    state = _copyGame(game, phase: GamePhase.playing);
  }

  void _finishGame({
    required bool civilsWon,
    required bool impostorGuessedWord,
    String? guesser,
  }) {
    if (state == null) return;
    final game = state!;

    state = _copyGame(
      game,
      phase: GamePhase.results,
      civilsWon: civilsWon,
      impostorGuessedWord: impostorGuessedWord,
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
              (player) => GamePlayerEntry(
                playerName: player.name,
                wasImpostor: player.role == PlayerRole.impostor,
                points: player.points,
                wasEliminated: player.isEliminated,
              ),
            )
            .toList(),
      );
    } catch (_) {
      // Persistence should not block the game flow.
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
    GamePhase? phase,
    int? currentRevealIndex,
    int? timeRemainingSeconds,
    bool? civilsWon,
    bool? impostorGuessedWord,
    int? livesRemaining,
    String? impostorWhoGuessed,
  }) {
    return ActiveGame(
      config: game.config,
      secretWord: game.secretWord,
      wordHints: game.wordHints,
      players: game.players,
      phase: phase ?? game.phase,
      currentRevealIndex: currentRevealIndex ?? game.currentRevealIndex,
      timeRemainingSeconds:
          timeRemainingSeconds ?? game.timeRemainingSeconds,
      civilsWon: civilsWon ?? game.civilsWon,
      impostorGuessedWord:
          impostorGuessedWord ?? game.impostorGuessedWord,
      livesRemaining: livesRemaining ?? game.livesRemaining,
      impostorWhoGuessed: impostorWhoGuessed ?? game.impostorWhoGuessed,
    );
  }

  bool _matchesSecretWord(String guess, String secretWord) {
    final normalizedGuess = _normalizeAnswer(guess);
    final normalizedSecret = _normalizeAnswer(secretWord);

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
    final normalizedSecret = _normalizeAnswer(secretWord);

    for (final allowedWord in _surnameMatchAllowedWords) {
      if (_normalizeAnswer(allowedWord) == normalizedSecret) {
        return true;
      }
    }

    return false;
  }

  String _normalizeAnswer(String value) {
    final normalized = _stripDiacritics(value.toLowerCase().trim())
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final tokens = normalized
        .split(' ')
        .where((token) => token.isNotEmpty)
        .map(_singularizeToken)
        .toList();

    return tokens.join(' ');
  }

  String _singularizeToken(String token) {
    if (token.length > 4 && token.endsWith('es')) {
      return token.substring(0, token.length - 2);
    }
    if (token.length > 3 && token.endsWith('s')) {
      return token.substring(0, token.length - 1);
    }
    return token;
  }

  String _stripDiacritics(String value) {
    const replacements = <String, String>{
      '\u00E1': 'a',
      '\u00E0': 'a',
      '\u00E2': 'a',
      '\u00E4': 'a',
      '\u00E3': 'a',
      '\u00E9': 'e',
      '\u00E8': 'e',
      '\u00EA': 'e',
      '\u00EB': 'e',
      '\u00ED': 'i',
      '\u00EC': 'i',
      '\u00EE': 'i',
      '\u00EF': 'i',
      '\u00F3': 'o',
      '\u00F2': 'o',
      '\u00F4': 'o',
      '\u00F6': 'o',
      '\u00F5': 'o',
      '\u00FA': 'u',
      '\u00F9': 'u',
      '\u00FB': 'u',
      '\u00FC': 'u',
      '\u00F1': 'n',
    };

    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(replacements[char] ?? char);
    }
    return buffer.toString();
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

  final result = <GameWithPlayers>[];
  for (final game in games) {
    final details = await gameDao.getGameDetails(game.id);
    result.add(
      GameWithPlayers(
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
    );
  }
  return result;
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
