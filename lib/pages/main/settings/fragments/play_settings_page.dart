import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';

class PlaySettingsPage extends StatelessWidget {
  const PlaySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

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
          SwitchListTile(
            title: const Text('推荐连播'),
            subtitle: const Text('自动获取下一个视频的推荐并替换播放列表'),
            value: playerProvider.recommendationAutoPlay,
            onChanged: (bool value) async {
              if (value) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('开启推荐连播'),
                    content: const Text('如果启动推荐视频自由连播，再切换到下一个视频的时候，将会自动获取下一个视频的推荐并替换播放列表，而不是播放本视频的推荐列表。\n\n本选项与循环模式冲突，当启用时，将禁用循环模式，并接管播放列表。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('确认'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  playerProvider.setRecommendationAutoPlay(true);
                }
              } else {
                playerProvider.setRecommendationAutoPlay(false);
              }
            },
          ),
          SwitchListTile(
            title: const Text('显示评论区'),
            subtitle: const Text('在视频详情页显示评论页'),
            value: settingsProvider.enableComments,
            onChanged: (bool value) {
              settingsProvider.setEnableComments(value);
            },
          ),
        ],
      ),
    );
  }
}
