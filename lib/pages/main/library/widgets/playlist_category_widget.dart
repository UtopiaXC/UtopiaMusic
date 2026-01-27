import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/connection/video/discover.dart';
import 'package:utopia_music/pages/main/library/widgets/online_playlist_detail_sheet.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_detail_sheet.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_form_sheet.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/providers/library_provider.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/connection/video/library.dart';
import 'package:utopia_music/utils/scheme_launch.dart';
import 'package:utopia_music/generated/l10n.dart';

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
  final VoidCallback? onLoginTap;
  final bool showDragHandle;
  final int? dragIndex;

  const PlaylistCategoryWidget({
    super.key,
    required this.type,
    required this.title,
    this.refreshSignal = 0,
    this.onLoginTap,
    this.showDragHandle = false,
    this.dragIndex,
  });

  @override
  State<PlaylistCategoryWidget> createState() => _PlaylistCategoryWidgetState();
}

class _PlaylistCategoryWidgetState extends State<PlaylistCategoryWidget>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {

  bool _isExpanded = false;
  bool _isLoading = false;
  bool _hasLoaded = false;

  String? _errorMessage;
  List<PlaylistInfo> _playlists = [];
  final LibraryApi _libraryApi = LibraryApi();

  late AnimationController _expandController;
  late Animation<double> _animation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.fastOutSlowIn,
    );
    _loadData(forceRefresh: false);
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PlaylistCategoryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshSignal != oldWidget.refreshSignal) {
      _loadData(forceRefresh: true);
    }
  }
  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasLoaded) {
      return;
    }

    final libraryProvider = Provider.of<LibraryProvider>(context, listen: false);
    bool isLocalRefreshOnly = libraryProvider.isLocalRefreshOnly;
    if (!forceRefresh && widget.type != PlaylistCategoryType.local && isLocalRefreshOnly && _playlists.isNotEmpty) {
      return;
    }

    if (widget.type == PlaylistCategoryType.local) {
      await _loadLocalPlaylists();
    } else {
      await _loadOnlinePlaylists();
    }
  }

  Future<void> _loadLocalPlaylists() async {
    if (!_hasLoaded) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

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
          _hasLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '${S.of(context).common_failed}: $e';
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
          _hasLoaded = true;
        });
      }
      return;
    }

    if (_playlists.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      int mid = authProvider.userInfo?.mid ?? 0;

      List<dynamic> rawList = [];
      if (widget.type == PlaylistCategoryType.favorites) {
        rawList = await _libraryApi.getFavoriteFolders(mid);
      } else {
        rawList = await _libraryApi.getCollections(mid);
      }

      if (mounted) {
        if (rawList.isEmpty) {
          setState(() {
            _playlists = [];
            _isLoading = false;
            _hasLoaded = true;
          });
        } else {
          List<PlaylistInfo> processedList = [];

          for (var item in rawList) {
            String id = item['id']?.toString() ?? '';
            String title = item['title'] ?? '';
            String cover = item['cover'] ?? '';
            int count = item['media_count'] ?? 0;

            if (widget.type == PlaylistCategoryType.favorites && (cover.isEmpty || cover.contains('bfs/archive/'))) {
              try {
                final info = await _libraryApi.getFavoriteFolderInfo(id);
                if (info != null) {
                  cover = info['cover'] ?? cover;
                }
              } catch (e) {
                print('Failed to fetch info for folder $id: $e');
              }
            }

            processedList.add(PlaylistInfo(
              id: id,
              title: title,
              coverUrl: cover,
              count: count,
              isLocal: false,
              originalData: item,
            ));
          }

          setState(() {
            _playlists = processedList;
            _isLoading = false;
            _hasLoaded = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = S.of(context).pages_discover_error_network;
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
            Provider.of<LibraryProvider>(context, listen: false).refreshLibrary(localOnly: true);
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
            Provider.of<LibraryProvider>(context, listen: false).refreshLibrary(localOnly: true);
          },
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => OnlinePlaylistDetailSheet(
          playlistInfo: playlist,
          isCollection: widget.type == PlaylistCategoryType.collections,
        ),
      );
    }
  }

  Future<void> _launchBilibili() async {
    await SchemeLauncher.launchBilibili(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
          SizeTransition(
            sizeFactor: _animation,
            axisAlignment: -1.0,
            child: _buildExpandedList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
          if (_isExpanded) {
            _expandController.forward();
          } else {
            _expandController.reverse();
          }
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
            if (widget.showDragHandle && widget.dragIndex != null)
              ReorderableDragStartListener(
                index: widget.dragIndex!,
                child: const Icon(Icons.drag_handle),
              ),
            const SizedBox(width: 8),
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
      return _buildErrorState(S.of(context).pages_library_category_not_logged_in, S.of(context).pages_library_category_login, () {
        if (widget.onLoginTap != null) {
          widget.onLoginTap!();
        } else {
          Provider.of<AuthProvider>(context, listen: false).login();
        }
      });
    }

    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!, S.of(context).common_refresh, () => _loadData(forceRefresh: true));
    }

    if (_isLoading) {
      return const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_playlists.isEmpty) {
      if (widget.type == PlaylistCategoryType.local) {
        return _buildEmptyState(S.of(context).pages_library_category_empty_local, S.of(context).common_create, _handleCreateLocalPlaylist);
      } else {
        return _buildEmptyState(S.of(context).pages_library_category_empty_online(widget.title), S.of(context).pages_library_category_go_bilibili, _launchBilibili);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: SizedBox(
        height: 160,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
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
                      child: Stack(
                        children: [
                          if (playlist.coverUrl.isEmpty)
                            Center(child: Icon(Icons.music_note, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                                '${playlist.count}',
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
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(child: Text(S.of(context).common_no_data)),
      );
    }

    if (widget.type == PlaylistCategoryType.local) {
      return Column(
        children: [
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: Text(S.of(context).pages_library_category_create_local),
            onTap: _handleCreateLocalPlaylist,
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _playlists.length,
            buildDefaultDragHandles: false,
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
              return ReorderableDelayedDragStartListener(
                key: ValueKey(playlist.id),
                index: index,
                child: ListTile(
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
                    child: Stack(
                      children: [
                        if (playlist.coverUrl.isEmpty)
                          Center(child: Icon(Icons.music_note, size: 24, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              '${playlist.count}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  title: Text(playlist.title),
                  subtitle: Text('${playlist.count}${S.of(context).common_count_of_songs}'),
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                  onTap: () => _handlePlaylistTap(playlist),
                ),
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
                  child: Stack(
                    children: [
                      if (playlist.coverUrl.isEmpty)
                        Center(child: Icon(Icons.music_note, size: 24, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            '${playlist.count}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                title: Text(playlist.title),
                subtitle: Text('${playlist.count}${S.of(context).common_count_of_songs}'),
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