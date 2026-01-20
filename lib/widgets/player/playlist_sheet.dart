import 'package:flutter/material.dart';
import 'package:utopia_music/models/song.dart';

class PlaylistSheet extends StatelessWidget {
  final List<Song> playlist;
  final Song? currentSong;
  final Function(Song) onSongSelected;

  const PlaylistSheet({
    super.key,
    required this.playlist,
    required this.currentSong,
    required this.onSongSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '播放列表 (${playlist.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: playlist.length,
              itemBuilder: (context, index) {
                final song = playlist[index];
                final isPlaying = song.bvid == currentSong?.bvid && song.cid == currentSong?.cid;
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      image: DecorationImage(
                        image: NetworkImage(song.coverUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  title: Text(
                    song.title,
                    style: TextStyle(
                      color: isPlaying ? Theme.of(context).colorScheme.primary : null,
                      fontWeight: isPlaying ? FontWeight.bold : null,
                    ),
                  ),
                  subtitle: Text(song.artist),
                  trailing: isPlaying 
                      ? Icon(
                          Icons.graphic_eq,
                          color: Theme.of(context).colorScheme.primary,
                        ) 
                      : null,
                  onTap: () {
                    onSongSelected(song);
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
