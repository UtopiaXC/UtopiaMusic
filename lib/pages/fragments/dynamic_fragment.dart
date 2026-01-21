import 'package:flutter/material.dart';

class DynamicFragment extends StatelessWidget {
  final ScrollController scrollController;
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey;

  const DynamicFragment({
    super.key,
    required this.scrollController,
    required this.refreshIndicatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('动态内容'));
  }
}
