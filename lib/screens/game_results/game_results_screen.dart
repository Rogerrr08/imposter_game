import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/game_state.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/player_row.dart';
import '../../widgets/result_hero.dart';
import '../../widgets/secret_word_card.dart';

class GameResultsScreen extends ConsumerStatefulWidget {
  const GameResultsScreen({super.key});

  @override
  ConsumerState<GameResultsScreen> createState() => _GameResultsScreenState();
}

class _GameResultsScreenState extends ConsumerState<GameResultsScreen> {
  @override
  void initState() {
    super.initState();
    // Celebración: un golpe háptico al aterrizar en los resultados.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) HapticFeedback.heavyImpact();
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    if (game == null) {
      return const Scaffold(body: Center(child: Text('No hay partida activa')));
    }

    final civilsWon = game.civilsWon;
    final impostorGuessed = game.impostorGuessedWord;
    final groupId = game.config.groupId;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildResultHeader(civilsWon, impostorGuessed),
                const SizedBox(height: 24),
                SecretWordCard(
                  word: game.secretWord,
                  category: game.wordCategory.displayName,
                ),
                if (game.impostors.any((p) => p.hint != null)) ...[
                  const SizedBox(height: 16),
                  _buildImpostorHints(game),
                ],
                if (civilsWon && !impostorGuessed) ...[
                  const SizedBox(height: 18),
                  _buildImpostorOverrideButton(context, ref, game),
                ],
                const SizedBox(height: 32),
                _buildPlayerRanking(game),
                const SizedBox(height: 32),
                _buildPointsSummary(game),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(gameProvider.notifier).clearGame();
                      context.go('/setup', extra: groupId);
                    },
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('¡Otra ronda!'),
                  ),
                ),
                if (groupId != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/rankings/$groupId'),
                      icon: const Icon(Icons.leaderboard_rounded),
                      label: const Text('Ver ranking'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      ref.read(gameProvider.notifier).clearGame();
                      if (groupId != null) {
                        context.go('/groups/$groupId');
                      } else {
                        context.go('/');
                      }
                    },
                    child: Text(
                      groupId != null ? 'Volver al grupo' : 'Ir al inicio',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultHeader(bool civilsWon, bool impostorGuessed) {
    final subtitle = civilsWon
        ? 'Todos los impostores fueron descubiertos'
        : impostorGuessed
        ? 'El impostor adivinó la palabra secreta'
        : 'Los civiles se quedaron sin vidas o ya solo quedaban dos jugadores';

    return ResultHero(
      civilsWon: civilsWon,
      title: civilsWon ? '¡Civiles ganan!' : '¡Impostores ganan!',
      subtitle: subtitle,
    );
  }

  Widget _buildImpostorHints(ActiveGame game) {
    final impostorsWithHints = game.impostors
        .where((player) => player.hint != null)
        .toList();

    if (impostorsWithHints.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.visibility_rounded,
                size: 18,
                color: AppTheme.secondaryColor.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 8),
              Text(
                'Pistas de los impostores',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...impostorsWithHints.map(
            (player) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        player.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        player.hint!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerRanking(ActiveGame game) {
    final sorted = List<GamePlayer>.from(game.players)
      ..sort((a, b) => b.points.compareTo(a.points));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ranking',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...sorted.asMap().entries.map((entry) {
          final player = entry.value;
          final isImpostor = player.role == PlayerRole.impostor;
          final roleColor = isImpostor
              ? AppTheme.secondaryColor
              : AppTheme.primaryColor;
          final initial = player.name.trim().isEmpty
              ? '?'
              : player.name.trim()[0].toUpperCase();
          return PlayerRow(
            position: entry.key + 1,
            name: player.name,
            isImpostor: isImpostor,
            points: player.points,
            isEliminated: player.isEliminated,
            avatar: CircleAvatar(
              radius: 18,
              backgroundColor: roleColor.withValues(alpha: 0.15),
              child: Text(
                initial,
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPointsSummary(ActiveGame game) {
    final totalPoints = game.players.fold<int>(0, (sum, player) {
      return sum + player.points;
    });
    final impostorPoints = game.impostors.fold<int>(0, (sum, player) {
      return sum + player.points;
    });
    final civilPoints = totalPoints - impostorPoints;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _pointColumn('Civiles', civilPoints, AppTheme.successColor),
          Container(
            width: 1,
            height: 40,
            color: AppTheme.textSecondary.withValues(alpha: 0.15),
          ),
          _pointColumn('Impostores', impostorPoints, AppTheme.secondaryColor),
        ],
      ),
    );
  }

  Widget _buildImpostorOverrideButton(
    BuildContext context,
    WidgetRef ref,
    ActiveGame game,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showImpostorOverrideDialog(context, ref, game),
        icon: const Icon(Icons.psychology_alt, size: 20),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.secondaryColor,
          side: BorderSide(
            color: AppTheme.secondaryColor.withValues(alpha: 0.4),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        label: const Text(
          'Darle la victoria al impostor',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showImpostorOverrideDialog(
    BuildContext context,
    WidgetRef ref,
    ActiveGame game,
  ) {
    final impostors = game.impostors;

    if (impostors.length == 1) {
      _confirmOverride(context, ref, impostors.first.name);
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          '¿Qué impostor adivinó?',
          style: TextStyle(fontWeight: FontWeight.w700),
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
                    _confirmOverride(context, ref, impostor.name);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    impostor.name,
                    style: const TextStyle(
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
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmOverride(
    BuildContext context,
    WidgetRef ref,
    String impostorName,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Confirmar cambio',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Se cambiará el resultado a victoria de impostores. '
          '$impostorName recibirá 3 pts y los demás impostores 1 pt. '
          'Los civiles no recibirán puntos.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref
                  .read(gameProvider.notifier)
                  .overrideImpostorGuessedCorrectly(impostorName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
            ),
            child: const Text(
              'Confirmar',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pointColumn(String label, int points, Color color) {
    return Column(
      children: [
        Text(
          '$points pts',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
