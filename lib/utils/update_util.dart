import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:utopia_music/connection/update/github_api.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/widgets/update/update_dialog.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/utils/log.dart';
import 'dart:ffi';

const String _tag = "UPDATE_UTIL";

class UpdateUtil {
  static Future<void> checkAndShow(
    BuildContext context, {
    bool isManualCheck = false,
  }) async {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    if (!isManualCheck && !settingsProvider.autoCheckUpdate) return;

    final bool checkPreRelease = settingsProvider.checkPreRelease;
    final String? ignoredVersion = settingsProvider.ignoredVersion;

    if (isManualCheck) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(S.of(context).util_update_checking),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final githubApi = GithubApi();
      Map<String, dynamic>? release;

      if (checkPreRelease) {
        release = await githubApi.getLatestPreRelease(context);
      } else {
        release = await githubApi.getLatestRelease(context);
      }

      if (isManualCheck && context.mounted) {
        Navigator.pop(context);
      }

      if (release == null) return;
      if (!context.mounted) return;

      final tagName = release['tag_name'] as String;
      final packageInfo = await PackageInfo.fromPlatform();
      String? cleanRemote = _extractCoreVersion(tagName);
      String? cleanLocal = _extractCoreVersion(packageInfo.version);
      if (cleanRemote == null || cleanLocal == null) {
        return;
      }

      if (cleanRemote != cleanLocal) {
        if (!isManualCheck && ignoredVersion == tagName) {
          return;
        }

        showDialog(
          context: context,
          builder: (ctx) => UpdateDialog(releaseData: release!),
        );
      } else {
        if (isManualCheck) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).util_update_already_newest)),
          );
        }
      }
    } catch (e) {
      if (isManualCheck && context.mounted) {
        Navigator.pop(context);
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(S.of(context).common_failed),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(S.of(context).common_confirm),
              ),
            ],
          ),
        );
      }
    }
  }

  static String? _extractCoreVersion(String input) {
    final RegExp regExp = RegExp(r'(\d+)\.(\d+)\.(\d+)');
    final match = regExp.firstMatch(input);
    if (match != null) {
      return match.group(0);
    }
    return null;
  }

  static Future<void> performSmartDownload(
    BuildContext context,
    Map<String, dynamic> releaseData,
  ) async {
    final List<dynamic> assets = releaseData['assets'] ?? [];
    final String htmlUrl = releaseData['html_url'];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? downloadUrl;

    try {
      if (Platform.isAndroid) {
        downloadUrl = await _matchAndroid(assets);
      } else if (Platform.isWindows) {
        downloadUrl = _matchWindows(assets);
      } else if (Platform.isLinux) {
        downloadUrl = _matchLinux(assets);
      } else if (Platform.isMacOS) {
        downloadUrl = _matchMac(assets);
      } else if (Platform.isIOS) {
        downloadUrl = _matchIos(assets);
      }
    } catch (e) {
      Log.w(_tag, 'Smart download match failed: $e');
    }

    if (context.mounted) {
      Navigator.pop(context);
    }
    final String target = downloadUrl ?? htmlUrl;
    _launchBrowser(target, context);
  }

  static Future<String?> _matchAndroid(List<dynamic> assets) async {
    final abi = Abi.current();
    String? targetArch;

    if (abi == Abi.androidArm64) {
      targetArch = 'v8a';
    } else if (abi == Abi.androidArm) {
      targetArch = 'v7a';
    } else if (abi == Abi.androidX64) {
      targetArch = 'x86_64';
    } else if (abi == Abi.androidIA32) {
      targetArch = 'x86';
    }

    if (targetArch == null) {
      Log.d(_tag, 'Unknown ABI $abi, falling back to browser.');
      return null;
    }

    Log.d(_tag, 'Current App Arch is $targetArch, strict matching...');
    try {
      final match = assets.firstWhere((asset) {
        final name = asset['name'].toString().toLowerCase();
        return name.contains('android') &&
            name.contains(targetArch!.toLowerCase()) &&
            name.endsWith('.apk');
      });
      return match['browser_download_url'];
    } catch (e) {
      Log.d(_tag, 'No strict match found for $targetArch.');
      return null;
    }
  }

  static String? _matchWindows(List<dynamic> assets) {
    var match = assets.firstWhere((asset) {
      final name = asset['name'].toString().toLowerCase();
      return name.contains('windows') &&
          name.contains('setup') &&
          name.endsWith('.exe');
    }, orElse: () => null);

    match ??= assets.firstWhere((asset) {
      final name = asset['name'].toString().toLowerCase();
      return name.contains('windows') && name.endsWith('.zip');
    }, orElse: () => null);

    return match?['browser_download_url'];
  }

  static String? _matchLinux(List<dynamic> assets) {
    var match = assets.firstWhere((asset) {
      final name = asset['name'].toString().toLowerCase();
      return name.contains('linux') && name.endsWith('.appimage');
    }, orElse: () => null);
    match ??= assets.firstWhere((asset) {
      final name = asset['name'].toString().toLowerCase();
      return name.contains('linux') && name.endsWith('.deb');
    }, orElse: () => null);

    return match?['browser_download_url'];
  }

  static String? _matchMac(List<dynamic> assets) {
    final match = assets.firstWhere((asset) {
      final name = asset['name'].toString().toLowerCase();
      return name.contains('macos') && name.endsWith('.dmg');
    }, orElse: () => null);
    return match?['browser_download_url'];
  }

  static String? _matchIos(List<dynamic> assets) {
    final match = assets.firstWhere((asset) {
      final name = asset['name'].toString().toLowerCase();
      return name.contains('ios') && name.endsWith('.ipa');
    }, orElse: () => null);
    return match?['browser_download_url'];
  }

  static Future<void> _launchBrowser(String url, BuildContext context) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${S.of(context).util_scheme_launch_fail}: $e'),
          ),
        );
      }
    }
  }
}
