import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

/// Displays a player's avatar: network image if available, or initial letter.
class PlayerAvatar extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;

  const PlayerAvatar({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.size = 48,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppTheme.primaryColor.withValues(alpha: 0.12);
    final fgColor = textColor ?? AppTheme.primaryColor;
    final initial = displayName.characters.first.toUpperCase();
    final fontSize = size * 0.38;

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      // Decode al tamaño del slot (en píxeles físicos), no a la resolución
      // original 256x256. Con 8 jugadores visibles ahorra 4-6 MB de RAM.
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final cacheSide = (size * dpr).round();
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: avatarUrl!,
            width: size,
            height: size,
            memCacheWidth: cacheSide,
            memCacheHeight: cacheSide,
            fit: BoxFit.cover,
            placeholder: (_, __) => _InitialCircle(
              initial: initial,
              size: size,
              fontSize: fontSize,
              bgColor: bgColor,
              fgColor: fgColor,
            ),
            errorWidget: (_, __, ___) => _InitialCircle(
              initial: initial,
              size: size,
              fontSize: fontSize,
              bgColor: bgColor,
              fgColor: fgColor,
            ),
          ),
        ),
      );
    }

    return _InitialCircle(
      initial: initial,
      size: size,
      fontSize: fontSize,
      bgColor: bgColor,
      fgColor: fgColor,
    );
  }
}

class _InitialCircle extends StatelessWidget {
  final String initial;
  final double size;
  final double fontSize;
  final Color bgColor;
  final Color fgColor;

  const _InitialCircle({
    required this.initial,
    required this.size,
    required this.fontSize,
    required this.bgColor,
    required this.fgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: fgColor,
          ),
        ),
      ),
    );
  }
}
