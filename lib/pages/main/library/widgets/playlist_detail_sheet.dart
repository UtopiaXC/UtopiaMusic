import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/services/database_service.dart';
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
  bool _isLoading = true;

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
    final updatedPlaylist = playlists.firstWhere((p) => p.id == _playlist.id, orElse: () => _playlist);
    
    if (mounted) {
      setState(() {
        _songs = songs;
        _playlist = updatedPlaylist;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleEdit() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PlaylistFormSheet(
        initialTitle: _playlist.title,
        initialDescription: _playlist.description,
        onSubmit: (title, description) async {
          await DatabaseService().updateLocalPlaylist(_playlist.id, title, description);
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
        title: const Text('确认删除'),
        content: Text('确定要删除歌单 "${_playlist.title}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
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
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePlay() async {
    if (_songs.isEmpty) return;
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    if (playerProvider.playlist.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('替换播放列表'),
          content: const Text('当前播放列表不为空，是否替换？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(S.of(context).common_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('替换'),
            ),
          ],
        ),
      );
      
      if (confirm != true) return;
    }

    if (mounted) {
      Navigator.pop(context);
    }
    await playerProvider.setPlaylistAndPlay(_songs, _songs.first);
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final song = _songs.removeAt(oldIndex);
    _songs.insert(newIndex, song);
    setState(() {});

    await DatabaseService().updateLocalPlaylistSongOrder(_playlist.id, oldIndex, newIndex);
  }

  void _showRenameDialog(Song song) {
    final controller = TextEditingController(text: song.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '标题'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
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
            child: const Text('确认'),
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
                              ? Icon(Icons.music_note, size: 48, color: colorScheme.onSurfaceVariant)
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
                                _playlist.description.isEmpty ? '暂无描述' : _playlist.description,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
              // Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _handlePlay,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('播放'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _handleEdit,
                      icon: const Icon(Icons.edit),
                      tooltip: '编辑信息',
                    ),
                    IconButton(
                      onPressed: _handleDelete,
                      icon: const Icon(Icons.delete),
                      tooltip: '删除歌单',
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Song List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _songs.isEmpty
                        ? GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onVerticalDragUpdate: (details) {
                              if (details.primaryDelta! > 10) {
                                Navigator.pop(context);
                              }
                            },
                            child: const Center(child: Text('暂无歌曲')),
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is ScrollUpdateNotification) {
                                if (notification.metrics.pixels <= 0 && notification.scrollDelta! < 0) {

                                }
                              }
                              return false;
                            },
                            child: ReorderableListView.builder(
                              scrollController: scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _songs.length,
                              onReorder: _handleReorder,
                              itemBuilder: (context, index) {
                                final song = _songs[index];
                                return SongListItem(
                                  key: ValueKey('${song.bvid}_${song.cid}'),
                                  song: song,
                                  contextList: _songs,
                                  onPlayAction: () {
                                    Navigator.pop(context);
                                  },
                                  menuItems: [
                                    const PopupMenuItem(
                                      value: 'rename',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 20),
                                          SizedBox(width: 12),
                                          Text('重命名'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'reset_title',
                                      child: Row(
                                        children: [
                                          Icon(Icons.restore, size: 20),
                                          SizedBox(width: 12),
                                          Text('重置为原标题'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'remove_from_playlist',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 20),
                                          SizedBox(width: 12),
                                          Text('从歌单中删除'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onMenuSelected: (value) async {
                                    if (value == 'rename') {
                                      _showRenameDialog(song);
                                    } else if (value == 'reset_title') {
                                      await DatabaseService().resetLocalPlaylistSongTitle(_playlist.id, song.bvid, song.cid);
                                      _loadSongs();
                                    } else if (value == 'remove_from_playlist') {
                                      await DatabaseService().removeSongFromLocalPlaylist(_playlist.id, song.bvid, song.cid);
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
