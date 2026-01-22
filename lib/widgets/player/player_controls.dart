import 'package:flutter/material.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/models/play_mode.dart';

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
  final PlayMode loopMode;

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
    this.loopMode = PlayMode.sequence,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Widget _getLoopModeIcon(BuildContext context) {
    switch (loopMode) {
      case PlayMode.sequence:
        return const Icon(Icons.repeat, color: Colors.grey);
      case PlayMode.loop:
        return const Icon(Icons.repeat);
      case PlayMode.single:
        return const Icon(Icons.repeat_one);
      case PlayMode.shuffle:
        return const Icon(Icons.shuffle);
      }
  }
  
  Color? _getLoopModeColor(BuildContext context) {
    if (loopMode == PlayMode.sequence) {
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: () => _showToast(context, '定时停止 - 功能正在开发中'),
              icon: const Icon(Icons.timer_outlined),
              tooltip: S.of(context).play_control_mode_timer_stop
            ),
            IconButton(
              onPressed: () => _showToast(context, '自由连播 - 功能正在开发中'),
              icon: const Icon(Icons.auto_awesome_motion),
              tooltip: S.of(context).play_control_mode_random_continue,
            ),
            IconButton(
              onPressed: () => _showToast(context, '合集 - 功能正在开发中'),
              icon: const Icon(Icons.subscriptions_outlined),
              tooltip: S.of(context).play_control_mode_random_collection,
            ),
            IconButton(
              onPressed: () => _showToast(context, '评论 - 功能正在开发中'),
              icon: const Icon(Icons.comment_outlined),
              tooltip:  S.of(context).play_control_mode_random_comment,
            ),
            IconButton(
              onPressed: () => _showToast(context, '详情 - 功能正在开发中'),
              icon: const Icon(Icons.info_outline),
              tooltip:  S.of(context).play_control_mode_random_info,
            ),
          ],
        ),
        const SizedBox(height: 16),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: onShuffle,
              icon: _getLoopModeIcon(context),
              color: _getLoopModeColor(context),
              tooltip: S.of(context).weight_play_control_label_switch_paly_mode,
            ),
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.skip_previous, size: 36),
              tooltip: S.of(context).play_control_previous,
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
              tooltip: S.of(context).play_control_next,
            ),
            IconButton(
              onPressed: onPlaylist,
              icon: const Icon(Icons.playlist_play),
              tooltip: S.of(context).weight_play_list_label_name,
            ),
          ],
        ),
      ],
    );
  }
}
