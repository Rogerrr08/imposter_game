import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/online_match_repository.dart';
import '../data/supabase_config.dart';
import '../domain/online_match.dart';

final onlineMatchRepositoryProvider = Provider<OnlineMatchRepository>((ref) {
  return OnlineMatchRepository(SupabaseConfig.client);
});

final onlineMatchProvider =
    StreamProvider.family<OnlineMatch?, String>((ref, matchId) {
  final repository = ref.watch(onlineMatchRepositoryProvider);
  return repository.watchMatch(matchId);
});

final onlineMatchPlayersProvider =
    StreamProvider.family<List<OnlineMatchPlayer>, String>((ref, matchId) {
  final repository = ref.watch(onlineMatchRepositoryProvider);
  return repository.watchMatchPlayers(matchId);
});

final myMatchStateProvider =
    FutureProvider.autoDispose.family<MyMatchState, String>((ref, matchId) {
  final repository = ref.watch(onlineMatchRepositoryProvider);
  return repository.getMyMatchState(matchId);
});

final onlineMatchCluesProvider =
    StreamProvider.family<List<OnlineMatchClue>, String>((ref, matchId) {
  final repository = ref.watch(onlineMatchRepositoryProvider);
  return repository.watchMatchClues(matchId);
});

final onlineMatchVotesProvider =
    StreamProvider.family<List<OnlineMatchVote>, String>((ref, matchId) {
  final repository = ref.watch(onlineMatchRepositoryProvider);
  return repository.watchMatchVotes(matchId);
});
