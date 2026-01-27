import 'package:flutter/material.dart';
import 'package:utopia_music/generated/l10n.dart';

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
    return Center(child: Text(S.of(context).pages_discover_live_developing));
  }
}
