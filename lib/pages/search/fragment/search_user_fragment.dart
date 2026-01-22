import 'package:flutter/material.dart';
import 'package:utopia_music/models/song.dart';

class SearchUserFragment extends StatelessWidget {
  final Function(Song) onSongSelected;
  final String keyword;

  const SearchUserFragment({
    super.key,
    required this.onSongSelected,
    required this.keyword,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('用户搜索功能开发中'));
  }
}
