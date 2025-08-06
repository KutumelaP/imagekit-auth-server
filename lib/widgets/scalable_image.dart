import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

/// A scalable image widget optimized for large inventories
class ScalableImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableLazyLoading;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const ScalableImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.enableLazyLoading = true,
    this.memCacheWidth,
    this.memCacheHeight,
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

    // For now, return placeholder to prevent crashes
    // This will be replaced with proper image loading when the decoding issue is resolved
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.whisper,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              color: AppTheme.cloud,
              size: width != null && height != null 
                  ? (width! < height! ? width! * 0.15 : height! * 0.15).clamp(16.0, 24.0)
                  : 20,
            ),
            const SizedBox(height: 4),
            Text(
              'Product',
              style: TextStyle(
                color: AppTheme.cloud,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.whisper,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          Icons.image_not_supported,
          color: AppTheme.cloud,
          size: width != null && height != null 
              ? (width! < height! ? width! * 0.2 : height! * 0.2).clamp(16.0, 32.0)
              : 24,
        ),
      ),
    );
  }
}

/// Optimized product grid for large inventories
class ScalableProductGrid extends StatelessWidget {
  final List<dynamic> products;
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  const ScalableProductGrid({
    Key? key,
    required this.products,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.75,
    this.crossAxisSpacing = 10,
    this.mainAxisSpacing = 10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(context, product);
      },
    );
  }

  Widget _buildProductCard(BuildContext context, dynamic product) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: ScalableImage(
              imageUrl: product['imageUrl'] ?? product['image'],
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? 'Product',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'R${product['price']?.toString() ?? '0.00'}',
                    style: TextStyle(
                      color: AppTheme.deepTeal,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 