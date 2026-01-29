import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/connection/user/user.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/widgets/song_list/song_list_item.dart';
import 'package:utopia_music/widgets/login/login_dialog.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:utopia_music/generated/l10n.dart';

class HistoryFragment extends StatefulWidget {
  final ScrollController scrollController;
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey;
  final Function(Song)? onSongSelected;

  const HistoryFragment({
    super.key,
    required this.scrollController,
    required this.refreshIndicatorKey,
    this.onSongSelected,
  });

  @override
  State<HistoryFragment> createState() => _HistoryFragmentState();
}

class _HistoryFragmentState extends State<HistoryFragment>
    with AutomaticKeepAliveClientMixin {
  final UserApi _userApi = UserApi();
  final HtmlUnescape _unescape = HtmlUnescape();

  List<Song> _songs = [];
  bool _isLoading = false;
  int _cursorMax = 0;
  int _cursorViewAt = 0;
  bool _hasMore = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      _loadData();
    }
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
    if (_isLoading) return;
    if (refresh) {
      _cursorMax = 0;
      _cursorViewAt = 0;
      _hasMore = true;
      setState(() {
        _songs = [];
      });
    }
    if (!_hasMore) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      setState(() => _isLoading = false);
      return;
    }

    final data = await _userApi.getHistory(_cursorMax, _cursorViewAt);

    if (mounted) {
      if (data != null) {
        final list = data['list'] as List<dynamic>? ?? [];
        final cursor = data['cursor'];

        if (list.isEmpty) {
          _hasMore = false;
        } else {
          final newSongs = list.map((item) => _mapToSong(item)).toList();
          _songs.addAll(newSongs);

          if (cursor != null) {
            _cursorMax = cursor['max'] ?? 0;
            _cursorViewAt = cursor['view_at'] ?? 0;
          } else {
            _hasMore = false;
          }
        }
      } else {
        _hasMore = false;
      }
      setState(() => _isLoading = false);
    }
  }

  Song _mapToSong(dynamic item) {
    String cover = item['cover'] ?? item['pic'] ?? '';
    if (cover.startsWith('http://')) {
      cover = cover.replaceFirst('http://', 'https://');
    }

    String title = item['title'] ?? '';
    title = _unescape.convert(title);

    String artist = item['author_name'] ?? item['owner']?['name'] ?? '';
    artist = _unescape.convert(artist);

    // History item usually has 'history' object with 'bvid' etc.
    // Or directly fields.
    // Structure: { title, author_name, cover, history: { bvid, cid, ... } }

    String bvid = item['history']?['bvid'] ?? item['bvid'] ?? '';
    int cid = item['history']?['cid'] ?? item['cid'] ?? 0;

    return Song(
      title: title,
      artist: artist,
      coverUrl: cover,
      lyrics: '',
      colorValue: 0xFF2196F3,
      bvid: bvid,
      cid: cid,
    );
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoginDialog(),
    ).then((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isLoggedIn) {
        _loadData(refresh: true);
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
                const Icon(Icons.history, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(S.of(context).pages_discover_history_not_logged_in),
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
          onRefresh: () => _loadData(refresh: true),
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: _songs.length + 1,
            itemBuilder: (context, index) {
              if (index == _songs.length) {
                if (_isLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (!_hasMore) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        S.of(context).common_at_bottom,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                } else {
                  return const SizedBox(height: 60);
                }
              }

              final song = _songs[index];
              return SongListItem(song: song, contextList: _songs);
            },
          ),
        );
      },
    );
  }
}
