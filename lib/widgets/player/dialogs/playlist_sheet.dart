import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_form_sheet.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/providers/library_provider.dart';

import 'package:utopia_music/utils/log.dart';

const String _tag = "PLAYLIST_SHEET";

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
    Log.v(_tag, "initState");
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentSong();
    });
  }

  void _scrollToCurrentSong() {
    Log.v(_tag, "_scrollToCurrentSong");
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
    Log.v(_tag, "_showClearConfirmation");
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

  void _handleSavePlaylist() {
    Log.v(_tag, "_handleSavePlaylist");
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PlaylistFormSheet(
        onSubmit: (title, description) async {
          final id = await DatabaseService().createLocalPlaylist(
            title,
            description,
          );
          final playerProvider = Provider.of<PlayerProvider>(
            context,
            listen: false,
          );
          for (var song in playerProvider.playlist) {
            await DatabaseService().addSongToLocalPlaylist(id, song);
          }
          if (mounted) {
            Provider.of<LibraryProvider>(
              context,
              listen: false,
            ).refreshLibrary(localOnly: true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(S.of(context).weight_player_saved_as_local),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    Log.v(_tag, "dispose");
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Log.v(_tag, "build");
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Consumer<PlayerProvider>(
        builder: (context, playerProvider, child) {
          final playlist = playerProvider.playlist;
          final currentSong = playerProvider.currentSong ?? widget.currentSong;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Text(
                      '${S.of(context).weight_play_list_label_name} (${playlist.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.folder_special_outlined),
                      onPressed: _handleSavePlaylist,
                      tooltip: S
                          .of(context)
                          .weight_player_saved_as_local_playlist,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _showClearConfirmation,
                      tooltip: S
                          .of(context)
                          .weight_play_list_label_confirm_clean_playlist_title,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ReorderableListView.builder(
                  scrollController: _scrollController,
                  buildDefaultDragHandles: false,
                  itemCount: playlist.length,
                  onReorder: (oldIndex, newIndex) {
                    playerProvider.reorderPlaylist(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final song = playlist[index];
                    final isPlaying =
                        song.bvid == currentSong.bvid &&
                        song.cid == currentSong.cid;

                    return ListTile(
                      key: ValueKey('${song.bvid}_${song.cid}'),
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              playerProvider.removeSong(index);
                            },
                          ),
                        ],
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
          );
        },
      ),
    );
  }
}
