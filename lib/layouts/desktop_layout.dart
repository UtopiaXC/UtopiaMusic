import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/layouts/desktop/desktop_player_bar.dart';
import 'package:utopia_music/layouts/desktop/desktop_playlist_drawer.dart';
import 'package:utopia_music/layouts/desktop/desktop_sidebar.dart';
import 'package:utopia_music/layouts/desktop/desktop_top_bar.dart';
import 'package:utopia_music/pages/main/library/downloaded_sheet.dart';
import 'package:utopia_music/pages/search/search_page.dart';
import 'package:utopia_music/providers/discover_provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/theme/app_theme.dart';
import 'package:utopia_music/widgets/common/liquid_glass_container.dart';
import 'package:utopia_music/widgets/player/full_player_card.dart';

/// Biu-inspired desktop shell with persistent sidebar, top search/profile bar,
/// responsive multi-column content pane, full-width bottom playback bar,
/// and slide-over playlist drawer.
class DesktopLayout extends StatefulWidget {
  final int selectedIndex;
  final List<Widget> pages;
  final ValueChanged<int> onItemTapped;
  final DiscoverCategoryType? activeDiscoverCategory;
  final ValueChanged<DiscoverCategoryType> onSelectDiscoverCategory;

  const DesktopLayout({
    super.key,
    required this.selectedIndex,
    required this.pages,
    required this.onItemTapped,
    required this.activeDiscoverCategory,
    required this.onSelectDiscoverCategory,
  });

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  bool _isQueueDrawerOpen = false;

  String _resolveTopBarTitle(BuildContext context, int selectedIndex) {
    if (selectedIndex == 0) {
      return _titleForCategory(context, widget.activeDiscoverCategory);
    }
    if (selectedIndex == 1) {
      return S.of(context).pages_tag_library;
    }
    return S.of(context).pages_tag_settings;
  }

  String _titleForCategory(
    BuildContext context,
    DiscoverCategoryType? category,
  ) {
    switch (category ?? DiscoverCategoryType.recommend) {
      case DiscoverCategoryType.recommend:
        return S.of(context).pages_discover_category_recommend;
      case DiscoverCategoryType.feed:
        return S.of(context).pages_discover_category_feed;
      case DiscoverCategoryType.history:
        return S.of(context).pages_discover_category_history;
      case DiscoverCategoryType.subscribe:
        return S.of(context).pages_discover_category_subscribe;
      case DiscoverCategoryType.live:
        return S.of(context).pages_discover_category_live;
      case DiscoverCategoryType.rank:
        return S.of(context).pages_discover_category_rank;
      case DiscoverCategoryType.musicRank:
        return S.of(context).pages_discover_category_music_rank;
      case DiscoverCategoryType.kichikuRank:
        return S.of(context).pages_discover_category_kichiku_rank;
    }
  }

  void _openSearch() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            SearchPage(onSongSelected: playerProvider.playSong),
      ),
    );
  }

  void _openDownloads() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DownloadedSheet(asPage: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final currentSong = playerProvider.currentSong;
    final isPlayerExpanded = playerProvider.isPlayerExpanded;
    final showFullPlayer = playerProvider.showFullPlayer;
    final bool isLiquidGlass = AppTheme.isLiquidGlass(context);

    final mainShell = Column(
      children: [
        Expanded(
          child: Row(
            children: [
              DesktopSidebar(
                selectedIndex: widget.selectedIndex,
                activeDiscoverCategory: widget.activeDiscoverCategory,
                onSelectDiscoverCategory: widget.onSelectDiscoverCategory,
                onSelectMainTab: widget.onItemTapped,
                onOpenDownloads: _openDownloads,
              ),
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        DesktopTopBar(
                          title: _resolveTopBarTitle(
                            context,
                            widget.selectedIndex,
                          ),
                          onOpenSearch: _openSearch,
                        ),
                        Expanded(
                          child: IndexedStack(
                            index: widget.selectedIndex,
                            children: widget.pages,
                          ),
                        ),
                      ],
                    ),
                    if (_isQueueDrawerOpen &&
                        currentSong != null &&
                        !playerProvider.isLiveMode)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        child: DesktopPlaylistDrawer(
                          onClose: () {
                            setState(() {
                              _isQueueDrawerOpen = false;
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (currentSong != null)
          DesktopPlayerBar(
            song: currentSong,
            isQueueOpen: _isQueueDrawerOpen && !playerProvider.isLiveMode,
            onToggleQueue: () {
              setState(() {
                _isQueueDrawerOpen = !_isQueueDrawerOpen;
              });
            },
            onExpandPlayer: playerProvider.togglePlayerExpansion,
          ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (playerProvider.isPlayerExpanded) {
          playerProvider.collapsePlayer();
        } else if (_isQueueDrawerOpen) {
          setState(() {
            _isQueueDrawerOpen = false;
          });
        }
      },
      child: Scaffold(
        backgroundColor: isLiquidGlass ? Colors.transparent : null,
        body: Stack(
          children: [
            isLiquidGlass ? LiquidGlassBackdrop(child: mainShell) : mainShell,
            if (showFullPlayer && currentSong != null)
              Positioned.fill(
                child: AnimatedSlide(
                  offset: isPlayerExpanded ? Offset.zero : const Offset(0, 1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  child: TickerMode(
                    enabled: isPlayerExpanded,
                    child: IgnorePointer(
                      ignoring: !isPlayerExpanded,
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
                ),
              ),
          ],
        ),
      ),
    );
  }
}
