import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_detail_sheet.dart';
import 'package:utopia_music/pages/main/library/widgets/playlist_form_sheet.dart';
import 'package:utopia_music/providers/discover_provider.dart';
import 'package:utopia_music/providers/library_provider.dart';
import 'package:utopia_music/services/database_service.dart';
import 'package:utopia_music/theme/app_theme.dart';
import 'package:utopia_music/widgets/common/liquid_glass_container.dart';

/// Navigation sidebar modeled after Biu's left desktop navigation column.
class DesktopSidebar extends StatefulWidget {
  final int selectedIndex;
  final DiscoverCategoryType? activeDiscoverCategory;
  final ValueChanged<DiscoverCategoryType> onSelectDiscoverCategory;
  final ValueChanged<int> onSelectMainTab;
  final VoidCallback onOpenDownloads;

  const DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.activeDiscoverCategory,
    required this.onSelectDiscoverCategory,
    required this.onSelectMainTab,
    required this.onOpenDownloads,
  });

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  List<LocalPlaylist> _localPlaylists = const [];
  int _lastLibrarySignal = -1;

  @override
  void initState() {
    super.initState();
    _loadLocalPlaylists();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final signal = Provider.of<LibraryProvider>(context).refreshSignal;
    if (signal != _lastLibrarySignal) {
      _lastLibrarySignal = signal;
      _loadLocalPlaylists();
    }
  }

  Future<void> _loadLocalPlaylists() async {
    try {
      final playlists = await DatabaseService().getLocalPlaylists();
      if (mounted) {
        setState(() {
          _localPlaylists = playlists;
        });
      }
    } catch (_) {
      // Ignore DB startup race in tests or early initialization.
    }
  }

  void _createLocalPlaylist() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => PlaylistFormSheet(
        onSubmit: (title, description) async {
          await DatabaseService().createLocalPlaylist(title, description);
          if (mounted) {
            Provider.of<LibraryProvider>(
              context,
              listen: false,
            ).refreshLibrary(localOnly: true);
          }
        },
      ),
    );
  }

  void _openPlaylist(LocalPlaylist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlaylistDetailSheet(
          playlist: playlist,
          onUpdate: () {
            Provider.of<LibraryProvider>(
              context,
              listen: false,
            ).refreshLibrary(localOnly: true);
          },
        ),
      ),
    );
  }

  IconData _iconForDiscover(DiscoverCategoryType type) {
    switch (type) {
      case DiscoverCategoryType.recommend:
        return Icons.explore_outlined;
      case DiscoverCategoryType.feed:
        return Icons.apps_outlined;
      case DiscoverCategoryType.history:
        return Icons.history;
      case DiscoverCategoryType.subscribe:
        return Icons.people_outline;
      case DiscoverCategoryType.live:
        return Icons.live_tv_outlined;
      case DiscoverCategoryType.rank:
        return Icons.leaderboard_outlined;
      case DiscoverCategoryType.musicRank:
        return Icons.music_note_outlined;
      case DiscoverCategoryType.kichikuRank:
        return Icons.graphic_eq;
    }
  }

  String _titleForDiscover(BuildContext context, DiscoverCategoryType type) {
    switch (type) {
      case DiscoverCategoryType.recommend:
        return S.of(context).pages_discover_category_recommend;
      case DiscoverCategoryType.feed:
        return S.of(context).pages_discover_category_feed;
      case DiscoverCategoryType.history:
        return S.of(context).pages_discover_category_history;
      case DiscoverCategoryType.subscribe:
        return S.of(context).pages_discover_category_subscribe;
      case DiscoverCategoryType.live:
        return S.of(context).pages_discover_category_live;
      case DiscoverCategoryType.rank:
        return S.of(context).pages_discover_category_rank;
      case DiscoverCategoryType.musicRank:
        return S.of(context).pages_discover_category_music_rank;
      case DiscoverCategoryType.kichikuRank:
        return S.of(context).pages_discover_category_kichiku_rank;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isLiquidGlass = AppTheme.isLiquidGlass(context);
    final discoverProvider = Provider.of<DiscoverProvider>(context);
    final categories = discoverProvider.visibleCategories;
    final glass = AppTheme.glassOf(context);

    final sidebarInner = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 16, 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  color: colorScheme.onPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Utopia Music',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            children: [
              _SectionLabel(label: S.of(context).pages_tag_discover),
              ...categories.map((category) {
                final bool isSelected =
                    widget.selectedIndex == 0 &&
                    widget.activeDiscoverCategory == category;
                return _SidebarNavItem(
                  icon: _iconForDiscover(category),
                  label: _titleForDiscover(context, category),
                  selected: isSelected,
                  onTap: () => widget.onSelectDiscoverCategory(category),
                );
              }),
              const SizedBox(height: 12),
              _SectionLabel(label: S.of(context).desktop_sidebar_my_music),
              _SidebarNavItem(
                icon: Icons.library_music_outlined,
                label: S.of(context).pages_tag_library,
                selected: widget.selectedIndex == 1,
                onTap: () => widget.onSelectMainTab(1),
              ),
              _SidebarNavItem(
                icon: Icons.download_outlined,
                label: S.of(context).desktop_sidebar_downloads,
                selected: false,
                onTap: widget.onOpenDownloads,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          S.of(context).desktop_sidebar_playlists,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _createLocalPlaylist,
                        icon: const Icon(Icons.add, size: 17),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 26,
                          minHeight: 26,
                        ),
                        tooltip: S
                            .of(context)
                            .pages_library_category_create_local,
                      ),
                    ],
                  ),
                ),
                if (_localPlaylists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      S.of(context).pages_library_category_empty_local,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  )
                else
                  ..._localPlaylists.map(
                    (playlist) => _SidebarNavItem(
                      icon: Icons.queue_music_rounded,
                      label: playlist.title,
                      selected: false,
                      onTap: () => _openPlaylist(playlist),
                    ),
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isLiquidGlass
                ? glass.borderColor.withValues(alpha: 0.45)
                : colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: _SidebarNavItem(
              icon: Icons.settings_outlined,
              label: S.of(context).pages_tag_settings,
              selected: widget.selectedIndex == 2,
              onTap: () => widget.onSelectMainTab(2),
            ),
          ),
        ],
      );

    if (isLiquidGlass) {
      return LiquidGlassContainer(
        width: 224,
        margin: const EdgeInsets.fromLTRB(10, 10, 0, 10),
        borderRadius: BorderRadius.circular(22),
        highContrastScrim: true,
        refractionStrength: 18.0,
        bezelWidth: 16.0,
        blurSigma: 14.0,
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(22),
          child: sidebarInner,
        ),
      );
    }

    return Container(
      width: 224,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: sidebarInner,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: selected
            ? colorScheme.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            height: 38,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
