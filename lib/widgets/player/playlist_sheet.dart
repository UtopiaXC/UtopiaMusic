import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/generated/l10n.dart';

class PlaylistSheet extends StatefulWidget {
  final List<Song> playlist;
  final Song currentSong;
  final Function(Song) onSongSelected;

  const PlaylistSheet({
    super.key,
    required this.playlist,
    required this.currentSong,
    required this.onSongSelected,
  });

  @override
  State<PlaylistSheet> createState() => _PlaylistSheetState();
}

class _PlaylistSheetState extends State<PlaylistSheet> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentSong();
    });
  }

  void _scrollToCurrentSong() {
    if (widget.playlist.isEmpty) return;

    final index = widget.playlist.indexWhere(
      (s) =>
          s.bvid == widget.currentSong.bvid && s.cid == widget.currentSong.cid,
    );

    if (index != -1 && _scrollController.hasClients) {
      final double itemHeight = 72.0;
      double offset = index * itemHeight;
      if (offset > _scrollController.position.maxScrollExtent) {
        offset = _scrollController.position.maxScrollExtent;
      }

      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).common_confirm_title),
        content: Text(
          S.of(context).weight_play_list_label_confirm_clean_message,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              Provider.of<PlayerProvider>(context, listen: false).closePlayer();
            },
            child: Text(S.of(context).common_clean),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text(
                  '${S.of(context).weight_play_list_label_name} (${widget.playlist.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _showClearConfirmation,
                  tooltip: S
                      .of(context)
                      .weight_search_label_confirm_clean_history_title,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: widget.playlist.length,
              itemBuilder: (context, index) {
                final song = widget.playlist[index];
                final isPlaying =
                    song.bvid == widget.currentSong.bvid &&
                    song.cid == widget.currentSong.cid;

                return ListTile(
                  leading: isPlaying
                      ? Icon(
                          Icons.equalizer,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : Text(
                          '${index + 1}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlaying
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      fontWeight: isPlaying ? FontWeight.bold : null,
                    ),
                  ),
                  subtitle: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlaying
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  onTap: () {
                    widget.onSongSelected(song);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
