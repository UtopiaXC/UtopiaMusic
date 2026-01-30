import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/services/audio/audio_player_service.dart';
import 'package:utopia_music/services/cache_manager_service.dart';
import 'package:utopia_music/services/download_manager.dart';
import 'package:utopia_music/utils/quality_utils.dart';
import 'package:utopia_music/generated/l10n.dart';

class DownloadSettingsPage extends StatefulWidget {
  const DownloadSettingsPage({super.key});

  @override
  State<DownloadSettingsPage> createState() => _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends State<DownloadSettingsPage> {
  int _currentCacheSize = 200;
  String _usedCacheSizeStr = "...";
  int _maxConcurrentDownloads = 3;
  String _downloadSizeStr = '...';
  int _otherCacheSize = 50;
  String _otherCacheSizeStr = '...';

  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  final DownloadManager _downloadManager = DownloadManager();
  final CacheManagerService _cacheManagerService = CacheManagerService();

  @override
  void initState() {
    super.initState();
    _cacheManagerService.init().then((_) => _loadSettings());
  }

  Future<void> _loadSettings() async {
    final maxLimit = await _audioPlayerService.getMaxCacheSize();
    final usedBytes = await _audioPlayerService.getUsedCacheSize();
    final maxConcurrent = await _downloadManager.getMaxConcurrentDownloads();
    final otherCacheMax = await _cacheManagerService.getMaxCacheSize();
    final otherCacheUsed = await _cacheManagerService.getUsedCacheSize();

    if (mounted) {
      setState(() {
        _currentCacheSize = maxLimit;
        _usedCacheSizeStr = _formatSize(usedBytes);
        _maxConcurrentDownloads = maxConcurrent;
        _otherCacheSize = otherCacheMax;
        _otherCacheSizeStr = _formatSize(otherCacheUsed);
      });
      _updateDownloadSize();
    }
  }

  Future<void> _updateDownloadSize() async {
    final size = await _downloadManager.getUsedDownloadSize();
    if (mounted) {
      setState(() {
        _downloadSizeStr = _formatSize(size);
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  Future<void> _updateCacheSize(int size) async {
    await _audioPlayerService.setMaxCacheSize(size);
    if (mounted) {
      setState(() {
        _currentCacheSize = size;
      });
    }
  }

  Future<void> _updateMaxConcurrent(int count) async {
    await _downloadManager.setMaxConcurrentDownloads(count);
    if (mounted) {
      setState(() {
        _maxConcurrentDownloads = count;
      });
    }
  }

  Future<void> _updateOtherCacheSize(int size) async {
    final success = await _cacheManagerService.setMaxCacheSize(size);
    if (!success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('缓存大小不能小于 10 MB')));
      return;
    }
    if (mounted) {
      setState(() {
        _otherCacheSize = size;
      });
    }
  }

  Future<void> _handleClearOtherCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空其他缓存'),
        content: const Text('这将清除图片缓存和页面状态缓存，确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).common_confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _cacheManagerService.clearAllCache();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('其他缓存已清除')));
        await _loadSettings();
      }
    }
  }

  void _showOtherCacheSizeDialog() {
    final controller = TextEditingController(text: _otherCacheSize.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置其他缓存上限'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(suffixText: 'MB'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              '最小值: 10 MB',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () {
              final size = int.tryParse(controller.text);
              if (size != null) {
                _updateOtherCacheSize(size);
              }
              Navigator.pop(context);
            },
            child: Text(S.of(context).common_confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _handleClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          S.of(context).pages_settings_tag_download_cache_clear_cache,
        ),
        content: Text(
          S
              .of(context)
              .pages_settings_tag_download_cache_clear_cache_description,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).common_confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await Provider.of<PlayerProvider>(context, listen: false).clearAllCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              S
                  .of(context)
                  .pages_settings_tag_download_cache_clear_cache_cleared,
            ),
          ),
        );
        await _loadSettings();
      }
    }
  }

  Future<void> _handleClearDownloads() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          S.of(context).pages_settings_tag_download_download_clear_downloaded,
        ),
        content: Text(
          S
              .of(context)
              .pages_settings_tag_download_download_clear_downloaded_description,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).common_confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _downloadManager.deleteAllDownloads();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              S
                  .of(context)
                  .pages_settings_tag_download_download_clear_downloaded_cleared,
            ),
          ),
        );
        await _loadSettings();
      }
    }
  }

  void _showCustomSizeDialog() {
    final controller = TextEditingController(
      text: _currentCacheSize.toString(),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).common_custom),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(suffixText: 'MB'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () {
              final size = int.tryParse(controller.text);
              if (size != null) {
                _updateCacheSize(size);
              }
              Navigator.pop(context);
            },
            child: Text(S.of(context).common_confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).pages_settings_tag_download_performance),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          _SettingsGroup(
            title: S.of(context).pages_settings_tag_download_performance_cache,
            children: [
              ListTile(
                title: Text(
                  S
                      .of(context)
                      .pages_settings_tag_download_performance_cache_limit,
                ),
                subtitle: Text(
                  S
                      .of(context)
                      .pages_settings_tag_download_performance_cache_limit_description,
                ),
                trailing: DropdownButton<int>(
                  value:
                      [
                        0,
                        10,
                        50,
                        100,
                        200,
                        500,
                        1000,
                        4096,
                      ].contains(_currentCacheSize)
                      ? _currentCacheSize
                      : -1,
                  underline: const SizedBox(),
                  alignment: Alignment.centerRight,
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(S.of(context).common_disable),
                    ),
                    DropdownMenuItem(value: 10, child: Text('10 MB')),
                    DropdownMenuItem(value: 50, child: Text('50 MB')),
                    DropdownMenuItem(value: 100, child: Text('100 MB')),
                    DropdownMenuItem(value: 200, child: Text('200 MB')),
                    DropdownMenuItem(value: 500, child: Text('500 MB')),
                    DropdownMenuItem(value: 1000, child: Text('1 GB')),
                    DropdownMenuItem(value: 4096, child: Text('4 GB')),
                    DropdownMenuItem(value: -1, child: Text('自定义')),
                  ],
                  onChanged: (value) {
                    if (value == -1) {
                      _showCustomSizeDialog();
                    } else if (value != null) {
                      _updateCacheSize(value);
                    }
                  },
                ),
              ),
              ListTile(
                title: Text(
                  S.of(context).pages_settings_tag_download_cache_clear_cache,
                ),
                subtitle: Text(
                  '${S.of(context).pages_settings_tag_download_cache_used}: $_usedCacheSizeStr',
                ),
                trailing: Icon(Icons.delete_outline, size: 20),
                onTap: _handleClearCache,
              ),
            ],
          ),
          _SettingsGroup(
            title: '其他缓存',
            children: [
              ListTile(
                title: const Text('其他缓存上限'),
                subtitle: const Text('图片、页面状态等缓存'),
                trailing: DropdownButton<int>(
                  value:
                      [
                        10,
                        50,
                        100,
                        200,
                        500,
                        1000,
                        4096,
                      ].contains(_otherCacheSize)
                      ? _otherCacheSize
                      : -1,
                  underline: const SizedBox(),
                  alignment: Alignment.centerRight,
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10 MB')),
                    DropdownMenuItem(value: 50, child: Text('50 MB')),
                    DropdownMenuItem(value: 100, child: Text('100 MB')),
                    DropdownMenuItem(value: 200, child: Text('200 MB')),
                    DropdownMenuItem(value: 500, child: Text('500 MB')),
                    DropdownMenuItem(value: 1000, child: Text('1 GB')),
                    DropdownMenuItem(value: 4096, child: Text('4 GB')),
                    DropdownMenuItem(value: -1, child: Text('自定义')),
                  ],
                  onChanged: (value) {
                    if (value == -1) {
                      _showOtherCacheSizeDialog();
                    } else if (value != null) {
                      _updateOtherCacheSize(value);
                    }
                  },
                ),
              ),
              ListTile(
                title: const Text('清空其他缓存'),
                subtitle: Text(
                  '${S.of(context).pages_settings_tag_download_cache_used}: $_otherCacheSizeStr',
                ),
                trailing: const Icon(Icons.delete_outline, size: 20),
                onTap: _handleClearOtherCache,
              ),
            ],
          ),
          _SettingsGroup(
            title: '下载',
            children: [
              ListTile(
                title: Text(S.of(context).pages_settings_tag_download),
                trailing: DropdownButton<int>(
                  value: _maxConcurrentDownloads,
                  underline: const SizedBox(),
                  alignment: Alignment.centerRight,
                  items: List.generate(5, (index) => index + 1).map((count) {
                    return DropdownMenuItem<int>(
                      value: count,
                      child: Text('$count'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateMaxConcurrent(value);
                    }
                  },
                ),
              ),
              ListTile(
                title: Text(
                  S.of(context).pages_settings_tag_download_default_quality,
                ),
                trailing: DropdownButton<int>(
                  value: settingsProvider.defaultDownloadQuality,
                  underline: const SizedBox(),
                  alignment: Alignment.centerRight,
                  items: QualityUtils.supportQualities.map((quality) {
                    return DropdownMenuItem<int>(
                      value: quality,
                      child: Text(
                        QualityUtils.getQualityLabel(
                          context,
                          quality,
                          detailed: true,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      settingsProvider.setDefaultDownloadQuality(newValue);
                    }
                  },
                ),
              ),
              ListTile(
                title: Text(S.of(context).pages_settings_tag_download_clear),
                subtitle: Text(
                  '${S.of(context).pages_settings_tag_download_cache_used}: $_downloadSizeStr',
                ),
                trailing: const Icon(Icons.delete_forever_outlined, size: 20),
                onTap: _handleClearDownloads,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 4.0),
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Card(
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
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}
