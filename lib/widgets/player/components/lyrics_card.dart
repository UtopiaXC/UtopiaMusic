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
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:utopia_music/utils/log.dart';

const String _tag = "LYRICS_CARD";

class _MergedDanmaku {
  String content;
  double time;
  int count;

  _MergedDanmaku({
    required this.content,
    required this.time,
    required this.count,
  });
}

class _LyricsCache {
  static const int _maxCacheSize = 3;
  static final Map<String, SubtitleResult> _subtitleResults = {};
  static final Map<String, List<model.DanmakuItem>> _danmakus = {};

  static void setSubtitleResult(String key, SubtitleResult data) {
    if (_subtitleResults.containsKey(key)) {
      _subtitleResults.remove(key);
    } else if (_subtitleResults.length >= _maxCacheSize) {
      _subtitleResults.remove(_subtitleResults.keys.first);
    }
    _subtitleResults[key] = data;
  }

  static SubtitleResult? getSubtitleResult(String key) {
    final data = _subtitleResults.remove(key);
    if (data != null) {
      _subtitleResults[key] = data;
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
    _subtitleResults.clear();
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

  // Subtitle state
  SubtitleResult? _subtitleResult;
  List<SubtitleItem> _subtitles = [];
  bool _isLoadingSubtitles = false;
  bool _hasSubtitles = false;

  // Danmaku state
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
  StreamSubscription? _playerStateSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    Log.v(_tag, "initState");
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
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

    _playerStateSubscription = playerProvider.player.playerStateStream.listen(
      (_) => _updateWakelock(),
    );
    settingsProvider.addListener(_updateWakelock);

    WidgetsBinding.instance.addPostFrameCallback((_) => _updateWakelock());
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    Log.v(_tag, "dispose");
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _subtitleTimer?.cancel();
    _danmakuTimer?.cancel();
    _danmakuSyncSubscription?.cancel();
    _playerStateSubscription?.cancel();
    Provider.of<SettingsProvider>(
      context,
      listen: false,
    ).removeListener(_updateWakelock);
    WakelockPlus.disable();
    super.dispose();
  }

  void _updateWakelock() {
    if (!mounted) return;
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final enable = playerProvider.isPlaying && settingsProvider.lyricsAlwaysOn;
    WakelockPlus.toggle(enable: enable);
  }

  void _resetState() {
    Log.v(_tag, "_resetState");
    _subtitleTimer?.cancel();
    _danmakuTimer?.cancel();

    setState(() {
      _subtitleResult = null;
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

    final cachedResult = _LyricsCache.getSubtitleResult(currentId);
    final cachedDanmakus = _LyricsCache.getDanmakus(currentId);

    if (cachedResult != null) {
      Log.v(_tag, "Using cached subtitle result for $currentId");
      setState(() {
        _subtitleResult = cachedResult;
        _subtitles = cachedResult.currentItems ?? [];
        _hasSubtitles = cachedResult.hasSubtitles;
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

    if (cachedResult != null && cachedDanmakus != null) {
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

      if (cachedResult == null) {
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
      final result = await _subtitleApi.getSubtitleResult(song.bvid, cid);
      if (mounted && _currentSongId == originalId) {
        _LyricsCache.setSubtitleResult(originalId, result);
        setState(() {
          _subtitleResult = result;
          _subtitles = result.currentItems ?? [];
          _hasSubtitles = result.hasSubtitles;
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

  /// Switch to a different subtitle track
  Future<void> _switchSubtitleTrack(int index) async {
    if (_subtitleResult == null ||
        index < 0 ||
        index >= _subtitleResult!.tracks.length) {
      return;
    }

    final track = _subtitleResult!.tracks[index];

    // Load content if not cached
    if (track.cachedItems == null) {
      setState(() => _isLoadingSubtitles = true);
      await _subtitleApi.loadTrackContent(track);
    }

    setState(() {
      _subtitleResult!.selectedIndex = index;
      _subtitles = track.cachedItems ?? [];
      _hasSubtitles = _subtitles.isNotEmpty;
      _currentSubtitleIndex = -1;
      _isLoadingSubtitles = false;
    });
  }

  void _showSubtitleSwitcher(BuildContext context) {
    if (_subtitleResult == null || _subtitleResult!.tracks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有可切换的字幕')));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.translate),
                    const SizedBox(width: 12),
                    Text(
                      '切换字幕',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...List.generate(_subtitleResult!.tracks.length, (index) {
                final track = _subtitleResult!.tracks[index];
                final isSelected = index == _subtitleResult!.selectedIndex;
                return ListTile(
                  leading: Icon(
                    track.type == SubtitleType.ai
                        ? Icons.smart_toy_outlined
                        : Icons.person_outline,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(
                    track.lanDoc,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    track.typeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: track.type == SubtitleType.ai
                          ? Colors.orange
                          : Colors.green,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _switchSubtitleTrack(index);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showDanmakuList(BuildContext context) {
    if (_rawDanmakus.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有弹幕')));
      return;
    }

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    // Merge duplicate danmaku at the same time
    final mergedDanmakus = _mergeDuplicateDanmakus(_rawDanmakus);

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.list),
                      const SizedBox(width: 12),
                      Text(
                        '弹幕列表 (${_rawDanmakus.length})',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (mergedDanmakus.length != _rawDanmakus.length) ...[
                        const SizedBox(width: 8),
                        Text(
                          '合并后 ${mergedDanmakus.length}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Scrollbar(
                    controller: scrollController,
                    thumbVisibility: true,
                    interactive: true,
                    thickness: 6,
                    radius: const Radius.circular(3),
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: mergedDanmakus.length,
                      itemBuilder: (context, index) {
                        final item = mergedDanmakus[index];
                        final time = Duration(
                          milliseconds: (item.time * 1000).toInt(),
                        );
                        final timeStr = _formatDuration(time);

                        return ListTile(
                          dense: true,
                          leading: Text(
                            timeStr,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (item.count > 1) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'x${item.count}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            playerProvider.player.seek(time);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Merge duplicate danmaku content (same text at similar time)
  List<_MergedDanmaku> _mergeDuplicateDanmakus(
    List<model.DanmakuItem> danmakus,
  ) {
    final Map<String, _MergedDanmaku> merged = {};

    for (var d in danmakus) {
      // Use content as key (merge all identical content regardless of time)
      // Or use time bucket + content for time-sensitive merging
      final key = d.content;

      if (merged.containsKey(key)) {
        merged[key]!.count++;
        // Keep the earliest time
        if (d.time < merged[key]!.time) {
          merged[key]!.time = d.time;
        }
      } else {
        merged[key] = _MergedDanmaku(
          content: d.content,
          time: d.time,
          count: 1,
        );
      }
    }

    // Sort by time
    final result = merged.values.toList();
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _syncDanmaku(Duration position) {
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

    // Determine which action button to show
    final bool isOnSubtitleTab = _tabController.index == 0;

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
                      SizedBox(height: topPadding + 8),
                      // Header row: back button + centered tab capsule + action button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            // Left: Back button
                            IconButton(
                              onPressed: widget.onBack,
                              icon: Icon(
                                Icons.keyboard_arrow_down,
                                color: useLightText
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : themeData.iconTheme.color,
                                size: 28,
                              ),
                              tooltip: S.of(context).common_retract,
                            ),
                            // Center: Tab capsule (expanded to take remaining space)
                            Expanded(
                              child: Center(
                                child: Container(
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
                                      Tab(
                                        text: S.of(context).common_ai_subtitle,
                                      ),
                                      Tab(text: S.of(context).common_danmuku),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Right: Action button
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: IconButton(
                                key: ValueKey(isOnSubtitleTab),
                                onPressed: () {
                                  if (isOnSubtitleTab) {
                                    _showSubtitleSwitcher(context);
                                  } else {
                                    _showDanmakuList(context);
                                  }
                                },
                                icon: Icon(
                                  isOnSubtitleTab
                                      ? Icons.translate
                                      : Icons.list,
                                  color: useLightText
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : Colors.black54,
                                ),
                                tooltip: isOnSubtitleTab ? '切换字幕' : '弹幕列表',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _KeepAliveWrapper(
                              child: StreamBuilder<Duration>(
                                stream: playerProvider.player.positionStream,
                                builder: (context, snapshot) {
                                  final position =
                                      snapshot.data ?? Duration.zero;
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
                                                index:
                                                    _currentSubtitleIndex + 1,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsView(Song song, ThemeData theme) {
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

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
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
          area: 0.9,
          hideScroll: false,
          hideTop: false,
          hideBottom: false,
        ),
      ),
    );
  }
}
