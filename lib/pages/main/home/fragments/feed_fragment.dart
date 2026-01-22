import 'package:flutter/material.dart';
import 'package:utopia_music/connection/video/video_list.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/widgets/song_list/song_list_item.dart';

class FeedFragment extends StatefulWidget {
  final ScrollController scrollController;
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey;

  const FeedFragment({
    super.key,
    required this.scrollController,
    required this.refreshIndicatorKey,
  });

  @override
  State<FeedFragment> createState() => _FeedFragmentState();
}

class _FeedFragmentState extends State<FeedFragment> with AutomaticKeepAliveClientMixin {
  final VideoApi _videoApi = VideoApi();
  final List<Song> _songs = [];
  bool _isLoading = false;
  String _offset = '';
  bool _hasMore = true;
  bool _isNotLoggedIn = false;

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
    if (widget.scrollController.position.pixels >=
            widget.scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadData();
    }
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      if (refresh) {
        _songs.clear();
        _offset = '';
        _hasMore = true;
        _isNotLoggedIn = false;
      }
    });

    final result = await _videoApi.getFeed(context, _offset);

    if (result['code'] == -101) {
      setState(() {
        _isNotLoggedIn = true;
        _isLoading = false;
      });
      return;
    }

    if (result['code'] == 0) {
      final newSongs = result['songs'] as List<Song>;
      _offset = result['offset'];
      _hasMore = result['has_more'];

      setState(() {
        _songs.addAll(newSongs);
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      // Handle error
    }
  }

  Future<void> _handleRefresh() async {
    await _loadData(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isNotLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_accounts, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('用户未登录，无法查看动态'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _handleRefresh,
              child: const Text('刷新'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      key: widget.refreshIndicatorKey,
      onRefresh: _handleRefresh,
      child: ListView.builder(
        controller: widget.scrollController,
        itemCount: _songs.length + 1,
        itemBuilder: (context, index) {
          if (index == _songs.length) {
            return _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }
          return SongListItem(
            song: _songs[index],
            contextList: _songs,
          );
        },
      ),
    );
  }
}
