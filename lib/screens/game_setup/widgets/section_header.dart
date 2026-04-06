import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
