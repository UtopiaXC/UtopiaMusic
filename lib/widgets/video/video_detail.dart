import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/connection/video/video_detail.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/widgets/song_list/song_list_item.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_music/connection/user/user.dart';
import 'package:just_audio/just_audio.dart';
import 'package:utopia_music/widgets/user/space_sheet.dart';
import 'package:utopia_music/widgets/song_list/add_to_playlist_sheet.dart';
import 'package:utopia_music/widgets/video/video_detail_info.dart';
import 'package:utopia_music/widgets/video/favorite_sheet.dart';
import 'package:utopia_music/widgets/dialogs/play_options_sheet.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/providers/library_provider.dart';
import 'package:utopia_music/utils/scheme_launch.dart';

class VideoDetailPage extends StatefulWidget {
  final String bvid;
  final bool simplified;
  final List<Song>? contextList;
  final ScrollController? scrollController;

  const VideoDetailPage({
    super.key,
    required this.bvid,
    this.simplified = false,
    this.contextList,
    this.scrollController,
  });

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final VideoDetailApi _videoDetailApi = VideoDetailApi();
  final UserApi _userApi = UserApi();

  Map<String, dynamic>? _videoDetail;
  bool _isLoadingDetail = true;
  List<Song> _relatedVideos = [];
  bool _isLoadingRelated = false;
  bool _recommendationAutoPlay = false;
  static const String _recommendationAutoPlayKey = 'recommendation_auto_play';
  List<Song> _collectionVideos = [];
  bool _isLoadingCollection = false;
  bool _hasCollection = false;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = false;
  int _commentPage = 1;
  bool _hasMoreComments = true;

  @override
  void initState() {
    super.initState();
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    int tabCount = 0;
    if (!widget.simplified) {
      tabCount = settingsProvider.enableComments ? 3 : 2;
    }
    
    if (tabCount > 0) {
      _tabController = TabController(length: tabCount, vsync: this);
    }
    
    _loadSettings();
    _loadAllData();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recommendationAutoPlay = prefs.getBool(_recommendationAutoPlayKey) ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_recommendationAutoPlayKey, _recommendationAutoPlay);
    if (mounted) {
      Provider.of<PlayerProvider>(context, listen: false).setRecommendationAutoPlay(_recommendationAutoPlay);
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoadingDetail = true);
    try {
      final detail = await _videoDetailApi.getVideoDetail(widget.bvid);
      if (mounted) {
        setState(() {
          _videoDetail = detail;
          _isLoadingDetail = false;
        });
        if (detail != null) {
          // Check favorite status using the API requested by user
          _checkFavStatus(detail['aid'] ?? 0);
          
          if (!widget.simplified) {
            _loadRelatedVideos();
            _loadCollection(detail['aid'] ?? 0);
            final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
            if (settingsProvider.enableComments) {
              _loadComments();
            }
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDetail = false);
    }
  }
  
  Future<void> _checkFavStatus(int aid) async {
    if (aid == 0) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final int myMid = authProvider.userInfo?.mid ?? 0;
    if (myMid == 0) return;

    try {
      final folders = await _userApi.getUserCreatedFavFoldersAll(myMid, aid);
      bool isFav = false;
      for (var folder in folders) {
        if (folder['fav_state'] == 1) {
          isFav = true;
          break;
        }
      }
      
      if (mounted) {
        setState(() {
          if (_videoDetail != null) {
            if (_videoDetail!['req_user'] == null) {
              _videoDetail!['req_user'] = {};
            }
            _videoDetail!['req_user']['favorite'] = isFav ? 1 : 0;
          }
        });
      }
    } catch (e) {
      print('Error checking fav status: $e');
    }
  }

  Future<void> _loadRelatedVideos() async {
    setState(() => _isLoadingRelated = true);
    final videos = await _videoDetailApi.getRelatedVideos(context, widget.bvid);
    if (mounted) {
      setState(() {
        _relatedVideos = videos;
        _isLoadingRelated = false;
      });
    }
  }

  Future<void> _loadCollection(int aid) async {
    setState(() => _isLoadingCollection = true);
    final videos = await _videoDetailApi.getVideoCollection(context, widget.bvid, aid);
    if (mounted) {
      setState(() {
        _collectionVideos = videos;
        _hasCollection = videos.isNotEmpty;
        _isLoadingCollection = false;
      });
    }
  }

  Future<void> _loadComments({bool refresh = false}) async {
    if (_isLoadingComments) return;
    if (refresh) {
      _commentPage = 1;
      _hasMoreComments = true;
      _comments = [];
    }
    if (!_hasMoreComments) return;

    setState(() => _isLoadingComments = true);
    final list = await _videoDetailApi.getVideoReplies(widget.bvid, page: _commentPage);
    if (mounted) {
      if (list.isEmpty) {
        _hasMoreComments = false;
      } else {
        _comments.addAll(list);
        _commentPage++;
      }
      setState(() => _isLoadingComments = false);
    }
  }
  
  Future<void> _loadSubReplies(int index, int oid, int rpid) async {
    final comment = _comments[index];
    int currentPage = (comment['sub_reply_page'] ?? 1) + 1;
    
    final subReplies = await _videoDetailApi.getReplyReplies(oid, rpid, page: currentPage);
    if (mounted) {
      setState(() {
        if (subReplies.isEmpty) {
          // No more sub-replies
          comment['no_more_sub_replies'] = true;
        } else {
          if (comment['replies'] == null) {
            comment['replies'] = [];
          }
          (comment['replies'] as List).addAll(subReplies);
          comment['sub_reply_page'] = currentPage;
        }
      });
    }
  }

  Future<void> _handleRecommendationAutoPlay(bool? value) async {
    if (value == true) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('开启推荐连播'),
          content: const Text('如果启动推荐视频自由连播，再切换到下一个视频的时候，将会自动获取下一个视频的推荐并替换播放列表，而不是播放本视频的推荐列表。\n\n本选项与循环模式冲突，当启用时，将禁用循环模式，并接管播放列表。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        setState(() {
          _recommendationAutoPlay = true;
        });
        await _saveSettings();
        final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
        if (_relatedVideos.isNotEmpty) {
           final currentSong = playerProvider.currentSong;
           if (currentSong != null && currentSong.bvid == widget.bvid) {
             List<Song> newPlaylist = [currentSong, ..._relatedVideos];
             await playerProvider.player.setShuffleModeEnabled(false);
             await playerProvider.player.setLoopMode(LoopMode.off);
             await playerProvider.setPlaylistAndPlay(newPlaylist, currentSong);
           }
        }
      }
    } else {
      setState(() {
        _recommendationAutoPlay = false;
      });
      await _saveSettings();
    }
  }

  Future<void> _handleCollectionReplace() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    String content = '是否用该合集替换当前的播放列表？';
    if (_recommendationAutoPlay) {
      content += '\n\n注意：自由连播模式已启动，合集播放会被其接管，如果希望完整播放合集，请关闭自由连播。';
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('替换播放列表'),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('替换'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (_collectionVideos.isNotEmpty) {
        Song? targetSong;
        for (var s in _collectionVideos) {
          if (s.bvid == widget.bvid) {
            targetSong = s;
            break;
          }
        }
        targetSong ??= _collectionVideos.first;
        
        await playerProvider.setPlaylistAndPlay(_collectionVideos, targetSong);
      }
    }
  }

  Future<void> _handleFav() async {
    if (_videoDetail == null) return;
    
    final int aid = _videoDetail!['aid'] ?? 0;
    if (aid == 0) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final int myMid = authProvider.userInfo?.mid ?? 0;
    if (myMid == 0) {
      // Use a post-frame callback or ensure context is valid for showing snackbar
      // But since this is inside a modal bottom sheet (VideoDetailPage), 
      // the ScaffoldMessenger might be covered or not in the right context.
      // However, usually ScaffoldMessenger works if there is a Scaffold above.
      // The user says "layer problem, cannot show on detail interface".
      // This is likely because VideoDetailPage is inside a BottomSheet, and the ScaffoldMessenger
      // might be showing the SnackBar behind the BottomSheet or attached to a Scaffold that is behind.
      
      // To fix this, we can try to show a Toast or use a Dialog, or find the right Scaffold.
      // But the user asked to "put its layer to the front".
      // A simple way is to show a Dialog instead of SnackBar for this specific error,
      // or use a global key for ScaffoldMessenger if available (not easily accessible here).
      // Another way is to use showDialog which appears above everything.
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: const Text('请先登录'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FavoriteSheet(aid: aid, mid: myMid),
    );
    
    if (result != null) {
      setState(() {
        if (_videoDetail!['req_user'] == null) {
          _videoDetail!['req_user'] = {};
        }
        _videoDetail!['req_user']['favorite'] = result ? 1 : 0;
      });
      
      // Refresh library to update favorite folder cover and count
      if (mounted) {
        Provider.of<LibraryProvider>(context, listen: false).refreshLibrary();
      }
    }
  }

  void _openSpace(int mid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SpaceSheet(mid: mid),
    );
  }

  void _playVideo(Song song) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    if (playerProvider.playlist.isEmpty) {
      // If playlist is empty, play directly
      List<Song> contextList = [song];
      if (widget.contextList != null && widget.contextList!.isNotEmpty) {
        contextList = widget.contextList!;
      } else if (_recommendationAutoPlay && _relatedVideos.isNotEmpty) {
        contextList.addAll(_relatedVideos);
      } else if (_hasCollection && _collectionVideos.isNotEmpty) {
         contextList = _collectionVideos;
      }
      
      playerProvider.setPlaylistAndPlay(contextList, song);
      if (widget.simplified) {
        Navigator.pop(context);
      }
    } else if (widget.simplified && widget.contextList != null) {
      // If simplified (opened from song list), show play options dialog
      showModalBottomSheet(
        context: context,
        builder: (context) => PlayOptionsSheet(
          song: song,
          contextList: widget.contextList!,
          onPlayAction: () {
            // Maybe close the detail sheet?
            // Navigator.pop(context); 
            // User didn't specify to close, but usually we stay or close.
            // Let's keep it open.
          },
        ),
      );
    } else {
      // Default behavior for full detail page
      List<Song> contextList = [song];
      if (_recommendationAutoPlay && _relatedVideos.isNotEmpty) {
        contextList.addAll(_relatedVideos);
      } else if (_hasCollection && _collectionVideos.isNotEmpty) {
         contextList = _collectionVideos;
      }
      
      playerProvider.setPlaylistAndPlay(contextList, song);
    }
  }

  Song _mapDetailToSong(Map<String, dynamic> data) {
    return Song(
      title: data['title'] ?? '',
      artist: data['owner']?['name'] ?? '',
      coverUrl: data['pic'] ?? '',
      lyrics: '',
      colorValue: 0xFF2196F3,
      bvid: data['bvid'] ?? '',
      cid: data['cid'] ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final playerProvider = Provider.of<PlayerProvider>(context);
    
    bool showPlayButton = true;
    if (playerProvider.currentSong != null && playerProvider.currentSong!.bvid == widget.bvid) {
      showPlayButton = false;
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
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
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () {
                    SchemeLauncher.launchVideo(context, widget.bvid);
                  },
                  tooltip: '在Bilibili中打开',
                ),
              ],
            ),
          ),
          if (_isLoadingDetail)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_videoDetail == null)
            const Expanded(child: Center(child: Text('无法加载视频详情')))
          else if (widget.simplified)
            Expanded(
              child: ListView(
                controller: widget.scrollController,
                children: [
                  VideoDetailInfo(
                    data: _videoDetail!,
                    showPlayButton: showPlayButton,
                    onPlay: () {
                      if (_videoDetail != null) {
                        _playVideo(_mapDetailToSong(_videoDetail!));
                      }
                    },
                    onFav: _handleFav,
                    onOpenSpace: _openSpace,
                  ),
                ],
              ),
            )
          else ...[
            VideoDetailInfo(
              data: _videoDetail!,
              showPlayButton: showPlayButton,
              onPlay: () {
                if (_videoDetail != null) {
                  _playVideo(_mapDetailToSong(_videoDetail!));
                }
              },
              onFav: _handleFav,
              onOpenSpace: _openSpace,
            ),
            
            // Tabs
            TabBar(
              controller: _tabController,
              tabs: [
                const Tab(text: '推荐'),
                const Tab(text: '合集与分P'),
                if (settingsProvider.enableComments) const Tab(text: '评论'),
              ],
            ),
            
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRelatedTab(),
                  _buildCollectionTab(),
                  if (settingsProvider.enableComments) _buildCommentsTab(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRelatedTab() {
    return Column(
      children: [
        CheckboxListTile(
          value: _recommendationAutoPlay,
          onChanged: _handleRecommendationAutoPlay,
          title: const Text('推荐连播'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        Expanded(
          child: _isLoadingRelated
              ? const Center(child: CircularProgressIndicator())
              : _relatedVideos.isEmpty
                  ? const Center(child: Text('暂无推荐'))
                  : ListView.builder(
                      controller: widget.scrollController,
                      itemCount: _relatedVideos.length,
                      itemBuilder: (context, index) {
                        return SongListItem(
                          song: _relatedVideos[index],
                          contextList: _relatedVideos,
                          onPlayAction: () {
                             // When clicked from related list, we want to open detail page?
                             // The user said: "lib/widgets/song_list/song_list_item.dart click logic replaced by opening detail page"
                             // But SongListItem has its own logic. We need to override it or change SongListItem.
                             // Wait, the user said "lib/widgets/song_list/song_list_item.dart click logic replaced by opening detail page".
                             // This means we should modify SongListItem or how we use it.
                             // But here we are inside VideoDetailPage. If we click a related video, we probably want to navigate to its detail page.
                             
                             // However, the user also said: "detail page opened via song_list_item should not have recommendation, parts, and comments"
                             // This suggests a "SimplifiedVideoDetailPage".
                             
                             // Let's handle this in SongListItem modification.
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildCollectionTab() {
    if (_isLoadingCollection) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_hasCollection || _collectionVideos.isEmpty) {
      return const Center(child: Text('无所属合集或分P'));
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: _handleCollectionReplace,
            icon: const Icon(Icons.playlist_play),
            label: const Text('替换播放列表'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: _collectionVideos.length,
            itemBuilder: (context, index) {
              final song = _collectionVideos[index];
              final isCurrent = song.bvid == widget.bvid;
              return Container(
                color: isCurrent ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3) : null,
                child: SongListItem(
                  song: song,
                  contextList: _collectionVideos,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsTab() {
    return Column(
      children: [
        Expanded(
          child: _comments.isEmpty && !_isLoadingComments
              ? const Center(child: Text('无评论'))
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
                      _loadComments();
                    }
                    return false;
                  },
                  child: ListView.separated(
                    controller: widget.scrollController,
                    itemCount: _comments.length + 1,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == _comments.length) {
                        if (_isLoadingComments) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        } else if (!_hasMoreComments) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: Text('到底了', style: TextStyle(color: Colors.grey))),
                          );
                        } else {
                          return const SizedBox(height: 60);
                        }
                      }
                      
                      final comment = _comments[index];
                      return _buildCommentItem(comment, index);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment, int index) {
    final member = comment['member'] ?? {};
    final content = comment['content'] ?? {};
    final String uname = member['uname'] ?? 'Unknown';
    final String avatar = member['avatar'] ?? '';
    final String message = content['message'] ?? '';
    final int ctime = comment['ctime'] ?? 0;
    final replies = comment['replies'];
    final int rpid = comment['rpid'] ?? 0;
    final int oid = comment['oid'] ?? 0;
    final bool noMoreSubReplies = comment['no_more_sub_replies'] ?? false;
    
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(avatar),
            radius: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(uname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(_formatFullDate(ctime), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 4),
                Text(message),
                if (replies != null && replies is List && replies.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < replies.length; i++)
                          _buildSubReply(replies[i]),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: GestureDetector(
                            onTap: noMoreSubReplies ? null : () => _loadSubReplies(index, oid, rpid),
                            behavior: HitTestBehavior.translucent,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                noMoreSubReplies ? '到底了' : '查看更多回复 >',
                                style: TextStyle(
                                  color: noMoreSubReplies ? Theme.of(context).disabledColor : Theme.of(context).colorScheme.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubReply(dynamic reply) {
    final member = reply['member'] ?? {};
    final content = reply['content'] ?? {};
    final String uname = member['uname'] ?? 'Unknown';
    final String message = content['message'] ?? '';
    final int ctime = reply['ctime'] ?? 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 12),
              children: [
                TextSpan(text: '$uname: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: message),
              ],
            ),
          ),
          Text(_formatFullDate(ctime), style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 10)),
        ],
      ),
    );
  }

  String _formatNumber(int num) {
    if (num >= 10000) {
      return '${(num / 10000).toStringAsFixed(1)}万';
    }
    return num.toString();
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.year}-${date.month}-${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  String _formatFullDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)} ${twoDigits(date.hour)}:${twoDigits(date.minute)}:${twoDigits(date.second)}';
  }
}
