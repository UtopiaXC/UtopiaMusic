import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/utils/quality_utils.dart';

class PlaySettingsPage extends StatelessWidget {
  const PlaySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('播放')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          _SettingsGroup(
            title: '解码',
            children: [
              // ListTile(
              //   title: const Text('解码器选择'),
              //   trailing: DropdownButton<int>(
              //     value: playerProvider.decoderType,
              //     underline: const SizedBox(),
              //     alignment: Alignment.centerRight,
              //     onChanged: (int? newValue) {
              //       if (newValue != null) {
              //         playerProvider.setDecoderType(newValue);
              //       }
              //     },
              //     items: const [
              //       DropdownMenuItem(value: 0, child: Text('软解 (兼容性好，性能差)')),
              //       DropdownMenuItem(value: 1, child: Text('硬解 (性能更好，更省电)')),
              //     ],
              //   ),
              // ),
              ListTile(
                title: const Text('默认在线播放音质'),
                trailing: DropdownButton<int>(
                  value: settingsProvider.defaultAudioQuality,
                  underline: const SizedBox(),
                  alignment: Alignment.centerRight,
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      settingsProvider.setDefaultAudioQuality(newValue);
                    }
                  },
                  items: QualityUtils.supportQualities.map((quality) {
                    return DropdownMenuItem<int>(
                      value: quality,
                      child: Text(
                        QualityUtils.getQualityLabel(quality, detailed: true),
                      ),
                    );
                  }).toList(),
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
            ],
          ),
          _SettingsGroup(
            title: '控制',
            children: [
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
          _SettingsGroup(
            title: '连播',
            children: [
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
                        content: const Text(
                          '如果启动推荐视频自由连播，再切换到下一个视频的时候，将会自动获取下一个视频的推荐并替换播放列表，而不是播放本视频的推荐列表。\n\n本选项与循环模式冲突，当启用时，将禁用循环模式，并接管播放列表。',
                        ),
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
            ],
          ),
          _SettingsGroup(
            title: '评论',
            children: [
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
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}