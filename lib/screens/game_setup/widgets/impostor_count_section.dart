import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import 'section_header.dart';

class ImpostorCountSection extends StatelessWidget {
  final int impostorCount;
  final int maxImpostors;
  final int playerCount;
  final int minPlayers;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const ImpostorCountSection({
    super.key,
    required this.impostorCount,
    required this.maxImpostors,
    required this.playerCount,
    required this.minPlayers,
    this.onDecrement,
    this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.psychology_alt_rounded,
          title: 'Impostores: $impostorCount',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              _roundIconButton(
                icon: Icons.remove_rounded,
                onTap: onDecrement,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$impostorCount',
                      style: GoogleFonts.nunito(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                    Text(
                      impostorCount == 1 ? 'impostor' : 'impostores',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _roundIconButton(
                icon: Icons.add_rounded,
                onTap: onIncrement,
              ),
            ],
          ),
        ),
        if (playerCount >= minPlayers)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'M\u00E1ximo $maxImpostors impostor${maxImpostors == 1 ? '' : 'es'} para $playerCount jugadores',
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ),
      ],
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Material(
      color: enabled
          ? AppTheme.primaryColor.withValues(alpha: 0.2)
          : AppTheme.textSecondary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: enabled ? AppTheme.primaryColor : AppTheme.textSecondary.withValues(alpha: 0.3),
            size: 24,
          ),
        ),
      ),
    );
  }
}
