import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/safe_network_image.dart';
import '../widgets/home_navigation_button.dart';
import '../widgets/bottom_action_bar.dart';
import '../screens/CheckoutScreen.dart';
import '../providers/cart_provider.dart';
import '../services/optimized_checkout_service.dart';
import 'package:flutter/services.dart';

import '../widgets/loading_widget.dart';
import '../constants/app_constants.dart';
import '../models/cart_item.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart' show SafeUI, ResponsiveUtils;
import '../widgets/bottom_action_bar.dart';

class EnhancedCartScreen extends StatefulWidget {
  const EnhancedCartScreen({super.key});

  @override
  State<EnhancedCartScreen> createState() => _EnhancedCartScreenState();
}

class _EnhancedCartScreenState extends State<EnhancedCartScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pre-warm checkout cache for faster navigation
    OptimizedCheckoutService.prewarmCache();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // Helper function to get appropriate icon based on product name
  IconData _getCategoryIcon(String productName) {
    final name = productName.toLowerCase();
    
    // Food categories
    if (name.contains('bread') || name.contains('cake') || name.contains('donut') || 
        name.contains('muffin') || name.contains('cookie') || name.contains('pie') ||
        name.contains('croissant') || name.contains('pastry') || name.contains('bun') ||
        name.contains('milk') || name.contains('cheese') || name.contains('apple') ||
        name.contains('chicken') || name.contains('rice') || name.contains('juice') ||
        name.contains('coffee') || name.contains('tea') || name.contains('water') ||
        name.contains('meat') || name.contains('fish') || name.contains('egg') ||
        name.contains('fruit') || name.contains('vegetable') || name.contains('snack') ||
        name.contains('chocolate') || name.contains('candy') || name.contains('sweet')) {
      return Icons.restaurant;
    }
    
    // Electronics categories
    if (name.contains('phone') || name.contains('laptop') || name.contains('computer') ||
        name.contains('camera') || name.contains('headphone') || name.contains('charger') ||
         name.contains('samsung') || name.contains('macbook') || name.contains('dell') ||
        name.contains('speaker') || name.contains('game') || name.contains('console') ||
        name.contains('smart') || name.contains('watch') || name.contains('fitbit')) {
      return Icons.devices;
    }
    
    // Clothes categories
    if (name.contains('shirt') || name.contains('dress') || name.contains('jeans') ||
        name.contains('shoes') || name.contains('hat') || name.contains('jacket') ||
        name.contains('pants') || name.contains('short') || name.contains('skirt') ||
        name.contains('sweater') || name.contains('hoodie') || name.contains('sneaker') ||
        name.contains('cap') || name.contains('belt') || name.contains('scarf') ||
        name.contains('underwear') || name.contains('sock') || name.contains('bra')) {
      return Icons.shopping_bag;
    }
    
    // Default to category icon
    return Icons.category;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.angel,
      appBar: AppBar(
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: AppTheme.angel,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: SafeUI.safeText(
          'Shopping Cart',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.angel,
            fontSize: ResponsiveUtils.getTitleSize(context),
          ),
          maxLines: 1,
        ),
        leading: Container(
          margin: EdgeInsets.all(ResponsiveUtils.isMobile(context) ? 8 : 6),
          decoration: BoxDecoration(
            color: AppTheme.angel.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios, 
              color: AppTheme.angel,
              size: ResponsiveUtils.getIconSize(context, baseSize: 20),
            ),
          onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              if (cartProvider.items.isNotEmpty) {
                return Container(
                  margin: EdgeInsets.only(right: ResponsiveUtils.getHorizontalPadding(context)),
                  decoration: BoxDecoration(
                    color: AppTheme.warmAccentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_outline, 
                      color: AppTheme.warmAccentColor,
                      size: ResponsiveUtils.getIconSize(context, baseSize: 22),
                    ),
                  onPressed: () => _showClearCartDialog(context, cartProvider),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.screenBackgroundGradient,
        ),
        child: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          if (cartProvider.isLoading) {
              return Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.cardBackgroundGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
                child: const LoadingWidget(message: 'Loading beautiful cart...'),
              );
          }

          if (cartProvider.items.isEmpty) {
              return _buildEnhancedEmptyCart();
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                    // Enhanced Cart Header
                    _buildCartHeader(cartProvider),
                    
                    // Beautiful Cart Items List
                  Expanded(
                    child: ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.getHorizontalPadding(context),
                          vertical: ResponsiveUtils.getVerticalPadding(context) * 0.5,
                        ),
                      itemCount: cartProvider.items.length,
                      itemBuilder: (context, index) {
                        final item = cartProvider.items[index];
                          return _buildEnhancedCartItem(context, item, cartProvider, index);
                      },
                    ),
                  ),
                  
                    // Enhanced Cart Summary
                                        _buildEnhancedCartSummary(context, cartProvider),
                ],
              ),
            ),
          );
        },
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some delicious food items to get started!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.shopping_bag),
              label: const Text('Start Shopping'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem item, CartProvider cartProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 80,
                height: 80,
                child: item.imageUrl != null && item.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'R${item.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
            
            // Quantity Controls
            Column(
              children: [
                // Remove Button
                IconButton(
                  onPressed: () => cartProvider.removeFromCart(item.id),
                  icon: Icon(Icons.remove_circle_outline, color: Colors.red),
                  iconSize: 24,
                ),
                
                // Quantity Display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                
                // Add Button
                IconButton(
                  onPressed: () => cartProvider.updateQuantity(
                    item.id,
                    item.quantity + 1,
                  ),
                  icon: Icon(Icons.add_circle_outline, color: Color(0xFF2E7D32)),
                  iconSize: 24,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSummary(BuildContext context, CartProvider cartProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Summary Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                'R${cartProvider.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shipping',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                '\$${cartProvider.shippingCost.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'R${cartProvider.totalWithShipping.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Checkout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CheckoutScreen(
                      totalPrice: cartProvider.totalPrice,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text('Proceed to Checkout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, CartProvider cartProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Are you sure you want to remove all items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              cartProvider.clearCart();
              Navigator.pop(context);
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartHeader(CartProvider cartProvider) {
    return Container(
      margin: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
      decoration: BoxDecoration(
        gradient: AppTheme.cardBackgroundGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.complementaryElevation,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.deepTeal, AppTheme.cloud],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.shopping_cart,
              color: AppTheme.angel,
              size: ResponsiveUtils.getIconSize(context, baseSize: 24),
            ),
          ),
          SizedBox(width: ResponsiveUtils.getHorizontalPadding(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeUI.safeText(
                  'Your Cart',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.deepTeal,
                  ),
                  maxLines: 1,
                ),
                SafeUI.safeText(
                  '${cartProvider.items.length} items • Total: R${cartProvider.totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                    color: AppTheme.breeze,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedCartItem(BuildContext context, CartItem item, CartProvider cartProvider, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.getVerticalPadding(context)),
      decoration: BoxDecoration(
        gradient: AppTheme.cardBackgroundGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.complementaryElevation,
        border: Border.all(
          color: AppTheme.breeze.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Could navigate to product detail
          },
          child: Padding(
            padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
            child: Row(
              children: [
                // Enhanced Product Image
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.deepTeal.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: ResponsiveUtils.isMobile(context) ? 80 : 100,
                      height: ResponsiveUtils.isMobile(context) ? 80 : 100,
                      child: item.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: item.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppTheme.whisper, AppTheme.angel],
                                  ),
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppTheme.whisper, AppTheme.angel],
                                  ),
                                ),
                                child: Icon(
                                  _getCategoryIcon(item.name),
                                  color: AppTheme.breeze,
                                  size: ResponsiveUtils.getIconSize(context, baseSize: 24),
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppTheme.whisper, AppTheme.angel],
                                ),
                              ),
                              child: Icon(
                                _getCategoryIcon(item.name),
                                color: AppTheme.breeze,
                                size: ResponsiveUtils.getIconSize(context, baseSize: 24),
                              ),
                            ),
                    ),
                  ),
                ),
                
                SizedBox(width: ResponsiveUtils.getHorizontalPadding(context)),
                
                // Product Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SafeUI.safeText(
                        item.name,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getTitleSize(context),
                          fontWeight: FontWeight.w600,
                          color: AppTheme.deepTeal,
                        ),
                        maxLines: 2,
                      ),
                      SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.3),
                      
                      SafeUI.safeText(
                        'R${item.price.toStringAsFixed(2)} each',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                          color: AppTheme.breeze,
                        ),
                        maxLines: 1,
                      ),
                      SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
                      
                      Row(
                        children: [
                          // Quantity Controls
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppTheme.whisper, AppTheme.angel],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.breeze.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    if (item.quantity > 1) {
                                      cartProvider.updateQuantity(item.id, item.quantity - 1);
                                    }
                                  },
                                  icon: Icon(
                                    Icons.remove,
                                    color: AppTheme.deepTeal,
                                    size: ResponsiveUtils.getIconSize(context, baseSize: 16),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: ResponsiveUtils.getHorizontalPadding(context) * 0.5,
                                  ),
                                  child: SafeUI.safeText(
                                    '${item.quantity}',
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getTitleSize(context),
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.deepTeal,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    cartProvider.updateQuantity(item.id, item.quantity + 1);
                                  },
                                  icon: Icon(
                                    Icons.add,
                                    color: AppTheme.deepTeal,
                                    size: ResponsiveUtils.getIconSize(context, baseSize: 16),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const Spacer(),
                          
                          // Total Price
                          SafeUI.safeText(
                            'R${(item.price * item.quantity).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getTitleSize(context) + 2,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.deepTeal,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                
                // Remove Button
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.warmAccentColor.withOpacity(0.1), AppTheme.warmAccentColor.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: () {
                      cartProvider.removeFromCart(item.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${item.name} removed from cart'),
                          backgroundColor: AppTheme.warmAccentColor,
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.close,
                      color: AppTheme.warmAccentColor,
                      size: ResponsiveUtils.getIconSize(context, baseSize: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedCartSummary(BuildContext context, CartProvider cartProvider) {
    return BottomActionBar(
      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
      backgroundColor: Colors.transparent,
      boxShadow: [],
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeUI.safeText(
                'Order Summary',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getTitleSize(context) + 2,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepTeal,
                ),
                maxLines: 1,
              ),
              SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SafeUI.safeText(
                    'Subtotal',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getTitleSize(context),
                      color: AppTheme.breeze,
                    ),
                    maxLines: 1,
                  ),
                  SafeUI.safeText(
                    'R${cartProvider.totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getTitleSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.deepTeal,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SafeUI.safeText(
                    'Delivery Fee',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getTitleSize(context),
                      color: AppTheme.breeze,
                    ),
                    maxLines: 1,
                  ),
                  SafeUI.safeText(
                    'R${(cartProvider.totalWithShipping - cartProvider.totalPrice).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getTitleSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.deepTeal,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
              
              Divider(
                height: ResponsiveUtils.getVerticalPadding(context) * 2,
                color: AppTheme.breeze.withOpacity(0.3),
                thickness: 1,
              ),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SafeUI.safeText(
                    'Total',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getTitleSize(context) + 4,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepTeal,
                    ),
                    maxLines: 1,
                  ),
                  SafeUI.safeText(
                    'R${cartProvider.totalWithShipping.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getTitleSize(context) + 6,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepTeal,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ],
          ),
        ),
        ActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CheckoutScreen(
                  totalPrice: cartProvider.totalPrice,
                ),
              ),
            );
          },
          icon: const Icon(Icons.shopping_cart_checkout),
          label: 'Checkout',
          isPrimary: true,
          height: 50,
        ),
      ],
    );
  }

  Widget _buildEnhancedEmptyCart() {
    return Container(
      margin: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 2),
      decoration: BoxDecoration(
        gradient: AppTheme.cardBackgroundGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.complementaryElevation,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 1.5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.whisper, AppTheme.angel],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.breeze.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: ResponsiveUtils.getIconSize(context, baseSize: 80),
                color: AppTheme.breeze,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 2),
            
            SafeUI.safeText(
              'Your cart is empty',
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context) + 8,
                fontWeight: FontWeight.w600,
                color: AppTheme.deepTeal,
              ),
              maxLines: 1,
            ),
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
            
            SafeUI.safeText(
              'Add some delicious items to get started!',
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context),
                color: AppTheme.breeze,
              ),
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 2),
            
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryButtonGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.complementaryElevation,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: ResponsiveUtils.getVerticalPadding(context),
                      horizontal: ResponsiveUtils.getHorizontalPadding(context) * 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          color: AppTheme.angel,
                          size: ResponsiveUtils.getIconSize(context, baseSize: 20),
                        ),
                        SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                        SafeUI.safeText(
                          'Start Shopping',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getTitleSize(context),
                            fontWeight: FontWeight.w600,
                            color: AppTheme.angel,
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
