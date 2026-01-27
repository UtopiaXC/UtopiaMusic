import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/models/play_mode.dart';
import 'package:utopia_music/providers/player_provider.dart';

class PlayerControls extends StatelessWidget {
  final VoidCallback onPlayPause;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback onShuffle;
  final VoidCallback onPlaylist;
  final VoidCallback? onLyrics;
  final VoidCallback? onTimer;
  final VoidCallback? onComment;
  final VoidCallback? onInfo;
  final VoidCallback? onMore;
  final bool isPlaying;
  final bool isLoading;
  final Duration duration;
  final Duration position;
  final ValueChanged<double> onSeek;
  final ValueChanged<double>? onSeekStart;
  final ValueChanged<double>? onSeekUpdate;
  final PlayMode loopMode;
  final bool hideExtraControls;
  final bool showLyricsButtonOnly;

  const PlayerControls({
    super.key,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onShuffle,
    required this.onPlaylist,
    this.onLyrics,
    this.onTimer,
    this.onComment,
    this.onInfo,
    this.onMore,
    this.isPlaying = false,
    this.isLoading = false,
    this.duration = Duration.zero,
    this.position = Duration.zero,
    required this.onSeek,
    this.onSeekStart,
    this.onSeekUpdate,
    this.loopMode = PlayMode.sequence,
    this.hideExtraControls = false,
    this.showLyricsButtonOnly = false,
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

  Widget _getSpeedIcon(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final speed = playerProvider.player.speed;

    String text;
    if (speed == 1.0) {
      text = "1.0x";
    } else if (speed == 0.5) {
      text = "0.5x";
    } else if (speed == 0.75) {
      text = "0.7x";
    } else if (speed == 1.25) {
      text = "1.2x";
    } else if (speed == 1.5) {
      text = "1.5x";
    } else if (speed == 2.0) {
      text = "2.0x";
    } else {
      text = "${speed}x";
    }

    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).iconTheme.color,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxDuration = duration.inSeconds.toDouble();
    final currentPosition = position.inSeconds.toDouble();
    final sliderValue = currentPosition > maxDuration
        ? maxDuration
        : currentPosition;

    final isCompleted =
        !isPlaying && duration > Duration.zero && position >= duration;
    final showPlayIcon = !isPlaying || isCompleted;

    final playerProvider = Provider.of<PlayerProvider>(context);
    final isTimerActive = playerProvider.isTimerActive;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hideExtraControls)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: onLyrics,
                icon: const Icon(Icons.lyrics_outlined),
                tooltip: S.of(context).common_lyrics,
              ),
              if (!showLyricsButtonOnly) ...[
                IconButton(
                  onPressed: onTimer,
                  icon: Icon(
                    Icons.timer_outlined,
                    color: isTimerActive
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  tooltip: S.of(context).play_control_mode_timer_stop,
                ),
                IconButton(
                  onPressed: onComment,
                  icon: const Icon(Icons.high_quality),
                  tooltip: S.of(context).common_audio_quality,
                ),
                IconButton(
                  onPressed: onInfo,
                  icon: _getSpeedIcon(context),
                  tooltip: S.of(context).common_audio_speed,
                ),
                IconButton(
                  onPressed: onMore,
                  icon: const Icon(Icons.info_outline),
                  tooltip: S.of(context).common_detail,
                ),
              ] else ...[
                const IconButton(
                  onPressed: null,
                  icon: Icon(Icons.timer_outlined, color: Colors.transparent),
                ),
                const IconButton(
                  onPressed: null,
                  icon: Icon(Icons.high_quality, color: Colors.transparent),
                ),
                const IconButton(
                  onPressed: null,
                  icon: Icon(Icons.speed, color: Colors.transparent),
                ),
                const IconButton(
                  onPressed: null,
                  icon: Icon(Icons.info_outline, color: Colors.transparent),
                ),
              ],
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
              Text(
                _formatDuration(position),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (isTimerActive && playerProvider.stopTime != null)
                Consumer<PlayerProvider>(
                  builder: (context, provider, child) {
                    final remaining = provider.stopTime!.difference(
                      DateTime.now(),
                    );
                    if (remaining.isNegative) return const SizedBox.shrink();

                    String text;
                    if (provider.stopAfterCurrent && remaining.inSeconds <= 0) {
                      text = S.of(context).weight_player_timer_stop_at_end;
                    } else {
                      final hours = remaining.inHours;
                      final minutes = remaining.inMinutes % 60;
                      final seconds = remaining.inSeconds % 60;
                      text =
                          '${S.of(context).weight_player_timer_over_discount}${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
                      if (provider.stopAfterCurrent) {
                        text += ' ${S.of(context).weight_player_timer_over_at}';
                      }
                    }
                    return Text(
                      text,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              Text(
                _formatDuration(duration),
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
                        child: CircularProgressIndicator(strokeWidth: 2.5),
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
