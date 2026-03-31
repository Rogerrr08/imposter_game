import '../data/word_bank.dart';

class QuickGamePreset {
  final List<String> playerNames;
  final int impostorCount;
  final bool hintsEnabled;
  final int durationSeconds;
  final List<WordCategory> categories;

  /// For group mode: IDs of players excluded from the game.
  final Set<int> excludedGroupPlayerIds;

  /// For group mode: ordered list of group player IDs.
  final List<int> groupPlayerOrder;

  const QuickGamePreset({
    required this.playerNames,
    required this.impostorCount,
    required this.hintsEnabled,
    required this.durationSeconds,
    required this.categories,
    this.excludedGroupPlayerIds = const {},
    this.groupPlayerOrder = const [],
  });
}
