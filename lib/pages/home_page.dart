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
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  late TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
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
                  scrollController: _scrollController,
                  refreshIndicatorKey: _refreshIndicatorKey,
                ),
                const DynamicFragment(),
                const RankFragment(),
                const MusicRankFragment(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
