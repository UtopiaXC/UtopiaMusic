import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/providers/sponsor_block_provider.dart';
import 'package:utopia_music/pages/sponsor_block/sponsor_block_page.dart';
import 'package:utopia_music/utils/quality_utils.dart';
import 'package:utopia_music/generated/l10n.dart';

class PlaySettingsPage extends StatelessWidget {
  const PlaySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).pages_settings_tag_player)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          _SettingsGroup(
            title: S.of(context).pages_settings_tag_player_codec,
            children: [
              ListTile(
                title: Text(
                  S
                      .of(context)
                      .pages_settings_tag_player_codec_online_default_quality,
                ),
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
                        QualityUtils.getQualityLabel(
                          context,
                          quality,
                          detailed: true,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SwitchListTile(
                title: Text(
                  S
                      .of(context)
                      .pages_settings_tag_player_codec_clear_unavailable,
                ),
                subtitle: Text(
                  S
                      .of(context)
                      .pages_settings_tag_player_codec_clear_unavailable_description,
                ),
                value: playerProvider.autoSkipInvalid,
                onChanged: (bool value) {
                  playerProvider.setAutoSkipInvalid(value);
                },
              ),
            ],
          ),
          _SettingsGroup(
            title: S.of(context).pages_settings_tag_player_control,
            children: [
              SwitchListTile(
                title: Text(
                  S.of(context).pages_settings_tag_player_control_save_progress,
                ),
                subtitle: Text(
                  S
                      .of(context)
                      .pages_settings_tag_player_control_save_progress_description,
                ),
                value: playerProvider.saveProgress,
                onChanged: (bool value) {
                  playerProvider.setSaveProgress(value);
                },
              ),
              SwitchListTile(
                title: Text(
                  S.of(context).pages_settings_tag_player_control_auto_play,
                ),
                subtitle: Text(
                  S
                      .of(context)
                      .pages_settings_tag_player_control_auto_play_description,
                ),
                value: playerProvider.autoPlay,
                onChanged: (bool value) {
                  playerProvider.setAutoPlay(value);
                },
              ),
              SwitchListTile(
                title: Text(
                  S.of(context).pages_settings_tag_player_control_quick_play,
                ),
                subtitle: Text(
                  S
                      .of(context)
                      .pages_settings_tag_player_control_quick_play_description,
                ),
                value: settingsProvider.quickPlay,
                onChanged: (bool value) {
                  settingsProvider.setQuickPlay(value);
                },
              ),
              ListTile(
                title: Text(
                  S
                      .of(context)
                      .pages_settings_tag_player_control_quick_playlist_replace,
                ),
                subtitle: Text(
                  S
                      .of(context)
                      .pages_settings_tag_player_control_quick_playlist_replace_description,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.35,
                      ),
                      child: Text(
                        _getQuickPlaylistReplaceLabel(
                          context,
                          settingsProvider.quickPlaylistReplace,
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
                onTap: () => _showQuickPlaylistReplaceDialog(
                  context,
                  settingsProvider,
                ),
              ),
            ],
          ),
          _SettingsGroup(
            title: S.of(context).pages_settings_tag_player_auto_next,
            children: [
              SwitchListTile(
                title: Text(
                  S.of(context).pages_settings_tag_player_auto_next_suggest,
                ),
                subtitle: Text(
                  S
                      .of(context)
                      .pages_settings_tag_player_auto_next_suggest_description,
                ),
                value: playerProvider.recommendationAutoPlay,
                onChanged: (bool value) async {
                  if (value) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          S
                              .of(context)
                              .pages_settings_tag_player_auto_next_suggest,
                        ),
                        content: Text(
                          S
                              .of(context)
                              .pages_settings_tag_player_auto_next_suggest_dialog_msg,
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
            title: S.of(context).pages_settings_tag_player_comment,
            children: [
              SwitchListTile(
                title: Text(
                  S.of(context).pages_settings_tag_player_comment_title,
                ),
                subtitle: Text(
                  S.of(context).pages_settings_tag_player_comment_description,
                ),
                value: settingsProvider.enableComments,
                onChanged: (bool value) {
                  settingsProvider.setEnableComments(value);
                },
              ),
            ],
          ),
          _SettingsGroup(
            title: '小电视空降助手',
            children: [
              Consumer<SponsorBlockProvider>(
                builder: (context, sbProvider, child) {
                  return Column(
                    children: [
                      SwitchListTile(
                        title: const Text('启用小电视空降助手'),
                        subtitle: const Text('自动跳过音频中的赞助广告、片头片尾等片段'),
                        value: sbProvider.enableSponsorBlock,
                        onChanged: (bool value) {
                          sbProvider.setEnableSponsorBlock(value);
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('空降助手详细设置'),
                        subtitle: const Text('自定义跳过行为、片段类别、颜色及统计'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SponsorBlockPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getQuickPlaylistReplaceLabel(BuildContext context, int option) {
    switch (option) {
      case 1:
        return S.of(context).sheet_option_replace_play_list_by_song_list;
      case 2:
        return S.of(context).sheet_option_insert_after;
      case 3:
        return S.of(context).sheet_option_insert_after_and_play;
      case 4:
        return S.of(context).sheet_option_append_to_end;
      case 5:
        return S.of(context).sheet_option_replace_by_single_song;
      case 0:
      default:
        return S.of(context).common_close;
    }
  }

  void _showQuickPlaylistReplaceDialog(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final options = [
      (0, S.of(context).common_close),
      (1, S.of(context).sheet_option_replace_play_list_by_song_list),
      (2, S.of(context).sheet_option_insert_after),
      (3, S.of(context).sheet_option_insert_after_and_play),
      (4, S.of(context).sheet_option_append_to_end),
      (5, S.of(context).sheet_option_replace_by_single_song),
    ];

    showDialog(
      context: context,
      builder: (context) {
        int selected = settingsProvider.quickPlaylistReplace;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                S
                    .of(context)
                    .pages_settings_tag_player_control_quick_playlist_replace,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: options.map((opt) {
                    return RadioListTile<int>(
                      value: opt.$1,
                      groupValue: selected,
                      title: Text(opt.$2),
                      onChanged: (int? val) {
                        if (val != null) {
                          setDialogState(() => selected = val);
                          settingsProvider.setQuickPlaylistReplace(val);
                          Navigator.pop(context);
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(S.of(context).common_cancel),
                ),
              ],
            );
          },
        );
      },
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
