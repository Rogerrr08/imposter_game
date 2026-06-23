import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// CTA de ancho completo con padding vertical fijo (18), para eliminar los
/// valores ad-hoc (14/16/17/18) repartidos por la app. Cubre el primario
/// (relleno) y el secundario (`outlined`), con ícono opcional.
class FullWidthButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  final Color? color;

  const FullWidthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    );
    final pad = const EdgeInsets.symmetric(vertical: 18);

    if (outlined) {
      final c = color ?? AppTheme.primaryColor;
      return SizedBox(
        width: double.infinity,
        child: icon == null
            ? OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: c,
                  side: BorderSide(color: c.withValues(alpha: 0.45), width: 1.5),
                  padding: pad,
                ),
                child: text,
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: text,
                style: OutlinedButton.styleFrom(
                  foregroundColor: c,
                  side: BorderSide(color: c.withValues(alpha: 0.45), width: 1.5),
                  padding: pad,
                ),
              ),
      );
    }

    final style = ElevatedButton.styleFrom(
      backgroundColor: color,
      padding: pad,
    );
    return SizedBox(
      width: double.infinity,
      child: icon == null
          ? ElevatedButton(onPressed: onPressed, style: style, child: text)
          : ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: text,
              style: style,
            ),
    );
  }
}
