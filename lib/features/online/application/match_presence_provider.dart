import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_config.dart';

/// Presencia en vivo de la partida (Fase 3). Cada cliente se "trackea" en un
/// canal de presence dedicado `match-presence:<id>`; cuando a alguien se le cae
/// el socket, Supabase emite `leave` a los demás en segundos (~12s), sin
/// depender del heartbeat + cron de la BD (que tarda ~90-150s).
///
/// Emite el set de `user_id` presentes ahora. La UI lo usa para el indicador de
/// conectado/desconectado en vivo. La BD (`is_connected`) + cron siguen siendo
/// el respaldo autoritativo para la limpieza/cancelación.
final matchPresenceProvider =
    StreamProvider.autoDispose.family<Set<String>, String>((ref, matchId) {
  final controller = StreamController<Set<String>>.broadcast();
  final userId = SupabaseConfig.client.auth.currentUser?.id;

  if (userId == null) {
    controller.add(const <String>{});
    ref.onDispose(controller.close);
    return controller.stream;
  }

  final client = SupabaseConfig.client;
  final channel = client.channel(
    'match-presence:$matchId',
    opts: RealtimeChannelConfig(key: userId),
  );

  void emit() {
    if (controller.isClosed) return;
    // La key de cada presence es el userId (RealtimeChannelConfig.key).
    controller.add(channel.presenceState().map((s) => s.key).toSet());
  }

  channel
      .onPresenceSync((_) => emit())
      .onPresenceJoin((_) => emit())
      .onPresenceLeave((_) => emit())
      .subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await channel.track({'user_id': userId});
          emit();
        }
      });

  ref.onDispose(() async {
    try {
      await channel.untrack();
    } catch (_) {}
    try {
      await client.removeChannel(channel);
    } catch (_) {}
    await controller.close();
  });

  return controller.stream;
});
