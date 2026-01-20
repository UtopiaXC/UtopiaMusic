import 'package:flutter/material.dart';

class PlayerControls extends StatelessWidget {
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onShuffle; // 实际上是切换循环模式
  final VoidCallback onPlaylist;
  final bool isPlaying;
  final bool isLoading;
  final Duration duration;
  final Duration position;
  final ValueChanged<double> onSeek;
  final ValueChanged<double>? onSeekStart;
  final ValueChanged<double>? onSeekUpdate;
  final int loopMode; // 0-列表顺序, 1-列表循环, 2-单曲循环, 3-随机播放

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

  IconData _getLoopModeIcon() {
    switch (loopMode) {
      case 0: return Icons.repeat; // 列表顺序 (暂时用 repeat 表示，通常顺序播放没有特定图标或用灰色 repeat)
      case 1: return Icons.repeat; // 列表循环
      case 2: return Icons.repeat_one; // 单曲循环
      case 3: return Icons.shuffle; // 随机播放
      default: return Icons.repeat;
    }
  }
  
  Color? _getLoopModeColor(BuildContext context) {
    // 列表顺序通常显示为灰色，其他模式显示为激活色
    if (loopMode == 0) {
      return Theme.of(context).disabledColor;
    }
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final maxDuration = duration.inSeconds.toDouble();
    final currentPosition = position.inSeconds.toDouble();
    final sliderValue = currentPosition > maxDuration ? maxDuration : currentPosition;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 进度条
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
        const SizedBox(height: 20),
        // 控制按钮行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: onShuffle,
              icon: Icon(_getLoopModeIcon()),
              color: _getLoopModeColor(context),
              tooltip: '切换播放模式',
            ),
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.skip_previous, size: 32),
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
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 32,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
              ),
            ),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.skip_next, size: 32),
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
