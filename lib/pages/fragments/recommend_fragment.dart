import 'package:flutter/material.dart';
import 'package:utopia_music/connection/video/video_list.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/widgets/song_list/song_list.dart';

class RecommendFragment extends StatefulWidget {
  final Function(Song) onSongSelected;
  final ScrollController scrollController;
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey;

  const RecommendFragment({
    super.key,
    required this.onSongSelected,
    required this.scrollController,
    required this.refreshIndicatorKey,
  });

  @override
  State<RecommendFragment> createState() => _RecommendFragmentState();
}

class _RecommendFragmentState extends State<RecommendFragment>
    with AutomaticKeepAliveClientMixin {
  final VideoApi _videoApi = VideoApi();
  List<Song> _songs = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (widget.scrollController.hasClients &&
        widget.scrollController.position.pixels >=
            widget.scrollController.position.maxScrollExtent - 200 &&
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      key: widget.refreshIndicatorKey,
      onRefresh: _onRefresh,
      child: SongList(
        songs: _songs,
        scrollController: widget.scrollController,
        isLoading: _isLoading,
        isLoadingMore: _isLoadingMore,
        emptyWidget: ListView(
          controller: widget.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 200),
            Center(child: Text('暂无数据')),
          ],
        ),
      ),
    );
  }
}
