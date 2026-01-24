import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/connection/user/user.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/widgets/user/space_sheet.dart';
import 'package:utopia_music/widgets/login/login_dialog.dart';

class SubscribeFragment extends StatefulWidget {
  final ScrollController scrollController;
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey;

  const SubscribeFragment({
    super.key,
    required this.scrollController,
    required this.refreshIndicatorKey,
  });

  @override
  State<SubscribeFragment> createState() => _SubscribeFragmentState();
}

class _SubscribeFragmentState extends State<SubscribeFragment> with AutomaticKeepAliveClientMixin {
  final UserApi _userApi = UserApi();
  List<dynamic> _users = [];
  bool _isLoading = false;
  int _page = 1;
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
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final mid = authProvider.userInfo?.mid ?? 0;
    
    if (mid == 0) {
      setState(() => _isLoading = false);
      return;
    }

    final list = await _userApi.getFollowings(mid, _page);
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
                const Icon(Icons.no_accounts, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('用户未登录，无法查看关注列表'),
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
          onRefresh: () => _loadData(refresh: true),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
                _loadData();
              }
              return false;
            },
            child: Scrollbar(
              controller: widget.scrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: widget.scrollController,
                itemCount: _users.length + 1,
                itemBuilder: (context, index) {
                  if (index == _users.length) {
                    if (_isLoading) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    } else if (!_hasMore) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: Text('到底了', style: TextStyle(color: Colors.grey))),
                      );
                    } else {
                      return const SizedBox(height: 60);
                    }
                  }

                  final user = _users[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(user['face'] ?? ''),
                    ),
                    title: Text(user['uname'] ?? ''),
                    subtitle: Text(user['sign'] ?? ''),
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
          ),
        );
      },
    );
  }
}
