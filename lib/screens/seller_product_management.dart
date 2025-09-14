import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import 'ProductEditScreen.dart';
import 'modern_product_card.dart';

class SellerProductManagement extends StatefulWidget {
  const SellerProductManagement({super.key});

  @override
  State<SellerProductManagement> createState() => _SellerProductManagementState();
}

class _SellerProductManagementState extends State<SellerProductManagement> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _products = [];
  String? _errorMessage;
  String _searchQuery = '';
  String _filterCategory = '';
  String _sortBy = 'newest';
  Set<String> _selectedProductIds = {};
  bool _selectionMode = false;
  bool _lowStockOnly = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _checkAndFixProductOwnership();
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

  Future<void> _checkAndFixProductOwnership() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: user.uid)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      int updatedCount = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        if (data['ownerId'] != user.uid) {
          batch.update(doc.reference, {'ownerId': user.uid});
          updatedCount++;
        }
      }

      if (updatedCount > 0) {
        await batch.commit();
        print('✅ Fixed ownership for $updatedCount products');
        _loadProducts();
      }
    } catch (e) {
      print('❌ Error checking product ownership: $e');
    }
  }

  Future<void> _deleteProduct(String productId, String productName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "$productName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .delete();

        setState(() {
          _products.removeWhere((product) => product['id'] == productId);
          _selectedProductIds.remove(productId);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product "$productName" deleted successfully'),
              backgroundColor: AppTheme.primaryGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete product: $e'),
              backgroundColor: AppTheme.primaryRed,
            ),
          );
        }
      }
    }
  }

  void _editProduct(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductEditScreen(
          productId: product['id'] as String,
          initialData: product,
        ),
      ),
    ).then((updated) {
      if (updated == true) {
        _loadProducts();
      }
    });
  }

  void _toggleSelect(String productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
      } else {
        _selectedProductIds.add(productId);
      }
      _selectionMode = _selectedProductIds.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedProductIds.clear();
      _selectionMode = false;
    });
  }

  void _selectAllFiltered() {
    setState(() {
      final filteredProducts = _filteredAndSortedProducts();
      for (final product in filteredProducts) {
        _selectedProductIds.add(product['id'] as String);
      }
      _selectionMode = _selectedProductIds.isNotEmpty;
    });
  }

  Future<void> _bulkUpdateStatus(bool active) async {
    if (_selectedProductIds.isEmpty) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final productId in _selectedProductIds) {
        final docRef = FirebaseFirestore.instance.collection('products').doc(productId);
        batch.update(docRef, {'status': active ? 'active' : 'draft'});
      }
      await batch.commit();

      setState(() {
        for (final product in _products) {
          if (_selectedProductIds.contains(product['id'])) {
            product['status'] = active ? 'active' : 'draft';
          }
        }
      });

      _clearSelection();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update products: $e')),
      );
    }
  }

  Future<void> _bulkDelete() async {
    if (_selectedProductIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Products'),
        content: Text('Are you sure you want to delete ${_selectedProductIds.length} products?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        for (final productId in _selectedProductIds) {
          final docRef = FirebaseFirestore.instance.collection('products').doc(productId);
          batch.delete(docRef);
        }
        await batch.commit();

        setState(() {
          _products.removeWhere((product) => _selectedProductIds.contains(product['id']));
        });

        _clearSelection();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete products: $e')),
        );
      }
    }
  }

  Future<void> _updateQuantity(String productId, int newQuantity) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .update({'quantity': newQuantity, 'stock': newQuantity});

      setState(() {
        final product = _products.firstWhere((p) => p['id'] == productId);
        product['quantity'] = newQuantity;
        product['stock'] = newQuantity;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update quantity: $e'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
    }
  }

  Future<void> _toggleStatus(String productId, bool active) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .update({'status': active ? 'active' : 'draft'});

      setState(() {
        final product = _products.firstWhere((p) => p['id'] == productId);
        product['status'] = active ? 'active' : 'draft';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _filteredAndSortedProducts() {
    var list = _products.where((product) {
      final name = (product['name'] ?? '').toString().toLowerCase();
      final category = (product['category'] ?? '').toString().toLowerCase();
      final searchLower = _searchQuery.toLowerCase();

      final matchesSearch = name.contains(searchLower) || category.contains(searchLower);
      final matchesCategory = _filterCategory.isEmpty || category == _filterCategory.toLowerCase();

      bool matchesLowStock = true;
      if (_lowStockOnly) {
        final qty = (product['quantity'] ?? product['stock'] ?? 0) is int
            ? (product['quantity'] ?? product['stock'] ?? 0) as int
            : int.tryParse('${product['quantity'] ?? product['stock'] ?? 0}') ?? 0;
        matchesLowStock = qty > 0 && qty <= 5;
      }

      return matchesSearch && matchesCategory && matchesLowStock;
    }).toList();

    list.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
        case 'price':
          final priceA = (a['price'] ?? 0.0) as double;
          final priceB = (b['price'] ?? 0.0) as double;
          return priceA.compareTo(priceB);
        case 'stock':
          final qtyA = (a['quantity'] ?? a['stock'] ?? 0) is int
              ? (a['quantity'] ?? a['stock'] ?? 0) as int
              : int.tryParse('${a['quantity'] ?? a['stock'] ?? 0}') ?? 0;
          final qtyB = (b['quantity'] ?? b['stock'] ?? 0) is int
              ? (b['quantity'] ?? b['stock'] ?? 0) as int
              : int.tryParse('${b['quantity'] ?? b['stock'] ?? 0}') ?? 0;
          return qtyA.compareTo(qtyB);
        case 'newest':
        default:
          final timestampA = a['timestamp'] as Timestamp?;
          final timestampB = b['timestamp'] as Timestamp?;
          if (timestampA == null && timestampB == null) return 0;
          if (timestampA == null) return 1;
          if (timestampB == null) return -1;
          return timestampB.compareTo(timestampA);
      }
    });

    return list;
  }

  List<String> _availableCategories() {
    final categories = _products
        .map((p) => (p['category'] ?? '').toString())
        .where((c) => c.isNotEmpty)
        .toSet();
    final list = categories.toList()..sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.whisper,
      appBar: AppBar(
        title: Text(
          _selectionMode ? '${_selectedProductIds.length} Selected' : 'My Products',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: AppTheme.angel,
        elevation: 0,
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              )
            : null,
        actions: [
          if (_selectionMode) ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'activate':
                    _bulkUpdateStatus(true);
                    break;
                  case 'deactivate':
                    _bulkUpdateStatus(false);
                    break;
                  case 'delete':
                    _bulkDelete();
                    break;
                  case 'select_all':
                    _selectAllFiltered();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'activate', child: Text('Activate All')),
                const PopupMenuItem(value: 'deactivate', child: Text('Deactivate All')),
                const PopupMenuItem(value: 'delete', child: Text('Delete All')),
                const PopupMenuItem(value: 'select_all', child: Text('Select All Visible')),
              ],
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadProducts,
              tooltip: 'Refresh',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.deepTeal))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        _buildStatsHeader(),
                        const SizedBox(height: 8),
                        _buildSearchAndFilters(),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadProducts,
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: MediaQuery.of(context).size.width < 600 ? 1 : 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: MediaQuery.of(context).size.width < 600 ? 0.75 : 1.0,
                              ),
                              itemCount: _filteredAndSortedProducts().length,
                              itemBuilder: (context, index) => _buildModernProductCard(index),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildModernProductCard(int index) {
    final product = _filteredAndSortedProducts()[index];
    final String id = product['id'] as String;
    
    return ModernProductCard(
      product: product,
      id: id,
      isSelected: _selectedProductIds.contains(id),
      selectionMode: _selectionMode,
      onTap: () {
        if (_selectionMode) {
          _toggleSelect(id);
        } else {
          _editProduct(product);
        }
      },
      onLongPress: () {
        setState(() => _selectionMode = true);
        _toggleSelect(id);
      },
      onToggleStatus: _toggleStatus,
      onUpdateQuantity: _updateQuantity,
      onEdit: _editProduct,
      onDelete: _deleteProduct,
      onToggleSelect: _toggleSelect,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.deepTeal.withOpacity(0.1), AppTheme.breeze.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppTheme.deepTeal.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Ready to Start Selling?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepTeal,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Upload your first product and start your marketplace journey',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/upload_product'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.deepTeal,
              foregroundColor: AppTheme.angel,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            icon: const Icon(Icons.add_circle),
            label: const Text('Add Your First Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    final totalProducts = _products.length;
    final activeProducts = _products.where((p) => (p['status'] ?? 'active') == 'active').length;
    final lowStockProducts = _products.where((p) {
      final qty = (p['quantity'] ?? p['stock'] ?? 0) is int 
          ? (p['quantity'] ?? p['stock'] ?? 0) as int 
          : int.tryParse('${p['quantity'] ?? p['stock'] ?? 0}') ?? 0;
      return qty > 0 && qty <= 5;
    }).length;
    final outOfStockProducts = _products.where((p) {
      final qty = (p['quantity'] ?? p['stock'] ?? 0) is int 
          ? (p['quantity'] ?? p['stock'] ?? 0) as int 
          : int.tryParse('${p['quantity'] ?? p['stock'] ?? 0}') ?? 0;
      
      // 🚀 DEBUG: Log stock comparison for first few products
      if (_products.indexOf(p) < 3) {
        print('🔍 SELLER STOCK DEBUG for ${p['name'] ?? 'Unknown'}:');
        print('   - Product ID: ${p['id']}');
        print('   - Raw quantity: ${p['quantity']} (${p['quantity'].runtimeType})');
        print('   - Raw stock: ${p['stock']} (${p['stock'].runtimeType})');
        print('   - Resolved qty: $qty');
        print('   - Is out of stock: ${qty == 0}');
        print('   - Has quantity field: ${p.containsKey('quantity')}');
        print('   - Has stock field: ${p.containsKey('stock')}');
      }
      
      return qty == 0;
    }).length;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.deepTeal, AppTheme.breeze],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('Total', '$totalProducts', Icons.inventory_2, Colors.white)),
          Expanded(child: _buildStatCard('Active', '$activeProducts', Icons.visibility, Colors.white)),
          Expanded(child: _buildStatCard('Low Stock', '$lowStockProducts', Icons.warning, Colors.orange)),
          Expanded(child: _buildStatCard('Out of Stock', '$outOfStockProducts', Icons.remove_circle, Colors.red)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 720;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.complementaryElevation,
          ),
          child: Column(
            children: [
              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.deepTeal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.deepTeal),
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 16),
              // Filters
              if (!isNarrow) ..._buildFiltersContent(isNarrow: false)
              else
                ElevatedButton.icon(
                  onPressed: _showFiltersBottomSheet,
                  icon: const Icon(Icons.tune),
                  label: Text('Filters${_filterCategory.isNotEmpty || _lowStockOnly ? ' (${(_filterCategory.isNotEmpty ? 1 : 0) + (_lowStockOnly ? 1 : 0)})' : ''}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deepTeal,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildFiltersContent({required bool isNarrow}) {
    if (isNarrow) {
      return [
        // Stack vertically to avoid horizontal overflow
        DropdownButtonFormField<String>(
          value: _filterCategory.isEmpty ? null : _filterCategory,
          decoration: InputDecoration(
            labelText: 'Category',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('All Categories')),
            ..._availableCategories().map((cat) => DropdownMenuItem(value: cat, child: Text(cat))),
          ],
          onChanged: (value) => setState(() => _filterCategory = value ?? ''),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _sortBy,
          decoration: InputDecoration(
            labelText: 'Sort By',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: const [
            DropdownMenuItem(value: 'newest', child: Text('Newest First')),
            DropdownMenuItem(value: 'name', child: Text('Name A-Z')),
            DropdownMenuItem(value: 'price', child: Text('Price Low-High')),
            DropdownMenuItem(value: 'stock', child: Text('Stock Low-High')),
          ],
          onChanged: (value) => setState(() => _sortBy = value ?? 'newest'),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          title: const Text('Low Stock Only'),
          value: _lowStockOnly,
          onChanged: (value) => setState(() => _lowStockOnly = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: AppTheme.deepTeal,
        ),
      ];
    }

    // Wide layout: two columns
    return [
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _filterCategory.isEmpty ? null : _filterCategory,
              decoration: InputDecoration(
                labelText: 'Category',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('All Categories')),
                ..._availableCategories().map((cat) => DropdownMenuItem(value: cat, child: Text(cat))),
              ],
              onChanged: (value) => setState(() => _filterCategory = value ?? ''),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _sortBy,
              decoration: InputDecoration(
                labelText: 'Sort By',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'newest', child: Text('Newest First')),
                DropdownMenuItem(value: 'name', child: Text('Name A-Z')),
                DropdownMenuItem(value: 'price', child: Text('Price Low-High')),
                DropdownMenuItem(value: 'stock', child: Text('Stock Low-High')),
              ],
              onChanged: (value) => setState(() => _sortBy = value ?? 'newest'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      CheckboxListTile(
        title: const Text('Low Stock Only'),
        value: _lowStockOnly,
        onChanged: (value) => setState(() => _lowStockOnly = value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        activeColor: AppTheme.deepTeal,
      ),
    ];
  }

  void _showFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              ..._buildFiltersContent(isNarrow: true),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check),
                  label: const Text('Apply Filters'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deepTeal, foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget? get floatingActionButton {
    if (_selectionMode) return null;
    return FloatingActionButton.extended(
      onPressed: () => Navigator.pushNamed(context, '/upload_product'),
      backgroundColor: AppTheme.deepTeal,
      foregroundColor: AppTheme.angel,
      icon: const Icon(Icons.add),
      label: const Text('Add Product'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
    );
  }
}
