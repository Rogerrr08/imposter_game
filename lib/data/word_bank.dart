import 'dart:math';

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
    WordCategory.entretenimiento: entretenimientoWords,
    WordCategory.geografia: geografiaWords,
    WordCategory.deportes: deportesWords,
  };

  static final List<WordEntry> _allWords = _wordsByCategory.values
      .expand((words) => words)
      .toList(growable: false);

  static List<WordEntry> get allWords => List.unmodifiable(_allWords);

  static List<WordEntry> getWordsByCategory(WordCategory category) {
    final words = _wordsByCategory[category];
    if (words == null) {
      return const [];
    }

    return List.unmodifiable(words);
  }

  static WordEntry getRandomWord(WordCategory category) {
    final words = List<WordEntry>.from(getWordsByCategory(category));
    words.shuffle(_random);
    return words.first;
  }

  static List<String> getHardHints(WordEntry word, {required int count}) {
    final harderHints = word.hints.length > 1
        ? word.hints.skip(1).toList()
        : List<String>.from(word.hints);

    harderHints.shuffle(_random);

    if (harderHints.isEmpty) {
      return const [];
    }

    return List<String>.generate(
      count,
      (index) => harderHints[index % harderHints.length],
    );
  }

  static String getRandomHint(WordEntry word) {
    final hints = List<String>.from(word.hints);
    hints.shuffle(_random);
    return hints.first;
  }
}
