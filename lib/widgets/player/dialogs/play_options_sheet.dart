import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';

class PlayOptionsSheet extends StatelessWidget {
  final Song song;
  final List<Song> contextList;
  final VoidCallback? onPlayAction;

  const PlayOptionsSheet({
    super.key,
    required this.song,
    required this.contextList,
    this.onPlayAction,
  });

  /// Executes the preset replacement option if configured (> 0),
  /// otherwise displays the [PlayOptionsSheet] modal bottom sheet.
  static void executeOrShow({
    required BuildContext context,
    required Song song,
    required List<Song> contextList,
    VoidCallback? onPlayAction,
  }) {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final int option = settingsProvider.quickPlaylistReplace;

    if (option > 0) {
      executeOption(
        context: context,
        option: option,
        song: song,
        contextList: contextList,
        onPlayAction: onPlayAction,
      );
    } else {
      showModalBottomSheet(
        context: context,
        builder: (context) => PlayOptionsSheet(
          song: song,
          contextList: contextList,
          onPlayAction: onPlayAction,
        ),
      );
    }
  }

  /// Directly executes one of the 5 replacement options without showing a modal sheet.
  static void executeOption({
    required BuildContext context,
    required int option,
    required Song song,
    required List<Song> contextList,
    VoidCallback? onPlayAction,
  }) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    switch (option) {
      case 1:
        playerProvider.setPlaylistAndPlay(contextList, song);
        onPlayAction?.call();
        break;
      case 2:
        playerProvider.insertNext(song);
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).sheet_option_insert_after),
            duration: const Duration(seconds: 1),
          ),
        );
        break;
      case 3:
        playerProvider.insertNextAndPlay(song);
        onPlayAction?.call();
        break;
      case 4:
        playerProvider.addToEnd(song);
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).sheet_option_append_to_end),
            duration: const Duration(seconds: 1),
          ),
        );
        break;
      case 5:
        playerProvider.replacePlaylistWithSong(song);
        onPlayAction?.call();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.playlist_play),
            title: Text(
              S.of(context).sheet_option_replace_play_list_by_song_list,
            ),
            onTap: () {
              Navigator.pop(context);
              Provider.of<PlayerProvider>(
                context,
                listen: false,
              ).setPlaylistAndPlay(contextList, song);
              onPlayAction?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: Text(S.of(context).sheet_option_insert_after),
            onTap: () {
              Navigator.pop(context);
              Provider.of<PlayerProvider>(
                context,
                listen: false,
              ).insertNext(song);
            },
          ),
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: Text(S.of(context).sheet_option_insert_after_and_play),
            onTap: () {
              Navigator.pop(context);
              Provider.of<PlayerProvider>(
                context,
                listen: false,
              ).insertNextAndPlay(song);
              onPlayAction?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_check),
            title: Text(S.of(context).sheet_option_append_to_end),
            onTap: () {
              Navigator.pop(context);
              Provider.of<PlayerProvider>(
                context,
                listen: false,
              ).addToEnd(song);
            },
          ),
          ListTile(
            leading: const Icon(Icons.swap_calls),
            title: Text(S.of(context).sheet_option_replace_by_single_song),
            onTap: () {
              Navigator.pop(context);
              Provider.of<PlayerProvider>(
                context,
                listen: false,
              ).replacePlaylistWithSong(song);
              onPlayAction?.call();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.close),
            title: Text(S.of(context).common_cancel),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
