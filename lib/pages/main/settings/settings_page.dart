import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/pages/main/settings/fragments/about_settings_page.dart';
import 'package:utopia_music/pages/main/settings/fragments/appearance_settings_page.dart';
import 'package:utopia_music/pages/main/settings/fragments/download_settings_page.dart';
import 'package:utopia_music/pages/main/settings/fragments/general_settings_page.dart';
import 'package:utopia_music/pages/main/settings/fragments/network_settings_page.dart';
import 'package:utopia_music/pages/main/settings/fragments/play_settings_page.dart';
import 'package:utopia_music/pages/main/settings/fragments/search_settings_page.dart';
import 'package:utopia_music/pages/main/settings/fragments/security_settings_page.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/theme/app_theme.dart';
import 'package:utopia_music/widgets/common/liquid_glass_container.dart';
import 'package:utopia_music/widgets/login/login_dialog.dart';
import 'package:utopia_music/widgets/user/space_sheet.dart';

class _SettingsCategory {
  final String title;
  final IconData icon;
  final Widget Function(bool embedded) builder;

  const _SettingsCategory({
    required this.title,
    required this.icon,
    required this.builder,
  });
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const double _desktopBreakpoint = 700.0;
  int _selectedCategoryIndex = 0;

  Future<void> _handleRefresh(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      await authProvider.login();
    }
  }

  List<_SettingsCategory> _buildCategories(BuildContext context) {
    return [
      _SettingsCategory(
        title: S.of(context).pages_settings_tag_appearance,
        icon: Icons.palette_outlined,
        builder: (embedded) => AppearanceSettingsPage(embedded: embedded),
      ),
      _SettingsCategory(
        title: S.of(context).pages_settings_tag_search,
        icon: Icons.search,
        builder: (embedded) => SearchSettingsPage(embedded: embedded),
      ),
      _SettingsCategory(
        title: S.of(context).pages_settings_tag_player,
        icon: Icons.play_circle_outline,
        builder: (embedded) => PlaySettingsPage(embedded: embedded),
      ),
      _SettingsCategory(
        title: S.of(context).pages_settings_tag_download,
        icon: Icons.download_outlined,
        builder: (embedded) => DownloadSettingsPage(embedded: embedded),
      ),
      _SettingsCategory(
        title: S.of(context).pages_settings_tag_network,
        icon: Icons.wifi,
        builder: (embedded) => NetworkSettingsPage(embedded: embedded),
      ),
      _SettingsCategory(
        title: S.of(context).pages_settings_tag_security,
        icon: Icons.security,
        builder: (embedded) => SecuritySettingsPage(embedded: embedded),
      ),
      _SettingsCategory(
        title: S.of(context).pages_settings_tag_general,
        icon: Icons.settings_outlined,
        builder: (embedded) => GeneralSettingsPage(embedded: embedded),
      ),
      _SettingsCategory(
        title: S.of(context).pages_settings_tag_about,
        icon: Icons.info_outline,
        builder: (embedded) => AboutSettingsPage(embedded: embedded),
      ),
    ];
  }

  void _handleUserTap(BuildContext context, AuthProvider authProvider) {
    final userInfo = authProvider.userInfo;
    if (!authProvider.isLoggedIn || userInfo == null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const LoginDialog(),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SpaceSheet(mid: userInfo.mid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _buildCategories(context);
    final int safeIndex = _selectedCategoryIndex.clamp(
      0,
      categories.length - 1,
    );

    return Scaffold(
      backgroundColor: AppTheme.isLiquidGlass(context)
          ? Colors.transparent
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= _desktopBreakpoint) {
            return _buildDesktopLayout(context, categories, safeIndex);
          }
          return _buildMobileLayout(context, categories);
        },
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    List<_SettingsCategory> categories,
  ) {
    return RefreshIndicator(
      onRefresh: () => _handleRefresh(context),
      child: ListView(
        children: [
          const SizedBox(height: 16),
          _buildUserSection(context),
          const SizedBox(height: 16),
          for (final category in categories)
            ListTile(
              leading: Icon(category.icon),
              title: Text(category.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => category.builder(false),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    List<_SettingsCategory> categories,
    int selectedIndex,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isLiquidGlass = AppTheme.isLiquidGlass(context);
    final glass = AppTheme.glassOf(context);
    final Color dividerColor = isLiquidGlass
        ? glass.borderColor
        : colorScheme.outlineVariant.withValues(alpha: 0.35);
    final activeCategory = categories[selectedIndex];

    return Row(
      children: [
        Container(
          width: 256,
          decoration: BoxDecoration(
            color: isLiquidGlass
                ? glass.glassSecondaryTint.withValues(alpha: 0.35)
                : colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
            border: Border(right: BorderSide(color: dividerColor)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                child: _buildDesktopUserCard(context),
              ),
              Divider(height: 1, color: dividerColor),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final item = categories[index];
                    final bool isSelected = index == selectedIndex;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            setState(() {
                              _selectedCategoryIndex = index;
                            });
                          },
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isLiquidGlass
                                        ? glass.highlightColor
                                        : colorScheme.primaryContainer
                                              .withValues(alpha: 0.72))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected && isLiquidGlass
                                  ? Border.all(color: glass.borderColor)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  size: 19,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? colorScheme.onSurface
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 18, 28, 14),
                child: Row(
                  children: [
                    Icon(
                      activeCategory.icon,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      activeCategory.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: dividerColor),
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey<int>(selectedIndex),
                  child: activeCategory.builder(true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopUserCard(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final bool isLiquidGlass = AppTheme.isLiquidGlass(context);
    final bool isLoggedIn = authProvider.isLoggedIn;
    final userInfo = authProvider.userInfo;

    final content = InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _handleUserTap(context, authProvider),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: isLoggedIn && userInfo != null
                  ? NetworkImage(userInfo.avatarUrl)
                  : null,
              child: !isLoggedIn ? const Icon(Icons.person, size: 22) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isLoggedIn && userInfo != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userInfo.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildBadge(
                              'LV${userInfo.level}',
                              _getLevelColor(userInfo.level),
                              Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: _buildBadge(
                                _getVipLabel(context, userInfo.vipType),
                                colorScheme.primaryContainer,
                                colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : const Text(
                      '点击登录',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );

    if (isLiquidGlass) {
      return LiquidGlassContainer(
        borderRadius: BorderRadius.circular(14),
        child: content,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: content,
    );
  }

  Widget _buildBadge(String label, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildUserSection(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoggedIn = authProvider.isLoggedIn;
    final userInfo = authProvider.userInfo;

    return InkWell(
      onTap: () => _handleUserTap(context, authProvider),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: isLoggedIn && userInfo != null
                  ? NetworkImage(userInfo.avatarUrl)
                  : null,
              child: !isLoggedIn ? const Icon(Icons.person, size: 30) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: isLoggedIn && userInfo != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userInfo.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getLevelColor(userInfo.level),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'LV${userInfo.level}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getVipLabel(context, userInfo.vipType),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : const Text(
                      '点击登录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(int level) {
    switch (level) {
      case 0:
      case 1:
        return const Color(0xFFBFBFBF);
      case 2:
        return const Color(0xFF95DDB2);
      case 3:
        return const Color(0xFF92D1E5);
      case 4:
        return const Color(0xFFFFB37C);
      case 5:
        return const Color(0xFFFF6C00);
      case 6:
        return const Color(0xFFFF0000);
      default:
        return const Color(0xFFBFBFBF);
    }
  }

  String _getVipLabel(BuildContext context, UserVipType type) {
    switch (type) {
      case UserVipType.vip:
        return S.of(context).weight_user_space_vip;
      case UserVipType.annualVip:
        return S.of(context).weight_user_space_annual_vip;
      default:
        return S.of(context).weight_user_space_normal;
    }
  }
}
