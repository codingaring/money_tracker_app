// Material 3 theme — Hot pink + cyan accent, white surfaces, large rounded
// shapes, Pretendard typography. Inspired by the Budget Tracker UI kit
// reference (`docs/.claude/money-tracker-reference1.png` 톤).
//
// 디자인 토큰:
//   primary   = #FF1F6E (hot pink)  — FAB, active pill, expense indicator, line chart
//   tertiary  = #13C2F0 (cyan)      — income indicator, secondary highlights
//   surface   = #FFFFFF              — cards, scaffold body
//   onSurface = #1A1B1F              — body text
//   outlineV  = #ECECEE              — soft hairline borders

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppPalette {
  const AppPalette._();

  static const Color pink = Color(0xFFFF1F6E);
  static const Color pinkSoft = Color(0xFFFFE3EC);
  static const Color cyan = Color(0xFF13C2F0);
  static const Color cyanSoft = Color(0xFFD8F3FB);
  static const Color ink = Color(0xFF1A1B1F);
  static const Color inkMuted = Color(0xFF6B6B72);
  static const Color hairline = Color(0xFFECECEE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF6F6F8);
}

class AppRadii {
  const AppRadii._();

  static const double card = 24;
  static const double field = 16;
  static const double button = 16;
  static const double pill = 999;
}

class AppTheme {
  const AppTheme._();

  static const String _fontFamily = 'SUIT';

  static ThemeData light() => _build(_lightScheme(), Brightness.light);

  static ThemeData dark() => _build(_darkScheme(), Brightness.dark);

  // ── Color schemes ──────────────────────────────────────────────────────────

  static ColorScheme _lightScheme() {
    return ColorScheme.fromSeed(
      seedColor: AppPalette.pink,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppPalette.pink,
      onPrimary: Colors.white,
      primaryContainer: AppPalette.pinkSoft,
      onPrimaryContainer: const Color(0xFF690022),
      tertiary: AppPalette.cyan,
      onTertiary: Colors.white,
      tertiaryContainer: AppPalette.cyanSoft,
      onTertiaryContainer: const Color(0xFF003848),
      surface: AppPalette.surface,
      onSurface: AppPalette.ink,
      surfaceContainerLowest: AppPalette.surface,
      surfaceContainerLow: const Color(0xFFFAFAFC),
      surfaceContainer: const Color(0xFFF6F6F8),
      surfaceContainerHigh: const Color(0xFFF1F1F4),
      surfaceContainerHighest: const Color(0xFFEBEBEF),
      onSurfaceVariant: AppPalette.inkMuted,
      outline: const Color(0xFFD9D9DD),
      outlineVariant: AppPalette.hairline,
    );
  }

  static ColorScheme _darkScheme() {
    return ColorScheme.fromSeed(
      seedColor: AppPalette.pink,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppPalette.pink,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF690022),
      onPrimaryContainer: AppPalette.pinkSoft,
      tertiary: AppPalette.cyan,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFF003848),
      onTertiaryContainer: AppPalette.cyanSoft,
    );
  }

  // ── Typography ─────────────────────────────────────────────────────────────

  static TextTheme _textTheme(ColorScheme scheme) {
    final base = scheme.brightness == Brightness.light
        ? Typography.blackMountainView
        : Typography.whiteMountainView;
    return base
        .apply(
          fontFamily: _fontFamily,
          fontFamilyFallback: const [
            'Pretendard',
            'NotoSansKR',
            'Roboto',
            'sans-serif',
          ],
        )
        .copyWith(
          displayLarge: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 56,
            height: 1.05,
            letterSpacing: -1.5,
            color: scheme.onSurface,
          ),
          displayMedium: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 44,
            height: 1.1,
            letterSpacing: -1.0,
            color: scheme.onSurface,
          ),
          displaySmall: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 34,
            height: 1.15,
            letterSpacing: -0.5,
            color: scheme.onSurface,
          ),
          headlineLarge: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 28,
            color: scheme.onSurface,
          ),
          headlineMedium: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: scheme.onSurface,
          ),
          headlineSmall: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: scheme.onSurface,
          ),
          titleLarge: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: scheme.onSurface,
          ),
          titleMedium: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: scheme.onSurface,
          ),
          titleSmall: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: scheme.onSurface,
          ),
          bodyLarge: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 16,
            color: scheme.onSurface,
          ),
          bodyMedium: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: scheme.onSurface,
          ),
          bodySmall: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          ),
          labelLarge: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.1,
            color: scheme.onSurface,
          ),
          labelMedium: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          ),
          labelSmall: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w500,
            fontSize: 11,
            color: scheme.onSurfaceVariant,
          ),
        );
  }

  // ── ThemeData composition ──────────────────────────────────────────────────

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final textTheme = _textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: _fontFamily,
      textTheme: textTheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),

      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          textStyle: textTheme.labelLarge,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          side: BorderSide(color: scheme.outline),
          foregroundColor: scheme.onSurface,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        focusElevation: 4,
        hoverElevation: 4,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: scheme.primary,
        secondarySelectedColor: scheme.primary,
        disabledColor: scheme.surfaceContainerLow,
        labelStyle: textTheme.labelLarge?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: scheme.onPrimary),
        side: BorderSide(color: scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: textTheme.bodySmall,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        height: 64,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            );
          }
          return textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.primary, size: 24);
          }
          return IconThemeData(color: scheme.onSurfaceVariant, size: 24);
        }),
      ),

      bottomAppBarTheme: BottomAppBarThemeData(
        color: scheme.surface,
        elevation: 0,
        height: 72,
        padding: EdgeInsets.zero,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHigh;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainer,
        circularTrackColor: scheme.surfaceContainer,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
        backgroundColor: scheme.onSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.surface),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
    );
  }
}
