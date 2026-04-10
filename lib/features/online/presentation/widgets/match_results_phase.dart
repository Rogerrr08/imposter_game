import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../theme/app_theme.dart';
import '../../application/online_match_provider.dart';
import '../../application/online_rooms_provider.dart';
import '../../data/supabase_config.dart';
import '../../domain/online_match.dart';
import '../../domain/online_room.dart';

class MatchResultsPhase extends ConsumerStatefulWidget {
  final String matchId;
  final MyMatchState myState;
  final bool isSpectator;

  const MatchResultsPhase({
    super.key,
    required this.matchId,
    required this.myState,
    this.isSpectator = false,
  });

  @override
  ConsumerState<MatchResultsPhase> createState() => _MatchResultsPhaseState();
}

class _MatchResultsPhaseState extends ConsumerState<MatchResultsPhase> {
  MatchScoresResult? _scores;
  bool _loading = true;
  bool _readyPressed = false;
  bool _settingReady = false;
  bool _startingMatch = false;
  bool _startFailed = false;

  String get _currentUserId =>
      SupabaseConfig.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    if (widget.isSpectator) {
      _loadScoresForSpectator();
    } else {
      _loadScores();
    }
  }

  Future<void> _loadScores() async {
    try {
      final result = await ref
          .read(onlineMatchRepositoryProvider)
          .calculateMatchScores(widget.matchId);
      if (mounted) {
        setState(() {
          _scores = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  /// Spectators can't call the RPC — derive from streams.
  void _loadScoresForSpectator() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final players =
          ref.read(onlineMatchPlayersProvider(widget.matchId)).value ?? [];
      final match =
          ref.read(onlineMatchProvider(widget.matchId)).value;

      if (players.isEmpty || match == null) {
        setState(() => _loading = false);
        return;
      }

      // Derive winner from players data
      final activeImpostors =
          players.where((p) => p.role == 'impostor' && !p.isEliminated).length;
      final winner = activeImpostors == 0 ? 'civils' : 'impostors';

      final scores = players.map((p) => PlayerScore(
        playerId: p.id,
        userId: p.userId,
        displayName: p.displayName,
        role: p.role,
        points: p.points,
        isEliminated: p.isEliminated,
        votedIncorrectly: p.votedIncorrectly,
        eliminatedByFailedGuess: p.eliminatedByFailedGuess,
        guessWord: p.guessWord,
      )).toList()
        ..sort((a, b) {
          final cmp = b.points.compareTo(a.points);
          return cmp != 0 ? cmp : a.displayName.compareTo(b.displayName);
        });

      setState(() {
        _scores = MatchScoresResult(
          winner: winner,
          word: widget.myState.word ?? '???',
          category: widget.myState.category,
          scores: scores,
        );
        _loading = false;
      });
    });
  }

  Future<void> _handlePlayAgain() async {
    if (_settingReady || _readyPressed) return;
    setState(() {
      _settingReady = true;
      _readyPressed = true;
    });
    try {
      await _setReadyWithRetry();
    } catch (e) {
      if (mounted) {
        setState(() => _readyPressed = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _settingReady = false);
    }
  }

  Future<void> _setReadyWithRetry() async {
    const maxRetries = 3;
    for (var i = 0; i < maxRetries; i++) {
      try {
        await ref.read(onlineRoomsRepositoryProvider).setReady(
              roomId: widget.myState.roomId,
              isReady: true,
            );
        return;
      } catch (e) {
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 800 * (i + 1)));
        } else {
          rethrow;
        }
      }
    }
  }

  Future<void> _autoStartMatch(OnlineRoom room, List<OnlineRoomPlayer> players) async {
    if (_startingMatch) return;
    setState(() => _startingMatch = true);
    try {
      final matchId = await ref
          .read(onlineMatchRepositoryProvider)
          .startMatch(room: room, players: players);
      if (mounted) {
        context.go('/online/match/$matchId');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _startingMatch = false;
          _startFailed = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  void _handleBackToRoom() {
    context.go('/online/room/${widget.myState.roomId}');
  }

  @override
  Widget build(BuildContext context) {
    // Watch room data for ready count and auto-start
    final roomPlayersAsync =
        ref.watch(onlineRoomPlayersProvider(widget.myState.roomId));
    final roomAsync =
        ref.watch(onlineRoomProvider(widget.myState.roomId));
    final roomPlayers = roomPlayersAsync.value ?? [];
    final room = roomAsync.value;
    final readyCount = roomPlayers.where((p) => p.isReady).length;
    final totalCount = roomPlayers.length;
    final minPlayers = room?.minPlayers ?? 4;
    final hasEnoughPlayers = totalCount >= minPlayers;
    final allReady = totalCount > 0 && readyCount == totalCount && hasEnoughPlayers;

    // Check if current user is host
    final isHost = roomPlayers
        .where((p) => p.userId == _currentUserId && p.isHost)
        .isNotEmpty;

    // Auto-start when all ready, enough players, and I'm host
    if (allReady && isHost && _readyPressed && !_startingMatch && !_startFailed && room != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_startingMatch && !_startFailed) {
          _autoStartMatch(room, roomPlayers);
        }
      });
    }

    // Non-host: when all ready, show "starting" state
    if (allReady && !isHost && _readyPressed && room != null) {
      // Watch for active match to navigate
      ref.listen<AsyncValue<OnlineRoom?>>(
        onlineRoomProvider(widget.myState.roomId),
        (prev, next) {
          final r = next.value;
          if (r != null && r.status == OnlineRoomStatus.playing) {
            // Room is now playing — find the new match and navigate
            _navigateToNewMatch();
          }
        },
      );
    }

    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            Text(
              'Calculando puntuación...',
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final scores = _scores;
    if (scores == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(
              'No se pudo cargar el resultado',
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleBackToRoom,
              child: const Text('Volver a la sala'),
            ),
          ],
        ),
      );
    }

    final civilsWon = scores.civilsWon;
    final winnerColor =
        civilsWon ? AppTheme.successColor : AppTheme.secondaryColor;

    // Impostor guess attempts (only show if any impostor tried to guess)
    final guessAttempts = scores.scores
        .where((s) => s.role == 'impostor' && s.guessWord != null)
        .toList();

    return SafeArea(
      child: Column(
        children: [
          // ─── Scrollable content ──────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // ─── Winner announcement ─────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 28, horizontal: 20),
                    decoration: BoxDecoration(
                      color: winnerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: winnerColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          civilsWon
                              ? 'assets/images/player_civil.webp'
                              : 'assets/images/player_impostor.webp',
                          width: 120,
                          height: 120,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          civilsWon
                              ? 'Los civiles ganan!'
                              : 'Los impostores ganan!',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: winnerColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Secret word revealed
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'La palabra era',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                scores.word,
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _badge(_capitalize(scores.category),
                                  AppTheme.textSecondary),
                            ],
                          ),
                        ),
                        // Override button (inside winner card)
                        if (civilsWon) ...[
                          const SizedBox(height: 16),
                          _buildImpostorOverrideButton(),
                        ],
                      ],
                    ),
                  ),

                  // ─── Impostor guess attempts ─────────────────────
                  if (guessAttempts.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildGuessAttemptsCard(guessAttempts),
                  ],

                  const SizedBox(height: 24),

                  // ─── Rankings ─────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ranking',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...scores.scores.asMap().entries.map((entry) {
                    final index = entry.key;
                    final player = entry.value;
                    return _buildPlayerRow(index, player);
                  }),
                  // Late joiners (room members not in match)
                  ..._buildLateJoiners(scores, roomPlayers),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ─── Fixed bottom buttons ────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.09),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPlayAgainButton(readyCount, totalCount, hasEnoughPlayers),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _handleBackToRoom,
                    child: Text(
                      'Volver a la sala',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayAgainButton(int readyCount, int totalCount, bool hasEnoughPlayers) {
    final waiting = _readyPressed && !_startingMatch && !_startFailed;
    final starting = _startingMatch;
    final failed = _startFailed || (_readyPressed && !hasEnoughPlayers);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _readyPressed ? null : _handlePlayAgain,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              AppTheme.textSecondary.withValues(alpha: 0.15),
          disabledForegroundColor: AppTheme.textSecondary,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: starting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Iniciando partida...',
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : failed
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_off_rounded, size: 20,
                          color: AppTheme.textSecondary),
                      const SizedBox(width: 10),
                      Text(
                        'No hay suficientes jugadores',
                        style: TextStyle(fontFamily: 'Nunito',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : waiting
                    ? Row(
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
                          Text(
                            'Esperando jugadores... ($readyCount/$totalCount)',
                            style: TextStyle(fontFamily: 'Nunito',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.replay_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Volver a jugar',
                            style: TextStyle(fontFamily: 'Nunito',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }

  Future<void> _navigateToNewMatch() async {
    try {
      final matchId = await ref
          .read(onlineMatchRepositoryProvider)
          .getActiveMatchForRoom(widget.myState.roomId);
      if (matchId != null && mounted) {
        context.go('/online/match/$matchId');
      }
    } catch (_) {}
  }

  Widget _buildGuessAttemptsCard(List<PlayerScore> attempts) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Intentos de adivinanza',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...attempts.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          a.displayName.characters.first.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.displayName,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '"${a.guessWord}"',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      a.eliminatedByFailedGuess
                          ? Icons.close_rounded
                          : Icons.check_rounded,
                      size: 20,
                      color: a.eliminatedByFailedGuess
                          ? AppTheme.secondaryColor
                          : AppTheme.successColor,
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(int index, PlayerScore player) {
    final isCurrentUser = player.userId == _currentUserId;
    final isImpostor = player.isImpostor;
    final roleColor =
        isImpostor ? AppTheme.secondaryColor : AppTheme.primaryColor;

    // Position color for top 3
    final posColor = index == 0
        ? const Color(0xFFFFD700) // Gold
        : index == 1
            ? const Color(0xFFC0C0C0) // Silver
            : index == 2
                ? const Color(0xFFCD7F32) // Bronze
                : AppTheme.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppTheme.primaryColor.withValues(alpha: 0.08)
            : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : AppTheme.textSecondary.withValues(alpha: 0.08),
          width: isCurrentUser ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Position
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: posColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: posColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                player.displayName.characters.first.toUpperCase(),
                style: TextStyle(fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: roleColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.displayName,
                  style: TextStyle(fontFamily: 'Nunito',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: player.isEliminated
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                    decoration: player.isEliminated
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isImpostor ? 'Impostor' : 'Civil',
                        style: TextStyle(fontFamily: 'Nunito',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: roleColor,
                        ),
                      ),
                    ),
                    if (player.isEliminated) ...[
                      const SizedBox(width: 4),
                      Text(
                        'Eliminado',
                        style: TextStyle(fontFamily: 'Nunito',
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    if (isCurrentUser) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(Tu)',
                        style: TextStyle(fontFamily: 'Nunito',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Points
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${player.points} pts',
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.warningColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLateJoiners(
    MatchScoresResult scores,
    List<OnlineRoomPlayer> roomPlayers,
  ) {
    final scoreUserIds = scores.scores.map((s) => s.userId).toSet();
    final lateJoiners =
        roomPlayers.where((p) => !scoreUserIds.contains(p.userId)).toList();

    if (lateJoiners.isEmpty) return [];

    return lateJoiners.map((player) {
      final isCurrentUser = player.userId == _currentUserId;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrentUser
                ? AppTheme.primaryColor.withValues(alpha: 0.3)
                : AppTheme.textSecondary.withValues(alpha: 0.08),
            width: isCurrentUser ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // No position — dash
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '-',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  player.displayName.characters.first.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + "Se unió" badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.displayName,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.textSecondary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Se unió',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(Tu)',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // 0 pts
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '0 pts',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildImpostorOverrideButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showImpostorOverrideDialog,
        icon: const Icon(Icons.psychology_alt, size: 18),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.secondaryColor,
          side: BorderSide(
            color: AppTheme.secondaryColor.withValues(alpha: 0.4),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        label: Text(
          'Darle la victoria al impostor',
          style: TextStyle(fontFamily: 'Nunito',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showImpostorOverrideDialog() {
    final scores = _scores;
    if (scores == null) return;

    final impostors = scores.scores.where((s) => s.isImpostor).toList();

    if (impostors.length == 1) {
      _confirmOverride(impostors.first.playerId, impostors.first.displayName);
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Que impostor adivino?',
          style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: impostors.map((impostor) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _confirmOverride(
                        impostor.playerId, impostor.displayName);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    impostor.displayName,
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancelar',
              style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmOverride(String impostorPlayerId, String impostorName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Confirmar cambio',
          style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Se cambiara el resultado a victoria de impostores. '
          '$impostorName recibira 3 pts y los demas impostores 1 pt. '
          'Los civiles no recibiran puntos.',
          style: TextStyle(fontFamily: 'Nunito',fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancelar',
              style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final result = await ref
                    .read(onlineMatchRepositoryProvider)
                    .overrideImpostorVictory(
                      matchId: widget.matchId,
                      impostorPlayerId: impostorPlayerId,
                    );
                if (mounted) {
                  setState(() => _scores = result);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          e.toString().replaceFirst('Exception: ', '')),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
            ),
            child: Text(
              'Confirmar',
              style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'Nunito',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
