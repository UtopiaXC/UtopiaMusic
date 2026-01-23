import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/connection/video/discover.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/widgets/song_list/song_list_item.dart';
import 'package:utopia_music/widgets/login/login_dialog.dart';

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
      // If not logged in, do not fetch data
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

    final result = await _videoApi.getFeed(context, _offset);

    if (result['code'] == -101) {
      // This might happen if cookie expired during session
      // But we check isLoggedIn first.
      // If API returns -101, it means not logged in.
      // We should probably update AuthProvider status?
      // But for now just show empty state.
      setState(() {
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

  void _showLoginDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoginDialog(),
    ).then((_) {
      // Refresh after login dialog closes (assuming login might have happened)
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
                const Text('用户未登录，无法查看动态'),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: _showLoginDialog,
                  child: const Text('登录'),
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
      },
    );
  }
}
