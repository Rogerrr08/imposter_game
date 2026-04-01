import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/game_state.dart';
import '../theme/app_theme.dart';

const gameModeLabels = <GameMode?, String>{
  null: 'Todas',
  GameMode.express: '\u26A1 Express',
  GameMode.classic: '\u{1F3DB}\uFE0F Cl\u00E1sico',
};

class GameModeFilterBar extends StatelessWidget {
  final GameMode? selectedMode;
  final ValueChanged<GameMode?> onModeSelected;

  const GameModeFilterBar({
    super.key,
    required this.selectedMode,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: gameModeLabels.entries.map((entry) {
          final isSelected = selectedMode == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(
                entry.value,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              backgroundColor: AppTheme.cardColor,
              selectedColor: AppTheme.secondaryColor,
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected
                    ? AppTheme.secondaryColor
                    : AppTheme.textSecondary.withValues(alpha: 0.2),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onSelected: (_) => onModeSelected(entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }
}
