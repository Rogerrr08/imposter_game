import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_theme.dart';
import '../../application/online_match_provider.dart';
import '../../data/supabase_config.dart';
import '../../domain/online_match.dart';

class MatchResultsPhase extends ConsumerStatefulWidget {
  final String matchId;
  final MyMatchState myState;

  const MatchResultsPhase({
    super.key,
    required this.matchId,
    required this.myState,
  });

  @override
  ConsumerState<MatchResultsPhase> createState() => _MatchResultsPhaseState();
}

class _MatchResultsPhaseState extends ConsumerState<MatchResultsPhase> {
  MatchScoresResult? _scores;
  bool _loading = true;

  String get _currentUserId =>
      SupabaseConfig.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadScores();
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

  void _handleBackToRoom() {
    context.go('/online/room/${widget.myState.roomId}');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            Text(
              'Calculando puntuacion...',
              style: GoogleFonts.nunito(
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
              style: GoogleFonts.nunito(
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

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ─── Winner announcement ────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: winnerColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: winnerColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    civilsWon
                        ? Icons.shield_rounded
                        : Icons.visibility_off_rounded,
                    size: 56,
                    color: winnerColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    civilsWon
                        ? 'Los civiles ganan!'
                        : 'Los impostores ganan!',
                    style: GoogleFonts.nunito(
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
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          scores.word,
                          style: GoogleFonts.nunito(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _badge(scores.category, AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Rankings ───────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ranking',
                style: GoogleFonts.nunito(
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
            const SizedBox(height: 28),

            // ─── Action button ─────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleBackToRoom,
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(
                  'Volver a la sala',
                  style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
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
                style: GoogleFonts.nunito(
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
                style: GoogleFonts.nunito(
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
                  style: GoogleFonts.nunito(
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
                        style: GoogleFonts.nunito(
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
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    if (isCurrentUser) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(Tu)',
                        style: GoogleFonts.nunito(
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
              style: GoogleFonts.nunito(
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

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
