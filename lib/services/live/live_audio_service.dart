import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:utopia_music/connection/utils/constants.dart';
import 'package:utopia_music/models/live_room.dart';
import 'package:utopia_music/services/audio/audio_player_service.dart';
import 'package:utopia_music/services/live/live_flv_audio_source.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = 'LIVE_AUDIO_SERVICE';

/// Narrow interface isolating live playback implementation for testing and decoupling.
abstract class LiveAudioServiceProtocol {
  Stream<PlayerState> get playerStateStream;
  Future<bool> playStreamUrls(
    List<String> urls, {
    LiveRoom? room,
    bool Function()? isCancelled,
  });
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  void dispose();
}

/// Live audio rendering pipeline dedicated solely to Bilibili live rooms.
///
/// Shares the single hardware [AudioPlayer] output session so live and VOD playback
/// cannot overlap, while bypassing [BiliAudioSource], download queues, caching,
/// playlist persistence, and history reporting.
class LiveAudioService implements LiveAudioServiceProtocol {
  AudioPlayer? _player;
  final bool _useSharedPlayer;
  StreamSubscription<PlayerState>? _playerStateSub;
  final StreamController<PlayerState> _stateController =
      StreamController<PlayerState>.broadcast();

  LiveAudioService({AudioPlayer? player})
    : _player = player,
      _useSharedPlayer = player == null {
    if (player != null) {
      _attachPlayer(player);
    }
  }

  AudioPlayer _ensurePlayer() {
    if (_player == null) {
      final shared = AudioPlayerService().player;
      _player = shared;
      _attachPlayer(shared);
    }
    return _player!;
  }

  void _attachPlayer(AudioPlayer player) {
    _playerStateSub?.cancel();
    _playerStateSub = player.playerStateStream.listen((state) {
      if (!_stateController.isClosed) {
        _stateController.add(state);
      }
    });
  }

  @override
  Stream<PlayerState> get playerStateStream => _stateController.stream;

  bool get isPlaying => _player?.playing ?? false;

  /// Attempts each candidate stream URL in order until one initializes and plays.
  @override
  Future<bool> playStreamUrls(
    List<String> urls, {
    LiveRoom? room,
    bool Function()? isCancelled,
  }) async {
    if (urls.isEmpty || isCancelled?.call() == true) return false;
    final player = _ensurePlayer();
    if (_useSharedPlayer) {
      AudioPlayerService().setLiveMode(true);
    }

    final headers = <String, String>{
      'Referer': 'https://live.bilibili.com/',
      'User-Agent': HttpConstants.userAgent,
    };
    final mediaTag = room == null
        ? null
        : MediaItem(
            id: 'live_${room.roomId}',
            title: room.title.isEmpty ? '${room.roomId}' : room.title,
            artist: room.uname,
            artUri: Uri.tryParse(room.cover.isNotEmpty ? room.cover : room.face),
          );

    try {
      await player.setLoopMode(LoopMode.off);
      await player.setSpeed(1.0);
    } catch (_) {}

    final List<String> rawFlvFallbacks = [];

    for (final url in urls) {
      if (isCancelled?.call() == true) return false;
      final uri = Uri.tryParse(url);
      if (uri == null) continue;
      final isFlv = uri.path.toLowerCase().endsWith('.flv');
      if (isFlv) {
        rawFlvFallbacks.add(url);
      }

      final AudioSource source = isFlv
          ? LiveFlvAacAudioSource(uri, headers: headers, tag: mediaTag)
          : AudioSource.uri(uri, headers: headers, tag: mediaTag);
      final timeout = isFlv
          ? const Duration(seconds: 8)
          : const Duration(seconds: 10);

      if (await _tryPlaySource(
        player: player,
        source: source,
        label: url,
        timeout: timeout,
        isCancelled: isCancelled,
      )) {
        return true;
      }
    }

    // Fallback to raw FLV only if ADTS demuxing did not succeed (e.g. exotic codec).
    for (final url in rawFlvFallbacks) {
      if (isCancelled?.call() == true) return false;
      final uri = Uri.tryParse(url);
      if (uri == null) continue;
      if (await _tryPlaySource(
        player: player,
        source: AudioSource.uri(uri, headers: headers, tag: mediaTag),
        label: '$url (raw-flv)',
        timeout: const Duration(seconds: 15),
        isCancelled: isCancelled,
      )) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _tryPlaySource({
    required AudioPlayer player,
    required AudioSource source,
    required String label,
    required Duration timeout,
    bool Function()? isCancelled,
  }) async {
    try {
      await player.stop();
      if (isCancelled?.call() == true) return false;

      await player.setAudioSource(source).timeout(timeout);
      if (isCancelled?.call() == true) {
        await player.stop();
        return false;
      }

      await player.play();
      return true;
    } catch (e) {
      if (isCancelled?.call() == true) return false;
      Log.w(_tag, 'Failed to open live stream url ($label): $e');
      return false;
    }
  }

  @override
  Future<void> pause() async {
    await _player?.pause();
  }

  @override
  Future<void> resume() async {
    await _player?.play();
  }

  @override
  Future<void> stop() async {
    try {
      if (_useSharedPlayer) {
        AudioPlayerService().setLiveMode(false);
      }
      await _player?.stop();
    } catch (e) {
      Log.w(_tag, 'Failed to stop live player: $e');
    }
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _stateController.close();
    if (!_useSharedPlayer) {
      _player?.dispose();
    }
  }
}
