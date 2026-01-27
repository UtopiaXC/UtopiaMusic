import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:utopia_music/services/audio/audio_player_service.dart';
import 'package:utopia_music/utils/update_util.dart';
import 'package:utopia_music/generated/l10n.dart';

class AboutSettingsPage extends StatefulWidget {
  const AboutSettingsPage({super.key});

  @override
  State<AboutSettingsPage> createState() => _AboutSettingsPageState();
}

class _AboutSettingsPageState extends State<AboutSettingsPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version;
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${S.of(context).util_scheme_lauch_fail}: $url'),
          ),
        );
      }
    }
  }

  void _showEulaDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder(
                future: rootBundle.loadString('assets/documentations/EULA.md'),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Markdown(data: snapshot.data!);
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        '${S.of(context).common_loaded_failed}: ${snapshot.error}',
                      ),
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () async {
                      await AudioPlayerService().stop();
                      exit(0);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: Text(
                      S.of(context).pages_settings_about_disagree_and_exit,
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(S.of(context).pages_settings_about_agree),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFaqDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder(
                future: rootBundle.loadString('assets/documentations/QA.md'),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Markdown(data: snapshot.data!);
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        '${S.of(context).common_loaded_failed}: ${snapshot.error}',
                      ),
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(S.of(context).common_close),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).pages_settings_tag_about)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.music_note,
                size: 60,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              S.of(context).common_title,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Version $_version',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          const SizedBox(height: 32),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  _buildItem(
                    context,
                    title: S.of(context).pages_settings_about_developer,
                    subtitle: 'UtopiaXC',
                    onTap: () => _launchUrl('https://github.com/UtopiaXC'),
                  ),
                  _buildItem(
                    context,
                    title: S.of(context).pages_settings_about_github,
                    subtitle: 'https://github.com/UtopiaXC/UtopiaMusic',
                    onTap: () =>
                        _launchUrl('https://github.com/UtopiaXC/UtopiaMusic'),
                  ),
                  _buildItem(
                    context,
                    title: S.of(context).pages_settings_about_check_update,
                    onTap: () {
                      UpdateUtil.checkAndShow(context, isManualCheck: true);
                    },
                  ),
                  _buildItem(
                    context,
                    title: S.of(context).pages_settings_about_eurl,
                    onTap: () => _showEulaDialog(context),
                  ),
                  _buildItem(
                    context,
                    title: S.of(context).pages_settings_about_qa,
                    onTap: () => _showFaqDialog(context),
                  ),
                  _buildItem(
                    context,
                    title: S
                        .of(context)
                        .pages_settings_about_open_source_license,
                    onTap: () {
                      showLicensePage(
                        context: context,
                        applicationName: S.of(context).common_title,
                        applicationVersion: _version,
                        applicationIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.music_note,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
