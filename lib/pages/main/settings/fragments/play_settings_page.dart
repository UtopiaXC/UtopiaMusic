import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
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
