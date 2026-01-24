import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:utopia_music/services/audio_player_service.dart';
import 'package:utopia_music/connection/update/github_api.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/widgets/update/update_dialog.dart';

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
          SnackBar(content: Text('无法打开链接: $url')),
        );
      }
    }
  }

  Future<void> _checkUpdate() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在检查更新...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      final githubApi = GithubApi();
      Map<String, dynamic>? release;

      if (settingsProvider.checkPreRelease) {
        release = await githubApi.getLatestPreRelease();
      } else {
        release = await githubApi.getLatestRelease();
      }

      if (!mounted) return;
      Navigator.pop(context);

      if (release != null) {
        final tagName = release['tag_name'] as String;
        String normalizedTag = tagName.startsWith('v') ? tagName.substring(1) : tagName;
        String normalizedCurrent = _version.split('+')[0];

        if (normalizedTag != normalizedCurrent) {
           showDialog(
             context: context,
             builder: (context) => UpdateDialog(releaseData: release!),
           );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当前已是最新版本')),
          );
        }
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('检查更新失败')),
          );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('检查更新失败'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
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
                    return Center(child: Text('加载失败: ${snapshot.error}'));
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
                    child: const Text('不同意并退出'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('同意'),
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
                    return Center(child: Text('加载失败: ${snapshot.error}'));
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
                  child: const Text('关闭'),
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
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        children: [
          const SizedBox(height: 32),
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
          const Center(
            child: Text(
              'Utopia Music',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
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
          _buildItem(
            context,
            title: '开发者',
            subtitle: 'UtopiaXC',
            onTap: () => _launchUrl('https://github.com/UtopiaXC'),
          ),
          _buildItem(
            context,
            title: 'GitHub',
            subtitle: 'https://github.com/UtopiaXC/UtopiaMusic',
            onTap: () => _launchUrl('https://github.com/UtopiaXC/UtopiaMusic'),
          ),
          _buildItem(
            context,
            title: '检查更新',
            onTap: _checkUpdate,
          ),
          _buildItem(
            context,
            title: '用户协议',
            onTap: () => _showEulaDialog(context),
          ),
          _buildItem(
            context,
            title: '常见问题',
            onTap: () => _showFaqDialog(context),
          ),
          _buildItem(
            context,
            title: '开源许可证',
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'Utopia Music',
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
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
