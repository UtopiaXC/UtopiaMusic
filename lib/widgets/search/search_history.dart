import 'package:flutter/material.dart';

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
                '搜索历史',
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
                      title: const Text('提示'),
                      content: const Text('确定要清空搜索历史吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onClear();
                          },
                          child: const Text('清空'),
                        ),
                      ],
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    '清空',
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
