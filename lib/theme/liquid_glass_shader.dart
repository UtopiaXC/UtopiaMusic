import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = 'LIQUID_GLASS_SHADER';

/// Loads and shares the optical Liquid Glass [ui.FragmentProgram] across glass surfaces.
class LiquidGlassShader {
  LiquidGlassShader._();

  static const String assetPath = 'assets/shaders/liquid_glass.frag';

  static final ValueNotifier<bool> readyNotifier = ValueNotifier<bool>(false);
  static ui.FragmentProgram? _program;
  static bool _loading = false;

  /// Whether the active Flutter rasterizer supports `ImageFilter.shader` (Impeller).
  static bool get isSupported => ui.ImageFilter.isShaderFilterSupported;

  static ui.FragmentProgram? get program => _program;

  static void ensureInitialized() {
    if (!isSupported || _program != null || _loading) return;
    _loading = true;
    ui.FragmentProgram.fromAsset(assetPath).then(
      (program) {
        _program = program;
        _loading = false;
        readyNotifier.value = true;
      },
      onError: (Object error, StackTrace stack) {
        _loading = false;
        Log.w(_tag, 'Failed to load liquid glass shader: $error');
      },
    );
  }

  /// Creates an [ui.ImageFilter.shader] configured with metric parameters in physical pixels.
  static ui.ImageFilter? buildBackdropFilter({
    required double devicePixelRatio,
    required double cornerRadius,
    required double bezelWidth,
    required double refraction,
    required double blurRadius,
    required double chromatic,
    required double highlight,
    required ui.Color tintColor,
  }) {
    if (!isSupported) return null;
    ensureInitialized();
    final prog = _program;
    if (prog == null) return null;

    final shader = prog.fragmentShader();
    final dpr = devicePixelRatio.clamp(1.0, 4.0);
    // Uniform slots 0 and 1 are reserved for engine-populated `uSize`.
    shader.setFloat(2, cornerRadius * dpr);
    shader.setFloat(3, bezelWidth * dpr);
    shader.setFloat(4, refraction * dpr);
    shader.setFloat(5, blurRadius * dpr);
    shader.setFloat(6, chromatic * dpr);
    shader.setFloat(7, highlight);
    shader.setFloat(8, tintColor.r);
    shader.setFloat(9, tintColor.g);
    shader.setFloat(10, tintColor.b);
    shader.setFloat(11, tintColor.a);

    return ui.ImageFilter.shader(shader);
  }
}
