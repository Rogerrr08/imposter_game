enum ActionRevealType {
  vote,
  guess,
  guessSkipped,
}

class ActionRevealData {
  final ActionRevealType type;
  final bool success;
  final String subjectText;
  final String? actorText;
  final int? livesRemaining;
  final Map<String, int> voteTallies;

  const ActionRevealData({
    required this.type,
    required this.success,
    required this.subjectText,
    this.actorText,
    this.livesRemaining,
    this.voteTallies = const {},
  });
}
