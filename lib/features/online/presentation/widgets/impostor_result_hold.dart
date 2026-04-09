import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

/// Intermediate screen shown after the impostor makes a decision.
///
/// Types:
/// - `risk`: "El impostor decidio arriesgar!" (3s)
/// - `no_risk`: "El impostor decidio no arriesgar" (3s)
/// - `wrong_guess`: "El impostor adivino mal!" — shows guess word (4s)
class ImpostorResultHold extends StatefulWidget {
  final String type; // 'risk', 'no_risk', 'wrong_guess'
  final String impostorName;
  final String? guessWord;
  final int durationSeconds;

  const ImpostorResultHold({
    super.key,
    required this.type,
    required this.impostorName,
    this.guessWord,
    required this.durationSeconds,
  });

  @override
  State<ImpostorResultHold> createState() => _ImpostorResultHoldState();
}

class _ImpostorResultHoldState extends State<ImpostorResultHold>
    with SingleTickerProviderStateMixin {
  late AnimationController _timerController;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.durationSeconds),
    )..forward();
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.type == 'risk'
        ? AppTheme.warningColor
        : AppTheme.secondaryColor;

    final String title;
    final IconData icon;
    switch (widget.type) {
      case 'risk':
        title = 'El impostor decidio\narriesgar!';
        icon = Icons.casino_rounded;
      case 'no_risk':
        title = 'El impostor decidio\nno arriesgar';
        icon = Icons.shield_rounded;
      case 'wrong_guess':
        title = 'El impostor\nadivino mal!';
        icon = Icons.close_rounded;
      default:
        title = '';
        icon = Icons.info_rounded;
    }

    return Column(
      children: [
        // Depleting timer bar
        AnimatedBuilder(
          animation: _timerController,
          builder: (context, child) {
            return LinearProgressIndicator(
              value: 1.0 - _timerController.value,
              backgroundColor: AppTheme.textSecondary.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            );
          },
        ),

        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Icon(icon, size: 48, color: color),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Impostor name card
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: color.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              widget.impostorName.characters.first
                                  .toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.impostorName,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Guess word (only for wrong_guess)
                  if (widget.type == 'wrong_guess' &&
                      widget.guessWord != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              AppTheme.secondaryColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Intento adivinar:',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '"${widget.guessWord}"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
