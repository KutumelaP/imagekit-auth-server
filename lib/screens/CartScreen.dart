import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/cart_provider.dart';
import '../services/optimized_checkout_service.dart';
import '../theme/app_theme.dart';
import '../widgets/safe_network_image.dart';
import '../widgets/home_navigation_button.dart';
import '../widgets/bottom_action_bar.dart';
import 'package:flutter/services.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // Pre-warm checkout cache for faster navigation
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) OptimizedCheckoutService.prewarmCache(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Your Cart'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: AppTheme.angel,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          HomeNavigationButton(
            backgroundColor: AppTheme.deepTeal,
            iconColor: AppTheme.angel,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppTheme.screenBackgroundGradient,
          color: AppTheme.whisper, // Fallback color
        ),
        child: Consumer<CartProvider>(
          builder: (context, cartProvider, child) {
            final cartItems = cartProvider.items;
            
            if (cartItems.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 64,
                      color: AppTheme.cloud,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your cart is empty',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppTheme.cloud,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final cartItem = cartItems[index];

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('products')
                            .doc(cartItem.id)
                            .get(),
                        builder: (context, productSnapshot) {
                          if (productSnapshot.hasError) {
                            return ListTile(
                              title: const Text('Error loading product'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => cartProvider.removeFromCart(cartItem.id),
                              ),
                            );
                          }
                          
                          if (productSnapshot.connectionState == ConnectionState.waiting) {
                            return const ListTile(
                              title: Text('Loading product...'),
                            );
                          }
                          
                          if (!productSnapshot.data!.exists) {
                            return ListTile(
                              title: const Text('Product no longer available'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => cartProvider.removeFromCart(cartItem.id),
                              ),
                            );
                          }

                          final productData = productSnapshot.data!.data() as Map<String, dynamic>;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.angel,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.deepTeal.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              leading: (productData['imageUrl'] != null && productData['imageUrl'].toString().isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SafeNetworkImage(
                                        imageUrl: productData['imageUrl'],
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(Icons.image, size: 40, color: Colors.grey),
                              title: Text(
                                productData['name'] ?? 'Unnamed Product',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Quantity: ${cartItem.quantity}'),
                                  Text(
                                    'R${(productData['price'] ?? 0).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: AppTheme.primaryGreen,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.remove_circle_outline, color: AppTheme.primaryRed),
                                    onPressed: () {
                                      if (cartItem.quantity > 1) {
                                        cartProvider.updateQuantity(cartItem.id, cartItem.quantity - 1);
                                      } else {
                                        cartProvider.removeFromCart(cartItem.id);
                                      }
                                    },
                                  ),
                                  Text(
                                    '${cartItem.quantity}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.add_circle_outline, 
                                      color: cartProvider.canIncrementQuantity(cartItem.id) 
                                        ? AppTheme.primaryGreen 
                                        : Colors.grey,
                                    ),
                                    onPressed: cartProvider.canIncrementQuantity(cartItem.id) 
                                      ? () => cartProvider.updateQuantity(cartItem.id, cartItem.quantity + 1)
                                      : null,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: AppTheme.primaryRed),
                                    onPressed: () => cartProvider.removeFromCart(cartItem.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: BottomActionBar(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total: R${cartProvider.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.deepTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ActionButton(
                        onPressed: cartItems.isNotEmpty ? () async {
                          // Check if any items are from blocked stores
                          bool hasBlockedItems = false;
                          String blockedStoreName = '';
                          double blockedDistance = 0.0;
                          double blockedServiceRadius = 20.0;
                          
                          for (var item in cartItems) {
                            final storeId = item.sellerId;
                            if (storeId.isNotEmpty) {
                              // Check if this store is blocked due to distance
                              try {
                                final storeDoc = await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(storeId)
                                    .get();
                                
                                if (storeDoc.exists) {
                                  final storeData = storeDoc.data()!;
                                  final storeLat = storeData['latitude'] as double?;
                                  final storeLng = storeData['longitude'] as double?;
                                  final serviceRadius = (storeData['serviceRadius'] as num?)?.toDouble() ?? 20.0;
                                  
                                  if (storeLat != null && storeLng != null) {
                                    // Get user location
                                    final userPos = await Geolocator.getCurrentPosition(
                                      desiredAccuracy: LocationAccuracy.medium,
                                      timeLimit: const Duration(seconds: 3),
                                    );
                                    
                                    if (userPos != null) {
                                      final distance = Geolocator.distanceBetween(
                                        userPos.latitude,
                                        userPos.longitude,
                                        storeLat,
                                        storeLng,
                                      ) / 1000;
                                      
                                      if (distance > serviceRadius) {
                                        hasBlockedItems = true;
                                        blockedStoreName = storeData['storeName'] ?? 'Store';
                                        blockedDistance = distance;
                                        blockedServiceRadius = serviceRadius;
                                        break;
                                      }
                                    }
                                  }
                                }
                              } catch (e) {
                                print('Error checking store distance: $e');
                              }
                            }
                          }
                          
                          if (hasBlockedItems) {
                            // Show error and prevent checkout
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Cannot checkout: $blockedStoreName is ${blockedDistance.toStringAsFixed(1)}km away (max ${blockedServiceRadius.toStringAsFixed(1)}km). Please remove items from this store or choose a closer store.'),
                                backgroundColor: AppTheme.error,
                                duration: const Duration(seconds: 5),
                                action: SnackBarAction(
                                  label: 'View Stores',
                                  textColor: Colors.white,
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/');
                                  },
                                ),
                              ),
                            );
                            return;
                          }
                          
                          // Proceed with checkout if no blocked items
                          Navigator.pushNamed(
                            context,
                            '/checkout',
                            arguments: {'totalPrice': cartProvider.totalPrice},
                          );
                        } : null,
                        icon: const Icon(Icons.shopping_cart_checkout),
                        label: 'Checkout',
                        isPrimary: true,
                        height: 50,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}