import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/safe_network_image.dart';
import 'ProductEditScreen.dart';

class SellerProductManagement extends StatefulWidget {
  const SellerProductManagement({super.key});

  @override
  State<SellerProductManagement> createState() => _SellerProductManagementState();
}

class _SellerProductManagementState extends State<SellerProductManagement> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _products = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _checkAndFixProductOwnership(); // Check and fix product ownership
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'Please log in to view your products';
          _isLoading = false;
        });
        return;
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      setState(() {
        _products = querySnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList()
            ..sort((a, b) {
              // Sort by timestamp descending (newest first)
              final timestampA = a['timestamp'] as Timestamp?;
              final timestampB = b['timestamp'] as Timestamp?;
              if (timestampA == null && timestampB == null) return 0;
              if (timestampA == null) return 1;
              if (timestampB == null) return -1;
              return timestampB.compareTo(timestampA);
            });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load products: $e';
        _isLoading = false;
      });
    }
  }

  // Helper function to check and fix product ownership
  Future<void> _checkAndFixProductOwnership() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      print('🔍 DEBUG: Checking product ownership for user: ${currentUser.uid}');

      // Get all products for the current user
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('ownerId', isEqualTo: currentUser.uid)
          .get();

      print('🔍 DEBUG: Found ${productsSnapshot.docs.length} products owned by user');

      // Also check for products with storeId that might have wrong ownerId
      final storeProductsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('storeId', isEqualTo: currentUser.uid)
          .get();

      print('🔍 DEBUG: Found ${storeProductsSnapshot.docs.length} products with storeId matching user');

      // Check for products that have storeId but wrong ownerId
      for (var doc in storeProductsSnapshot.docs) {
        final data = doc.data();
        final ownerId = data['ownerId'] as String?;
        
        if (ownerId != currentUser.uid) {
          print('🔍 DEBUG: Found product with wrong ownerId: ${doc.id}');
          print('🔍 DEBUG: Current ownerId: $ownerId, Should be: ${currentUser.uid}');
          
          // Fix the ownerId
          await FirebaseFirestore.instance
              .collection('products')
              .doc(doc.id)
              .update({
            'ownerId': currentUser.uid,
          });
          
          print('🔍 DEBUG: Fixed ownerId for product: ${doc.id}');
        }
      }

      print('🔍 DEBUG: Product ownership check completed');
    } catch (e) {
      print('❌ Error checking product ownership: $e');
    }
  }

  Future<void> _deleteProduct(String productId, String productName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "$productName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        setState(() {
          _isLoading = true;
        });

        // Get current user to verify ownership
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          throw Exception('User not authenticated');
        }

        print('🔍 DEBUG: Attempting to delete product: $productId');
        print('🔍 DEBUG: Current user ID: ${currentUser.uid}');

        // First verify the product belongs to the current user
        final productDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .get();

        if (!productDoc.exists) {
          throw Exception('Product not found');
        }

        final productData = productDoc.data()!;
        final productOwnerId = productData['ownerId'] as String?;
        
        print('🔍 DEBUG: Product data: $productData');
        print('🔍 DEBUG: Product ownerId: $productOwnerId');
        print('🔍 DEBUG: Current user ID: ${currentUser.uid}');
        print('🔍 DEBUG: Owner match: ${productOwnerId == currentUser.uid}');

        if (productOwnerId == null) {
          throw Exception('Product has no owner ID');
        }

        if (productOwnerId != currentUser.uid) {
          throw Exception('You can only delete your own products. Product owner: $productOwnerId, Your ID: ${currentUser.uid}');
        }

        print('🔍 DEBUG: Ownership verified, proceeding with deletion...');

        // Delete the product
        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .delete();

        print('🔍 DEBUG: Product deleted successfully');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $productName deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        _loadProducts(); // Reload the list
      } catch (e) {
        print('❌ Error deleting product: $e');
        
        String errorMessage = 'Failed to delete product';
        if (e.toString().contains('permission-denied')) {
          errorMessage = 'Permission denied. You can only delete your own products.';
        } else if (e.toString().contains('not found')) {
          errorMessage = 'Product not found.';
        } else if (e.toString().contains('not authenticated')) {
          errorMessage = 'Please log in to delete products.';
        } else if (e.toString().contains('You can only delete your own products')) {
          errorMessage = e.toString();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _editProduct(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductEditScreen(
          productId: product['id'],
          initialData: product,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadProducts(); // Reload if product was updated
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.whisper,
      appBar: AppBar(
        title: const Text('My Products'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: AppTheme.angel,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.deepTeal,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProducts,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.deepTeal,
                          foregroundColor: AppTheme.angel,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No products yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start by uploading your first product',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              // Navigate to product upload
                              Navigator.pushNamed(context, '/upload_product');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.deepTeal,
                              foregroundColor: AppTheme.angel,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Upload Product'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadProducts,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Product Image
                                if (product['imageUrl'] != null)
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                    child: SafeNetworkImage(
                                      imageUrl: product['imageUrl'],
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover,
                                      errorWidget: Container(
                                        width: double.infinity,
                                        height: 200,
                                        color: Colors.grey[200],
                                        child: Icon(
                                          Icons.image,
                                          size: 48,
                                          color: Colors.grey[400],
                                        ),
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
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.deepTeal,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      
                                      // Price and Category
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryGreen,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'R${(product['price'] ?? 0.0).toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: AppTheme.angel,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.deepTeal.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: AppTheme.deepTeal.withOpacity(0.3),
                                              ),
                                            ),
                                            child: Text(
                                              product['category'] ?? 'Uncategorized',
                                              style: TextStyle(
                                                color: AppTheme.deepTeal,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      
                                      // Stock and Status
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.inventory,
                                            size: 16,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Stock: ${product['quantity'] ?? 0}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Icon(
                                            Icons.circle,
                                            size: 12,
                                            color: (product['quantity'] ?? 0) > 0
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            (product['quantity'] ?? 0) > 0 ? 'In Stock' : 'Out of Stock',
                                            style: TextStyle(
                                              color: (product['quantity'] ?? 0) > 0
                                                  ? Colors.green
                                                  : Colors.red,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      // Action Buttons
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => _editProduct(product),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.deepTeal,
                                                foregroundColor: AppTheme.angel,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                              icon: const Icon(Icons.edit, size: 18),
                                              label: const Text('Edit'),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => _deleteProduct(
                                                product['id'],
                                                product['name'] ?? 'Product',
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: AppTheme.angel,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                              icon: const Icon(Icons.delete, size: 18),
                                              label: const Text('Delete'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
} 