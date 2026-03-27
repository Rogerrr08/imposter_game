import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/game_provider.dart';

class GameHistoryScreen extends ConsumerStatefulWidget {
  final int groupId;

  const GameHistoryScreen({super.key, required this.groupId});

  @override
  ConsumerState<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends ConsumerState<GameHistoryScreen> {
  static const _categoryLabels = <String?, String>{
    null: 'Todas',
    'cosas': 'Cosas',
    'entretenimiento': 'Entretenimiento',
    'geografia': 'Geograf\u00eda',
    'deportes': 'Deportes',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selectedCategory = ref.read(historyCategoryFilterProvider);
      ref.invalidate(
        gameHistoryProvider(
          (
            groupId: widget.groupId,
            category: selectedCategory,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupId = widget.groupId;
    final selectedCategory = ref.watch(historyCategoryFilterProvider);
    final request = (groupId: groupId, category: selectedCategory);
    final historyAsync = ref.watch(
      gameHistoryProvider(request),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/groups/$groupId'),
        ),
        title: Text(
          'Historial',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Borrar historial',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _confirmClearHistory,
          ),
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(gameHistoryProvider(request)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter chips
          _buildCategoryFilter(ref, selectedCategory),
          const SizedBox(height: 8),

          // History list
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppTheme.secondaryColor),
                      const SizedBox(height: 16),
                      Text(
                        'Error al cargar el historial',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => ref.invalidate(gameHistoryProvider(request)),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (games) {
                if (games.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 80,
                            color: AppTheme.successColor.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No hay partidas registradas',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Las partidas jugadas con este grupo\naparecerán aqu\u00ed.',
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
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    final gameWithPlayers = games[index];
                    return _GameHistoryCard(gameWithPlayers: gameWithPlayers);
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
                    .read(historyCategoryFilterProvider.notifier)
                    .setCategory(entry.key);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Borrar historial',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Esto borrará el historial guardado de este grupo. El ranking no se verá afectado.',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
            ),
            child: Text(
              'Borrar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final db = ref.read(databaseProvider);
    await GameDao(db).clearHistoryForGroup(widget.groupId);
    ref.invalidate(gameHistoryProvider);
  }
}

class _GameHistoryCard extends StatefulWidget {
  final dynamic gameWithPlayers;

  const _GameHistoryCard({required this.gameWithPlayers});

  @override
  State<_GameHistoryCard> createState() => _GameHistoryCardState();
}

class _GameHistoryCardState extends State<_GameHistoryCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  static const _categoryDisplayNames = {
    'cosas': 'Cosas',
    'entretenimiento': 'Entretenimiento',
    'geografia': 'Geograf\u00eda',
    'deportes': 'Deportes',
  };

  @override
  Widget build(BuildContext context) {
    final game = widget.gameWithPlayers.game;
    final players = widget.gameWithPlayers.players as List<dynamic>;
    final civilsWon = game.civilsWon as bool;
    final impostorGuessedWord = game.impostorGuessedWord as bool;
    final dateFormat = DateFormat('dd MMM yyyy - HH:mm', 'es');

    final impostors = players.where((p) => p.wasImpostor == true).toList();

    final resultText = civilsWon ? 'Civiles ganaron' : 'Impostores ganaron';
    final resultColor = civilsWon ? AppTheme.successColor : AppTheme.secondaryColor;
    final resultIcon = civilsWon ? Icons.shield_rounded : Icons.psychology_alt;

    final categoryDisplay =
        _categoryDisplayNames[game.category] ?? game.category;

    final durationMinutes = (game.duration as int) ~/ 60;
    final durationSeconds = (game.duration as int) % 60;
    final durationText = durationMinutes > 0
        ? '${durationMinutes}m ${durationSeconds}s'
        : '${durationSeconds}s';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: resultColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: date and expand icon
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateFormat.format(game.playedAt),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.timer_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      durationText,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white38,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Category and word
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        categoryDisplay,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Palabra: ${game.word}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Impostors
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.psychology_alt,
                      size: 16,
                      color: AppTheme.secondaryColor.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
                          children: [
                            const TextSpan(text: 'Impostor: '),
                            TextSpan(
                              text: impostors.map((p) => p.playerName).join(', '),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Result
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: resultColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(resultIcon, size: 18, color: resultColor),
                      const SizedBox(width: 8),
                      Text(
                        resultText,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: resultColor,
                        ),
                      ),
                      if (impostorGuessedWord) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Adivin\u00f3 la palabra',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.warningColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Expanded details
                if (_isExpanded) ...[
                  const SizedBox(height: 16),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.1),
                    height: 1,
                  ),
                  const SizedBox(height: 16),

                  // Points header
                  Text(
                    'Puntuaci\u00f3n',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Player points list
                  ...players.map((player) {
                    final isImpostor = player.wasImpostor == true;
                    final wasEliminated = player.wasEliminated == true;
                    final points = player.points as int;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          // Impostor/civil icon
                          Icon(
                            isImpostor ? Icons.psychology_alt : Icons.shield_rounded,
                            size: 16,
                            color: isImpostor
                                ? AppTheme.secondaryColor
                                : AppTheme.successColor.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 8),

                          // Player name
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  player.playerName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isImpostor
                                        ? AppTheme.secondaryColor
                                        : Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                                if (wasEliminated) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'eliminado',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.white38,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Points
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: points > 0
                                  ? AppTheme.successColor.withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              points > 0 ? '+$points pts' : '0 pts',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: points > 0
                                    ? AppTheme.successColor
                                    : Colors.white38,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
