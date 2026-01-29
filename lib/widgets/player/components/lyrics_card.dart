import 'dart:async';
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
import 'package:utopia_music/widgets/player/components/player_controls.dart';
import 'package:just_audio/just_audio.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/widgets/player/components/player_background.dart';

import 'package:utopia_music/utils/log.dart';

const String _tag = "LYRICS_CARD";

class _LyricsCache {
  static const int _maxCacheSize = 3;
  static final Map<String, List<SubtitleItem>> _subtitles = {};
  static final Map<String, List<model.DanmakuItem>> _danmakus = {};

  static void setSubtitles(String key, List<SubtitleItem> data) {
    if (_subtitles.containsKey(key)) {
      _subtitles.remove(key);
    } else if (_subtitles.length >= _maxCacheSize) {
      _subtitles.remove(_subtitles.keys.first);
    }
    _subtitles[key] = data;
  }

  static List<SubtitleItem>? getSubtitles(String key) {
    final data = _subtitles.remove(key);
    if (data != null) {
      _subtitles[key] = data;
    }
    return data;
  }

  static void setDanmakus(String key, List<model.DanmakuItem> data) {
    if (_danmakus.containsKey(key)) {
      _danmakus.remove(key);
    } else if (_danmakus.length >= _maxCacheSize) {
      _danmakus.remove(_danmakus.keys.first);
    }
    _danmakus[key] = data;
  }

  static List<model.DanmakuItem>? getDanmakus(String key) {
    final data = _danmakus.remove(key);
    if (data != null) {
      _danmakus[key] = data;
    }
    return data;
  }

  static void clear() {
    _subtitles.clear();
    _danmakus.clear();
  }
}

class LyricsPage extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onPlaylist;

  const LyricsPage({super.key, required this.onBack, required this.onPlaylist});

  @override
  State<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isDragging = false;
  double _dragValue = 0.0;
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
  int _currentSubtitleIndex = -1;
  bool _autoScroll = true;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  Timer? _subtitleTimer;
  Timer? _danmakuTimer;
  StreamSubscription? _danmakuSyncSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    Log.v(_tag, "initState");
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    _danmakuSyncSubscription = playerProvider.player.positionStream.listen((
      position,
    ) {
      if (mounted && playerProvider.isPlaying && !_isDragging) {
        _syncDanmaku(position);
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
  }

  @override
  void dispose() {
    Log.v(_tag, "dispose");
    _tabController.dispose();
    _subtitleTimer?.cancel();
    _danmakuTimer?.cancel();
    _danmakuSyncSubscription?.cancel();
    super.dispose();
  }

  void _resetState() {
    Log.v(_tag, "_resetState");
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

  void _loadData() {
    Log.v(_tag, "_loadData");
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final song = playerProvider.currentSong;
    if (song == null) return;

    final currentId = '${song.bvid}_${song.cid}';
    if (currentId != _currentSongId) return;

    _subtitleTimer?.cancel();
    _danmakuTimer?.cancel();

    final cachedSubtitles = _LyricsCache.getSubtitles(currentId);
    final cachedDanmakus = _LyricsCache.getDanmakus(currentId);

    if (cachedSubtitles != null) {
      Log.v(_tag, "Using cached subtitles for $currentId");
      setState(() {
        _subtitles = cachedSubtitles;
        _hasSubtitles = cachedSubtitles.isNotEmpty;
        _isLoadingSubtitles = false;
      });
    } else {
      setState(() => _isLoadingSubtitles = true);
    }

    if (cachedDanmakus != null) {
      Log.v(_tag, "Using cached danmakus for $currentId");
      setState(() {
        _rawDanmakus = cachedDanmakus;
        _hasDanmaku = cachedDanmakus.isNotEmpty;
        _isLoadingDanmaku = false;
      });
      if (mounted) {
        _resetDanmakuCursor(
          playerProvider.player.position.inMilliseconds / 1000.0,
        );
      }
    } else {
      setState(() => _isLoadingDanmaku = true);
    }

    if (cachedSubtitles != null && cachedDanmakus != null) {
      return;
    }

    _subtitleTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      if (_currentSongId != currentId) return;

      int realCid = song.cid;
      if (realCid == 0) {
        realCid = await _resolveCid(song);
      }

      if (!mounted || _currentSongId != currentId) return;

      if (cachedSubtitles == null) {
        await _loadSubtitles(song, currentId, realCid);
      }

      if (cachedDanmakus == null) {
        _danmakuTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted && _currentSongId == currentId) {
            _loadDanmaku(song, currentId, realCid);
          }
        });
      }
    });
  }

  Future<int> _resolveCid(Song song) async {
    Log.v(_tag, "_resolveCid, bvid: ${song.bvid}, cid: ${song.cid}");
    if (song.cid != 0) return song.cid;
    try {
      final detail = await _videoDetailApi.getVideoDetail(song.bvid);
      if (detail != null && detail['cid'] != null) {
        return detail['cid'] as int;
      }
    } catch (e) {
      Log.w(_tag, 'Failed to fetch CID: $e');
    }
    return 0;
  }

  Future<void> _loadSubtitles(Song song, String originalId, int cid) async {
    Log.v(_tag, "_loadSubtitles, bvid: ${song.bvid}, cid: $cid");
    if (_currentSongId != originalId) return;

    if (cid == 0) {
      if (mounted) setState(() => _isLoadingSubtitles = false);
      return;
    }

    try {
      final subtitles = await _subtitleApi.getSubtitles(song.bvid, cid);
      if (mounted && _currentSongId == originalId) {
        _LyricsCache.setSubtitles(originalId, subtitles);
        setState(() {
          _subtitles = subtitles;
          _hasSubtitles = subtitles.isNotEmpty;
          _isLoadingSubtitles = false;
        });
      }
    } catch (e) {
      Log.w(_tag, "Failed to load subtitles: $e");
      if (mounted && _currentSongId == originalId) {
        setState(() => _isLoadingSubtitles = false);
      }
    }
  }

  Future<void> _loadDanmaku(Song song, String originalId, int cid) async {
    Log.v(_tag, "_loadDanmaku, bvid: ${song.bvid}, cid: $cid");
    if (_currentSongId != originalId) return;

    if (cid == 0) {
      if (mounted) setState(() => _isLoadingDanmaku = false);
      return;
    }

    try {
      final danmakus = await _danmakuApi.getDanmaku(cid);
      if (mounted && _currentSongId == originalId) {
        _LyricsCache.setDanmakus(originalId, danmakus);
        setState(() {
          _rawDanmakus = danmakus;
          _hasDanmaku = danmakus.isNotEmpty;
          _isLoadingDanmaku = false;
        });
        if (mounted) {
          _resetDanmakuCursor(
            Provider.of<PlayerProvider>(
                  context,
                  listen: false,
                ).player.position.inMilliseconds /
                1000.0,
          );
        }
      }
    } catch (e) {
      Log.w(_tag, "Failed to load danmaku: $e");
      if (mounted && _currentSongId == originalId) {
        setState(() => _isLoadingDanmaku = false);
      }
    }
  }

  void _syncDanmaku(Duration position) {
    // Log.v(_tag, "_syncDanmaku, position: ${position.inMilliseconds}");
    if (_rawDanmakus.isEmpty || _danmakuController == null) return;

    final double currentSeconds = position.inMilliseconds / 1000.0;
    if (currentSeconds < _lastPositionSeconds ||
        (currentSeconds - _lastPositionSeconds).abs() > 1.5) {
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
    Log.v(_tag, "_resetDanmakuCursor, targetSeconds: $targetSeconds");
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

  bool _calculateSubtitleIndex(Duration position) {
    // Log.v(_tag, "_calculateSubtitleIndex, position: ${position.inMilliseconds}",);
    if (_subtitles.isEmpty) return false;
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
      _currentSubtitleIndex = index;
      return true;
    }
    return false;
  }

  void _onSeekStart(double value) {
    Log.v(_tag, "_onSeekStart, value: $value");
    setState(() {
      _isDragging = true;
      _dragValue = value;
      _autoScroll = false;
    });
    _danmakuController?.clear();
  }

  void _onSeekUpdate(double value) => setState(() => _dragValue = value);

  void _onSeekEnd(double value) {
    Log.v(_tag, "_onSeekEnd, value: $value");
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final position = Duration(seconds: value.toInt());
    playerProvider.player.seek(position);

    if (!playerProvider.isPlaying ||
        playerProvider.player.processingState == ProcessingState.completed) {
      playerProvider.player.play();
    }

    setState(() {
      _isDragging = false;
      _autoScroll = true;
    });
    _resetDanmakuCursor(value);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Log.v(_tag, "build");
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
    final isBlurMode =
        backgroundMode == 'gaussian_blur' || backgroundMode == 'blur';
    final isNoneMode = backgroundMode == 'none';

    final themeData = Theme.of(context);
    final isDarkMode = themeData.brightness == Brightness.dark;
    final bool useLightText = isDarkMode || isBlurMode;

    return Theme(
      data: themeData,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isBlurMode || !isNoneMode)
            PlayerBackground(coverUrl: song.coverUrl, mode: backgroundMode)
          else
            Container(
              color: themeData.scaffoldBackgroundColor.withValues(alpha: 0.95),
            ),

          Scaffold(
            backgroundColor: Colors.transparent,
            body: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (details.primaryDelta! > 10) widget.onBack();
              },
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta! > 10) widget.onBack();
              },
              child: Stack(
                children: [
                  Column(
                    children: [
                      SizedBox(height: topPadding + 16),
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        width: 200,
                        height: 36,
                        decoration: BoxDecoration(
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
                          unselectedLabelColor: useLightText
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.black54,
                          dividerColor: Colors.transparent,
                          tabs: [
                            Tab(text: S.of(context).common_ai_subtitle),
                            Tab(text: S.of(context).common_danmuku),
                          ],
                        ),
                      ),

                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            StreamBuilder<Duration>(
                              stream: playerProvider.player.positionStream,
                              builder: (context, snapshot) {
                                final position = snapshot.data ?? Duration.zero;
                                if (_hasSubtitles && !_isDragging) {
                                  bool changed = _calculateSubtitleIndex(
                                    position,
                                  );
                                  if (changed &&
                                      _autoScroll &&
                                      _currentSubtitleIndex != -1) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (_itemScrollController
                                              .isAttached) {
                                            _itemScrollController.scrollTo(
                                              index: _currentSubtitleIndex + 1,
                                              duration: const Duration(
                                                milliseconds: 300,
                                              ),
                                              curve: Curves.easeInOut,
                                              alignment: 0.4,
                                            );
                                          }
                                        });
                                  }
                                }

                                return _buildLyricsView(song, themeData);
                              },
                            ),
                            _DanmakuPage(
                              isLoading: _isLoadingDanmaku,
                              hasDanmaku: _hasDanmaku,
                              rawDanmakus: _rawDanmakus,
                              onControllerCreated: (controller) =>
                                  _danmakuController = controller,
                              textColor: useLightText
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(bottom: 48.0, top: 24.0),
                        child: StreamBuilder<Duration?>(
                          stream: playerProvider.player.durationStream,
                          builder: (context, durSnapshot) {
                            final duration = durSnapshot.data ?? Duration.zero;
                            return StreamBuilder<Duration>(
                              stream: playerProvider.player.positionStream,
                              builder: (context, posSnapshot) {
                                final position =
                                    posSnapshot.data ?? Duration.zero;
                                return PlayerControls(
                                  isPlaying: playerProvider.isPlaying,
                                  isLoading:
                                      playerProvider.player.processingState ==
                                      ProcessingState.buffering,
                                  duration: duration,
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
                                  onPlaylist: widget.onPlaylist,
                                  onLyrics: widget.onBack,
                                  hideExtraControls: false,
                                  showLyricsButtonOnly: true,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: topPadding + 12,
                    left: 16,
                    child: IconButton(
                      onPressed: widget.onBack,
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: themeData.iconTheme.color,
                        size: 28,
                      ),
                      tooltip: S.of(context).common_retract,
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

  Widget _buildLyricsView(Song song, ThemeData theme) {
    // Log.v(_tag, "_buildLyricsView, song: ${song.title}, bvid: ${song.bvid}");
    if (_isLoadingSubtitles) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }
    final baseTextStyle = theme.textTheme.bodyLarge?.copyWith(
      color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.9),
    );
    final highlightColor = theme.colorScheme.primary;
    final normalColor = theme.textTheme.bodyLarge?.color?.withValues(
      alpha: 0.6,
    );

    if (!_hasSubtitles) {
      if (song.lyrics.isNotEmpty) {
        return Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(32),
            child: Text(
              song.lyrics,
              textAlign: TextAlign.center,
              style: baseTextStyle?.copyWith(height: 1.8, fontSize: 18),
            ),
          ),
        );
      }
      return Center(
        child: Text(S.of(context).common_no_lyrics, style: baseTextStyle),
      );
    }

    return ScrollablePositionedList.builder(
      key: ValueKey(_subtitles),
      itemCount: _subtitles.length + 2,
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      initialScrollIndex:
          (_currentSubtitleIndex > -1 &&
              _currentSubtitleIndex < _subtitles.length)
          ? _currentSubtitleIndex + 1
          : 0,
      physics: const ClampingScrollPhysics(),
      itemBuilder: (context, index) {
        if (index == 0 || index == _subtitles.length + 1) {
          return SizedBox(height: MediaQuery.of(context).size.height * 0.4);
        }
        final subtitleIndex = index - 1;
        final subtitle = _subtitles[subtitleIndex];
        final isActive = subtitleIndex == _currentSubtitleIndex;

        return GestureDetector(
          onTap: () {
            Provider.of<PlayerProvider>(context, listen: false).player.seek(
              Duration(milliseconds: (subtitle.from * 1000).toInt()),
            );
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

class _DanmakuPageState extends State<_DanmakuPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    Log.v(_tag, "build _DanmakuPage");
    super.build(context);
    if (widget.isLoading) {
      return Center(
        child: Text(
          S.of(context).weight_player_loading_danmuku,
          style: TextStyle(color: widget.textColor),
        ),
      );
    }
    if (!widget.hasDanmaku) {
      return Center(
        child: Text(
          S.of(context).weight_player_no_danmuku,
          style: TextStyle(color: widget.textColor),
        ),
      );
    }
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
