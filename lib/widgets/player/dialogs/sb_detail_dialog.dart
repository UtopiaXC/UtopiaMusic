import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/models/sponsor_block/segment_model.dart';
import 'package:utopia_music/models/sponsor_block/segment_type.dart';
import 'package:utopia_music/models/sponsor_block/skip_type.dart';
import 'package:utopia_music/providers/sponsor_block_provider.dart';

class SBDetailDialog extends StatelessWidget {
  final Function(Duration) onSeek;

  const SBDetailDialog({
    super.key,
    required this.onSeek,
  });

  String _formatMs(int ms) {
    final dur = Duration(milliseconds: ms);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = dur.inHours;
    final minutes = twoDigits(dur.inMinutes.remainder(60));
    final seconds = twoDigits(dur.inSeconds.remainder(60));
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _showVoteDialog(BuildContext context, SponsorBlockProvider provider, SegmentModel segment) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('投票与修正 - ${segment.segmentType.shortTitle}'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await provider.voteOnSegment(segment, 1);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? '投票成功' : '投票失败')),
                );
              }
            },
            child: const Row(
              children: [
                Icon(Icons.thumb_up_outlined, size: 20),
                SizedBox(width: 12),
                Text('赞成票'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await provider.voteOnSegment(segment, 0);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? '投票成功' : '投票失败')),
                );
              }
            },
            child: const Row(
              children: [
                Icon(Icons.thumb_down_outlined, size: 20),
                SizedBox(width: 12),
                Text('反对票'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showCategoryDialog(context, provider, segment);
            },
            child: const Row(
              children: [
                Icon(Icons.category_outlined, size: 20),
                SizedBox(width: 12),
                Text('更改类别'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryDialog(
    BuildContext context,
    SponsorBlockProvider provider,
    SegmentModel segment,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择新类别'),
        children: SegmentType.values.map((cat) {
          final color = provider.getColor(cat);
          return SimpleDialogOption(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await provider.changeCategory(segment, cat);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? '修改类别成功' : '修改类别失败')),
                );
              }
            },
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Text(cat.title),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SponsorBlockProvider>(context);
    final segments = provider.currentSegments;
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.shield_outlined),
          SizedBox(width: 8),
          Text('空降片段信息'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: segments.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(child: Text('当前曲目无空降片段数据')),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: segments.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final seg = segments[index];
                  final color = provider.getColor(seg.segmentType);
                  final isShowOnly = seg.skipType == SkipType.showOnly;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                    title: Text(
                      seg.segmentType.title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${_formatMs(seg.segment.$1)} 至 ${_formatMs(seg.segment.$2)} · ${seg.skipType.label}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: isShowOnly ? '跳至此片段' : '跳过此片段',
                      icon: Icon(
                        isShowOnly ? Icons.my_location : Icons.skip_next,
                        size: 20,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        final targetMs = isShowOnly ? seg.segment.$1 : seg.segment.$2;
                        onSeek(Duration(milliseconds: targetMs));
                      },
                    ),
                    onTap: () => _showVoteDialog(context, provider, seg),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
