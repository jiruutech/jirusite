import 'package:flutter/material.dart';

/// JIRUSite Design Token System — Construction site materials palette
class AppColors {
  // ── Core palette ──────────────────────────────────────────────────────────
  static const blueprintInk = Color(0xFF16303D);
  static const chalk = Color(0xFFEFEDE6);
  static const concrete = Color(0xFFB7B3A9);
  static const safetyOrange = Color(0xFFE8720C);
  static const rebarRust = Color(0xFF8A4A2E);
  static const levelGreen = Color(0xFF3C7A54);
  static const ochreDust = Color(0xFFC9A227);

  // ── Semantic aliases (backward compat) ───────────────────────────────────
  static const primary = blueprintInk;
  static const secondary = safetyOrange;
  static const background = chalk;
  static const divider = concrete;
  static const success = levelGreen;
  static const warning = ochreDust;
  static const error = rebarRust;
  static const textPrimary = blueprintInk;
  static const textSecondary = Color(0xFF4A5C63);
  static const surface = Color(0xFFF5F3EE);

  // ── Budget health ─────────────────────────────────────────────────────────
  static const budgetGood = levelGreen;
  static const budgetWarning = ochreDust;
  static const budgetDanger = rebarRust;

  // ── Sync status ───────────────────────────────────────────────────────────
  static const syncPending = ochreDust;
  static const syncSynced = levelGreen;
  static const syncConflict = rebarRust;

  // ── Misc ──────────────────────────────────────────────────────────────────
  static const onPrimary = chalk;
  static const primaryLight = Color(0xFF2A4A5A);
}

/// JIRUSite type scale — matches design brief
class AppTextStyles {
  static const display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );
  static const heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const subhead = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(
    fontSize: 15,
    color: AppColors.textPrimary,
  );
  static const caption = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );
  static const micro = TextStyle(
    fontSize: 11,
    color: AppColors.textSecondary,
  );

  /// IBM Plex Mono style for financial/numeric data
  static const numeric = TextStyle(
    fontSize: 15,
    fontFamily: 'monospace',
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w600,
  );
}

class AppTheme {
  static const double _cardRadius = 5.0;
  static const double _inputRadius = 4.0;
  static const double _buttonRadius = 5.0;

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.blueprintInk,
          onPrimary: AppColors.chalk,
          secondary: AppColors.safetyOrange,
          onSecondary: AppColors.chalk,
          error: AppColors.rebarRust,
          onError: AppColors.chalk,
          surface: AppColors.surface,
          onSurface: AppColors.blueprintInk,
          surfaceContainerHighest: AppColors.chalk,
          outline: AppColors.concrete,
        ),
        scaffoldBackgroundColor: AppColors.chalk,

        // ── App bar ─────────────────────────────────────────────────────────
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.blueprintInk,
          foregroundColor: AppColors.chalk,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppColors.chalk,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          iconTheme: IconThemeData(color: AppColors.chalk),
          actionsIconTheme: IconThemeData(color: AppColors.chalk),
        ),

        // ── Cards ────────────────────────────────────────────────────────────
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_cardRadius)),
          color: AppColors.surface,
          margin: const EdgeInsets.only(bottom: 8),
        ),

        // ── Bottom navigation ────────────────────────────────────────────────
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.chalk,
          selectedItemColor: AppColors.safetyOrange,
          unselectedItemColor: AppColors.blueprintInk,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.chalk,
          indicatorColor: AppColors.safetyOrange.withValues(alpha: 0.15),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.safetyOrange);
            }
            return const IconThemeData(color: AppColors.blueprintInk);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.safetyOrange);
            }
            return const TextStyle(
                fontSize: 12, color: AppColors.blueprintInk);
          }),
          elevation: 8,
        ),

        // ── FAB ──────────────────────────────────────────────────────────────
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.safetyOrange,
          foregroundColor: AppColors.chalk,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(_buttonRadius))),
        ),

        // ── Input fields ─────────────────────────────────────────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
            borderSide: const BorderSide(color: AppColors.concrete),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
            borderSide: const BorderSide(color: AppColors.concrete),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
            borderSide:
                const BorderSide(color: AppColors.blueprintInk, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
            borderSide: const BorderSide(color: AppColors.rebarRust),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
            borderSide:
                const BorderSide(color: AppColors.rebarRust, width: 1.5),
          ),
          labelStyle: const TextStyle(
              fontSize: 14, color: AppColors.textSecondary),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),

        // ── Buttons ──────────────────────────────────────────────────────────
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blueprintInk,
            foregroundColor: AppColors.chalk,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_buttonRadius)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.blueprintInk,
            minimumSize: const Size(double.infinity, 50),
            side: const BorderSide(color: AppColors.blueprintInk),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_buttonRadius)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.safetyOrange,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_buttonRadius)),
          ),
        ),

        // ── Chips ────────────────────────────────────────────────────────────
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_buttonRadius)),
          selectedColor: AppColors.blueprintInk.withValues(alpha: 0.12),
          backgroundColor: AppColors.chalk,
          side: const BorderSide(color: AppColors.concrete),
          labelStyle: const TextStyle(
              fontSize: 13, color: AppColors.textPrimary),
        ),

        // ── Divider ──────────────────────────────────────────────────────────
        dividerTheme: const DividerThemeData(
            color: AppColors.concrete, space: 1, thickness: 1),

        // ── Text theme ───────────────────────────────────────────────────────
        textTheme: const TextTheme(
          // Display 28
          headlineLarge: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.5),
          // Heading 22
          headlineMedium: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
          // Subhead 18
          titleLarge: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
          // UI 16
          titleMedium: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary),
          titleSmall: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary),
          // Body 15
          bodyLarge: TextStyle(fontSize: 15, color: AppColors.textPrimary),
          bodyMedium: TextStyle(fontSize: 15, color: AppColors.textPrimary),
          // Caption 13
          bodySmall: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          labelLarge: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
          // Micro 11
          labelSmall: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),

        // ── Snack bar ────────────────────────────────────────────────────────
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.blueprintInk,
          contentTextStyle:
              const TextStyle(color: AppColors.chalk, fontSize: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_cardRadius)),
          behavior: SnackBarBehavior.floating,
        ),

        // ── Dialog ───────────────────────────────────────────────────────────
        dialogTheme: const DialogThemeData(
          backgroundColor: AppColors.chalk,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(6))),
          titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),

        // ── Progress indicator ───────────────────────────────────────────────
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.safetyOrange,
          linearTrackColor: AppColors.concrete,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: AppColors.safetyOrange,
          onPrimary: AppColors.chalk,
          secondary: AppColors.ochreDust,
          onSecondary: AppColors.blueprintInk,
          error: AppColors.rebarRust,
          onError: AppColors.chalk,
          surface: Color(0xFF1E2E36),
          onSurface: AppColors.chalk,
          surfaceContainerHighest: Color(0xFF16303D),
          outline: Color(0xFF4A5C63),
        ),
        scaffoldBackgroundColor: const Color(0xFF0E1F28),
      );
}
