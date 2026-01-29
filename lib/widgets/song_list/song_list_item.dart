import 'package:flutter/material.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/widgets/common/cached_cover_image.dart';
import 'package:utopia_music/widgets/song_list/add_to_playlist_sheet.dart';
import 'package:utopia_music/widgets/video/video_detail.dart';
import 'package:utopia_music/widgets/player/dialogs/play_options_sheet.dart';

class SongListItem extends StatelessWidget {
  final Song song;
  final List<Song> contextList;
  final List<PopupMenuEntry<String>>? menuItems;
  final void Function(String)? onMenuSelected;
  final VoidCallback? onPlayAction;
  final bool useCardStyle;

  const SongListItem({
    super.key,
    required this.song,
    required this.contextList,
    this.menuItems,
    this.onMenuSelected,
    this.onPlayAction,
    this.useCardStyle = false,
  });

  void _showPlayOptionsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => PlayOptionsSheet(
        song: song,
        contextList: contextList,
        onPlayAction: onPlayAction,
      ),
    );
  }

  void _showAddToLocalPlaylistSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddToPlaylistSheet(song: song),
    );
  }

  void _handleTap(BuildContext context) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: VideoDetailPage(
              bvid: song.bvid,
              simplified: true,
              contextList: contextList,
              scrollController: scrollController,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        CachedCoverImage.small(
          imageUrl: song.coverUrl,
          size: 48,
          borderRadius: BorderRadius.circular(useCardStyle ? 8 : 4),
          placeholderColor: Theme.of(context).colorScheme.primaryContainer,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                song.artist,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onSelected: (value) {
            if (value == 'add_to_playlist') {
              _showPlayOptionsDialog(context);
            } else if (value == 'add_to_local_playlist') {
              _showAddToLocalPlaylistSheet(context);
            } else if (onMenuSelected != null) {
              onMenuSelected!(value);
            }
          },
          itemBuilder: (context) {
            final List<PopupMenuEntry<String>> items = [
              PopupMenuItem(
                value: 'add_to_playlist',
                child: Row(
                  children: [
                    const Icon(Icons.add, size: 20),
                    const SizedBox(width: 12),
                    Text(S.of(context).item_options_add_to_play_list),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'add_to_local_playlist',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add, size: 20),
                    SizedBox(width: 12),
                    Text(S.of(context).weight_song_list_add_to_local),
                  ],
                ),
              ),
            ];
            if (menuItems != null) {
              items.addAll(menuItems!);
            }
            return items;
          },
        ),
      ],
    );

    if (useCardStyle) {
      final primaryColor = Theme.of(context).colorScheme.primary;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryColor.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: primaryColor.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _handleTap(context),
            child: Padding(padding: const EdgeInsets.all(12), child: content),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _handleTap(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: content,
      ),
    );
  }
}
