import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/pages/main/discover/fragments/feed_fragment.dart';
import 'package:utopia_music/pages/main/discover/fragments/history_fragment.dart';
import 'package:utopia_music/pages/main/discover/fragments/kichiku_rank_fragment.dart';
import 'package:utopia_music/pages/main/discover/fragments/live_fragment.dart';
import 'package:utopia_music/pages/main/discover/fragments/music_rank_fragment.dart';
import 'package:utopia_music/pages/main/discover/fragments/rank_fragment.dart';
import 'package:utopia_music/pages/main/discover/fragments/recommend_fragment.dart';
import 'package:utopia_music/pages/main/discover/fragments/subscribe_fragment.dart';
import 'package:utopia_music/providers/discover_provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/pages/search/search_page.dart';
import 'package:utopia_music/generated/l10n.dart';

class DiscoverPage extends StatefulWidget {
  final Function(Song) onSongSelected;

  const DiscoverPage({super.key, required this.onSongSelected});

  @override
  State<DiscoverPage> createState() => DiscoverPageState();
}

class DiscoverPageState extends State<DiscoverPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  TabController? _tabController;
  int _currentTabIndex = 0;

  final List<ScrollController> _scrollControllers = [];
  final List<GlobalKey<RefreshIndicatorState>> _refreshKeys = [];

  DateTime? _lastTapTime;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 8; i++) {
      _scrollControllers.add(ScrollController());
      _refreshKeys.add(GlobalKey<RefreshIndicatorState>());
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    for (var controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initTabController(int length, int initialIndex) {
    _tabController?.dispose();
    _tabController = TabController(
      length: length,
      vsync: this,
      initialIndex: initialIndex < length ? initialIndex : 0,
    );
    _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) {
        if (_currentTabIndex != _tabController!.index) {
          setState(() {
            _currentTabIndex = _tabController!.index;
          });
        }
      }
    });
    _currentTabIndex = _tabController!.index;
  }

  void handleTabTap(int index) {
    if (_currentTabIndex != index) {
      setState(() {
        _currentTabIndex = index;
      });
      _lastTapTime = null;
      return;
    }
    final controller = _scrollControllers[index];

    if (controller.hasClients && controller.offset > 0) {
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
      );
      _lastTapTime = null;
    } else {
      final now = DateTime.now();
      if (_lastTapTime != null &&
          now.difference(_lastTapTime!) < const Duration(seconds: 1)) {
        _refreshKeys[index].currentState?.show();
        _lastTapTime = null;
      } else {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).pages_discover_refresh_toast),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _lastTapTime = now;
      }
    }
  }

  void handleBottomTabReselect() {
    handleTabTap(_currentTabIndex);
  }

  void _openSearchPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SearchPage(onSongSelected: widget.onSongSelected),
      ),
    );
  }

  void _handleSongSelected(Song song) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.currentSong == null) {
      playerProvider.playSong(song);
      playerProvider.expandPlayer();
    } else {
      playerProvider.playSong(song);
    }
  }

  String _getCategoryTitle(BuildContext context, DiscoverCategoryType type) {
    switch (type) {
      case DiscoverCategoryType.recommend:
        return S.of(context).pages_discover_tag_recommend;
      case DiscoverCategoryType.feed:
        return S.of(context).pages_discover_tag_feed;
      case DiscoverCategoryType.history:
        return '历史'; // TODO: Add to l10n
      case DiscoverCategoryType.subscribe:
        return '关注'; // TODO: Add to l10n
      case DiscoverCategoryType.live:
        return S.of(context).pages_discover_tag_live;
      case DiscoverCategoryType.rank:
        return S.of(context).pages_discover_tag_ranking;
      case DiscoverCategoryType.musicRank:
        return S.of(context).pages_discover_tag_ranking_category_music;
      case DiscoverCategoryType.kichikuRank:
        return S.of(context).pages_discover_tag_ranking_category_kichiku;
    }
  }

  Widget _buildFragment(DiscoverCategoryType type, int index) {
    switch (type) {
      case DiscoverCategoryType.recommend:
        return RecommendFragment(
          onSongSelected: _handleSongSelected,
          scrollController: _scrollControllers[index],
          refreshIndicatorKey: _refreshKeys[index],
        );
      case DiscoverCategoryType.feed:
        return FeedFragment(
          scrollController: _scrollControllers[index],
          refreshIndicatorKey: _refreshKeys[index],
        );
      case DiscoverCategoryType.history:
        return HistoryFragment(
          scrollController: _scrollControllers[index],
          refreshIndicatorKey: _refreshKeys[index],
          onSongSelected: _handleSongSelected,
        );
      case DiscoverCategoryType.subscribe:
        return SubscribeFragment(
          scrollController: _scrollControllers[index],
          refreshIndicatorKey: _refreshKeys[index],
        );
      case DiscoverCategoryType.live:
        return LiveFragment(
          scrollController: _scrollControllers[index],
          refreshIndicatorKey: _refreshKeys[index],
        );
      case DiscoverCategoryType.rank:
        return RankFragment(
          scrollController: _scrollControllers[index],
          refreshIndicatorKey: _refreshKeys[index],
        );
      case DiscoverCategoryType.musicRank:
        return MusicRankFragment(
          scrollController: _scrollControllers[index],
          refreshIndicatorKey: _refreshKeys[index],
        );
      case DiscoverCategoryType.kichikuRank:
        return KichikuRankFragment(
          scrollController: _scrollControllers[index],
          refreshIndicatorKey: _refreshKeys[index],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Consumer<DiscoverProvider>(
      builder: (context, discoverProvider, child) {
        final visibleCategories = discoverProvider.visibleCategories;
        
        if (_tabController == null || _tabController!.length != visibleCategories.length) {
          // Try to keep the same tab selected if possible, or default to Recommend if available
          int newIndex = 0;
          if (_tabController != null) {
             // Logic to find new index could be complex, for now just reset or keep index if within bounds
             newIndex = _currentTabIndex < visibleCategories.length ? _currentTabIndex : 0;
          } else {
             // Initial load, try to find Recommend
             final recommendIndex = visibleCategories.indexOf(DiscoverCategoryType.recommend);
             if (recommendIndex != -1) {
               newIndex = recommendIndex;
             }
          }
          _initTabController(visibleCategories.length, newIndex);
        }

        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: GestureDetector(
                  onTap: _openSearchPage,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          S.of(context).pages_search_hint_search_input,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onTap: handleTabTap,
                tabs: visibleCategories.map((type) => Tab(text: _getCategoryTitle(context, type))).toList(),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: List.generate(visibleCategories.length, (index) {
                    return _buildFragment(visibleCategories[index], index);
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
