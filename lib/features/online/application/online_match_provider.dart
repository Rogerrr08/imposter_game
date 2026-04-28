import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/online_match_channel.dart';
import '../data/online_match_repository.dart';
import '../data/supabase_config.dart';
import '../domain/online_match.dart';

final onlineMatchRepositoryProvider = Provider<OnlineMatchRepository>((ref) {
  return OnlineMatchRepository(SupabaseConfig.client);
});

/// Canal unificado por match. Una sola conexión WebSocket privada al topic
/// `match:<id>` reemplaza los 4 `stream()` previos sobre tablas. El canal
/// arranca en background; los `StreamProvider`s lo consumen sin esperar al
/// snapshot inicial (los streams emiten valores tan pronto como llegan).
final onlineMatchChannelProvider =
    Provider.autoDispose.family<OnlineMatchChannel, String>((ref, matchId) {
  final channel = OnlineMatchChannel(SupabaseConfig.client, matchId);
  // Fire-and-forget: el canal hace su snapshot + subscribe en paralelo.
  unawaited(channel.start());
  ref.onDispose(() {
    unawaited(channel.dispose());
  });
  return channel;
});

final onlineMatchProvider =
    StreamProvider.family<OnlineMatch?, String>((ref, matchId) {
  final channel = ref.watch(onlineMatchChannelProvider(matchId));
  return channel.watchMatch();
});

final onlineMatchPlayersProvider =
    StreamProvider.family<List<OnlineMatchPlayer>, String>((ref, matchId) {
  final channel = ref.watch(onlineMatchChannelProvider(matchId));
  return channel.watchPlayers();
});

final onlineMatchCluesProvider =
    StreamProvider.family<List<OnlineMatchClue>, String>((ref, matchId) {
  final channel = ref.watch(onlineMatchChannelProvider(matchId));
  return channel.watchClues();
});

final onlineMatchVotesProvider =
    StreamProvider.family<List<OnlineMatchVote>, String>((ref, matchId) {
  final channel = ref.watch(onlineMatchChannelProvider(matchId));
  return channel.watchVotes();
});

final myMatchStateProvider =
    FutureProvider.autoDispose.family<MyMatchState, String>((ref, matchId) {
  final repository = ref.watch(onlineMatchRepositoryProvider);
  return repository.getMyMatchState(matchId);
});
