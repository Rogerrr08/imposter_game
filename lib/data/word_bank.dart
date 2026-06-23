import 'dart:math' as math;

import 'word_bank/categories/animales_words.dart';
import 'word_bank/categories/comidas_words.dart';
import 'word_bank/categories/cosas_words.dart';
import 'word_bank/categories/deportes_words.dart';
import 'word_bank/categories/entretenimiento_words.dart';
import 'word_bank/categories/geografia_words.dart';
import 'word_bank/word_bank_models.dart';

export 'word_bank/word_bank_models.dart';

final _random = math.Random();

/// Resultado de una elección con scoring. Útil para logging/diagnóstico.
class WordPickResult {
  final WordEntry word;
  /// Score del candidato ganador (0.0 = visto hace un instante, 1.0 = nunca
  /// visto / hace mucho tiempo).
  final double freshnessScore;
  /// Cantidad de candidatos generados (excluido el hard floor).
  final int candidatesGenerated;
  /// Cantidad de palabras en hard exclusion en esta elección.
  final int hardExcludedCount;
  /// Tamaño del pool elegible de la categoría elegida (≤75, menos hard excluded).
  final int eligiblePoolSize;

  const WordPickResult({
    required this.word,
    required this.freshnessScore,
    required this.candidatesGenerated,
    required this.hardExcludedCount,
    required this.eligiblePoolSize,
  });
}

class WordBank {
  // ─── Parámetros del algoritmo (Spotify-style soft decay) ───
  /// Cuántas palabras más recientes están **prohibidas** (hard floor). Las
  /// que están en este window NUNCA salen. Pequeño y simple — la garantía
  /// fuerte contra repetición inmediata.
  static const int _hardExclusionWindow = 10;

  /// Cuántos candidatos generamos en cada pick. Cada uno se puntúa con la
  /// función de freshness y se elige el de mejor score. Mayor K = más sesgo
  /// hacia palabras "viejas/no vistas"; menor K = más random puro.
  static const int _candidatePoolSize = 8;

  /// Constante de decay τ del scoring. Una palabra vista hace `τ` se ve
  /// con score ~0.63 (1 - 1/e). 48 h significa: hace 2 días → 0.63,
  /// hace 4 días → 0.86, hace 1 semana → 0.96, nunca vista → 1.0.
  static const Duration _decayTau = Duration(hours: 48);

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

  /// Bolsa de categorías (shuffle-bag), una por cada conjunto de categorías
  /// seleccionadas. Garantiza que no se repita una categoría hasta que todas
  /// las del conjunto hayan salido. En memoria: se reinicia al cerrar la app.
  static final Map<String, List<WordCategory>> _categoryBags = {};

  static List<WordEntry> get allWords => List.unmodifiable(_allWords);

  static List<WordEntry> getWordsByCategory(WordCategory category) {
    final words = _wordsByCategory[category];
    if (words == null) {
      return const [];
    }

    return List.unmodifiable(words);
  }

  static WordEntry getRandomWord(WordCategory category) {
    final words = getWordsByCategory(category);
    if (words.isEmpty) {
      throw StateError('No hay palabras disponibles en esta categoría.');
    }
    return words[_random.nextInt(words.length)];
  }

  /// Shuffle-bag de categorías: devuelve una categoría que no se repite hasta
  /// que todas las del conjunto seleccionado hayan salido. Al vaciarse la
  /// bolsa, se rellena con todas y se baraja de nuevo. La clave por conjunto
  /// de categorías hace que distintas selecciones tengan bolsas independientes.
  static WordCategory _pickCategoryFromBag(List<WordCategory> categories) {
    final normalized = categories.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final key = normalized.map((c) => c.name).join('|');
    final bag = _categoryBags.putIfAbsent(key, () => <WordCategory>[]);
    if (bag.isEmpty) {
      bag
        ..addAll(normalized)
        ..shuffle(_random);
    }
    return bag.removeLast();
  }

  /// Selección en dos pasos:
  ///   A. **Bolsa de categorías**: elige una categoría que no se repite hasta
  ///      que todas las seleccionadas hayan salido ([_pickCategoryFromBag]).
  ///   B. **Soft scoring por decay** de la PALABRA dentro de esa categoría
  ///      (patrón Spotify "Fewer Repeats", sin cambios respecto a antes):
  ///        1. Hard floor: las últimas [_hardExclusionWindow] palabras (por
  ///           `lastSeenAt`) quedan FUERA.
  ///        2. Genera [_candidatePoolSize] candidatos aleatorios del pool
  ///           elegible de la categoría.
  ///        3. Cada candidato recibe score `1 - exp(-Δt/τ)`; gana el mayor.
  ///           Nunca vista → 1.0; vista hace mucho → ~1; reciente → ~0.
  ///
  /// Si el pool elegible queda vacío (cooldown ≥ tamaño de categoría, no
  /// debería pasar con 75 palabras), cae a uniforme sobre la categoría.
  static WordPickResult pickWordWithDecay({
    required List<WordCategory> categories,
    required Map<String, DateTime> lastSeenAt,
    DateTime? now,
  }) {
    final validCategories = categories
        .where((category) => getWordsByCategory(category).isNotEmpty)
        .toList(growable: false);

    if (validCategories.isEmpty) {
      throw StateError(
          'No hay palabras disponibles para las categorías seleccionadas.');
    }

    // Paso A: categoría desde la bolsa (no repite hasta agotar todas).
    final category = _pickCategoryFromBag(validCategories);
    final pool = getWordsByCategory(category);

    // Paso B: soft-decay de la palabra dentro de la categoría elegida.
    // Hard floor: top _hardExclusionWindow más recientes
    final hardExcluded = _topRecent(
      lastSeenAt,
      n: _hardExclusionWindow,
    );
    final eligible = pool
        .where((entry) => !hardExcluded.contains(entry.word))
        .toList(growable: false);

    final referenceNow = now ?? DateTime.now();
    final workingPool = eligible.isEmpty ? pool : eligible;

    // Soft scoring: K candidatos aleatorios, eligo el mejor.
    WordEntry? best;
    double bestScore = -double.infinity;
    final seen = <String>{};
    for (int i = 0; i < _candidatePoolSize; i++) {
      final candidate = workingPool[_random.nextInt(workingPool.length)];
      // Evita reevaluar la misma palabra dentro del batch.
      if (!seen.add(candidate.word)) continue;
      final score = _freshnessScore(candidate.word, lastSeenAt, referenceNow);
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    return WordPickResult(
      word: best!,
      freshnessScore: bestScore,
      candidatesGenerated: seen.length,
      hardExcludedCount: hardExcluded.length,
      eligiblePoolSize: workingPool.length,
    );
  }

  /// Reparte las pistas a los impostores: baraja las 3 (todas calibradas a la
  /// misma dificultad, sin reservar una "fácil") y entrega una por impostor,
  /// distintas entre sí mientras alcancen. Usada por el modo local y el online.
  static List<String> getImpostorHints(WordEntry word, {required int count}) {
    if (word.hints.isEmpty) return const [];

    // Cualquier pista es elegible; se baraja y se reparte una por impostor.
    final pool = List<String>.from(word.hints)..shuffle(_random);

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

  /// Devuelve las `n` palabras más recientes según `lastSeenAt`. Si hay
  /// menos de `n` entradas, devuelve todas. O(N log N) por el sort — N
  /// aquí es como máximo `_wordHistoryWindow × categorías` ≈ 210, trivial.
  static Set<String> _topRecent(Map<String, DateTime> lastSeenAt, {required int n}) {
    if (lastSeenAt.length <= n) return lastSeenAt.keys.toSet();
    final entries = lastSeenAt.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(n).map((entry) => entry.key).toSet();
  }

  /// `1 - exp(-Δt / τ)`. Para Δt = 0 → 0.0 (recién vista). Para Δt = ∞ → 1.0.
  /// Para Δt = τ → ~0.63. Palabras nunca vistas → 1.0 (fresco máximo).
  static double _freshnessScore(
    String word,
    Map<String, DateTime> lastSeenAt,
    DateTime now,
  ) {
    final lastSeen = lastSeenAt[word];
    if (lastSeen == null) return 1.0;
    final dtMinutes = now.difference(lastSeen).inMinutes.toDouble();
    final tauMinutes = _decayTau.inMinutes.toDouble();
    if (tauMinutes <= 0) return 1.0;
    return 1.0 - math.exp(-dtMinutes / tauMinutes);
  }
}

