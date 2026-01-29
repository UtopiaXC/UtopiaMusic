import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/services/download_manager.dart';
import 'package:utopia_music/utils/quality_utils.dart';
import 'package:utopia_music/widgets/song_list/add_to_playlist_sheet.dart';
import 'package:utopia_music/widgets/video/video_detail.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/widgets/player/dialogs/play_options_sheet.dart';
import 'package:utopia_music/generated/l10n.dart';

class DownloadedSheet extends StatefulWidget {
  const DownloadedSheet({super.key});

  @override
  State<DownloadedSheet> createState() => _DownloadedSheetState();
}

class _DownloadedSheetState extends State<DownloadedSheet> {
  final DownloadManager _downloadManager = DownloadManager();
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _allDownloads = [];
  bool _isLoading = true;
  StreamSubscription? _updateSubscription;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
    _updateSubscription = _downloadManager.downloadUpdateStream.listen((update) {
      _updateProgress(update);
    });
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDownloads() async {
    setState(() => _isLoading = true);
    final downloads = await _dbService.getAllDownloads();
    if (mounted) {
      setState(() {
        _allDownloads = List.from(downloads);
        _sortDownloads();
        _isLoading = false;
      });
    }
  }

  void _updateProgress(DownloadUpdate update) {
    final index = _allDownloads.indexWhere((d) => d['id'] == update.id);
    if (index != -1) {
      setState(() {
        final item = Map<String, dynamic>.from(_allDownloads[index]);
        item['progress'] = update.progress;
        item['status'] = update.status;
        _allDownloads[index] = item;
        _sortDownloads();
      });
    } else {
      _loadDownloads();
    }
  }

  void _sortDownloads() {
    _allDownloads.sort((a, b) {
      int statusA = a['status'];
      int statusB = b['status'];

      int priorityA = _getStatusPriority(statusA);
      int priorityB = _getStatusPriority(statusB);

      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }
      
      int timeA = a['create_time'] ?? 0;
      int timeB = b['create_time'] ?? 0;

      if (statusA == 0 || statusA == 1) {
         return timeA.compareTo(timeB);
      }
      return timeB.compareTo(timeA);
    });
  }

  int _getStatusPriority(int status) {
    switch (status) {
      case 1: // Downloading
        return 0;
      case 0: // Queued
        return 1;
      case 3: // Completed
        return 2;
      case 4: // Failed
        return 3;
      default:
        return 4;
    }
  }

  Future<void> _deleteDownload(String bvid, int cid) async {
    await _downloadManager.deleteDownload(bvid, cid);
    _loadDownloads();
  }

  Future<void> _cancelDownload(String bvid, int cid) async {
    await _deleteDownload(bvid, cid);
  }

  Future<void> _retryDownload(String bvid, int cid) async {
    await _downloadManager.retryDownload(bvid, cid);
    _loadDownloads();
  }

  Future<void> _handleDeleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).pages_library_download_delete_all),
        content: Text(S.of(context).pages_library_download_delete_all_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).pages_library_download_action_delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (var item in _allDownloads) {
        await _downloadManager.deleteDownload(item['bvid'], item['cid']);
      }
      _loadDownloads();
    }
  }

  Future<void> _handlePauseAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).pages_library_download_pause_all),
        content: Text(S.of(context).pages_library_download_pause_all_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).play_control_pause),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _downloadManager.setMaxConcurrentDownloads(0);
      await Future.delayed(const Duration(milliseconds: 200));
      _loadDownloads();
    }
  }

  Future<void> _handleResumeAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).pages_library_download_resume_all),
        content: Text(S.of(context).pages_library_download_resume_all_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).play_control_resume),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _downloadManager.setMaxConcurrentDownloads(3);
      await Future.delayed(const Duration(milliseconds: 200));
      _loadDownloads();
    }
  }

  void _playAll(int initialIndex) {
    final songs = _allDownloads.map((d) => Song(
      title: d['title'],
      artist: d['artist'],
      coverUrl: d['cover_url'],
      lyrics: '',
      colorValue: 0,
      bvid: d['bvid'],
      cid: d['cid'],
    )).toList();

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.playlist.isEmpty) {
      final song = songs[initialIndex];
      playerProvider.setPlaylistAndPlay(songs, song);
    } else {
      final song = songs[initialIndex];
      showModalBottomSheet(
        context: context,
        builder: (context) => PlayOptionsSheet(
          song: song,
          contextList: songs,
          onPlayAction: () {},
        ),
      );
    }
  }

  void _showAddToPlaylist(Song song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddToPlaylistSheet(song: song),
    );
  }

  void _showDetail(String bvid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: VideoDetailPage(
              bvid: bvid,
              simplified: false,
              scrollController: scrollController,
            ),
          );
        },
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.of(context).size.height * 0.85;
    
    bool hasDownloading = _allDownloads.any((d) => d['status'] == 1);
    bool hasQueuedOrPaused = _allDownloads.any((d) => d['status'] == 0); 
    
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Text(
                  S.of(context).pages_library_download_manager,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_allDownloads.isNotEmpty)
                  TextButton(
                    onPressed: _handleDeleteAll,
                    child: Text(S.of(context).pages_library_download_delete_all),
                  ),
                if (hasDownloading)
                  TextButton(
                    onPressed: _handlePauseAll,
                    child: Text(S.of(context).play_control_pause),
                  )
                else if (hasQueuedOrPaused)
                   TextButton(
                    onPressed: _handleResumeAll,
                    child: Text(S.of(context).play_control_resume),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allDownloads.isEmpty
                    ? Center(child: Text(S.of(context).pages_library_download_empty))
                    : ListView.builder(
                        itemCount: _allDownloads.length,
                        itemBuilder: (context, index) {
                          final item = _allDownloads[index];
                          final status = item['status'] as int;
                          final progress = item['progress'] as double? ?? 0.0;
                          final title = item['title'] as String;
                          final artist = item['artist'] as String;
                          final coverUrl = item['cover_url'] as String;
                          final quality = item['quality'] as int;
                          final bvid = item['bvid'] as String;
                          final cid = item['cid'] as int;
                          
                          String statusText = '';
                          Widget? trailingInfo;
                          
                          if (status == 1) {
                            statusText = '${S.of(context).pages_library_download_status_downloading}: ${(progress * 100).toInt()}%';
                          } else if (status == 0) {
                            statusText = S.of(context).pages_library_download_status_queued;
                          } else if (status == 3) {
                            statusText = S.of(context).pages_library_download_status_completed;
                            final path = item['save_path'] as String;
                            final file = File(path);
                            trailingInfo = FutureBuilder<int>(
                              future: file.exists().then((exists) => exists ? file.length() : 0),
                              builder: (context, snapshot) {
                                final size = snapshot.data ?? 0;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatSize(size),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Theme.of(context).dividerColor),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        QualityUtils.getQualityLabel(context,quality),
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          } else if (status == 4) {
                            statusText = S.of(context).pages_library_download_status_failed;
                          }

                          return ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                image: coverUrl.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage('$coverUrl@100w_100h.webp'),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                              child: coverUrl.isEmpty ? const Icon(Icons.music_note) : null,
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              statusText,
                              style: TextStyle(
                                color: status == 1 ? Theme.of(context).colorScheme.primary : null,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (status == 4)
                                  IconButton(
                                    icon: const Icon(Icons.refresh),
                                    onPressed: () => _retryDownload(bvid, cid),
                                    tooltip: S.of(context).common_retry,
                                  ),
                                if (trailingInfo != null) trailingInfo,
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) {
                                    final song = Song(
                                      title: title,
                                      artist: artist,
                                      coverUrl: coverUrl,
                                      lyrics: '',
                                      colorValue: 0,
                                      bvid: bvid,
                                      cid: cid,
                                    );
                                    
                                    switch (value) {
                                      case 'cancel':
                                        _cancelDownload(bvid, cid);
                                        break;
                                      case 'delete':
                                        _deleteDownload(bvid, cid);
                                        break;
                                      case 'add_to_playlist':
                                        _playAll(index);
                                        break;
                                      case 'add_to_sheet':
                                        _showAddToPlaylist(song);
                                        break;
                                      case 'detail':
                                        _showDetail(bvid);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (status == 1 || status == 0)
                                      PopupMenuItem(
                                        value: 'cancel',
                                        child: Text(S.of(context).pages_library_download_action_cancel),
                                      ),
                                    if (status == 3 || status == 4)
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text(S.of(context).pages_library_download_action_delete),
                                      ),
                                    PopupMenuItem(
                                      value: 'add_to_playlist',
                                      child: Text(S.of(context).pages_library_download_action_add_to_playlist),
                                    ),
                                    PopupMenuItem(
                                      value: 'add_to_sheet',
                                      child: Text(S.of(context).pages_library_download_action_add_to_sheet),
                                    ),
                                    PopupMenuItem(
                                      value: 'detail',
                                      child: Text(S.of(context).pages_library_download_action_detail),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => _playAll(index),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
