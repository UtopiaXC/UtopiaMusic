import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CachedCoverImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? placeholderColor;
  final String? sizeSuffix;

  const CachedCoverImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.placeholderColor,
    this.sizeSuffix,
  });

  factory CachedCoverImage.small({
    Key? key,
    required String imageUrl,
    double size = 48,
    BorderRadius? borderRadius,
    Color? placeholderColor,
  }) {
    return CachedCoverImage(
      key: key,
      imageUrl: imageUrl,
      width: size,
      height: size,
      borderRadius: borderRadius ?? BorderRadius.circular(4),
      sizeSuffix: '@100w_100h.webp',
      placeholderColor: placeholderColor,
    );
  }

  factory CachedCoverImage.medium({
    Key? key,
    required String imageUrl,
    double size = 120,
    BorderRadius? borderRadius,
    Color? placeholderColor,
  }) {
    return CachedCoverImage(
      key: key,
      imageUrl: imageUrl,
      width: size,
      height: size,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      sizeSuffix: '@200w_200h.webp',
      placeholderColor: placeholderColor,
    );
  }

  factory CachedCoverImage.large({
    Key? key,
    required String imageUrl,
    double? width,
    double? height,
    BorderRadius? borderRadius,
    Color? placeholderColor,
  }) {
    return CachedCoverImage(
      key: key,
      imageUrl: imageUrl,
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      sizeSuffix: '@600w_600h.webp',
      placeholderColor: placeholderColor,
    );
  }

  String get _optimizedUrl {
    if (imageUrl.isEmpty) return '';
    if (sizeSuffix != null && sizeSuffix!.isNotEmpty) {
      return '$imageUrl$sizeSuffix';
    }
    return imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildPlaceholder(context);
    }

    Widget image = CachedNetworkImage(
      imageUrl: _optimizedUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => _buildPlaceholder(context),
      errorWidget: (context, url, error) =>
          errorWidget ?? _buildErrorWidget(context),
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: const Duration(milliseconds: 150),
      memCacheWidth: width != null ? (width! * 2).toInt() : null,
      memCacheHeight: height != null ? (height! * 2).toInt() : null,
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (placeholder != null) return placeholder!;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color:
            placeholderColor ??
            Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Icon(
          Icons.music_note,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: (width ?? 48) * 0.5,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color:
            placeholderColor ??
            Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Icon(
          Icons.broken_image,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: (width ?? 48) * 0.4,
        ),
      ),
    );
  }
}
