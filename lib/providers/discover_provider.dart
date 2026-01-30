import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/utils/log.dart';

enum DiscoverCategoryType {
  recommend,
  feed,
  history,
  subscribe,
  live,
  rank,
  musicRank,
  kichikuRank,
}

class DiscoverProvider extends ChangeNotifier {
  static const String _categoryOrderKey = 'discover_category_order';
  static const String _hiddenCategoriesKey = 'discover_hidden_categories';

  List<DiscoverCategoryType> _categoryOrder = [
    DiscoverCategoryType.recommend,
    DiscoverCategoryType.feed,
    DiscoverCategoryType.history,
    DiscoverCategoryType.subscribe,
    DiscoverCategoryType.live,
    DiscoverCategoryType.rank,
    DiscoverCategoryType.musicRank,
    DiscoverCategoryType.kichikuRank,
  ];

  Set<DiscoverCategoryType> _hiddenCategories = {};

  List<DiscoverCategoryType> get categoryOrder => _categoryOrder;
  Set<DiscoverCategoryType> get hiddenCategories => _hiddenCategories;

  List<DiscoverCategoryType> get visibleCategories => _categoryOrder
      .where((type) => !_hiddenCategories.contains(type))
      .toList();

  DiscoverProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final List<String>? savedOrder = prefs.getStringList(_categoryOrderKey);
    if (savedOrder != null) {
      final List<DiscoverCategoryType> newOrder = [];
      for (var str in savedOrder) {
        try {
          final index = int.parse(str);
          if (index >= 0 && index < DiscoverCategoryType.values.length) {
            newOrder.add(DiscoverCategoryType.values[index]);
          }
        } catch (e) {}
      }

      final Set<DiscoverCategoryType> present = newOrder.toSet();
      for (var type in DiscoverCategoryType.values) {
        if (!present.contains(type)) {
          newOrder.add(type);
        }
      }
      _categoryOrder = newOrder;
    }

    final List<String>? savedHidden = prefs.getStringList(_hiddenCategoriesKey);
    if (savedHidden != null) {
      _hiddenCategories = savedHidden
          .map((str) {
            try {
              final index = int.parse(str);
              if (index >= 0 && index < DiscoverCategoryType.values.length) {
                return DiscoverCategoryType.values[index];
              }
            } catch (e) {}
            return null;
          })
          .whereType<DiscoverCategoryType>()
          .toSet();
    }

    notifyListeners();
  }

  Future<void> updateOrder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _categoryOrder.removeAt(oldIndex);
    _categoryOrder.insert(newIndex, item);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final List<String> orderToSave = _categoryOrder
        .map((e) => e.index.toString())
        .toList();
    await prefs.setStringList(_categoryOrderKey, orderToSave);
  }

  Future<void> toggleCategoryVisibility(DiscoverCategoryType type) async {
    if (_hiddenCategories.contains(type)) {
      _hiddenCategories.remove(type);
    } else {
      _hiddenCategories.add(type);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final List<String> hiddenToSave = _hiddenCategories
        .map((e) => e.index.toString())
        .toList();
    await prefs.setStringList(_hiddenCategoriesKey, hiddenToSave);
  }

  static const String _cacheKey = 'discover_first_tab_cache';
  static const String _scrollPositionKey = 'discover_first_tab_scroll';
  static const String _tag = 'DISCOVER_PROVIDER';

  final DatabaseService _db = DatabaseService();
  DiscoverCategoryType get firstVisibleCategory => visibleCategories.isNotEmpty
      ? visibleCategories.first
      : DiscoverCategoryType.recommend;

  Future<void> saveFirstTabCache(List<Song> songs) async {
    try {
      final jsonList = songs
          .take(30)
          .map(
            (s) => {
              'title': s.title,
              'originTitle': s.originTitle,
              'artist': s.artist,
              'coverUrl': s.coverUrl,
              'lyrics': s.lyrics,
              'bvid': s.bvid,
              'cid': s.cid,
              'colorValue': s.colorValue,
            },
          )
          .toList();
      final jsonStr = json.encode(jsonList);
      await _db.saveListCache(_cacheKey, jsonStr);
      Log.v(_tag, 'Saved first tab cache: ${songs.length} songs (max 30)');
    } catch (e) {
      Log.w(_tag, 'Failed to save first tab cache: $e');
    }
  }

  Future<List<Song>> loadFirstTabCache() async {
    try {
      final jsonStr = await _db.getListCache(_cacheKey);
      if (jsonStr == null) return [];

      final List<dynamic> jsonList = json.decode(jsonStr);
      final songs = jsonList
          .map(
            (item) => Song(
              title: item['title'] ?? '',
              originTitle: item['originTitle'],
              artist: item['artist'] ?? '',
              coverUrl: item['coverUrl'] ?? '',
              lyrics: item['lyrics'] ?? '',
              bvid: item['bvid'] ?? '',
              cid: item['cid'] ?? 0,
              colorValue: item['colorValue'] ?? 0,
            ),
          )
          .toList();
      Log.v(_tag, 'Loaded first tab cache: ${songs.length} songs');
      return songs;
    } catch (e) {
      Log.w(_tag, 'Failed to load first tab cache: $e');
      return [];
    }
  }

  Future<void> saveScrollPosition(double position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_scrollPositionKey, position);
  }

  Future<double> loadScrollPosition() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_scrollPositionKey) ?? 0.0;
  }

  Future<void> clearFirstTabCache() async {
    await _db.deleteListCache(_cacheKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scrollPositionKey);
  }
}
