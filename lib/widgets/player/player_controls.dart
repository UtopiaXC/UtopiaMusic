import 'package:flutter/material.dart';

class PlayerControls extends StatelessWidget {
  final VoidCallback onPlayPause;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback onShuffle;
  final VoidCallback onPlaylist;
  final bool isPlaying;
  final bool isLoading;
  final Duration duration;
  final Duration position;
  final ValueChanged<double> onSeek;
  final ValueChanged<double>? onSeekStart;
  final ValueChanged<double>? onSeekUpdate;
  final int loopMode;

  const PlayerControls({
    super.key,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onShuffle,
    required this.onPlaylist,
    this.isPlaying = false,
    this.isLoading = false,
    this.duration = Duration.zero,
    this.position = Duration.zero,
    required this.onSeek,
    this.onSeekStart,
    this.onSeekUpdate,
    this.loopMode = 0,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _getLoopModeIcon(BuildContext context) {
    switch (loopMode) {
      case 0: // Sequence
        return const Icon(Icons.repeat, color: Colors.grey);
      case 1: // Loop
        return const Icon(Icons.repeat);
      case 2: // Single
        return const Icon(Icons.repeat_one);
      case 3: // Shuffle
        return const Icon(Icons.shuffle);
      default:
        return const Icon(Icons.repeat, color: Colors.grey);
    }
  }
  
  Color? _getLoopModeColor(BuildContext context) {
    if (loopMode == 0) {
      return Theme.of(context).disabledColor;
    }
    return Theme.of(context).colorScheme.primary;
  }

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxDuration = duration.inSeconds.toDouble();
    final currentPosition = position.inSeconds.toDouble();
    final sliderValue = currentPosition > maxDuration ? maxDuration : currentPosition;
    
    final isCompleted = !isPlaying && duration > Duration.zero && position >= duration;
    final showPlayIcon = !isPlaying || isCompleted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top Controls (Timer, Free Play, Collection, Comment, Info)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: () => _showToast(context, '定时停止 - 功能正在开发中'),
              icon: const Icon(Icons.timer_outlined),
              tooltip: '定时停止',
            ),
            IconButton(
              onPressed: () => _showToast(context, '自由连播 - 功能正在开发中'),
              icon: const Icon(Icons.auto_awesome_motion),
              tooltip: '自由连播',
            ),
            IconButton(
              onPressed: () => _showToast(context, '合集 - 功能正在开发中'),
              icon: const Icon(Icons.subscriptions_outlined),
              tooltip: '合集',
            ),
            IconButton(
              onPressed: () => _showToast(context, '评论 - 功能正在开发中'),
              icon: const Icon(Icons.comment_outlined),
              tooltip: '评论',
            ),
            IconButton(
              onPressed: () => _showToast(context, '详情 - 功能正在开发中'),
              icon: const Icon(Icons.info_outline),
              tooltip: '详情',
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Progress Bar
        Slider(
          value: sliderValue,
          min: 0,
          max: maxDuration > 0 ? maxDuration : 1.0,
          onChanged: onSeekUpdate ?? onSeek,
          onChangeStart: onSeekStart,
          onChangeEnd: onSeek,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(position), style: Theme.of(context).textTheme.bodySmall),
              Text(_formatDuration(duration), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Playback Controls (Mode, Prev, Play/Pause, Next, Playlist)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: onShuffle,
              icon: _getLoopModeIcon(context),
              color: _getLoopModeColor(context),
              tooltip: '切换播放模式',
            ),
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.skip_previous, size: 36),
              tooltip: '上一首',
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: IconButton(
                onPressed: isLoading ? null : onPlayPause,
                icon: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                        ),
                      )
                    : Icon(
                        showPlayIcon ? Icons.play_arrow : Icons.pause,
                        size: 32,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
              ),
            ),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.skip_next, size: 36),
              tooltip: '下一首',
            ),
            IconButton(
              onPressed: onPlaylist,
              icon: const Icon(Icons.playlist_play),
              tooltip: '播放列表',
            ),
          ],
        ),
      ],
    );
  }
}
