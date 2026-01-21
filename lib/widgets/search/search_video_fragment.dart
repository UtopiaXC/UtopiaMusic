import 'package:flutter/material.dart';
import 'package:utopia_music/connection/video/search_api.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/widgets/song_list/song_list.dart';

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

    return SongList(
      songs: _songs,
      scrollController: _scrollController,
      isLoadingMore: _isLoadingMore,
    );
  }
}
