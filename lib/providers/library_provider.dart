import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_category_widget.dart';

class LibraryProvider extends ChangeNotifier {
  static const String _categoryOrderKey = 'library_category_order';
  static const String _hiddenCategoriesKey = 'library_hidden_categories';

  List<PlaylistCategoryType> _categoryOrder = [
    PlaylistCategoryType.favorites,
    PlaylistCategoryType.collections,
    PlaylistCategoryType.local,
  ];

  Set<PlaylistCategoryType> _hiddenCategories = {};

  List<PlaylistCategoryType> get categoryOrder => _categoryOrder;
  Set<PlaylistCategoryType> get hiddenCategories => _hiddenCategories;

  // Returns only visible categories in order
  List<PlaylistCategoryType> get visibleCategories => 
      _categoryOrder.where((type) => !_hiddenCategories.contains(type)).toList();

  int _refreshSignal = 0;
  int get refreshSignal => _refreshSignal;

  bool _isLocalRefreshOnly = false;
  bool get isLocalRefreshOnly => _isLocalRefreshOnly;

  LibraryProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Order
    final List<String>? savedOrder = prefs.getStringList(_categoryOrderKey);
    if (savedOrder != null) {
      final List<PlaylistCategoryType> newOrder = [];
      for (var str in savedOrder) {
        try {
          final index = int.parse(str);
          if (index >= 0 && index < PlaylistCategoryType.values.length) {
            newOrder.add(PlaylistCategoryType.values[index]);
          }
        } catch (e) {}
      }

      final Set<PlaylistCategoryType> present = newOrder.toSet();
      for (var type in PlaylistCategoryType.values) {
        if (!present.contains(type)) {
          newOrder.add(type);
        }
      }
      _categoryOrder = newOrder;
    }

    // Load Hidden Categories
    final List<String>? savedHidden = prefs.getStringList(_hiddenCategoriesKey);
    if (savedHidden != null) {
      _hiddenCategories = savedHidden.map((str) {
        try {
          final index = int.parse(str);
          if (index >= 0 && index < PlaylistCategoryType.values.length) {
            return PlaylistCategoryType.values[index];
          }
        } catch (e) {}
        return null;
      }).whereType<PlaylistCategoryType>().toSet();
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

  Future<void> toggleCategoryVisibility(PlaylistCategoryType type) async {
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

  void refreshLibrary({bool localOnly = false}) {
    _isLocalRefreshOnly = localOnly;
    _refreshSignal++;
    notifyListeners();
  }
}
