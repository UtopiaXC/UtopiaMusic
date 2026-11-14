import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/providers/settings_provider.dart';
import 'package:utopia_music/providers/library_provider.dart';
import 'package:utopia_music/providers/discover_provider.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_category_widget.dart';
import 'package:utopia_music/pages/main/settings/widgets/settings_widgets.dart';
import 'package:utopia_music/generated/l10n.dart';

class AppearanceSettingsPage extends StatelessWidget {
  final bool? isAndroidOverride;
  final bool embedded;

  const AppearanceSettingsPage({
    super.key,
    @visibleForTesting this.isAndroidOverride,
    this.embedded = false,
  });

  bool get _isAndroid => isAndroidOverride ?? (!kIsWeb && Platform.isAndroid);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    final listView = ListView(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      children: [
        SettingsGroup(
          title: S.of(context).pages_settings_appearance_global,
          children: [
            _buildThemeModeItem(context, settingsProvider),
            if (_isAndroid) _buildMonetColorItem(context, settingsProvider),
            _buildColorItem(context, settingsProvider),
            _buildSongListStyleItem(context, settingsProvider),
          ],
        ),
        SettingsGroup(
          title: S.of(context).pages_settings_appearance_pages,
          children: [
            _buildStartPageItem(context, settingsProvider),
            _buildLibraryOrderItem(context),
            _buildDiscoverOrderItem(context),
          ],
        ),
        SettingsGroup(
          title: S.of(context).pages_settings_appearance_player,
          children: [
            _buildPlayerBackgroundItem(context, settingsProvider),
            SwitchListTile(
              title: Text(
                S.of(context).pages_settings_appearance_always_turn_on,
              ),
              subtitle: Text(
                S
                    .of(context)
                    .pages_settings_appearance_always_turn_on_description,
              ),
              value: settingsProvider.lyricsAlwaysOn,
              onChanged: (bool value) {
                settingsProvider.setLyricsAlwaysOn(value);
              },
            ),
          ],
        ),
        SettingsGroup(
          title: S.of(context).pages_settings_appearance_experimental,
          children: [
            SwitchListTile(
              title: Text(S.of(context).pages_settings_appearance_liquid_glass),
              subtitle: Text(
                S.of(context).pages_settings_appearance_liquid_glass_desc,
              ),
              value: settingsProvider.enableLiquidGlass,
              onChanged: settingsProvider.setEnableLiquidGlass,
            ),
          ],
        ),
      ],
    );

    return SettingsFragmentScaffold(
      title: S.of(context).pages_settings_tag_appearance,
      embedded: embedded,
      body: listView,
    );
  }

  Widget _buildThemeModeItem(BuildContext context, SettingsProvider provider) {
    return ListTile(
      title: Text(S.of(context).pages_settings_appearance_dark_mode),
      trailing: DropdownButton<ThemeMode>(
        value: provider.themeMode,
        underline: const SizedBox(),
        alignment: Alignment.centerRight,
        items: [
          DropdownMenuItem(
            value: ThemeMode.system,
            child: Text(
              S.of(context).pages_settings_appearance_dark_mode_system,
            ),
          ),
          DropdownMenuItem(
            value: ThemeMode.light,
            child: Text(
              S.of(context).pages_settings_appearance_dark_mode_light,
            ),
          ),
          DropdownMenuItem(
            value: ThemeMode.dark,
            child: Text(S.of(context).pages_settings_appearance_dark_mode_dark),
          ),
        ],
        onChanged: (value) {
          if (value != null) provider.setThemeMode(value);
        },
      ),
    );
  }

  Widget _buildSongListStyleItem(
    BuildContext context,
    SettingsProvider provider,
  ) {
    return ListTile(
      title: Text(S.of(context).pages_settings_appearance_track_list_style),
      trailing: DropdownButton<SongListStyle>(
        value: provider.songListStyle,
        underline: const SizedBox(),
        alignment: Alignment.centerRight,
        items: [
          DropdownMenuItem(
            value: SongListStyle.cardGrid,
            child: Text(
              S.of(context).pages_settings_appearance_track_list_style_grid,
            ),
          ),
          DropdownMenuItem(
            value: SongListStyle.cardList,
            child: Text(
              S.of(context).pages_settings_appearance_track_list_style_card,
            ),
          ),
          DropdownMenuItem(
            value: SongListStyle.seamlessList,
            child: Text(
              S.of(context).pages_settings_appearance_track_list_style_seamless,
            ),
          ),
        ],
        onChanged: (value) {
          if (value != null) provider.setSongListStyle(value);
        },
      ),
    );
  }

  Widget _buildMonetColorItem(BuildContext context, SettingsProvider provider) {
    final bool isDisabled = provider.enableLiquidGlass;
    return SwitchListTile(
      title: Text(S.of(context).pages_settings_appearance_monet_color),
      subtitle: Text(
        isDisabled
            ? S.of(context).pages_settings_appearance_monet_disabled_by_glass
            : S.of(context).pages_settings_appearance_monet_color_desc,
      ),
      value: provider.enableMonetColor,
      onChanged: isDisabled ? null : provider.setEnableMonetColor,
    );
  }

  Widget _buildColorItem(BuildContext context, SettingsProvider provider) {
    final bool overriddenByMonet = _isAndroid && provider.isMonetColorActive;
    final bool overriddenByGlass = provider.enableLiquidGlass;
    final bool disabled = overriddenByMonet || overriddenByGlass;
    final Color previewColor = overriddenByMonet
        ? Theme.of(context).colorScheme.primary
        : provider.seedColor;

    return ListTile(
      enabled: !disabled,
      title: Text(S.of(context).pages_settings_appearance_theme_color),
      subtitle: overriddenByMonet
          ? Text(S.of(context).pages_settings_appearance_monet_active)
          : (overriddenByGlass
                ? Text(S.of(context).pages_settings_appearance_liquid_glass)
                : null),
      trailing: GestureDetector(
        onTap: disabled ? null : () => _showColorPicker(context, provider),
        child: Opacity(
          opacity: disabled ? 0.45 : 1.0,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: previewColor,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerBackgroundItem(
    BuildContext context,
    SettingsProvider provider,
  ) {
    return ListTile(
      title: Text(S.of(context).pages_settings_appearance_player_background),
      subtitle: Text(
        S.of(context).pages_settings_appearance_player_background_description,
      ),
      trailing: DropdownButton<String>(
        value: provider.playerBackgroundMode,
        underline: const SizedBox(),
        alignment: Alignment.centerRight,
        items: [
          DropdownMenuItem(
            value: 'none',
            child: Text(
              S.of(context).pages_settings_appearance_player_background_none,
            ),
          ),
          DropdownMenuItem(
            value: 'gradient',
            child: Text(
              S
                  .of(context)
                  .pages_settings_appearance_player_background_gradient,
            ),
          ),
          DropdownMenuItem(
            value: 'blur',
            child: Text(
              S.of(context).pages_settings_appearance_player_background_blur,
            ),
          ),
          DropdownMenuItem(
            value: 'gaussian_blur',
            child: Text(
              S
                  .of(context)
                  .pages_settings_appearance_player_background_gaussian_blur,
            ),
          ),
        ],
        onChanged: (value) {
          if (value != null) provider.setPlayerBackgroundMode(value);
        },
      ),
    );
  }

  Widget _buildStartPageItem(BuildContext context, SettingsProvider provider) {
    return ListTile(
      title: Text(S.of(context).pages_settings_appearance_startup_page),
      trailing: DropdownButton<int>(
        value: provider.startPageIndex,
        underline: const SizedBox(),
        alignment: Alignment.centerRight,
        items: [
          DropdownMenuItem(
            value: 0,
            child: Text(
              S.of(context).pages_settings_appearance_startup_page_discover,
            ),
          ),
          DropdownMenuItem(
            value: 1,
            child: Text(
              S.of(context).pages_settings_appearance_startup_page_library,
            ),
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
      title: Text(
        S.of(context).pages_settings_appearance_startup_page_library_order,
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _showLibraryOrderDialog(context),
    );
  }

  Widget _buildDiscoverOrderItem(BuildContext context) {
    return ListTile(
      title: Text(
        S.of(context).pages_settings_appearance_startup_page_discover_order,
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _showDiscoverOrderDialog(context),
    );
  }

  void _showColorPicker(BuildContext context, SettingsProvider provider) {
    Color pickerColor = provider.seedColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).pages_settings_appearance_pickup_color),
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
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () {
              provider.setSeedColor(pickerColor);
              Navigator.pop(context);
            },
            child: Text(S.of(context).common_confirm),
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

class _LibraryOrderDialog extends StatelessWidget {
  const _LibraryOrderDialog();

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
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                child: Text(
                  S
                      .of(context)
                      .pages_settings_appearance_startup_page_library_order,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: Consumer<LibraryProvider>(
                  builder: (context, libraryProvider, child) {
                    return Scrollbar(
                      controller: scrollController,
                      thumbVisibility: false,
                      interactive: true,
                      thickness: 6,
                      radius: const Radius.circular(3),
                      child: ReorderableListView.builder(
                        scrollController: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: libraryProvider.categoryOrder.length,
                        onReorder: libraryProvider.updateOrder,
                        itemBuilder: (context, index) {
                          final type = libraryProvider.categoryOrder[index];
                          final isHidden = libraryProvider.hiddenCategories
                              .contains(type);
                          String title = '';
                          switch (type) {
                            case PlaylistCategoryType.favorites:
                              title = S
                                  .of(context)
                                  .pages_settings_appearance_startup_page_library_order_folder;
                              break;
                            case PlaylistCategoryType.collections:
                              title = S
                                  .of(context)
                                  .pages_settings_appearance_startup_page_library_order_collection;
                              break;
                            case PlaylistCategoryType.local:
                              title = S
                                  .of(context)
                                  .pages_settings_appearance_startup_page_library_order_songlist;
                              break;
                          }
                          return ListTile(
                            key: ValueKey(type),
                            title: Text(
                              title,
                              style: TextStyle(
                                color: isHidden
                                    ? Theme.of(context).disabledColor
                                    : null,
                                decoration: isHidden
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isHidden
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () => _showVisibilityDialog(
                                    context,
                                    libraryProvider,
                                    type,
                                    isHidden,
                                  ),
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
                      child: Text(S.of(context).common_close),
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

  void _showVisibilityDialog(
    BuildContext context,
    LibraryProvider provider,
    PlaylistCategoryType type,
    bool isHidden,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isHidden
              ? S
                    .of(context)
                    .pages_settings_appearance_startup_page_library_order_show
              : S
                    .of(context)
                    .pages_settings_appearance_startup_page_library_order_hide,
        ),
        content: Text(
          isHidden
              ? S
                    .of(context)
                    .pages_settings_appearance_startup_page_library_order_show_ask
              : S
                    .of(context)
                    .pages_settings_appearance_startup_page_library_order_hide_ask,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () {
              provider.toggleCategoryVisibility(type);
              Navigator.pop(dialogContext);
            },
            child: Text(S.of(context).common_confirm),
          ),
        ],
      ),
    );
  }
}

class _DiscoverOrderDialog extends StatelessWidget {
  const _DiscoverOrderDialog();

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
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  S
                      .of(context)
                      .pages_settings_appearance_startup_page_discover_order,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: Consumer<DiscoverProvider>(
                  builder: (context, discoverProvider, child) {
                    return Scrollbar(
                      controller: scrollController,
                      thumbVisibility: false,
                      interactive: true,
                      thickness: 6,
                      radius: const Radius.circular(3),
                      child: ReorderableListView.builder(
                        scrollController: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: discoverProvider.categoryOrder.length,
                        onReorder: discoverProvider.updateOrder,
                        itemBuilder: (context, index) {
                          final type = discoverProvider.categoryOrder[index];
                          final isHidden = discoverProvider.hiddenCategories
                              .contains(type);
                          String title = _getCategoryTitle(context, type);

                          return ListTile(
                            key: ValueKey(type),
                            title: Text(
                              title,
                              style: TextStyle(
                                color: isHidden
                                    ? Theme.of(context).disabledColor
                                    : null,
                                decoration: isHidden
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isHidden
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () => _showVisibilityDialog(
                                    context,
                                    discoverProvider,
                                    type,
                                    isHidden,
                                  ),
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
                      child: Text(S.of(context).common_close),
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
        return S.of(context).common_recommend;
      case DiscoverCategoryType.feed:
        return S.of(context).pages_discover_tag_feed;
      case DiscoverCategoryType.history:
        return S.of(context).common_history;
      case DiscoverCategoryType.subscribe:
        return S.of(context).common_subscribe;
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

  void _showVisibilityDialog(
    BuildContext context,
    DiscoverProvider provider,
    DiscoverCategoryType type,
    bool isHidden,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isHidden
              ? S
                    .of(context)
                    .pages_settings_appearance_startup_page_library_order_show
              : S
                    .of(context)
                    .pages_settings_appearance_startup_page_library_order_hide,
        ),
        content: Text(
          isHidden
              ? S
                    .of(context)
                    .pages_settings_appearance_startup_page_discover_order_show_ask
              : S
                    .of(context)
                    .pages_settings_appearance_startup_page_discover_order_hide_ask,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(S.of(context).common_cancel),
          ),
          TextButton(
            onPressed: () {
              provider.toggleCategoryVisibility(type);
              Navigator.pop(dialogContext);
            },
            child: Text(S.of(context).common_confirm),
          ),
        ],
      ),
    );
  }
}
