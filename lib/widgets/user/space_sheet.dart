import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/connection/user/user.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/pages/main/library/widgets/online_playlist_detail_sheet.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_category_widget.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/widgets/song_list/song_list_item.dart';
import 'package:html_unescape/html_unescape.dart';

class SpaceSheet extends StatefulWidget {
  final int mid;

  const SpaceSheet({super.key, required this.mid});

  @override
  State<SpaceSheet> createState() => _SpaceSheetState();
}

class _SpaceSheetState extends State<SpaceSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserApi _userApi = UserApi();
  final HtmlUnescape _unescape = HtmlUnescape();

  Map<String, dynamic>? _userInfo;
  bool _isLoadingInfo = true;
  bool _isFollowing = false;
  bool _isSelf = false;

  // Tab 1: Videos
  List<Song> _videos = [];
  bool _isLoadingVideos = false;
  int _videoPage = 1;
  String _videoOrder = 'pubdate'; // pubdate, click
  bool _hasMoreVideos = true;
  static const int _pageSize = 20;

  // Tab 2: Created Playlists
  List<PlaylistInfo> _createdPlaylists = [];
  bool _isLoadingCreated = false;
  int _createdPage = 1;
  bool _hasMoreCreated = true;

  // Tab 3: Collected Playlists
  List<PlaylistInfo> _collectedPlaylists = [];
  bool _isLoadingCollected = false;
  int _collectedPage = 1;
  bool _hasMoreCollected = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkIfSelf();
    _loadUserInfo();
    _loadVideos();
    _loadCreatedPlaylists();
    _loadCollectedPlaylists();
  }

  void _checkIfSelf() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn && authProvider.userInfo?.mid == widget.mid) {
      _isSelf = true;
    }
  }

  Future<void> _loadUserInfo() async {
    setState(() => _isLoadingInfo = true);
    final data = await _userApi.getUserCard(widget.mid);
    if (mounted && data != null) {
      setState(() {
        _userInfo = data;
        _isFollowing = data['following'] ?? false;
        _isLoadingInfo = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingInfo = false);
    }
  }

  Future<void> _loadVideos({bool refresh = false}) async {
    if (_isLoadingVideos) return;
    if (refresh) {
      _videoPage = 1;
      _hasMoreVideos = true;
      _videos = [];
    }
    if (!_hasMoreVideos) return;

    setState(() => _isLoadingVideos = true);
    final list = await _userApi.getUserVideos(widget.mid, _videoPage, _videoOrder);
    if (mounted) {
      if (list.isEmpty) {
        _hasMoreVideos = false;
      } else {
        final newVideos = list.map((item) => _mapVideoToSong(item)).toList();
        _videos.addAll(newVideos);
        if (list.length < _pageSize) {
          _hasMoreVideos = false;
        } else {
          _videoPage++;
        }
      }
      setState(() => _isLoadingVideos = false);
    }
  }

  Future<void> _loadCreatedPlaylists({bool refresh = false}) async {
    if (_isLoadingCreated) return;
    if (refresh) {
      _createdPage = 1;
      _hasMoreCreated = true;
      _createdPlaylists = [];
    }
    if (!_hasMoreCreated) return;

    setState(() => _isLoadingCreated = true);
    final list = await _userApi.getUserCreatedFavFolders(widget.mid, _createdPage);
    if (mounted) {
      if (list.isEmpty) {
        _hasMoreCreated = false;
      } else {
        final newPlaylists = list.map((item) => _mapToPlaylistInfo(item)).toList();
        _createdPlaylists.addAll(newPlaylists);
        if (list.length < _pageSize) {
          _hasMoreCreated = false;
        } else {
          _createdPage++;
        }
      }
      setState(() => _isLoadingCreated = false);
    }
  }

  Future<void> _loadCollectedPlaylists({bool refresh = false}) async {
    if (_isLoadingCollected) return;
    if (refresh) {
      _collectedPage = 1;
      _hasMoreCollected = true;
      _collectedPlaylists = [];
    }
    if (!_hasMoreCollected) return;

    setState(() => _isLoadingCollected = true);
    final list = await _userApi.getUserCollectedFavFolders(widget.mid, _collectedPage);
    if (mounted) {
      if (list.isEmpty) {
        _hasMoreCollected = false;
      } else {
        final newPlaylists = list.map((item) => _mapToPlaylistInfo(item)).toList();
        _collectedPlaylists.addAll(newPlaylists);
        if (list.length < _pageSize) {
          _hasMoreCollected = false;
        } else {
          _collectedPage++;
        }
      }
      setState(() => _isLoadingCollected = false);
    }
  }

  Song _mapVideoToSong(dynamic item) {
    String cover = item['pic'] ?? '';
    if (cover.startsWith('http://')) {
      cover = cover.replaceFirst('http://', 'https://');
    }
    return Song(
      title: _unescape.convert(item['title'] ?? ''),
      artist: _unescape.convert(item['author'] ?? ''),
      coverUrl: cover,
      lyrics: '',
      colorValue: 0xFF2196F3,
      bvid: item['bvid'] ?? '',
      cid: 0, // CID needs to be fetched separately if not provided
    );
  }

  PlaylistInfo _mapToPlaylistInfo(dynamic item) {
    return PlaylistInfo(
      id: item['id'].toString(),
      title: item['title'],
      coverUrl: item['cover'] ?? '',
      count: item['media_count'] ?? 0,
      isLocal: false,
      originalData: item,
    );
  }

  Future<void> _handleFollow() async {
    final act = _isFollowing ? 2 : 1; // 1: follow, 2: unfollow
    final actionName = _isFollowing ? '取消关注' : '关注';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(actionName),
        content: Text('确定要$actionName吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _userApi.modifyRelation(widget.mid, act);
      if (success && mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await Provider.of<AuthProvider>(context, listen: false).logout();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16.0, left: 8.0, right: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              _buildHeader(context),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '投稿'),
                  Tab(text: '创建'),
                  Tab(text: '收藏'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildVideoList(scrollController),
                    _buildPlaylistList(scrollController, _createdPlaylists, _isLoadingCreated, _hasMoreCreated, '当前用户没有公开的合集或收藏夹'),
                    _buildPlaylistList(scrollController, _collectedPlaylists, _isLoadingCollected, _hasMoreCollected, '当前用户没有公开收藏他人的收藏夹', isCollection: true),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (_isLoadingInfo) {
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    }

    final card = _userInfo?['card'];
    final name = card?['name'] ?? '';
    final face = card?['face'] ?? '';
    final sign = card?['sign'] ?? '';
    final level = card?['level_info']?['current_level'] ?? 0;
    final vipType = card?['vip']?['type'] ?? 0;
    final vipStatus = card?['vip']?['status'] ?? 0;
    
    String vipLabel = '';
    if (vipStatus == 1) {
      if (vipType == 2) vipLabel = '年度大会员';
      else if (vipType == 1) vipLabel = '大会员';
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(image: NetworkImage(face), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getLevelColor(level),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'LV$level',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (vipLabel.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          vipLabel,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'UID: ${widget.mid}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (sign.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    sign,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (_isSelf)
            IconButton(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout),
              tooltip: '退出登录',
            )
          else
            IconButton(
              onPressed: _handleFollow,
              icon: Icon(
                _isFollowing ? Icons.favorite : Icons.favorite_border,
                color: _isFollowing ? Colors.red : null,
              ),
              tooltip: _isFollowing ? '取消关注' : '关注',
            ),
        ],
      ),
    );
  }

  Widget _buildVideoList(ScrollController scrollController) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DropdownButton<String>(
                value: _videoOrder,
                items: const [
                  DropdownMenuItem(value: 'pubdate', child: Text('最新发布')),
                  DropdownMenuItem(value: 'click', child: Text('最多播放')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _videoOrder = value;
                    });
                    _loadVideos(refresh: true);
                  }
                },
                underline: const SizedBox(),
                icon: const Icon(Icons.sort),
              ),
            ],
          ),
        ),
        Expanded(
          child: _videos.isEmpty && !_isLoadingVideos
              ? const Center(child: Text('当前用户没有投稿'))
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
                      _loadVideos();
                    }
                    return false;
                  },
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: _videos.length + 1,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      if (index == _videos.length) {
                        if (_isLoadingVideos) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        } else if (!_hasMoreVideos) {
                          return Container(
                            height: 60,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '到底了',
                                  style: TextStyle(
                                    color: Theme.of(context).disabledColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          return const SizedBox(height: 60);
                        }
                      }
                      final song = _videos[index];
                      return SongListItem(
                        song: song,
                        contextList: _videos,
                        onPlayAction: () {}, // Optional: close sheet?
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPlaylistList(ScrollController scrollController, List<PlaylistInfo> playlists, bool isLoading, bool hasMore, String emptyText, {bool isCollection = false}) {
    return Column(
      children: [
        const SizedBox(height: 8), 
        Expanded(
          child: playlists.isEmpty && !isLoading
              ? Center(child: Text(emptyText))
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
                      if (isCollection) {
                        _loadCollectedPlaylists();
                      } else {
                        _loadCreatedPlaylists();
                      }
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: playlists.length + 1,
                    itemBuilder: (context, index) {
                      if (index == playlists.length) {
                        if (isLoading) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        } else if (!hasMore) {
                          return Container(
                            height: 60,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '到底了',
                                  style: TextStyle(
                                    color: Theme.of(context).disabledColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          return const SizedBox(height: 60);
                        }
                      }
                      final playlist = playlists[index];
                      return ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            image: playlist.coverUrl.isNotEmpty
                                ? DecorationImage(image: NetworkImage(playlist.coverUrl), fit: BoxFit.cover)
                                : null,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          child: playlist.coverUrl.isEmpty ? const Icon(Icons.music_note) : null,
                        ),
                        title: Text(playlist.title),
                        subtitle: Text('${playlist.count}首'),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => OnlinePlaylistDetailSheet(
                              playlistInfo: playlist,
                              isCollection: isCollection, // Pass isCollection flag
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Color _getLevelColor(int level) {
    switch (level) {
      case 0:
      case 1:
        return const Color(0xFFBFBFBF);
      case 2:
        return const Color(0xFF95DDB2);
      case 3:
        return const Color(0xFF92D1E5);
      case 4:
        return const Color(0xFFFFB37C);
      case 5:
        return const Color(0xFFFF6C00);
      case 6:
        return const Color(0xFFFF0000);
      default:
        return const Color(0xFFBFBFBF);
    }
  }
}
