import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/connection/video/discover.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/utils/log.dart';
import 'package:utopia_music/providers/discover_provider.dart';
import 'package:utopia_music/widgets/song_list/song_list.dart';
import 'package:utopia_music/generated/l10n.dart';

const String _tag = "RECOMMEND_FRAGMENT";

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
  bool _hasCacheLoaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initWithCache();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _saveScrollPosition();
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  Future<void> _initWithCache() async {
    final discoverProvider = Provider.of<DiscoverProvider>(
      context,
      listen: false,
    );
    if (discoverProvider.firstVisibleCategory ==
        DiscoverCategoryType.recommend) {
      final cached = await discoverProvider.loadFirstTabCache();
      if (cached.isNotEmpty && mounted) {
        final scrollPos = await discoverProvider.loadScrollPosition();
        setState(() {
          _songs = cached;
          _isLoading = false;
          _hasCacheLoaded = true;
        });
        if (scrollPos > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (widget.scrollController.hasClients && mounted) {
              widget.scrollController.jumpTo(scrollPos);
            }
          });
        }
        _refreshInBackground();
        return;
      }
    }
    await _loadData();
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

  Future<void> _saveScrollPosition() async {
    final discoverProvider = Provider.of<DiscoverProvider>(
      context,
      listen: false,
    );
    if (discoverProvider.firstVisibleCategory ==
            DiscoverCategoryType.recommend &&
        widget.scrollController.hasClients) {
      await discoverProvider.saveScrollPosition(widget.scrollController.offset);
    }
  }

  Future<void> _saveToCache() async {
    final discoverProvider = Provider.of<DiscoverProvider>(
      context,
      listen: false,
    );
    if (discoverProvider.firstVisibleCategory ==
        DiscoverCategoryType.recommend) {
      await discoverProvider.saveFirstTabCache(_songs);
    }
  }

  Future<void> _refreshInBackground() async {
    try {
      final songs = await _videoApi.getRecommentVideos(context);
      if (mounted && songs.isNotEmpty) {
        setState(() {
          _songs = songs;
        });
        await _saveToCache();
      }
    } catch (e) {
      Log.w(_tag, "Fail to get recomment videos, $e");
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
        if (_songs.isNotEmpty) {
          await _saveToCache();
        }
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
        // Update cache with new data
        await _saveToCache();
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
      child: Scrollbar(
        controller: widget.scrollController,
        thumbVisibility: false,
        interactive: true,
        thickness: 6,
        radius: const Radius.circular(3),
        child: SongList(
          songs: _songs,
          scrollController: widget.scrollController,
          isLoading: _isLoading,
          isLoadingMore: _isLoadingMore,
          useCardStyle: true,
          emptyWidget: ListView(
            controller: widget.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 200),
              Center(child: Text(S.of(context).common_no_data)),
            ],
          ),
        ),
      ),
    );
  }
}
