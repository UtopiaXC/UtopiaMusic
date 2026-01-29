import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/widgets/player/components/swipeable_player_card.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "MINI_PLAYER_CARD";

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
    // Log.v(_tag, "build");
    final colorScheme = Theme.of(context).colorScheme;
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    Song? previousSong;
    Song? nextSong;
    final playlist = playerProvider.playlist;
    final currentIndex = playlist.indexWhere(
      (s) => s.bvid == song.bvid && s.cid == song.cid,
    );

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

    Widget buildContent(Song displaySong) {
      final String optimizedCover = displaySong.coverUrl.isNotEmpty
          ? '${displaySong.coverUrl}@100w_100h.webp'
          : '';

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
              tooltip: S.of(context).common_close,
            ),
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(left: 0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                image: displaySong.coverUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(optimizedCover),
                        fit: BoxFit.cover,
                        onError: (exception, stackTrace) {},
                      )
                    : null,
              ),
              child: displaySong.coverUrl.isEmpty
                  ? Center(
                      child: Icon(
                        Icons.music_note,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 24,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final textStyle = Theme.of(
                          context,
                        ).textTheme.titleMedium;
                        final textSpan = TextSpan(
                          text: displaySong.title,
                          style: textStyle,
                        );
                        final textPainter = TextPainter(
                          text: textSpan,
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                        );
                        textPainter.layout();

                        if (textPainter.width > constraints.maxWidth) {
                          return Marquee(
                            text: displaySong.title,
                            style: textStyle,
                            scrollAxis: Axis.horizontal,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            blankSpace: 20.0,
                            velocity: 30.0,
                            pauseAfterRound: const Duration(seconds: 1),
                            startPadding: 0.0,
                            accelerationDuration: const Duration(seconds: 1),
                            accelerationCurve: Curves.linear,
                            decelerationDuration: const Duration(
                              milliseconds: 500,
                            ),
                            decelerationCurve: Curves.easeOut,
                          );
                        } else {
                          return Text(
                            displaySong.title,
                            style: textStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        }
                      },
                    ),
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
            const SizedBox(width: 8),
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
              onPressed: playerProvider.hasNext
                  ? () => playerProvider.playNext()
                  : null,
              icon: const Icon(Icons.skip_next),
              color: playerProvider.hasNext
                  ? null
                  : Theme.of(context).disabledColor,
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
        onPrevious: playerProvider.hasPrevious
            ? () => playerProvider.playPrevious()
            : null,
        previousChild: previousSong != null ? buildContent(previousSong) : null,
        nextChild: nextSong != null ? buildContent(nextSong) : null,
        child: buildContent(song),
      ),
    );
  }
}
