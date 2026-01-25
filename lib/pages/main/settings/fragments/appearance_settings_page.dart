import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/providers/library_provider.dart';
import 'package:utopia_music/providers/discover_provider.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_category_widget.dart';
import 'package:utopia_music/generated/l10n.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('外观')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          _SettingsGroup(
            title: '全局',
            children: [
              _buildThemeModeItem(context, settingsProvider),
              _buildColorItem(context, settingsProvider),
            ],
          ),
          _SettingsGroup(
            title: '页面',
            children: [
              _buildStartPageItem(context, settingsProvider),
              _buildLibraryOrderItem(context),
              _buildDiscoverOrderItem(context),
            ],
          ),
          _SettingsGroup(
            title: '播放器',
            children: [
              _buildBlurBackgroundItem(context, settingsProvider),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeItem(BuildContext context, SettingsProvider provider) {
    return ListTile(
      title: const Text('深色模式'),
      trailing: DropdownButton<ThemeMode>(
        value: provider.themeMode,
        underline: const SizedBox(),
        alignment: Alignment.centerRight,
        items: const [
          DropdownMenuItem(
            value: ThemeMode.system,
            child: Text('跟随系统'),
          ),
          DropdownMenuItem(
            value: ThemeMode.light,
            child: Text('始终浅色'),
          ),
          DropdownMenuItem(
            value: ThemeMode.dark,
            child: Text('始终深色'),
          ),
        ],
        onChanged: (value) {
          if (value != null) provider.setThemeMode(value);
        },
      ),
    );
  }

  Widget _buildColorItem(BuildContext context, SettingsProvider provider) {
    return ListTile(
      title: const Text('主题颜色'),
      trailing: GestureDetector(
        onTap: () => _showColorPicker(context, provider),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: provider.seedColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlurBackgroundItem(BuildContext context, SettingsProvider provider) {
    return SwitchListTile(
      title: const Text('播放器高斯模糊'),
      subtitle: const Text('非常费电，非常卡顿，非常好看'),
      value: provider.enableBlurBackground,
      onChanged: (value) => provider.setEnableBlurBackground(value),
    );
  }

  Widget _buildStartPageItem(BuildContext context, SettingsProvider provider) {
    return ListTile(
      title: const Text('启动页'),
      trailing: DropdownButton<int>(
        value: provider.startPageIndex,
        underline: const SizedBox(),
        alignment: Alignment.centerRight,
        items: const [
          DropdownMenuItem(
            value: 0,
            child: Text('首页'),
          ),
          DropdownMenuItem(
            value: 1,
            child: Text('曲库'),
          ),
        ],
        onChanged: (value) {
          if (value != null) provider.setStartPageIndex(value);
        },
      ),
    );
  }

  Widget _buildLibraryOrderItem(BuildContext context) {
    return ListTile(
      title: const Text('曲库页面排序与显示'),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _showLibraryOrderDialog(context),
    );
  }

  Widget _buildDiscoverOrderItem(BuildContext context) {
    return ListTile(
      title: const Text('发现页面排序与显示'),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _showDiscoverOrderDialog(context),
    );
  }

  void _showColorPicker(BuildContext context, SettingsProvider provider) {
    Color pickerColor = provider.seedColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择颜色'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) {
              pickerColor = color;
            },
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
            displayThumbColor: true,
            paletteType: PaletteType.hsvWithHue,
            labelTypes: const [],
            pickerAreaBorderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2.0),
              topRight: Radius.circular(2.0),
            ),
            hexInputBar: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              provider.setSeedColor(pickerColor);
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showLibraryOrderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _LibraryOrderDialog(),
    );
  }

  void _showDiscoverOrderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _DiscoverOrderDialog(),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
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
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// 1. 修正后的 _LibraryOrderDialog 类
class _LibraryOrderDialog extends StatelessWidget {
  const _LibraryOrderDialog({super.key});

  @override
  Widget build(BuildContext context) {
    // ScrollController 必须由 Scrollbar 和 ReorderableListView 共享
    final scrollController = ScrollController();

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                child: Text(
                  '曲库页面排序与显示',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: Consumer<LibraryProvider>(
                  builder: (context, libraryProvider, child) {
                    return Scrollbar(
                      controller: scrollController,
                      thumbVisibility: true,
                      child: ReorderableListView.builder(
                        // 【修正】这里参数名是 scrollController，不是 controller
                        scrollController: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: libraryProvider.categoryOrder.length,
                        onReorder: libraryProvider.updateOrder,
                        itemBuilder: (context, index) {
                          final type = libraryProvider.categoryOrder[index];
                          final isHidden = libraryProvider.hiddenCategories.contains(type);
                          String title = '';
                          switch (type) {
                            case PlaylistCategoryType.favorites:
                              title = '收藏夹';
                              break;
                            case PlaylistCategoryType.collections:
                              title = '合集';
                              break;
                            case PlaylistCategoryType.local:
                              title = '本地歌单';
                              break;
                          }
                          return ListTile(
                            key: ValueKey(type),
                            title: Text(
                              title,
                              style: TextStyle(
                                color: isHidden ? Theme.of(context).disabledColor : null,
                                decoration: isHidden ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(isHidden ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => _showVisibilityDialog(context, libraryProvider, type, isHidden),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.drag_handle),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVisibilityDialog(BuildContext context, LibraryProvider provider, PlaylistCategoryType type, bool isHidden) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isHidden ? '显示控件' : '隐藏控件'),
        content: Text(isHidden ? '是否在曲库中恢复显示该控件？' : '是否在曲库中隐藏该控件？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              provider.toggleCategoryVisibility(type);
              Navigator.pop(dialogContext);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

// 2. 修正后的 _DiscoverOrderDialog 类
class _DiscoverOrderDialog extends StatelessWidget {
  const _DiscoverOrderDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '发现页面排序与显示',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: Consumer<DiscoverProvider>(
                  builder: (context, discoverProvider, child) {
                    return Scrollbar(
                      controller: scrollController,
                      thumbVisibility: true,
                      child: ReorderableListView.builder(
                        // 【修正】这里参数名是 scrollController，不是 controller
                        scrollController: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: discoverProvider.categoryOrder.length,
                        onReorder: discoverProvider.updateOrder,
                        itemBuilder: (context, index) {
                          final type = discoverProvider.categoryOrder[index];
                          final isHidden = discoverProvider.hiddenCategories.contains(type);
                          String title = _getCategoryTitle(context, type);

                          return ListTile(
                            key: ValueKey(type),
                            title: Text(
                              title,
                              style: TextStyle(
                                color: isHidden ? Theme.of(context).disabledColor : null,
                                decoration: isHidden ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(isHidden ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => _showVisibilityDialog(context, discoverProvider, type, isHidden),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.drag_handle),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCategoryTitle(BuildContext context, DiscoverCategoryType type) {
    switch (type) {
      case DiscoverCategoryType.recommend:
        return S.of(context).pages_discover_tag_recommend;
      case DiscoverCategoryType.feed:
        return S.of(context).pages_discover_tag_feed;
      case DiscoverCategoryType.history:
        return '历史';
      case DiscoverCategoryType.subscribe:
        return '关注';
      case DiscoverCategoryType.live:
        return S.of(context).pages_discover_tag_live;
      case DiscoverCategoryType.rank:
        return S.of(context).pages_discover_tag_ranking;
      case DiscoverCategoryType.musicRank:
        return S.of(context).pages_discover_tag_ranking_category_music;
      case DiscoverCategoryType.kichikuRank:
        return S.of(context).pages_discover_tag_ranking_category_kichiku;
    }
  }

  void _showVisibilityDialog(BuildContext context, DiscoverProvider provider, DiscoverCategoryType type, bool isHidden) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isHidden ? '显示控件' : '隐藏控件'),
        content: Text(isHidden ? '是否在发现页中恢复显示该控件？' : '是否在发现页中隐藏该控件？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              provider.toggleCategoryVisibility(type);
              Navigator.pop(dialogContext);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}