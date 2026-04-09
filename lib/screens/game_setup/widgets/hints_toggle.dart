import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class HintsToggle extends StatelessWidget {
  final bool hintsEnabled;
  final ValueChanged<bool> onChanged;

  const HintsToggle({
    super.key,
    required this.hintsEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          'Pistas para impostores',
          style: TextStyle(fontFamily: 'Nunito',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          hintsEnabled
              ? 'Los impostores reciben una pista m\u00E1s sutil'
              : 'Sin pistas, mayor dificultad',
          style: TextStyle(fontFamily: 'Nunito',
            fontSize: 12,
            color: AppTheme.textSecondary.withValues(alpha: 0.8),
          ),
        ),
        secondary: Icon(
          hintsEnabled ? Icons.lightbulb_rounded : Icons.lightbulb_outline,
          color: hintsEnabled ? AppTheme.warningColor : AppTheme.textSecondary.withValues(alpha: 0.5),
          size: 26,
        ),
        value: hintsEnabled,
        activeColor: AppTheme.primaryColor,
        onChanged: onChanged,
      ),
    );
  }
}
