import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import 'shake_widget.dart';

class PlayerListItem {
  final String name;
  final bool isActive;

  const PlayerListItem({required this.name, this.isActive = true});
}

class PlayerList extends StatelessWidget {
  final List<PlayerListItem> players;
  final int minPlayers;
  final bool isGroupMode;
  final int? draggingIndex;
  final ValueChanged<int> onDragStart;
  final VoidCallback onDragEnd;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<int>? onRemovePlayer;
  final ValueChanged<int>? onTogglePlayer;

  const PlayerList({
    super.key,
    required this.players,
    required this.minPlayers,
    required this.isGroupMode,
    required this.draggingIndex,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onReorder,
    this.onRemovePlayer,
    this.onTogglePlayer,
  });

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 36,
              color: AppTheme.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega al menos $minPlayers jugadores',
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      proxyDecorator: (child, index, animation) {
        return ShakeWidget(child: child);
      },
      onReorderStart: onDragStart,
      onReorderEnd: (_) => onDragEnd(),
      itemCount: players.length,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final player = players[index];
        final isDragging = draggingIndex == index;
        final isExcluded = !player.isActive;

        return Container(
          key: ValueKey(player.name),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isExcluded
                ? AppTheme.surfaceColor.withValues(alpha: 0.5)
                : isDragging
                    ? AppTheme.primaryColor.withValues(alpha: 0.1)
                    : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isExcluded
                  ? AppTheme.textSecondary.withValues(alpha: 0.1)
                  : isDragging
                      ? AppTheme.secondaryColor
                      : AppTheme.textSecondary.withValues(alpha: 0.15),
              width: isDragging ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.drag_handle_rounded,
                color: isExcluded
                    ? AppTheme.textSecondary.withValues(alpha: 0.2)
                    : isDragging
                        ? AppTheme.secondaryColor
                        : AppTheme.textSecondary.withValues(alpha: 0.4),
                size: 20,
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 14,
                backgroundColor: isExcluded
                    ? AppTheme.textSecondary.withValues(alpha: 0.2)
                    : isDragging
                        ? AppTheme.secondaryColor.withValues(alpha: 0.6)
                        : AppTheme.primaryColor.withValues(alpha: 0.6),
                child: Text(
                  player.name[0].toUpperCase(),
                  style: TextStyle(fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  player.name,
                  style: TextStyle(fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: isExcluded ? FontWeight.w400 : FontWeight.w600,
                    color: isExcluded
                        ? AppTheme.textSecondary.withValues(alpha: 0.5)
                        : isDragging
                            ? AppTheme.secondaryColor
                            : AppTheme.textPrimary,
                    decoration: isExcluded ? TextDecoration.lineThrough : null,
                    decorationColor: AppTheme.textSecondary.withValues(alpha: 0.4),
                  ),
                ),
              ),
              if (isGroupMode && onTogglePlayer != null)
                GestureDetector(
                  onTap: () => onTogglePlayer!(index),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isExcluded
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : AppTheme.secondaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isExcluded ? Icons.add_rounded : Icons.close_rounded,
                      size: 16,
                      color: isExcluded
                          ? AppTheme.primaryColor
                          : AppTheme.secondaryColor,
                    ),
                  ),
                )
              else if (!isGroupMode && onRemovePlayer != null)
                GestureDetector(
                  onTap: () => onRemovePlayer!(index),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
