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
import 'package:utopia_music/utils/scheme_launch.dart';
import 'package:utopia_music/widgets/player/dialogs/play_options_sheet.dart';
import 'package:utopia_music/generated/l10n.dart';

class SpaceSheet extends StatefulWidget {
  final int mid;

  const SpaceSheet({super.key, required this.mid});

  @override
  State<SpaceSheet> createState() => _SpaceSheetState();
}

class _SpaceSheetState extends State<SpaceSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserApi _userApi = UserApi();
  final HtmlUnescape _unescape = HtmlUnescape();

  Map<String, dynamic>? _userInfo;
  bool _isLoadingInfo = true;
  bool _isFollowing = false;
  bool _isSelf = false;

  List<Song> _videos = [];
  bool _isLoadingVideos = false;
  int _videoPage = 1;
  String _videoOrder = 'pubdate';
  bool _hasMoreVideos = true;
  static const int _pageSize = 20;

  List<PlaylistInfo> _createdPlaylists = [];
  bool _isLoadingCreated = false;
  int _createdPage = 1;
  bool _hasMoreCreated = true;

  List<PlaylistInfo> _collectedPlaylists = [];
  bool _isLoadingCollected = false;
  int _collectedPage = 1;
  bool _hasMoreCollected = true;

  List<PlaylistInfo> _seasonsSeries = [];
  bool _isLoadingSeasons = false;
  int _seasonsPage = 1;
  bool _hasMoreSeasons = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkIfSelf();
    _loadUserInfo();
    _loadVideos();
    _loadCreatedPlaylists();
    _loadCollectedPlaylists();
    _loadSeasonsSeries();
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
    final list = await _userApi.getUserVideos(
      widget.mid,
      _videoPage,
      _videoOrder,
    );
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
    final list = await _userApi.getUserCreatedFavFolders(
      widget.mid,
      _createdPage,
    );
    if (mounted) {
      if (list.isEmpty) {
        _hasMoreCreated = false;
      } else {
        final newPlaylists = list
            .map((item) => _mapToPlaylistInfo(item))
            .toList();
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
    final list = await _userApi.getUserCollectedFavFolders(
      widget.mid,
      _collectedPage,
    );
    if (mounted) {
      if (list.isEmpty) {
        _hasMoreCollected = false;
      } else {
        final newPlaylists = list
            .map((item) => _mapToPlaylistInfo(item))
            .toList();
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

  Future<void> _loadSeasonsSeries({bool refresh = false}) async {
    if (_isLoadingSeasons) return;
    if (refresh) {
      _seasonsPage = 1;
      _hasMoreSeasons = true;
      _seasonsSeries = [];
    }
    if (!_hasMoreSeasons) return;

    setState(() => _isLoadingSeasons = true);
    final data = await _userApi.getUserSeasonsSeriesList(
      widget.mid,
      _seasonsPage,
    );
    if (mounted) {
      if (data == null ||
          data['items_lists'] == null ||
          (data['items_lists'] as Map).isEmpty) {
        _hasMoreSeasons = false;
      } else {
        final itemsLists = data['items_lists'] as Map<String, dynamic>;
        final seasonsList = itemsLists['seasons_list'] as List<dynamic>? ?? [];
        final seriesList = itemsLists['series_list'] as List<dynamic>? ?? [];

        final allItems = [...seasonsList, ...seriesList];

        if (allItems.isEmpty) {
          _hasMoreSeasons = false;
        } else {
          final newPlaylists = allItems
              .map((item) => _mapSeasonToPlaylistInfo(item))
              .toList();
          _seasonsSeries.addAll(newPlaylists);

          final pageInfo = data['page'] as Map<String, dynamic>?;
          if (pageInfo != null) {
            final total = pageInfo['total'] as int? ?? 0;
            if (_seasonsSeries.length >= total) {
              _hasMoreSeasons = false;
            } else {
              _seasonsPage++;
            }
          } else {
            _hasMoreSeasons = false;
          }
        }
      }
      setState(() => _isLoadingSeasons = false);
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
      cid: 0,
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

  PlaylistInfo _mapSeasonToPlaylistInfo(dynamic item) {
    final meta = item['meta'];
    return PlaylistInfo(
      id: meta['season_id'].toString(),
      title: meta['name'],
      coverUrl: meta['cover'] ?? '',
      count: meta['total'] ?? 0,
      isLocal: false,
      originalData: null,
    );
  }

  Future<void> _handleFollow() async {
    final act = _isFollowing ? 2 : 1;
    final actionName = _isFollowing
        ? S.of(context).common_unsubscribe
        : S.of(context).common_subscribe;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(actionName),
        content: Text(
          '${S.of(context).common_confirm_to}$actionName${S.of(context).common_confirm_to_end}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).common_confirm),
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
        title: Text(S.of(context).weight_user_space_logout_title),
        content: Text(S.of(context).weight_user_space_logout_conntent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).common_confirm),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      Navigator.pop(context);
      authProvider.logout();
    }
  }

  void _handlePlayFirst() {
    if (_videos.isEmpty) return;
    final song = _videos.first;
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    if (playerProvider.playlist.isEmpty) {
      playerProvider.setPlaylistAndPlay(_videos, song);
      Navigator.pop(context);
    } else {
      showModalBottomSheet(
        context: context,
        builder: (context) => PlayOptionsSheet(
          song: song,
          contextList: _videos,
          onPlayAction: () {
            Navigator.pop(context);
          },
        ),
      );
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
                padding: const EdgeInsets.only(
                  top: 16.0,
                  left: 8.0,
                  right: 8.0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () {
                        SchemeLauncher.launchUser(context, widget.mid);
                      },
                      tooltip: S.of(context).common_open_in_bilibili,
                    ),
                  ],
                ),
              ),
              _buildHeader(context),
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: S.of(context).common_uploaded),
                  Tab(text: S.of(context).common_collection),
                  Tab(text: S.of(context).common_favourite),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildVideoList(scrollController),
                    _buildPlaylistList(
                      scrollController,
                      _seasonsSeries,
                      _isLoadingSeasons,
                      _hasMoreSeasons,
                      S.of(context).weight_user_space_no_public_connection,
                      isCollection: true,
                    ),
                    _buildCombinedFavList(scrollController),
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
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
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
      if (vipType == 2) {
        vipLabel = S.of(context).weight_user_space_annual_vip;
      } else if (vipType == 1) {
        vipLabel = S.of(context).weight_user_space_vip;
      } else {
        vipLabel = S.of(context).weight_user_space_vip;
      }
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
              image: DecorationImage(
                image: NetworkImage(face),
                fit: BoxFit.cover,
              ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getLevelColor(level),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'LV$level',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (vipLabel.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          vipLabel,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
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
              tooltip: S.of(context).weight_user_space_logout_title,
            )
          else
            IconButton(
              onPressed: _handleFollow,
              icon: Icon(
                _isFollowing ? Icons.favorite : Icons.favorite_border,
                color: _isFollowing ? Colors.red : null,
              ),
              tooltip: _isFollowing
                  ? S.of(context).common_unsubscribe
                  : S.of(context).common_subscribe,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_videos.isNotEmpty)
                InkWell(
                  onTap: _handlePlayFirst,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          S.of(context).common_play_all,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox(),

              DropdownButton<String>(
                value: _videoOrder,
                items: [
                  DropdownMenuItem(
                    value: 'pubdate',
                    child: Text(S.of(context).weight_user_space_newest),
                  ),
                  DropdownMenuItem(
                    value: 'click',
                    child: Text(S.of(context).weight_user_space_most_play),
                  ),
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
              ? Center(child: Text(S.of(context).common_no_uploaded))
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent - 200) {
                      _loadVideos();
                    }
                    return false;
                  },
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: _videos.length + 1,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 72),
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
                                  S.of(context).common_at_bottom,
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
                        onPlayAction: () {
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPlaylistList(
    ScrollController scrollController,
    List<PlaylistInfo> playlists,
    bool isLoading,
    bool hasMore,
    String emptyText, {
    bool isCollection = false,
  }) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Expanded(
          child: playlists.isEmpty && !isLoading
              ? Center(child: Text(emptyText))
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent - 200) {
                      if (isCollection) {
                        _loadSeasonsSeries();
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
                                  S.of(context).common_at_bottom,
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
                                ? DecorationImage(
                                    image: NetworkImage(playlist.coverUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                          child: playlist.coverUrl.isEmpty
                              ? const Icon(Icons.music_note)
                              : null,
                        ),
                        title: Text(playlist.title),
                        subtitle: Text(
                          '${playlist.count}${S.of(context).common_count_of_songs}',
                        ),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => OnlinePlaylistDetailSheet(
                              playlistInfo: playlist,
                              isCollection: isCollection,
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

  Widget _buildCombinedFavList(ScrollController scrollController) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200) {
          if (_hasMoreCreated && !_isLoadingCreated) {
            _loadCreatedPlaylists();
          }
          if (_hasMoreCollected && !_isLoadingCollected) {
            _loadCollectedPlaylists();
          }
        }
        return false;
      },
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          if (_createdPlaylists.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  S.of(context).weight_user_space_created_favourite_folder,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final playlist = _createdPlaylists[index];
                return ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      image: playlist.coverUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(playlist.coverUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                    child: playlist.coverUrl.isEmpty
                        ? const Icon(Icons.music_note)
                        : null,
                  ),
                  title: Text(playlist.title),
                  subtitle: Text(
                    '${playlist.count}${S.of(context).common_count_of_songs}',
                  ),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => OnlinePlaylistDetailSheet(
                        playlistInfo: playlist,
                        isCollection: false,
                      ),
                    );
                  },
                );
              }, childCount: _createdPlaylists.length),
            ),
            if (_isLoadingCreated)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            const SliverToBoxAdapter(child: Divider()),
          ],

          if (_collectedPlaylists.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  S.of(context).weight_user_space_subscribe_favourite_folder,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final playlist = _collectedPlaylists[index];
                return ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      image: playlist.coverUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(playlist.coverUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                    child: playlist.coverUrl.isEmpty
                        ? const Icon(Icons.music_note)
                        : null,
                  ),
                  title: Text(playlist.title),
                  subtitle: Text(
                    '${playlist.count}${S.of(context).common_count_of_songs}',
                  ),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => OnlinePlaylistDetailSheet(
                        playlistInfo: playlist,
                        isCollection: true,
                      ),
                    );
                  },
                );
              }, childCount: _collectedPlaylists.length),
            ),
            if (_isLoadingCollected)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],

          if (_createdPlaylists.isEmpty &&
              _collectedPlaylists.isEmpty &&
              !_isLoadingCreated &&
              !_isLoadingCollected)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  S.of(context).weight_user_space_no_favourite_folder,
                ),
              ),
            ),

          if (!_hasMoreCreated &&
              !_hasMoreCollected &&
              (_createdPlaylists.isNotEmpty || _collectedPlaylists.isNotEmpty))
            SliverToBoxAdapter(
              child: Container(
                height: 60,
                alignment: Alignment.center,
                child: Text(
                  S.of(context).common_at_bottom,
                  style: TextStyle(
                    color: Theme.of(context).disabledColor,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
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
