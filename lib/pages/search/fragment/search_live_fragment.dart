import 'package:flutter/material.dart';

class SearchLiveFragment extends StatelessWidget {
  final String keyword;

  const SearchLiveFragment({
    super.key,
    required this.keyword,
  });

  @override
  Widget build(BuildContext context) {
    if (keyword.isEmpty) {
      return const Center(child: Text('直播搜索功能开发中'));
    }
    return const Center(child: Text('直播搜索功能开发中'));
  }
}
