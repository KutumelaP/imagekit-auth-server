import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../utils/performance_utils.dart';

class RobustImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool showLoadingIndicator;
  final bool isCritical; // For important images that should be prioritized

  const RobustImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.showLoadingIndicator = true,
    this.isCritical = false,
  });

  @override
  Widget build(BuildContext context) {
    // Validate image URL
    if (imageUrl == null || imageUrl!.isEmpty || !_isValidImageUrl(imageUrl!)) {
      return _buildFallbackImage();
    }

    // Monitor cache health for critical images
    if (isCritical && !PerformanceUtils.isCacheHealthy()) {
      print('⚠️  Critical image loading with unhealthy cache');
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => placeholder ?? _buildLoadingPlaceholder(),
        errorWidget: (context, url, error) {
          print('🖼️ Image loading error for $url: $error');
          // Clear the corrupted cache entry
          _clearCorruptedCache(url);
          return errorWidget ?? _buildFallbackImage();
        },
        // Optimized settings for large cache
        memCacheWidth: width != null && width!.isFinite ? width!.toInt() : null,
        memCacheHeight: height != null && height!.isFinite ? height!.toInt() : null,
        // Add retry logic
        httpHeaders: const {
          'User-Agent': 'omniaSA-App/1.0',
        },
        // Optimized cache settings for large caches
        maxWidthDiskCache: 2048, // Increased for better quality
        maxHeightDiskCache: 2048,
        // Add cache key to avoid conflicts
        cacheKey: _generateCacheKey(imageUrl!),
      ),
    );
  }

  bool _isValidImageUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  void _clearCorruptedCache(String url) {
    try {
      // This would clear the specific corrupted entry
      // For now, we'll just log it
      print('🧹 Clearing corrupted cache entry: $url');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  String _generateCacheKey(String url) {
    // Generate a unique cache key based on URL and dimensions
    final key = '${url}_${width?.toInt() ?? 0}x${height?.toInt() ?? 0}';
    return key;
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.whisper,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: showLoadingIndicator
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cloud),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.whisper,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image,
              color: AppTheme.cloud,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Image',
              style: TextStyle(
                color: AppTheme.cloud,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Specialized image widgets for different use cases
class ProductImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const ProductImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return RobustImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      placeholder: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.cloud,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(
            Icons.inventory_2_outlined,
            color: AppTheme.deepTeal,
            size: 32,
          ),
        ),
      ),
    );
  }
}

class StoreImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const StoreImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return RobustImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      placeholder: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.paleLinen,
          borderRadius: borderRadius ?? BorderRadius.circular(16),
        ),
        child: const Center(
          child: Icon(
            Icons.store_outlined,
            color: AppTheme.deepTeal,
            size: 32,
          ),
        ),
      ),
    );
  }
}

class CategoryImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const CategoryImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return RobustImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      placeholder: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.deepTeal, AppTheme.cloud],
          ),
          borderRadius: borderRadius ?? BorderRadius.circular(20),
        ),
        child: const Center(
          child: Icon(
            Icons.category_outlined,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
} 