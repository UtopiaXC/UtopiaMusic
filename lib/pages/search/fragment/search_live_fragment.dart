import 'package:flutter/material.dart';
import 'package:utopia_music/generated/l10n.dart';

class SearchLiveFragment extends StatelessWidget {
  final String keyword;

  const SearchLiveFragment({super.key, required this.keyword});

  @override
  Widget build(BuildContext context) {
    if (keyword.isEmpty) {
      return Center(child: Text(S.of(context).common_under_development));
    }
    return Center(child: Text(S.of(context).common_under_development));
  }
}
