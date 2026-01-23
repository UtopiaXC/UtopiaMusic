import 'package:flutter/material.dart';
import 'package:utopia_music/connection/video/video_list.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/widgets/song_list/song_list_item.dart';

class KichikuRankFragment extends StatefulWidget {
  final ScrollController scrollController;
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey;

  const KichikuRankFragment({
    super.key,
    required this.scrollController,
    required this.refreshIndicatorKey,
  });

  @override
  State<KichikuRankFragment> createState() => _KichikuRankFragmentState();
}

class _KichikuRankFragmentState extends State<KichikuRankFragment> with AutomaticKeepAliveClientMixin {
  final VideoApi _videoApi = VideoApi();
  final List<Song> _songs = [];
  bool _isLoading = false;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _songs.clear();
      _hasError = false;
    });

    try {
      final newSongs = await _videoApi.getRankingVideos(context, rid: 119); // 119 for kichiku
      if (mounted) {
        setState(() {
          _songs.addAll(newSongs);
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

  Future<void> _handleRefresh() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading && _songs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError && _songs.isEmpty) {
      return RefreshIndicator(
        key: widget.refreshIndicatorKey,
        onRefresh: _handleRefresh,
        child: ListView(
          controller: widget.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('无网络或接口请求被风控，请重试'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadData,
                    child: Text('重试'),
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
      onRefresh: _handleRefresh,
      child: ListView.builder(
        controller: widget.scrollController,
        itemCount: _songs.length,
        itemBuilder: (context, index) {
          return SongListItem(
            song: _songs[index],
            contextList: _songs,
          );
        },
      ),
    );
  }
}
