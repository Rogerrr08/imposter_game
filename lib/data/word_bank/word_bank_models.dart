enum WordCategory {
  cosas,
  comidas,
  entretenimiento,
  geografia,
  deportes,
  animales;

  String get displayName {
    switch (this) {
      case WordCategory.cosas:
        return 'Cosas';
      case WordCategory.comidas:
        return 'Comidas';
      case WordCategory.entretenimiento:
        return 'Entretenimiento';
      case WordCategory.geografia:
        return 'Geografía';
      case WordCategory.deportes:
        return 'Deportes';
      case WordCategory.animales:
        return 'Animales';
    }
  }

  String get icon {
    switch (this) {
      case WordCategory.cosas:
        return '\u{1F4E6}';
      case WordCategory.comidas:
        return '\u{1F37D}\uFE0F';
      case WordCategory.entretenimiento:
        return '\u{1F3AC}';
      case WordCategory.geografia:
        return '\u{1F30D}';
      case WordCategory.deportes:
        return '\u{26BD}';
      case WordCategory.animales:
        return '\u{1F43E}';
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
