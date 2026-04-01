import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';

class StartButton extends StatelessWidget {
  final int playerCount;
  final int minPlayers;
  final VoidCallback onStart;

  const StartButton({
    super.key,
    required this.playerCount,
    required this.minPlayers,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final canStart = playerCount >= minPlayers;
    final missingPlayers = (minPlayers - playerCount).clamp(0, minPlayers);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: canStart ? onStart : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              canStart ? AppTheme.primaryColor : AppTheme.surfaceColor,
          foregroundColor: canStart ? Colors.white : AppTheme.textSecondary.withValues(alpha: 0.4),
          disabledBackgroundColor: AppTheme.surfaceColor,
          disabledForegroundColor: AppTheme.textSecondary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: canStart ? 6 : 0,
          shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              canStart ? Icons.play_arrow_rounded : Icons.lock_rounded,
              size: 26,
            ),
            const SizedBox(width: 10),
            Text(
              canStart
                  ? 'Comenzar Partida'
                  : 'Faltan $missingPlayers jugador${missingPlayers == 1 ? '' : 'es'}',
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
