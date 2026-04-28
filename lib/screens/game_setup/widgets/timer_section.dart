import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import 'section_header.dart';

class TimerSection extends StatelessWidget {
  final int durationSeconds;
  final ValueChanged<int> onDurationChanged;

  const TimerSection({
    super.key,
    required this.durationSeconds,
    required this.onDurationChanged,
  });

  static const List<int> _presetDurations = [60, 120, 180, 300, 600, 900];
  static const List<String> _presetLabels = [
    '1 min',
    '2 min',
    '3 min',
    '5 min',
    '10 min',
    '15 min',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.timer_rounded,
          title: 'Duraci\u00F3n: ${_formatDuration(durationSeconds)}',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _presetDurations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final duration = _presetDurations[index];
              final isSelected = durationSeconds == duration;

              return GestureDetector(
                onTap: () => onDurationChanged(duration),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondary.withValues(alpha: 0.1),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      _presetLabels[index],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.primaryColor,
            inactiveTrackColor: AppTheme.surfaceColor,
            thumbColor: AppTheme.primaryColor,
            overlayColor: AppTheme.primaryColor.withValues(alpha: 0.15),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: durationSeconds.toDouble(),
            min: 60,
            max: 900,
            divisions: 84,
            onChanged: (value) => onDurationChanged(value.round()),
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) {
      return '$minutes min';
    }
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')} min';
  }
}
