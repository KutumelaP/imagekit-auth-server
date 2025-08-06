import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../theme/admin_theme.dart';

class EnhancedProductManagement extends StatefulWidget {
  final FirebaseFirestore firestore;

  const EnhancedProductManagement({
    Key? key,
    required this.firestore,
  }) : super(key: key);

  @override
  State<EnhancedProductManagement> createState() => _EnhancedProductManagementState();
}

class _EnhancedProductManagementState extends State<EnhancedProductManagement>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  
  // Filter states
  String _selectedCategory = 'All';
  String _selectedStatus = 'All';
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _sortAscending = true;
  
  final List<String> _categories = ['All', 'Food', 'Beverages', 'Snacks', 'Desserts', 'Other'];
  final List<String> _statuses = ['All', 'active', 'inactive', 'out_of_stock'];
  final List<String> _sortOptions = ['name', 'price', 'rating', 'stock', 'createdAt'];
  
  // Bulk operations
  Set<String> _selectedProductIds = {};
  bool _selectAll = false;
  
  // Real-time updates
  StreamSubscription<QuerySnapshot>? _productsSubscription;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadProducts();
    _setupRealTimeUpdates();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _productsSubscription?.cancel();
    super.dispose();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    
    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    
    try {
      final snapshot = await widget.firestore
          .collection('products')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      _products = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading products: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupRealTimeUpdates() {
    _productsSubscription = widget.firestore
        .collection('products')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _products = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              ...data,
            };
          }).toList();
        });
        _applyFilters();
      }
    });
  }

  void _applyFilters() {
    _filteredProducts = _products.where((product) {
      // Category filter
      if (_selectedCategory != 'All' && product['category'] != _selectedCategory) {
        return false;
      }
      
      // Status filter
      if (_selectedStatus != 'All') {
        final status = product['status'] as String? ?? 'active';
        if (status != _selectedStatus) {
          return false;
        }
      }
      
      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final name = product['name']?.toString().toLowerCase() ?? '';
        final description = product['description']?.toString().toLowerCase() ?? '';
        final category = product['category']?.toString().toLowerCase() ?? '';
        
        if (!name.contains(query) && 
            !description.contains(query) && 
            !category.contains(query)) {
          return false;
        }
      }
      
      return true;
    }).toList();
    
    // Apply sorting
    _filteredProducts.sort((a, b) {
      dynamic aValue = a[_sortBy];
      dynamic bValue = b[_sortBy];
      
      if (aValue == null) aValue = '';
      if (bValue == null) bValue = '';
      
      int comparison = 0;
      if (aValue is String && bValue is String) {
        comparison = aValue.compareTo(bValue);
      } else if (aValue is num && bValue is num) {
        comparison = aValue.compareTo(bValue);
      } else {
        comparison = aValue.toString().compareTo(bValue.toString());
      }
      
      return _sortAscending ? comparison : -comparison;
    });
  }

  Future<void> _updateProductStatus(String productId, String newStatus) async {
    try {
      await widget.firestore
          .collection('products')
          .doc(productId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product status updated to $newStatus'),
          backgroundColor: AdminTheme.deepTeal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update product status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateProductStock(String productId, int newStock) async {
    try {
      await widget.firestore
          .collection('products')
          .doc(productId)
          .update({
        'stock': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product stock updated to $newStock'),
          backgroundColor: AdminTheme.deepTeal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update product stock: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _bulkUpdateStatus(String newStatus) async {
    if (_selectedProductIds.isEmpty) return;
    
    try {
      final batch = widget.firestore.batch();
      
      for (final productId in _selectedProductIds) {
        final docRef = widget.firestore.collection('products').doc(productId);
        batch.update(docRef, {
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      
      setState(() {
        _selectedProductIds.clear();
        _selectAll = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated ${_selectedProductIds.length} products to $newStatus'),
          backgroundColor: AdminTheme.deepTeal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update products: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleProductSelection(String productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
      } else {
        _selectedProductIds.add(productId);
      }
      _selectAll = _selectedProductIds.length == _filteredProducts.length;
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectAll) {
        _selectedProductIds.clear();
      } else {
        _selectedProductIds = _filteredProducts.map((p) => p['id'] as String).toSet();
      }
      _selectAll = !_selectAll;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              _buildHeader(),
              _buildFilters(),
              _buildProductStats(),
              if (_selectedProductIds.isNotEmpty) _buildBulkActions(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildProductList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        border: Border(
          bottom: BorderSide(color: AdminTheme.silverGray.withOpacity(0.3)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enhanced Product Management',
                style: AdminTheme.headlineLarge.copyWith(
                  color: AdminTheme.deepTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Comprehensive product catalog management',
                style: AdminTheme.bodyMedium.copyWith(
                  color: AdminTheme.darkGrey,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminTheme.deepTeal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inventory,
                  color: AdminTheme.angel,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_filteredProducts.length} Products',
                  style: AdminTheme.labelMedium.copyWith(
                    color: AdminTheme.angel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.whisper,
        border: Border(
          bottom: BorderSide(color: AdminTheme.silverGray.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AdminTheme.angel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminTheme.silverGray),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Search products by name, description, or category...',
                hintStyle: AdminTheme.bodyMedium.copyWith(
                  color: AdminTheme.darkGrey,
                ),
                border: InputBorder.none,
                icon: Icon(
                  Icons.search,
                  color: AdminTheme.deepTeal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Filter controls
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  'Category',
                  _selectedCategory,
                  _categories,
                  (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  'Status',
                  _selectedStatus,
                  _statuses,
                  (value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  'Sort By',
                  _sortBy,
                  _sortOptions,
                  (value) {
                    setState(() {
                      _sortBy = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  setState(() {
                    _sortAscending = !_sortAscending;
                  });
                  _applyFilters();
                },
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: AdminTheme.deepTeal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.silverGray),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item.replaceAll('_', ' ').toUpperCase(),
                style: AdminTheme.bodyMedium,
              ),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
        ),
      ),
    );
  }

  Widget _buildProductStats() {
    final stats = _calculateProductStats();
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Products',
              stats['total'].toString(),
              Icons.inventory,
              AdminTheme.deepTeal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Active',
              stats['active'].toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Out of Stock',
              stats['outOfStock'].toString(),
              Icons.warning,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Low Stock',
              stats['lowStock'].toString(),
              Icons.trending_down,
              Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateProductStats() {
    int total = _filteredProducts.length;
    int active = 0;
    int outOfStock = 0;
    int lowStock = 0;
    
    for (final product in _filteredProducts) {
      final status = product['status'] as String? ?? 'active';
      final stock = (product['stock'] as num?)?.toInt() ?? 0;
      
      if (status == 'active') {
        active++;
        if (stock == 0) {
          outOfStock++;
        } else if (stock <= 5) {
          lowStock++;
        }
      }
    }
    
    return {
      'total': total,
      'active': active,
      'outOfStock': outOfStock,
      'lowStock': lowStock,
    };
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AdminTheme.cardDecoration(
        color: AdminTheme.angel,
        boxShadow: [
          BoxShadow(
            color: AdminTheme.indigo.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AdminTheme.titleLarge.copyWith(
              color: AdminTheme.deepTeal,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: AdminTheme.bodySmall.copyWith(
              color: AdminTheme.darkGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.cloud.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: AdminTheme.silverGray.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedProductIds.length} products selected',
            style: AdminTheme.titleMedium.copyWith(
              color: AdminTheme.deepTeal,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            onSelected: (value) => _bulkUpdateStatus(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'active',
                child: Text('Activate'),
              ),
              const PopupMenuItem(
                value: 'inactive',
                child: Text('Deactivate'),
              ),
              const PopupMenuItem(
                value: 'out_of_stock',
                child: Text('Mark Out of Stock'),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AdminTheme.deepTeal,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit,
                    color: AdminTheme.angel,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Bulk Actions',
                    style: AdminTheme.labelMedium.copyWith(
                      color: AdminTheme.angel,
                      fontWeight: FontWeight.bold,
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

  Widget _buildProductList() {
    if (_filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_outlined,
              size: 64,
              color: AdminTheme.darkGrey,
            ),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: AdminTheme.headlineSmall.copyWith(
                color: AdminTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: AdminTheme.bodyMedium.copyWith(
                color: AdminTheme.darkGrey,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final productId = product['id'] as String? ?? '';
    final name = product['name'] as String? ?? 'Unknown Product';
    final price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final stock = (product['stock'] as num?)?.toInt() ?? 0;
    final status = product['status'] as String? ?? 'active';
    final category = product['category'] as String? ?? 'Uncategorized';
    final rating = (product['rating'] as num?)?.toDouble() ?? 0.0;
    final imageUrl = product['imageUrl'] as String?;
    final createdAt = (product['createdAt'] as Timestamp?)?.toDate();
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'active':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'inactive':
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        break;
      case 'out_of_stock':
        statusColor = Colors.red;
        statusIcon = Icons.warning;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }
    
    final isSelected = _selectedProductIds.contains(productId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? AdminTheme.cloud.withOpacity(0.1) : AdminTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AdminTheme.deepTeal : AdminTheme.silverGray.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AdminTheme.silverGray.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (value) => _toggleProductSelection(productId),
              activeColor: AdminTheme.deepTeal,
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
                size: 20,
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            if (imageUrl != null)
              Container(
                width: 50,
                height: 50,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AdminTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    category,
                    style: AdminTheme.bodySmall.copyWith(
                      color: AdminTheme.darkGrey,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'R${price.toStringAsFixed(2)}',
                  style: AdminTheme.titleMedium.copyWith(
                    color: AdminTheme.deepTeal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 12,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      rating.toStringAsFixed(1),
                      style: AdminTheme.bodySmall.copyWith(
                        color: AdminTheme.darkGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.replaceAll('_', ' ').toUpperCase(),
                style: AdminTheme.labelSmall.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Stock: $stock',
              style: AdminTheme.bodySmall.copyWith(
                color: stock <= 5 ? Colors.red : AdminTheme.darkGrey,
                fontWeight: stock <= 5 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProductDetails(product),
                const SizedBox(height: 16),
                _buildProductActions(productId, status, stock),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetails(Map<String, dynamic> product) {
    final description = product['description'] as String? ?? 'No description available';
    final sellerId = product['sellerId'] as String? ?? 'Unknown Seller';
    final createdAt = (product['createdAt'] as Timestamp?)?.toDate();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Details',
          style: AdminTheme.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: AdminTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Seller ID:',
              style: AdminTheme.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              sellerId.substring(0, 8),
              style: AdminTheme.bodySmall,
            ),
          ],
        ),
        if (createdAt != null) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Created:',
                style: AdminTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('MMM dd, yyyy').format(createdAt),
                style: AdminTheme.bodySmall,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildProductActions(String productId, String currentStatus, int currentStock) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AdminTheme.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Update Status',
                Icons.edit,
                () => _showStatusDialog(productId, currentStatus),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                'Update Stock',
                Icons.inventory,
                () => _showStockDialog(productId, currentStock),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: AdminTheme.labelSmall.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminTheme.deepTeal,
        foregroundColor: AdminTheme.angel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showStatusDialog(String productId, String currentStatus) {
    final statuses = ['active', 'inactive', 'out_of_stock'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Update Product Status',
          style: AdminTheme.titleLarge.copyWith(
            color: AdminTheme.deepTeal,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: statuses.map((status) {
            return ListTile(
              title: Text(status.replaceAll('_', ' ').toUpperCase()),
              leading: Radio<String>(
                value: status,
                groupValue: currentStatus,
                onChanged: (value) {
                  if (value != null) {
                    _updateProductStatus(productId, value);
                    Navigator.of(context).pop();
                  }
                },
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AdminTheme.bodyMedium.copyWith(
                color: AdminTheme.darkGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStockDialog(String productId, int currentStock) {
    final controller = TextEditingController(text: currentStock.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Update Product Stock',
          style: AdminTheme.titleLarge.copyWith(
            color: AdminTheme.deepTeal,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Stock Quantity',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AdminTheme.bodyMedium.copyWith(
                color: AdminTheme.darkGrey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final newStock = int.tryParse(controller.text) ?? currentStock;
              _updateProductStock(productId, newStock);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.deepTeal,
              foregroundColor: AdminTheme.angel,
            ),
            child: Text(
              'Update',
              style: AdminTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 