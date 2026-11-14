import 'package:flutter/material.dart';
import 'package:utopia_music/theme/app_theme.dart';
import 'package:utopia_music/widgets/common/liquid_glass_container.dart';

/// Shared container shell for settings fragments supporting standalone mobile
/// routes and embedded desktop split-pane presentation.
class SettingsFragmentScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final bool embedded;

  const SettingsFragmentScaffold({
    super.key,
    required this.title,
    required this.body,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLiquidGlass = AppTheme.isLiquidGlass(context);

    if (embedded) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: body,
          ),
        ),
      );
    }

    final scaffold = Scaffold(
      backgroundColor: isLiquidGlass ? Colors.transparent : null,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: isLiquidGlass ? Colors.transparent : null,
      ),
      body: body,
    );

    return isLiquidGlass ? LiquidGlassBackdrop(child: scaffold) : scaffold;
  }
}

/// Shared grouped section card for settings items, adapting automatically
/// between Material 3 surfaces and Liquid Glass styling.
class SettingsGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const SettingsGroup({super.key, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isLiquidGlass = AppTheme.isLiquidGlass(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 4.0),
              child: Text(
                title!,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          isLiquidGlass
              ? LiquidGlassSurface(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(children: children),
                )
              : Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(children: children),
                ),
        ],
      ),
    );
  }
}
