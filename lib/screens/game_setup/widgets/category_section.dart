import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../data/word_bank.dart';
import '../../../theme/app_theme.dart';
import 'section_header.dart';

class CategorySection extends StatelessWidget {
  final Set<WordCategory> selectedCategories;
  final ValueChanged<WordCategory> onToggle;
  final VoidCallback onSelectAll;

  const CategorySection({
    super.key,
    required this.selectedCategories,
    required this.onToggle,
    required this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    final allSelected =
        selectedCategories.length == WordCategory.values.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          icon: Icons.category_rounded,
          title: 'Categorías (aleatorio)',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: WordCategory.values.map((category) {
            final isSelected = selectedCategories.contains(category);

            return FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(category.icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(category.displayName),
                ],
              ),
              labelStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color:
                    isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
              backgroundColor: AppTheme.cardColor,
              selectedColor: AppTheme.primaryColor.withValues(alpha: 0.25),
              checkmarkColor: AppTheme.primaryColor,
              side: BorderSide(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary.withValues(alpha: 0.1),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onSelected: (_) => onToggle(category),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: allSelected ? null : onSelectAll,
          child: Text(
            allSelected ? 'Todas seleccionadas' : 'Seleccionar todas',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color:
                  allSelected ? AppTheme.textSecondary : AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
