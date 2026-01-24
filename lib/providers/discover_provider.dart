import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  List<DiscoverCategoryType> get visibleCategories => 
      _categoryOrder.where((type) => !_hiddenCategories.contains(type)).toList();

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
      _hiddenCategories = savedHidden.map((str) {
        try {
          final index = int.parse(str);
          if (index >= 0 && index < DiscoverCategoryType.values.length) {
            return DiscoverCategoryType.values[index];
          }
        } catch (e) {}
        return null;
      }).whereType<DiscoverCategoryType>().toSet();
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
    final List<String> orderToSave = _categoryOrder.map((e) => e.index.toString()).toList();
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
    final List<String> hiddenToSave = _hiddenCategories.map((e) => e.index.toString()).toList();
    await prefs.setStringList(_hiddenCategoriesKey, hiddenToSave);
  }
}
