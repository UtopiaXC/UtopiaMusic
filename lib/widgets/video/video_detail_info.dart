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
      final pages = widget.data['pages'];
      if (pages is List && pages.length > 1) {
        bool allDownloaded = true;
        for (final p in pages) {
          final pCid = p['cid'] as int? ?? 0;
          if (!await DownloadManager().isDownloaded(bvid, pCid)) {
            allDownloaded = false;
            break;
          }
        }
        if (mounted) {
          setState(() {
            _isDownloaded = allDownloaded;
          });
        }
      } else {
        final isDownloaded = await DownloadManager().isDownloaded(bvid, cid);
        if (mounted) {
          setState(() {
            _isDownloaded = isDownloaded;
          });
        }
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
    final pages = widget.data['pages'];
    if (pages is List && pages.length > 1) {
      await _showMultiPartDownloadSheet(context, pages, widget.data);
      return;
    }

    if (_isDownloaded) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.of(context).common_downloaded)));
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
      _checkDownloadStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              S.of(context).weight_video_detail_added_to_download_queue,
            ),
          ),
        );
      }
    }
  }

  Future<void> _showMultiPartDownloadSheet(
    BuildContext context,
    List<dynamic> pages,
    Map<String, dynamic> data,
  ) async {
    final bvid = data['bvid'] ?? '';
    final title = data['title'] ?? '';
    final artist = data['owner']?['name'] ?? '';
    final coverUrl = data['pic'] ?? '';

    final Set<int> downloadedCids = {};
    for (final p in pages) {
      final cid = p['cid'] as int? ?? 0;
      if (await DownloadManager().isDownloaded(bvid, cid)) {
        downloadedCids.add(cid);
      }
    }

    if (!mounted) return;

    final Set<int> selectedCids = {};
    for (final p in pages) {
      final cid = p['cid'] as int? ?? 0;
      if (!downloadedCids.contains(cid)) {
        selectedCids.add(cid);
      }
    }
    if (selectedCids.isEmpty) {
      selectedCids.addAll(pages.map((p) => p['cid'] as int? ?? 0));
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final allSelected = selectedCids.length == pages.length;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.download),
                        const SizedBox(width: 8),
                        Text(
                          '下载分P (${selectedCids.length}/${pages.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              if (allSelected) {
                                selectedCids.clear();
                              } else {
                                selectedCids.clear();
                                selectedCids.addAll(pages.map((p) => p['cid'] as int? ?? 0));
                              }
                            });
                          },
                          child: Text(allSelected ? '取消全选' : '全选'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: pages.length,
                      itemBuilder: (context, index) {
                        final page = pages[index];
                        final pageCid = page['cid'] as int? ?? 0;
                        final pageNum = page['page'] ?? (index + 1);
                        final partTitle = page['part'] ?? '';
                        final isDownloaded = downloadedCids.contains(pageCid);
                        final isSelected = selectedCids.contains(pageCid);

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) {
                            setSheetState(() {
                              if (val == true) {
                                selectedCids.add(pageCid);
                              } else {
                                selectedCids.remove(pageCid);
                              }
                            });
                          },
                          title: Text(
                            'P$pageNum $partTitle',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDownloaded
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                          subtitle: isDownloaded
                              ? Text(
                                  S.of(context).common_downloaded,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                )
                              : null,
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: selectedCids.isEmpty
                            ? null
                            : () async {
                                Navigator.pop(sheetContext);
                                int queuedCount = 0;
                                for (final page in pages) {
                                  final pageCid = page['cid'] as int? ?? 0;
                                  if (selectedCids.contains(pageCid)) {
                                    final pageNum = page['page'] ?? 1;
                                    final partTitle = page['part'] ?? '';
                                    final song = Song(
                                      title: '$title - ${pageNum}P $partTitle',
                                      artist: artist,
                                      coverUrl: coverUrl,
                                      lyrics: '',
                                      colorValue: 0,
                                      bvid: bvid,
                                      cid: pageCid,
                                    );
                                    await DownloadManager().startDownload(song);
                                    queuedCount++;
                                  }
                                }
                                _checkDownloadStatus();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '已添加 $queuedCount 个分P到下载队列',
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: Text(
                          selectedCids.isEmpty
                              ? '请选择要下载的分P'
                              : '下载选中 (${selectedCids.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
