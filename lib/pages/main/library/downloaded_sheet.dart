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

  // Section collapse states
  bool _downloadingExpanded = true;
  bool _failedExpanded = true;
  bool _queuedExpanded = true;
  bool _completedExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadDownloads(showLoading: true);
    _updateSubscription = _downloadManager.downloadUpdateStream.listen((
      update,
    ) {
      _updateProgress(update);
    });
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDownloads({bool showLoading = false}) async {
    if (showLoading && _allDownloads.isEmpty) {
      setState(() => _isLoading = true);
    }
    final downloads = await _dbService.getAllDownloads();
    if (mounted) {
      setState(() {
        _allDownloads = List.from(downloads);
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
      });
    } else {
      _loadDownloads(showLoading: false);
    }
  }

  List<Map<String, dynamic>> get _downloadingList =>
      _allDownloads.where((d) => d['status'] == 1).toList();

  List<Map<String, dynamic>> get _failedList =>
      _allDownloads.where((d) => d['status'] == 4).toList();

  List<Map<String, dynamic>> get _queuedOrPausedList =>
      _allDownloads.where((d) => d['status'] == 0 || d['status'] == 2).toList();

  List<Map<String, dynamic>> get _completedList =>
      _allDownloads.where((d) => d['status'] == 3).toList();

  Future<void> _deleteDownload(String bvid, int cid) async {
    await _downloadManager.deleteDownload(bvid, cid);
    await _loadDownloads(showLoading: false);
  }

  Future<void> _cancelDownload(String bvid, int cid) async {
    await _deleteDownload(bvid, cid);
  }

  Future<void> _retryDownload(String bvid, int cid) async {
    await _downloadManager.retryDownload(bvid, cid);
    await _loadDownloads(showLoading: false);
  }

  Future<void> _retryAllFailed() async {
    final failed = _failedList;
    for (var item in failed) {
      await _downloadManager.retryDownload(item['bvid'], item['cid']);
    }
    await _loadDownloads(showLoading: false);
  }

  Future<void> _pauseDownload(String bvid, int cid) async {
    await _downloadManager.pauseDownload(bvid, cid);
    await _loadDownloads(showLoading: false);
  }

  Future<void> _resumeDownload(String bvid, int cid) async {
    await _downloadManager.resumeDownload(bvid, cid);
    await _loadDownloads(showLoading: false);
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
      await _loadDownloads(showLoading: false);
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
      await _downloadManager.pauseAllDownloads();
      await _loadDownloads(showLoading: false);
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
      await _downloadManager.resumeAllDownloads();
      await _loadDownloads(showLoading: false);
    }
  }

  void _playCompleted(int initialIndex) {
    final completed = _completedList;
    if (completed.isEmpty) return;

    final songs = completed
        .map(
          (d) => Song(
            title: d['title'] ?? '',
            artist: d['artist'] ?? '',
            coverUrl: d['cover_url'] ?? '',
            lyrics: '',
            colorValue: 0,
            bvid: d['bvid'] ?? '',
            cid: d['cid'] ?? 0,
          ),
        )
        .toList();

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
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.of(context).size.height * 0.85;

    final downloading = _downloadingList;
    final failed = _failedList;
    final queuedOrPaused = _queuedOrPausedList;
    final completed = _completedList;

    final bool hasActiveDownloading = downloading.isNotEmpty;
    final bool hasPausedOrQueued = queuedOrPaused.isNotEmpty;

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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_allDownloads.isNotEmpty)
                  TextButton(
                    onPressed: _handleDeleteAll,
                    child: Text(
                      S.of(context).pages_library_download_delete_all,
                    ),
                  ),
                if (hasActiveDownloading)
                  TextButton(
                    onPressed: _handlePauseAll,
                    child: Text(S.of(context).play_control_pause),
                  )
                else if (hasPausedOrQueued)
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
                    ? Center(
                        child: Text(S.of(context).pages_library_download_empty),
                      )
                    : ListView(
                        children: [
                          // 1. 下载中 (Downloading)
                          if (downloading.isNotEmpty)
                            _buildSectionHeader(
                              icon: Icons.downloading,
                              iconColor: Theme.of(context).colorScheme.primary,
                              title: S.of(context).pages_library_download_status_downloading,
                              count: downloading.length,
                              isExpanded: _downloadingExpanded,
                              onToggle: () => setState(() => _downloadingExpanded = !_downloadingExpanded),
                              actionButton: TextButton.icon(
                                onPressed: _handlePauseAll,
                                icon: const Icon(Icons.pause, size: 16),
                                label: Text(S.of(context).play_control_pause),
                              ),
                            ),
                          if (downloading.isNotEmpty && _downloadingExpanded)
                            ...downloading.map((item) => _buildItemTile(item)),

                          // 2. 下载失败 (Failed)
                          if (failed.isNotEmpty)
                            _buildSectionHeader(
                              icon: Icons.error_outline,
                              iconColor: Theme.of(context).colorScheme.error,
                              title: S.of(context).pages_library_download_status_failed,
                              count: failed.length,
                              isExpanded: _failedExpanded,
                              onToggle: () => setState(() => _failedExpanded = !_failedExpanded),
                              actionButton: TextButton.icon(
                                onPressed: _retryAllFailed,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: Text(S.of(context).common_retry),
                              ),
                            ),
                          if (failed.isNotEmpty && _failedExpanded)
                            ...failed.map((item) => _buildItemTile(item)),

                          // 3. 队列中 / 暂停中 (Queued / Paused)
                          if (queuedOrPaused.isNotEmpty)
                            _buildSectionHeader(
                              icon: Icons.schedule,
                              iconColor: Colors.orange,
                              title: S.of(context).pages_library_download_status_queued,
                              count: queuedOrPaused.length,
                              isExpanded: _queuedExpanded,
                              onToggle: () => setState(() => _queuedExpanded = !_queuedExpanded),
                              actionButton: TextButton.icon(
                                onPressed: _handleResumeAll,
                                icon: const Icon(Icons.play_arrow, size: 16),
                                label: Text(S.of(context).play_control_resume),
                              ),
                            ),
                          if (queuedOrPaused.isNotEmpty && _queuedExpanded)
                            ...queuedOrPaused.map((item) => _buildItemTile(item)),

                          // 4. 已下载 (Downloaded)
                          if (completed.isNotEmpty)
                            _buildSectionHeader(
                              icon: Icons.check_circle_outline,
                              iconColor: Colors.green,
                              title: S.of(context).pages_library_download_status_completed,
                              count: completed.length,
                              isExpanded: _completedExpanded,
                              onToggle: () => setState(() => _completedExpanded = !_completedExpanded),
                              actionButton: TextButton.icon(
                                onPressed: () => _playCompleted(0),
                                icon: const Icon(Icons.play_circle_fill, size: 16),
                                label: Text(S.of(context).common_play_all),
                              ),
                            ),
                          if (completed.isNotEmpty && _completedExpanded)
                            ...List.generate(
                              completed.length,
                              (idx) => _buildItemTile(completed[idx], completedIndex: idx),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required int count,
    required bool isExpanded,
    required VoidCallback onToggle,
    Widget? actionButton,
  }) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35),
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
              ),
              const Spacer(),
              if (actionButton != null) actionButton,
              Icon(
                isExpanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
                size: 20,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item, {int? completedIndex}) {
    final status = item['status'] as int;
    final progress = item['progress'] as double? ?? 0.0;
    final title = item['title'] as String;
    final artist = item['artist'] as String;
    final coverUrl = item['cover_url'] as String;
    final quality = item['quality'] as int;
    final bvid = item['bvid'] as String;
    final cid = item['cid'] as int;
    final savePath = item['save_path'] as String? ?? '';

    String statusText = '';
    Widget? trailingInfo;

    if (status == 1) {
      statusText =
          '${S.of(context).pages_library_download_status_downloading}: ${(progress * 100).toInt()}%';
    } else if (status == 0) {
      statusText = S.of(context).pages_library_download_status_queued;
    } else if (status == 2) {
      statusText = S.of(context).play_control_pause;
    } else if (status == 3) {
      statusText = S.of(context).pages_library_download_status_completed;

      // Accurately resolve real file path and length, fixing iOS/LiveContainer 0 B bug
      trailingInfo = FutureBuilder<File?>(
        future: _downloadManager.getRealDownloadFile(
          savePath,
          bvid,
          cid,
          quality,
        ),
        builder: (context, snapshot) {
          final file = snapshot.data;
          int size = 0;
          if (file != null && file.existsSync()) {
            try {
              size = file.lengthSync();
            } catch (_) {}
          }
          if (size <= 0 && item['total_bytes'] != null && (item['total_bytes'] as int) > 0) {
            size = item['total_bytes'] as int;
          }

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
                  QualityUtils.getQualityLabel(context, quality),
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
      key: ValueKey('download_${bvid}_$cid'),
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            statusText,
            style: TextStyle(
              color: status == 1
                  ? Theme.of(context).colorScheme.primary
                  : (status == 4 ? Theme.of(context).colorScheme.error : null),
            ),
          ),
          if (status == 1) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick action buttons
          if (status == 1)
            IconButton(
              icon: const Icon(Icons.pause, size: 20),
              tooltip: S.of(context).play_control_pause,
              onPressed: () => _pauseDownload(bvid, cid),
            )
          else if (status == 2)
            IconButton(
              icon: const Icon(Icons.play_arrow, size: 20),
              tooltip: S.of(context).play_control_resume,
              onPressed: () => _resumeDownload(bvid, cid),
            )
          else if (status == 4)
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: S.of(context).common_retry,
              onPressed: () => _retryDownload(bvid, cid),
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
                case 'pause':
                  _pauseDownload(bvid, cid);
                  break;
                case 'resume':
                  _resumeDownload(bvid, cid);
                  break;
                case 'retry':
                  _retryDownload(bvid, cid);
                  break;
                case 'cancel':
                  _cancelDownload(bvid, cid);
                  break;
                case 'delete':
                  _deleteDownload(bvid, cid);
                  break;
                case 'play':
                  if (completedIndex != null) {
                    _playCompleted(completedIndex);
                  }
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
              if (status == 1)
                PopupMenuItem(
                  value: 'pause',
                  child: Text(S.of(context).play_control_pause),
                ),
              if (status == 2)
                PopupMenuItem(
                  value: 'resume',
                  child: Text(S.of(context).play_control_resume),
                ),
              if (status == 4)
                PopupMenuItem(
                  value: 'retry',
                  child: Text(S.of(context).common_retry),
                ),
              if (status == 1 || status == 0 || status == 2)
                PopupMenuItem(
                  value: 'cancel',
                  child: Text(S.of(context).pages_library_download_action_cancel),
                ),
              if (status == 3 || status == 4)
                PopupMenuItem(
                  value: 'delete',
                  child: Text(S.of(context).pages_library_download_action_delete),
                ),
              if (status == 3)
                PopupMenuItem(
                  value: 'play',
                  child: Text(S.of(context).common_play),
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
      onTap: () {
        if (status == 3 && completedIndex != null) {
          _playCompleted(completedIndex);
        } else if (status == 4) {
          _retryDownload(bvid, cid);
        } else if (status == 2) {
          _resumeDownload(bvid, cid);
        } else if (status == 1) {
          _pauseDownload(bvid, cid);
        }
      },
    );
  }
}
