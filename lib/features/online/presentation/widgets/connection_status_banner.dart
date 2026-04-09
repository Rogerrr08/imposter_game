import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

/// Thin banner shown at the top of the match screen when
/// the player is reconnecting after coming back from background.
class ConnectionStatusBanner extends StatefulWidget {
  final bool isReconnecting;

  const ConnectionStatusBanner({
    super.key,
    required this.isReconnecting,
  });

  @override
  State<ConnectionStatusBanner> createState() => _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState extends State<ConnectionStatusBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isReconnecting) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.warningColor.withValues(alpha: 0.15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.3, end: 1.0)
                .animate(_pulseController),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.warningColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Reconectando...',
            style: TextStyle(fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.warningColor,
            ),
          ),
        ],
      ),
    );
  }
}
