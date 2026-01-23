import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/providers/player_provider.dart';
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
    final showFullPlayer = playerProvider.showFullPlayer;
    final isPlaying = playerProvider.isPlaying;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (playerProvider.isPlayerExpanded) {
          playerProvider.collapsePlayer();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: selectedIndex,
                    children: pages,
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
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
                            onNext: () {},
                            onPrevious: () {},
                            onClose: playerProvider.closePlayer,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            if (showFullPlayer && currentSong != null)
              AnimatedSlide(
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
          ],
        ),
        bottomNavigationBar: NavigationBar(
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
    );
  }
}
