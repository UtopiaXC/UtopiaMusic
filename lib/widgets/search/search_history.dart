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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                      content: Text(
                        S
                            .of(context)
                            .weight_search_label_confirm_clean_history_message,
                      ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: history.map<Widget>((keyword) {
                  return InputChip(
                    label: Text(keyword),
                    avatar: const Icon(Icons.history, size: 16),
                    onPressed: () => onSearch(keyword),
                    onDeleted: () => onDelete(keyword),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
