import 'package:flutter/material.dart';

class LiveFragment extends StatelessWidget {
  final ScrollController scrollController;
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey;

  const LiveFragment({
    super.key,
    required this.scrollController,
    required this.refreshIndicatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('直播功能开发中'));
  }
}
