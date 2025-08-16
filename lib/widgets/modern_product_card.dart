import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'safe_network_image.dart';

class ModernProductCard extends StatefulWidget {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String sellerName;
  final double rating;
  final int reviewCount;
  final bool showAddToCart;
  final VoidCallback? onTap;
  final Color? accentColor;

  const ModernProductCard({
    Key? key,
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.sellerName,
    required this.rating,
    required this.reviewCount,
    this.showAddToCart = true,
    this.onTap,
    this.accentColor,
  }) : super(key: key);

  @override
  State<ModernProductCard> createState() => _ModernProductCardState();
}

class _ModernProductCardState extends State<ModernProductCard>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _hoverController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _hoverAnimation;
  bool _isHovered = false;
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
    
    _hoverAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );
    
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    
    if (isHovered) {
      _hoverController.forward();
    } else {
      _hoverController.reverse();
    }
  }

  Future<void> _addToCart() async {
    if (_isAddingToCart) return;
    
    setState(() {
      _isAddingToCart = true;
    });
    
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.addToCart(
        CartItem(
          id: widget.id,
          name: widget.name,
          price: widget.price,
          imageUrl: widget.imageUrl,
          sellerName: widget.sellerName,
          quantity: 1,
        ),
      );
      
      // Show success message (simple text to avoid overflow)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.name} added to cart'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add to cart: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
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
      child: MouseRegion(
        onEnter: (_) => _onHover(true),
        onExit: (_) => _onHover(false),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(_isHovered ? 0.15 : 0.08),
                      blurRadius: _isHovered ? 20 : 10,
                      offset: Offset(0, _isHovered ? 8 : 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onTap,
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image Section with Overlay
                          Stack(
                            children: [
                              // Product Image
                              AspectRatio(
                                aspectRatio: 1.0,
                                child: widget.imageUrl.isNotEmpty
                                    ? SafeProductImage(
                                        imageUrl: widget.imageUrl,
                                        width: double.infinity,
                                        height: double.infinity,
                                        borderRadius: BorderRadius.circular(12),
                                        // Keep default caching (no forced bypass here)
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                          size: 40,
                                        ),
                                      ),
                              ),
                              
                              // Rating Badge
                              if (widget.rating > 0)
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warning.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 12,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          widget.rating.toStringAsFixed(1),
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              
                              // Quick Add to Cart Button
                              if (widget.showAddToCart)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: AnimatedBuilder(
                                    animation: _hoverAnimation,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: 0.8 + (0.2 * _hoverAnimation.value),
                                        child: GestureDetector(
                                          onTap: _addToCart,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: _isAddingToCart
                                                ? SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                                                    ),
                                                  )
                                                : Icon(
                                                    Icons.add_shopping_cart,
                                                    size: 16,
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                  ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                          
                          // Content Section
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product Name
                                  Text(
                                    widget.name,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  
                                  // Seller Name
                                  Text(
                                    widget.sellerName,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  
                                  // Price and Rating Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Price
                                      Text(
                                        'R${widget.price.toStringAsFixed(2)}',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      
                                      // Review Count
                                      if (widget.reviewCount > 0)
                                        Text(
                                          '(${widget.reviewCount})',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                          ),
                                        ),
                                    ],
                                  ),
                                  
                                  const Spacer(),
                                  
                                  // Add to Cart Button
                                  if (widget.showAddToCart)
                                    AnimatedBuilder(
                                      animation: _hoverAnimation,
                                      builder: (context, child) {
                                        return AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          width: double.infinity,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(
                                              _hoverAnimation.value > 0.5 ? 1.0 : 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: Theme.of(context).colorScheme.primary,
                                              width: 1,
                                            ),
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _addToCart,
                                              borderRadius: BorderRadius.circular(14),
                                              child: Center(
                                                child: _isAddingToCart
                                                    ? SizedBox(
                                                        width: 12,
                                                        height: 12,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                                                        ),
                                                      )
                                                    : Text(
                                                        'Add to Cart',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600,
                                                          color: _hoverAnimation.value > 0.5 
                                                              ? Theme.of(context).colorScheme.onPrimary 
                                                              : Theme.of(context).colorScheme.primary,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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