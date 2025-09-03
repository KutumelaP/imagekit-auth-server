import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/safe_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';

class ProductDetailScreen extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  // Helper function to get appropriate icon for product category
  IconData _getCategoryIcon(String? category) {
    if (category == null) return Icons.category;
    
    switch (category.toLowerCase()) {
      case 'food':
      case 'fruits':
      case 'vegetables':
      case 'bakery':
      case 'snacks':
      case 'beverages':
      case 'dairy':
      case 'meat':
        return Icons.restaurant;
      case 'clothes':
      case 'clothing':
        return Icons.shopping_bag;
      case 'electronics':
        return Icons.devices;
      case 'home':
      case 'furniture':
        return Icons.home;
      case 'beauty':
      case 'cosmetics':
        return Icons.face;
      case 'sports':
      case 'fitness':
        return Icons.sports_soccer;
      case 'books':
      case 'education':
        return Icons.book;
      case 'other':
        return Icons.category;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = _getProductStock(product);
    final isOutOfStock = stock <= 0;

    // Buy Now functionality
    Future<void> _buyNow(BuildContext context) async {
      // Get cart provider
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      
      // Check if user is authenticated
      if (!cartProvider.isAuthenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to proceed with purchase'),
            backgroundColor: AppTheme.warning,
          ),
        );
        return;
      }
      
      // Check stock availability
      final stock = _getProductStock(product);
      if (stock <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This product is out of stock!'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
        return;
      }
      
      // Add to cart (default quantity 1)
      final success = await cartProvider.addItem(
        product['id'],
        product['name'] ?? 'Unknown Product',
        (product['price'] ?? 0.0).toDouble(),
        product['imageUrl'] ?? '',
        product['ownerId'] ?? product['sellerId'] ?? '',
        product['storeName'] ?? 'Unknown Store',
        product['storeCategory'] ?? 'Other',
        quantity: 1, // Default quantity for this screen
        availableStock: stock,
      );
      
      if (success) {
        // Navigate to cart
        Navigator.pushNamed(context, '/cart');
      } else {
        // Show specific error message from cart provider
        final errorMessage = cartProvider.lastAddError ?? 'Failed to add product to cart';
        final backgroundColor = cartProvider.lastAddBlocked ? Colors.red : Colors.orange;
        final icon = cartProvider.lastAddBlocked ? Icons.block : Icons.warning;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.whisper,
      appBar: AppBar(
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          product['name'] ?? 'Product Details',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Container(
              height: 300,
              width: double.infinity,
              child: product['imageUrl'] != null && product['imageUrl'].toString().isNotEmpty
                  ? SafeProductImage(
                      imageUrl: product['imageUrl'],
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: AppTheme.cloud,
                      child: Icon(
                        _getCategoryIcon(product['category']),
                        color: AppTheme.deepTeal,
                        size: 64,
                      ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Product Name
                      Text(
                        product['name'] ?? 'Unnamed Product',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepTeal,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Price
                  Row(
                    children: [
                      Text(
                        'R${(product['price'] ?? 0.0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepTeal,
                        ),
                      ),
                      const Spacer(),
                      if (isOutOfStock)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Out of Stock',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'In Stock: $stock',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                  ),

                        const SizedBox(height: 16),

                  // Category and Subcategory
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.deepTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          product['category'] ?? 'Unknown',
                          style: const TextStyle(
                            color: AppTheme.deepTeal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (product['subcategory'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.cloud,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            product['subcategory'],
                            style: TextStyle(
                              color: AppTheme.mediumGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                  ),

                  const SizedBox(height: 24),

                  // Description
                  if (product['description'] != null && product['description'].toString().isNotEmpty) ...[
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepTeal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product['description'],
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.mediumGrey,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Product Details
                  _buildDetailSection(
                    'Product Details',
                    [
                      _buildDetailRow('Status', product['status'] ?? 'active'),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  if (!isOutOfStock) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: Implement add-to-cart without success toast
                        },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.deepTeal,
                              foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Add to Cart',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                              const SizedBox(height: 12),
                              SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          // Buy now functionality - add to cart and navigate
                          _buyNow(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.deepTeal,
                          side: const BorderSide(color: AppTheme.deepTeal),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Buy Now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Out of Stock',
                          style: TextStyle(
                            fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                    ),
                  ],
                                            ],
                                          ),
            ),
          ],
                                        ),
                                      ),
                                    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.deepTeal,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.cloud.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: children,
                                ),
                              ),
                            ],
                          );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.mediumGrey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.deepTeal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year}';
      }
      return timestamp.toString();
    } catch (e) {
      return 'Unknown';
    }
  }

  int _getProductStock(Map<String, dynamic> product) {
    final stock = product['stock'];
    final quantity = product['quantity'];
    
    if (stock != null) {
      return int.tryParse(stock.toString()) ?? 0;
    } else if (quantity != null) {
      return int.tryParse(quantity.toString()) ?? 0;
    }
    
    return 0;
  }



  // Generate order number
}
