import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../database/database.dart';
import '../../models/game_state.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/game_provider.dart';
import '../../widgets/category_filter_bar.dart';
import '../../widgets/game_mode_filter_bar.dart';

class RankingsScreen extends ConsumerStatefulWidget {
  final int groupId;

  const RankingsScreen({super.key, required this.groupId});

  @override
  ConsumerState<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends ConsumerState<RankingsScreen> {
  static const _goldColor = Color(0xFFFFD700);
  static const _silverColor = Color(0xFFC0C0C0);
  static const _bronzeColor = Color(0xFFCD7F32);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selectedCategory = ref.read(rankingCategoryFilterProvider);
      final selectedMode = ref.read(rankingGameModeFilterProvider);
      ref.invalidate(
        rankingsProvider(
          (
            groupId: widget.groupId,
            category: selectedCategory,
            mode: selectedMode,
          ),
        ),
      );
    });
  }

  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/groups/${widget.groupId}');
  }

  @override
  Widget build(BuildContext context) {
    final groupId = widget.groupId;
    final selectedCategory = ref.watch(rankingCategoryFilterProvider);
    final selectedMode = ref.watch(rankingGameModeFilterProvider);
    final request = (
      groupId: groupId,
      category: selectedCategory,
      mode: selectedMode,
    );
    final rankingsAsync = ref.watch(
      rankingsProvider(request),
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleBackNavigation,
          ),
          title: const Text(
            'Rankings',
            style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              tooltip: 'Borrar ranking',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _confirmClearRanking,
            ),
            IconButton(
              tooltip: 'Refrescar',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.invalidate(rankingsProvider(request)),
            ),
          ],
        ),
        body: Column(
          children: [
            GameModeFilterBar(
              selectedMode: selectedMode,
              onModeSelected: (mode) => ref
                  .read(rankingGameModeFilterProvider.notifier)
                  .setMode(mode),
            ),
            CategoryFilterBar(
              selectedCategory: selectedCategory,
              onCategorySelected: (category) => ref
                  .read(rankingCategoryFilterProvider.notifier)
                  .setCategory(category),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: rankingsAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppTheme.secondaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error al cargar rankings',
                          style: TextStyle(fontFamily: 'Nunito',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => ref.invalidate(rankingsProvider(request)),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (rankings) {
                  if (rankings.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.leaderboard_rounded,
                              size: 80,
                              color: AppTheme.warningColor.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No hay rankings aún',
                              style: TextStyle(fontFamily: 'Nunito',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Juega partidas con este grupo\npara ver las clasificaciones.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'Nunito',
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: rankings.length,
                    itemBuilder: (context, index) {
                      final ranking = rankings[index];
                      final position = index + 1;
                      return _buildRankingItem(ranking, position);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingItem(PlayerRanking ranking, int position) {
    final isTop3 = position <= 3;

    String positionDisplay;
    Color positionColor;
    double fontSize;

    switch (position) {
      case 1:
        positionDisplay = '\uD83E\uDD47'; // Gold medal
        positionColor = _goldColor;
        fontSize = 28;
        break;
      case 2:
        positionDisplay = '\uD83E\uDD48'; // Silver medal
        positionColor = _silverColor;
        fontSize = 26;
        break;
      case 3:
        positionDisplay = '\uD83E\uDD49'; // Bronze medal
        positionColor = _bronzeColor;
        fontSize = 24;
        break;
      default:
        positionDisplay = '#$position';
        positionColor = AppTheme.textSecondary;
        fontSize = 14;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        color: isTop3
            ? AppTheme.cardColor.withValues(alpha: 1.0)
            : AppTheme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isTop3
              ? BorderSide(
                  color: positionColor.withValues(alpha: 0.4),
                  width: 1.5,
                )
              : BorderSide.none,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isTop3 ? 16 : 12,
          ),
          child: Row(
            children: [
              // Position
              SizedBox(
                width: 50,
                child: position <= 3
                    ? Text(
                        positionDisplay,
                        style: TextStyle(fontSize: fontSize),
                        textAlign: TextAlign.center,
                      )
                    : Text(
                        positionDisplay,
                        style: TextStyle(fontFamily: 'Nunito',
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          color: positionColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),
              const SizedBox(width: 12),

              // Player info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ranking.playerName,
                      style: TextStyle(fontFamily: 'Nunito',
                        fontSize: isTop3 ? 17 : 15,
                        fontWeight: isTop3 ? FontWeight.w700 : FontWeight.w500,
                        color: isTop3
                            ? AppTheme.textPrimary
                            : AppTheme.textPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                    if (ranking.gamesPlayed > 0)
                      Text(
                        'Partidas jugadas: ${ranking.gamesPlayed}  |  Victorias como civil: ${ranking.civilWins}  |  Victorias como impostor: ${ranking.impostorWins}',
                        style: TextStyle(fontFamily: 'Nunito',
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),

              // Points
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isTop3
                      ? positionColor.withValues(alpha: 0.15)
                      : AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '${ranking.totalPoints}',
                      style: TextStyle(fontFamily: 'Nunito',
                        fontSize: isTop3 ? 20 : 16,
                        fontWeight: FontWeight.w800,
                        color: isTop3 ? positionColor : AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'pts',
                      style: TextStyle(fontFamily: 'Nunito',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isTop3
                            ? positionColor.withValues(alpha: 0.7)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearRanking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Borrar ranking',
          style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Esto borrará el ranking acumulado de este grupo. Esta acción no se puede deshacer.',
          style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancelar',
              style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
            ),
            child: const Text(
              'Borrar',
              style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final db = ref.read(databaseProvider);
    await GameDao(db).clearRankingForGroup(widget.groupId);
    ref.invalidate(rankingsProvider);
  }
}
