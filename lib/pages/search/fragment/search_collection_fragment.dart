import 'package:flutter/material.dart';
import 'package:utopia_music/models/song.dart';

class SearchCollectionFragment extends StatelessWidget {
  final Function(Song) onSongSelected;
  final String keyword;

  const SearchCollectionFragment({
    super.key,
    required this.onSongSelected,
    required this.keyword,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('合集搜索功能开发中'));
  }
}
