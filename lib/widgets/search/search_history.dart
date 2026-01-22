import 'package:flutter/material.dart';
import 'package:utopia_music/generated/l10n.dart';

class SearchHistory extends StatelessWidget {
  final List<String> history;
  final Function(String) onSearch;
  final Function(String) onDelete;
  final VoidCallback onClear;

  const SearchHistory({
    super.key,
    required this.history,
    required this.onSearch,
    required this.onDelete,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context).weight_search_label_serach_history,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(S.of(context).common_confirm_title),
                      content: Text(S.of(context).weight_search_label_confirm_clean_history_message),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(S.of(context).common_cancel),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onClear();
                          },
                          child: Text(S.of(context).common_clean),
                        ),
                      ],
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    S.of(context).common_clean,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const ClampingScrollPhysics(),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final keyword = history[index];
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: const Icon(Icons.history, size: 18),
                title: Text(keyword),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => onDelete(keyword),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
                onTap: () => onSearch(keyword),
              );
            },
          ),
        ),
      ],
    );
  }
}
