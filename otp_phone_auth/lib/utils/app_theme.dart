import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.deepNavy,
        secondary: AppColors.safetyOrange,
        surface: AppColors.cleanWhite,
        error: AppColors.statusOverdue,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.lightSlate,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.deepNavy,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: AppColors.deepNavy,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.borderColor, width: 0.5),
        ),
        color: AppColors.cleanWhite,
        shadowColor: AppColors.deepNavy.withValues(alpha: 0.08),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          backgroundColor: AppColors.deepNavy,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.deepNavy,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          side: const BorderSide(color: AppColors.deepNavy, width: 1.5),
          foregroundColor: AppColors.deepNavy,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          foregroundColor: AppColors.deepNavy,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textHint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.deepNavy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.statusOverdue),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(
            color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textSecondary),
        bodySmall: TextStyle(color: AppColors.textTertiary),
        labelLarge:
            TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: AppColors.textSecondary),
        labelSmall: TextStyle(color: AppColors.textTertiary),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerColor,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSlate,
        selectedColor: AppColors.deepNavy.withValues(alpha: 0.1),
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        side: const BorderSide(color: AppColors.borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.deepNavy,
        unselectedItemColor: AppColors.textTertiary,
        elevation: 8,
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.safetyOrange,
        textColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.safetyOrange,
      ),
    );
  }

  /// A genuinely dark theme — this used to just return [lightTheme], which
  /// meant the dark-mode toggle in Settings was wired up but changed
  /// nothing on screen. Screens that read colors from `Theme.of(context)`
  /// (via Scaffold/AppBar/Card/Input defaults, `CommonWidgets`, etc.) now
  /// respond correctly. Screens that hardcode `AppColors.X` literals
  /// directly instead of going through the theme still won't — that's a
  /// separate, much larger migration (see the CommonWidgets-adoption note
  /// in the audit) than what's safe to do in a theme-definition change.
  static ThemeData get darkTheme {
    const darkSurface = Color(0xFF16202E);
    const darkBackground = Color(0xFF0F1720);
    const darkCard = Color(0xFF1C2836);
    const darkBorder = Color(0xFF2C3A4C);
    const darkTextPrimary = Color(0xFFE9EDF2);
    const darkTextSecondary = Color(0xFFAAB4C0);
    const darkTextTertiary = Color(0xFF7C8794);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.deepNavyLight,
        secondary: AppColors.safetyOrangeLight,
        surface: darkSurface,
        error: const Color(0xFFE57373),
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: darkTextPrimary,
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: darkSurface,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: darkBackground,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: darkBorder, width: 0.5),
        ),
        color: darkCard,
        shadowColor: Colors.black.withValues(alpha: 0.4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          backgroundColor: AppColors.deepNavyLight,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.deepNavyLight,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          side: const BorderSide(color: AppColors.deepNavyLight, width: 1.5),
          foregroundColor: AppColors.deepNavyLight,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          foregroundColor: AppColors.deepNavyLight,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: darkTextSecondary),
        hintStyle: const TextStyle(color: darkTextTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.deepNavyLight, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          borderSide: BorderSide(color: Color(0xFFE57373)),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: darkTextSecondary, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: darkTextPrimary),
        bodyMedium: TextStyle(color: darkTextSecondary),
        bodySmall: TextStyle(color: darkTextTertiary),
        labelLarge: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: darkTextSecondary),
        labelSmall: TextStyle(color: darkTextTertiary),
      ),
      iconTheme: const IconThemeData(color: darkTextSecondary),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkCard,
        selectedColor: AppColors.deepNavyLight.withValues(alpha: 0.25),
        labelStyle: const TextStyle(color: darkTextPrimary),
        side: const BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: AppColors.deepNavyLight,
        unselectedItemColor: darkTextTertiary,
        elevation: 8,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: AppColors.safetyOrangeLight,
        textColor: Colors.black,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.safetyOrangeLight,
      ),
    );
  }
}
