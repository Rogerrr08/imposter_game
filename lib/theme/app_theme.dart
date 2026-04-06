import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Fiesta Sospechosa (light) ───
  static const _lightPrimary = Color(0xFF5B4CDB);
  static const _lightSecondary = Color(0xFFE63946);
  static const _lightBackground = Color(0xFFFFF8F0);
  static const _lightSurface = Color(0xFFFFEFDF);
  static const _lightCard = Color(0xFFFFFFFF);
  static const _lightSuccess = Color(0xFF2EC4B6);
  static const _lightWarning = Color(0xFFFFB627);
  static const _lightError = Color(0xFFD62828);
  static const _lightTextPrimary = Color(0xFF1A1A2E);
  static const _lightTextSecondary = Color(0xFF6B7280);

  // ─── Neon Undercover (dark) ───
  static const _darkPrimary = Color(0xFF00D1FF);
  static const _darkSecondary = Color(0xFFFF2D7B);
  static const _darkBackground = Color(0xFF0A0A12);
  static const _darkSurface = Color(0xFF12121E);
  static const _darkCard = Color(0xFF1A1A2E);
  static const _darkSuccess = Color(0xFF39FF8E);
  static const _darkWarning = Color(0xFFFFD166);
  static const _darkError = Color(0xFFFF6B8A);
  static const _darkTextPrimary = Color(0xFFEAEAFF);
  static const _darkTextSecondary = Color(0xFF7B7BA0);

  // ─── Panel colors per theme ───
  static const lightPanelColors = [
    Color(0xFF5B4CDB), // índigo
    Color(0xFFE63946), // rojo vivo
    Color(0xFF2EC4B6), // teal
  ];

  static const darkPanelColors = [
    Color(0xFF00D1FF), // cyan
    Color(0xFFA855F7), // violeta
    Color(0xFFFF2D7B), // magenta
  ];

  // ─── Runtime accessors (resolved via brightness) ───
  static Color primaryColor = _lightPrimary;
  static Color secondaryColor = _lightSecondary;
  static Color backgroundColor = _lightBackground;
  static Color surfaceColor = _lightSurface;
  static Color cardColor = _lightCard;
  static Color successColor = _lightSuccess;
  static Color warningColor = _lightWarning;
  static Color errorColor = _lightError;
  static Color textPrimary = _lightTextPrimary;
  static Color textSecondary = _lightTextSecondary;

  /// Call this when theme changes to update the static accessors.
  static void applyBrightness(bool isDark) {
    if (isDark) {
      primaryColor = _darkPrimary;
      secondaryColor = _darkSecondary;
      backgroundColor = _darkBackground;
      surfaceColor = _darkSurface;
      cardColor = _darkCard;
      successColor = _darkSuccess;
      warningColor = _darkWarning;
      errorColor = _darkError;
      textPrimary = _darkTextPrimary;
      textSecondary = _darkTextSecondary;
    } else {
      primaryColor = _lightPrimary;
      secondaryColor = _lightSecondary;
      backgroundColor = _lightBackground;
      surfaceColor = _lightSurface;
      cardColor = _lightCard;
      successColor = _lightSuccess;
      warningColor = _lightWarning;
      errorColor = _lightError;
      textPrimary = _lightTextPrimary;
      textSecondary = _lightTextSecondary;
    }
  }

  static List<Color> panelColors(bool isDark) =>
      isDark ? darkPanelColors : lightPanelColors;

  // ─── Light ThemeData ───
  static ThemeData get lightTheme => _buildTheme(
        brightness: Brightness.light,
        primary: _lightPrimary,
        secondary: _lightSecondary,
        background: _lightBackground,
        surface: _lightSurface,
        card: _lightCard,
        success: _lightSuccess,
        warning: _lightWarning,
        error: _lightError,
        textPrimary: _lightTextPrimary,
        textSecondary: _lightTextSecondary,
      );

  // ─── Dark ThemeData ───
  static ThemeData get darkTheme => _buildTheme(
        brightness: Brightness.dark,
        primary: _darkPrimary,
        secondary: _darkSecondary,
        background: _darkBackground,
        surface: _darkSurface,
        card: _darkCard,
        success: _darkSuccess,
        warning: _darkWarning,
        error: _darkError,
        textPrimary: _darkTextPrimary,
        textSecondary: _darkTextSecondary,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color secondary,
    required Color background,
    required Color surface,
    required Color card,
    required Color success,
    required Color warning,
    required Color error,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: primary,
            secondary: secondary,
            surface: surface,
            error: error,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: textPrimary,
            onError: Colors.white,
          )
        : ColorScheme.light(
            primary: primary,
            secondary: secondary,
            surface: surface,
            error: error,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: textPrimary,
            onError: Colors.white,
          );

    final baseTextTheme = isDark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      cardColor: card,
      canvasColor: surface,
      splashColor: primary.withValues(alpha: 0.12),
      highlightColor: Colors.transparent,
      dividerColor: textSecondary.withValues(alpha: 0.12),
      textTheme: GoogleFonts.nunitoTextTheme(baseTextTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: textPrimary,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surface,
          disabledForegroundColor: textSecondary.withValues(alpha: 0.45),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: textSecondary.withValues(alpha: 0.22)),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surface : card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: textSecondary.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: textSecondary.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: error, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.nunito(
          color: textSecondary.withValues(alpha: 0.55),
        ),
        labelStyle: GoogleFonts.nunito(
          color: textSecondary.withValues(alpha: 0.7),
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: textSecondary.withValues(alpha: 0.1)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? card : textPrimary,
        contentTextStyle: GoogleFonts.nunito(
          color: isDark ? textPrimary : background,
        ),
        actionTextColor: warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: surface,
        circularTrackColor: surface,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return textSecondary.withValues(alpha: 0.5);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.35);
          }
          return textSecondary.withValues(alpha: 0.18);
        }),
      ),
      iconTheme: IconThemeData(color: textPrimary),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        textStyle: GoogleFonts.nunito(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
