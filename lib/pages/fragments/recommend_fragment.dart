import 'package:flutter/material.dart';
import 'package:utopia_music/connection/video/video_list.dart';
import 'package:utopia_music/models/song.dart';

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

    Widget content;

    if (_isLoading && _songs.isEmpty) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_songs.isEmpty) {
      content = ListView(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(child: Text('暂无数据')),
        ],
      );
    } else {
      content = ListView.separated(
        controller: widget.scrollController,
        itemCount: _songs.length + 1,
        padding: const EdgeInsets.only(bottom: 120, top: 8),
        separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          if (index == _songs.length) {
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
                : const SizedBox(height: 60);
          }

          final song = _songs[index];
          final String optimizedCover = song.coverUrl.isNotEmpty
              ? '${song.coverUrl}@100w_100h.webp'
              : '';

          return InkWell(
            onTap: () => widget.onSongSelected(song),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Color(song.colorValue),
                      borderRadius: BorderRadius.circular(4),
                      image: song.coverUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(optimizedCover),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: song.coverUrl.isEmpty
                        ? const Center(
                            child: Icon(
                              Icons.music_note,
                              color: Colors.white,
                              size: 24,
                            ),
                          )
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artist,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {},
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return RefreshIndicator(
      key: widget.refreshIndicatorKey,
      onRefresh: _onRefresh,
      child: content,
    );
  }
}
