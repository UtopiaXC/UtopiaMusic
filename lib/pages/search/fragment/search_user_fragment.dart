import 'package:flutter/material.dart';
import 'package:utopia_music/connection/user/user.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/widgets/user/space_sheet.dart';
import 'package:utopia_music/widgets/user/user_list_item.dart';
import 'package:utopia_music/generated/l10n.dart';

class SearchUserFragment extends StatefulWidget {
  final Function(Song) onSongSelected;
  final String keyword;

  const SearchUserFragment({
    super.key,
    required this.onSongSelected,
    required this.keyword,
  });

  @override
  State<SearchUserFragment> createState() => _SearchUserFragmentState();
}

class _SearchUserFragmentState extends State<SearchUserFragment>
    with AutomaticKeepAliveClientMixin {
  final UserApi _userApi = UserApi();
  List<dynamic> _users = [];
  bool _isLoading = false;
  int _page = 1;
  bool _hasMore = true;
  String _currentKeyword = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentKeyword = widget.keyword;
    _loadData();
  }

  @override
  void didUpdateWidget(SearchUserFragment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.keyword != oldWidget.keyword) {
      _currentKeyword = widget.keyword;
      _loadData(refresh: true);
    }
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _users = [];
    }
    if (!_hasMore) return;

    setState(() => _isLoading = true);

    final list = await _userApi.searchUsers(_currentKeyword, _page);
    if (mounted) {
      if (list.isEmpty) {
        _hasMore = false;
      } else {
        _users.addAll(list);
        _page++;
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_users.isEmpty && !_isLoading) {
      return Center(child: Text(S.of(context).common_none));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200) {
          _loadData();
        }
        return false;
      },
      child: Scrollbar(
        thumbVisibility: false,
        interactive: true,
        thickness: 6,
        radius: const Radius.circular(3),
        child: ListView.builder(
          itemCount: _users.length + 1,
          itemBuilder: (context, index) {
            if (index == _users.length) {
              if (_isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (!_hasMore) {
                return Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      S.of(context).common_at_bottom,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              } else {
                return const SizedBox(height: 60);
              }
            }

            final user = _users[index];
            String cover = user['upic'] ?? '';
            if (cover.startsWith('//')) {
              cover = 'https:$cover';
            }

            return UserListItem(
              avatarUrl: cover,
              name: user['uname'] ?? '',
              subtitle: user['usign'] ?? '',
              useCardStyle: true,
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => SpaceSheet(mid: user['mid']),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
