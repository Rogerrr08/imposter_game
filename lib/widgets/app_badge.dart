import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppBadgeSize { sm, md }

/// Pill de estado/rol unificado. Reemplaza los ~5 métodos `_badge()` duplicados
/// y los badges inline (que mezclaban radios rectangulares y pill).
/// Siempre pill, fondo tintado del color y texto del color.
class AppBadge extends StatelessWidget {
  final String label;
  final Color color;
  final AppBadgeSize size;
  final IconData? icon;

  const AppBadge({
    super.key,
    required this.label,
    required this.color,
    this.size = AppBadgeSize.md,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final sm = size == AppBadgeSize.sm;
    final fontSize = sm ? 11.0 : 13.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sm ? AppTheme.sp8 : AppTheme.sp12,
        vertical: sm ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.rFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
