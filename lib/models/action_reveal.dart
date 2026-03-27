enum ActionRevealType {
  vote,
  guess,
}

class ActionRevealData {
  final ActionRevealType type;
  final bool success;
  final String subjectText;
  final String? actorText;
  final int? livesRemaining;

  const ActionRevealData({
    required this.type,
    required this.success,
    required this.subjectText,
    this.actorText,
    this.livesRemaining,
  });
}
