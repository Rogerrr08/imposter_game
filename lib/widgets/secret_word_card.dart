import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_badge.dart';

/// Revelación de la palabra secreta, unificada local ↔ online: card con glow
/// ámbar, la palabra grande y un badge con la categoría.
class SecretWordCard extends StatelessWidget {
  const SecretWordCard({super.key, required this.word, required this.category});

  final String word;
  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.r20),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: AppTheme.glowSoft(AppTheme.warningColor),
      ),
      child: Column(
        children: [
          Text(
            'La palabra secreta',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            word,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: AppTheme.warningColor,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 12),
          AppBadge(label: category, color: AppTheme.primaryColor),
        ],
      ),
    );
  }
}
