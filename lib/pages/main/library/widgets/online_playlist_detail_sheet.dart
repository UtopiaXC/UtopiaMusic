import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/connection/video/discover.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_category_widget.dart';
import 'package:utopia_music/providers/library_provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/widgets/song_list/song_list_item.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/connection/video/library.dart';

class OnlinePlaylistDetailSheet extends StatefulWidget {
  final PlaylistInfo playlistInfo;

  const OnlinePlaylistDetailSheet({
    super.key,
    required this.playlistInfo,
  });

  @override
  State<OnlinePlaylistDetailSheet> createState() => _OnlinePlaylistDetailSheetState();
}

class _OnlinePlaylistDetailSheetState extends State<OnlinePlaylistDetailSheet> {
  List<Song> _songs = [];
  bool _isLoading = true;
  final VideoApi _videoApi = VideoApi();
  final LibraryApi _libraryApi = LibraryApi();

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    try {
      final mediaId = widget.playlistInfo.id;
      final songs = await _libraryApi.getFavoriteResources(mediaId, context);
      
      if (mounted) {
        setState(() {
          _songs = songs;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading online playlist songs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleClone() async {
    if (_songs.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final id = await DatabaseService().createLocalPlaylist(
        widget.playlistInfo.title,
        'Cloned from Bilibili',
      );
      
      for (var song in _songs) {
        await DatabaseService().addSongToLocalPlaylist(id, song);
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已克隆到本地歌单')),
        );
        Provider.of<LibraryProvider>(context, listen: false).refreshLibrary(localOnly: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('克隆失败: $e')),
        );
      }
    }
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

    await playerProvider.setPlaylistAndPlay(_songs, _songs.first);
    if (mounted) {
      Navigator.pop(context);
    }
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
                            image: widget.playlistInfo.coverUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(widget.playlistInfo.coverUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: Stack(
                            children: [
                              if (widget.playlistInfo.coverUrl.isEmpty)
                                Center(child: Icon(Icons.music_note, size: 48, color: colorScheme.onSurfaceVariant)),
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${widget.playlistInfo.count}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.playlistInfo.title,
                                style: Theme.of(context).textTheme.titleLarge,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${widget.playlistInfo.count}首',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSecondaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
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
                        label: const Text('播放'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _handleClone,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('克隆到本地'),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
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
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _songs.length,
                            itemBuilder: (context, index) {
                              final song = _songs[index];
                              return SongListItem(
                                song: song,
                                contextList: _songs,
                                onPlayAction: () {
                                  Navigator.pop(context);
                                },
                                menuItems: const [],
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
