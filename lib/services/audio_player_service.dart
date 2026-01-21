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
  static const int _maxCacheSize = 100 * 1024 * 1024; // 100 MB
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();
  final AudioStreamApi _audioStreamApi = AudioStreamApi();
  final SearchApi _searchApi = SearchApi();
  String? _cacheDir;
  
  String? _currentPlayingBvid;

  AudioPlayer get player => _player;

  Future<String> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final dir = await getTemporaryDirectory();
    _cacheDir = "${dir.path}/utopiaMusicCache";
    final directory = Directory(_cacheDir!);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return _cacheDir!;
  }

  Future<void> playSong(Song song) async {
    try {
      await _player.stop();
      await Future.delayed(const Duration(milliseconds: 200));

      if (_currentPlayingBvid != null) {
        await _tryRescueFailedRename(_currentPlayingBvid!);
      }

      await _performSmartCacheCleanup();
      
      _currentPlayingBvid = song.bvid;

      int cid = song.cid;
      // Try to fetch CID if missing
      if (cid == 0 && song.bvid.isNotEmpty) {
        try {
          cid = await _searchApi.fetchCid(song.bvid);
        } catch (e) {
          print("Network error fetching CID: $e");
        }
      }

      final dirPath = await _getCacheDir();
      final String fileName = 'song_${song.bvid}.m4s';
      final File cacheFile = File('$dirPath/$fileName');
      bool isCacheAvailable = await cacheFile.exists();

      String? audioUrl;

      if (song.bvid.isNotEmpty && cid != 0) {
        try {
          audioUrl = await _audioStreamApi.getAudioStream(song.bvid, cid);
        } catch (e) {
          print("Network error fetching audio stream: $e");
        }
      }

      if (audioUrl == null || audioUrl.isEmpty) {
        if (isCacheAvailable) {
          print("Network failed but cache found. Playing offline: ${song.title}");
          audioUrl = "http://localhost/offline_fallback_${song.bvid}"; 
        } else {
          print("Failed to play: No network and no cache for ${song.title}");
          return;
        }
      }

      if (audioUrl != null) {
        if (isCacheAvailable) {
          try {
            await cacheFile.setLastModified(DateTime.now());
          } catch (e) {
            print("Failed to update last modified time: $e");
          }
        }

        final source = LockCachingAudioSource(
          Uri.parse(audioUrl),
          cacheFile: cacheFile,
          headers: {
            'User-Agent': HttpConstants.userAgent,
            'Referer': HttpConstants.referer,
          },
          tag: MediaItem(
            id: song.bvid,
            title: song.title,
            artist: song.artist,
            artUri: song.coverUrl.isNotEmpty ? Uri.parse(song.coverUrl) : null,
          ),
        );

        await _player.setAudioSource(source);
        await _player.play();
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
    Future.delayed(const Duration(milliseconds: 200), () async {
       if (_currentPlayingBvid != null) {
         await _tryRescueFailedRename(_currentPlayingBvid!);
         _currentPlayingBvid = null;
       }
    });
  }

  Future<void> _tryRescueFailedRename(String bvid) async {
    try {
      final dirPath = await _getCacheDir();
      final String fileName = 'song_$bvid.m4s';
      final File cacheFile = File('$dirPath/$fileName');
      final File partFile = File('$dirPath/$fileName.part');

      if (await partFile.exists() && !await cacheFile.exists()) {
        print("Attempting to rescue failed rename for $bvid...");
        try {
          await partFile.rename(cacheFile.path);
          print("Successfully rescued cache file: $fileName");
        } catch (e) {
          print("Failed to rescue cache file (rename failed): $e");
        }
      }
    } catch (e) {
      print("Error during rescue: $e");
    }
  }

  Future<void> _performSmartCacheCleanup() async {
    try {
      final dirPath = await _getCacheDir();
      final dir = Directory(dirPath);
      if (!await dir.exists()) return;
      
      final List<FileSystemEntity> entities = dir.listSync();
      List<File> cacheFiles = [];
      int totalCacheSize = 0;

      for (var entity in entities) {
        if (entity is File) {
          final path = entity.path;
          final filename = path.split(Platform.pathSeparator).last;

          if (path.endsWith('.mine')) {
             final baseName = path.substring(0, path.length - 5); // remove .mine
             // Only delete .mine if neither .m4s nor .part exists
             if (!await File(baseName).exists() && !await File('$baseName.part').exists()) {
                await _tryDeleteFile(entity);
                print("Deleted orphaned .mine file: $filename");
             }
          }
          else if (path.endsWith('.part')) {
             await _tryDeleteFile(entity);
             print("Deleted stale .part file: $filename");
          }
          else if (path.endsWith('.m4s')) {
            cacheFiles.add(entity);
            totalCacheSize += await entity.length();
          }
        }
      }

      if (totalCacheSize > _maxCacheSize) {
        print("Cache full (${totalCacheSize ~/ 1024 ~/ 1024}MB). Trimming...");
        
        cacheFiles.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
        
        for (var file in cacheFiles) {
          if (totalCacheSize <= _maxCacheSize) break;

          bool deleted = await _tryDeleteFile(file);
          if (deleted) {
            print("Deleted old cache file: ${file.path.split(Platform.pathSeparator).last}");
            final mineFile = File('${file.path}.mine');
            if (await mineFile.exists()) {
               await _tryDeleteFile(mineFile);
               print("Deleted corresponding .mine file");
            }
          }
        }
      }
    } catch (e) {
      print("Cache cleanup routine warning: $e");
    }
  }

  Future<bool> _tryDeleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        if (await file.exists()) {
          await file.delete();
          return true;
        }
      } catch (e2) {
        return false;
      }
    }
    return false;
  }

  Future<void> clearCache() async {
    try {
      final dirPath = await _getCacheDir();
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await _player.stop();
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          await dir.delete(recursive: true);
          print("Cache directory deleted.");
        } catch (e) {
           dir.listSync().forEach((entity) {
             if (entity is File) {
               try { entity.deleteSync(); } catch(e) {}
             }
           });
        }
      }
    } catch (e) {
      print("Error clearing cache: $e");
    }
  }

  void dispose() {
    _player.dispose();
  }
}
