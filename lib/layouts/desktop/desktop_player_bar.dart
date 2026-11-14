import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/connection/video/video_detail.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/models/play_mode.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/sponsor_block_provider.dart';
import 'package:utopia_music/theme/app_theme.dart';
import 'package:utopia_music/widgets/common/liquid_glass_container.dart';
import 'package:utopia_music/widgets/player/components/segment_slider_track_shape.dart';
import 'package:utopia_music/widgets/player/dialogs/sb_detail_dialog.dart';
import 'package:utopia_music/widgets/song_list/add_to_playlist_sheet.dart';
import 'package:utopia_music/widgets/user/space_sheet.dart';

/// Persistent full-width desktop bottom playback bar inspired by Biu.
class DesktopPlayerBar extends StatefulWidget {
  final Song song;
  final bool isQueueOpen;
  final VoidCallback onToggleQueue;
  final VoidCallback onExpandPlayer;

  const DesktopPlayerBar({
    super.key,
    required this.song,
    required this.isQueueOpen,
    required this.onToggleQueue,
    required this.onExpandPlayer,
  });

  @override
  State<DesktopPlayerBar> createState() => _DesktopPlayerBarState();
}

class _DesktopPlayerBarState extends State<DesktopPlayerBar> {
  final VideoDetailApi _videoDetailApi = VideoDetailApi();
  bool _isDragging = false;
  double _dragValue = 0.0;

  Future<void> _showArtistSpace(BuildContext context, Song song) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.isLiveMode) {
      final uid = playerProvider.currentLiveRoom?.uid ?? 0;
      if (uid > 0) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (sheetContext) => SpaceSheet(mid: uid),
        );
      }
      return;
    }
    if (song.bvid.isEmpty) return;
    final detail = await _videoDetailApi.getVideoDetail(song.bvid);
    if (!context.mounted) return;
    final mid = detail?['owner']?['mid'];
    if (mid is int && mid > 0) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => SpaceSheet(mid: mid),
      );
    }
  }

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

  IconData _playModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequence:
        return Icons.playlist_play_rounded;
      case PlayMode.loop:
        return Icons.repeat_rounded;
      case PlayMode.single:
        return Icons.repeat_one_rounded;
      case PlayMode.shuffle:
        return Icons.shuffle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final sbProvider = Provider.of<SponsorBlockProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final bool isLiquidGlass = AppTheme.isLiquidGlass(context);
    final bool isLiveMode = playerProvider.isLiveMode;
    final glass = AppTheme.glassOf(context);
    final song = widget.song;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color barColor = isLiquidGlass
        ? Colors.transparent
        : colorScheme.surfaceContainer;
    final Color borderColor = isLiquidGlass
        ? glass.borderColor.withValues(alpha: 0.45)
        : colorScheme.outlineVariant.withValues(alpha: 0.35);

    final bool isLoading =
        !playerProvider.hasLiveError &&
        (playerProvider.isLiveLoading ||
            playerProvider.player.processingState == ProcessingState.buffering ||
            playerProvider.player.processingState == ProcessingState.loading);

    final barContent = Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: barColor,
        border: isLiquidGlass
            ? null
            : Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 270,
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: widget.onExpandPlayer,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: song.coverUrl.isNotEmpty
                        ? Image.network(
                            '${song.coverUrl}@120w_120h.webp',
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _FallbackCover(colorScheme: colorScheme),
                          )
                        : _FallbackCover(colorScheme: colorScheme),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: widget.onExpandPlayer,
                        child: SizedBox(
                          height: 22,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              const style = TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              );
                              final painter = TextPainter(
                                text: TextSpan(text: song.title, style: style),
                                textDirection: TextDirection.ltr,
                                maxLines: 1,
                              )..layout();
                              if (painter.width > constraints.maxWidth &&
                                  constraints.maxWidth > 0) {
                                return RepaintBoundary(
                                  child: ClipRect(
                                    child: Marquee(
                                      text: song.title,
                                      style: style,
                                      blankSpace: 24.0,
                                      velocity: 28.0,
                                      pauseAfterRound: const Duration(
                                        seconds: 1,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return Text(
                                song.title,
                                style: style,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showArtistSpace(context, song),
                        child: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLiveMode &&
                    sbProvider.enableSponsorBlock &&
                    sbProvider.currentSegments.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.shield_outlined, size: 18),
                    tooltip: '片段信息',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => SBDetailDialog(
                          onSeek: (target) =>
                              playerProvider.player.seek(target),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 19,
                          visualDensity: VisualDensity.compact,
                          onPressed:
                              (isLiveMode ||
                                  playerProvider.recommendationAutoPlay)
                              ? null
                              : playerProvider.togglePlayMode,
                          icon: Icon(_playModeIcon(playerProvider.playMode)),
                          tooltip: S
                              .of(context)
                              .weight_play_control_label_switch_paly_mode,
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          iconSize: 24,
                          visualDensity: VisualDensity.compact,
                          onPressed: playerProvider.hasPrevious
                              ? () => playerProvider.playPrevious()
                              : null,
                          icon: const Icon(Icons.skip_previous_rounded),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary,
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 22,
                            color: colorScheme.onPrimary,
                            onPressed: playerProvider.togglePlayPause,
                            icon: isLoading
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.onPrimary,
                                    ),
                                  )
                                : Icon(
                                    playerProvider.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          iconSize: 24,
                          visualDensity: VisualDensity.compact,
                          onPressed: playerProvider.hasNext
                              ? () => playerProvider.playNext()
                              : null,
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                        const SizedBox(width: 6),
                        if (sbProvider.manualPromptSegment != null)
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              '跳过: ${sbProvider.manualPromptSegment!.segmentType.shortTitle}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () {
                              final prompt = sbProvider.manualPromptSegment;
                              if (prompt == null) return;
                              sbProvider.skipManualSegment(
                                prompt,
                                seekTo: (pos) =>
                                    playerProvider.player.seek(pos),
                                showToast: (msg) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(msg),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              );
                            },
                          )
                        else
                          const SizedBox(width: 32),
                      ],
                    ),
                    RepaintBoundary(
                      child: StreamBuilder<Duration?>(
                        stream: playerProvider.player.durationStream,
                        builder: (context, durationSnap) {
                          final duration = durationSnap.data ?? Duration.zero;
                          return StreamBuilder<Duration>(
                            stream: playerProvider.player.positionStream,
                            builder: (context, posSnap) {
                              final position = posSnap.data ?? Duration.zero;
                              final maxSeconds = duration.inSeconds.toDouble();
                              final currentSeconds = _isDragging
                                  ? _dragValue
                                  : position.inSeconds.toDouble();
                              final sliderVal = maxSeconds > 0
                                  ? currentSeconds.clamp(0.0, maxSeconds)
                                  : 0.0;

                              final slider = Slider(
                                value: isLiveMode ? 0.0 : sliderVal,
                                min: 0,
                                max: (!isLiveMode && maxSeconds > 0)
                                    ? maxSeconds
                                    : 1.0,
                                onChangeStart: isLiveMode
                                    ? null
                                    : (v) {
                                        setState(() {
                                          _isDragging = true;
                                          _dragValue = v;
                                        });
                                      },
                                onChanged: isLiveMode
                                    ? null
                                    : (v) {
                                        setState(() {
                                          _dragValue = v;
                                        });
                                      },
                                onChangeEnd: isLiveMode
                                    ? null
                                    : (v) {
                                        setState(() {
                                          _isDragging = false;
                                        });
                                        playerProvider.seek(
                                          Duration(seconds: v.toInt()),
                                        );
                                      },
                              );

                              final themedSlider =
                                  (!isLiveMode &&
                                      sbProvider.enableSponsorBlock &&
                                      sbProvider.currentSegments.isNotEmpty &&
                                      sbProvider.currentSongBvid == song.bvid &&
                                      duration > Duration.zero)
                                  ? SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 3,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 5,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 10,
                                            ),
                                        trackShape: SegmentSliderTrackShape(
                                          segments: sbProvider.currentSegments,
                                          duration: duration,
                                          blockColor: sbProvider.blockColor,
                                        ),
                                      ),
                                      child: slider,
                                    )
                                  : SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 3,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 5,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 10,
                                            ),
                                      ),
                                      child: slider,
                                    );

                              return Row(
                                children: [
                                  Text(
                                    isLiveMode
                                        ? S.of(context).live_badge_live
                                        : _formatDuration(
                                            Duration(seconds: sliderVal.toInt()),
                                          ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isLiveMode
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: isLiveMode
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  Expanded(child: themedSlider),
                                  Text(
                                    isLiveMode
                                        ? '--:--'
                                        : _formatDuration(duration),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isLiveMode
                                          ? Theme.of(context).disabledColor
                                          : colorScheme.onSurfaceVariant,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PopupMenuButton<double>(
                enabled: !isLiveMode,
                tooltip: S.of(context).desktop_player_speed,
                onSelected: playerProvider.player.setSpeed,
                itemBuilder: (context) => [0.75, 1.0, 1.25, 1.5, 2.0]
                    .map(
                      (speed) => PopupMenuItem<double>(
                        value: speed,
                        child: Text('${speed}x'),
                      ),
                    )
                    .toList(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    isLiveMode ? '1.0x' : '${playerProvider.player.speed}x',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isLiveMode
                          ? Theme.of(context).disabledColor
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              IconButton(
                iconSize: 20,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                tooltip: S.of(context).desktop_player_lyrics,
                onPressed: playerProvider.expandToLyrics,
                icon: const Icon(Icons.lyrics_outlined),
              ),
              IconButton(
                iconSize: 20,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: isLiveMode
                    ? null
                    : () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => AddToPlaylistSheet(song: song),
                        );
                      },
                icon: const Icon(Icons.playlist_add_outlined),
              ),
              IconButton(
                iconSize: 20,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                color: (!isLiveMode && widget.isQueueOpen)
                    ? colorScheme.primary
                    : null,
                tooltip: S.of(context).weight_play_list_label_name,
                onPressed: isLiveMode ? null : widget.onToggleQueue,
                icon: const Icon(Icons.queue_music_rounded),
              ),
              IconButton(
                iconSize: 19,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                tooltip: S.of(context).common_close,
                onPressed: playerProvider.closePlayer,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ],
      ),
    );
    if (!isLiquidGlass) {
      return barContent;
    }
    return LiquidGlassContainer(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      borderRadius: BorderRadius.circular(26),
      highContrastScrim: true,
      refractionStrength: 20.0,
      bezelWidth: 18.0,
      blurSigma: 16.0,
      chromaticAberration: 1.5,
      tintColor: isDark
          ? const Color(0xFF141926).withValues(alpha: 0.82)
          : const Color(0xFFF7FAFF).withValues(alpha: 0.80),
      child: barContent,
    );
  }
}

class _FallbackCover extends StatelessWidget {
  final ColorScheme colorScheme;

  const _FallbackCover({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      color: colorScheme.primaryContainer,
      child: Icon(
        Icons.music_note,
        color: colorScheme.onPrimaryContainer,
        size: 22,
      ),
    );
  }
}
