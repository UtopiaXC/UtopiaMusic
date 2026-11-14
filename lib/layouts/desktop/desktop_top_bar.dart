import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/providers/auth_provider.dart';
import 'package:utopia_music/theme/app_theme.dart';
import 'package:utopia_music/widgets/common/liquid_glass_container.dart';
import 'package:utopia_music/widgets/login/login_dialog.dart';
import 'package:utopia_music/widgets/user/space_sheet.dart';

/// Top header bar for desktop layout with search capsule and user profile pill.
class DesktopTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onOpenSearch;

  const DesktopTopBar({
    super.key,
    required this.title,
    required this.onOpenSearch,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authProvider = Provider.of<AuthProvider>(context);
    final bool isLiquidGlass = AppTheme.isLiquidGlass(context);
    final glass = AppTheme.glassOf(context);

    final Color capsuleBg = isLiquidGlass
        ? glass.glassTint
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final Color capsuleBorder = isLiquidGlass
        ? glass.borderColor
        : colorScheme.outlineVariant.withValues(alpha: 0.35);

    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLiquidGlass
                ? glass.borderColor.withValues(alpha: 0.5)
                : colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: InkWell(
                  onTap: onOpenSearch,
                  borderRadius: BorderRadius.circular(20),
                  child: isLiquidGlass
                      ? LiquidGlassContainer(
                          height: 38,
                          borderRadius: BorderRadius.circular(19),
                          refractionStrength: 18.0,
                          bezelWidth: 15.0,
                          blurSigma: 12.0,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                size: 18,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  S.of(context).pages_search_hint_search_input,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: capsuleBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: capsuleBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                size: 18,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  S.of(context).pages_search_hint_search_input,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _UserPill(authProvider: authProvider),
        ],
      ),
    );
  }
}

class _UserPill extends StatelessWidget {
  final AuthProvider authProvider;

  const _UserPill({required this.authProvider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final userInfo = authProvider.userInfo;
    final bool isLoggedIn = authProvider.isLoggedIn && userInfo != null;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (isLoggedIn) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => SpaceSheet(mid: userInfo.mid),
            );
          } else {
            showDialog(
              context: context,
              builder: (context) => const LoginDialog(),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: (isLoggedIn && userInfo.avatarUrl.isNotEmpty)
                    ? NetworkImage(userInfo.avatarUrl)
                    : null,
                child: (!isLoggedIn || userInfo.avatarUrl.isEmpty)
                    ? Icon(
                        Icons.person_outline,
                        size: 16,
                        color: colorScheme.onPrimaryContainer,
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  isLoggedIn
                      ? userInfo.name
                      : S.of(context).pages_library_category_login,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
