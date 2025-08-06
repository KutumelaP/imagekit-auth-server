import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import '../theme/app_theme.dart';

class OptimizedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget? errorWidget;
  final bool enableMemoryCache;
  final Duration fadeInDuration;
  final Duration placeholderFadeInDuration;
  final String? cacheKey;
  final Map<String, String>? httpHeaders;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final FilterQuality filterQuality;

  const OptimizedImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.enableMemoryCache = true,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.placeholderFadeInDuration = const Duration(milliseconds: 300),
    this.cacheKey,
    this.httpHeaders,
    this.memCacheWidth,
    this.memCacheHeight,
    this.filterQuality = FilterQuality.low,
  }) : super(key: key);

      @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildErrorWidget(context);
    }

    // Validate URL format
    try {
      Uri.parse(imageUrl!);
    } catch (e) {
      print('Invalid image URL: $imageUrl');
      return _buildErrorWidget(context);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder ?? (context, url) => _buildPlaceholder(context),
      errorWidget: (context, url, error) {
        print('🖼️ OptimizedImage loading error for $url: $error');
        return _buildErrorWidget(context);
      },
      fadeInDuration: fadeInDuration,
      fadeOutDuration: const Duration(milliseconds: 100),
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      filterQuality: filterQuality,
      cacheKey: cacheKey,
      httpHeaders: {
        'User-Agent': 'Mzansi-Marketplace-App/1.0',
        ...?httpHeaders,
      },
      maxWidthDiskCache: 1024,
      maxHeightDiskCache: 1024,
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.whisper,
            AppTheme.angel.withOpacity(0.5),
          ],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.whisper,
            AppTheme.angel.withOpacity(0.3),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_not_supported,
          color: AppTheme.cloud,
          size: (width != null && height != null) 
              ? (width! < height! ? width! * 0.3 : height! * 0.3).clamp(16.0, 48.0)
              : 32,
        ),
      ),
    );
  }
}

/// Optimized product image with better performance characteristics
class OptimizedProductImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final bool isListItem;

  const OptimizedProductImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.isListItem = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate optimal cache dimensions based on usage
    int? cacheWidth;
    int? cacheHeight;
    
    if (width != null && height != null && 
        width!.isFinite && height!.isFinite && 
        width! > 0 && height! > 0) {
      // Scale down for memory efficiency
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      cacheWidth = (width! * pixelRatio * 0.8).round();
      cacheHeight = (height! * pixelRatio * 0.8).round();
      
      // For list items, use lower resolution to save memory
      if (isListItem) {
        cacheWidth = (cacheWidth * 0.7).round();
        cacheHeight = (cacheHeight * 0.7).round();
      }
    }

    return RepaintBoundary(
      child: OptimizedImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        memCacheWidth: cacheWidth,
        memCacheHeight: cacheHeight,
        filterQuality: isListItem ? FilterQuality.low : FilterQuality.medium,
        fadeInDuration: const Duration(milliseconds: 200),
        cacheKey: imageUrl != null ? '${imageUrl}_${width}_${height}' : null,
      ),
    );
  }
}

/// Hero image with optimized loading for product details
class OptimizedHeroImage extends StatelessWidget {
  final String? imageUrl;
  final String heroTag;
  final double? width;
  final double? height;

  const OptimizedHeroImage({
    Key? key,
    required this.imageUrl,
    required this.heroTag,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: RepaintBoundary(
        child: OptimizedImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          fadeInDuration: const Duration(milliseconds: 150),
          enableMemoryCache: true,
        ),
      ),
    );
  }
}

/// Carousel image with lazy loading
class OptimizedCarouselImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const OptimizedCarouselImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: RepaintBoundary(
        child: OptimizedImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          fadeInDuration: const Duration(milliseconds: 250),
          // Use smaller cache for carousel images
          memCacheWidth: width != null && width!.isFinite && width! > 0 ? (width! * 0.9).round() : null,
          memCacheHeight: height != null && height!.isFinite && height! > 0 ? (height! * 0.9).round() : null,
        ),
      ),
    );
  }
}

/// Image preloader for better user experience
class ImagePreloader {
  static final Map<String, bool> _preloadedImages = {};

  /// Preload images for better performance
  static Future<void> preloadImages(BuildContext context, List<String> imageUrls) async {
    final futures = <Future<void>>[];
    
    for (final url in imageUrls) {
      if (!_preloadedImages.containsKey(url)) {
        futures.add(_preloadSingleImage(context, url));
      }
    }
    
    if (futures.isNotEmpty) {
      try {
        await Future.wait(futures, eagerError: false);
      } catch (e) {
        if (kDebugMode) {
          print('Error preloading images: $e');
        }
      }
    }
  }

  static Future<void> _preloadSingleImage(BuildContext context, String url) async {
    try {
      final imageProvider = CachedNetworkImageProvider(url);
      await precacheImage(imageProvider, context);
      _preloadedImages[url] = true;
    } catch (e) {
      if (kDebugMode) {
        print('Error preloading image $url: $e');
      }
    }
  }

  /// Clear preloaded images cache
  static void clearCache() {
    _preloadedImages.clear();
  }
}

/// Utility for determining optimal image dimensions
class ImageSizeUtils {
  /// Calculate optimal image size for grid items
  static Map<String, double> getOptimalGridImageSize(
    BuildContext context,
    int crossAxisCount,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = 16.0 * 2; // Left and right padding
    final spacing = 8.0 * (crossAxisCount - 1); // Spacing between items
    final itemWidth = (screenWidth - padding - spacing) / crossAxisCount;
    
    return {'width': itemWidth, 'height': itemWidth * 1.2};
  }

  /// Calculate optimal image size for list items
  static Map<String, double> getOptimalListImageSize(
    BuildContext context,
  ) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    return isTablet 
        ? {'width': 120.0, 'height': 120.0}
        : {'width': 80.0, 'height': 80.0};
  }
} 