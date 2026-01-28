import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "SCHEME_LAUNCH";

class SchemeLauncher {
  static Future<void> launchBilibili(
    BuildContext context, {
    String schemePath = 'home',
    String webUrl = 'https://www.bilibili.com',
  }) async {
    final Uri uri = Uri.parse(webUrl);

    if (Platform.isAndroid || Platform.isIOS) {
      final Uri appUri = Uri.parse('bilibili://$schemePath');
      try {
        if (await canLaunchUrl(appUri)) {
          await launchUrl(appUri);
          return;
        }
      } catch (e) {
        Log.w(_tag, 'Error launching app scheme: $e');
      }
    }

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).util_scheme_lauch_fail)),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${S.of(context).util_scheme_lauch_fail}: $e'),
          ),
        );
      }
    }
  }

  static Future<void> launchVideo(BuildContext context, String bvid) async {
    await launchBilibili(
      context,
      schemePath: 'video/$bvid',
      webUrl: 'https://www.bilibili.com/video/$bvid',
    );
  }

  static Future<void> launchUser(BuildContext context, int mid) async {
    await launchBilibili(
      context,
      schemePath: 'space/$mid',
      webUrl: 'https://space.bilibili.com/$mid',
    );
  }

  static Future<void> launchLive(BuildContext context, int roomId) async {
    await launchBilibili(
      context,
      schemePath: 'live/$roomId',
      webUrl: 'https://live.bilibili.com/$roomId',
    );
  }
}
