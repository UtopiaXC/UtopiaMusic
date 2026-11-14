import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:utopia_music/theme/app_theme.dart';

/// Optical Liquid Glass surface with Gaussian backdrop blur and specular bevel rim.
///
/// Uses clamped [ImageFilter.blur] inside [BackdropFilter] paired with a local
/// meniscus bevel rim painter so refraction framing stays aligned across all
/// scroll offsets, screen positions, and rendering backends.
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? blurSigma;
  final Color? tintColor;
  final double? width;
  final double? height;
  final BoxShadow? shadow;
  final double refractionStrength;
  final double bezelWidth;
  final double chromaticAberration;
  final double highlightStrength;
  final bool highContrastScrim;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding,
    this.margin,
    this.blurSigma,
    this.tintColor,
    this.width,
    this.height,
    this.shadow,
    this.refractionStrength = 22.0,
    this.bezelWidth = 18.0,
    this.chromaticAberration = 1.6,
    this.highlightStrength = 0.72,
    this.highContrastScrim = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glass = AppTheme.glassOf(context);
    final double sigma =
        blurSigma ??
        (highContrastScrim
            ? 16.0
            : (glass.enabled ? glass.blurSigma : 12.0));

    final Color defaultTint = highContrastScrim
        ? (isDark
              ? const Color(0xFF141925).withValues(alpha: 0.84)
              : const Color(0xFFF7FAFF).withValues(alpha: 0.84))
        : (glass.enabled
              ? glass.glassTint
              : (isDark
                    ? const Color(0xFF181E2B).withValues(alpha: 0.70)
                    : const Color(0xFFF7FAFF).withValues(alpha: 0.68)));
    final Color baseTint = tintColor ?? defaultTint;

    final Color rimHighlight = glass.enabled
        ? glass.highlightColor
        : (isDark
              ? Colors.white.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.94));
    final Color edgeColor = glass.enabled
        ? glass.borderColor
        : (isDark
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.84));

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          shadow ??
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.10),
                blurRadius: 24,
                spreadRadius: -2,
                offset: const Offset(0, 10),
              ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.clamp,
          ),
          child: CustomPaint(
            foregroundPainter: _LiquidGlassRimPainter(
              borderRadius: borderRadius,
              isDark: isDark,
              highlightColor: rimHighlight,
              borderColor: edgeColor,
              bezelWidth: bezelWidth,
              includeInnerMeniscus: true,
            ),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    baseTint.withValues(
                      alpha: (baseTint.a * 1.12).clamp(0.0, 0.94),
                    ),
                    baseTint,
                    baseTint.withValues(
                      alpha: (baseTint.a * 0.90).clamp(0.0, 0.94),
                    ),
                  ],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints curved specular bezel rims and optical meniscus highlights.
class _LiquidGlassRimPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final bool isDark;
  final Color highlightColor;
  final Color borderColor;
  final double bezelWidth;
  final bool includeInnerMeniscus;

  const _LiquidGlassRimPainter({
    required this.borderRadius,
    required this.isDark,
    required this.highlightColor,
    required this.borderColor,
    required this.bezelWidth,
    required this.includeInnerMeniscus,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    if (includeInnerMeniscus) {
      // Soft optical bevel ring mimicking curved edge thickness on Skia backends.
      final bevelStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (bezelWidth * 0.5).clamp(3.0, 10.0)
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.16 : 0.42),
            Colors.transparent,
            (isDark ? const Color(0xFF7CC4FF) : const Color(0xFF9AC5FF))
                .withValues(alpha: isDark ? 0.10 : 0.16),
          ],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(rect);
      canvas.drawRRect(rrect.deflate(1.5), bevelStroke);
    }

    // Crisp outer specular rim catch.
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          highlightColor,
          borderColor.withValues(alpha: borderColor.a * 0.35),
          highlightColor.withValues(alpha: highlightColor.a * 0.65),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect.deflate(0.6), rimPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassRimPainter oldDelegate) {
    return borderRadius != oldDelegate.borderRadius ||
        isDark != oldDelegate.isDark ||
        highlightColor != oldDelegate.highlightColor ||
        borderColor != oldDelegate.borderColor ||
        bezelWidth != oldDelegate.bezelWidth ||
        includeInnerMeniscus != oldDelegate.includeInnerMeniscus;
  }
}

/// Soft ambient backdrop so translucent Liquid Glass layers visibly refract depth.
class LiquidGlassBackdrop extends StatelessWidget {
  final Widget child;

  const LiquidGlassBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final tertiary = theme.colorScheme.tertiary;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF0A0D14),
                        Color.alphaBlend(
                          primary.withValues(alpha: 0.14),
                          const Color(0xFF0E1320),
                        ),
                        Color.alphaBlend(
                          tertiary.withValues(alpha: 0.10),
                          const Color(0xFF090B10),
                        ),
                      ]
                    : [
                        const Color(0xFFF3F7FD),
                        Color.alphaBlend(
                          primary.withValues(alpha: 0.08),
                          const Color(0xFFEAF1FB),
                        ),
                        Color.alphaBlend(
                          tertiary.withValues(alpha: 0.07),
                          const Color(0xFFF6F8FC),
                        ),
                      ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Lightweight sculpted glass surface for high-FPS scrolling list and grid items.
///
/// Mirrors [LiquidGlassContainer] sheen and rim highlights without spawning
/// expensive per-cell [BackdropFilter] passes inside scrollable lists.
class LiquidGlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? fallbackColor;
  final Border? fallbackBorder;
  final List<BoxShadow>? fallbackShadow;

  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.margin,
    this.padding,
    this.fallbackColor,
    this.fallbackBorder,
    this.fallbackShadow,
  });

  /// Returns the optical glass box decoration when Liquid Glass is active.
  static BoxDecoration glassDecoration(
    BuildContext context, {
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(14)),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glass = AppTheme.glassOf(context);
    final Color topTint = isDark
        ? const Color(0xFF21293B).withValues(alpha: 0.78)
        : Colors.white.withValues(alpha: 0.78);
    final Color bottomTint = isDark
        ? const Color(0xFF171D2A).withValues(alpha: 0.66)
        : const Color(0xFFEEF4FC).withValues(alpha: 0.64);
    final Color borderColor = glass.enabled
        ? glass.borderColor.withValues(alpha: isDark ? 0.28 : 0.88)
        : Colors.white.withValues(alpha: isDark ? 0.24 : 0.84);

    return BoxDecoration(
      borderRadius: borderRadius,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [topTint, bottomTint],
      ),
      border: Border.all(color: borderColor, width: 1.0),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
          blurRadius: 14,
          spreadRadius: -2,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLiquidGlass = AppTheme.isLiquidGlass(context);
    final BoxDecoration decoration = isLiquidGlass
        ? glassDecoration(context, borderRadius: borderRadius)
        : BoxDecoration(
            color:
                fallbackColor ?? Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: borderRadius,
            border: fallbackBorder,
            boxShadow: fallbackShadow,
          );

    return Container(
      margin: margin,
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: borderRadius,
        child: padding != null ? Padding(padding: padding!, child: child) : child,
      ),
    );
  }
}

/// Optical translucent Liquid Glass wrapper for modals, dialogs, and bottom sheets.
class LiquidGlassSheetSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final Color? fallbackColor;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const LiquidGlassSheetSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(24)),
    this.fallbackColor,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLiquidGlass = AppTheme.isLiquidGlass(context);
    final Color resolvedFallback =
        fallbackColor ?? Theme.of(context).colorScheme.surface;

    if (!isLiquidGlass) {
      return Material(
        color: resolvedFallback,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          height: height,
          child: padding != null ? Padding(padding: padding!, child: child) : child,
        ),
      );
    }

    return LiquidGlassContainer(
      width: width,
      height: height,
      padding: padding,
      borderRadius: borderRadius,
      highContrastScrim: true,
      refractionStrength: 20.0,
      bezelWidth: 18.0,
      blurSigma: 16.0,
      chromaticAberration: 1.4,
      highlightStrength: 0.78,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }
}
