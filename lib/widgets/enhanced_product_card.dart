import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../constants/app_constants.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import 'safe_network_image.dart';

class EnhancedProductCard extends StatefulWidget {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String sellerId;
  final String sellerName;
  final double rating;
  final int reviewCount;
  final int? quantity;
  final VoidCallback? onTap;
  final bool showAddToCart;

  const EnhancedProductCard({
    super.key,
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.sellerId,
    required this.sellerName,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.quantity,
    this.onTap,
    this.showAddToCart = true,
  });

  @override
  State<EnhancedProductCard> createState() => _EnhancedProductCardState();
}

class _EnhancedProductCardState extends State<EnhancedProductCard>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isHovered = false;
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  Future<void> _addToCart() async {
    if (_isAddingToCart) return;
    
    // Check if out of stock
    if (widget.quantity != null && widget.quantity! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info, color: Colors.white),
              const SizedBox(width: 8),
              Text('${widget.name} is out of stock'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }
    
    setState(() {
      _isAddingToCart = true;
    });

    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final success = await cartProvider.addItem(
        widget.id,
        widget.name,
        widget.price,
        widget.imageUrl,
        widget.sellerId,
        availableStock: widget.quantity,
      );
      
      if (success) {
      // Show success animation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('${widget.name} added to cart'),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      } else {
        // Show insufficient stock message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 8),
                Text('Insufficient stock for ${widget.name}'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add to cart: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isAddingToCart = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
              child: Container(
                decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Enhanced Product Image Section
                _buildProductImage(),
                
                // Product Information Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      Text(
                        widget.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Seller Info Row
                      Row(
                        children: [
                          Icon(
                            Icons.store_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.sellerName,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Rating Row
                      if (widget.rating > 0 || widget.reviewCount > 0)
                        _buildRatingRow(),
                      
                      // Stock Information
                      if (widget.quantity != null) ...[
                        const SizedBox(height: 8),
                        _buildStockInfo(),
                      ],
                      
                      const SizedBox(height: 12),
                      
                      // Price and Add to Cart Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                          // Price
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              'R${widget.price.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          
                          // Add to Cart Button
                          if (widget.showAddToCart)
                            _buildAddToCartButton(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade100,
            Colors.grey.shade50,
          ],
        ),
                          ),
      child: Stack(
        children: [
          // Product Image
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
                            child: widget.imageUrl.isNotEmpty
                                ? SafeProductImage(
                                    imageUrl: widget.imageUrl,
                      fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    borderRadius: BorderRadius.circular(16),
                                  )
                                : Container(
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                    ),
            ),
          ),
          
          // Gradient Overlay for better text visibility
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.1),
                  ],
                                    ),
                                  ),
                          ),
                        ),
                        
          // Rating Badge (if has rating)
                        if (widget.rating > 0)
                          Positioned(
              top: 12,
              left: 12,
                            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                    Icon(
                                    Icons.star,
                      color: Colors.orange,
                      size: 14,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    widget.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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

  Widget _buildRatingRow() {
    return Row(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            return Icon(
              index < widget.rating.floor() ? Icons.star : Icons.star_outline,
              color: Colors.orange,
              size: 14,
            );
          }),
                                ),
        const SizedBox(width: 6),
        Text(
          '${widget.rating.toStringAsFixed(1)} (${widget.reviewCount})',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
    );
  }

  Widget _buildStockInfo() {
    final quantity = widget.quantity ?? 0;
    final isLowStock = quantity > 0 && quantity <= 5;
    final isOutOfStock = quantity <= 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOutOfStock 
          ? Colors.red.withOpacity(0.1)
          : isLowStock 
            ? Colors.orange.withOpacity(0.1)
            : AppTheme.deepTeal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOutOfStock 
            ? Colors.red.withOpacity(0.3)
            : isLowStock 
              ? Colors.orange.withOpacity(0.3)
              : AppTheme.deepTeal.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
                            children: [
          Icon(
            isOutOfStock 
              ? Icons.remove_shopping_cart
              : isLowStock 
                ? Icons.warning
                : Icons.inventory,
            size: 14,
            color: isOutOfStock 
              ? Colors.red
              : isLowStock 
                ? Colors.orange
                : AppTheme.deepTeal,
                              ),
          const SizedBox(width: 4),
                                Text(
            isOutOfStock
              ? 'Out of Stock'
              : isLowStock
                ? 'Only $quantity left'
                : '$quantity in stock',
                                  style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isOutOfStock 
                ? Colors.red
                : isLowStock 
                  ? Colors.orange
                  : AppTheme.deepTeal,
                                  ),
                                ),
                            ],
                          ),
    );
  }

  Widget _buildAddToCartButton() {
    final isOutOfStock = widget.quantity != null && widget.quantity! <= 0;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOutOfStock
            ? [Colors.grey, Colors.grey.withOpacity(0.8)]
            : [
                AppTheme.deepTeal,
                AppTheme.deepTeal.withOpacity(0.8),
              ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isOutOfStock 
          ? []
          : [
              BoxShadow(
                color: AppTheme.deepTeal.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (_isAddingToCart || isOutOfStock) ? null : _addToCart,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: _isAddingToCart
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOutOfStock 
                          ? Icons.remove_shopping_cart
                          : Icons.add_shopping_cart,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOutOfStock ? 'Sold Out' : 'Add',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }
} 