import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:utopia_music/models/sponsor_block/segment_type.dart';
import 'package:utopia_music/models/sponsor_block/skip_type.dart';
import 'package:utopia_music/pages/sponsor_block/slide_color_picker.dart';
import 'package:utopia_music/providers/sponsor_block_provider.dart';

class SponsorBlockPage extends StatefulWidget {
  const SponsorBlockPage({super.key});

  @override
  State<SponsorBlockPage> createState() => _SponsorBlockPageState();
}

class _SponsorBlockPageState extends State<SponsorBlockPage> {
  static const String _aboutUrl = 'https://github.com/hanydd/BilibiliSponsorBlock';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<SponsorBlockProvider>(context, listen: false);
      if (provider.serverStatus == null) {
        provider.checkServerStatus();
      }
      if (provider.userInfo == null) {
        provider.fetchUserInfo();
      }
    });
  }

  void _showLimitDialog(BuildContext context, SponsorBlockProvider provider) {
    final textController = TextEditingController(text: provider.blockLimit.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('最短片段时长'),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            suffixText: 's',
            hintText: '输入秒数',
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(textController.text);
              if (val != null && val >= 0) {
                provider.setBlockLimit(val);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showUserIdDialog(BuildContext context, SponsorBlockProvider provider) {
    final textController = TextEditingController(text: provider.blockUserID);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('用户ID'),
        content: TextField(
          controller: textController,
          autofocus: true,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '至少30字符长度',
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]+')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await provider.generateAndSetRandomUserId();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('随机'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final text = textController.text.trim();
              if (text.length >= 30) {
                provider.setBlockUserID(text);
                Navigator.of(ctx).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('用户ID要求至少30个字符')),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showServerDialog(BuildContext context, SponsorBlockProvider provider) {
    final textController = TextEditingController(text: provider.blockServer);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('服务器地址'),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://www.bsbsb.top',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              provider.resetBlockServer();
              Navigator.of(ctx).pop();
            },
            child: const Text('重置'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                provider.setBlockServer(text);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showColorPickerDialog(
    BuildContext context,
    SponsorBlockProvider provider,
    SegmentType type,
  ) {
    final currentColor = provider.getColor(type);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: currentColor,
              ),
            ),
            const SizedBox(width: 8),
            Text('设置颜色 - ${type.title}'),
          ],
        ),
        content: SlideColorPicker(
          color: currentColor,
          showResetBtn: true,
          onChanged: (newColor) {
            if (newColor == null) {
              provider.resetCategoryColor(type);
            } else {
              provider.updateCategoryColor(type, newColor);
            }
          },
        ),
      ),
    );
  }

  Widget _buildGroup(BuildContext context, {required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 4.0),
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SponsorBlockProvider>(context);
    final theme = Theme.of(context);

    String statusText;
    Color statusColor;
    if (provider.serverStatus == null) {
      statusText = '检测中...';
      statusColor = theme.colorScheme.outline;
    } else if (provider.serverStatus == true) {
      statusText = '正常';
      statusColor = Colors.green;
    } else {
      statusText = '异常';
      statusColor = theme.colorScheme.error;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('小电视空降助手'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: '更多选项',
            onSelected: (val) {
              if (val == 'reset_categories') {
                provider.resetAllCategoriesToDefault();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已恢复各片段分类的默认跳过设置')),
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'reset_categories',
                child: Text('恢复分类默认设置'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          // 基础设置分组
          _buildGroup(
            context,
            title: '通用设置',
            children: [
              ListTile(
                title: const Text('服务器状态'),
                subtitle: const Text('点击测试与空降助手社区服务器的连接'),
                trailing: Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                onTap: provider.checkServerStatus,
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('最短片段时长'),
                subtitle: const Text('忽略短于此时长的片段'),
                trailing: Text('${provider.blockLimit}s'),
                onTap: () => _showLimitDialog(context, provider),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('显示跳过提示'),
                subtitle: const Text('执行自动跳过时在界面弹出通知提示'),
                value: provider.blockToast,
                onChanged: provider.setBlockToast,
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('跳过次数统计跟踪'),
                subtitle: const Text(
                  '此功能追踪您跳过了哪些片段，向服务器发送跳过统计，帮助社区了解片段被多少人使用。',
                ),
                value: provider.blockTrack,
                onChanged: provider.setBlockTrack,
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('您的贡献与统计'),
                subtitle: provider.isLoadingUserInfo
                    ? const Text('正在加载统计数据...')
                    : Text(provider.userInfo?.toString() ?? '点击获取您的空降助手贡献信息'),
                onTap: provider.fetchUserInfo,
              ),
            ],
          ),

          // 片段分类分组 (11个分类)
          _buildGroup(
            context,
            title: '片段类型与行为',
            children: SegmentType.values.map((type) {
              final skipType = provider.getSkipType(type);
              final color = provider.getColor(type);
              final isDisable = skipType == SkipType.disable;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: GestureDetector(
                      onTap: () => _showColorPickerDialog(context, provider, type),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      type.title,
                      style: TextStyle(
                        color: isDisable ? theme.disabledColor : null,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      type.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDisable ? theme.disabledColor : theme.colorScheme.outline,
                      ),
                    ),
                    trailing: PopupMenuButton<SkipType>(
                      initialValue: skipType,
                      tooltip: '选择行为',
                      onSelected: (val) {
                        provider.updateCategorySkipType(type, val);
                      },
                      itemBuilder: (ctx) => SkipType.values.map((item) {
                        return PopupMenuItem<SkipType>(
                          value: item,
                          child: Text(item.label),
                        );
                      }).toList(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              skipType.label,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDisable
                                    ? theme.disabledColor
                                    : theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (type != SegmentType.values.last) const Divider(height: 1),
                ],
              );
            }).toList(),
          ),

          // 高级与关于分组
          _buildGroup(
            context,
            title: '高级设置',
            children: [
              ListTile(
                title: const Text('用户ID'),
                subtitle: Text(
                  provider.blockUserID.isNotEmpty
                      ? provider.blockUserID
                      : '未生成',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _showUserIdDialog(context, provider),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('服务器地址'),
                subtitle: Text(provider.blockServer),
                onTap: () => _showServerDialog(context, provider),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('关于小电视空降助手'),
                subtitle: const Text(_aboutUrl),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () async {
                  final uri = Uri.parse(_aboutUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
