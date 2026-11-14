import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:utopia_music/generated/l10n.dart';
import 'package:utopia_music/models/live_room.dart';
import 'package:utopia_music/providers/player_provider.dart';
import 'package:utopia_music/widgets/common/cached_cover_image.dart';
import 'package:utopia_music/widgets/common/liquid_glass_container.dart';

class LiveRoomCard extends StatelessWidget {
  final LiveRoom room;
  final VoidCallback? onTap;

  const LiveRoomCard({super.key, required this.room, this.onTap});

  static SliverGridDelegate gridDelegateForWidth(double width) {
    final int columns = width < 600 ? 2 : (width / 230).floor().clamp(2, 6);
    const double horizontalPadding = 12;
    const double crossSpacing = 10;
    final double itemWidth =
        (width - horizontalPadding * 2 - crossSpacing * (columns - 1)) /
        columns;
    final double mainAxisExtent = (itemWidth / 1.6) + 82;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: crossSpacing,
      mainAxisSpacing: 10,
      mainAxisExtent: mainAxisExtent,
    );
  }

  String _formatOnline(BuildContext context, int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}${S.of(context).number_ten_thousand}';
    }
    return count.toString();
  }

  void _defaultTap(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    playerProvider.playLiveRoom(room);
    playerProvider.expandPlayer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LiquidGlassSurface(
      fallbackColor: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? () => _defaultTap(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedCoverImage(
                    imageUrl: room.cover,
                    fit: BoxFit.cover,
                    sizeSuffix: '@640w_400h.webp',
                    placeholderColor: colorScheme.primaryContainer,
                  ),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.error.withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        S.of(context).live_badge_live,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  if (room.online > 0)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.visibility_outlined,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _formatOnline(context, room.online),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (room.isFollowed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              S.of(context).live_badge_followed,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            room.uname,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (room.areaName.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              room.areaName,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.outline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
