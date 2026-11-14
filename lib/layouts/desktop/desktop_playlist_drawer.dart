import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/theme/app_theme.dart';
import 'package:utopia_music/widgets/common/liquid_glass_container.dart';

/// Right-hand slide-over playback queue panel styled after Biu's playlist drawer.
class DesktopPlaylistDrawer extends StatefulWidget {
  final VoidCallback onClose;

  const DesktopPlaylistDrawer({super.key, required this.onClose});

  @override
  State<DesktopPlaylistDrawer> createState() => _DesktopPlaylistDrawerState();
}

class _DesktopPlaylistDrawerState extends State<DesktopPlaylistDrawer> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent(List<Song> playlist, Song? currentSong) {
    if (currentSong == null || !_scrollController.hasClients) return;
    final index = playlist.indexWhere(
      (s) => s.bvid == currentSong.bvid && s.cid == currentSong.cid,
    );
    if (index == -1) return;
    final targetOffset = (index * 58.0).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final playlist = playerProvider.playlist;
    final currentSong = playerProvider.currentSong;
    final colorScheme = Theme.of(context).colorScheme;
    final bool isLiquidGlass = AppTheme.isLiquidGlass(context);
    final glass = AppTheme.glassOf(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isLiquidGlass
        ? Colors.transparent
        : colorScheme.surfaceContainerLow;
    final Color borderColor = isLiquidGlass
        ? glass.borderColor
        : colorScheme.outlineVariant.withValues(alpha: 0.35);

    final panel = Container(
      width: 320,
      decoration: BoxDecoration(
        color: bgColor,
        border: isLiquidGlass
            ? null
            : Border(left: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${S.of(context).weight_play_list_label_name} (${playlist.length})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _scrollToCurrent(playlist, currentSong),
                  icon: const Icon(Icons.my_location, size: 18),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                ),
                IconButton(
                  onPressed: playlist.isEmpty
                      ? null
                      : playerProvider.clearPlaylist,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  tooltip: S.of(context).common_clean,
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 18),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  tooltip: S.of(context).common_close,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),
          Expanded(
            child: playlist.isEmpty
                ? Center(
                    child: Text(
                      S.of(context).pages_library_playlist_empty,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemExtent: 58,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    itemCount: playlist.length,
                    itemBuilder: (context, index) {
                      final song = playlist[index];
                      final bool isCurrent =
                          currentSong != null &&
                          song.bvid == currentSong.bvid &&
                          song.cid == currentSong.cid;

                      return Material(
                        color: isCurrent
                            ? colorScheme.primary.withValues(alpha: 0.14)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => playerProvider.playSong(song),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: song.coverUrl.isNotEmpty
                                      ? Image.network(
                                          '${song.coverUrl}@100w_100h.webp',
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            width: 40,
                                            height: 40,
                                            color: colorScheme.primaryContainer,
                                            child: Icon(
                                              Icons.music_note,
                                              size: 18,
                                              color: colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          width: 40,
                                          height: 40,
                                          color: colorScheme.primaryContainer,
                                          child: Icon(
                                            Icons.music_note,
                                            size: 18,
                                            color:
                                                colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isCurrent
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: isCurrent
                                              ? colorScheme.primary
                                              : colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        song.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      playerProvider.removeSong(index),
                                  icon: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    if (!isLiquidGlass) {
      return DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.14),
              blurRadius: 22,
              offset: const Offset(-6, 0),
            ),
          ],
        ),
        child: panel,
      );
    }

    return LiquidGlassContainer(
      margin: const EdgeInsets.fromLTRB(0, 8, 10, 8),
      borderRadius: BorderRadius.circular(24),
      highContrastScrim: true,
      refractionStrength: 18.0,
      bezelWidth: 18.0,
      blurSigma: 14.0,
      tintColor: isDark
          ? const Color(0xFF141822).withValues(alpha: 0.80)
          : const Color(0xFFF7FAFF).withValues(alpha: 0.82),
      shadow: BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.14),
        blurRadius: 24,
        offset: const Offset(-6, 0),
      ),
      child: panel,
    );
  }
}
