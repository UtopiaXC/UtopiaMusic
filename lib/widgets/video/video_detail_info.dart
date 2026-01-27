import 'package:flutter/material.dart';
import 'package:utopia_music/services/download_manager.dart';
import 'package:utopia_music/models/song.dart';
import 'package:utopia_music/generated/l10n.dart';

class VideoDetailInfo extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool showPlayButton;
  final VoidCallback? onPlay;
  final VoidCallback? onFav;
  final Function(int)? onOpenSpace;

  const VideoDetailInfo({
    super.key,
    required this.data,
    this.showPlayButton = true,
    this.onPlay,
    this.onFav,
    this.onOpenSpace,
  });

  @override
  State<VideoDetailInfo> createState() => _VideoDetailInfoState();
}

class _VideoDetailInfoState extends State<VideoDetailInfo> {
  bool _isTitleExpanded = false;
  bool _isDescExpanded = false;
  bool _isDownloaded = false;

  @override
  void initState() {
    super.initState();
    _checkDownloadStatus();
  }

  @override
  void didUpdateWidget(VideoDetailInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data['bvid'] != widget.data['bvid'] ||
        oldWidget.data['cid'] != widget.data['cid']) {
      _checkDownloadStatus();
    }
  }

  Future<void> _checkDownloadStatus() async {
    final bvid = widget.data['bvid'] as String? ?? '';
    final cid = widget.data['cid'] as int? ?? 0;
    if (bvid.isNotEmpty) {
      final isDownloaded = await DownloadManager().isDownloaded(bvid, cid);
      if (mounted) {
        setState(() {
          _isDownloaded = isDownloaded;
        });
      }
    }
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

  Future<void> _handleDownload() async {
    if (_isDownloaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).common_downloaded),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).common_confirm_title),
        content: Text(
          S.of(context).weight_video_detail_download_confirm_message,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).common_download),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final data = widget.data;
      final song = Song(
        title: data['title'] ?? '',
        artist: data['owner']?['name'] ?? '',
        coverUrl: data['pic'] ?? '',
        lyrics: '',
        colorValue: 0,
        bvid: data['bvid'] ?? '',
        cid: data['cid'] ?? 0,
      );

      await DownloadManager().startDownload(song);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(S.of(context).weight_video_detail_added_to_download_queue)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final String title = data['title'] ?? '';
    final String desc = data['desc'] ?? '';
    final String pic = data['pic'] ?? '';
    final Map<String, dynamic> stat = data['stat'] ?? {};
    final int view = stat['view'] ?? 0;
    final int danmaku = stat['danmaku'] ?? 0;
    final int pubdate = data['pubdate'] ?? 0;
    final String bvid = data['bvid'] ?? '';
    final Map<String, dynamic> owner = data['owner'] ?? {};
    final String ownerName = owner['name'] ?? 'Unknown';
    final int ownerMid = owner['mid'] ?? 0;

    bool isFav = false;
    if (data['req_user'] != null) {
      isFav = data['req_user']['favorite'] == 1;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  pic,
                  width: 120,
                  height: 75,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 120,
                    height: 75,
                    color: Colors.grey,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _isTitleExpanded = !_isTitleExpanded,
                            ),
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: _isTitleExpanded ? null : 1,
                              overflow: _isTitleExpanded
                                  ? null
                                  : TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(
                            () => _isTitleExpanded = !_isTitleExpanded,
                          ),
                          child: Icon(
                            _isTitleExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => widget.onOpenSpace?.call(ownerMid),
                      behavior: HitTestBehavior.translucent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          ownerName,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _isDescExpanded = !_isDescExpanded,
                            ),
                            child: Text(
                              '${S.of(context).common_intro}：${desc.isEmpty ? "${S.of(context).common_none}" : desc}',
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: _isDescExpanded ? null : 1,
                              overflow: _isDescExpanded
                                  ? null
                                  : TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(
                            () => _isDescExpanded = !_isDescExpanded,
                          ),
                          child: Icon(
                            _isDescExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    onPressed: widget.onFav,
                    icon: Icon(
                      isFav ? Icons.star : Icons.star_border,
                      color: isFav ? Colors.amber : null,
                    ),
                  ),
                  IconButton(
                    onPressed: _handleDownload,
                    icon: Icon(
                      Icons.download,
                      color: _isDownloaded ? Colors.green : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${S.of(context).common_play}: ${_formatNumber(view)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${S.of(context).common_time}: ${_formatDate(pubdate)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${S.of(context).common_danmuku}: ${_formatNumber(danmaku)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            bvid,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.showPlayButton)
                IconButton(
                  onPressed: widget.onPlay,
                  icon: const Icon(Icons.play_circle_fill, size: 40),
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
