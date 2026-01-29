import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/services/download_manager.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_form_sheet.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/widgets/song_list/song_list_item.dart';
import 'package:utopia_music/generated/l10n.dart';

class PlaylistDetailSheet extends StatefulWidget {
  final LocalPlaylist playlist;
  final Function() onUpdate;

  const PlaylistDetailSheet({
    super.key,
    required this.playlist,
    required this.onUpdate,
  });

  @override
  State<PlaylistDetailSheet> createState() => _PlaylistDetailSheetState();
}

class _PlaylistDetailSheetState extends State<PlaylistDetailSheet> {
  late LocalPlaylist _playlist;
  List<Song> _songs = [];
  List<Song> _displaySongs = [];
  bool _isLoading = true;
  bool _isDescending = true;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    final songs = await DatabaseService().getLocalPlaylistSongs(_playlist.id);
    final playlists = await DatabaseService().getLocalPlaylists();
    final updatedPlaylist = playlists.firstWhere(
      (p) => p.id == _playlist.id,
      orElse: () => _playlist,
    );

    if (mounted) {
      setState(() {
        _songs = songs;
        _playlist = updatedPlaylist;
        _applySorting();
        _isLoading = false;
      });
    }
  }

  void _applySorting() {
    _displaySongs = List.from(_songs);
    if (_isDescending) {
      _displaySongs = _displaySongs.reversed.toList();
    }
  }

  void _toggleSortOrder() {
    setState(() {
      _isDescending = !_isDescending;
      _applySorting();
    });
  }

  Future<void> _handleEdit() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PlaylistFormSheet(
        initialTitle: _playlist.title,
        initialDescription: _playlist.description,
        onSubmit: (title, description) async {
          await DatabaseService().updateLocalPlaylist(
            _playlist.id,
            title,
            description,
          );
          widget.onUpdate();
          _loadSongs();
        },
      ),
    );
  }

  Future<void> _handleDelete() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).common_confirm_title),
        content: Text(
          S.of(context).pages_library_playlist_delete_confirm(_playlist.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseService().deleteLocalPlaylist(_playlist.id);
              widget.onUpdate();
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: Text(S.of(context).pages_library_download_action_delete),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDownload() async {
    if (_songs.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).common_confirm_title),
        content: Text(S.of(context).pages_library_playlist_download_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).common_download),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (var song in _songs) {
        await DownloadManager().startDownload(song);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              S.of(context).pages_library_playlist_download_started,
            ),
          ),
        );
      }
    }
  }

  Future<void> _handlePlay() async {
    if (_displaySongs.isEmpty) return;
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    if (playerProvider.playlist.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(S.of(context).common_replace_playlist),
          content: Text(
            S.of(context).pages_library_playlist_play_replace_confirm,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(S.of(context).common_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(S.of(context).common_replace),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    if (mounted) {
      Navigator.pop(context);
    }
    await playerProvider.setPlaylistAndPlay(_displaySongs, _displaySongs.first);
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final song = _displaySongs.removeAt(oldIndex);
    _displaySongs.insert(newIndex, song);
    setState(() {});

    final originalOldIndex = _isDescending
        ? _songs.length - 1 - oldIndex
        : oldIndex;
    final originalNewIndex = _isDescending
        ? _songs.length - 1 - newIndex
        : newIndex;

    await DatabaseService().updateLocalPlaylistSongOrder(
      _playlist.id,
      originalOldIndex,
      originalNewIndex,
    );

    await _loadSongs();
  }

  void _showRenameDialog(Song song) {
    final controller = TextEditingController(text: song.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).pages_library_playlist_rename_dialog_title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: S.of(context).pages_library_playlist_rename_dialog_label,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await DatabaseService().updateLocalPlaylistSongTitle(
                  _playlist.id,
                  song.bvid,
                  song.cid,
                  controller.text,
                );
                _loadSongs();
                Navigator.pop(context);
              }
            },
            child: Text(S.of(context).common_confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            image: _playlist.coverUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_playlist.coverUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _playlist.coverUrl == null
                              ? Icon(
                                  Icons.music_note,
                                  size: 48,
                                  color: colorScheme.onSurfaceVariant,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _playlist.title,
                                style: Theme.of(context).textTheme.titleLarge,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _playlist.description.isEmpty
                                    ? S.of(context).common_none
                                    : _playlist.description,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _handlePlay,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(S.of(context).common_play),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _handleEdit,
                      icon: const Icon(Icons.edit),
                      tooltip: S.of(context).pages_library_playlist_edit,
                    ),
                    IconButton(
                      onPressed: _handleDownload,
                      icon: const Icon(Icons.download),
                      tooltip: S.of(context).common_download,
                    ),
                    IconButton(
                      onPressed: _handleDelete,
                      icon: const Icon(Icons.delete),
                      tooltip: S
                          .of(context)
                          .pages_library_download_action_delete,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    const Expanded(child: Divider()),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _toggleSortOrder,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isDescending
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _displaySongs.isEmpty
                    ? GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragUpdate: (details) {
                          if (details.primaryDelta! > 10) {
                            Navigator.pop(context);
                          }
                        },
                        child: Center(
                          child: Text(
                            S.of(context).pages_library_playlist_empty,
                          ),
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollUpdateNotification) {
                            if (notification.metrics.pixels <= 0 &&
                                notification.scrollDelta! < 0) {}
                          }
                          return false;
                        },
                        child: ReorderableListView.builder(
                          scrollController: scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _displaySongs.length,
                          onReorder: _handleReorder,
                          itemBuilder: (context, index) {
                            final song = _displaySongs[index];
                            return SongListItem(
                              key: ValueKey('${song.bvid}_${song.cid}_$index'),
                              song: song,
                              contextList: _displaySongs,
                              onPlayAction: () {
                                Navigator.pop(context);
                              },
                              menuItems: [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit, size: 20),
                                      const SizedBox(width: 12),
                                      Text(
                                        S
                                            .of(context)
                                            .pages_library_playlist_menu_rename,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'reset_title',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.restore, size: 20),
                                      const SizedBox(width: 12),
                                      Text(
                                        S
                                            .of(context)
                                            .pages_library_playlist_menu_reset_title,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'remove_from_playlist',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete, size: 20),
                                      const SizedBox(width: 12),
                                      Text(
                                        S
                                            .of(context)
                                            .pages_library_playlist_menu_remove,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onMenuSelected: (value) async {
                                if (value == 'rename') {
                                  _showRenameDialog(song);
                                } else if (value == 'reset_title') {
                                  await DatabaseService()
                                      .resetLocalPlaylistSongTitle(
                                        _playlist.id,
                                        song.bvid,
                                        song.cid,
                                      );
                                  _loadSongs();
                                } else if (value == 'remove_from_playlist') {
                                  await DatabaseService()
                                      .removeSongFromLocalPlaylist(
                                        _playlist.id,
                                        song.bvid,
                                        song.cid,
                                      );
                                  _loadSongs();
                                  widget.onUpdate();
                                }
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
