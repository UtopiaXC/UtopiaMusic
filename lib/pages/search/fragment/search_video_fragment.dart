import 'package:flutter/material.dart';
import 'package:utopia_music/connection/video/search_api.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/widgets/song_list/song_list.dart';
import 'package:utopia_music/generated/l10n.dart';

class SearchVideoFragment extends StatefulWidget {
  final Function(Song) onSongSelected;
  final String keyword;
  final int searchTimestamp;

  const SearchVideoFragment({
    super.key,
    required this.onSongSelected,
    required this.keyword,
    this.searchTimestamp = 0,
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
  bool _hasError = false;

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
    if (widget.keyword.isNotEmpty) {
      if (widget.keyword != oldWidget.keyword || widget.searchTimestamp != oldWidget.searchTimestamp) {
        _doSearch(widget.keyword);
      }
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
        !_hasError &&
        widget.keyword.isNotEmpty) {
      _loadMoreData();
    }
  }

  Future<void> _doSearch(String keyword) async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _songs = [];
      _hasError = false;
    });

    try {
      final songs = await _searchApi.searchVideos(context, keyword, page: _currentPage);

      if (mounted) {
        setState(() {
          _songs = songs;
          _isLoading = false;
          if (_songs.isEmpty) {
            _hasError = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _loadMoreData() async {
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    try {
      final newSongs = await _searchApi.searchVideos(context, widget.keyword, page: _currentPage);

      if (mounted) {
        setState(() {
          _songs.addAll(newSongs);
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          // Don't set _hasError here, just stop loading more
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError && _songs.isEmpty && widget.keyword.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('无结果，有可能是无网络或接口请求被风控，请重试'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _doSearch(widget.keyword),
              child: Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_songs.isEmpty && widget.keyword.isNotEmpty) {
      return Center(child: Text(S.of(context).common_no_data));
    }

    if (_songs.isEmpty) {
      return Center(child: Text(S.of(context).pages_search_tag_video_hint));
    }

    return SongList(
      songs: _songs,
      scrollController: _scrollController,
      isLoadingMore: _isLoadingMore,
    );
  }
}
