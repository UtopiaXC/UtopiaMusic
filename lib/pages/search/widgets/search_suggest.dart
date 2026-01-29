import 'package:flutter/material.dart';

class SearchSuggest extends StatelessWidget {
  final List<String> suggestions;
  final Function(String) onSelected;

  const SearchSuggest({
    super.key,
    required this.suggestions,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,

      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return ListTile(
          leading: const Icon(Icons.search, size: 20, color: Colors.grey),
          title: Text(
            suggestion,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          onTap: () => onSelected(suggestion),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }
}
