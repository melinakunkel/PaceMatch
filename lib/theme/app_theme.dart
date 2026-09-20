import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeVariant {
  standard,
  girly,
  sporty;

  String get label {
    switch (this) {
      case AppThemeVariant.standard:
        return 'Standard';
      case AppThemeVariant.girly:
        return 'Girly';
      case AppThemeVariant.sporty:
        return 'Sporty';
    }
  }

  String get description {
    switch (this) {
      case AppThemeVariant.standard:
        return 'Das klassische SAMEPACE-Grün.';
      case AppThemeVariant.girly:
        return 'Soft, verspielt, in Beerentönen.';
      case AppThemeVariant.sporty:
        return 'Bold & kontrastreich – für Triathlet:innen.';
    }
  }

  _Palette get _palette {
    switch (this) {
      case AppThemeVariant.standard:
        return const _Palette(
          primary: Color(0xFF1B4332),
          secondary: Color(0xFF40916C),
          secondaryLight: Color(0xFFD8F3DC),
          background: Color(0xFFF8F6F1),
          surface: Colors.white,
          textPrimary: Color(0xFF1B2E28),
          textSecondary: Color(0xFF6B7A75),
          border: Color(0xFFE5E1D8),
          danger: Color(0xFFD64545),
        );
      case AppThemeVariant.girly:
        return const _Palette(
          primary: Color(0xFF9D2953),
          secondary: Color(0xFFE85D8A),
          secondaryLight: Color(0xFFFCE4EC),
          background: Color(0xFFFFF5F7),
          surface: Colors.white,
          textPrimary: Color(0xFF4A2C3A),
          textSecondary: Color(0xFF8C6B7A),
          border: Color(0xFFF3D9E3),
          danger: Color(0xFFE5335F),
        );
      case AppThemeVariant.sporty:
        return const _Palette(
          primary: Color(0xFF14181F),
          secondary: Color(0xFFFF6B35),
          secondaryLight: Color(0xFFFFE4D6),
          background: Color(0xFFF3F4F6),
          surface: Colors.white,
          textPrimary: Color(0xFF14181F),
          textSecondary: Color(0xFF6B7280),
          border: Color(0xFFE1E3E8),
          danger: Color(0xFFE53935),
        );
    }
  }
}

class _Palette {
  const _Palette({
    required this.primary,
    required this.secondary,
    required this.secondaryLight,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.danger,
  });

  final Color primary;
  final Color secondary;
  final Color secondaryLight;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color danger;
}

/// Currently active palette. Not `const` on purpose — [ThemeController]
/// reassigns these fields when the user picks a different design, and
/// every widget that reads them (almost the whole app) rebuilds because
/// that switch also bumps [ThemeController.variant], a ValueNotifier the
/// root widget listens to.
class AppColors {
  AppColors._();

  static Color primary = AppThemeVariant.standard._palette.primary;
  static Color secondary = AppThemeVariant.standard._palette.secondary;
  static Color secondaryLight =
      AppThemeVariant.standard._palette.secondaryLight;
  static Color background = AppThemeVariant.standard._palette.background;
  static Color surface = AppThemeVariant.standard._palette.surface;
  static Color textPrimary = AppThemeVariant.standard._palette.textPrimary;
  static Color textSecondary = AppThemeVariant.standard._palette.textSecondary;
  static Color border = AppThemeVariant.standard._palette.border;
  static Color danger = AppThemeVariant.standard._palette.danger;

  static void _applyVariant(AppThemeVariant variant) {
    final p = variant._palette;
    primary = p.primary;
    secondary = p.secondary;
    secondaryLight = p.secondaryLight;
    background = p.background;
    surface = p.surface;
    textPrimary = p.textPrimary;
    textSecondary = p.textSecondary;
    border = p.border;
    danger = p.danger;
  }
}

/// Holds the active design and persists the user's choice. The root widget
/// listens to [variant] and rebuilds the whole app when it changes.
class ThemeController {
  ThemeController._();

  static const _prefsKey = 'theme_variant';
  static final ValueNotifier<AppThemeVariant> variant = ValueNotifier(
    AppThemeVariant.standard,
  );

  static Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    for (final v in AppThemeVariant.values) {
      if (v.name == saved) {
        AppColors._applyVariant(v);
        variant.value = v;
        break;
      }
    }
  }

  static Future<void> setVariant(AppThemeVariant v) async {
    AppColors._applyVariant(v);
    variant.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, v.name);
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.secondary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.secondary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.secondaryLight,
        labelStyle: TextStyle(color: AppColors.primary),
        side: BorderSide.none,
      ),
    );
  }
}
