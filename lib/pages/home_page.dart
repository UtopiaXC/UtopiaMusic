import 'package:flutter/material.dart';
import 'package:utopia_music/connection/video/video_list.dart';
import 'package:utopia_music/models/song.dart';

class HomePage extends StatefulWidget {
  final Function(Song) onSongSelected;

  const HomePage({super.key, required this.onSongSelected});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  final VideoApi _videoApi = VideoApi();
  final ScrollController _scrollController = ScrollController();
  List<Song> _songs = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  
  DateTime? _lastTabClickTime;
  bool _showRefreshHint = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        !_isLoading) {
      _loadMoreData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    final songs = await _videoApi.getRecommentVideos();
    if (mounted) {
      setState(() {
        _songs = songs;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    setState(() {
      _isLoadingMore = true;
    });
    final newSongs = await _videoApi.getRecommentVideos();
    if (mounted) {
      setState(() {
        _songs.addAll(newSongs);
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }

  // 公开此方法供外部调用
  void handleTabTap() {
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      // 不在顶部，滚动到顶部
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      _showRefreshHint = false;
    } else {
      // 已经在顶部
      final now = DateTime.now();
      if (_lastTabClickTime != null && 
          now.difference(_lastTabClickTime!) < const Duration(seconds: 2)) {
        // 2秒内再次点击，触发刷新
        _refreshIndicatorKey.currentState?.show();
        _showRefreshHint = false;
      } else {
        // 第一次点击，显示提示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('再次点击刷新'),
            duration: Duration(seconds: 1),
          ),
        );
        _showRefreshHint = true;
      }
      _lastTabClickTime = now;
    }
  }

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DefaultTabController(
      length: 4,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              onTap: (index) {
                if (index == 0) {
                  handleTabTap();
                }
              },
              tabs: const [
                Tab(text: '推荐'),
                Tab(text: '动态'),
                Tab(text: '全站排行'),
                Tab(text: '音乐区排行'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSongList(),
                  const Center(child: Text('动态内容')),
                  const Center(child: Text('全站排行内容')),
                  const Center(child: Text('音乐区排行内容')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongList() {
    if (_isLoading && _songs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_songs.isEmpty) {
      return RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 200),
            Center(child: Text('暂无数据')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      key: _refreshIndicatorKey,
      onRefresh: _onRefresh,
      // 调整 edgeOffset，确保刷新球不被 TabBar 遮挡
      // 这里的 0.0 是相对于 RefreshIndicator 的位置，通常不需要额外偏移，
      // 除非 RefreshIndicator 被放在了 Stack 下层。
      // 但为了确保列表下移，RefreshIndicator 默认行为就是下移 child。
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _songs.length + 1,
        // 增加底部 padding，防止被 MiniPlayer 遮挡
        padding: const EdgeInsets.only(bottom: 120, top: 16),
        itemBuilder: (context, index) {
          if (index == _songs.length) {
            // 底部加载更多指示器
            return _isLoadingMore
                ? Container(
                    height: 60,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : const SizedBox(height: 60); // 留出一点空白，防止跳动
          }

          final song = _songs[index];

          return GestureDetector(
            onTap: () => widget.onSongSelected(song),
            child: Container(
              height: 80,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    decoration: BoxDecoration(
                      color: Color(song.colorValue),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                      image: song.coverUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(song.coverUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: song.coverUrl.isEmpty
                        ? const Center(child: Icon(Icons.music_note, color: Colors.white))
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artist,
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.play_circle_outline, color: Colors.grey),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
