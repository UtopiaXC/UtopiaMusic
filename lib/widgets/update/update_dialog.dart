import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:utopia_music/providers/settings_provider.dart';

class UpdateDialog extends StatelessWidget {
  final Map<String, dynamic> releaseData;

  const UpdateDialog({super.key, required this.releaseData});

  @override
  Widget build(BuildContext context) {
    final tagName = releaseData['tag_name'] as String;
    final body = releaseData['body'] as String;
    final htmlUrl = releaseData['html_url'] as String;
    final isPrerelease = releaseData['prerelease'] as bool;

    return AlertDialog(
      title: const Text('发现新版本'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(tagName, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPrerelease ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isPrerelease ? '测试版' : '正式版',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('版本来源: GitHub', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: MarkdownBody(data: body),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _showIgnoreDialog(context, tagName),
              child: const Text('忽略本次'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _launchUrl(context, htmlUrl),
              child: const Text('下载'),
            ),
          ],
        ),
      ],
    );
  }

  void _showIgnoreDialog(BuildContext context, String version) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('忽略更新'),
        content: const Text('将不会再检测该版本的更新，是否确认？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<SettingsProvider>(context, listen: false).setIgnoredVersion(version);
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开链接: $url')),
        );
      }
    }
  }
}
