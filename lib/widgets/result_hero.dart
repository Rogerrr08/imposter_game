import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Encabezado de resultado unificado (local ↔ online): ilustración enmarcada
/// en card oscura + glow, título grande y subtítulo opcional. El color y la
/// imagen salen de quién ganó.
class ResultHero extends StatelessWidget {
  const ResultHero({
    super.key,
    required this.civilsWon,
    required this.title,
    this.subtitle,
  });

  final bool civilsWon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final color = civilsWon ? AppTheme.successColor : AppTheme.secondaryColor;
    final image = civilsWon
        ? 'assets/images/player_civil.webp'
        : 'assets/images/player_impostor.webp';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.r24),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: AppTheme.glowSoft(color),
      ),
      child: Column(
        children: [
          // Ilustración enmarcada (decisión de rebrand: card oscura + glow,
          // ya que los assets tienen fondo claro).
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppTheme.r20),
            ),
            child: Image.asset(
              image,
              width: 132,
              height: 132,
              cacheWidth: 264,
              cacheHeight: 264,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.05,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
