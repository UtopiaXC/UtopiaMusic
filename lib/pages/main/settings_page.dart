import 'package:flutter/material.dart';
import 'package:utopia_music/generated/l10n.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Text(S.of(context).pages_tag_settings),
      ),
    );
  }
}
