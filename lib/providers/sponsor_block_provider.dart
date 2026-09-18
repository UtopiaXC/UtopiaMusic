import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/models/sponsor_block/segment_item_model.dart';
import 'package:utopia_music/models/sponsor_block/segment_model.dart';
import 'package:utopia_music/models/sponsor_block/segment_type.dart';
import 'package:utopia_music/models/sponsor_block/skip_type.dart';
import 'package:utopia_music/models/sponsor_block/user_info.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/services/sponsor_block/sponsor_block_service.dart';
import 'package:utopia_music/services/audio/audio_player_service.dart';
import 'package:utopia_music/main.dart';
import 'package:utopia_music/connection/video/search.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "SPONSOR_BLOCK_PROVIDER";

class SponsorBlockProvider extends ChangeNotifier {
  static const String _enableKey = 'enable_sponsor_block';
  static const String _serverKey = 'sponsor_block_server';
  static const String _limitKey = 'sponsor_block_limit';
  static const String _toastKey = 'sponsor_block_toast';
  static const String _trackKey = 'sponsor_block_track';
  static const String _userIdKey = 'sponsor_block_user_id';
  static const String _settingsKey = 'sponsor_block_settings';
  static const String _settingsVersionKey = 'sponsor_block_settings_v2';
  static const String _colorKey = 'sponsor_block_color';

  final SponsorBlockService _service = SponsorBlockService();
  final DatabaseService _dbService = DatabaseService();

  bool _enableSponsorBlock = true;
  String _blockServer = SponsorBlockService.defaultServer;
  double _blockLimit = 0.0;
  bool _blockToast = true;
  bool _blockTrack = true;
  String _blockUserID = '';
  final Map<SegmentType, SkipType> _blockSettings = {};
  final Map<SegmentType, Color> _blockColor = {};

  List<SegmentModel> _currentSegments = [];
  SegmentModel? _manualPromptSegment;
  Timer? _manualPromptTimer;
  bool? _serverStatus;
  UserInfo? _userInfo;
  bool _isLoadingUserInfo = false;
  int _lastCheckedMs = 0;
  String _currentSongBvid = '';
  int _currentSongCid = 0;
  int _loadRequestId = 0;
  StreamSubscription? _indexSub;
  StreamSubscription? _positionSub;

  bool get enableSponsorBlock => _enableSponsorBlock;
  String get blockServer => _blockServer;
  double get blockLimit => _blockLimit;
  bool get blockToast => _blockToast;
  bool get blockTrack => _blockTrack;
  String get blockUserID => _blockUserID;
  Map<SegmentType, SkipType> get blockSettings => Map.unmodifiable(_blockSettings);
  Map<SegmentType, Color> get blockColor => Map.unmodifiable(_blockColor);

  List<SegmentModel> get currentSegments => List.unmodifiable(_currentSegments);
  SegmentModel? get manualPromptSegment => _manualPromptSegment;
  bool? get serverStatus => _serverStatus;
  UserInfo? get userInfo => _userInfo;
  bool get isLoadingUserInfo => _isLoadingUserInfo;
  String get currentSongBvid => _currentSongBvid;
  int get currentSongCid => _currentSongCid;

  SponsorBlockProvider() {
    _init();
  }

  Future<void> _init() async {
    Log.v(_tag, "Initializing SponsorBlockProvider");
    final prefs = await SharedPreferences.getInstance();
    _enableSponsorBlock = prefs.getBool(_enableKey) ?? true;
    _blockServer = prefs.getString(_serverKey) ?? SponsorBlockService.defaultServer;
    _blockLimit = prefs.getDouble(_limitKey) ?? 0.0;
    _blockToast = prefs.getBool(_toastKey) ?? true;
    _blockTrack = prefs.getBool(_trackKey) ?? true;

    String? savedUserId = prefs.getString(_userIdKey);
    if (savedUserId == null || savedUserId.trim().isEmpty) {
      savedUserId = _generateRandomHexId();
      await prefs.setString(_userIdKey, savedUserId);
    }
    _blockUserID = savedUserId;

    // Load segment skip settings (v2 defaults: sponsor, padding, music_offtopic = skipOnce; others = showOnly)
    final settingsVersion = prefs.getInt(_settingsVersionKey) ?? 0;
    if (settingsVersion < 2) {
      for (var type in SegmentType.values) {
        _blockSettings[type] = getDefaultSkipType(type);
      }
      final list = SegmentType.values
          .map((t) => (_blockSettings[t]!).index.toString())
          .toList();
      await prefs.setStringList(_settingsKey, list);
      await prefs.setInt(_settingsVersionKey, 2);
    } else {
      final savedSettings = prefs.getStringList(_settingsKey);
      if (savedSettings != null && savedSettings.length == SegmentType.values.length) {
        for (int i = 0; i < SegmentType.values.length; i++) {
          final skipIndex = int.tryParse(savedSettings[i]) ??
              getDefaultSkipType(SegmentType.values[i]).index;
          _blockSettings[SegmentType.values[i]] = SkipType.values[skipIndex];
        }
      } else {
        for (var type in SegmentType.values) {
          _blockSettings[type] = getDefaultSkipType(type);
        }
      }
    }

    // Load segment colors
    final savedColors = prefs.getStringList(_colorKey);
    if (savedColors != null && savedColors.length == SegmentType.values.length) {
      for (int i = 0; i < SegmentType.values.length; i++) {
        final colorValue = int.tryParse(savedColors[i]);
        _blockColor[SegmentType.values[i]] =
            colorValue != null ? Color(colorValue) : SegmentType.values[i].color;
      }
    } else {
      for (var type in SegmentType.values) {
        _blockColor[type] = type.color;
      }
    }

    notifyListeners();

    _bindAudioService();

    if (_enableSponsorBlock) {
      checkServerStatus();
      fetchUserInfo();
      final audioService = AudioPlayerService();
      loadSegmentsForSong(audioService.currentSong);
    }
  }

  void _bindAudioService() {
    final audioService = AudioPlayerService();
    _indexSub?.cancel();
    _indexSub = audioService.currentIndexStream.listen((index) {
      if (!_enableSponsorBlock) return;
      final song = audioService.currentSong;
      loadSegmentsForSong(song);
    });

    _positionSub?.cancel();
    _positionSub = audioService.player.positionStream.listen((position) {
      if (!_enableSponsorBlock) return;
      onPositionTick(
        position: position,
        seekTo: (target) => audioService.player.seek(target),
        showToast: _showToast,
      );
    });
  }

  void _showToast(String msg) {
    if (!_blockToast) return;
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _indexSub?.cancel();
    _positionSub?.cancel();
    _manualPromptTimer?.cancel();
    super.dispose();
  }

  String _generateRandomHexId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return md5.convert(bytes).toString();
  }

  static SkipType getDefaultSkipType(SegmentType type) {
    if (type == SegmentType.sponsor ||
        type == SegmentType.padding ||
        type == SegmentType.music_offtopic) {
      return SkipType.skipOnce;
    }
    return SkipType.showOnly;
  }

  Color getColor(SegmentType type) => _blockColor[type] ?? type.color;
  SkipType getSkipType(SegmentType type) => _blockSettings[type] ?? getDefaultSkipType(type);

  Future<void> resetAllCategoriesToDefault() async {
    for (var type in SegmentType.values) {
      _blockSettings[type] = getDefaultSkipType(type);
    }
    final prefs = await SharedPreferences.getInstance();
    final list = SegmentType.values
        .map((t) => (_blockSettings[t]!).index.toString())
        .toList();
    await prefs.setStringList(_settingsKey, list);
    notifyListeners();
  }

  Future<void> setEnableSponsorBlock(bool value) async {
    _enableSponsorBlock = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableKey, value);
    if (value) {
      checkServerStatus();
      fetchUserInfo();
      final audioService = AudioPlayerService();
      loadSegmentsForSong(audioService.currentSong);
    } else {
      _currentSegments = [];
      _manualPromptSegment = null;
      _manualPromptTimer?.cancel();
      _currentSongBvid = '';
      _currentSongCid = 0;
    }
    notifyListeners();
  }

  Future<void> setBlockServer(String value) async {
    _blockServer = value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, _blockServer);
    checkServerStatus();
    fetchUserInfo();
    notifyListeners();
  }

  Future<void> resetBlockServer() async {
    await setBlockServer(SponsorBlockService.defaultServer);
  }

  Future<void> setBlockLimit(double value) async {
    _blockLimit = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_limitKey, value);
    notifyListeners();
  }

  Future<void> setBlockToast(bool value) async {
    _blockToast = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_toastKey, value);
    notifyListeners();
  }

  Future<void> setBlockTrack(bool value) async {
    _blockTrack = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trackKey, value);
    notifyListeners();
  }

  Future<void> setBlockUserID(String value) async {
    _blockUserID = value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, _blockUserID);
    fetchUserInfo();
    notifyListeners();
  }

  Future<void> generateAndSetRandomUserId() async {
    final newId = _generateRandomHexId();
    await setBlockUserID(newId);
  }

  Future<void> updateCategorySkipType(SegmentType type, SkipType skipType) async {
    _blockSettings[type] = skipType;
    final prefs = await SharedPreferences.getInstance();
    final list = SegmentType.values.map((t) => (_blockSettings[t] ?? SkipType.skipOnce).index.toString()).toList();
    await prefs.setStringList(_settingsKey, list);
    notifyListeners();
  }

  Future<void> updateCategoryColor(SegmentType type, Color color) async {
    _blockColor[type] = color;
    final prefs = await SharedPreferences.getInstance();
    final list = SegmentType.values.map((t) => (_blockColor[t] ?? t.color).toARGB32().toString()).toList();
    await prefs.setStringList(_colorKey, list);
    notifyListeners();
  }

  Future<void> resetCategoryColor(SegmentType type) async {
    await updateCategoryColor(type, type.color);
  }

  Future<void> checkServerStatus() async {
    _serverStatus = null;
    notifyListeners();
    final ok = await _service.uptimeStatus(server: _blockServer);
    _serverStatus = ok;
    notifyListeners();
  }

  Future<void> fetchUserInfo() async {
    if (_blockUserID.isEmpty) return;
    _isLoadingUserInfo = true;
    notifyListeners();
    final info = await _service.getUserInfo(
      server: _blockServer,
      userId: _blockUserID,
    );
    _userInfo = info;
    _isLoadingUserInfo = false;
    notifyListeners();
  }

  Future<void> loadSegmentsForSong(Song? song, {Duration? currentPosition}) async {
    final nextBvid = song?.bvid ?? '';
    final nextCid = song?.cid ?? 0;
    final int requestId = ++_loadRequestId;

    // Immediately clear current segments on song change to avoid flashing old segments
    _currentSegments = [];
    _manualPromptSegment = null;
    _manualPromptTimer?.cancel();
    _lastCheckedMs = 0;
    _currentSongBvid = nextBvid;
    _currentSongCid = nextCid;
    notifyListeners();

    if (!_enableSponsorBlock || song == null || song.bvid.isEmpty) {
      return;
    }

    final bvid = song.bvid;
    int cid = song.cid;

    // 1. If CID is unknown or 0, resolve the real CID asynchronously
    if (cid <= 0) {
      try {
        final fetchedCid = await SearchApi().fetchCid(bvid);
        if (requestId != _loadRequestId) return;
        if (fetchedCid > 0) {
          cid = fetchedCid;
          _currentSongCid = cid;
        }
      } catch (e) {
        Log.w(_tag, 'Failed to resolve CID for $bvid: $e');
      }
    }

    if (requestId != _loadRequestId) return;

    // 2. Check local database cache first (supports offline & downloaded tracks)
    final localData = await _dbService.getSponsorBlockSegments(bvid, cid);
    if (requestId != _loadRequestId) return;

    if (localData != null && localData.isNotEmpty) {
      try {
        final decoded = jsonDecode(localData);
        if (decoded is List) {
          final items = decoded
              .map((i) => SegmentItemModel.fromJson(i as Map<String, dynamic>))
              .toList();
          if (requestId == _loadRequestId) {
            _applySegmentItems(items);
            Log.i(
              _tag,
              'Loaded ${_currentSegments.length} segments from local DB for ${bvid}_$cid',
            );
          }
        }
      } catch (e) {
        Log.w(_tag, 'Error decoding local cached segments: $e');
      }
    }

    if (requestId != _loadRequestId) return;

    // 3. Fetch fresh segments from remote network API
    try {
      final remoteItems = await _service.getSkipSegments(
        server: _blockServer,
        bvid: bvid,
        cid: cid,
      );
      if (requestId != _loadRequestId) return;

      if (remoteItems != null) {
        _applySegmentItems(remoteItems);
        // Update local database cache
        final jsonStr = jsonEncode(remoteItems.map((s) => s.toJson()).toList());
        await _dbService.saveSponsorBlockSegments(bvid, cid, jsonStr);
        Log.i(
          _tag,
          'Fetched and cached ${remoteItems.length} segments for ${bvid}_$cid',
        );
      }
    } catch (e) {
      Log.w(_tag, 'Failed to fetch remote segments: $e');
    }
  }

  void _applySegmentItems(List<SegmentItemModel> items) {
    final double blockLimitMs = _blockLimit * 1000;
    final List<SegmentModel> list = [];

    for (var item in items) {
      final model = SegmentModel.fromItemModel(
        item,
        blockSettings: _blockSettings,
        blockLimitMs: blockLimitMs,
      );
      if (model.skipType != SkipType.disable && model.segment.$2 >= model.segment.$1) {
        list.add(model);
      }
    }

    list.sort();
    _currentSegments = list;
    _lastCheckedMs = 0;
    notifyListeners();

    final audioService = AudioPlayerService();
    if (audioService.player.position.inSeconds <= 1) {
      final initialSkip = getInitialSkipPosition(audioService.player.position.inMilliseconds);
      if (initialSkip != null) {
        audioService.player.seek(initialSkip);
        _showToast('已跳过开场片段');
      }
    }
  }

  Duration? getInitialSkipPosition([int posMs = 0]) {
    if (!_enableSponsorBlock || _currentSegments.isEmpty) return null;
    int targetMs = posMs;
    for (var item in _currentSegments) {
      final (start, end) = item.segment;
      if (start == end) continue;
      if (start - targetMs < 300) {
        if (item.skipType == SkipType.alwaysSkip ||
            (item.skipType == SkipType.skipOnce && !item.hasSkipped)) {
          item.hasSkipped = true;
          targetMs = max(targetMs, end);
        }
      } else {
        break;
      }
    }
    if (targetMs > posMs) {
      return Duration(milliseconds: targetMs);
    }
    return null;
  }

  void onPositionTick({
    required Duration position,
    required Function(Duration) seekTo,
    required Function(String) showToast,
  }) {
    if (!_enableSponsorBlock || _currentSegments.isEmpty) return;

    final currentMs = position.inMilliseconds;

    // Check if manual prompt is active and whether current position is still within its segment
    if (_manualPromptSegment != null) {
      final (pStart, pEnd) = _manualPromptSegment!.segment;
      if (currentMs < pStart || currentMs >= pEnd) {
        dismissManualPrompt();
      }
    }

    // Throttle frequent ticks to ~200ms unless seeking occurred (gap >= 1000ms)
    final diff = (currentMs - _lastCheckedMs).abs();
    if (diff < 200) {
      return;
    }
    _lastCheckedMs = currentMs;

    for (final item in _currentSegments) {
      // If position is before the segment, reset hasSkipped so it can skip if re-entered later
      if (currentMs < item.segment.$1 - 1000) {
        item.hasSkipped = false;
      }

      // If position falls anywhere within the skippable segment
      // (from start up to end - 500ms to avoid infinite skip loop at the very end edge)
      if (currentMs >= item.segment.$1 && currentMs < item.segment.$2 - 500) {
        switch (item.skipType) {
          case SkipType.alwaysSkip:
            _executeSkip(item, seekTo: seekTo, showToast: showToast);
            return;
          case SkipType.skipOnce:
            if (!item.hasSkipped) {
              item.hasSkipped = true;
              _executeSkip(item, seekTo: seekTo, showToast: showToast);
              return;
            }
            break;
          case SkipType.skipManually:
            _promptManualSkip(item);
            return;
          case SkipType.showOnly:
          case SkipType.disable:
            break;
        }
      }
    }
  }

  void _executeSkip(
    SegmentModel item, {
    required Function(Duration) seekTo,
    required Function(String) showToast,
  }) {
    final target = Duration(milliseconds: item.segment.$2);
    seekTo(target);

    if (_blockToast) {
      if (item.segmentType == SegmentType.poi_highlight) {
        showToast('已跳至${item.segmentType.shortTitle}');
      } else {
        showToast('已跳过${item.segmentType.shortTitle}片段');
      }
    }

    if (_blockTrack && item.uuid.isNotEmpty) {
      _service.viewedVideoSponsorTime(
        server: _blockServer,
        uuid: item.uuid,
      );
    }
  }

  void _promptManualSkip(SegmentModel item) {
    if (_manualPromptSegment == item) return;
    _manualPromptSegment = item;
    notifyListeners();

    _manualPromptTimer?.cancel();
    _manualPromptTimer = Timer(const Duration(seconds: 4), () {
      _manualPromptSegment = null;
      notifyListeners();
    });
  }

  void skipManualSegment(
    SegmentModel item, {
    required Function(Duration) seekTo,
    required Function(String) showToast,
  }) {
    _manualPromptTimer?.cancel();
    _manualPromptSegment = null;
    _executeSkip(item, seekTo: seekTo, showToast: showToast);
    notifyListeners();
  }

  void dismissManualPrompt() {
    _manualPromptTimer?.cancel();
    _manualPromptSegment = null;
    notifyListeners();
  }

  Future<bool> voteOnSegment(SegmentModel item, int type) async {
    if (item.uuid.isEmpty) return false;
    final success = await _service.voteOnSponsorTime(
      server: _blockServer,
      uuid: item.uuid,
      userId: _blockUserID,
      type: type,
    );
    return success;
  }

  Future<bool> changeCategory(SegmentModel item, SegmentType newCategory) async {
    if (item.uuid.isEmpty) return false;
    final success = await _service.voteOnSponsorTime(
      server: _blockServer,
      uuid: item.uuid,
      userId: _blockUserID,
      category: newCategory,
    );
    return success;
  }
}
