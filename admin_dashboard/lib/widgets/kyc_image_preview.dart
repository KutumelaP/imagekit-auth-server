import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';

class KycImagePreview extends StatelessWidget {
  final String imageUrl;
  final String label;
  final double thumbnailWidth;
  final double thumbnailHeight;
  final bool showZoomIndicator;
  final VoidCallback? onTap;

  const KycImagePreview({
    super.key,
    required this.imageUrl,
    required this.label,
    this.thumbnailWidth = 160,
    this.thumbnailHeight = 100,
    this.showZoomIndicator = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => _showFullScreenPreview(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AdminTheme.primaryColor.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Image.network(
                    imageUrl,
                    width: thumbnailWidth,
                    height: thumbnailHeight,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: thumbnailWidth,
                        height: thumbnailHeight,
                        color: Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: thumbnailWidth,
                      height: thumbnailHeight,
                      color: Colors.grey[200],
                      child: const Icon(Icons.error, size: 32, color: Colors.red),
                    ),
                  ),
                  if (showZoomIndicator)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AdminTheme.primaryColor.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.zoom_in,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AdminTheme.mediumGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxH = constraints.maxHeight * 0.9;
            final maxW = constraints.maxWidth * 0.9;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH, maxWidth: maxW),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Icon(Icons.error, size: 48, color: Colors.red),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class KycImageGrid extends StatelessWidget {
  final List<KycImageData> images;
  final double thumbnailWidth;
  final double thumbnailHeight;
  final bool showZoomIndicator;

  const KycImageGrid({
    super.key,
    required this.images,
    this.thumbnailWidth = 160,
    this.thumbnailHeight = 100,
    this.showZoomIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: images.map((image) => KycImagePreview(
        imageUrl: image.url,
        label: image.label,
        thumbnailWidth: thumbnailWidth,
        thumbnailHeight: thumbnailHeight,
        showZoomIndicator: showZoomIndicator,
      )).toList(),
    );
  }
}

class KycImageData {
  final String url;
  final String label;

  const KycImageData({
    required this.url,
    required this.label,
  });
}
