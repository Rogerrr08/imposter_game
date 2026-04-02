/// Cuenta votos por objetivo. Retorna un mapa {nombreJugador: cantidadDeVotos}.
Map<String, int> countVotes(Map<String, String> votes) {
  final counts = <String, int>{};
  for (final target in votes.values) {
    counts[target] = (counts[target] ?? 0) + 1;
  }
  return counts;
}

/// Resultado de una ronda de votación.
class VoteResult {
  /// Jugadores empatados con la mayor cantidad de votos (más de 1 = empate).
  final List<String> topCandidates;

  /// Conteo de votos por jugador.
  final Map<String, int> tallies;

  const VoteResult({required this.topCandidates, required this.tallies});

  bool get isTie => topCandidates.length > 1;

  /// Nombre del eliminado (solo válido si no hay empate).
  String? get eliminatedName => isTie ? null : topCandidates.firstOrNull;
}

/// Resuelve una ronda de votación: cuenta votos, detecta empates,
/// y retorna los candidatos con mayor cantidad de votos.
VoteResult resolveVotes(Map<String, String> votes) {
  final tallies = countVotes(votes);

  if (tallies.isEmpty) {
    return const VoteResult(topCandidates: [], tallies: {});
  }

  final maxVotes = tallies.values.reduce((a, b) => a > b ? a : b);
  final topCandidates = tallies.entries
      .where((entry) => entry.value == maxVotes)
      .map((entry) => entry.key)
      .toList();

  return VoteResult(topCandidates: topCandidates, tallies: tallies);
}
