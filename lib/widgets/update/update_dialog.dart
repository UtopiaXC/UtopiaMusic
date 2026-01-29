import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/utils/update_util.dart';
import 'package:utopia_music/generated/l10n.dart';

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
      title: Text(S.of(context).weight_update_new_version_found),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isPrerelease ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isPrerelease
                        ? S.of(context).weight_update_test_version
                        : S.of(context).weight_update_release_version,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${S.of(context).weight_update_from}: ${S.of(context).common_github}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(child: MarkdownBody(data: body)),
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
              child: Text(S.of(context).common_cancel),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _showIgnoreDialog(context, tagName),
              child: Text(S.of(context).weight_update_ignore_this_version),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () =>
                  UpdateUtil.performSmartDownload(context, releaseData),
              child: Text(S.of(context).common_download),
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
        title: Text(S.of(context).weight_update_ignore_this_version),
        content: Text(S.of(context).weight_update_ignore_this_version_message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () {
              Provider.of<SettingsProvider>(
                context,
                listen: false,
              ).setIgnoredVersion(version);
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: Text(S.of(context).common_confirm),
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
          SnackBar(
            content: Text('${S.of(context).util_scheme_launch_fail}: $url'),
          ),
        );
      }
    }
  }
}
