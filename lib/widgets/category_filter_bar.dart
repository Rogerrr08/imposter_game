import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

const categoryLabels = <String?, String>{
  null: 'Todas',
  'cosas': 'Cosas',
  'comidas': 'Comidas',
  'animales': 'Animales',
  'entretenimiento': 'Entretenimiento',
  'geografia': 'Geograf\u00eda',
  'deportes': 'Deportes',
};

class CategoryFilterBar extends StatelessWidget {
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;

  const CategoryFilterBar({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: categoryLabels.entries.map((entry) {
          final isSelected = selectedCategory == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(
                entry.value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              backgroundColor: AppTheme.cardColor,
              selectedColor: AppTheme.primaryColor,
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary.withValues(alpha: 0.2),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onSelected: (_) => onCategorySelected(entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }
}
