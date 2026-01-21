import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:utopia_music/connection/audio/audio_stream.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/connection/utils/constants.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  static const int _maxCacheSize = 10 * 1024 * 1024;
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();
  final AudioStreamApi _audioStreamApi = AudioStreamApi();
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
      String? audioUrl;
      if (song.bvid.isNotEmpty && song.cid != 0) {
        audioUrl = await _audioStreamApi.getAudioStream(song.bvid, song.cid);
      }

      if (audioUrl != null && audioUrl.isNotEmpty) {
        final dirPath = await _getCacheDir();
        final String fileName = 'song_${song.bvid}_${song.cid}.m4s';
        final File cacheFile = File('$dirPath/$fileName');

        final source = LockCachingAudioSource(
          Uri.parse(audioUrl),
          cacheFile: cacheFile,
          headers: {
            'User-Agent': HttpConstants.userAgent,
            'Referer': HttpConstants.referer,
          },
          tag: MediaItem(
            id: '${song.bvid}_${song.cid}',
            title: song.title,
            artUri: Uri.parse(song.coverUrl),
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
      final List<FileSystemEntity> files = dir.listSync().where((e) {
        return e is File && e.path.endsWith('.m4s');
      }).toList();
      int totalSize = 0;
      for (var file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      if (totalSize < _maxCacheSize) return;
      print("Cache size (${totalSize / 1024 / 1024} MB) exceeds limit. Cleaning up...");
      files.sort((a, b) {
        return a.statSync().modified.compareTo(b.statSync().modified);
      });
      for (var file in files) {
        if (totalSize < _maxCacheSize) break;
        if (file is File) {
          final size = await file.length();
          await file.delete();
          totalSize -= size;
          print("Deleted old cache: ${file.path.split('/').last}");
        }
      }

    } catch (e) {
      print("Auto cache cleanup failed: $e");
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