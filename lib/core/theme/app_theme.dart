import 'package:flutter/material.dart';

class AppColors {
  // ═══════════════════════════════════════════════════════════
  // MODE CLAIR
  // ═══════════════════════════════════════════════════════════
  static const Color primary = Color(0xFF1B4332);
  static const Color primaryLight = Color(0xFF2D6A4F);
  static const Color accent = Color(0xFFD8F3DC);

  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;

  static const Color textPrimary = Color(0xFF212529);
  static const Color textSecondary = Color(0xFF6C757D);

  static const Color success = Color(0xFF2A9D8F);
  static const Color danger = Color(0xFFE63946);
  static const Color warning = Color(0xFFF4A261);

  // ═══════════════════════════════════════════════════════════
  // MODE SOMBRE — One Dark VS Code
  // ═══════════════════════════════════════════════════════════
  // Fonds
  static const Color darkBackground = Color(0xFF1E2127); // Fond principal
  static const Color darkSurface = Color(0xFF282C34); // Cartes, surfaces
  static const Color darkElevated = Color(0xFF31363F); // Cartes élevées
  static const Color darkBorderColor = Color(0xFF3E4451); // Bordures subtiles

  // Textes
  static const Color darkTextPrimary = Color(0xFFABB2BF); // Texte principal
  static const Color darkTextSecondary = Color(0xFF7F848E); // Texte secondaire

  // Couleurs One Dark
  static const Color darkGreen = Color(0xFF98C379); // Vert (accent)
  static const Color darkBlue = Color(0xFF61AFEF); // Bleu
  static const Color darkRed = Color(0xFFE06C75); // Rouge
  static const Color darkOrange = Color(0xFFD19A66); // Orange
  static const Color darkYellow = Color(0xFFE5C07B); // Jaune
  static const Color darkPurple = Color(0xFFC678DD); // Violet
  static const Color darkCyan = Color(0xFF56B6C2); // Cyan

  // Alias pour compatibilité
  static const Color darkPrimary = darkGreen;
  static const Color darkAccent = Color(0xFF2D6A4F);
  static const Color darkSuccess = darkGreen;
  static const Color darkDanger = darkRed;
  static const Color darkWarning = darkOrange;

  // ═══════════════════════════════════════════════════════════
  // ⚡ COULEURS ADAPTATIVES
  // ═══════════════════════════════════════════════════════════

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Fond principal
  static Color bg(BuildContext context) =>
      isDark(context) ? darkBackground : background;

  /// Surface (cartes, containers)
  static Color card(BuildContext context) =>
      isDark(context) ? darkSurface : surface;

  /// Surface élevée (cartes importantes)
  static Color cardSecondary(BuildContext context) =>
      isDark(context) ? darkElevated : surface;

  /// Couleur principale (vert)
  static Color green(BuildContext context) =>
      isDark(context) ? darkGreen : primary;

  /// Vert clair pour les fonds
  static Color greenLight(BuildContext context) =>
      isDark(context) ? darkGreen.withOpacity(0.15) : accent;

  /// Texte principal
  static Color text(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  /// Texte secondaire
  static Color textSec(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  /// Bordure
  static Color border(BuildContext context) =>
      isDark(context) ? darkBorderColor : Colors.grey.shade200;

  /// Succès
  static Color successTheme(BuildContext context) =>
      isDark(context) ? darkGreen : success;

  /// Danger
  static Color dangerTheme(BuildContext context) =>
      isDark(context) ? darkRed : danger;

  /// Avertissement
  static Color warningTheme(BuildContext context) =>
      isDark(context) ? darkOrange : warning;

  /// Accent
  static Color accentTheme(BuildContext context) =>
      isDark(context) ? darkAccent : accent;

  /// Couleur de texte sur fond vert
  static Color onGreen(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E2127) : Colors.white;

  /// Couleur de texte secondaire sur fond vert
  static Color onGreenSec(BuildContext context) => isDark(context)
      ? const Color(0xFF1E2127).withOpacity(0.7)
      : Colors.white70;
}

class AppTheme {
  // ═══════════════════════════════════════════════════════════
  // THÈME CLAIR
  // ═══════════════════════════════════════════════════════════
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // THÈME SOMBRE — One Dark VS Code
  // ═══════════════════════════════════════════════════════════
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.darkGreen,
        primary: AppColors.darkGreen,
        onPrimary: AppColors.darkBackground,
        secondary: AppColors.darkBlue,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        surfaceContainerHighest: AppColors.darkElevated,
        outline: AppColors.darkBorderColor,
        error: AppColors.darkRed,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkGreen,
          foregroundColor: AppColors.darkBackground,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkGreen,
          side: const BorderSide(color: AppColors.darkGreen),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkGreen, width: 2),
        ),
        hintStyle: const TextStyle(color: AppColors.darkTextSecondary),
        labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
      ),
      cardTheme: CardTheme(
        color: AppColors.darkElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorderColor),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.darkGreen,
        unselectedItemColor: AppColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorderColor,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.darkTextPrimary),
        bodyMedium: TextStyle(color: AppColors.darkTextPrimary),
        bodySmall: TextStyle(color: AppColors.darkTextSecondary),
        titleLarge: TextStyle(color: AppColors.darkTextPrimary),
        titleMedium: TextStyle(color: AppColors.darkTextPrimary),
        titleSmall: TextStyle(color: AppColors.darkTextPrimary),
      ),
    );
  }
}
