import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:utopia_music/services/audio_player_service.dart';

class PerformanceSettingsPage extends StatefulWidget {
  const PerformanceSettingsPage({super.key});

  @override
  State<PerformanceSettingsPage> createState() => _PerformanceSettingsPageState();
}

class _PerformanceSettingsPageState extends State<PerformanceSettingsPage> {
  int _currentCacheSize = 200;
  final AudioPlayerService _audioPlayerService = AudioPlayerService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final size = await _audioPlayerService.getMaxCacheSize();
    setState(() {
      _currentCacheSize = size;
    });
  }

  Future<void> _updateCacheSize(int size) async {
    await _audioPlayerService.setMaxCacheSize(size);
    setState(() {
      _currentCacheSize = size;
    });
  }

  void _showCustomSizeDialog() {
    final controller = TextEditingController(text: _currentCacheSize.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义缓存大小 (MB)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            suffixText: 'MB',
          ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('性能')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('音乐缓存上限'),
            subtitle: const Text('缓存可减少重复播放曲目的流量消耗'),
            trailing: DropdownButton<int>(
              value: [0, 10, 50, 100, 200, 500, 1000, 4096].contains(_currentCacheSize)
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
                DropdownMenuItem(value: 4096, child: Text('4 BG')),
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
        ],
      ),
    );
  }
}
