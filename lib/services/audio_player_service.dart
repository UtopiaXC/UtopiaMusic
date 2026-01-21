import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:utopia_music/connection/audio/audio_stream.dart';
import 'package:utopia_music/connection/video/search_api.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/connection/utils/constants.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  static const Duration _staleThreshold = Duration(hours: 24);
  static const int _maxCacheSize = 10 * 1024 * 1024;
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();
  final AudioStreamApi _audioStreamApi = AudioStreamApi();
  final SearchApi _searchApi = SearchApi();
  String? _cacheDir;

  AudioPlayer get player => _player;

  Future<String> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final dir = await getTemporaryDirectory();
    _cacheDir = dir.path;
    return _cacheDir!;
  }

  Future<void> playSong(Song song) async {
    try {
      _performLRUCacheCleanup();
      int cid = song.cid;
      if (cid == 0 && song.bvid.isNotEmpty) {
        cid = await _searchApi.fetchCid(song.bvid);
        if (cid == 0) {
          print("Failed to fetch CID for song: ${song.title}");
          return;
        }
      }

      String? audioUrl;
      if (song.bvid.isNotEmpty && cid != 0) {
        audioUrl = await _audioStreamApi.getAudioStream(song.bvid, cid);
      }

      if (audioUrl != null && audioUrl.isNotEmpty) {
        final dirPath = await _getCacheDir();
        final String fileName = 'song_${song.bvid}_$cid.m4s';
        final File cacheFile = File('$dirPath/$fileName');

        final source = LockCachingAudioSource(
          Uri.parse(audioUrl),
          cacheFile: cacheFile,
          headers: {
            'User-Agent': HttpConstants.userAgent,
            'Referer': HttpConstants.referer,
          },
          tag: MediaItem(
            id: '${song.bvid}_$cid',
            title: song.title,
            artist: song.artist,
            artUri: song.coverUrl.isNotEmpty ? Uri.parse(song.coverUrl) : null,
          ),
        );

        await _player.setAudioSource(source);
        await _player.play();
      } else {
        print("No audio url found for song: ${song.title}");
      }
    } catch (e) {
      print("Error playing audio: $e");
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> _performLRUCacheCleanup() async {
    try {
      final dirPath = await _getCacheDir();
      final dir = Directory(dirPath);
      if (!await dir.exists()) return;
      final List<FileSystemEntity> entities = dir.listSync();
      int totalM4sSize = 0;
      List<File> m4sFiles = [];
      for (var entity in entities) {
        if (entity is! File) continue;
        final path = entity.path;
        if (path.endsWith('.part')) {
          try {
            final stat = await entity.stat();
            final age = DateTime.now().difference(stat.modified);
            if (age > _staleThreshold) {
              print("Cleaning stale temp file: ${path.split(Platform.pathSeparator).last}");
              await entity.delete();
            }
          } catch (e) {
            print("Skipped locked temp file: ${path.split(Platform.pathSeparator).last}");
          }
        }
        else if (path.endsWith('.m4s')) {
          m4sFiles.add(entity);
          totalM4sSize += await entity.length();
        }
      }
      if (totalM4sSize > _maxCacheSize) {
        print("Cache full (${totalM4sSize ~/ 1024 ~/ 1024}MB). Trimming...");
        m4sFiles.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
        for (var file in m4sFiles) {
          if (totalM4sSize < _maxCacheSize) break;

          try {
            final size = await file.length();
            await file.delete();
            totalM4sSize -= size;
            print("Deleted old cache: ${file.path.split(Platform.pathSeparator).last}");
          } catch (e) {
            print("Skipped locked cache file: ${file.path.split(Platform.pathSeparator).last}");
          }
        }
      }
    } catch (e) {
      print("Cleanup routine warning: $e");
    }
  }

  Future<void> clearCache() async {
    try {
      final dirPath = await _getCacheDir();
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        dir.listSync().forEach((FileSystemEntity entity) {
          if (entity is File && entity.path.endsWith('.m4s')) {
            entity.deleteSync();
          }
        });
      }
    } catch (e) {
      print("Error clearing cache: $e");
    }
  }

  void dispose() {
    _player.dispose();
  }
}
