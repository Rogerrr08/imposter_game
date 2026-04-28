import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'online_rooms_provider.dart';

/// Heartbeat de conexión hacia la BD: cada 60 segundos marca al jugador
/// como conectado en `room_players`. Antes era cada 30 s, pero el presence
/// channel del lobby ya detecta desconexiones en tiempo real, así que el
/// heartbeat en BD solo sirve como fallback para reconexión tras cerrar
/// la app. 60 s reduce la carga sin afectar la UX (el grace period de
/// detección sigue por debajo del tiempo típico de un turno de juego).
final matchHeartbeatProvider =
    Provider.autoDispose.family<void, ({String roomId})>((ref, params) {
  final repository = ref.read(onlineRoomsRepositoryProvider);

  // Send initial heartbeat immediately
  repository
      .setPlayerConnected(roomId: params.roomId, connected: true)
      .catchError((_) {});

  final timer = Timer.periodic(const Duration(seconds: 60), (_) {
    repository
        .setPlayerConnected(roomId: params.roomId, connected: true)
        .catchError((_) {});
  });

  ref.onDispose(() {
    timer.cancel();
  });
});
