import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/providers/player_provider.dart';

class PlaySettingsPage extends StatelessWidget {
  const PlaySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('播放')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('解码器选择'),
            trailing: DropdownButton<int>(
              value: playerProvider.decoderType,
              onChanged: (int? newValue) {
                if (newValue != null) {
                  playerProvider.setDecoderType(newValue);
                }
              },
              items: const [
                DropdownMenuItem(
                  value: 0,
                  child: Text('软解 (兼容性好，性能差)'),
                ),
                DropdownMenuItem(
                  value: 1,
                  child: Text('硬解 (性能更好，更省电)'),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('自动跳过失效资源'),
            subtitle: const Text('遇到版权或充电视频等无效资源时，静默清理并播放下一首'),
            value: playerProvider.autoSkipInvalid,
            onChanged: (bool value) {
              playerProvider.setAutoSkipInvalid(value);
            },
          ),
          SwitchListTile(
            title: const Text('保存播放进度（实验性）'),
            subtitle: const Text('重启软件时定位到最后播放的音乐的进度条位置'),
            value: playerProvider.saveProgress,
            onChanged: (bool value) {
              playerProvider.setSaveProgress(value);
            },
          ),
          SwitchListTile(
            title: const Text('自动播放'),
            subtitle: const Text('退出软件时如果正在播放则打开软件时自动播放'),
            value: playerProvider.autoPlay,
            onChanged: (bool value) {
              playerProvider.setAutoPlay(value);
            },
          ),
        ],
      ),
    );
  }
}
