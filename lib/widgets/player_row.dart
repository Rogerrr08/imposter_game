import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_badge.dart';

/// Fila de ranking unificada local ↔ online: medalla de posición (oro/plata/
/// bronce para el top 3), avatar (lo provee cada pantalla), nombre + rol, y
/// los puntos. Marca al jugador actual (online) y a los eliminados.
class PlayerRow extends StatelessWidget {
  const PlayerRow({
    super.key,
    required this.position,
    required this.name,
    required this.avatar,
    required this.isImpostor,
    required this.points,
    this.isEliminated = false,
    this.isCurrentUser = false,
  });

  /// Posición 1-based. 1/2/3 reciben color de medalla.
  final int position;
  final String name;
  final Widget avatar;
  final bool isImpostor;
  final int points;
  final bool isEliminated;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final roleColor = isImpostor
        ? AppTheme.secondaryColor
        : AppTheme.primaryColor;
    final posColor = switch (position) {
      1 => AppTheme.goldColor,
      2 => AppTheme.silverColor,
      3 => AppTheme.bronzeColor,
      _ => AppTheme.textSecondary,
    };
    final pointsColor = points >= 0
        ? AppTheme.warningColor
        : AppTheme.errorColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppTheme.primaryColor.withValues(alpha: 0.08)
            : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.r16),
        border: Border.all(
          color: isCurrentUser
              ? AppTheme.primaryColor.withValues(alpha: 0.30)
              : AppTheme.textSecondary.withValues(alpha: 0.08),
          width: isCurrentUser ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: posColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$position',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: posColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isEliminated
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                    decoration: isEliminated
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    AppBadge(
                      label: isImpostor ? 'Impostor' : 'Civil',
                      color: roleColor,
                      size: AppBadgeSize.sm,
                    ),
                    if (isEliminated) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Eliminado',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(Tú)',
                        style: TextStyle(
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: pointsColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppTheme.rFull),
            ),
            child: Text(
              '${points >= 0 ? '+' : ''}$points',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: pointsColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
