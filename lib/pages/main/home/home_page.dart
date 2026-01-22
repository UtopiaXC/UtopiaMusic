import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/pages/main/home/fragments/feed_fragment.dart';
import 'package:utopia_music/pages/main/home/fragments/kichiku_rank_fragment.dart';
import 'package:utopia_music/pages/main/home/fragments/live_fragment.dart';
import 'package:utopia_music/pages/main/home/fragments/music_rank_fragment.dart';
import 'package:utopia_music/pages/main/home/fragments/rank_fragment.dart';
import 'package:utopia_music/pages/main/home/fragments/recommend_fragment.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/pages/search/search_page.dart';
import 'package:utopia_music/generated/l10n.dart';

class HomePage extends StatefulWidget {
  final Function(Song) onSongSelected;

  const HomePage({super.key, required this.onSongSelected});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 1; // Default to Recommend (index 1)

  final List<ScrollController> _scrollControllers = [];
  final List<GlobalKey<RefreshIndicatorState>> _refreshKeys = [];

  DateTime? _lastTapTime;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: 1,
    ); // 6 tabs, start at 1 (Recommend)
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_currentTabIndex != _tabController.index) {
          setState(() {
            _currentTabIndex = _tabController.index;
          });
        }
      }
    });

    for (int i = 0; i < 6; i++) {
      _scrollControllers.add(ScrollController());
      _refreshKeys.add(GlobalKey<RefreshIndicatorState>());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
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
            content: Text(S.of(context).pages_home_refresh_toast),
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
            tabs: [
              Tab(text: S.of(context).pages_home_tag_live),
              Tab(text: S.of(context).pages_home_tag_recommend),
              Tab(text: S.of(context).pages_home_tag_feed),
              Tab(text: S.of(context).pages_home_tag_ranking),
              Tab(text: S.of(context).pages_home_tag_ranking_category_music),
              Tab(text: S.of(context).pages_home_tag_ranking_category_kichiku),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                LiveFragment(
                  scrollController: _scrollControllers[0],
                  refreshIndicatorKey: _refreshKeys[0],
                ),
                RecommendFragment(
                  onSongSelected: _handleSongSelected,
                  scrollController: _scrollControllers[1],
                  refreshIndicatorKey: _refreshKeys[1],
                ),
                FeedFragment(
                  scrollController: _scrollControllers[2],
                  refreshIndicatorKey: _refreshKeys[2],
                ),
                RankFragment(
                  scrollController: _scrollControllers[3],
                  refreshIndicatorKey: _refreshKeys[3],
                ),
                MusicRankFragment(
                  scrollController: _scrollControllers[4],
                  refreshIndicatorKey: _refreshKeys[4],
                ),
                KichikuRankFragment(
                  scrollController: _scrollControllers[5],
                  refreshIndicatorKey: _refreshKeys[5],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
