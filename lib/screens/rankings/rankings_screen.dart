import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../providers/game_provider.dart';

class RankingsScreen extends ConsumerWidget {
  final int groupId;

  const RankingsScreen({super.key, required this.groupId});

  static const _goldColor = Color(0xFFFFD700);
  static const _silverColor = Color(0xFFC0C0C0);
  static const _bronzeColor = Color(0xFFCD7F32);

  static const _categoryLabels = <String?, String>{
    null: 'Todas',
    'cosas': 'Cosas',
    'entretenimiento': 'Entretenimiento',
    'geografia': 'Geograf\u00eda',
    'deportes': 'Deportes',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(rankingCategoryFilterProvider);
    final rankingsAsync = ref.watch(
      rankingsProvider((groupId: groupId, category: selectedCategory)),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Rankings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          // Category filter chips
          _buildCategoryFilter(ref, selectedCategory),
          const SizedBox(height: 8),

          // Rankings list
          Expanded(
            child: rankingsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppTheme.secondaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error al cargar rankings',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
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
                            'No hay rankings a\u00fan',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Juega partidas con este grupo\npara ver las clasificaciones.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white54,
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
    );
  }

  Widget _buildCategoryFilter(WidgetRef ref, String? selectedCategory) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _categoryLabels.entries.map((entry) {
          final isSelected = selectedCategory == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(
                entry.value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
              backgroundColor: AppTheme.cardColor,
              selectedColor: AppTheme.primaryColor,
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected
                    ? AppTheme.primaryColor
                    : Colors.white.withValues(alpha: 0.15),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onSelected: (_) {
                ref
                    .read(rankingCategoryFilterProvider.notifier)
                    .setCategory(entry.key);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRankingItem(dynamic ranking, int position) {
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
        positionColor = Colors.white54;
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
                        style: GoogleFonts.poppins(
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
                      style: GoogleFonts.poppins(
                        fontSize: isTop3 ? 17 : 15,
                        fontWeight: isTop3 ? FontWeight.w700 : FontWeight.w500,
                        color: isTop3
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    if (ranking.gamesPlayed > 0)
                      Text(
                        '${ranking.gamesPlayed} partida${ranking.gamesPlayed == 1 ? '' : 's'}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white54,
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
                      style: GoogleFonts.poppins(
                        fontSize: isTop3 ? 20 : 16,
                        fontWeight: FontWeight.w800,
                        color: isTop3 ? positionColor : Colors.white,
                      ),
                    ),
                    Text(
                      'pts',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isTop3
                            ? positionColor.withValues(alpha: 0.7)
                            : Colors.white54,
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
}
