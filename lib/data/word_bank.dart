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
  static const int _recentWordLimit = 10;

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
  static final List<String> _recentWords = <String>[];
  static final Map<String, List<WordCategory>> _categoryBagsBySelection =
      <String, List<WordCategory>>{};

  static List<WordEntry> get allWords => List.unmodifiable(_allWords);

  static List<WordEntry> getWordsByCategory(WordCategory category) {
    final words = _wordsByCategory[category];
    if (words == null) {
      return const [];
    }

    return List.unmodifiable(words);
  }

  static WordEntry getRandomWord(WordCategory category) {
    final entry = _pickRandomWord(getWordsByCategory(category));
    _rememberWord(entry.word);
    return entry;
  }

  static WordEntry getRandomWordFromCategories(List<WordCategory> categories) {
    final validCategories = categories
        .where((category) => getWordsByCategory(category).isNotEmpty)
        .toList(growable: false);

    if (validCategories.isEmpty) {
      throw StateError('No hay palabras disponibles para las categorías seleccionadas.');
    }

    final category = _pickRandomCategoryFromBag(validCategories);
    final entry = _pickRandomWord(getWordsByCategory(category));
    _rememberWord(entry.word);
    return entry;
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

  static WordEntry _pickRandomWord(List<WordEntry> words) {
    if (words.isEmpty) {
      throw StateError('No hay palabras disponibles en esta categoría.');
    }

    final recentWordSet = _recentWords.toSet();
    final eligibleWords = words
        .where((entry) => !recentWordSet.contains(entry.word))
        .toList(growable: false);

    final pool = eligibleWords.isNotEmpty ? eligibleWords : words;
    return pool[_random.nextInt(pool.length)];
  }

  static void _rememberWord(String word) {
    _recentWords.add(word);
    if (_recentWords.length > _recentWordLimit) {
      _recentWords.removeAt(0);
    }
  }
}
