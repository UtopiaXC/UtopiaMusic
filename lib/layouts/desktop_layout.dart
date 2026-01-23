import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/widgets/player/full_player_card.dart';
import 'package:utopia_music/widgets/player/mini_player.dart';

class DesktopLayout extends StatelessWidget {
  final int selectedIndex;
  final List<Widget> pages;
  final ValueChanged<int> onItemTapped;

  const DesktopLayout({
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

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onItemTapped,
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.explore_outlined),
                selectedIcon: const Icon(Icons.explore),
                label: Text(S.of(context).pages_tag_discover),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.music_note_outlined),
                selectedIcon: const Icon(Icons.music_note),
                label: Text(S.of(context).pages_tag_library),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: Text(S.of(context).pages_tag_settings),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Stack(
              children: [
                IndexedStack(
                  index: selectedIndex,
                  children: pages,
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
                if (currentSong != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedSlide(
                      offset: (!isPlayerExpanded)
                          ? Offset.zero
                          : const Offset(0, 1),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                      child: MiniPlayer(
                        song: currentSong,
                        isPlaying: isPlaying,
                        onTap: playerProvider.togglePlayerExpansion,
                        onPlayPause: playerProvider.togglePlayPause,
                        onNext: () {}, // Handled internally by MiniPlayer using Provider
                        onPrevious: () {}, // Handled internally by MiniPlayer using Provider
                        onClose: playerProvider.closePlayer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
