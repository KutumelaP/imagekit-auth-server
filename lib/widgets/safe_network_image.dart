import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:typed_data';
import '../theme/app_theme.dart';

class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty || !_isValidImageUrl(imageUrl!)) {
      return _buildFallbackImage();
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) {
          if (loadingBuilder != null) {
            // Convert CachedNetworkImage placeholder to old loadingBuilder format
            return loadingBuilder!(context, Container(), null);
          }
          return placeholder ?? _buildLoadingPlaceholder();
        },
        errorWidget: (context, url, error) {
          if (errorBuilder != null) {
            return errorBuilder!(context, error, StackTrace.current);
          }
          print('🖼️ CachedNetworkImage failed for $url: $error');
          // Try direct network download as fallback
          return _buildDirectDownloadImage();
        },
        memCacheWidth: width != null && width!.isFinite ? width!.toInt() : null,
        memCacheHeight: height != null && height!.isFinite ? height!.toInt() : null,
        httpHeaders: const {
          'User-Agent': 'Mzansi-Marketplace-App/1.0',
        },
        maxWidthDiskCache: 1024,
        maxHeightDiskCache: 1024,
        cacheKey: _generateCacheKey(imageUrl!),
      ),
    );
  }

  Widget _buildDirectDownloadImage() {
    return FutureBuilder<Uint8List?>(
      future: _downloadImageDirectly(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingPlaceholder();
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          return ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.zero,
            child: Image.memory(
              snapshot.data!,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) {
                print('🖼️ Even direct download failed: $error');
                return errorWidget ?? _buildFallbackImage();
              },
            ),
          );
        }
        
        // If direct download failed, try reliable placeholder
        return _buildReliablePlaceholder();
      },
    );
  }

  Future<Uint8List?> _downloadImageDirectly() async {
    try {
      print('🔄 Attempting direct download of: $imageUrl');
      
      final response = await http.get(
        Uri.parse(imageUrl!),
        headers: {
          'User-Agent': 'Mzansi-Marketplace-App/1.0',
          'Accept': 'image/*',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        print('✅ Direct download successful for: $imageUrl');
        return response.bodyBytes;
      } else {
        print('❌ Direct download failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Direct download error: $e');
      return null;
    }
  }

  Widget _buildReliablePlaceholder() {
    // Use a reliable placeholder image from a CDN
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: _getReliablePlaceholderUrl(),
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _buildLoadingPlaceholder(),
        errorWidget: (context, url, error) {
          print('🖼️ Even placeholder image failed: $error');
          return errorWidget ?? _buildFallbackImage();
        },
        httpHeaders: const {
          'User-Agent': 'Mzansi-Marketplace-App/1.0',
        },
        cacheKey: _generateCacheKey(_getReliablePlaceholderUrl()),
      ),
    );
  }

  String _getReliablePlaceholderUrl() {
    final placeholders = [
      'https://via.placeholder.com/400x300/2E7D32/FFFFFF?text=Product+Image',
      'https://via.placeholder.com/400x300/1976D2/FFFFFF?text=Store+Image',
      'https://via.placeholder.com/400x300/7B1FA2/FFFFFF?text=Image',
      'https://via.placeholder.com/400x300/FF8F00/FFFFFF?text=Loading...',
    ];
    final hash = imageUrl?.hashCode ?? 0;
    final index = hash.abs() % placeholders.length;
    return placeholders[index];
  }

  String _generateCacheKey(String url) {
    // Create a unique cache key based on URL and dimensions
    final widthInt = width != null && width!.isFinite ? width!.toInt() : 0;
    final heightInt = height != null && height!.isFinite ? height!.toInt() : 0;
    final key = '${url}_${widthInt}x${heightInt}';
    return key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  bool _isValidImageUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.cloud,
        borderRadius: borderRadius ?? BorderRadius.zero,
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.cloud,
        borderRadius: borderRadius ?? BorderRadius.zero,
      ),
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          color: AppTheme.deepTeal,
          size: 40,
        ),
      ),
    );
  }
}

// Specialized widgets for different image types
class SafeProductImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final BorderRadius? borderRadius;

  const SafeProductImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return SafeNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
    );
  }
}

class SafeStoreImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final BorderRadius? borderRadius;

  const SafeStoreImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return SafeNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
    );
  }
} 