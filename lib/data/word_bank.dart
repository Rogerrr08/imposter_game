import 'dart:math';

import 'word_bank/categories/animales_words.dart';
import 'word_bank/categories/comidas_words.dart';
import 'word_bank/categories/cosas_words.dart';
import 'word_bank/categories/deportes_words.dart';
import 'word_bank/categories/entretenimiento_words.dart';
import 'word_bank/categories/geografia_words.dart';
import 'word_bank/word_bank_models.dart';

export 'word_bank/word_bank_models.dart';

final _random = Random();

class WordBank {
  static const Map<WordCategory, List<WordEntry>> _wordsByCategory = {
    WordCategory.cosas: cosasWords,
    WordCategory.comidas: comidasWords,
    WordCategory.entretenimiento: entretenimientoWords,
    WordCategory.geografia: geografiaWords,
    WordCategory.deportes: deportesWords,
    WordCategory.animales: animalesWords,
  };

  static final List<WordEntry> _allWords = _wordsByCategory.values
      .expand((words) => words)
      .toList(growable: false);
  static final Map<String, List<WordCategory>> _categoryBagsBySelection =
      <String, List<WordCategory>>{};
  static final Map<WordCategory, List<WordEntry>> _wordBagsByCategory =
      <WordCategory, List<WordEntry>>{};

  static List<WordEntry> get allWords => List.unmodifiable(_allWords);

  static List<WordEntry> getWordsByCategory(WordCategory category) {
    final words = _wordsByCategory[category];
    if (words == null) {
      return const [];
    }

    return List.unmodifiable(words);
  }

  static WordEntry getRandomWord(WordCategory category) {
    return _pickFromWordBag(category);
  }

  /// Elige una palabra aleatoria entre `categories`, evitando las que estén
  /// en `excludedWords` (típicamente las últimas N palabras jugadas por el
  /// grupo, leídas de `word_history` en BD).
  ///
  /// El shuffle-bag de sesión sigue activo como segunda capa: si la primera
  /// elección cae en una palabra excluida, se vuelve a sacar de la bolsa
  /// hasta encontrar una válida. Si la categoría se queda sin candidatos
  /// (ej. más excluidas que palabras en la bolsa actual), la bolsa se
  /// rellena y se reintenta. Como hard fallback (no debería ocurrir con
  /// 75 palabras / 25 excluidas), se acepta una palabra excluida.
  static WordEntry getRandomWordFromCategories(
    List<WordCategory> categories, {
    Set<String> excludedWords = const <String>{},
  }) {
    final validCategories = categories
        .where((category) => getWordsByCategory(category).isNotEmpty)
        .toList(growable: false);

    if (validCategories.isEmpty) {
      throw StateError(
          'No hay palabras disponibles para las categorías seleccionadas.');
    }

    final category = _pickRandomCategoryFromBag(validCategories);
    return _pickFromWordBag(category, excludedWords: excludedWords);
  }

  static List<String> getHardHints(WordEntry word, {required int count}) {
    if (word.hints.isEmpty) return const [];

    // When count fits within the total hints, use all hints so each
    // impostor gets a unique one. Only skip the easiest hint when there
    // are more hints than impostors (keeping difficulty preference).
    final pool = word.hints.length > count
        ? word.hints.skip(1).toList()
        : List<String>.from(word.hints);

    pool.shuffle(_random);

    return List<String>.generate(
      count,
      (index) => pool[index % pool.length],
    );
  }

  static String getRandomHint(WordEntry word) {
    final hints = List<String>.from(word.hints);
    hints.shuffle(_random);
    return hints.first;
  }

  static WordCategory _pickRandomCategoryFromBag(
    List<WordCategory> categories,
  ) {
    final normalizedCategories = categories.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final selectionKey =
        normalizedCategories.map((category) => category.name).join('|');

    final bag = _categoryBagsBySelection.putIfAbsent(
      selectionKey,
      () => <WordCategory>[],
    );

    if (bag.isEmpty) {
      bag.addAll(normalizedCategories);
      bag.shuffle(_random);
    }

    return bag.removeLast();
  }

  /// Shuffle-bag per category: cycles through all words before repeating.
  /// Si se proveen `excludedWords`, salta entries de la bolsa que coincidan
  /// hasta encontrar una válida o agotar la bolsa (en cuyo caso la rellena
  /// y reintenta una sola vez antes de aceptar una excluida).
  static WordEntry _pickFromWordBag(
    WordCategory category, {
    Set<String> excludedWords = const <String>{},
  }) {
    final words = getWordsByCategory(category);
    if (words.isEmpty) {
      throw StateError('No hay palabras disponibles en esta categoría.');
    }

    final bag = _wordBagsByCategory.putIfAbsent(
      category,
      () => <WordEntry>[],
    );

    WordEntry? pickFromCurrentBag() {
      while (bag.isNotEmpty) {
        final candidate = bag.removeLast();
        if (!excludedWords.contains(candidate.word)) {
          return candidate;
        }
      }
      return null;
    }

    if (bag.isEmpty) {
      bag.addAll(words);
      bag.shuffle(_random);
    }

    final firstTry = pickFromCurrentBag();
    if (firstTry != null) return firstTry;

    // Bolsa drenada por exclusiones. Refill+reshuffle e intentar de nuevo.
    bag
      ..addAll(words)
      ..shuffle(_random);

    final secondTry = pickFromCurrentBag();
    if (secondTry != null) return secondTry;

    // Hard fallback: todas las palabras de la categoría están excluidas
    // (no debería pasar con 75 - 25 = 50 candidatos). Devolver cualquier
    // palabra de la categoría para no fallar la partida.
    return words[_random.nextInt(words.length)];
  }
}
