import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/connection/subtitles/danmaku_api.dart';
import 'package:utopia_music/connection/subtitles/subtitle_api.dart';
import 'package:utopia_music/connection/video/video_detail.dart';
import 'package:utopia_music/models/danmaku.dart' as model;
import 'package:utopia_music/models/subtitle.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/widgets/player/player_controls.dart';
import 'package:just_audio/just_audio.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';

class LyricsPage extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onPlaylist;

  const LyricsPage({
    super.key,
    required this.onBack,
    required this.onPlaylist,
  });

  @override
  State<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> with TickerProviderStateMixin {
  bool _isDragging = false;
  double _dragValue = 0.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  late TabController _tabController;
  final SubtitleApi _subtitleApi = SubtitleApi();
  final DanmakuApi _danmakuApi = DanmakuApi();
  final VideoDetailApi _videoDetailApi = VideoDetailApi();

  List<SubtitleItem> _subtitles = [];
  bool _isLoadingSubtitles = false;
  bool _hasSubtitles = false;

  List<model.DanmakuItem> _rawDanmakus = [];
  bool _isLoadingDanmaku = false;
  bool _hasDanmaku = false;

  DanmakuController? _danmakuController;

  int _lastProcessedIndex = 0;
  double _lastPositionSeconds = 0.0;
  String? _currentSongId;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  int _currentSubtitleIndex = -1;
  bool _autoScroll = true;

  Timer? _subtitleTimer;
  Timer? _danmakuTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    _position = playerProvider.player.position;
    _duration = playerProvider.player.duration ?? Duration.zero;

    playerProvider.player.positionStream.listen((position) {
      if (mounted) {
        if (!_isDragging) {
          setState(() {
            _position = position;
          });
          if (playerProvider.isPlaying) {
            _syncDanmaku(position);
          }
        }
        _updateSubtitleIndex(position);
      }
    });

    playerProvider.player.playerStateStream.listen((state) {
      if (mounted && _danmakuController != null) {
        if (state.playing) {
          _danmakuController!.resume();
        } else {
          _danmakuController!.pause();
        }
      }
    });

    playerProvider.player.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subtitleTimer?.cancel();
    _danmakuTimer?.cancel();
    super.dispose();
  }

  void _resetState() {
    _subtitleTimer?.cancel();
    _danmakuTimer?.cancel();

    setState(() {
      _subtitles = [];
      _isLoadingSubtitles = true;
      _hasSubtitles = false;

      _rawDanmakus = [];
      _isLoadingDanmaku = true;
      _hasDanmaku = false;

      _currentSubtitleIndex = -1;
      _lastProcessedIndex = 0;
      _lastPositionSeconds = 0.0;
    });
    _danmakuController?.clear();
  }

  void _syncDanmaku(Duration position) {
    if (_rawDanmakus.isEmpty || _danmakuController == null) return;

    final double currentSeconds = position.inMilliseconds / 1000.0;

    if (currentSeconds < _lastPositionSeconds || (currentSeconds - _lastPositionSeconds).abs() > 1.5) {
      _resetDanmakuCursor(currentSeconds);
      return;
    }

    int i = _lastProcessedIndex;
    while (i < _rawDanmakus.length) {
      final item = _rawDanmakus[i];
      if (item.time > currentSeconds) break;

      if (item.time >= _lastPositionSeconds) {
        _danmakuController!.addDanmaku(
          DanmakuContentItem(
            item.content,
            color: Color(item.color | 0xFF000000),
            type: DanmakuItemType.scroll,
          ),
        );
      }
      i++;
    }

    _lastProcessedIndex = i;
    _lastPositionSeconds = currentSeconds;
  }

  void _resetDanmakuCursor(double targetSeconds) {
    _danmakuController?.clear();
    _lastPositionSeconds = targetSeconds;

    int newIndex = 0;
    for (int i = 0; i < _rawDanmakus.length; i++) {
      if (_rawDanmakus[i].time >= targetSeconds) {
        newIndex = i;
        break;
      }
    }
    _lastProcessedIndex = newIndex;
  }

  void _loadData() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final song = playerProvider.currentSong;
    if (song == null) return;

    final currentId = '${song.bvid}_${song.cid}';
    if (currentId != _currentSongId) return;

    _subtitleTimer?.cancel();
    _danmakuTimer?.cancel();

    _subtitleTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _loadSubtitles(song, currentId);
    });

    _danmakuTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) _loadDanmaku(song, currentId);
    });
  }

  Future<int> _resolveCid(Song song) async {
    if (song.cid != 0) return song.cid;
    try {
      final detail = await _videoDetailApi.getVideoDetail(song.bvid);
      if (detail != null && detail['cid'] != null) {
        return detail['cid'] as int;
      }
    } catch (e) {
      print('LyricsPage: Failed to fetch CID: $e');
    }
    return 0;
  }

  Future<void> _loadSubtitles(Song song, String originalId) async {
    if (_currentSongId != originalId) return;

    final int realCid = await _resolveCid(song);

    if (_currentSongId != originalId || !mounted) return;

    if (realCid == 0) {
      setState(() => _isLoadingSubtitles = false);
      return;
    }

    final subtitles = await _subtitleApi.getSubtitles(song.bvid, realCid);

    if (mounted && _currentSongId == originalId) {
      setState(() {
        _subtitles = subtitles;
        _hasSubtitles = subtitles.isNotEmpty;
        _isLoadingSubtitles = false;
      });
    }
  }

  Future<void> _loadDanmaku(Song song, String originalId) async {
    if (_currentSongId != originalId) return;

    final int realCid = await _resolveCid(song);

    if (_currentSongId != originalId || !mounted) return;

    if (realCid == 0) {
      setState(() => _isLoadingDanmaku = false);
      return;
    }

    final danmakus = await _danmakuApi.getDanmaku(realCid);

    if (mounted && _currentSongId == originalId) {
      setState(() {
        _rawDanmakus = danmakus;
        _hasDanmaku = danmakus.isNotEmpty;
        _isLoadingDanmaku = false;
      });
      _resetDanmakuCursor(Provider.of<PlayerProvider>(context, listen: false).player.position.inMilliseconds / 1000.0);
    }
  }

  void _updateSubtitleIndex(Duration position) {
    if (_subtitles.isEmpty) return;
    final seconds = position.inMilliseconds / 1000.0;
    int index = -1;
    for (int i = 0; i < _subtitles.length; i++) {
      if (seconds >= _subtitles[i].from && seconds < _subtitles[i].to) {
        index = i;
        break;
      }
      if (seconds >= _subtitles[i].from) index = i;
    }
    if (index != _currentSubtitleIndex) {
      setState(() => _currentSubtitleIndex = index);
      if (_autoScroll && index != -1) {
        _itemScrollController.scrollTo(
          index: index + 1, // +1 因为头部有 Padding 占位
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.35, // 歌词高亮位置靠上
        );
      }
    }
  }

  void _onSeekStart(double value) {
    setState(() {
      _isDragging = true;
      _dragValue = value;
      _autoScroll = false;
    });
    _danmakuController?.clear();
  }

  void _onSeekUpdate(double value) => setState(() => _dragValue = value);

  void _onSeekEnd(double value) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final position = Duration(seconds: value.toInt());
    playerProvider.player.seek(position);

    if (!playerProvider.isPlaying || playerProvider.player.processingState == ProcessingState.completed) {
      playerProvider.player.play();
    }

    setState(() {
      _isDragging = false;
      _position = position;
      _autoScroll = true;
    });
    _resetDanmakuCursor(value);
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final song = playerProvider.currentSong;
    if (song == null) return const SizedBox();

    final newSongId = '${song.bvid}_${song.cid}';
    if (newSongId != _currentSongId) {
      _currentSongId = newSongId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _resetState();
          _loadData();
        }
      });
    }

    final topPadding = MediaQuery.of(context).padding.top;
    final backgroundMode = settingsProvider.playerBackgroundMode;
    final isBlurMode = backgroundMode == 'gaussian_blur' || backgroundMode == 'blur';
    final isNoneMode = backgroundMode == 'none';

    // --- 核心修改：主题与夜间模式适配 ---
    final themeData = Theme.of(context);
    final isDarkMode = themeData.brightness == Brightness.dark;
    final bool useLightText = isDarkMode || isBlurMode; // 深色模式或模糊模式下，文字通常用白色

    return Theme(
      data: themeData,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isBlurMode)
            _buildBlurredBackground(song.coverUrl, backgroundMode == 'gaussian_blur' ? 20.0 : 10.0)
          else if (isNoneMode)
          // 修改：使用主题背景色，而不是写死白色
            Container(color: themeData.scaffoldBackgroundColor.withValues(alpha: 0.95))
          else
            Container(color: themeData.scaffoldBackgroundColor.withValues(alpha: 0.95)),

          Scaffold(
            backgroundColor: Colors.transparent,
            body: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (details.primaryDelta! > 10) widget.onBack();
              },
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta! > 10) {
                  widget.onBack();
                }
              },
              child: Stack(
                children: [
                  Column(
                    children: [
                      SizedBox(height: topPadding + 16),
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        width: 200, height: 36,
                        decoration: BoxDecoration(
                          // 修改：背景条颜色适配
                          color: useLightText
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: themeData.colorScheme.primary,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: themeData.colorScheme.onPrimary,
                          // 修改：未选中文字颜色适配
                          unselectedLabelColor: useLightText
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.black54,
                          dividerColor: Colors.transparent,
                          tabs: const [Tab(text: 'AI/字幕'), Tab(text: '弹幕')],
                        ),
                      ),

                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildLyricsView(song, themeData),
                            _DanmakuPage(
                              isLoading: _isLoadingDanmaku,
                              hasDanmaku: _hasDanmaku,
                              rawDanmakus: _rawDanmakus,
                              onControllerCreated: (controller) => _danmakuController = controller,
                              // 修改：弹幕文字颜色适配
                              textColor: useLightText ? Colors.white : Colors.black,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 48.0, top: 24.0),
                        child: PlayerControls(
                          isPlaying: playerProvider.isPlaying,
                          isLoading: playerProvider.player.processingState == ProcessingState.buffering,
                          duration: _duration,
                          position: _isDragging ? Duration(seconds: _dragValue.toInt()) : _position,
                          loopMode: playerProvider.playMode,
                          onSeek: _onSeekEnd,
                          onSeekStart: _onSeekStart,
                          onSeekUpdate: _onSeekUpdate,
                          onPlayPause: playerProvider.togglePlayPause,
                          onNext: playerProvider.hasNext ? () => playerProvider.playNext() : null,
                          onPrevious: playerProvider.hasPrevious ? () => playerProvider.playPrevious() : null,
                          onShuffle: playerProvider.togglePlayMode,
                          onPlaylist: widget.onPlaylist,
                          onLyrics: widget.onBack,
                          hideExtraControls: false,
                          showLyricsButtonOnly: true,
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: topPadding + 12,
                    left: 16,
                    child: IconButton(
                      onPressed: widget.onBack,
                      icon: Icon(Icons.keyboard_arrow_down, color: themeData.iconTheme.color, size: 28),
                      tooltip: '收起',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurredBackground(String coverUrl, double sigma) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            coverUrl,
            fit: BoxFit.cover,
            cacheWidth: 100,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          ),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsView(song, ThemeData theme) {
    if (_isLoadingSubtitles) return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
    final baseTextStyle = theme.textTheme.bodyLarge?.copyWith(color: theme.textTheme.bodyLarge?.color?.withOpacity(0.9));
    final highlightColor = theme.colorScheme.primary;
    final normalColor = theme.textTheme.bodyLarge?.color?.withOpacity(0.6);

    if (!_hasSubtitles) {
      if (song.lyrics.isNotEmpty) {
        return Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(32),
            child: Text(
                song.lyrics,
                textAlign: TextAlign.center,
                style: baseTextStyle?.copyWith(height: 1.8, fontSize: 18)
            ),
          ),
        );
      }
      return Center(child: Text('暂无字幕', style: baseTextStyle));
    }
    return ScrollablePositionedList.builder(
      itemCount: _subtitles.length + 2,
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      physics: const ClampingScrollPhysics(),
      itemBuilder: (context, index) {
        if (index == 0 || index == _subtitles.length + 1) return SizedBox(height: MediaQuery.of(context).size.height * 0.4);
        final subtitleIndex = index - 1;
        final subtitle = _subtitles[subtitleIndex];
        final isActive = subtitleIndex == _currentSubtitleIndex;
        return GestureDetector(
          onTap: () {
            Provider.of<PlayerProvider>(context, listen: false).player.seek(Duration(milliseconds: (subtitle.from * 1000).toInt()));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
            alignment: Alignment.center,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: isActive ? 24 : 18,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? highlightColor : normalColor,
                height: 1.5,
              ),
              child: Text(subtitle.content, textAlign: TextAlign.center),
            ),
          ),
        );
      },
    );
  }
}

class _DanmakuPage extends StatefulWidget {
  final bool isLoading;
  final bool hasDanmaku;
  final List<model.DanmakuItem> rawDanmakus;
  final Function(DanmakuController) onControllerCreated;
  final Color textColor;

  const _DanmakuPage({
    required this.isLoading,
    required this.hasDanmaku,
    required this.rawDanmakus,
    required this.onControllerCreated,
    required this.textColor,
  });

  @override
  State<_DanmakuPage> createState() => _DanmakuPageState();
}

class _DanmakuPageState extends State<_DanmakuPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.isLoading) return Center(child: Text('弹幕装载中...', style: TextStyle(color: widget.textColor)));
    if (!widget.hasDanmaku) return Center(child: Text('该视频暂无弹幕', style: TextStyle(color: widget.textColor)));
    return Padding(
      padding: const EdgeInsets.only(top: 72.0),
      child: DanmakuScreen(
        key: ValueKey(widget.rawDanmakus.hashCode),
        createdController: widget.onControllerCreated,
        option: DanmakuOption(
          opacity: 0.9,
          fontSize: 18,
          area: 0.6,
          hideScroll: false,
          hideTop: false,
          hideBottom: false,
        ),
      ),
    );
  }
}