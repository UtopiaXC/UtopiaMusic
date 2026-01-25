import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/widgets/player/lyrics_card.dart';
import 'package:utopia_music/widgets/player/player_content.dart';
import 'package:utopia_music/widgets/player/player_controls.dart';
import 'package:utopia_music/widgets/player/playlist_sheet.dart';
import 'package:utopia_music/widgets/player/swipeable_player_card.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/widgets/user/space_sheet.dart';
import 'package:utopia_music/connection/video/video_detail.dart';
import 'package:utopia_music/widgets/video/video_detail.dart';
import 'package:utopia_music/connection/audio/audio_stream.dart';
import 'package:utopia_music/utils/quality_utils.dart';
import 'package:utopia_music/connection/video/search.dart';
import 'package:utopia_music/services/download_manager.dart';

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
  bool _isDragging = false;
  double _dragValue = 0.0;
  Duration _duration = Duration.zero;
  bool _showLyrics = false;
  Timer? _timer;
  final VideoDetailApi _videoDetailApi = VideoDetailApi();
  bool _isDownloaded = false;

  @override
  void initState() {
    super.initState();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    playerProvider.player.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
    
    _checkDownloadStatus();
  }

  @override
  void didUpdateWidget(FullPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.bvid != widget.song.bvid || oldWidget.song.cid != widget.song.cid) {
      _checkDownloadStatus();
    }
  }

  Future<void> _checkDownloadStatus() async {
    final isDownloaded = await DownloadManager().isDownloaded(widget.song.bvid, widget.song.cid);
    if (mounted) {
      setState(() {
        _isDownloaded = isDownloaded;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
          title: const Text('关闭定时器'),
          content: Text(
            '当前停止时间为：${playerProvider.stopTime?.toString().split('.')[0]}\n是否关闭定时器？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                playerProvider.cancelTimer();
                Navigator.pop(context);
              },
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => const _TimerDialog(),
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
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  '选择倍速',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
      builder: (context) => _QualityDialog(song: widget.song),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已下载')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('下载确认'),
        content: const Text('是否下载该曲目？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('下载'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DownloadManager().startDownload(widget.song);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已加入下载队列')),
        );
      }
    }
  }

  Widget _buildCardContent(
    BuildContext context,
    Song song, {
    bool isCurrent = false,
  }) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    return Container(
      key: ValueKey('${song.bvid}_${song.cid}'),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Expanded(child: PlayerContent(song: song)),
          Padding(
            padding: const EdgeInsets.only(bottom: 48.0, top: 24.0),
            child: isCurrent
                ? StreamBuilder<Duration>(
                    stream: playerProvider.player.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      return PlayerControls(
                        isPlaying: playerProvider.isPlaying,
                        isLoading:
                            (playerProvider.player.processingState ==
                                ProcessingState.buffering ||
                            playerProvider.player.processingState ==
                                ProcessingState.loading),
                        duration: _duration,
                        position: _isDragging
                            ? Duration(seconds: _dragValue.toInt())
                            : position,
                        loopMode: playerProvider.playMode,
                        onSeek: _onSeekEnd,
                        onSeekStart: _onSeekStart,
                        onSeekUpdate: _onSeekUpdate,
                        onPlayPause: playerProvider.togglePlayPause,
                        onNext: playerProvider.hasNext
                            ? () => playerProvider.playNext()
                            : null,
                        onPrevious: playerProvider.hasPrevious
                            ? () => playerProvider.playPrevious()
                            : null,
                        onShuffle: playerProvider.togglePlayMode,
                        onPlaylist: _showPlaylist,
                        onLyrics: _toggleLyrics,
                        onTimer: _showTimerDialog,
                        onComment: _showQualityDialog,
                        onInfo: _showSpeedDialog,
                        onMore: _showVideoDetail,
                      );
                    },
                  )
                : PlayerControls(
                    isPlaying: false,
                    isLoading: false,
                    duration: Duration.zero,
                    position: Duration.zero,
                    loopMode: playerProvider.playMode,
                    onSeek: (v) {},
                    onPlayPause: () {},
                    onNext: null,
                    onPrevious: null,
                    onShuffle: () {},
                    onPlaylist: () {},
                    onLyrics: () {},
                    onTimer: () {},
                    onComment: () {},
                    onInfo: () {},
                    onMore: () {},
                  ),
          ),
        ],
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法获取用户信息')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('获取信息失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final playerProvider = Provider.of<PlayerProvider>(context);
    final hasNext = playerProvider.hasNext;
    final hasPrevious = playerProvider.hasPrevious;

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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        if (_showLyrics) {
          _toggleLyrics();
          return;
        }
        widget.onCollapse();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta! > 10) {
              if (_showLyrics) {
                _toggleLyrics();
              }
              widget.onCollapse();
            }
          },
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                SizedBox(height: topPadding + 12),
                SizedBox(
                  height: kToolbarHeight,
                  child: NavigationToolbar(
                    leading: IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: () {
                        if (_showLyrics) {
                          _toggleLyrics();
                        }
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
                              final textStyle = const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              );
                              final textSpan = TextSpan(
                                text: widget.song.title,
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
                                  text: widget.song.title,
                                  style: textStyle,
                                  scrollAxis: Axis.horizontal,
                                  crossAxisAlignment: CrossAxisAlignment.center,
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
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
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
                      icon: Icon(
                        Icons.download,
                        color: _isDownloaded ? Colors.green : null,
                      ),
                      onPressed: _handleDownload,
                      tooltip: '下载',
                    ),
                    centerMiddle: true,
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      AnimatedSlide(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        offset: _showLyrics ? const Offset(-1, 0) : Offset.zero,
                        child: SwipeablePlayerCard(
                          onNext: hasNext
                              ? () => playerProvider.playNext()
                              : null,
                          onPrevious: hasPrevious
                              ? () => playerProvider.playPrevious()
                              : null,
                          previousChild: previousSong != null
                              ? _buildCardContent(context, previousSong)
                              : null,
                          nextChild: nextSong != null
                              ? _buildCardContent(context, nextSong)
                              : null,
                          child: _buildCardContent(
                            context,
                            widget.song,
                            isCurrent: true,
                          ),
                        ),
                      ),

                      AnimatedSlide(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        offset: _showLyrics ? Offset.zero : const Offset(1, 0),
                        child: LyricsPage(onBack: _toggleLyrics),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimerDialog extends StatefulWidget {
  const _TimerDialog();

  @override
  State<_TimerDialog> createState() => _TimerDialogState();
}

class _TimerDialogState extends State<_TimerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _stopAfterCurrent = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setTimer(int minutes) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    playerProvider.setStopTimer(
      Duration(minutes: minutes),
      stopAfterCurrent: _stopAfterCurrent,
    );
    Navigator.pop(context);
  }

  void _showCustomTimerDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义倒计时'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '分钟', suffixText: 'min'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final minutes = int.tryParse(controller.text);
              if (minutes != null && minutes > 0) {
                _setTimer(minutes);
                Navigator.pop(context);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SizedBox(
          height: 400,
          child: Column(
            children: [
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _stopAfterCurrent,
                onChanged: (value) {
                  setState(() {
                    _stopAfterCurrent = value ?? false;
                  });
                },
                title: const Text('播放完当前曲目后停止'),
              ),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '倒计时关闭'),
                  Tab(text: '指定时间关闭'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildCountdownTab(), _buildSpecificTimeTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownTab() {
    return ListView(
      children: [
        ListTile(title: const Text('15 分钟'), onTap: () => _setTimer(15)),
        ListTile(title: const Text('30 分钟'), onTap: () => _setTimer(30)),
        ListTile(title: const Text('60 分钟'), onTap: () => _setTimer(60)),
        ListTile(title: const Text('90 分钟'), onTap: () => _setTimer(90)),
        ListTile(title: const Text('自定义'), onTap: _showCustomTimerDialog),
      ],
    );
  }

  Widget _buildSpecificTimeTab() {
    return Center(
      child: FilledButton(
        onPressed: () async {
          final now = TimeOfDay.now();
          final time = await showTimePicker(context: context, initialTime: now);
          if (time != null) {
            final nowDateTime = DateTime.now();
            var selectedDateTime = DateTime(
              nowDateTime.year,
              nowDateTime.month,
              nowDateTime.day,
              time.hour,
              time.minute,
            );
            if (selectedDateTime.isBefore(nowDateTime)) {
              selectedDateTime = selectedDateTime.add(const Duration(days: 1));
            }

            if (mounted) {
              final playerProvider = Provider.of<PlayerProvider>(
                context,
                listen: false,
              );
              playerProvider.setStopTime(
                selectedDateTime,
                stopAfterCurrent: _stopAfterCurrent,
              );
              Navigator.pop(context);
            }
          }
        },
        child: const Text('选择时间'),
      ),
    );
  }
}

class _QualityDialog extends StatefulWidget {
  final Song song;

  const _QualityDialog({required this.song});

  @override
  State<_QualityDialog> createState() => _QualityDialogState();
}

class _QualityDialogState extends State<_QualityDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AudioStreamInfo? _streamInfo;
  final AudioStreamApi _audioApi = AudioStreamApi();
  final SearchApi _searchApi = SearchApi();
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStreamInfo();
  }

  Future<void> _loadStreamInfo() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      int cid = widget.song.cid;
      if (cid == 0) {
        print("CID is 0, fetching real CID for ${widget.song.bvid}...");
        cid = await _searchApi.fetchCid(widget.song.bvid);
        if (cid == 0) {
          throw Exception("无法获取有效的 CID");
        }
      }

      final info = await _audioApi.getAudioStream(widget.song.bvid, cid);

      if (mounted) {
        setState(() {
          _streamInfo = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Failed to load stream info: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SizedBox(
          height: 400,
          child: Column(
            children: [
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '默认音质'),
                  Tab(text: '该曲可用'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDefaultQualityTab(),
                    _buildAvailableQualityTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultQualityTab() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final qualities = QualityUtils.supportQualities;

    return ListView.builder(
      itemCount: qualities.length,
      itemBuilder: (context, index) {
        final quality = qualities[index];
        final isSelected = settingsProvider.defaultAudioQuality == quality;
        return ListTile(
          title: Text(QualityUtils.getQualityLabel(quality, detailed: true)),
          trailing: isSelected
              ? const Icon(Icons.check, color: Colors.blue)
              : null,
          onTap: () {
            settingsProvider.setDefaultAudioQuality(quality);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildAvailableQualityTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 36),
            const SizedBox(height: 8),
            const Text('加载失败'),
            TextButton(onPressed: _loadStreamInfo, child: const Text('重试')),
          ],
        ),
      );
    }

    if (_streamInfo == null || _streamInfo!.availableQualities.isEmpty) {
      return const Center(child: Text('无可用音质信息'));
    }
    final available = _streamInfo!.availableQualities;
    final current = context.select<PlayerProvider, int>(
      (p) => p.currentPlayingQuality,
    );
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '可用的音质通过请求接口得到，基于您的登录状态、大会员情况、与音源因素共同决定，不代表该曲目只有以下音质。',
            style: TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: available.length,
            itemBuilder: (context, index) {
              final quality = available[index];
              final isCurrent = quality == current;

              return ListTile(
                title: Text(
                  QualityUtils.getQualityLabel(quality, detailed: true),
                ),
                subtitle: isCurrent
                    ? Text(
                        '当前使用',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                        ),
                      )
                    : null,
                trailing: isCurrent
                    ? Icon(
                        Icons.volume_up,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  if (!isCurrent) {
                    Provider.of<SettingsProvider>(
                      context,
                      listen: false,
                    ).setDefaultAudioQuality(quality);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
