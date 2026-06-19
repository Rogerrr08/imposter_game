import 'package:flutter_test/flutter_test.dart';
import 'package:imposter_game/data/word_bank.dart';

void main() {
  test('bolsa de categorías: no repite categoría hasta agotar la bolsa', () {
    final cats = WordCategory.values.toList();
    final n = cats.length;

    // Dos ciclos completos: cada bloque de n elecciones debe contener las n
    // categorías sin repetición (la palabra dentro de cada una sigue siendo
    // soft-decay, acá solo verificamos la rotación de categorías).
    for (var cycle = 0; cycle < 2; cycle++) {
      final seen = <WordCategory>{};
      for (var i = 0; i < n; i++) {
        final r = WordBank.pickWordWithDecay(
          categories: cats,
          lastSeenAt: const {},
        );
        expect(
          seen.add(r.word.category),
          isTrue,
          reason: 'categoría repetida antes de agotar la bolsa',
        );
      }
      expect(seen.length, n, reason: 'la bolsa debe cubrir todas las categorías');
    }
  });

  test('cada palabra tiene exactamente 3 pistas de una sola palabra', () {
    for (final entry in WordBank.allWords) {
      expect(entry.hints.length, 3,
          reason: '${entry.word}: debe tener 3 pistas');
      final lower = entry.hints.map((h) => h.toLowerCase()).toList();
      for (final hint in entry.hints) {
        expect(hint.trim(), isNotEmpty, reason: '${entry.word}: pista vacía');
        expect(hint.trim().contains(' '), isFalse,
            reason: '${entry.word}: la pista "$hint" debe ser una sola palabra');
      }
      expect(lower.toSet().length, 3,
          reason: '${entry.word}: pistas duplicadas');
      expect(lower.contains(entry.word.toLowerCase()), isFalse,
          reason: '${entry.word}: una pista es la palabra misma');
    }
  });
}
