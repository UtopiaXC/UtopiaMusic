import 'package:flutter/material.dart';
import 'package:utopia_music/connection/video/video_list.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/widgets/song_list/song_list_item.dart';

class MusicRankFragment extends StatefulWidget {
  final ScrollController scrollController;
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey;

  const MusicRankFragment({
    super.key,
    required this.scrollController,
    required this.refreshIndicatorKey,
  });

  @override
  State<MusicRankFragment> createState() => _MusicRankFragmentState();
}

class _MusicRankFragmentState extends State<MusicRankFragment> with AutomaticKeepAliveClientMixin {
  final VideoApi _videoApi = VideoApi();
  final List<Song> _songs = [];
  bool _isLoading = false;

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
    });

    final newSongs = await _videoApi.getRankingVideos(context, rid: 3);

    setState(() {
      _songs.addAll(newSongs);
      _isLoading = false;
    });
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
