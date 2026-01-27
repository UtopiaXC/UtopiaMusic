import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_form_sheet.dart';
import 'package:utopia_music/providers/library_provider.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/generated/l10n.dart';

class AddToPlaylistSheet extends StatefulWidget {
  final Song song;

  const AddToPlaylistSheet({super.key, required this.song});

  @override
  State<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<AddToPlaylistSheet> {
  List<LocalPlaylist> _playlists = [];
  bool _isLoading = true;
  bool _rename = false;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _loadPlaylists();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylists() async {
    setState(() => _isLoading = true);
    final playlists = await DatabaseService().getLocalPlaylists();
    if (mounted) {
      setState(() {
        _playlists = playlists;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCreatePlaylist() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PlaylistFormSheet(
        onSubmit: (title, description) async {
          await DatabaseService().createLocalPlaylist(title, description);
          _loadPlaylists();
          if (mounted) {
            Provider.of<LibraryProvider>(
              context,
              listen: false,
            ).refreshLibrary();
          }
        },
      ),
    );
  }

  Future<void> _addToPlaylist(LocalPlaylist playlist) async {
    final songToAdd = widget.song.copyWith(
      title: _rename ? _titleController.text : widget.song.title,
      originTitle: widget.song.originTitle.isEmpty
          ? widget.song.title
          : widget.song.originTitle,
    );

    await DatabaseService().addSongToLocalPlaylist(playlist.id, songToAdd);

    if (mounted) {
      Provider.of<LibraryProvider>(context, listen: false).refreshLibrary();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${S.of(context).weight_song_list_added_to_list} "${playlist.title}"',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  S.of(context).weight_song_list_add_to_list,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _rename,
                          onChanged: (value) {
                            setState(() {
                              _rename = value ?? false;
                            });
                          },
                        ),
                        Text(S.of(context).weight_song_list_rename_add),
                      ],
                    ),
                    if (_rename)
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: S.of(context).common_new_title,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(S.of(context).weight_song_list_new_list),
                onTap: _handleCreatePlaylist,
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = _playlists[index];
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                image: playlist.coverUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(playlist.coverUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: playlist.coverUrl == null
                                  ? const Icon(Icons.music_note, size: 20)
                                  : null,
                            ),
                            title: Text(playlist.title),
                            subtitle: Text(
                              '${playlist.songCount}${S.of(context).common_count_of_songs}',
                            ),
                            onTap: () => _addToPlaylist(playlist),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
