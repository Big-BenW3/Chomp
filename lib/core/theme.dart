/// Chomp design system.
///
/// Tokens, motion curves and full component theming — both the light
/// and dark palettes are built from one `_build(Brightness)` pass, so
/// a token change lands in both themes simultaneously.
///
/// Dark-first brand: near-black surfaces with a faint magenta cast,
/// `#FF2D87` accent, Space Grotesk for display/numbers, Plus Jakarta
/// Sans for body. Custom widgets should pull colors from `ColorScheme`
/// or the `AppTokens` extension — never hardcode hex values outside
/// this file, or light mode breaks.
///
/// Motion philosophy: everything moves on the `appCurve` spring and
/// only `transform`/`opacity` are ever animated — no layout thrash.

library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';

/// Brand + semantic palette. Kept as raw hex; surfaces stay exact so
/// both themes feel machined rather than seed-generated.
abstract final class AppColors {
  /// Brand magenta.
  static const Color brand = Color(0xFFFF2D87);

  /// Dark theme — OLED-adjacent with a magenta undertone.
  static const Color darkBg = Color(0xFF0E0B12);
  static const Color darkSurface = Color(0xFF16121C);
  static const Color darkSurfaceHigh = Color(0xFF1E1826);
  static const Color darkHairline = Color(0x1FFFFFFF); // white 12%

  /// Light theme — paper white.
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF7F5F9);
  static const Color lightSurfaceHigh = Color(0xFFFFFFFF);
  static const Color lightHairline = Color(0x0F000000); // black 6%

  /// Semantic status colors.
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF5A623);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF5B8DEF);
}

/// Motion language. One spring-ish curve everywhere, three durations.
abstract final class AppMotion {
  /// `cubic-bezier(0.32, 0.72, 0, 1)` — fast attack, long settle. Feels
  /// like mass snapping to rest rather than a tween.
  static const Curve curve = Cubic(0.32, 0.72, 0, 1);
  static const Duration micro = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 360);
  static const Duration expressive = Duration(milliseconds: 720);
}

/// Radius scale. `shell > card` so nested enclosures stay concentric.
abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double card = 20;
  static const double shell = 24;
  static const double pill = 999;
}

/// Builds the complete [ThemeData] for a brightness.
ThemeData _build(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
  final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
  final surfaceHigh =
      isDark ? AppColors.darkSurfaceHigh : AppColors.lightSurfaceHigh;
  final hairline = isDark ? AppColors.darkHairline : AppColors.lightHairline;
  final onSurface = isDark ? Colors.white : Colors.black;

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: AppColors.brand,
    onPrimary: Colors.white,
    primaryContainer: AppColors.brand.withValues(alpha: 0.14),
    onPrimaryContainer: AppColors.brand,
    secondary: AppColors.brand,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.brand.withValues(alpha: 0.14),
    onSecondaryContainer: AppColors.brand,
    error: AppColors.danger,
    onError: Colors.white,
    errorContainer: AppColors.danger.withValues(alpha: 0.14),
    onErrorContainer: AppColors.danger,
    surface: bg,
    onSurface: onSurface,
    surfaceContainerLowest: bg,
    surfaceContainerLow: surface,
    surfaceContainer: surface,
    surfaceContainerHigh: surfaceHigh,
    surfaceContainerHighest: surfaceHigh,
    onSurfaceVariant: onSurface.withValues(alpha: 0.6),
    outline: hairline,
    outlineVariant: hairline,
    inverseSurface: isDark ? Colors.white : Colors.black,
    onInverseSurface: isDark ? AppColors.darkBg : Colors.white,
    shadow: isDark ? Colors.black : AppColors.brand.withValues(alpha: 0.08),
    scrim: Colors.black.withValues(alpha: 0.6),
  );

  const display = GoogleFonts.spaceGrotesk;
  const body = GoogleFonts.plusJakartaSans;

  final textTheme = TextTheme(
    displayLarge: display(
        fontSize: 40,
        height: 1.05,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5),
    displayMedium: display(
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -1),
    headlineMedium: display(
        fontSize: 24,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5),
    headlineSmall: display(
        fontSize: 20,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3),
    titleLarge:
        display(fontSize: 18, height: 1.25, fontWeight: FontWeight.w600),
    titleMedium: body(fontSize: 15, height: 1.3, fontWeight: FontWeight.w600),
    bodyLarge: body(fontSize: 16, height: 1.45, fontWeight: FontWeight.w400),
    bodyMedium: body(fontSize: 14, height: 1.4, fontWeight: FontWeight.w400),
    bodySmall: body(fontSize: 12, height: 1.35, fontWeight: FontWeight.w400),
    labelLarge: body(fontSize: 14, height: 1.2, fontWeight: FontWeight.w600),
    labelMedium: body(fontSize: 12, height: 1.2, fontWeight: FontWeight.w600),
    labelSmall: body(
        fontSize: 10,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4),
  ).apply(bodyColor: onSurface, displayColor: onSurface);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    splashFactory: InkSparkle.splashFactory,
    textTheme: textTheme,
    extensions: [
      AppTokens(surface: surface, surfaceHigh: surfaceHigh, hairline: hairline),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: display(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: onSurface),
      iconTheme: IconThemeData(color: onSurface.withValues(alpha: 0.7)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: surfaceHigh,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.brand.withValues(alpha: 0.16),
      indicatorShape: const StadiumBorder(),
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return body(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.2,
            color: selected ? onSurface : onSurface.withValues(alpha: 0.55));
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
            color:
                selected ? AppColors.brand : onSurface.withValues(alpha: 0.45));
      }),
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: hairline)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: body(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
          foregroundColor: onSurface.withValues(alpha: 0.7)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? Colors.white
              : onSurface.withValues(alpha: 0.6)),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.brand
              : onSurface.withValues(alpha: 0.12)),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      trackOutlineWidth: const WidgetStatePropertyAll(0),
    ),
    dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? surfaceHigh : Colors.black,
      contentTextStyle:
          body(fontSize: 14, color: isDark ? Colors.white : Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
      elevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.shell))),
      showDragHandle: true,
      dragHandleColor: onSurface.withValues(alpha: 0.2),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.shell)),
      titleTextStyle: display(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: onSurface),
      contentTextStyle: body(
          fontSize: 14, height: 1.4, color: onSurface.withValues(alpha: 0.7)),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.brand),
  );
}

/// Extra design tokens not covered by [ColorScheme], readable via
/// `Theme.of(context).extension<AppTokens>()`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens(
      {required this.surface,
      required this.surfaceHigh,
      required this.hairline});

  final Color surface;
  final Color surfaceHigh;
  final Color hairline;

  @override
  AppTokens copyWith({Color? surface, Color? surfaceHigh, Color? hairline}) =>
      AppTokens(
        surface: surface ?? this.surface,
        surfaceHigh: surfaceHigh ?? this.surfaceHigh,
        hairline: hairline ?? this.hairline,
      );

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
    );
  }
}

/// Root entry point for the app's themes.
abstract final class AppTheme {
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  /// Maps a persisted preference to a concrete [ThemeData].
  static ThemeData forMode(ThemeModePref mode) =>
      mode == ThemeModePref.light ? light() : dark();
}
