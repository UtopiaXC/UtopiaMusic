import 'package:flutter/material.dart';
import 'package:utopia_music/models/song.dart';

class MiniPlayer extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onClose;
  final bool isPlaying;

  const MiniPlayer({
    super.key,
    required this.song,
    required this.onTap,
    required this.onPlayPause,
    required this.onNext,
    required this.onClose,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 关闭按钮
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 20),
              tooltip: '关闭',
            ),
            // 迷你封面
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(left: 0),
              decoration: BoxDecoration(
                color: Color(song.colorValue),
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(song.coverUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 标题和歌手
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    song.artist,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 迷你控制按钮
            // 播放按钮改为圆形背景
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
              onPressed: onNext,
              icon: const Icon(Icons.skip_next),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
