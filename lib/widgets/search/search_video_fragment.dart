import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/connection/video/search_api.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';

class SearchVideoFragment extends StatefulWidget {
  final Function(Song) onSongSelected;
  final String keyword;

  const SearchVideoFragment({
    super.key,
    required this.onSongSelected,
    required this.keyword,
  });

  @override
  State<SearchVideoFragment> createState() => _SearchVideoFragmentState();
}

class _SearchVideoFragmentState extends State<SearchVideoFragment>
    with AutomaticKeepAliveClientMixin {
  final SearchApi _searchApi = SearchApi();
  final ScrollController _scrollController = ScrollController();

  List<Song> _songs = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.keyword.isNotEmpty) {
      _doSearch(widget.keyword);
    }
  }

  @override
  void didUpdateWidget(covariant SearchVideoFragment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.keyword != oldWidget.keyword && widget.keyword.isNotEmpty) {
      _doSearch(widget.keyword);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        !_isLoading &&
        widget.keyword.isNotEmpty) {
      _loadMoreData();
    }
  }

  Future<void> _doSearch(String keyword) async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _songs = [];
    });

    final songs = await _searchApi.searchVideos(keyword, page: _currentPage);

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
      _currentPage++;
    });

    final newSongs = await _searchApi.searchVideos(widget.keyword, page: _currentPage);

    if (mounted) {
      setState(() {
        _songs.addAll(newSongs);
        _isLoadingMore = false;
      });
    }
  }

  void _handleSongTap(Song song) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    if (playerProvider.currentSong != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: const Text('播放单曲将替换当前播放列表，是否继续？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close Dialog
                playerProvider.playSong(song);
              },
              child: const Text('继续'),
            ),
          ],
        ),
      );
    } else {
      playerProvider.playSong(song);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_songs.isEmpty && widget.keyword.isNotEmpty) {
      return const Center(child: Text('未找到相关内容'));
    }

    if (_songs.isEmpty) {
      return const Center(child: Text('输入关键词开始搜索'));
    }

    return ListView.separated(
      controller: _scrollController,
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
          onTap: () => _handleSongTap(song),
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
}
