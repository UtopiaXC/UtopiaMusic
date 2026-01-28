import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/widgets/player/components/lyrics_card.dart';
import 'package:utopia_music/widgets/player/components/player_content.dart';
import 'package:utopia_music/widgets/player/components/player_controls.dart';
import 'package:utopia_music/widgets/player/dialogs/playlist_sheet.dart';
import 'package:utopia_music/widgets/player/components/swipeable_player_card.dart';
import 'package:utopia_music/widgets/player/components/player_background.dart';
import 'package:utopia_music/widgets/player/dialogs/timer_dialog.dart';
import 'package:utopia_music/widgets/player/dialogs/quality_dialog.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/widgets/user/space_sheet.dart';
import 'package:utopia_music/connection/video/video_detail.dart';
import 'package:utopia_music/widgets/video/video_detail.dart';
import 'package:utopia_music/services/download_manager.dart';
import 'package:utopia_music/utils/scheme_launch.dart';
import 'package:utopia_music/widgets/video/favorite_sheet.dart';
import 'package:utopia_music/widgets/song_list/add_to_playlist_sheet.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "FULL_PLAYER_CARD";

class FullPlayerPage extends StatefulWidget {
  final Song song;
  final VoidCallback onCollapse;
  final Function(Song) onSongSelected;

  const FullPlayerPage({
    super.key,
    required this.song,
    required this.onCollapse,
    required this.onSongSelected,
  });

  @override
  State<FullPlayerPage> createState() => _FullPlayerPageState();
}

class _FullPlayerPageState extends State<FullPlayerPage> {
  final GlobalKey<SwipeablePlayerCardState> _swipeKey = GlobalKey();

  bool _isDragging = false;
  double _dragValue = 0.0;
  bool _showLyrics = false;
  final VideoDetailApi _videoDetailApi = VideoDetailApi();
  bool _isDownloaded = false;
  double _dragAccumulator = 0.0;
  ColorScheme? _extractedColorScheme;

  @override
  void initState() {
    super.initState();
    _checkDownloadStatus();
    _updatePalette();
  }

  @override
  void didUpdateWidget(FullPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.bvid != widget.song.bvid ||
        oldWidget.song.cid != widget.song.cid) {
      _checkDownloadStatus();
      _updatePalette();
    }
  }

  Future<void> _updatePalette() async {
    if (widget.song.coverUrl.isEmpty) return;
    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: NetworkImage(widget.song.coverUrl),
        brightness: Theme.of(context).brightness,
      );
      if (mounted) {
        setState(() {
          _extractedColorScheme = scheme;
        });
      }
    } catch (e) {
      Log.e(_tag, 'Failed to extract color', e);
    }
  }

  Future<void> _checkDownloadStatus() async {
    final isDownloaded = await DownloadManager().isDownloaded(
      widget.song.bvid,
      widget.song.cid,
    );
    if (mounted) {
      setState(() {
        _isDownloaded = isDownloaded;
      });
    }
  }

  void _onSeekStart(double value) {
    setState(() {
      _isDragging = true;
      _dragValue = value;
    });
  }

  void _onSeekUpdate(double value) {
    setState(() {
      _dragValue = value;
    });
  }

  void _onSeekEnd(double value) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final position = Duration(seconds: value.toInt());
    playerProvider.player.seek(position);

    if (!playerProvider.isPlaying ||
        playerProvider.player.processingState == ProcessingState.completed) {
      playerProvider.player.play();
    }

    setState(() {
      _isDragging = false;
    });
  }

  void _showPlaylist() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PlaylistSheet(
        playlist: playerProvider.playlist,
        currentSong: widget.song,
        onSongSelected: widget.onSongSelected,
      ),
    );
  }

  void _toggleLyrics() {
    setState(() {
      _showLyrics = !_showLyrics;
    });
  }

  void _showTimerDialog() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.isTimerActive) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(S.of(context).weight_player_stop_timer),
          content: Text(
            '${S.of(context).weight_player_timer_stop_at}: ${playerProvider.stopTime?.toString().split('.')[0]}\n是否关闭定时器？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(S.of(context).common_cancel),
            ),
            TextButton(
              onPressed: () {
                playerProvider.cancelTimer();
                Navigator.pop(context);
              },
              child: Text(S.of(context).common_close),
            ),
          ],
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => const TimerDialog(),
      );
    }
  }

  void _showSpeedDialog() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final currentSpeed = playerProvider.player.speed;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  S.of(context).weight_player_select_speed,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildSpeedOption(0.5, currentSpeed),
              _buildSpeedOption(0.75, currentSpeed),
              _buildSpeedOption(1.0, currentSpeed),
              _buildSpeedOption(1.25, currentSpeed),
              _buildSpeedOption(1.5, currentSpeed),
              _buildSpeedOption(2.0, currentSpeed),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedOption(double speed, double currentSpeed) {
    return ListTile(
      title: Text('${speed}x'),
      trailing: speed == currentSpeed
          ? const Icon(Icons.check, color: Colors.blue)
          : null,
      onTap: () {
        final playerProvider = Provider.of<PlayerProvider>(
          context,
          listen: false,
        );
        playerProvider.player.setSpeed(speed);
        Navigator.pop(context);
      },
    );
  }

  void _showQualityDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => QualityDialog(song: widget.song),
    );
  }

  void _showVideoDetail() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: VideoDetailPage(bvid: widget.song.bvid),
          );
        },
      ),
    );
  }

  Future<void> _handleDownload() async {
    if (_isDownloaded) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.of(context).common_downloaded)));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).common_confirm_title),
        content: Text(
          S.of(context).weight_video_detail_download_confirm_message,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).common_download),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DownloadManager().startDownload(widget.song);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              S.of(context).weight_video_detail_added_to_download_queue,
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleAddToFav() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final int myMid = authProvider.userInfo?.mid ?? 0;
    if (myMid == 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(S.of(context).common_tips),
          content: Text(S.of(context).weight_video_detail_please_login_first),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(S.of(context).common_confirm),
            ),
          ],
        ),
      );
      return;
    }
    try {
      final detail = await _videoDetailApi.getVideoDetail(widget.song.bvid);
      if (detail != null && detail['aid'] != null) {
        final int aid = detail['aid'];
        if (mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => FavoriteSheet(aid: aid, mid: myMid),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context).weight_player_no_video_fetched),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${S.of(context).common_failed}: $e')),
        );
      }
    }
  }

  void _handleAddToLocalPlaylist() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddToPlaylistSheet(song: widget.song),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(S.of(context).common_open_in_bilibili),
              onTap: () {
                Navigator.pop(context);
                SchemeLauncher.launchVideo(context, widget.song.bvid);
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_border),
              title: Text(
                S.of(context).common_save_in_bilibili_favourite_folder,
              ),
              onTap: () {
                Navigator.pop(context);
                _handleAddToFav();
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: Text(S.of(context).weight_song_list_add_to_local),
              onTap: () {
                Navigator.pop(context);
                _handleAddToLocalPlaylist();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.download,
                color: _isDownloaded ? Colors.green : null,
              ),
              title: Text(
                _isDownloaded
                    ? S.of(context).common_downloaded
                    : S.of(context).common_download,
              ),
              onTap: () {
                Navigator.pop(context);
                _handleDownload();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showArtistSpace(BuildContext context) async {
    if (widget.song.bvid.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final detail = await _videoDetailApi.getVideoDetail(widget.song.bvid);
      if (mounted) {
        Navigator.pop(context);
        if (detail != null && detail['owner'] != null) {
          final mid = detail['owner']['mid'];
          if (mid != null) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => SpaceSheet(mid: mid),
            );
            return;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).weight_player_no_user_fetched)),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${S.of(context).common_failed}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Log.v(_tag, "build");
    final topPadding = MediaQuery.of(context).padding.top;
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final hasNext = playerProvider.hasNext;
    final hasPrevious = playerProvider.hasPrevious;
    final backgroundMode = settingsProvider.playerBackgroundMode;

    final bool forceDark =
        backgroundMode == 'gaussian_blur' || backgroundMode == 'blur';
    final themeData = forceDark ? ThemeData.dark() : Theme.of(context);

    Song? previousSong;
    Song? nextSong;

    final playlist = playerProvider.playlist;
    final currentIndex = playlist.indexWhere(
      (s) => s.bvid == widget.song.bvid && s.cid == widget.song.cid,
    );

    if (currentIndex != -1 && playlist.isNotEmpty) {
      if (hasPrevious) {
        int prevIndex = currentIndex - 1;
        if (prevIndex < 0) prevIndex = playlist.length - 1;
        previousSong = playlist[prevIndex];
      }
      if (hasNext) {
        int nextIndex = currentIndex + 1;
        if (nextIndex >= playlist.length) nextIndex = 0;
        nextSong = playlist[nextIndex];
      }
    }
    if (hasPrevious && previousSong == null) previousSong = widget.song;
    if (hasNext && nextSong == null) nextSong = widget.song;

    return Theme(
      data: themeData,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_showLyrics) {
            _toggleLyrics();
            return;
          }
          widget.onCollapse();
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              PlayerBackground(
                coverUrl: widget.song.coverUrl,
                mode: backgroundMode,
                extractedColorScheme: _extractedColorScheme,
              ),

              Column(
                children: [
                  SizedBox(height: topPadding + 12),
                  // --- Title Bar ---
                  SizedBox(
                    height: kToolbarHeight,
                    child: NavigationToolbar(
                      leading: IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down),
                        onPressed: () {
                          if (_showLyrics) _toggleLyrics();
                          widget.onCollapse();
                        },
                        tooltip: S.of(context).common_retract,
                      ),
                      middle: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 24,
                            width: MediaQuery.of(context).size.width * 0.6,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final textStyle = TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: themeData.textTheme.bodyLarge?.color,
                                );
                                if (widget.song.title.length > 15) {
                                  // Simple length check optimization
                                  return Marquee(
                                    text: widget.song.title,
                                    style: textStyle,
                                    scrollAxis: Axis.horizontal,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    blankSpace: 20.0,
                                    velocity: 30.0,
                                    pauseAfterRound: const Duration(seconds: 1),
                                    startPadding: 0.0,
                                    accelerationDuration: const Duration(
                                      seconds: 1,
                                    ),
                                    accelerationCurve: Curves.linear,
                                    decelerationDuration: const Duration(
                                      milliseconds: 500,
                                    ),
                                    decelerationCurve: Curves.easeOut,
                                  );
                                } else {
                                  return Text(
                                    widget.song.title,
                                    style: textStyle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  );
                                }
                              },
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showArtistSpace(context),
                            behavior: HitTestBehavior.translucent,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                                horizontal: 8.0,
                              ),
                              child: Text(
                                widget.song.artist,
                                style: themeData.textTheme.bodySmall?.copyWith(
                                  decoration: TextDecoration.underline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: _showMoreMenu,
                        tooltip: S.of(context).common_more,
                      ),
                      centerMiddle: true,
                    ),
                  ),

                  // --- Main Content (Swipeable) ---
                  Expanded(
                    child: SwipeablePlayerCard(
                      key: _swipeKey,
                      onNext: hasNext ? () => playerProvider.playNext() : null,
                      onPrevious: hasPrevious
                          ? () => playerProvider.playPrevious()
                          : null,
                      previousChild: previousSong != null
                          ? GestureDetector(
                              onHorizontalDragUpdate: (details) {},
                              child: PlayerContent(song: previousSong),
                            )
                          : null,
                      nextChild: nextSong != null
                          ? GestureDetector(
                              onHorizontalDragUpdate: (details) {},
                              child: PlayerContent(song: nextSong),
                            )
                          : null,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (details) {},
                        onVerticalDragStart: (_) {
                          _dragAccumulator = 0.0;
                        },
                        onVerticalDragUpdate: (details) {
                          _dragAccumulator += details.delta.dy;
                          if (_dragAccumulator > 20) {
                            widget.onCollapse();
                            _dragAccumulator = 0.0;
                          } else if (_dragAccumulator < -20) {
                            _toggleLyrics();
                            _dragAccumulator = 0.0;
                          }
                        },
                        child: PlayerContent(song: widget.song),
                      ),
                    ),
                  ),

                  // --- Controls with StreamBuilder ---
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: (details) {
                      _swipeKey.currentState?.handleDragStart(details);
                    },
                    onHorizontalDragUpdate: (details) {
                      _swipeKey.currentState?.handleDragUpdate(details);
                    },
                    onHorizontalDragEnd: (details) {
                      _swipeKey.currentState?.handleDragEnd(details);
                    },
                    onVerticalDragStart: (_) {
                      _dragAccumulator = 0.0;
                    },
                    onVerticalDragUpdate: (details) {
                      _dragAccumulator += details.delta.dy;
                      if (_dragAccumulator > 20) {
                        widget.onCollapse();
                        _dragAccumulator = 0.0;
                      } else if (_dragAccumulator < -20) {
                        _toggleLyrics();
                        _dragAccumulator = 0.0;
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 48.0, top: 24.0),
                      // 局部刷新：仅进度条和时间变化时重绘
                      child: StreamBuilder<Duration?>(
                        stream: playerProvider.player.durationStream,
                        builder: (context, durationSnapshot) {
                          final duration =
                              durationSnapshot.data ?? Duration.zero;

                          return StreamBuilder<Duration>(
                            stream: playerProvider.player.positionStream,
                            builder: (context, positionSnapshot) {
                              final position =
                                  positionSnapshot.data ?? Duration.zero;

                              return PlayerControls(
                                isPlaying: playerProvider.isPlaying,
                                isLoading:
                                    (playerProvider.player.processingState ==
                                        ProcessingState.buffering ||
                                    playerProvider.player.processingState ==
                                        ProcessingState.loading),
                                duration: duration,
                                position: _isDragging
                                    ? Duration(seconds: _dragValue.toInt())
                                    : position,
                                loopMode: playerProvider.playMode,
                                onShuffle: () {
                                  if (playerProvider.recommendationAutoPlay) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          S
                                              .of(context)
                                              .weight_video_detail_replace_by_this_collection_recommend_alert,
                                        ),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } else {
                                    playerProvider.togglePlayMode();
                                  }
                                },
                                onSeek: _onSeekEnd,
                                onSeekStart: _onSeekStart,
                                onSeekUpdate: _onSeekUpdate,
                                onPlayPause: playerProvider.togglePlayPause,
                                onNext: hasNext
                                    ? () => playerProvider.playNext()
                                    : null,
                                onPrevious: hasPrevious
                                    ? () => playerProvider.playPrevious()
                                    : null,
                                onPlaylist: _showPlaylist,
                                onLyrics: _toggleLyrics,
                                onTimer: _showTimerDialog,
                                onComment: _showQualityDialog,
                                onInfo: _showSpeedDialog,
                                onMore: _showVideoDetail,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),

              AnimatedSlide(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                offset: _showLyrics ? Offset.zero : const Offset(0, 1),
                child: LyricsPage(
                  onBack: _toggleLyrics,
                  onPlaylist: _showPlaylist,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
