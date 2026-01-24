import 'package:flutter/material.dart';

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
              // Cover
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
                    // Title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isTitleExpanded = !_isTitleExpanded),
                            child: Text(
                              title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: _isTitleExpanded ? null : 1,
                              overflow: _isTitleExpanded ? null : TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _isTitleExpanded = !_isTitleExpanded),
                          child: Icon(
                            _isTitleExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Author
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
                    // Description
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isDescExpanded = !_isDescExpanded),
                            child: Text(
                              '简介：${desc.isEmpty ? "暂无" : desc}',
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: _isDescExpanded ? null : 1,
                              overflow: _isDescExpanded ? null : TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _isDescExpanded = !_isDescExpanded),
                          child: Icon(
                            _isDescExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 16,
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onFav,
                icon: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav ? Colors.amber : null,
                ),
              ),
            ],
          ),
        ),

        // Metadata and Play Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('播放: ${_formatNumber(view)}', style: Theme.of(context).textTheme.bodySmall)),
                        Expanded(child: Text('时间: ${_formatDate(pubdate)}', style: Theme.of(context).textTheme.bodySmall)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: Text('弹幕: ${_formatNumber(danmaku)}', style: Theme.of(context).textTheme.bodySmall)),
                        Expanded(child: Text(bvid, style: Theme.of(context).textTheme.bodySmall)),
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
