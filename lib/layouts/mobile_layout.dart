import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/theme/app_theme.dart';
import 'package:utopia_music/widgets/common/liquid_glass_container.dart';
import 'package:utopia_music/widgets/player/full_player_card.dart';
import 'package:utopia_music/widgets/player/mini_player.dart';

class MobileLayout extends StatelessWidget {
  final int selectedIndex;
  final List<Widget> pages;
  final ValueChanged<int> onItemTapped;

  const MobileLayout({
    super.key,
    required this.selectedIndex,
    required this.pages,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final currentSong = playerProvider.currentSong;
    final isPlayerExpanded = playerProvider.isPlayerExpanded;
    final isPlaying = playerProvider.isPlaying;
    final bool isLiquidGlass = AppTheme.isLiquidGlass(context);
    final double bottomSafe = MediaQuery.of(context).padding.bottom;
    final double floatingBarHeight = 64.0;
    final double floatingBarBottom = bottomSafe + 10.0;
    final double miniPlayerBottom = isLiquidGlass
        ? floatingBarBottom + floatingBarHeight + 4.0
        : 0.0;

    final bodyStack = Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: isLiquidGlass
                      ? (floatingBarBottom + floatingBarHeight)
                      : 0.0,
                ),
                child: IndexedStack(index: selectedIndex, children: pages),
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: miniPlayerBottom,
          child: AnimatedSlide(
            offset: (currentSong != null && !isPlayerExpanded)
                ? Offset.zero
                : const Offset(0, 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              height: (currentSong != null && !isPlayerExpanded) ? 80 : 0,
              child: currentSong != null
                  ? SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: MiniPlayer(
                        song: currentSong,
                        isPlaying: isPlaying,
                        onTap: playerProvider.togglePlayerExpansion,
                        onPlayPause: playerProvider.togglePlayPause,
                        onNext: playerProvider.hasNext
                            ? playerProvider.playNext
                            : null,
                        onPrevious: playerProvider.hasPrevious
                            ? playerProvider.playPrevious
                            : null,
                        onClose: playerProvider.closePlayer,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        if (isLiquidGlass)
          Positioned(
            left: 16,
            right: 16,
            bottom: floatingBarBottom,
            child: _FloatingLiquidGlassTabBar(
              selectedIndex: selectedIndex,
              onItemTapped: onItemTapped,
              height: floatingBarHeight,
            ),
          ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (playerProvider.isPlayerExpanded) {
          playerProvider.collapsePlayer();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            extendBody: isLiquidGlass,
            backgroundColor: isLiquidGlass ? Colors.transparent : null,
            body: isLiquidGlass
                ? LiquidGlassBackdrop(child: bodyStack)
                : bodyStack,
            bottomNavigationBar: isLiquidGlass
                ? null
                : NavigationBar(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onItemTapped,
                    destinations: [
                      NavigationDestination(
                        icon: const Icon(Icons.explore_outlined),
                        selectedIcon: const Icon(Icons.explore),
                        label: S.of(context).pages_tag_discover,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.music_note_outlined),
                        selectedIcon: const Icon(Icons.music_note),
                        label: S.of(context).pages_tag_library,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.settings_outlined),
                        selectedIcon: const Icon(Icons.settings),
                        label: S.of(context).pages_tag_settings,
                      ),
                    ],
                  ),
          ),
          if (currentSong != null)
            Positioned.fill(
              child: AnimatedSlide(
                offset: isPlayerExpanded ? Offset.zero : const Offset(0, 1),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: FullPlayerPage(
                    song: currentSong,
                    onCollapse: playerProvider.collapsePlayer,
                    onSongSelected: playerProvider.playSong,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FloatingLiquidGlassTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final double height;

  const _FloatingLiquidGlassTabBar({
    required this.selectedIndex,
    required this.onItemTapped,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = [
      (Icons.explore_outlined, Icons.explore, S.of(context).pages_tag_discover),
      (
        Icons.music_note_outlined,
        Icons.music_note,
        S.of(context).pages_tag_library,
      ),
      (
        Icons.settings_outlined,
        Icons.settings,
        S.of(context).pages_tag_settings,
      ),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LiquidGlassContainer(
      height: height,
      borderRadius: BorderRadius.circular(height / 2),
      refractionStrength: 28.0,
      bezelWidth: 22.0,
      blurSigma: 14.0,
      chromaticAberration: 2.0,
      highlightStrength: 0.86,
      tintColor: isDark
          ? const Color(0xFF141824).withValues(alpha: 0.78)
          : const Color(0xFFF7FAFF).withValues(alpha: 0.76),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final bool selected = selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onItemTapped(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular((height - 12) / 2),
                  color: selected
                      ? colorScheme.primary.withValues(alpha: 0.16)
                      : Colors.transparent,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? item.$2 : item.$1,
                      size: 22,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.$3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
