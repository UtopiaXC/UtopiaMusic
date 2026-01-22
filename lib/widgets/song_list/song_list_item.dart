import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';

class SongListItem extends StatelessWidget {
  final Song song;
  final List<Song> contextList;
  final List<PopupMenuEntry<String>>? menuItems;
  final void Function(String)? onMenuSelected;

  const SongListItem({
    super.key,
    required this.song,
    required this.contextList,
    this.menuItems,
    this.onMenuSelected,
  });

  void _showPlayOptionsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: const Text('用当前列表替换播放列表'),
              onTap: () {
                Navigator.pop(context);
                Provider.of<PlayerProvider>(context, listen: false)
                    .setPlaylistAndPlay(contextList, song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('插入到当前播放音乐后'),
              onTap: () {
                Navigator.pop(context);
                Provider.of<PlayerProvider>(context, listen: false).insertNext(song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('插入到当前音乐后并立刻播放'),
              onTap: () {
                Navigator.pop(context);
                Provider.of<PlayerProvider>(context, listen: false)
                    .insertNextAndPlay(song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_check),
              title: const Text('添加到播放列表末尾'),
              onTap: () {
                Navigator.pop(context);
                Provider.of<PlayerProvider>(context, listen: false).addToEnd(song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_calls),
              title: const Text('用该单曲替换播放列表'),
              onTap: () {
                Navigator.pop(context);
                Provider.of<PlayerProvider>(context, listen: false)
                    .replacePlaylistWithSong(song);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('取消'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    FocusScope.of(context).unfocus();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    if (playerProvider.playlist.isEmpty) {
      playerProvider.setPlaylistAndPlay(contextList, song);
      playerProvider.expandPlayer(); // Expand player when starting from empty
    } else {
      _showPlayOptionsDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String optimizedCover =
        song.coverUrl.isNotEmpty ? '${song.coverUrl}@100w_100h.webp' : '';

    return InkWell(
      onTap: () => _handleTap(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Color(song.colorValue),
                borderRadius: BorderRadius.circular(4),
                image: song.coverUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(optimizedCover),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: song.coverUrl.isEmpty
                  ? const Center(
                      child: Icon(
                        Icons.music_note,
                        color: Colors.white,
                        size: 24,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song.artist,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (value) {
                if (value == 'add_to_playlist') {
                  _showPlayOptionsDialog(context);
                } else if (onMenuSelected != null) {
                  onMenuSelected!(value);
                }
              },
              itemBuilder: (context) {
                final List<PopupMenuEntry<String>> items = [
                  const PopupMenuItem(
                    value: 'add_to_playlist',
                    child: Text('添加到播放列表'),
                  ),
                ];
                if (menuItems != null) {
                  items.addAll(menuItems!);
                }
                return items;
              },
            ),
          ],
        ),
      ),
    );
  }
}
