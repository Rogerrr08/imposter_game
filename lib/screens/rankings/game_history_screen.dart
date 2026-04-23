import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../../models/game_state.dart';
import '../../providers/database_provider.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/category_filter_bar.dart';
import '../../widgets/game_mode_filter_bar.dart';

class GameHistoryScreen extends ConsumerStatefulWidget {
  final int groupId;

  const GameHistoryScreen({super.key, required this.groupId});

  @override
  ConsumerState<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends ConsumerState<GameHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selectedCategory = ref.read(historyCategoryFilterProvider);
      final selectedMode = ref.read(historyGameModeFilterProvider);
      ref.invalidate(
        gameHistoryProvider(
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
    final selectedCategory = ref.watch(historyCategoryFilterProvider);
    final selectedMode = ref.watch(historyGameModeFilterProvider);
    final request = (
      groupId: widget.groupId,
      category: selectedCategory,
      mode: selectedMode,
    );
    final historyAsync = ref.watch(gameHistoryProvider(request));

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
            'Historial',
            style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w700),
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
            GameModeFilterBar(
              selectedMode: selectedMode,
              onModeSelected: (mode) => ref
                  .read(historyGameModeFilterProvider.notifier)
                  .setMode(mode),
            ),
            CategoryFilterBar(
              selectedCategory: selectedCategory,
              onCategorySelected: (category) => ref
                  .read(historyCategoryFilterProvider.notifier)
                  .setCategory(category),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: historyAsync.when(
                loading: () => Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.primaryColor),
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
                          'Error al cargar el historial',
                          style: TextStyle(fontFamily: 'Nunito',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () =>
                              ref.invalidate(gameHistoryProvider(request)),
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
                              color:
                                  AppTheme.successColor.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No hay partidas registradas',
                              style: TextStyle(fontFamily: 'Nunito',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Las partidas jugadas con este grupo\naparecer\u00E1n aqu\u00ED.',
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
                    itemCount: games.length,
                    itemBuilder: (context, index) {
                      return _GameHistoryCard(gameWithPlayers: games[index]);
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

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Borrar historial',
          style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Esto borrara el historial guardado de este grupo. El ranking no se vera afectado.',
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

  String _modeDisplay(String mode) {
    switch (mode) {
      case 'classic':
        return '\u{1F3DB}\uFE0F Cl\u00E1sico';
      case 'express':
      default:
        return '\u26A1 Express';
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.gameWithPlayers.game;
    final players = widget.gameWithPlayers.players as List<dynamic>;
    final civilsWon = game.civilsWon as bool;
    final impostorGuessedWord = game.impostorGuessedWord as bool;
    final dateFormat = DateFormat('dd MMM yyyy - HH:mm', 'es');

    final impostors = players.where((p) => p.wasImpostor == true).toList();
    final resultText = civilsWon ? 'Civiles ganaron' : 'Impostores ganaron';
    final resultColor =
        civilsWon ? AppTheme.successColor : AppTheme.secondaryColor;
    final resultIcon =
        civilsWon ? Icons.shield_rounded : Icons.psychology_alt;
    final categoryDisplay = categoryLabels[game.category] ?? game.category;
    final modeDisplay = _modeDisplay(game.mode as String);

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
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateFormat.format(game.playedAt),
                      style: TextStyle(fontFamily: 'Nunito',
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.timer_rounded,
                      size: 14,
                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      durationText,
                      style: TextStyle(fontFamily: 'Nunito',
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textSecondary.withValues(alpha: 0.6),
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.textSecondary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        modeDisplay,
                        style: TextStyle(fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        categoryDisplay,
                        style: TextStyle(fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    Text(
                      'Palabra: ${game.word}',
                      style: TextStyle(fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                          style: TextStyle(fontFamily: 'Nunito',
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                          children: [
                            const TextSpan(text: 'Impostor: '),
                            TextSpan(
                              text: impostors.map((p) => p.playerName).join(', '),
                              style: TextStyle(fontFamily: 'Nunito',
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                        style: TextStyle(fontFamily: 'Nunito',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: resultColor,
                        ),
                      ),
                      if (impostorGuessedWord) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Adivino la palabra',
                            style: TextStyle(fontFamily: 'Nunito',
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
                if (_isExpanded) ...[
                  const SizedBox(height: 16),
                  Divider(
                    color: AppTheme.textSecondary.withValues(alpha: 0.15),
                    height: 1,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Puntuaci\u00F3n',
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...players.map((player) {
                    final isImpostor = player.wasImpostor == true;
                    final wasEliminated = player.wasEliminated == true;
                    final points = player.points as int;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            isImpostor
                                ? Icons.psychology_alt
                                : Icons.shield_rounded,
                            size: 16,
                            color: isImpostor
                                ? AppTheme.secondaryColor
                                : AppTheme.successColor.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  player.playerName,
                                  style: TextStyle(fontFamily: 'Nunito',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isImpostor
                                        ? AppTheme.secondaryColor
                                        : AppTheme.textPrimary.withValues(
                                            alpha: 0.85,
                                          ),
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
                                      color: AppTheme.textSecondary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'eliminado',
                                      style: TextStyle(fontFamily: 'Nunito',
                                        fontSize: 10,
                                        color: AppTheme.textSecondary.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: points > 0
                                  ? AppTheme.successColor.withValues(alpha: 0.12)
                                  : AppTheme.textSecondary.withValues(
                                      alpha: 0.07,
                                    ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              points > 0 ? '+$points pts' : '0 pts',
                              style: TextStyle(fontFamily: 'Nunito',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: points > 0
                                    ? AppTheme.successColor
                                    : AppTheme.textSecondary.withValues(
                                        alpha: 0.6,
                                      ),
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
