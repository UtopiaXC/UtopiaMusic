import 'package:flutter/material.dart';

/// Theme extension providing optical styling tokens for Liquid Glass surfaces.
@immutable
class LiquidGlassThemeExtension
    extends ThemeExtension<LiquidGlassThemeExtension> {
  final bool enabled;
  final Color glassTint;
  final Color glassSecondaryTint;
  final Color borderColor;
  final Color highlightColor;
  final double blurSigma;

  const LiquidGlassThemeExtension({
    required this.enabled,
    required this.glassTint,
    required this.glassSecondaryTint,
    required this.borderColor,
    required this.highlightColor,
    this.blurSigma = 24.0,
  });

  static const LiquidGlassThemeExtension disabled = LiquidGlassThemeExtension(
    enabled: false,
    glassTint: Colors.transparent,
    glassSecondaryTint: Colors.transparent,
    borderColor: Colors.transparent,
    highlightColor: Colors.transparent,
    blurSigma: 0.0,
  );

  @override
  LiquidGlassThemeExtension copyWith({
    bool? enabled,
    Color? glassTint,
    Color? glassSecondaryTint,
    Color? borderColor,
    Color? highlightColor,
    double? blurSigma,
  }) {
    return LiquidGlassThemeExtension(
      enabled: enabled ?? this.enabled,
      glassTint: glassTint ?? this.glassTint,
      glassSecondaryTint: glassSecondaryTint ?? this.glassSecondaryTint,
      borderColor: borderColor ?? this.borderColor,
      highlightColor: highlightColor ?? this.highlightColor,
      blurSigma: blurSigma ?? this.blurSigma,
    );
  }

  @override
  LiquidGlassThemeExtension lerp(
    covariant ThemeExtension<LiquidGlassThemeExtension>? other,
    double t,
  ) {
    if (other is! LiquidGlassThemeExtension) return this;
    return LiquidGlassThemeExtension(
      enabled: t < 0.5 ? enabled : other.enabled,
      glassTint: Color.lerp(glassTint, other.glassTint, t) ?? glassTint,
      glassSecondaryTint:
          Color.lerp(glassSecondaryTint, other.glassSecondaryTint, t) ??
          glassSecondaryTint,
      borderColor: Color.lerp(borderColor, other.borderColor, t) ?? borderColor,
      highlightColor:
          Color.lerp(highlightColor, other.highlightColor, t) ?? highlightColor,
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t) ?? blurSigma,
    );
  }

  static double? lerpDouble(num? a, num? b, double t) {
    if (a == null && b == null) return null;
    final start = (a ?? 0).toDouble();
    final end = (b ?? 0).toDouble();
    return start + (end - start) * t;
  }
}

/// Builds light and dark [ThemeData] for Material 3, Android Monet, and Liquid Glass.
class AppTheme {
  const AppTheme._();

  static ThemeData buildTheme({
    required Brightness brightness,
    required Color seedColor,
    required bool enableLiquidGlass,
    ColorScheme? dynamicScheme,
    String? fontFamily,
    List<String>? fontFamilyFallback,
  }) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme effectiveScheme =
        (!enableLiquidGlass && dynamicScheme != null)
        ? dynamicScheme
        : ColorScheme.fromSeed(
            seedColor: enableLiquidGlass
                ? (isDark ? const Color(0xFF5AC8FA) : const Color(0xFF007AFF))
                : seedColor,
            brightness: brightness,
          );
    final baseTextTheme = fontFamilyFallback != null
        ? const TextTheme(
            bodyLarge: TextStyle(),
            bodyMedium: TextStyle(),
            titleMedium: TextStyle(),
          ).apply(fontFamilyFallback: fontFamilyFallback)
        : null;

    if (!enableLiquidGlass) {
      return ThemeData(
        colorScheme: effectiveScheme,
        useMaterial3: true,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        textTheme: baseTextTheme,
        extensions: const [LiquidGlassThemeExtension.disabled],
      );
    }

    final Color scaffoldBg = isDark
        ? const Color(0xFF090B10)
        : const Color(0xFFEFF3F9);
    // Optical glass surface balances refraction visibility with text legibility.
    final Color glassSurface = isDark
        ? const Color(0xFF181E2B).withValues(alpha: 0.70)
        : const Color(0xFFF7FAFF).withValues(alpha: 0.68);
    final Color glassSecondary = isDark
        ? const Color(0xFF202738).withValues(alpha: 0.78)
        : const Color(0xFFF2F6FD).withValues(alpha: 0.76);
    final Color border = isDark
        ? Colors.white.withValues(alpha: 0.24)
        : Colors.white.withValues(alpha: 0.88);
    final Color highlight = isDark
        ? Colors.white.withValues(alpha: 0.34)
        : Colors.white.withValues(alpha: 0.96);

    final ColorScheme glassScheme = effectiveScheme.copyWith(
      surface: isDark ? const Color(0xFF121620) : const Color(0xFFF6F9FE),
      surfaceContainerLow: isDark
          ? const Color(0xFF161C28).withValues(alpha: 0.72)
          : const Color(0xFFF8FAFF).withValues(alpha: 0.70),
      surfaceContainer: isDark
          ? const Color(0xFF1C2332).withValues(alpha: 0.78)
          : const Color(0xFFF4F8FE).withValues(alpha: 0.76),
      surfaceContainerHigh: isDark
          ? const Color(0xFF232B3D).withValues(alpha: 0.84)
          : const Color(0xFFEEF4FC).withValues(alpha: 0.84),
      surfaceContainerHighest: isDark
          ? const Color(0xFF2B3448).withValues(alpha: 0.88)
          : const Color(0xFFE8EEF7).withValues(alpha: 0.88),
      outlineVariant: border,
    );

    final glassExtension = LiquidGlassThemeExtension(
      enabled: true,
      glassTint: glassSurface,
      glassSecondaryTint: glassSecondary,
      borderColor: border,
      highlightColor: highlight,
      blurSigma: 12.0,
    );

    final Color tooltipBg = isDark
        ? const Color(0xFF1D2434).withValues(alpha: 0.88)
        : const Color(0xFFF8FAFF).withValues(alpha: 0.90);

    return ThemeData(
      brightness: brightness,
      colorScheme: glassScheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      textTheme: baseTextTheme,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: glassScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        color: glassSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: border, width: 1.0),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark
            ? const Color(0xFF171D2A).withValues(alpha: 0.86)
            : const Color(0xFFF8FAFF).withValues(alpha: 0.88),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: border, width: 1.0),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark
            ? const Color(0xFF171D2A).withValues(alpha: 0.86)
            : const Color(0xFFF8FAFF).withValues(alpha: 0.88),
        modalBackgroundColor: isDark
            ? const Color(0xFF171D2A).withValues(alpha: 0.86)
            : const Color(0xFFF8FAFF).withValues(alpha: 0.88),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark
            ? const Color(0xFF1D2332).withValues(alpha: 0.90)
            : const Color(0xFFF8FAFF).withValues(alpha: 0.90),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border, width: 0.9),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: tooltipBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        textStyle: TextStyle(
          color: glassScheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF1B2130).withValues(alpha: 0.88)
            : const Color(0xFFF8FAFF).withValues(alpha: 0.90),
        contentTextStyle: TextStyle(color: glassScheme.onSurface),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border, width: 1.0),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        thickness: 0.6,
      ),
      extensions: [glassExtension],
    );
  }

  static bool isLiquidGlass(BuildContext context) {
    return Theme.of(context).extension<LiquidGlassThemeExtension>()?.enabled ??
        false;
  }

  static LiquidGlassThemeExtension glassOf(BuildContext context) {
    return Theme.of(context).extension<LiquidGlassThemeExtension>() ??
        LiquidGlassThemeExtension.disabled;
  }
}
