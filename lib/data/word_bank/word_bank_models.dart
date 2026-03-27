enum WordCategory {
  cosas,
  entretenimiento,
  geografia,
  deportes;

  String get displayName {
    switch (this) {
      case WordCategory.cosas:
        return 'Cosas';
      case WordCategory.entretenimiento:
        return 'Entretenimiento';
      case WordCategory.geografia:
        return 'Geografía';
      case WordCategory.deportes:
        return 'Deportes';
    }
  }

  String get icon {
    switch (this) {
      case WordCategory.cosas:
        return '📦';
      case WordCategory.entretenimiento:
        return '🎬';
      case WordCategory.geografia:
        return '🌍';
      case WordCategory.deportes:
        return '⚽';
    }
  }
}

class WordEntry {
  final String word;
  final List<String> hints;
  final WordCategory category;

  const WordEntry({
    required this.word,
    required this.hints,
    required this.category,
  });
}
