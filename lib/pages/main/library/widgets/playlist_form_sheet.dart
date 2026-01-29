import 'package:flutter/material.dart';
import 'package:utopia_music/generated/l10n.dart';

class PlaylistFormSheet extends StatefulWidget {
  final String? initialTitle;
  final String? initialDescription;
  final Function(String title, String description) onSubmit;

  const PlaylistFormSheet({
    super.key,
    this.initialTitle,
    this.initialDescription,
    required this.onSubmit,
  });

  @override
  State<PlaylistFormSheet> createState() => _PlaylistFormSheetState();
}

class _PlaylistFormSheetState extends State<PlaylistFormSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descController = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.initialTitle == null
                ? S.of(context).pages_library_playlist_create
                : S.of(context).pages_library_playlist_edit,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: S.of(context).pages_library_playlist_name,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            decoration: InputDecoration(
              labelText: S.of(context).pages_library_playlist_desc,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (_titleController.text.isNotEmpty) {
                widget.onSubmit(_titleController.text, _descController.text);
                Navigator.pop(context);
              }
            },
            child: Text(S.of(context).common_confirm),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
