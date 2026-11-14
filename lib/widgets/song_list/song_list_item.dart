import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/widgets/common/cached_cover_image.dart';
import 'package:utopia_music/widgets/common/liquid_glass_container.dart';
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
  final bool followGlobalStyle;
  final SongListStyle? styleOverride;

  const SongListItem({
    super.key,
    required this.song,
    required this.contextList,
    this.menuItems,
    this.onMenuSelected,
    this.onPlayAction,
    this.useCardStyle = false,
    this.followGlobalStyle = false,
    this.styleOverride,
  });

  static SongListStyle resolveStyle(
    BuildContext context, {
    bool followGlobalStyle = false,
    SongListStyle? styleOverride,
    bool useCardStyle = false,
  }) {
    if (styleOverride != null) return styleOverride;
    if (!followGlobalStyle) {
      return useCardStyle ? SongListStyle.cardList : SongListStyle.seamlessList;
    }
    try {
      return Provider.of<SettingsProvider>(context).songListStyle;
    } catch (_) {
      return useCardStyle ? SongListStyle.cardList : SongListStyle.seamlessList;
    }
  }

  void _showPlayOptionsDialog(BuildContext context) {
    PlayOptionsSheet.executeOrShow(
      context: context,
      song: song,
      contextList: contextList,
      onPlayAction: onPlayAction,
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
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    if (settingsProvider.quickPlay) {
      if (playerProvider.playlist.isEmpty || playerProvider.currentSong == null) {
        playerProvider.setPlaylistAndPlay(contextList, song);
        onPlayAction?.call();
      } else {
        PlayOptionsSheet.executeOrShow(
          context: context,
          song: song,
          contextList: contextList,
          onPlayAction: onPlayAction,
        );
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
            ),
          ),
          DraggableScrollableSheet(
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
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatCount(BuildContext context, int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}${S.of(context).number_ten_thousand}';
    }
    return count.toString();
  }

  Widget _buildPopupMenu(BuildContext context, {bool compact = false}) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: compact ? 18 : 22,
      ),
      padding: compact ? EdgeInsets.zero : const EdgeInsets.all(8),
      constraints: compact
          ? const BoxConstraints(minWidth: 28, minHeight: 28)
          : null,
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
                const Icon(Icons.playlist_add, size: 20),
                const SizedBox(width: 12),
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
    );
  }

  Widget _buildGridCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasStats = song.viewCount != null || song.danmakuCount != null;

    return LiquidGlassSurface(
      fallbackColor: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handleTap(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedCoverImage(
                    imageUrl: song.coverUrl,
                    fit: BoxFit.cover,
                    sizeSuffix: '@640w_400h.webp',
                    placeholderColor: colorScheme.primaryContainer,
                  ),
                  if (song.durationSeconds != null && song.durationSeconds! > 0)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(song.durationSeconds!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 4, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    if (hasStats)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3, right: 4),
                        child: Row(
                          children: [
                            if (song.viewCount != null) ...[
                              Icon(
                                Icons.play_circle_outline,
                                size: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatCount(context, song.viewCount!),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (song.danmakuCount != null) ...[
                              Icon(
                                Icons.subtitles_outlined,
                                size: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatCount(context, song.danmakuCount!),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        if (song.isFollowed == true) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              S.of(context).live_badge_followed,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            song.artist,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: _buildPopupMenu(context, compact: true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = resolveStyle(
      context,
      followGlobalStyle: followGlobalStyle,
      styleOverride: styleOverride,
      useCardStyle: useCardStyle,
    );

    if (effectiveStyle == SongListStyle.cardGrid) {
      return _buildGridCard(context);
    }

    final isCard = effectiveStyle == SongListStyle.cardList;
    final content = Row(
      children: [
        CachedCoverImage.small(
          imageUrl: song.coverUrl,
          size: 48,
          borderRadius: BorderRadius.circular(isCard ? 8 : 4),
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
        _buildPopupMenu(context),
      ],
    );

    if (isCard) {
      final primaryColor = Theme.of(context).colorScheme.primary;
      return LiquidGlassSurface(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        borderRadius: BorderRadius.circular(14),
        fallbackColor: Theme.of(context).colorScheme.surface,
        fallbackBorder: Border.all(
          color: primaryColor.withValues(alpha: 0.15),
          width: 0.5,
        ),
        fallbackShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _handleTap(context),
          child: Padding(padding: const EdgeInsets.all(12), child: content),
        ),
      );
    }

    return InkWell(
      onTap: () => _handleTap(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: content,
      ),
    );
  }
}
