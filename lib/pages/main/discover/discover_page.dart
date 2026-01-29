import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/utils/log.dart';
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

const String _tag = "DISCOVER_PAGE";

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
    Log.v(_tag, "initState");
    super.initState();
    for (int i = 0; i < 8; i++) {
      _scrollControllers.add(ScrollController());
      _refreshKeys.add(GlobalKey<RefreshIndicatorState>());
    }
  }

  @override
  void dispose() {
    Log.v(_tag, "dispose");
    _tabController?.dispose();
    for (var controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initTabController(int length, int initialIndex) {
    Log.v(
      _tag,
      "_initTabController, length: $length, initialIndex: $initialIndex",
    );
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
    Log.v(_tag, "handleTabTap, index: $index");
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
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _lastTapTime = now;
      }
    }
  }

  void handleBottomTabReselect() {
    Log.v(_tag, "handleBottomTabReselect");
    handleTabTap(_currentTabIndex);
  }

  void _openSearchPage() {
    Log.v(_tag, "_openSearchPage");
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SearchPage(onSongSelected: widget.onSongSelected),
      ),
    );
  }

  void _handleSongSelected(Song song) {
    Log.v(_tag, "_handleSongSelected");
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.currentSong == null) {
      playerProvider.playSong(song);
      playerProvider.expandPlayer();
    } else {
      playerProvider.playSong(song);
    }
  }

  String _getCategoryTitle(BuildContext context, DiscoverCategoryType type) {
    Log.v(_tag, "_getCategoryTitle");
    switch (type) {
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

  Widget _buildFragment(DiscoverCategoryType type, int index) {
    Log.v(_tag, "_buildFragment");
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
    Log.v(_tag, "build");
    super.build(context);

    return Consumer<DiscoverProvider>(
      builder: (context, discoverProvider, child) {
        final visibleCategories = discoverProvider.visibleCategories;

        if (_tabController == null ||
            _tabController!.length != visibleCategories.length) {
          int newIndex = 0;
          if (_tabController != null) {
            newIndex = _currentTabIndex < visibleCategories.length
                ? _currentTabIndex
                : 0;
          } else {
            final recommendIndex = visibleCategories.indexOf(
              DiscoverCategoryType.recommend,
            );
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: GestureDetector(
                  onTap: _openSearchPage,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                labelColor: Theme.of(context).colorScheme.onPrimaryContainer,
                unselectedLabelColor:
                    Theme.of(context).colorScheme.onSurfaceVariant,
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                tabs: visibleCategories
                    .map((type) => Tab(text: _getCategoryTitle(context, type)))
                    .toList(),
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
