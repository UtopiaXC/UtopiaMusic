import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "PLAYER_BACKGROUND";

class PlayerBackground extends StatelessWidget {
  final String coverUrl;
  final String mode;
  final ColorScheme? extractedColorScheme;

  const PlayerBackground({
    super.key,
    required this.coverUrl,
    required this.mode,
    this.extractedColorScheme,
  });

  @override
  Widget build(BuildContext context) {
    // Log.v(_tag, "build");
    switch (mode) {
      case 'gradient':
        return _buildGradientBackground(context);
      case 'gaussian_blur':
        return _buildBlurredBackground(coverUrl, 20.0);
      case 'blur':
        return _buildBlurredBackground(coverUrl, 10.0);
      case 'none':
      default:
        return Container(color: Theme.of(context).scaffoldBackgroundColor);
    }
  }

  Widget _buildGradientBackground(BuildContext context) {
    // Log.v(_tag, "_buildGradientBackground");
    if (extractedColorScheme == null) {
      return Container(color: Theme.of(context).scaffoldBackgroundColor);
    }
    final color = extractedColorScheme!.primaryContainer;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  color.withValues(alpha: 0.6),
                  Theme.of(context).scaffoldBackgroundColor,
                ]
              : [
                  color.withValues(alpha: 0.3),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
        ),
      ),
    );
  }

  Widget _buildBlurredBackground(String coverUrl, double sigma) {
    // Log.v(_tag, "_buildBlurredBackground, coverUrl: $coverUrl, sigma: $sigma");
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            coverUrl,
            fit: BoxFit.cover,
            cacheWidth: 100,
            errorBuilder: (_, _, _) => Container(color: Colors.black),
          ),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}
