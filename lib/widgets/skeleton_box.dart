import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Placeholder de carga con pulso suave. Se usa para "skeleton screens":
/// mostrar la silueta del contenido mientras llega, en vez de un spinner.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.height = 16,
    this.width,
    this.radius = AppTheme.r12,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Pulso de opacidad entre ~0.05 y ~0.16.
        final alpha = 0.05 + 0.11 * _controller.value;
        return Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppTheme.textSecondary.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}
