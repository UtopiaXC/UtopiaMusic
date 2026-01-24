import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.playlist_play),
            title: Text(S.of(context).dialog_option_replace_play_list_by_song_list),
            onTap: () {
              Navigator.pop(context);
              Provider.of<PlayerProvider>(context, listen: false)
                  .setPlaylistAndPlay(contextList, song);
              onPlayAction?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: Text(S.of(context).dialog_option_insert_after),
            onTap: () {
              Navigator.pop(context);
              Provider.of<PlayerProvider>(context, listen: false).insertNext(song);
            },
          ),
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: Text(S.of(context).dialog_option_insert_after_and_play),
            onTap: () {
              Navigator.pop(context);
              Provider.of<PlayerProvider>(context, listen: false)
                  .insertNextAndPlay(song);
              onPlayAction?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_check),
            title: Text(S.of(context).dialog_option_append_to_end),
            onTap: () {
              Navigator.pop(context);
              Provider.of<PlayerProvider>(context, listen: false).addToEnd(song);
            },
          ),
          ListTile(
            leading: const Icon(Icons.swap_calls),
            title: Text(S.of(context).dialog_option_replace_by_single_song),
            onTap: () {
              Navigator.pop(context);
              Provider.of<PlayerProvider>(context, listen: false)
                  .replacePlaylistWithSong(song);
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
