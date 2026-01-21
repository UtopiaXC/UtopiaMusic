import 'package:flutter/material.dart';

class MusicRankFragment extends StatelessWidget {
  final ScrollController scrollController;
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey;
  const MusicRankFragment({
    super.key,
    required this.scrollController,
    required this.refreshIndicatorKey
  });

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('音乐区排行内容'));
  }
}
