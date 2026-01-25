import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_category_widget.dart';
import 'package:utopia_music/providers/library_provider.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/services/download_manager.dart';
import 'package:utopia_music/widgets/song_list/song_list_item.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/connection/video/library.dart';
import 'package:utopia_music/connection/user/user.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_form_sheet.dart';

class OnlinePlaylistDetailSheet extends StatefulWidget {
  final PlaylistInfo playlistInfo;
  final bool isCollection;

  const OnlinePlaylistDetailSheet({
    super.key,
    required this.playlistInfo,
    this.isCollection = false,
  });

  @override
  State<OnlinePlaylistDetailSheet> createState() => _OnlinePlaylistDetailSheetState();
}

class _OnlinePlaylistDetailSheetState extends State<OnlinePlaylistDetailSheet> {
  List<Song> _songs = [];
  bool _isLoading = true;
  final LibraryApi _libraryApi = LibraryApi();
  final UserApi _userApi = UserApi();
  late PlaylistInfo _currentPlaylistInfo;

  @override
  void initState() {
    super.initState();
    _currentPlaylistInfo = widget.playlistInfo;
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    try {
      final mediaId = _currentPlaylistInfo.id;
      List<Song> songs;
      bool isActuallyCollection = widget.isCollection;
      if (widget.isCollection && _currentPlaylistInfo.originalData != null) {
         final attr = _currentPlaylistInfo.originalData['attr'];
         if (attr != null && attr != 0) {
           isActuallyCollection = false;
         }
      }

      if (isActuallyCollection) {
        songs = await _libraryApi.getCollectionResources(mediaId, context);
      } else {
        songs = await _libraryApi.getFavoriteResources(mediaId, context);
      }
      
      if (mounted) {
        setState(() {
          _songs = songs;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading online playlist songs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleClone() async {
    if (_songs.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('克隆歌单'),
        content: Text('确定要将 "${_currentPlaylistInfo.title}" 克隆成本地歌单吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('克隆'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    
    setState(() => _isLoading = true);
    try {
      final id = await DatabaseService().createLocalPlaylist(
        _currentPlaylistInfo.title,
        '',
      );
      
      for (var song in _songs) {
        await DatabaseService().addSongToLocalPlaylist(id, song);
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已克隆到本地歌单')),
        );
        Provider.of<LibraryProvider>(context, listen: false).refreshLibrary(localOnly: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('克隆失败: $e')),
        );
      }
    }
  }

  Future<void> _handleDownload() async {
    if (_songs.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('下载确认'),
        content: const Text('是否下载该列表？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('下载'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (var song in _songs) {
        await DownloadManager().startDownload(song);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已全部加入下载队列')),
        );
      }
    }
  }

  Future<void> _handlePlay() async {
    if (_songs.isEmpty) return;
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    if (playerProvider.playlist.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('替换播放列表'),
          content: const Text('当前播放列表不为空，是否替换？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(S.of(context).common_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('替换'),
            ),
          ],
        ),
      );
      
      if (confirm != true) return;
    }

    if (mounted) {
      Navigator.pop(context);
    }
    await playerProvider.setPlaylistAndPlay(_songs, _songs.first);
  }

  Future<void> _handleEdit() async {
    if (widget.isCollection) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BilibiliPlaylistEditSheet(
        mediaId: int.parse(_currentPlaylistInfo.id),
        initialTitle: _currentPlaylistInfo.title,
      ),
    );
    
    // Refresh info if needed, but we might need to reload the whole sheet or just update title locally
    // For simplicity, we can just pop and let user reload, or try to reload info.
    // But _loadSongs doesn't reload playlist info.
    // We can fetch info and update _currentPlaylistInfo.
    final info = await _libraryApi.getFavoriteFolderInfo(_currentPlaylistInfo.id);
    if (info != null && mounted) {
      setState(() {
        _currentPlaylistInfo = PlaylistInfo(
          id: _currentPlaylistInfo.id,
          title: info['title'],
          coverUrl: _currentPlaylistInfo.coverUrl,
          count: _currentPlaylistInfo.count,
          isLocal: false,
          originalData: info,
        );
      });
    }
  }

  Future<void> _handleRemoveSong(Song song) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除视频'),
        content: Text('确定要将 "${song.title}" 从此收藏夹移除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final detailData = await _libraryApi.getVideoDetailForAid(song.bvid);
      int aid = 0;
      if (detailData != null) {
        aid = detailData['aid'];
      }
      
      if (aid == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法获取视频信息')),
          );
        }
        return;
      }

      final success = await _libraryApi.removeResource(
        int.parse(_currentPlaylistInfo.id),
        aid,
      );
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已移除')),
          );
          _loadSongs();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('移除失败')),
          );
        }
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
              Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            image: _currentPlaylistInfo.coverUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(_currentPlaylistInfo.coverUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: Stack(
                            children: [
                              if (_currentPlaylistInfo.coverUrl.isEmpty)
                                Center(child: Icon(Icons.music_note, size: 48, color: colorScheme.onSurfaceVariant)),
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${_currentPlaylistInfo.count}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentPlaylistInfo.title,
                                style: Theme.of(context).textTheme.titleLarge,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${_currentPlaylistInfo.count}首',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSecondaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _handlePlay,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('播放'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _handleClone,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('克隆'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!widget.isCollection) ...[
                      IconButton.filledTonal(
                        onPressed: _handleEdit,
                        icon: const Icon(Icons.edit),
                        tooltip: '编辑',
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton.filledTonal(
                      onPressed: _handleDownload,
                      icon: const Icon(Icons.download),
                      tooltip: '下载全部',
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _songs.isEmpty
                        ? GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onVerticalDragUpdate: (details) {
                              if (details.primaryDelta! > 10) {
                                Navigator.pop(context);
                              }
                            },
                            child: const Center(child: Text('暂无歌曲')),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _songs.length,
                            itemBuilder: (context, index) {
                              final song = _songs[index];
                              return SongListItem(
                                song: song,
                                contextList: _songs,
                                onPlayAction: () {
                                  Navigator.pop(context);
                                },
                                menuItems: [
                                  if (!widget.isCollection)
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 20),
                                          SizedBox(width: 12),
                                          Text('移除该视频'),
                                        ],
                                      ),
                                    ),
                                ],
                                onMenuSelected: (value) {
                                  if (value == 'remove') {
                                    _handleRemoveSong(song);
                                  }
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BilibiliPlaylistEditSheet extends StatefulWidget {
  final int mediaId;
  final String initialTitle;

  const _BilibiliPlaylistEditSheet({
    required this.mediaId,
    required this.initialTitle,
  });

  @override
  State<_BilibiliPlaylistEditSheet> createState() => _BilibiliPlaylistEditSheetState();
}

class _BilibiliPlaylistEditSheetState extends State<_BilibiliPlaylistEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  bool _isPublic = false;
  bool _isLoading = true;
  final LibraryApi _libraryApi = LibraryApi();
  final UserApi _userApi = UserApi();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descController = TextEditingController();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final info = await _libraryApi.getFavoriteFolderInfo(widget.mediaId.toString());
    if (mounted && info != null) {
      setState(() {
        _titleController.text = info['title'] ?? widget.initialTitle;
        _descController.text = info['intro'] ?? '';
        _isPublic = (info['attr'] ?? 0) & 1 == 0; // attr bit 0: 0=public, 1=private
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final success = await _userApi.editFavFolder(
      widget.mediaId,
      _titleController.text,
      _descController.text,
      _isPublic,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('修改成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('修改失败')),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除收藏夹'),
        content: const Text('确定要删除此收藏夹吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await _userApi.deleteFavFolder(widget.mediaId);
      
      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          Navigator.pop(context); // Close edit sheet
          Navigator.pop(context); // Close detail sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除成功')),
          );
          Provider.of<LibraryProvider>(context, listen: false).refreshLibrary();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除失败')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '编辑收藏夹',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            IconButton(
                              onPressed: _handleDelete,
                              icon: const Icon(Icons.delete_outline),
                              tooltip: '删除收藏夹',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: '标题',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入标题';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descController,
                          decoration: const InputDecoration(
                            labelText: '简介',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('公开收藏夹'),
                          value: _isPublic,
                          onChanged: (value) {
                            setState(() {
                              _isPublic = value;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _handleSubmit,
                            child: const Text('保存'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
        },
      ),
    );
  }
}
