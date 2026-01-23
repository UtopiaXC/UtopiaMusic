import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_category_widget.dart';

class LibraryProvider extends ChangeNotifier {
  static const String _categoryOrderKey = 'library_category_order';
  
  // Default order: Favorites, Collections, Local
  List<PlaylistCategoryType> _categoryOrder = [
    PlaylistCategoryType.favorites,
    PlaylistCategoryType.collections,
    PlaylistCategoryType.local,
  ];

  List<PlaylistCategoryType> get categoryOrder => _categoryOrder;

  // A simple counter or timestamp to trigger refresh
  int _refreshSignal = 0;
  int get refreshSignal => _refreshSignal;

  LibraryProvider() {
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedOrder = prefs.getStringList(_categoryOrderKey);
    
    if (savedOrder != null) {
      final List<PlaylistCategoryType> newOrder = [];
      for (var str in savedOrder) {
        // Find the enum value that matches the string index or name
        // Assuming we saved indices or names. Let's save indices for simplicity.
        try {
          final index = int.parse(str);
          if (index >= 0 && index < PlaylistCategoryType.values.length) {
            newOrder.add(PlaylistCategoryType.values[index]);
          }
        } catch (e) {
          // Ignore invalid data
        }
      }
      
      // Ensure all types are present and no duplicates
      final Set<PlaylistCategoryType> present = newOrder.toSet();
      for (var type in PlaylistCategoryType.values) {
        if (!present.contains(type)) {
          newOrder.add(type);
        }
      }
      
      _categoryOrder = newOrder;
      notifyListeners();
    }
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

  void refreshLibrary() {
    _refreshSignal++;
    notifyListeners();
  }
}
