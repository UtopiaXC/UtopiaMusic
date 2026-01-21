import 'package:flutter/material.dart';

class RankFragment extends StatelessWidget {
  final ScrollController scrollController;
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey;

  const RankFragment({
    super.key,
    required this.scrollController,
    required this.refreshIndicatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('全站排行内容'));
  }
}
