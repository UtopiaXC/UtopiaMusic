import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/connection/video/video_list.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_detail_sheet.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_form_sheet.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/providers/library_provider.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:url_launcher/url_launcher.dart';

enum PlaylistCategoryType {
  favorites,
  collections,
  local,
}

class PlaylistInfo {
  final String id;
  final String title;
  final String coverUrl;
  final int count;
  final bool isLocal;
  final dynamic originalData;

  PlaylistInfo({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.count,
    this.isLocal = false,
    this.originalData,
  });
}

class PlaylistCategoryWidget extends StatefulWidget {
  final PlaylistCategoryType type;
  final String title;
  final int refreshSignal;

  const PlaylistCategoryWidget({
    super.key,
    required this.type,
    required this.title,
    this.refreshSignal = 0,
  });

  @override
  State<PlaylistCategoryWidget> createState() => _PlaylistCategoryWidgetState();
}

class _PlaylistCategoryWidgetState extends State<PlaylistCategoryWidget> {
  bool _isExpanded = false;
  bool _isLoading = false;
  String? _errorMessage;
  List<PlaylistInfo> _playlists = [];
  final VideoApi _videoApi = VideoApi();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(PlaylistCategoryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshSignal != oldWidget.refreshSignal) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (widget.type == PlaylistCategoryType.local) {
      await _loadLocalPlaylists();
    } else {
      await _loadOnlinePlaylists();
    }
  }

  Future<void> _loadLocalPlaylists() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final localPlaylists = await DatabaseService().getLocalPlaylists();
      if (mounted) {
        setState(() {
          _playlists = localPlaylists.map((p) => PlaylistInfo(
            id: p.id.toString(),
            title: p.title,
            coverUrl: p.coverUrl ?? '',
            count: p.songCount,
            isLocal: true,
            originalData: p,
          )).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '加载失败: $e';
        });
      }
    }
  }

  Future<void> _loadOnlinePlaylists() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      if (mounted) {
        setState(() {
          _errorMessage = 'not_logged_in';
          _playlists = [];
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      int mid = 0; // Placeholder
      
      List<dynamic> rawList = [];
      if (widget.type == PlaylistCategoryType.favorites) {
        rawList = await _videoApi.getFavoriteFolders(mid);
      } else {
        // Collections logic (placeholder)
        // rawList = await _videoApi.getCollections(mid);
      }

      if (mounted) {
        if (rawList.isEmpty) {
           setState(() {
             _playlists = [];
             _isLoading = false;
           });
        } else {
          setState(() {
            _playlists = rawList.map((item) => PlaylistInfo(
              id: item['id'].toString(),
              title: item['title'],
              coverUrl: item['cover'] ?? '',
              count: item['media_count'] ?? 0,
              isLocal: false,
              originalData: item,
            )).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '无网络或被风控，请尝试重新获取';
        });
      }
    }
  }

  void _handleCreateLocalPlaylist() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PlaylistFormSheet(
        onSubmit: (title, description) async {
          await DatabaseService().createLocalPlaylist(title, description);
          if (mounted) {
             Provider.of<LibraryProvider>(context, listen: false).refreshLibrary();
          }
        },
      ),
    );
  }

  void _handlePlaylistTap(PlaylistInfo playlist) {
    if (playlist.isLocal) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => PlaylistDetailSheet(
          playlist: playlist.originalData as LocalPlaylist,
          onUpdate: () {
            Provider.of<LibraryProvider>(context, listen: false).refreshLibrary();
          },
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('在线歌单详情暂未实现')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(colorScheme),
          _buildCoverFlow(),
          if (_isExpanded) _buildExpandedList(),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Container(
        margin: const EdgeInsets.all(12.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverFlow() {
    if (_errorMessage == 'not_logged_in') {
      return _buildErrorState('未登录，请登录后查看', '登录', () {
        Provider.of<AuthProvider>(context, listen: false).login().then((_) => _loadData());
      });
    }

    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!, '刷新', _loadData);
    }

    if (_isLoading) {
      return const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_playlists.isEmpty) {
      if (widget.type == PlaylistCategoryType.local) {
        return _buildEmptyState('当前无本地歌单', '创建', _handleCreateLocalPlaylist);
      } else {
        return _buildEmptyState('当前没有${widget.title}，请前往Bilibili创建', '前往Bilibili', () {
          launchUrl(Uri.parse('https://www.bilibili.com'));
        });
      }
    }

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _playlists.length,
        itemBuilder: (context, index) {
          final playlist = _playlists[index];
          return GestureDetector(
            onTap: () => _handlePlaylistTap(playlist),
            child: Container(
              width: 110,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      image: playlist.coverUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(playlist.coverUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: playlist.coverUrl.isEmpty
                        ? const Icon(Icons.music_note, size: 48)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    playlist.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
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

  Widget _buildErrorState(String message, String buttonText, VoidCallback onPressed) {
    return Container(
      height: 140,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message, 
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onPressed,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, String buttonText, VoidCallback onPressed) {
    return Container(
      height: 140,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message, 
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onPressed,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedList() {
    if (_playlists.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: Text('无内容')),
      );
    }

    if (widget.type == PlaylistCategoryType.local) {
      return Column(
        children: [
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('新建歌单'),
            onTap: _handleCreateLocalPlaylist,
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _playlists.length,
            onReorder: (oldIndex, newIndex) {
               setState(() {
                 if (oldIndex < newIndex) {
                   newIndex -= 1;
                 }
                 final item = _playlists.removeAt(oldIndex);
                 _playlists.insert(newIndex, item);
               });
            },
            itemBuilder: (context, index) {
              final playlist = _playlists[index];
              return ListTile(
                key: ValueKey(playlist.id),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    image: playlist.coverUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(playlist.coverUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: playlist.coverUrl.isEmpty
                      ? const Icon(Icons.music_note, size: 24)
                      : null,
                ),
                title: Text(playlist.title),
                subtitle: Text('${playlist.count}首'),
                trailing: const Icon(Icons.drag_handle),
                onTap: () => _handlePlaylistTap(playlist),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      );
    } else {
      return Column(
        children: [
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _playlists.length,
            itemBuilder: (context, index) {
              final playlist = _playlists[index];
              return ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    image: playlist.coverUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(playlist.coverUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: playlist.coverUrl.isEmpty
                      ? const Icon(Icons.music_note, size: 24)
                      : null,
                ),
                title: Text(playlist.title),
                subtitle: Text('${playlist.count}首'),
                onTap: () => _handlePlaylistTap(playlist),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      );
    }
  }
}
