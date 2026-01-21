import 'package:flutter/material.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/pages/fragments/dynamic_fragment.dart';
import 'package:utopia_music/pages/fragments/music_rank_fragment.dart';
import 'package:utopia_music/pages/fragments/rank_fragment.dart';
import 'package:utopia_music/pages/fragments/recommend_fragment.dart';

class HomePage extends StatefulWidget {
  final Function(Song) onSongSelected;

  const HomePage({super.key, required this.onSongSelected});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  final List<ScrollController> _scrollControllers = [];
  final List<GlobalKey<RefreshIndicatorState>> _refreshKeys = [];

  DateTime? _lastTapTime;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_currentTabIndex != _tabController.index) {
          setState(() {
            _currentTabIndex = _tabController.index;
          });
        }
      }
    });

    for (int i = 0; i < 4; i++) {
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
      if (_lastTapTime != null && now.difference(_lastTapTime!) < const Duration(seconds: 1)) {
        _refreshKeys[index].currentState?.show();
        _lastTapTime = null;
      } else {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('再次点击刷新列表'),
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            onTap: handleTabTap,
            tabs: const [
              Tab(text: '推荐'),
              Tab(text: '动态'),
              Tab(text: '全站排行'),
              Tab(text: '音乐区排行'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RecommendFragment(
                  onSongSelected: widget.onSongSelected,
                  scrollController: _scrollControllers[0],
                  refreshIndicatorKey: _refreshKeys[0],
                ),
                DynamicFragment(
                  scrollController: _scrollControllers[1],
                  refreshIndicatorKey: _refreshKeys[1],
                ),
                RankFragment(
                  scrollController: _scrollControllers[2],
                  refreshIndicatorKey: _refreshKeys[2],
                ),
                MusicRankFragment(
                  scrollController: _scrollControllers[3],
                  refreshIndicatorKey: _refreshKeys[3],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}