import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Foco neón radial detrás de una ilustración. Pensado para imágenes con fondo
/// transparente (p.ej. el logo): el resplandor "ilumina" el asset sin tocarlo.
/// No usarlo detrás de imágenes con fondo claro (el fondo tapa el glow).
class NeonSpotlight extends StatelessWidget {
  const NeonSpotlight({
    super.key,
    required this.child,
    this.color,
    this.size = 280,
    this.intensity = 1,
  });

  final Widget child;
  final Color? color;
  final double size;

  /// 0..1 — opacidad del foco (para animarlo o atenuarlo).
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primaryColor;
    return Stack(
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  c.withValues(alpha: 0.30 * intensity),
                  c.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
