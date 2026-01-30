import 'package:flutter/material.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/widgets/song_list/song_list_item.dart';
import 'package:utopia_music/generated/l10n.dart';

class SongList extends StatelessWidget {
  final List<Song> songs;
  final ScrollController? scrollController;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Widget? emptyWidget;
  final List<PopupMenuEntry<String>>? itemMenuItems;
  final void Function(String, Song)? onItemMenuSelected;
  final bool useCardStyle;

  const SongList({
    super.key,
    required this.songs,
    this.scrollController,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.emptyWidget,
    this.itemMenuItems,
    this.onItemMenuSelected,
    this.useCardStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && songs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (songs.isEmpty) {
      return emptyWidget ?? Center(child: Text(S.of(context).common_no_data));
    }

    return Scrollbar(
      controller: scrollController,
      thumbVisibility: false,
      interactive: true,
      thickness: 6,
      radius: const Radius.circular(3),
      child: ListView.separated(
        controller: scrollController,
        itemCount: songs.length + 1,
        padding: EdgeInsets.only(bottom: 120, top: useCardStyle ? 4 : 8),
        separatorBuilder: (context, index) => useCardStyle
            ? const SizedBox.shrink()
            : const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          if (index == songs.length) {
            if (isLoadingMore) {
              return Container(
                height: 60,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              );
            } else if (!hasMore) {
              return Container(
                height: 60,
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      S.of(context).common_at_bottom,
                      style: TextStyle(
                        color: Theme.of(context).disabledColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            } else {
              return const SizedBox(height: 60);
            }
          }

          final song = songs[index];
          return SongListItem(
            song: song,
            contextList: songs,
            menuItems: itemMenuItems,
            onMenuSelected: onItemMenuSelected != null
                ? (value) => onItemMenuSelected!(value, song)
                : null,
            useCardStyle: useCardStyle,
          );
        },
      ),
    );
  }
}
