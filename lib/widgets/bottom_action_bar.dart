import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A standardized bottom action bar widget that properly handles safe areas
/// and provides consistent spacing across all platforms including Android browser
class BottomActionBar extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;
  final Border? border;
  final double? height;

  const BottomActionBar({
    super.key,
    required this.children,
    this.padding,
    this.backgroundColor,
    this.boxShadow,
    this.border,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: height,
        padding: padding ?? const EdgeInsets.fromLTRB(16, 16, 16, 24),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          boxShadow: boxShadow ?? [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
          border: border,
        ),
        child: Row(
          children: children,
        ),
      ),
    );
  }
}

/// A standardized action button for the bottom action bar
class ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final bool isPrimary;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const ActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.isPrimary = false,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: height ?? 50,
        child: isPrimary
            ? ElevatedButton.icon(
                onPressed: onPressed,
                icon: icon,
                label: Text(label),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.deepTeal,
                  foregroundColor: Colors.white,
                  padding: padding ?? const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: icon,
                label: Text(label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.deepTeal,
                  side: BorderSide(color: AppTheme.deepTeal, width: 2),
                  padding: padding ?? const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
      ),
    );
  }
}

/// A standardized bottom action bar specifically for product actions
class ProductActionBar extends StatelessWidget {
  final bool isOutOfStock;
  final VoidCallback? onContactSeller;
  final VoidCallback? onBuyNow;
  final VoidCallback? onAddToCart;
  final String? addToCartText;
  final bool showQuantitySelector;

  const ProductActionBar({
    super.key,
    required this.isOutOfStock,
    this.onContactSeller,
    this.onBuyNow,
    this.onAddToCart,
    this.addToCartText,
    this.showQuantitySelector = false,
  });

  @override
  Widget build(BuildContext context) {
    return BottomActionBar(
      children: [
        if (!isOutOfStock) ...[
          if (onContactSeller != null) ...[
            ActionButton(
              onPressed: onContactSeller,
              icon: const Icon(Icons.message),
              label: 'Contact Seller',
              isPrimary: false,
            ),
            const SizedBox(width: 12),
          ],
          if (onBuyNow != null) ...[
            ActionButton(
              onPressed: onBuyNow,
              icon: const Icon(Icons.flash_on),
              label: 'Buy Now',
              isPrimary: true,
            ),
          ] else if (onAddToCart != null) ...[
            ActionButton(
              onPressed: onAddToCart,
              icon: const Icon(Icons.shopping_cart),
              label: addToCartText ?? 'Add to Cart',
              isPrimary: true,
            ),
          ],
        ] else ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.error),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: AppTheme.error),
                  const SizedBox(width: 8),
                  Text(
                    'Out of Stock',
                    style: TextStyle(
                      color: AppTheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
