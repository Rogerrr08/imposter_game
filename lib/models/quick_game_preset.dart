import '../data/word_bank.dart';

class QuickGamePreset {
  final List<String> playerNames;
  final int impostorCount;
  final bool hintsEnabled;
  final int durationSeconds;
  final WordCategory category;

  const QuickGamePreset({
    required this.playerNames,
    required this.impostorCount,
    required this.hintsEnabled,
    required this.durationSeconds,
    required this.category,
  });
}
