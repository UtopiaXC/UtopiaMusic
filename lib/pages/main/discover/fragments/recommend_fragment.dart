import 'package:flutter/material.dart';
import 'package:utopia_music/connection/video/discover.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/widgets/song_list/song_list.dart';
import 'package:utopia_music/generated/l10n.dart';

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
  bool _hasError = false;

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
        !_isLoading &&
        !_hasError) {
      _loadMoreData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final songs = await _videoApi.getRecommentVideos(context);
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
    });
    try {
      final newSongs = await _videoApi.getRecommentVideos(context);
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
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_hasError && _songs.isEmpty) {
      return RefreshIndicator(
        key: widget.refreshIndicatorKey,
        onRefresh: _onRefresh,
        child: ListView(
          controller: widget.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(S.of(context).pages_discover_error_rank_risk),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadData,
                    child: Text(S.of(context).common_retry),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

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
          children: [
            const SizedBox(height: 200),
            Center(child: Text(S.of(context).common_no_data)),
          ],
        ),
      ),
    );
  }
}
