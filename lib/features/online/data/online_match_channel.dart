import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/online_match.dart';

/// Canal Realtime unificado por match. Reemplaza los 4 streams de Postgres
/// Changes (`matches`, `match_players`, `match_clues`, `match_votes`) por una
/// única conexión WebSocket privada al canal `match:<id>` que recibe deltas
/// publicados por triggers en la base de datos.
///
/// Patrón snapshot + deltas:
///   1. `start()` llama a `get_match_snapshot` para hidratar el estado inicial.
///   2. Suscribe al canal broadcast privado.
///   3. Cada evento (`match-updated`, `player-updated`, `clue-added`,
///      `vote-added`) actualiza el estado en memoria y emite por los streams
///      correspondientes.
///   4. Si la suscripción se cierra/reabre (reconexión), se re-llama al
///      snapshot para reconciliar deltas perdidos.
class OnlineMatchChannel {
  OnlineMatchChannel(this._client, this.matchId);

  final SupabaseClient _client;
  final String matchId;

  RealtimeChannel? _channel;
  bool _started = false;
  bool _disposed = false;
  bool _resyncing = false;
  Timer? _pollTimer;

  // Estado en memoria
  OnlineMatch? _match;
  final Map<String, OnlineMatchPlayer> _players = {};
  final Map<String, OnlineMatchClue> _clues = {};
  final Map<String, OnlineMatchVote> _votes = {};

  // Streams broadcast (re-emiten el último valor a nuevos suscriptores)
  final _matchCtrl = StreamController<OnlineMatch?>.broadcast();
  final _playersCtrl = StreamController<List<OnlineMatchPlayer>>.broadcast();
  final _cluesCtrl = StreamController<List<OnlineMatchClue>>.broadcast();
  final _votesCtrl = StreamController<List<OnlineMatchVote>>.broadcast();

  /// Stream del match. Emite `null` si todavía no se ha cargado el snapshot
  /// o si el match no existe.
  Stream<OnlineMatch?> watchMatch() async* {
    yield _match;
    yield* _matchCtrl.stream;
  }

  Stream<List<OnlineMatchPlayer>> watchPlayers() async* {
    yield _sortedPlayers();
    yield* _playersCtrl.stream;
  }

  Stream<List<OnlineMatchClue>> watchClues() async* {
    yield _sortedClues();
    yield* _cluesCtrl.stream;
  }

  Stream<List<OnlineMatchVote>> watchVotes() async* {
    yield _sortedVotes();
    yield* _votesCtrl.stream;
  }

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;

    // 1. Snapshot inicial. Si falla, el canal queda sin estado pero igual
    //    suscribimos para no perder deltas (los aplicará sobre vacío).
    await _loadSnapshot();
    if (_disposed) return;

    // 2. Canal broadcast privado.
    _channel = _subscribeChannel();

    // 3. Poll de respaldo (Fase 5): si un delta se pierde con el socket "vivo"
    //    (caso raro), un re-snapshot cada 5s reconcilia el estado. Es catch-up:
    //    nunca regresa el estado (guard por state_version en _loadSnapshot). En
    //    segundo plano el navegador/OS estrangula el timer solo, y el resume del
    //    lifecycle hace su propio resync.
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_disposed) unawaited(_loadSnapshot(isPoll: true));
    });
  }

  /// Crea y suscribe una nueva instancia del canal broadcast privado.
  /// `subscribe()` solo puede llamarse una vez por instancia de canal
  /// (lanza si no), por eso para reconectar hay que crear una nueva — ver
  /// [resync].
  RealtimeChannel _subscribeChannel() {
    final channel = _client.channel(
      'match:$matchId',
      opts: const RealtimeChannelConfig(private: true),
    );

    channel
        .onBroadcast(event: 'match-updated', callback: _onMatchUpdated)
        .onBroadcast(event: 'player-updated', callback: _onPlayerUpdated)
        .onBroadcast(event: 'clue-added', callback: _onClueAdded)
        .onBroadcast(event: 'vote-added', callback: _onVoteAdded)
        .subscribe((status, error) async {
          if (_disposed) return;

          // En reconnects (closed → subscribed) recargamos el snapshot para
          // recuperar los eventos perdidos durante la desconexión.
          if (status == RealtimeSubscribeStatus.subscribed) {
            await _loadSnapshot();
          }
        });

    return channel;
  }

  /// Reconciliación forzada tras un posible corte silencioso del socket
  /// (caso típico: la app vuelve de segundo plano y el WebSocket murió sin
  /// que el cliente lo detecte, porque los timers de heartbeat estuvieron
  /// congelados). Hace dos cosas:
  ///   1. Recarga el snapshot por HTTPS → catch-up inmediato del estado,
  ///      sin esperar a que el socket se reconecte.
  ///   2. Recrea el canal subyacente para forzar una reconexión limpia del
  ///      WebSocket (`subscribe()` solo se puede invocar una vez por
  ///      instancia, así que se descarta la vieja y se crea una nueva).
  ///
  /// Pensado para llamarse desde el lifecycle `resumed`. Idempotente: si ya
  /// hay un resync en curso, no encola otro.
  Future<void> resync() async {
    if (_disposed || !_started || _resyncing) return;
    _resyncing = true;
    try {
      // 1. Catch-up inmediato del estado.
      await _loadSnapshot();
      if (_disposed) return;

      // 2. Recrear el canal para reconectar el socket si murió en silencio.
      final old = _channel;
      _channel = null;
      if (old != null) {
        try {
          await _client.removeChannel(old);
        } catch (_) {}
      }
      if (_disposed) return;
      _channel = _subscribeChannel();
    } finally {
      _resyncing = false;
    }
  }

  Future<void> _loadSnapshot({bool isPoll = false}) async {
    try {
      final result = await _client.rpc(
        'get_match_snapshot',
        params: {'input_match_id': matchId},
      );
      if (_disposed) return;
      final data = result as Map<String, dynamic>;

      final matchMap = data['match'] as Map<String, dynamic>?;
      final nextMatch = matchMap != null
          ? OnlineMatch.fromMap(matchMap)
          : null;
      // Poll de respaldo: catch-up only. Si los deltas ya van más adelante
      // (state_version mayor), no regresamos el estado para evitar parpadeos.
      final current = _match;
      if (isPoll &&
          nextMatch != null &&
          current != null &&
          nextMatch.stateVersion < current.stateVersion) {
        return;
      }
      _match = nextMatch;

      _players
        ..clear()
        ..addEntries(
          (data['players'] as List<dynamic>? ?? const []).map((raw) {
            final p = OnlineMatchPlayer.fromMap(raw as Map<String, dynamic>);
            return MapEntry(p.id, p);
          }),
        );

      _clues
        ..clear()
        ..addEntries(
          (data['clues'] as List<dynamic>? ?? const []).map((raw) {
            final c = OnlineMatchClue.fromMap(raw as Map<String, dynamic>);
            return MapEntry(c.id, c);
          }),
        );

      _votes
        ..clear()
        ..addEntries(
          (data['votes'] as List<dynamic>? ?? const []).map((raw) {
            final v = OnlineMatchVote.fromMap(raw as Map<String, dynamic>);
            return MapEntry(v.id, v);
          }),
        );

      _emitMatch();
      _emitPlayers();
      _emitClues();
      _emitVotes();
    } catch (_) {
      // Best-effort. Si falla el snapshot (ej. RLS, red), los listeners
      // verán los valores actuales (posiblemente vacíos) y los siguientes
      // broadcasts irán cubriendo el gap.
    }
  }

  void _onMatchUpdated(Map<String, dynamic> payload) {
    final data = _extractPayload(payload);
    if (data == null) return;
    final next = OnlineMatch.fromMap(data);
    // Anti-stale: si llega un delta con state_version anterior al actual
    // (p. ej. fuera de orden), lo ignoramos.
    final current = _match;
    if (current != null && next.stateVersion < current.stateVersion) return;
    _match = next;
    _emitMatch();
  }

  void _onPlayerUpdated(Map<String, dynamic> payload) {
    final data = _extractPayload(payload);
    if (data == null) return;
    final p = OnlineMatchPlayer.fromMap(data);
    _players[p.id] = p;
    _emitPlayers();
  }

  void _onClueAdded(Map<String, dynamic> payload) {
    final data = _extractPayload(payload);
    if (data == null) return;
    final c = OnlineMatchClue.fromMap(data);
    _clues[c.id] = c;
    _emitClues();
  }

  void _onVoteAdded(Map<String, dynamic> payload) {
    final data = _extractPayload(payload);
    if (data == null) return;
    final v = OnlineMatchVote.fromMap(data);
    _votes[v.id] = v;
    _emitVotes();
  }

  /// Los broadcasts de Supabase Realtime envuelven el payload del trigger
  /// como `{event, type, payload: {...}}`. Esta utilidad extrae el inner.
  Map<String, dynamic>? _extractPayload(Map<String, dynamic> envelope) {
    final inner = envelope['payload'];
    if (inner is Map<String, dynamic>) return inner;
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return null;
  }

  List<OnlineMatchPlayer> _sortedPlayers() =>
      _players.values.toList()
        ..sort((a, b) => a.seatOrder.compareTo(b.seatOrder));

  List<OnlineMatchClue> _sortedClues() =>
      _clues.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<OnlineMatchVote> _sortedVotes() =>
      _votes.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  void _emitMatch() {
    if (_disposed || _matchCtrl.isClosed) return;
    _matchCtrl.add(_match);
  }

  void _emitPlayers() {
    if (_disposed || _playersCtrl.isClosed) return;
    _playersCtrl.add(_sortedPlayers());
  }

  void _emitClues() {
    if (_disposed || _cluesCtrl.isClosed) return;
    _cluesCtrl.add(_sortedClues());
  }

  void _emitVotes() {
    if (_disposed || _votesCtrl.isClosed) return;
    _votesCtrl.add(_sortedVotes());
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _pollTimer?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await _client.removeChannel(channel);
      } catch (_) {}
    }

    await _matchCtrl.close();
    await _playersCtrl.close();
    await _cluesCtrl.close();
    await _votesCtrl.close();
  }
}
