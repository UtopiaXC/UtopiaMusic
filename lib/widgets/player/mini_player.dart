import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/widgets/player/swipeable_player_card.dart';

class MiniPlayer extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback onClose;
  final bool isPlaying;

  const MiniPlayer({
    super.key,
    required this.song,
    required this.onTap,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    Song? previousSong;
    Song? nextSong;
    final playlist = playerProvider.playlist;
    final currentIndex = playlist.indexWhere((s) => s.bvid == song.bvid && s.cid == song.cid);

    if (currentIndex != -1 && playlist.isNotEmpty) {
       if (playerProvider.hasPrevious) {
         int prevIndex = currentIndex - 1;
         if (prevIndex < 0) prevIndex = playlist.length - 1;
         previousSong = playlist[prevIndex];
       }
       if (playerProvider.hasNext) {
         int nextIndex = currentIndex + 1;
         if (nextIndex >= playlist.length) nextIndex = 0;
         nextSong = playlist[nextIndex];
       }
    }

    // MiniPlayer content widget to be reused in SwipeablePlayerCard
    Widget buildContent(Song displaySong) {
      return Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 20),
              tooltip: '关闭',
            ),
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(left: 0),
              decoration: BoxDecoration(
                color: Color(displaySong.colorValue),
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(displaySong.coverUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displaySong.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    displaySong.artist,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer,
              ),
              child: IconButton(
                onPressed: onPlayPause,
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            IconButton(
              onPressed: playerProvider.hasNext ? () => playerProvider.playNext() : null,
              icon: const Icon(Icons.skip_next),
              color: playerProvider.hasNext ? null : Theme.of(context).disabledColor,
            ),
            const SizedBox(width: 8),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! < -10) {
          onTap();
        }
      },
      child: SwipeablePlayerCard(
        onNext: playerProvider.hasNext ? () => playerProvider.playNext() : null,
        onPrevious: playerProvider.hasPrevious ? () => playerProvider.playPrevious() : null,
        previousChild: previousSong != null ? buildContent(previousSong) : null,
        nextChild: nextSong != null ? buildContent(nextSong) : null,
        child: buildContent(song),
      ),
    );
  }
}
