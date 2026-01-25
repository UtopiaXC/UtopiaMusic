import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/services/audio/audio_player_service.dart';
import 'package:utopia_music/utils/quality_utils.dart';

class PerformanceSettingsPage extends StatefulWidget {
  const PerformanceSettingsPage({super.key});

  @override
  State<PerformanceSettingsPage> createState() =>
      _PerformanceSettingsPageState();
}

class _PerformanceSettingsPageState extends State<PerformanceSettingsPage> {
  int _currentCacheSize = 200;
  String _usedCacheSizeStr = '计算中...';
  final AudioPlayerService _audioPlayerService = AudioPlayerService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final maxLimit = await _audioPlayerService.getMaxCacheSize();
    final usedBytes = await _audioPlayerService.getUsedCacheSize();

    if (mounted) {
      setState(() {
        _currentCacheSize = maxLimit;
        _usedCacheSizeStr = _formatSize(usedBytes);
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

  Future<void> _handleClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空音乐缓存'),
        content: const Text('确定要删除所有已缓存的歌曲文件并重置统计数据吗？\n这将需要重新下载所有歌曲。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await Provider.of<PlayerProvider>(context, listen: false).clearAllCache();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('缓存已清空')));
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
        title: const Text('自定义缓存大小 (MB)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(suffixText: 'MB'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final size = int.tryParse(controller.text);
              if (size != null) {
                _updateCacheSize(size);
              }
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('性能')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('音乐缓存上限'),
            subtitle: const Text('缓存可减少重复播放曲目的流量消耗'),
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
              items: const [
                DropdownMenuItem(value: 0, child: Text('禁用缓存')),
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
            title: const Text('清空音乐缓存'),
            subtitle: Text('当前音乐缓存大小：$_usedCacheSizeStr'),
            onTap: _handleClearCache,
          ),
          ListTile(
            title: const Text('默认下载音质'),
            trailing: DropdownButton<int>(
              value: settingsProvider.defaultDownloadQuality,
              underline: const SizedBox(),
              items: QualityUtils.supportQualities.map((quality) {
                return DropdownMenuItem<int>(
                  value: quality,
                  child: Text(
                    QualityUtils.getQualityLabel(quality, detailed: true),
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
        ],
      ),
    );
  }
}
