import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/connection/video/discover.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/widgets/song_list/song_list_item.dart';
import 'package:utopia_music/widgets/login/login_dialog.dart';
import 'package:utopia_music/generated/l10n.dart';

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

class _FeedFragmentState extends State<FeedFragment>
    with AutomaticKeepAliveClientMixin {
  final VideoApi _videoApi = VideoApi();
  final List<Song> _songs = [];
  bool _isLoading = false;
  String _offset = '';
  bool _hasMore = true;

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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      if (refresh) {
        setState(() {
          _songs.clear();
          _offset = '';
          _hasMore = true;
          _isLoading = false;
        });
      }
      return;
    }

    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      if (refresh) {
        _songs.clear();
        _offset = '';
        _hasMore = true;
      }
    });

    await _fetchFeedRecursively();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchFeedRecursively() async {
    final result = await _videoApi.getFeed(context, _offset);

    if (result['code'] == -101) {
      return;
    }

    if (result['code'] == 0) {
      final newSongs = result['songs'] as List<Song>;
      final newOffset = result['offset'];
      final hasMoreData = result['has_more'];

      if (newOffset == _offset && newSongs.isEmpty) {
        setState(() {
          _hasMore = false;
        });
        return;
      }

      _offset = newOffset;
      _hasMore = hasMoreData;

      setState(() {
        _songs.addAll(newSongs);
      });

      if (newSongs.length < 10 && _hasMore) {
        await _fetchFeedRecursively();
      } else if (newSongs.isEmpty && !_hasMore) {
        setState(() {
          _hasMore = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadData(refresh: true);
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoginDialog(),
    ).then((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isLoggedIn) {
        _handleRefresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isLoggedIn) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.no_accounts, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(S.of(context).pages_discover_feed_not_logged_in),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: _showLoginDialog,
                  child: Text(S.of(context).pages_library_category_login),
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
              // 到达列表底部
              if (index == _songs.length) {
                if (_hasMore) {
                  if (!_isLoading) {
                    Future.microtask(() => _loadData());
                  }
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(S.of(context).common_at_bottom, style: const TextStyle(color: Colors.grey)),
                    ),
                  );
                }
              }
              return SongListItem(song: _songs[index], contextList: _songs);
            },
          ),
        );
      },
    );
  }
}
