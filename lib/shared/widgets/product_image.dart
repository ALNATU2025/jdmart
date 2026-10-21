import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/constants/catalog.dart';
import 'category_icon.dart';

/// A product photo from Firebase Storage, cached on the device to save mobile
/// data. Listings without photos show the category artwork instead.
class ProductImage extends StatelessWidget {
  final String? url;
  final String categoryId;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final double iconSize;

  const ProductImage({
    super.key,
    required this.url,
    required this.categoryId,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.iconSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    final u = url;
    final Widget child = (u == null || u.isEmpty)
        ? _art()
        : NetImage(url: u, fit: BoxFit.cover, error: _art);
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(width: width, height: height, child: child),
    );
  }

  Widget _art() {
    final c = Catalog.category(categoryId);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.color.withValues(alpha: 0.14), c.color.withValues(alpha: 0.32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -iconSize * 0.4,
            bottom: -iconSize * 0.4,
            child: CategoryIcon(category: c, size: iconSize * 2.2, opacity: 0.12),
          ),
          Center(child: CategoryIcon(category: c, size: iconSize * 1.3)),
        ],
      ),
    );
  }
}

/// Network photo that works everywhere.
/// Phones: cached on the device to save data.
/// Web: if the storage bucket doesn't send CORS headers, the browser shows the
/// photo with a plain <img> element instead of failing.
class NetImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final Widget Function() error;
  const NetImage({super.key, required this.url, this.fit = BoxFit.cover, required this.error});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        url,
        fit: fit,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        frameBuilder: (_, child, frame, sync) => AnimatedOpacity(
          opacity: sync || frame != null ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: child,
        ),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : Container(color: const Color(0xFFF1F3F7)),
        errorBuilder: (_, __, ___) => error(),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(color: const Color(0xFFF1F3F7)),
      errorWidget: (_, __, ___) => error(),
    );
  }
}

/// Image provider for avatars etc. that also works on the web without CORS.
ImageProvider netImageProvider(String url) => kIsWeb
    ? NetworkImage(url, webHtmlElementStrategy: WebHtmlElementStrategy.fallback)
    : CachedNetworkImageProvider(url);
