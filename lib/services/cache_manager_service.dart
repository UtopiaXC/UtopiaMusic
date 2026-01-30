import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/utils/log.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

const String _tag = "CACHE_MANAGER_SERVICE";

class CacheManagerService {
  static final CacheManagerService _instance = CacheManagerService._internal();
  factory CacheManagerService() => _instance;
  CacheManagerService._internal();

  static const String _prefKeyMaxCacheSize = 'other_cache_max_size_mb';
  static const int _defaultMaxCacheSizeMb = 50;
  static const int _minCacheSizeMb = 10;
  static const double _cleanupThreshold = 0.8;

  final DatabaseService _db = DatabaseService();

  Future<void> init() async {
    await _db.database;
  }

  Future<int> getMaxCacheSize() async {
    final prefs = await SharedPreferences.getInstance();
    final size = prefs.getInt(_prefKeyMaxCacheSize) ?? _defaultMaxCacheSizeMb;
    return size < _minCacheSizeMb ? _minCacheSizeMb : size;
  }

  Future<bool> setMaxCacheSize(int sizeMb) async {
    if (sizeMb < _minCacheSizeMb) {
      Log.w(
        _tag,
        "Rejected cache size $sizeMb MB - minimum is $_minCacheSizeMb MB",
      );
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyMaxCacheSize, sizeMb);
    Log.v(_tag, "Max cache size set to $sizeMb MB");
    await _checkAndCleanup();
    return true;
  }

  Future<int> getUsedCacheSize() async {
    int total = 0;

    try {
      total += await _db.getListCacheSize();
    } catch (e) {
      Log.w(_tag, "Error getting list cache size: $e");
    }

    try {
      final cacheDir = await getTemporaryDirectory();
      final imageCacheDir = Directory('${cacheDir.path}/libCachedImageData');
      if (await imageCacheDir.exists()) {
        await for (var entity in imageCacheDir.list(recursive: true)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
    } catch (e) {
      Log.w(_tag, "Error getting image cache size: $e");
    }

    return total;
  }

  Future<void> _checkAndCleanup() async {
    try {
      final maxBytes = (await getMaxCacheSize()) * 1024 * 1024;
      final usedBytes = await getUsedCacheSize();
      final threshold = maxBytes * _cleanupThreshold;

      if (usedBytes > threshold) {
        Log.v(
          _tag,
          "Cache cleanup triggered: $usedBytes bytes > $threshold threshold",
        );
        final bytesToFree = usedBytes - (maxBytes * 0.5).toInt();
        await _db.cleanupListCacheLFU(bytesToFree);
      }
    } catch (e) {
      Log.w(_tag, "Error during cache cleanup check: $e");
    }
  }

  Future<void> clearAllCache() async {
    Log.v(_tag, "Clearing all other cache");
    try {
      await _db.clearListCache();
      Log.v(_tag, "List cache cleared");
    } catch (e) {
      Log.w(_tag, "Error clearing list cache: $e");
    }

    try {
      await DefaultCacheManager().emptyCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      Log.v(_tag, "Image cache cleared");
    } catch (e) {
      Log.w(_tag, "Error clearing image cache: $e");
    }
  }

  static String formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }
}
