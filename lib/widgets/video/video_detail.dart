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
import 'package:utopia_music/widgets/video/video_detail_info.dart';
import 'package:utopia_music/widgets/video/favorite_sheet.dart';
import 'package:utopia_music/widgets/dialogs/play_options_sheet.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/providers/library_provider.dart';
import 'package:utopia_music/utils/scheme_launch.dart';
import 'package:utopia_music/utils/log.dart';

const String _tag = "VIDEO_DETAIL";

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

class _VideoDetailPageState extends State<VideoDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final VideoDetailApi _videoDetailApi = VideoDetailApi();
  final UserApi _userApi = UserApi();
  bool _isClosing = false;

  Map<String, dynamic>? _videoDetail;
  bool _isLoadingDetail = true;
  List<Song> _relatedVideos = [];
  bool _isLoadingRelated = false;
  bool _recommendationAutoPlay = false;
  static const String _recommendationAutoPlayKey = 'recommendation_auto_play';
  List<Song> _collectionVideos = [];
  bool _isLoadingCollection = false;
  bool _hasCollection = false;
  bool _isParts = false;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = false;
  int _commentPage = 1;
  bool _hasMoreComments = true;

  @override
  void initState() {
    super.initState();
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

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

  final ScrollPhysics _scrollPhysics = const BouncingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recommendationAutoPlay =
          prefs.getBool(_recommendationAutoPlayKey) ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_recommendationAutoPlayKey, _recommendationAutoPlay);
    if (mounted) {
      Provider.of<PlayerProvider>(
        context,
        listen: false,
      ).setRecommendationAutoPlay(_recommendationAutoPlay);
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
          _checkFavStatus(detail['aid'] ?? 0);

          if (!widget.simplified) {
            _loadRelatedVideos();
            _loadCollectionOrParts(detail);
            final settingsProvider = Provider.of<SettingsProvider>(
              context,
              listen: false,
            );
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
      Log.w(_tag, 'Error checking fav status: $e');
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

  Future<void> _loadCollectionOrParts(Map<String, dynamic> detail) async {
    setState(() => _isLoadingCollection = true);

    final int videos = detail['videos'] ?? 0;
    if (videos > 1) {
      final parts = await _videoDetailApi.getVideoParts(context, widget.bvid);
      if (mounted) {
        setState(() {
          _collectionVideos = parts;
          _hasCollection = parts.isNotEmpty;
          _isParts = true;
          _isLoadingCollection = false;
        });
      }
    } else {
      final videos = await _videoDetailApi.getVideoCollection(
        context,
        widget.bvid,
        detail['aid'] ?? 0,
      );
      if (mounted) {
        setState(() {
          _collectionVideos = videos;
          _hasCollection = videos.isNotEmpty;
          _isParts = false;
          _isLoadingCollection = false;
        });
      }
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
    final list = await _videoDetailApi.getVideoReplies(
      widget.bvid,
      page: _commentPage,
    );
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

    final subReplies = await _videoDetailApi.getReplyReplies(
      oid,
      rpid,
      page: currentPage,
    );
    if (mounted) {
      setState(() {
        if (subReplies.isEmpty) {
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
          title: Text(
            S.of(context).weight_video_detail_enable_auto_continue_title,
          ),
          content: Text(
            S.of(context).weight_video_detail_enable_auto_continue_message,
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
        setState(() {
          _recommendationAutoPlay = true;
        });
        await _saveSettings();
        final playerProvider = Provider.of<PlayerProvider>(
          context,
          listen: false,
        );
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
    String content = S
        .of(context)
        .weight_video_detail_replace_by_this_collection_title;
    if (_recommendationAutoPlay) {
      content += S
          .of(context)
          .weight_video_detail_replace_by_this_collection_recommend_alert;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).common_replace_playlist),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).common_replace),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (_collectionVideos.isNotEmpty) {
        Song? targetSong;
        if (_isParts) {
          final currentSong = playerProvider.currentSong;
          if (currentSong != null && currentSong.bvid == widget.bvid) {
            for (var s in _collectionVideos) {
              if (s.cid == currentSong.cid) {
                targetSong = s;
                break;
              }
            }
          }
        } else {
          for (var s in _collectionVideos) {
            if (s.bvid == widget.bvid) {
              targetSong = s;
              break;
            }
          }
        }

        targetSong ??= _collectionVideos.first;

        await playerProvider.setPlaylistAndPlay(_collectionVideos, targetSong);
        if (mounted) Navigator.pop(context);
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
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(S.of(context).common_tips),
          content: Text(S.of(context).weight_video_detail_please_login_first),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(S.of(context).common_confirm),
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
      List<Song> contextList = [song];
      if (widget.contextList != null && widget.contextList!.isNotEmpty) {
        contextList = widget.contextList!;
      } else if (_recommendationAutoPlay && _relatedVideos.isNotEmpty) {
        contextList.addAll(_relatedVideos);
      } else if (_hasCollection && _collectionVideos.isNotEmpty) {
        contextList = _collectionVideos;
      }

      playerProvider.setPlaylistAndPlay(contextList, song);
      Navigator.pop(context);
    } else if (widget.simplified && widget.contextList != null) {
      showModalBottomSheet(
        context: context,
        builder: (context) => PlayOptionsSheet(
          song: song,
          contextList: widget.contextList!,
          onPlayAction: () {
            Navigator.pop(context);
          },
        ),
      );
    } else {
      List<Song> contextList = [song];
      if (_recommendationAutoPlay && _relatedVideos.isNotEmpty) {
        contextList.addAll(_relatedVideos);
      } else if (_hasCollection && _collectionVideos.isNotEmpty) {
        contextList = _collectionVideos;
      }

      playerProvider.setPlaylistAndPlay(contextList, song);
      Navigator.pop(context);
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
    if (playerProvider.currentSong != null &&
        playerProvider.currentSong!.bvid == widget.bvid) {
      if (_isParts) {
        showPlayButton = false;
      } else {
        showPlayButton = false;
      }
    }

    String collectionTabTitle = S.of(context).common_collection_and_parts;
    if (_isParts) {
      collectionTabTitle = S.of(context).common_parts;
    } else if (_hasCollection) {
      collectionTabTitle = S.of(context).common_collection;
    }

    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        if (_isClosing) return false;

        if (notification.metrics.pixels < -80 &&
            notification.dragDetails != null) {
          _isClosing = true;
          Navigator.pop(context);
          return true;
        }
        return false;
      },
      child: Container(
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
                    tooltip: S.of(context).common_open_in_bilibili,
                  ),
                ],
              ),
            ),
            if (_isLoadingDetail)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_videoDetail == null)
              Expanded(
                child: Center(
                  child: Text(
                    S.of(context).weight_video_detail_cannot_load_detail,
                  ),
                ),
              )
            else if (widget.simplified)
              Expanded(
                child: ListView(
                  physics: _scrollPhysics,
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

              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: S.of(context).common_recommend),
                  Tab(text: collectionTabTitle),
                  if (settingsProvider.enableComments)
                    Tab(text: S.of(context).common_comment),
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
      ),
    );
  }

  Widget _buildRelatedTab() {
    return Column(
      children: [
        CheckboxListTile(
          value: _recommendationAutoPlay,
          onChanged: _handleRecommendationAutoPlay,
          title: Text(S.of(context).play_control_mode_random_continue),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        Expanded(
          child: _isLoadingRelated
              ? const Center(child: CircularProgressIndicator())
              : _relatedVideos.isEmpty
              ? Center(child: Text(S.of(context).common_none))
              : ListView.builder(
                  physics: _scrollPhysics,
                  controller: widget.scrollController,
                  itemCount: _relatedVideos.length,
                  itemBuilder: (context, index) {
                    return SongListItem(
                      song: _relatedVideos[index],
                      contextList: _relatedVideos,
                      onPlayAction: () {
                        Navigator.pop(context);
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
      return Center(child: Text(S.of(context).common_none));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: _handleCollectionReplace,
            icon: const Icon(Icons.playlist_play),
            label: Text(S.of(context).common_replace_playlist),
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: _scrollPhysics,
            controller: widget.scrollController,
            itemCount: _collectionVideos.length,
            itemBuilder: (context, index) {
              final song = _collectionVideos[index];
              bool isCurrent = false;
              if (_isParts) {
                final playerProvider = Provider.of<PlayerProvider>(
                  context,
                  listen: false,
                );
                if (playerProvider.currentSong != null &&
                    playerProvider.currentSong!.bvid == widget.bvid &&
                    playerProvider.currentSong!.cid == song.cid) {
                  isCurrent = true;
                }
              } else {
                isCurrent = song.bvid == widget.bvid;
              }

              return Container(
                color: isCurrent
                    ? Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withOpacity(0.3)
                    : null,
                child: SongListItem(
                  song: song,
                  contextList: _collectionVideos,
                  onPlayAction: () {
                    Navigator.pop(context);
                  },
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
              ? Center(child: Text(S.of(context).common_no_comment))
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent - 200) {
                      _loadComments();
                    }
                    return false;
                  },
                  child: ListView.separated(
                    physics: _scrollPhysics,
                    controller: widget.scrollController,
                    itemCount: _comments.length + 1,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == _comments.length) {
                        if (_isLoadingComments) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        } else if (!_hasMoreComments) {
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
    final String mid = member['mid']?.toString() ?? '0';

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openSpace(int.parse(mid)),
            child: CircleAvatar(
              backgroundImage: NetworkImage(avatar),
              radius: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => _openSpace(int.parse(mid)),
                      child: Text(
                        uname,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      _formatFullDate(ctime),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(message),
                if (replies != null &&
                    replies is List &&
                    replies.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
                            onTap: noMoreSubReplies
                                ? null
                                : () => _loadSubReplies(index, oid, rpid),
                            behavior: HitTestBehavior.translucent,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Text(
                                noMoreSubReplies
                                    ? S.of(context).common_at_bottom
                                    : S
                                          .of(context)
                                          .weight_video_detail_more_comments,
                                style: TextStyle(
                                  color: noMoreSubReplies
                                      ? Theme.of(context).disabledColor
                                      : Theme.of(context).colorScheme.primary,
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
    final String mid = member['mid']?.toString() ?? '0';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 12,
              ),
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => _openSpace(int.parse(mid)),
                    child: Text(
                      '$uname: ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                TextSpan(text: message),
              ],
            ),
          ),
          Text(
            _formatFullDate(ctime),
            style: TextStyle(
              color: Theme.of(context).disabledColor,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int num) {
    if (num >= 10000) {
      return '${(num / 10000).toStringAsFixed(1)} ${S.of(context).number_ten_thousand}';
    }
    return num.toString();
  }

  String _formatFullDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)} ${twoDigits(date.hour)}:${twoDigits(date.minute)}:${twoDigits(date.second)}';
  }
}
