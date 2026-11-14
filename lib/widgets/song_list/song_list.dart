import 'package:flutter/material.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/settings_provider.dart';
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
  final VoidCallback? onPlayAction;
  final bool useCardStyle;
  final bool followGlobalStyle;
  final SongListStyle? styleOverride;
  final bool showFooter;
  final ScrollPhysics? physics;
  final VoidCallback? onLoadMore;

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
    this.onPlayAction,
    this.useCardStyle = false,
    this.followGlobalStyle = false,
    this.styleOverride,
    this.showFooter = true,
    this.physics,
    this.onLoadMore,
  });

  Widget _buildFooter(BuildContext context) {
    if (!showFooter) {
      return const SizedBox(height: 24);
    }
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
    }
    if (hasMore && onLoadMore != null) {
      Future.microtask(onLoadMore!);
      return Container(
        height: 60,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    if (!hasMore) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        child: Text(
          S.of(context).common_at_bottom,
          style: TextStyle(
            color: Theme.of(context).disabledColor,
            fontSize: 12,
          ),
        ),
      );
    }
    return const SizedBox(height: 60);
  }

  Widget _buildItem(Song song, SongListStyle effectiveStyle) {
    return SongListItem(
      song: song,
      contextList: songs,
      menuItems: itemMenuItems,
      onMenuSelected: onItemMenuSelected != null
          ? (value) => onItemMenuSelected!(value, song)
          : null,
      onPlayAction: onPlayAction,
      followGlobalStyle: false,
      styleOverride: effectiveStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && songs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (songs.isEmpty) {
      return emptyWidget ?? Center(child: Text(S.of(context).common_no_data));
    }

    final effectiveStyle = SongListItem.resolveStyle(
      context,
      followGlobalStyle: followGlobalStyle,
      styleOverride: styleOverride,
      useCardStyle: useCardStyle,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final footer = _buildFooter(context);

        Widget scrollChild;
        if (effectiveStyle == SongListStyle.cardGrid) {
          final int columns = width < 600
              ? 2
              : (width / 230).floor().clamp(2, 6);
          const double horizontalPadding = 12;
          const double crossSpacing = 10;
          final double itemWidth =
              (width - horizontalPadding * 2 - crossSpacing * (columns - 1)) /
              columns;
          final double mainAxisExtent = (itemWidth / 1.6) + 118;

          scrollChild = CustomScrollView(
            controller: scrollController,
            physics: physics ?? const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: crossSpacing,
                    mainAxisSpacing: 10,
                    mainAxisExtent: mainAxisExtent,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return _buildItem(songs[index], effectiveStyle);
                  }, childCount: songs.length),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 96),
                  child: footer,
                ),
              ),
            ],
          );
        } else if (effectiveStyle == SongListStyle.cardList && width >= 700) {
          scrollChild = CustomScrollView(
            controller: scrollController,
            physics: physics ?? const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 420,
                    mainAxisExtent: 92,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return _buildItem(songs[index], effectiveStyle);
                  }, childCount: songs.length),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 96),
                  child: footer,
                ),
              ),
            ],
          );
        } else {
          final isCard = effectiveStyle == SongListStyle.cardList;
          scrollChild = ListView.separated(
            controller: scrollController,
            physics: physics ?? const AlwaysScrollableScrollPhysics(),
            itemCount: songs.length + 1,
            padding: EdgeInsets.only(
              bottom: 120,
              top: isCard ? 4 : 8,
            ),
            separatorBuilder: (context, index) => isCard
                ? const SizedBox.shrink()
                : const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              if (index == songs.length) {
                return footer;
              }
              return _buildItem(songs[index], effectiveStyle);
            },
          );
        }

        return Scrollbar(
          controller: scrollController,
          thumbVisibility: false,
          interactive: true,
          thickness: 6,
          radius: const Radius.circular(3),
          child: scrollChild,
        );
      },
    );
  }
}
