import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_theme.dart';
import '../../application/match_presence_provider.dart';
import '../../application/online_match_provider.dart';
import '../../domain/online_match.dart';
import 'player_avatar.dart';

class ClueWritingPhase extends ConsumerStatefulWidget {
  final String matchId;
  final MyMatchState myState;
  final bool isSpectator;
  final int? countdownSeconds; // Pre-vote countdown (null = normal mode)

  const ClueWritingPhase({
    super.key,
    required this.matchId,
    required this.myState,
    this.isSpectator = false,
    this.countdownSeconds,
  });

  @override
  ConsumerState<ClueWritingPhase> createState() => _ClueWritingPhaseState();
}

class _ClueWritingPhaseState extends ConsumerState<ClueWritingPhase> {
  final _clueController = TextEditingController();
  final _focusNode = FocusNode();
  bool _submitting = false;
  bool _myClueWritten = false;
  bool _autoSkipping = false;
  int? _autoSkippedTurnIndex; // Track which turn we already skipped
  int? _timedOutForTurn; // Solo disparamos el timeout una vez por turno
  Timer? _turnTimer; // Ticker de 1s: solo refresca el número en pantalla
  int _secondsLeft = 30;
  Set<String> _present = const {}; // user_ids presentes (presence en vivo)

  @override
  void initState() {
    super.initState();
    if (widget.countdownSeconds == null) {
      _startTurnTimer();
    }
  }

  @override
  void didUpdateWidget(ClueWritingPhase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.myState.currentTurnIndex !=
        widget.myState.currentTurnIndex) {
      // El nuevo turno trae su propio turn_ends_at; solo limpiamos input/flags.
      _clueController.clear();
      _autoSkipping = false;
      _autoSkippedTurnIndex = null;
    }
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    _clueController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Ticker de 1s: solo fuerza un rebuild para refrescar el número. Los segundos
  // restantes se calculan en build desde `turn_ends_at` (servidor) + el offset
  // de reloj, así todos los clientes ven el mismo número y un reconectado ve el
  // tiempo correcto. El timeout se dispara desde build (una vez por turno).
  void _startTurnTimer() {
    _turnTimer?.cancel();
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {});
    });
  }

  bool get _isMyTurn =>
      !widget.isSpectator &&
      widget.myState.mySeatOrder == widget.myState.currentTurnIndex;

  // Conexión en vivo desde presence (Fase 3); cae al flag de BD si presence aún
  // no cargó (set vacío). Si está activa, siempre me incluye al menos a mí.
  bool _connected(OnlineMatchPlayer p) =>
      _present.isNotEmpty ? _present.contains(p.userId) : p.isConnected;

  Future<void> _handleSubmitClue() async {
    final clue = _clueController.text.trim();
    if (clue.isEmpty || _submitting || _myClueWritten) return;

    setState(() => _submitting = true);
    try {
      await ref.read(onlineMatchRepositoryProvider).submitClue(
            matchId: widget.matchId,
            clue: clue,
          );
      if (mounted) {
        _clueController.clear();
        setState(() => _myClueWritten = true);
        // El cambio de fase (a 'voting') llega por el stream del match; ya no
        // hace falta invalidar el RPC (Fase 1: fuente única de verdad).
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleTimeout() async {
    if (widget.isSpectator) return;
    final turnIndex = widget.myState.currentTurnIndex;
    if (!_isMyTurn) {
      // Cualquier jugador puede disparar el skip al vencer el deadline; el
      // compare-and-swap del servidor (expected_turn_index) evita el over-skip.
      try {
        await ref
            .read(onlineMatchRepositoryProvider)
            .skipClueTurn(widget.matchId, expectedTurnIndex: turnIndex);
      } catch (_) {}
      return;
    }

    // It's our turn and we timed out — try to submit if we typed something
    final clue = _clueController.text.trim();
    if (clue.isNotEmpty) {
      await _handleSubmitClue();
    } else {
      // Skip our own turn
      try {
        await ref
            .read(onlineMatchRepositoryProvider)
            .skipClueTurn(widget.matchId, expectedTurnIndex: turnIndex);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(onlineMatchProvider(widget.matchId));
    final playersAsync = ref.watch(onlineMatchPlayersProvider(widget.matchId));
    final cluesAsync = ref.watch(onlineMatchCluesProvider(widget.matchId));
    _present =
        ref.watch(matchPresenceProvider(widget.matchId)).value ?? const {};

    final match = matchAsync.value;
    final players = playersAsync.value ?? [];
    final clues = cluesAsync.value ?? [];

    final activePlayers =
        players.where((p) => !p.isEliminated).toList();
    final currentTurnPlayer = activePlayers
        .where((p) => p.seatOrder == (match?.currentTurnIndex ?? 0))
        .firstOrNull;
    final turnIndex = match?.currentTurnIndex ?? 0;

    // Segundos restantes desde el deadline del servidor (turn_ends_at), con
    // corrección del offset de reloj → countdown sincronizado entre clientes.
    // Si todavía no hay deadline (SQL sin aplicar), mostramos 30 sin timeout.
    final offset =
        ref.watch(serverClockOffsetProvider).value ?? Duration.zero;
    final turnEndsAt = match?.turnEndsAt;
    final hasDeadline = turnEndsAt != null && widget.countdownSeconds == null;
    if (hasDeadline) {
      final remaining = turnEndsAt.difference(
        DateTime.now().toUtc().add(offset),
      );
      _secondsLeft = (remaining.inMilliseconds / 1000).round().clamp(0, 30);
    }

    // Disparar el timeout una sola vez por turno cuando el deadline venció.
    if (hasDeadline &&
        _secondsLeft <= 0 &&
        _timedOutForTurn != turnIndex &&
        !widget.isSpectator) {
      _timedOutForTurn = turnIndex;
      Future.microtask(_handleTimeout);
    }

    // Auto-skip when the current turn player was eliminated (abandoned).
    // Guard: only skip once per turn index to prevent loops caused by
    // Realtime lag (the RPC completes but the stream hasn't updated yet).
    final turnPlayerEliminated = currentTurnPlayer == null &&
        players.any((p) => p.seatOrder == turnIndex && p.isEliminated);

    if (turnPlayerEliminated &&
        !_autoSkipping &&
        _autoSkippedTurnIndex != turnIndex &&
        !widget.isSpectator &&
        widget.countdownSeconds == null) {
      _autoSkipping = true;
      _autoSkippedTurnIndex = turnIndex;
      Future.microtask(() async {
        try {
          await ref
              .read(onlineMatchRepositoryProvider)
              .skipClueTurn(widget.matchId, expectedTurnIndex: turnIndex);
        } catch (_) {}
        if (mounted) _autoSkipping = false;
      });
    }

    // Antes había un Future.microtask(invalidate(...)) cuando se detectaba
    // que todas las pistas estaban en. Se eliminó porque (a) corría en cada
    // rebuild mientras la condición se mantenía, (b) cerraba/reabría los
    // streams añadiendo latencia y dejando "0/0" momentáneo, y (c) el
    // servidor ya avanza la fase y el Realtime propaga el cambio.
    // Ver docs/online-realtime-refactor-plan.md §0.2.

    final isImpostor = widget.myState.isImpostor;
    final accentColor =
        isImpostor ? AppTheme.secondaryColor : AppTheme.primaryColor;

    return SafeArea(
      child: Column(
        children: [
          // ─── Turn indicator + timer ───
          if (widget.countdownSeconds == null)
            _buildTurnHeader(currentTurnPlayer, accentColor),

          // ─── Role context reminder ───
          if (widget.countdownSeconds == null)
            _buildRoleReminder(accentColor),

          // ─── Clue list ───
          Expanded(
            child: _buildClueList(clues, players),
          ),

          // ─── Input, waiting, or pre-vote countdown ───
          if (widget.countdownSeconds != null)
            _buildPreVoteCountdown(widget.countdownSeconds!)
          else if (_isMyTurn && !_myClueWritten)
            _buildClueInput(accentColor)
          else
            _buildWaiting(currentTurnPlayer),
        ],
      ),
    );
  }

  Widget _buildTurnHeader(
      OnlineMatchPlayer? currentPlayer, Color accentColor) {
    final timerColor = _secondsLeft <= 10
        ? AppTheme.errorColor
        : _secondsLeft <= 15
            ? AppTheme.warningColor
            : AppTheme.textSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: AppTheme.surfaceColor,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (currentPlayer != null &&
                    !_connected(currentPlayer) &&
                    !_isMyTurn) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    _isMyTurn
                        ? 'Tu turno — escribe una pista'
                        : 'Turno de ${currentPlayer?.displayName ?? '...'}${currentPlayer != null && !_connected(currentPlayer) ? ' (desconectado)' : ''}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _isMyTurn ? accentColor : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: timerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 16, color: timerColor),
                const SizedBox(width: 4),
                Text(
                  '${_secondsLeft}s',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: timerColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleReminder(Color accentColor) {
    final isImpostor = widget.myState.isImpostor;
    // Spectators (eliminated or late joiners) always see the word
    final isActualSpectator =
        widget.myState.myIsEliminated || widget.myState.isSpectator;
    final showWord = isActualSpectator || !isImpostor;
    final text = showWord
        ? 'Palabra: ${widget.myState.word ?? '???'}'
        : 'Pista: ${widget.myState.myHint ?? 'Sin pista'}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: accentColor.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(
            isImpostor
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            size: 16,
            color: accentColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
          if (!isImpostor)
            _buildBadge(
              _capitalize(widget.myState.category),
              AppTheme.textSecondary,
            ),
        ],
      ),
    );
  }

  Widget _buildClueList(
      List<OnlineMatchClue> allClues, List<OnlineMatchPlayer> players) {
    // Show newest clue first
    final clues = allClues.reversed.toList();
    if (clues.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit_note_rounded,
              size: 48,
              color: AppTheme.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Aún no hay pistas',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: clues.length,
      itemBuilder: (context, index) {
        final clue = clues[index];
        final player =
            players.where((p) => p.id == clue.playerId).firstOrNull;
        return _ClueCard(
          playerName: player?.displayName ?? 'Jugador',
          avatarUrl: player?.avatarUrl,
          clue: clue.clue,
          seatOrder: clue.turnOrder,
          isConnected: player != null ? _connected(player) : true,
          role: (widget.myState.myIsEliminated || widget.myState.isSpectator)
              ? player?.role
              : null,
        );
      },
    );
  }

  Widget _buildClueInput(Color accentColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(
            color: AppTheme.textSecondary.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _clueController,
              focusNode: _focusNode,
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.none,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Escribe tu pista...',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary,
                ),
                counterText: '',
                filled: true,
                fillColor: AppTheme.cardColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: accentColor.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: accentColor, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 50,
            child: Tooltip(
              message: 'Enviar pista',
              child: ElevatedButton(
                onPressed: _submitting ? null : _handleSubmitClue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaiting(OnlineMatchPlayer? currentPlayer) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(
            color: AppTheme.textSecondary.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: AppTheme.textSecondary,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              currentPlayer != null && !_connected(currentPlayer)
                  ? 'Esperando a ${currentPlayer.displayName} (desconectado)...'
                  : 'Esperando a ${currentPlayer?.displayName ?? '...'}...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: currentPlayer != null && !_connected(currentPlayer)
                    ? AppTheme.warningColor
                    : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreVoteCountdown(int seconds) {
    final progress = seconds / 5.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(
            color: AppTheme.textSecondary.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.textSecondary.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warningColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.how_to_vote_rounded,
                size: 20,
                color: AppTheme.warningColor,
              ),
              const SizedBox(width: 10),
              Text(
                'Votación en $seconds...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.warningColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ClueCard extends StatelessWidget {
  final String playerName;
  final String? avatarUrl;
  final String clue;
  final int seatOrder;
  final bool isConnected;
  final String? role; // Show role badge for spectators

  const _ClueCard({
    required this.playerName,
    this.avatarUrl,
    required this.clue,
    required this.seatOrder,
    this.isConnected = true,
    this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.textSecondary.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              children: [
                PlayerAvatar(
                  displayName: playerName,
                  avatarUrl: avatarUrl,
                  size: 36,
                ),
                if (!isConnected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.wifi_off_rounded,
                        size: 11,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      playerName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (role != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: role == 'impostor'
                              ? AppTheme.secondaryColor.withValues(alpha: 0.15)
                              : AppTheme.successColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          role == 'impostor' ? 'Impostor' : 'Civil',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: role == 'impostor'
                                ? AppTheme.secondaryColor
                                : AppTheme.successColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  clue,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
