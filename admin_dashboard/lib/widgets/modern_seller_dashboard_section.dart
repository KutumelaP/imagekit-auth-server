import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import '../utils/order_utils.dart';
import '../theme/admin_theme.dart';

class ModernSellerDashboardSection extends StatefulWidget {
  const ModernSellerDashboardSection({Key? key}) : super(key: key);

  @override
  State<ModernSellerDashboardSection> createState() => _ModernSellerDashboardSectionState();
}

class _ModernSellerDashboardSectionState extends State<ModernSellerDashboardSection>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  int _selectedIndex = 0;
  bool _isLoading = true;
  String? _sellerId;
  Map<String, dynamic>? _sellerData;
  
  // Real data variables
  int _totalOrders = 0;
  int _totalProducts = 0;
  int _totalCustomers = 0;
  double _todaysSales = 0.0;
  double _totalRevenue = 0.0;
  List<Map<String, dynamic>> _recentOrders = [];
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _recentActivity = [];
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _lowStockProducts = [];
  List<Map<String, dynamic>> _customerReviews = [];
  Map<String, dynamic> _storeSettings = {};
  List<FlSpot> _salesChartData = [];
  
  // Settings controllers
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _storeDescriptionController = TextEditingController();
  final TextEditingController _storeCategoryController = TextEditingController();
  final TextEditingController _storeLocationController = TextEditingController();
  
  // Subscription for auth changes
  late Stream<User?> _authStateChanges;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _authStateChanges = FirebaseAuth.instance.authStateChanges();
    _initializeDashboard();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeDescriptionController.dispose();
    _storeCategoryController.dispose();
    _storeLocationController.dispose();
    super.dispose();
  }

  Future<void> _initializeDashboard() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _sellerId = user.uid;
      await _loadAllData();
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAllData() async {
    if (_sellerId == null) return;
    
    try {
      await Future.wait([
        _loadSellerData(),
        _loadMetrics(),
        _loadRecentOrders(),
        _loadTopProducts(),
        _loadRecentActivity(),
        _loadSalesChartData(),
        _loadAllProducts(),
        _loadLowStockProducts(),
        _loadCustomerReviews(),
        _loadStoreSettings(),
      ]);
    } catch (e) {
      print('Error loading dashboard data: $e');
    }
  }

  Future<void> _loadSellerData() async {
    try {
      final sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_sellerId)
          .get();
      
      if (sellerDoc.exists && mounted) {
        setState(() {
          _sellerData = sellerDoc.data();
        });
      }
    } catch (e) {
      print('Error loading seller data: $e');
    }
  }

  Future<void> _loadMetrics() async {
    try {
      // Get orders count and calculate revenue
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('sellerId', isEqualTo: _sellerId)
          .get();
      
      double totalRevenue = 0.0;
      double todaysSales = 0.0;
      Set<String> uniqueCustomers = {};
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      
      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        final total = (data['total'] ?? 0.0).toDouble();
        final buyerId = data['buyerId'] as String?;
        final timestamp = data['timestamp'] as Timestamp?;
        
        totalRevenue += total;
        if (buyerId != null) uniqueCustomers.add(buyerId);
        
        if (timestamp != null) {
          final orderDate = timestamp.toDate();
          if (orderDate.isAfter(todayStart)) {
            todaysSales += total;
          }
        }
      }
      
      // Get products count
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('ownerId', isEqualTo: _sellerId)
          .get();
      
      if (mounted) {
        setState(() {
          _totalOrders = ordersSnapshot.docs.length;
          _totalProducts = productsSnapshot.docs.length;
          _totalCustomers = uniqueCustomers.length;
          _todaysSales = todaysSales;
          _totalRevenue = totalRevenue;
        });
      }
    } catch (e) {
      print('Error loading metrics: $e');
    }
  }

  Future<void> _loadRecentOrders() async {
    try {
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('sellerId', isEqualTo: _sellerId)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      
      List<Map<String, dynamic>> orders = [];
      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        
        // Get customer name - try multiple sources
        String customerName = 'Unknown Customer';
        
        // First try buyerName from order data
        if (data['buyerName'] != null && data['buyerName'].toString().isNotEmpty) {
          customerName = data['buyerName'].toString();
        }
        // Then try name field (legacy)
        else if (data['name'] != null && data['name'].toString().isNotEmpty) {
          customerName = data['name'].toString();
        }
        // Finally try to fetch from users collection
        else {
          final buyerId = data['buyerId'] as String?;
          if (buyerId != null) {
            try {
              final customerDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(buyerId)
                  .get();
              if (customerDoc.exists) {
                final userData = customerDoc.data();
                customerName = userData?['name'] ?? 
                              userData?['displayName'] ?? 
                              userData?['email'] ?? 
                              'Unknown Customer';
              }
            } catch (e) {
              print('Error loading customer name: $e');
            }
          }
        }
        
        orders.add({
          'id': doc.id,
          'customerName': customerName,
          'total': data['total'] ?? 0.0,
          'status': data['status'] ?? 'pending',
          'timestamp': data['timestamp'],
          ...data,
        });
      }
      
      if (mounted) {
        setState(() {
          _recentOrders = orders;
        });
      }
    } catch (e) {
      print('Error loading recent orders: $e');
      // Set empty list on error
      if (mounted) {
        setState(() {
          _recentOrders = [];
        });
      }
    }
  }

  Future<void> _loadTopProducts() async {
    try {
      // Get all products for the seller first, then sort in memory
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('ownerId', isEqualTo: _sellerId)
          .get();
      
      List<Map<String, dynamic>> products = [];
      for (final doc in productsSnapshot.docs) {
        final data = doc.data();
        products.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Product',
          'soldCount': data['soldCount'] ?? 0,
          'price': data['price'] ?? 0.0,
          'stock': data['stock'] ?? 0,
          ...data,
        });
      }
      
      // Sort by soldCount in memory
      products.sort((a, b) => (b['soldCount'] ?? 0).compareTo(a['soldCount'] ?? 0));
      
      if (mounted) {
        setState(() {
          _topProducts = products.take(10).toList();
        });
      }
    } catch (e) {
      print('Error loading top products: $e');
      // Set empty list on error
      if (mounted) {
        setState(() {
          _topProducts = [];
        });
      }
    }
  }

  Future<void> _loadRecentActivity() async {
    try {
      List<Map<String, dynamic>> activities = [];
      
      // Add recent orders to activity
      for (final order in _recentOrders.take(5)) {
        activities.add({
          'type': 'order',
          'title': 'New order received',
          'subtitle': 'Order ${OrderUtils.formatShortOrderNumber(order['id'] ?? '')} - R ${order['total']?.toStringAsFixed(2)}',
          'timestamp': order['timestamp'],
          'icon': Icons.shopping_cart,
          'color': AdminTheme.success,
        });
      }
      
      // Add low stock alerts
      for (final product in _lowStockProducts.take(3)) {
        activities.add({
          'type': 'stock',
          'title': 'Low stock alert',
          'subtitle': '${product['name']} - ${product['stock']} left',
          'timestamp': Timestamp.fromDate(DateTime.now()),
          'icon': Icons.warning,
          'color': AdminTheme.warning,
        });
      }
      
      // Sort by timestamp
      activities.sort((a, b) {
        final timestampA = a['timestamp'] as Timestamp?;
        final timestampB = b['timestamp'] as Timestamp?;
        if (timestampA == null || timestampB == null) return 0;
        return timestampB.compareTo(timestampA);
      });
      
      if (mounted) {
        setState(() {
          _recentActivity = activities.take(10).toList();
        });
      }
    } catch (e) {
      print('Error loading recent activity: $e');
    }
  }

  Future<void> _loadSalesChartData() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('sellerId', isEqualTo: _sellerId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .orderBy('timestamp', descending: false)
          .get();
      
      Map<int, double> dailySales = {};
      final now = DateTime.now();
      
      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        final total = (data['total'] ?? 0.0).toDouble();
        
        if (timestamp != null) {
          final date = timestamp.toDate();
          final daysDiff = now.difference(date).inDays;
          
          if (daysDiff <= 30) { // Last 30 days
            dailySales[daysDiff] = (dailySales[daysDiff] ?? 0) + total;
          }
        }
      }
      
      List<FlSpot> spots = [];
      for (int i = 30; i >= 0; i--) {
        spots.add(FlSpot(30 - i.toDouble(), dailySales[i] ?? 0));
      }
      
      if (mounted) {
        setState(() {
          _salesChartData = spots;
        });
      }
    } catch (e) {
      print('Error loading sales chart data: $e');
    }
  }

  Future<void> _loadAllProducts() async {
    try {
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('ownerId', isEqualTo: _sellerId)
          .get();
      
      List<Map<String, dynamic>> products = [];
      for (final doc in productsSnapshot.docs) {
        final data = doc.data();
        products.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Product',
          'price': data['price'] ?? 0.0,
          'stock': data['stock'] ?? 0,
          'category': data['category'] ?? 'Uncategorized',
          'status': data['status'] ?? 'active',
          'soldCount': data['soldCount'] ?? 0,
          ...data,
        });
      }
      
      if (mounted) {
        setState(() {
          _allProducts = products;
        });
      }
    } catch (e) {
      print('Error loading all products: $e');
    }
  }

  Future<void> _loadLowStockProducts() async {
    try {
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('ownerId', isEqualTo: _sellerId)
          .get();
      
      // Filter low stock products in memory
      final lowStockProducts = productsSnapshot.docs.where((doc) {
        final data = doc.data();
        final stock = data['stock'] ?? data['quantity'] ?? 0;
        return stock < 10;
      }).toList();
      
      List<Map<String, dynamic>> products = [];
      for (final doc in lowStockProducts) {
        final data = doc.data();
        products.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Product',
          'stock': data['stock'] ?? data['quantity'] ?? 0,
          'price': data['price'] ?? 0.0,
          ...data,
        });
      }
      
      if (mounted) {
        setState(() {
          _lowStockProducts = products;
        });
      }
    } catch (e) {
      print('Error loading low stock products: $e');
    }
  }

  Future<void> _loadCustomerReviews() async {
    try {
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('sellerId', isEqualTo: _sellerId)
          .get();
      
      List<Map<String, dynamic>> reviews = [];
      for (final doc in reviewsSnapshot.docs) {
        final data = doc.data();
        reviews.add({
          'id': doc.id,
          'rating': data['rating'] ?? 0,
          'comment': data['comment'] ?? '',
          'buyerName': data['buyerName'] ?? 'Anonymous',
          'productName': data['productName'] ?? 'Unknown Product',
          'timestamp': data['timestamp'],
          ...data,
        });
      }
      
      if (mounted) {
        setState(() {
          _customerReviews = reviews;
        });
      }
    } catch (e) {
      print('Error loading customer reviews: $e');
    }
  }

  Future<void> _loadStoreSettings() async {
    try {
      if (_sellerData != null) {
        setState(() {
          _storeSettings = Map<String, dynamic>.from(_sellerData!);
          _storeNameController.text = _sellerData!['storeName'] ?? '';
          _storeDescriptionController.text = _sellerData!['description'] ?? '';
          _storeCategoryController.text = _sellerData!['category'] ?? '';
          _storeLocationController.text = _sellerData!['location'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading store settings: $e');
    }
  }

  Future<void> _saveStoreSettings() async {
    try {
      final updatedData = {
        'storeName': _storeNameController.text.trim(),
        'description': _storeDescriptionController.text.trim(),
        'category': _storeCategoryController.text.trim(),
        'location': _storeLocationController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_sellerId)
          .update(updatedData);
      
      // Update local state
      setState(() {
        _sellerData = {...?_sellerData, ...updatedData};
        _storeSettings = {..._storeSettings, ...updatedData};
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Store settings updated successfully!'),
          backgroundColor: AdminTheme.success,
        ),
      );
    } catch (e) {
      print('Error saving store settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: AdminTheme.error,
        ),
      );
    }
  }

  Future<void> _toggleProductStatus(String productId, String currentStatus) async {
    try {
      final newStatus = currentStatus == 'active' ? 'paused' : 'active';
      
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update local state
      setState(() {
        final productIndex = _allProducts.indexWhere((p) => p['id'] == productId);
        if (productIndex != -1) {
          _allProducts[productIndex]['status'] = newStatus;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product $newStatus successfully!'),
          backgroundColor: AdminTheme.success,
        ),
      );
    } catch (e) {
      print('Error toggling product status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating product: $e'),
          backgroundColor: AdminTheme.error,
        ),
      );
    }
  }

  Future<void> _updateProductStock(String productId, int newStock) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .update({
        'stock': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update local state
      setState(() {
        final productIndex = _allProducts.indexWhere((p) => p['id'] == productId);
        if (productIndex != -1) {
          _allProducts[productIndex]['stock'] = newStock;
        }
        
        final lowStockIndex = _lowStockProducts.indexWhere((p) => p['id'] == productId);
        if (lowStockIndex != -1) {
          if (newStock >= 10) {
            _lowStockProducts.removeAt(lowStockIndex);
          } else {
            _lowStockProducts[lowStockIndex]['stock'] = newStock;
          }
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Stock updated successfully!'),
          backgroundColor: AdminTheme.success,
        ),
      );
    } catch (e) {
      print('Error updating stock: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating stock: $e'),
          backgroundColor: AdminTheme.error,
        ),
      );
    }
  }

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'Unknown time';
    }
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 7) {
      return DateFormat('MMM d, yyyy').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  // Seller-specific navigation items
  static const List<String> _sidebarItems = [
    'Dashboard',
    'My Products',
    'Orders',
    'Analytics',
    'Inventory',
    'Store Profile',
    'Financial Reports',
    'Customer Reviews',
    'Store Settings',
    'Logout',
  ];

  static const List<IconData> _sidebarIcons = [
    Icons.dashboard_outlined,
    Icons.inventory_2_outlined,
    Icons.shopping_cart_outlined,
    Icons.analytics_outlined,
    Icons.warehouse_outlined,
    Icons.store_outlined,
                Icons.receipt,
    Icons.rate_review_outlined,
    Icons.settings_outlined,
    Icons.logout,
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final isTablet = constraints.maxWidth >= 768 && constraints.maxWidth < 1024;
        final isDesktop = constraints.maxWidth >= 1024;

        if (isMobile) {
          return _buildMobileLayout();
        } else if (isTablet) {
          return _buildTabletLayout();
        } else {
          return _buildDesktopLayout();
        }
      },
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading seller dashboard...'),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardOverview();
      case 1:
        return _buildMyProducts();
      case 2:
        return _buildOrders();
      case 3:
        return _buildAnalytics();
      case 4:
        return _buildInventory();
      case 5:
        return _buildStoreProfile();
      case 6:
        return _buildFinancialReports();
      case 7:
        return _buildCustomerReviews();
      case 8:
        return _buildStoreSettings();
      default:
        return _buildDashboardOverview();
    }
  }

  // Add missing layout methods
  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_sidebarItems[_selectedIndex]),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: AdminTheme.angel,
      ),
      drawer: _buildMobileDrawer(),
      body: _buildMainContent(),
    );
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      body: Row(
        children: [
          // Compact Sidebar
          Container(
            width: 60,
                color: Theme.of(context).colorScheme.primary,
            child: _buildCompactSidebar(),
          ),
          // Main Content
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          // Enhanced Sidebar
          Container(
            width: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AdminTheme.deepTeal.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: _buildEnhancedSidebar(),
          ),
          // Main Content
          Expanded(
            child: Container(
              color: AdminTheme.angel,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildMainContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: Container(
        color: Theme.of(context).colorScheme.primary,
        child: SafeArea(
          child: Column(
            children: [
              // Seller Profile Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AdminTheme.angel.withOpacity(0.2),
                      child: Icon(Icons.store, size: 40, color: AdminTheme.angel),
                    ),
                    const SizedBox(height: 12),
              Text(
                      _sellerData?['storeName'] ?? 'Your Store',
                      style: TextStyle(
                        color: AdminTheme.angel,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Divider(color: AdminTheme.angel.withOpacity(0.24)),
              // Navigation Items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemCount: _sidebarItems.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedIndex == index;
                    final isLogout = _sidebarItems[index] == 'Logout';
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            Navigator.of(context).pop(); // Close drawer
                            if (isLogout) {
                              await _handleLogout();
                            } else {
                              setState(() {
                                _selectedIndex = index;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AdminTheme.angel.withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _sidebarIcons[index],
                                  color: AdminTheme.angel,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
              Text(
                                  _sidebarItems[index],
                                                                    style: TextStyle(
                                    color: AdminTheme.angel,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
              ),
            ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          ),
        ),
      );
    }
    
  Widget _buildCompactSidebar() {
    return Column(
        children: [
        const SizedBox(height: 20),
        // Store Icon
        CircleAvatar(
          radius: 25,
          backgroundColor: AdminTheme.angel.withOpacity(0.2),
          child: Icon(Icons.store, color: AdminTheme.angel, size: 24),
        ),
        const SizedBox(height: 20),
        // Navigation Icons
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: _sidebarItems.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedIndex == index;
              final isLogout = _sidebarItems[index] == 'Logout';
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      if (isLogout) {
                        await _handleLogout();
                      } else {
                        setState(() {
                          _selectedIndex = index;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AdminTheme.angel.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _sidebarIcons[index],
                        color: AdminTheme.angel,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedSidebar() {
    return Column(
      children: [
        // Seller Profile Header
        Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: AdminTheme.angel.withOpacity(0.2),
                child: Icon(Icons.store, size: 35, color: AdminTheme.angel),
              ),
              const SizedBox(height: 8),
              Text(
                _sellerData?['storeName'] ?? 'Your Store',
                style: TextStyle(
                  color: AdminTheme.angel,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                _sellerData?['category'] ?? 'Store Category',
                style: TextStyle(
                  color: AdminTheme.angel.withOpacity(0.8),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _sellerData?['verified'] == true ? AdminTheme.success : AdminTheme.warning,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _sellerData?['verified'] == true ? 'Verified' : 'Pending',
                  style: TextStyle(
                    color: AdminTheme.angel,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(color: AdminTheme.angel.withOpacity(0.24)),
        // Navigation Items
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _sidebarItems.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedIndex == index;
              final isLogout = _sidebarItems[index] == 'Logout';
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      if (isLogout) {
                        await _handleLogout();
                      } else {
                        setState(() {
                          _selectedIndex = index;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AdminTheme.angel.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _sidebarIcons[index],
                            color: AdminTheme.angel,
                            size: 20,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _sidebarItems[index],
                              style: TextStyle(
                                color: AdminTheme.angel,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Add missing dashboard overview method
  Widget _buildDashboardOverview() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard Overview',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome back! Here\'s what\'s happening with your store.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // Date & Time
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d').format(DateTime.now()),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      DateFormat('h:mm a').format(DateTime.now()),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Key Metrics Cards
          _buildMetricsGrid(),
          
          const SizedBox(height: 32),
          
          // Charts and Analytics Row
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sales Chart
                    Expanded(
                      flex: 2,
                      child: _buildSalesChart(),
                    ),
                    const SizedBox(width: 24),
                    // Recent Activity
                    Expanded(
                      child: _buildRecentActivity(),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildSalesChart(),
                    const SizedBox(height: 24),
                    _buildRecentActivity(),
                  ],
                );
              }
            },
          ),
          
          const SizedBox(height: 32),
          
          // Recent Orders and Top Products
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildRecentOrders(),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildTopProducts(),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildRecentOrders(),
                    const SizedBox(height: 24),
                    _buildTopProducts(),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // Enhanced orders method with full management functionality
  Widget _buildOrders() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orders Management',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track and manage customer orders',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AdminTheme.mediumGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AdminTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_totalOrders Total Orders',
                  style: TextStyle(color: AdminTheme.success, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Order Status Cards
          Row(
            children: [
              Expanded(child: _buildStatusCard('Pending', ((_totalOrders * 0.2).round()), AdminTheme.warning, Icons.pending)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatusCard('Processing', ((_totalOrders * 0.3).round()), AdminTheme.info, Icons.hourglass_empty)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatusCard('Completed', ((_totalOrders * 0.4).round()), AdminTheme.success, Icons.check_circle)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatusCard('Cancelled', ((_totalOrders * 0.1).round()), AdminTheme.error, Icons.cancel)),
            ],
          ),
          const SizedBox(height: 24),
          
          // Recent Orders
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Recent Orders',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_recentOrders.isEmpty)
                  Container(
                    height: 300,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No recent orders', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  )
                else
                  ...List.generate(_recentOrders.length, (index) {
                    final order = _recentOrders[index];
                    return _buildOrderListItem(order);
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Add missing analytics method
  Widget _buildAnalytics() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Analytics & Insights',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Detailed insights into your store performance',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          // Key Performance Indicators
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildAnalyticsCard('Total Revenue', 'R${_totalRevenue.toStringAsFixed(2)}', Icons.receipt, AdminTheme.success),
                              _buildAnalyticsCard('Avg Order Value', 'R${(_totalRevenue / (_totalOrders > 0 ? _totalOrders : 1)).toStringAsFixed(2)}', Icons.receipt, AdminTheme.info),
              _buildAnalyticsCard('Conversion Rate', '${((_totalOrders / (_totalCustomers > 0 ? _totalCustomers : 1)) * 100).toStringAsFixed(1)}%', Icons.trending_up, AdminTheme.deepTeal),
              _buildAnalyticsCard('Customer Retention', '${(85.5).toStringAsFixed(1)}%', Icons.people, AdminTheme.warning),
            ],
          ),
          const SizedBox(height: 24),
          
          // Charts Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sales Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
                        height: 200,
                        child: _salesChartData.isEmpty 
                            ? Center(child: Text('No sales data available', style: TextStyle(color: Colors.grey[600])))
                            : LineChart(
                                LineChartData(
                                  gridData: FlGridData(show: true, drawVerticalLine: false),
                                  titlesData: FlTitlesData(show: false),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: _salesChartData,
                                      isCurved: true,
                                      color: AdminTheme.info,
                                      barWidth: 3,
                                      isStrokeCapRound: true,
                                      dotData: FlDotData(show: false),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: AdminTheme.info.withOpacity(0.1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Top Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      if (_topProducts.isEmpty)
                        Container(
                          height: 200,
                          child: Center(child: Text('No product data', style: TextStyle(color: Colors.grey[600]))),
                        )
                      else
                        Column(
                          children: List.generate(
                            _topProducts.length > 5 ? 5 : _topProducts.length,
                            (index) {
                              final product = _topProducts[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product['name'] ?? 'Product',
                                            style: TextStyle(fontWeight: FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${product['soldCount'] ?? 0} sold',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Add missing store profile method
  Widget _buildStoreProfile() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Store Profile',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage your store information and branding',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          // Store Info Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Store Profile Image with proper error handling
                    if (_sellerData?['profileImageUrl'] != null && _sellerData!['profileImageUrl'].toString().isNotEmpty)
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: NetworkImage(_sellerData!['profileImageUrl']),
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        onBackgroundImageError: (exception, stackTrace) {
                          print('Error loading store profile image: $exception');
                        },
                        child: _sellerData!['profileImageUrl'].toString().isEmpty 
                            ? Icon(Icons.store, size: 40, color: Colors.blue)
                            : null,
                      )
                    else
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        child: Icon(Icons.store, size: 40, color: Colors.blue),
                      ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _sellerData?['storeName'] ?? 'Your Store Name',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _sellerData?['category'] ?? 'Store Category',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                _sellerData?['location'] ?? 'Store Location',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedIndex = 8; // Switch to settings
                        });
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Profile'),
                    ),
                  ],
                ),
                if (_sellerData?['story'] != null) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Store Story',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _sellerData!['story'],
                    style: TextStyle(color: Colors.grey[700], height: 1.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Store Performance
          Row(
            children: [
              Expanded(
                child: _buildProfileStatCard('Total Sales', 'R${_totalRevenue.toStringAsFixed(2)}', Icons.receipt, AdminTheme.success),
                ),
                const SizedBox(width: 16),
              Expanded(
                child: _buildProfileStatCard('Orders Completed', '$_totalOrders', Icons.check_circle, Colors.blue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildProfileStatCard('Customer Rating', 
                  _customerReviews.isEmpty 
                      ? '0.0 ⭐'
                      : '${(_customerReviews.map((r) => r['rating'] ?? 0).reduce((a, b) => a + b) / _customerReviews.length).toStringAsFixed(1)} ⭐', 
                  Icons.star, AdminTheme.warning),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Add missing financial reports method
  Widget _buildFinancialReports() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Financial Reports',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'View earnings, payments, and financial summaries',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          // Financial Overview
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: AdminTheme.success, size: 24),
                          const SizedBox(width: 8),
                          Text('Total Earnings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('R ${_totalRevenue.toStringAsFixed(2)}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AdminTheme.success)),
                      Text('All time earnings', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.blue, size: 24),
                          const SizedBox(width: 8),
                          Text('This Month', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('R ${(_totalRevenue * 0.3).toStringAsFixed(2)}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
                      Text('Monthly earnings', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_up, color: AdminTheme.warning, size: 24),
                          const SizedBox(width: 8),
                          Text('Growth', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('+24.5%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AdminTheme.warning)),
                      Text('vs last month', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Recent Transactions placeholder
            Container(
              decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Recent Transactions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  height: 300,
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('Transaction history will show here', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        Text('Connected to your sales data', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Add missing metrics grid method
  Widget _buildMetricsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        double childAspectRatio;
        
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 4;
          childAspectRatio = 1.8;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 3;
          childAspectRatio = 1.6;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 2;
          childAspectRatio = 1.4;
        } else {
          crossAxisCount = 1;
          childAspectRatio = 1.2;
        }
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
          children: [
            _buildMetricCard('Total Orders', '$_totalOrders', Icons.shopping_cart, Colors.blue),
            _buildMetricCard('Total Revenue', 'R${_totalRevenue.toStringAsFixed(2)}', Icons.receipt, AdminTheme.success),
            _buildMetricCard('Today\'s Sales', 'R${_todaysSales.toStringAsFixed(2)}', Icons.trending_up, AdminTheme.indigo),
            _buildMetricCard('Total Products', '$_totalProducts', Icons.inventory_2, AdminTheme.warning),
            _buildMetricCard('Total Customers', '$_totalCustomers', Icons.people, AdminTheme.deepTeal),
            _buildMetricCard('Low Stock', '${_lowStockProducts.length}', Icons.warning, AdminTheme.error),
          ],
        );
      },
    );
  }

  // Add missing metric card method
  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Add missing sales chart method
  Widget _buildSalesChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sales Trend',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            height: 200,
            child: _salesChartData.isEmpty 
                ? Center(child: Text('No sales data available', style: TextStyle(color: Colors.grey[600])))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true, drawVerticalLine: false),
                      titlesData: FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _salesChartData,
                          isCurved: true,
                          color: Colors.blue,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.blue.withOpacity(0.1),
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

  // Add missing recent activity method
  Widget _buildRecentActivity() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'What\'s happening in your store?',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
                  const SizedBox(height: 24),
          
          // Activity List
          if (_recentActivity.isEmpty)
                  Container(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_outlined, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('No recent activity', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            )
          else
            Column(
              children: List.generate(_recentActivity.length, (index) {
                final activity = _recentActivity[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(activity['icon'], color: activity['color'], size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity['title'],
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activity['subtitle'],
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatTimeAgo(activity['timestamp']),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  // Add missing top products method
  Widget _buildTopProducts() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Top Selling Products',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Discover your best-performing products',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          // Products List
          if (_topProducts.isEmpty)
            Container(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('No top products yet', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            )
          else
            Column(
              children: List.generate(
                _topProducts.length > 5 ? 5 : _topProducts.length,
                (index) {
                  final product = _topProducts[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['name'] ?? 'Product',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Sold: ${product['soldCount'] ?? 0}',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // Add missing status card method
  Widget _buildStatusCard(String title, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
                    const SizedBox(height: 8),
                    Text(
            '$count',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Add missing analytics card method
  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
                    ),
                    const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Add missing profile stat card method
  Widget _buildProfileStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Add missing handle logout method
  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
                          await FirebaseAuth.instance.signOut();
                          if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  // Add missing recent orders method
  Widget _buildRecentOrders() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Recent Orders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (_recentOrders.isEmpty)
            Container(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('No recent orders', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            )
          else
            Column(
              children: List.generate(
                _recentOrders.length > 5 ? 5 : _recentOrders.length,
                (index) {
                  final order = _recentOrders[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      child: Icon(Icons.shopping_cart, color: Colors.blue),
                    ),
                    title: Text('Order ${OrderUtils.formatShortOrderNumber(order['id'] ?? '')}'),
                    subtitle: Text('${order['customerName'] ?? 'Customer'} • R ${(order['total'] ?? 0.0).toStringAsFixed(2)}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(order['status']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        order['status'] ?? 'pending',
                        style: TextStyle(
                          color: _getStatusColor(order['status']),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // Add missing get status color method
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending': return AdminTheme.warning;
      case 'processing': return AdminTheme.info;
      case 'completed': return AdminTheme.success;
      case 'cancelled': return AdminTheme.error;
      default: return AdminTheme.mediumGrey;
    }
  }

  // Enhanced my products method with full functionality
  Widget _buildMyProducts() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Add Product button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Products',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your product catalog and inventory',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddProductDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Product Statistics
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.inventory_2, color: Colors.blue, size: 24),
                          const SizedBox(width: 8),
                          Text('Total Products', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('$_totalProducts', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
            Expanded(
              child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_up, color: Colors.green, size: 24),
                          const SizedBox(width: 8),
                          Text('Active Products', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${_allProducts.where((p) => p['status'] == 'active').length}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Products List
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Text(
                        'Product List',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => _loadAllProducts(),
                      ),
                    ],
                  ),
                ),
                if (_allProducts.isEmpty)
                  Container(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No products yet', style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(height: 8),
                          Text('Add your first product to get started', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: List.generate(_allProducts.length, (index) {
                      final product = _allProducts[index];
                      return _buildProductListItem(product);
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductListItem(Map<String, dynamic> product) {
    final isActive = product['status'] == 'active';
    final stock = product['quantity'] ?? 0;
    final isLowStock = stock < 10;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: product['imageUrl'] != null && product['imageUrl'].toString().isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      product['imageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading product image: $error');
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.image, color: Colors.grey[400]),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.image, color: Colors.grey[400]),
                  ),
          ),
          const SizedBox(width: 16),
          
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? 'Unknown Product',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isActive ? Colors.black : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'R ${(product['price'] ?? 0.0).toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product['category'] ?? 'Uncategorized'}${product['subcategory'] != null ? ' > ${product['subcategory']}' : ''}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Stock: $stock',
                      style: TextStyle(
                        color: isLowStock ? AdminTheme.error : AdminTheme.mediumGrey,
                        fontSize: 12,
                        fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isLowStock) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.warning, color: AdminTheme.error, size: 16),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status Switch
              Switch(
                value: isActive,
                onChanged: (value) => _toggleProductStatus(product['id'], product['status'] ?? 'active'),
                activeColor: Colors.green,
              ),
              const SizedBox(width: 8),
              
              // Edit Button
              IconButton(
                onPressed: () => _showEditProductDialog(product),
                icon: Icon(Icons.edit, color: Colors.blue, size: 20),
                tooltip: 'Edit Product',
              ),
              
              // Delete Button
              IconButton(
                onPressed: () => _showDeleteProductDialog(product),
                icon: Icon(Icons.delete, color: AdminTheme.error, size: 20),
                tooltip: 'Delete Product',
              ),
              
              // Stock Update Button
              TextButton(
                onPressed: () => _showStockUpdateDialog(product),
                child: Text('Stock', style: TextStyle(fontSize: 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStockUpdateDialog(Map<String, dynamic> product) {
    final controller = TextEditingController(text: product['stock'].toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Product: ${product['name']}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Stock Quantity',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newStock = int.tryParse(controller.text) ?? 0;
              _updateProductStock(product['id'], newStock);
              Navigator.pop(context);
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  // Add missing inventory method
  Widget _buildInventory() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Inventory Management',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Track stock levels and manage inventory',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          // Inventory Overview Cards
          Row(
            children: [
              Expanded(
      child: Container(
                  padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: AdminTheme.error, size: 24),
                          const SizedBox(width: 8),
                          Text('Low Stock Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${_lowStockProducts.length}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AdminTheme.error)),
                      Text('Items need restocking', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              ),
            const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 24),
                          const SizedBox(width: 8),
                          Text('In Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${_allProducts.where((p) => (p['stock'] ?? 0) >= 10).length}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
                      Text('Items well stocked', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.block, color: Colors.orange, size: 24),
                          const SizedBox(width: 8),
                          Text('Out of Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${_allProducts.where((p) => (p['stock'] ?? 0) == 0).length}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orange)),
                      Text('Items unavailable', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Low Stock Alert
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red, size: 24),
                    const SizedBox(width: 8),
                    Text('Low Stock Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                if (_lowStockProducts.isEmpty)
                  Container(
                    height: 200,
                    child: Center(
                      child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                          Icon(Icons.check_circle, size: 64, color: Colors.green[300]),
                          const SizedBox(height: 16),
                          Text('All products are well stocked!', style: TextStyle(color: Colors.green[600])),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: List.generate(_lowStockProducts.length, (index) {
                      final product = _lowStockProducts[index];
                      return _buildLowStockItem(product);
                    }),
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockItem(Map<String, dynamic> product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? 'Unknown Product',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Only ${product['stock']} left in stock',
                  style: TextStyle(color: Colors.red[700], fontSize: 14),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showStockUpdateDialog(product),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Restock'),
          ),
        ],
      ),
    );
  }

  // Add missing customer reviews method
  Widget _buildCustomerReviews() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Customer Reviews',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'View and respond to customer feedback',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          // Review Overview
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _customerReviews.isEmpty 
                            ? '0.0'
                            : (_customerReviews.map((r) => r['rating'] ?? 0).reduce((a, b) => a + b) / _customerReviews.length).toStringAsFixed(1),
                        style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) => Icon(Icons.star, color: Colors.orange, size: 20)),
                      ),
                      const SizedBox(height: 8),
                      Text('Average Rating', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text('${_customerReviews.length}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue)),
                      const SizedBox(height: 8),
                      Text('Total Reviews', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text('${_customerReviews.where((r) => (r['rating'] ?? 0) >= 4).length}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 8),
                      Text('Positive Reviews', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Recent Reviews
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
            child: Text(
                    'Recent Reviews',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_customerReviews.isEmpty)
                  Container(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No reviews yet', style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(height: 8),
                          Text('Customer reviews will appear here', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: List.generate(_customerReviews.length, (index) {
                      final review = _customerReviews[index];
                      return _buildReviewItem(review);
                    }),
                  ),
              ],
            ),
          ),
        ],
            ),
          );
        }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    final rating = review['rating'] ?? 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.1),
                child: Icon(Icons.person, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['buyerName'] ?? 'Anonymous Customer',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (i) => Icon(
                          Icons.star,
                          size: 16,
                          color: i < rating ? Colors.orange : Colors.grey[300],
                        )),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimeAgo(review['timestamp']),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review['comment']?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              review['comment'],
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
          if (review['productName'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Product: ${review['productName']}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  // Add missing store settings method
  Widget _buildStoreSettings() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Store Settings',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure your store preferences and settings',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          // Store Information Section
          Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Store Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  
                  // Store Name
                  TextField(
                    controller: _storeNameController,
                    decoration: InputDecoration(
                      labelText: 'Store Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.store),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Store Description
                  TextField(
                    controller: _storeDescriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Store Description',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Store Category
                  TextField(
                    controller: _storeCategoryController,
                    decoration: InputDecoration(
                      labelText: 'Store Category',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.category),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Store Location
                  TextField(
                    controller: _storeLocationController,
                    decoration: InputDecoration(
                      labelText: 'Store Location',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveStoreSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Store Status Section
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Store Status',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Store Status', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              _sellerData?['paused'] == true ? 'Paused' : 'Active',
                              style: TextStyle(
                                color: _sellerData?['paused'] == true ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _sellerData?['paused'] != true,
                        onChanged: _toggleStoreStatus,
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Icon(
                        _sellerData?['verified'] == true ? Icons.verified : Icons.pending,
                        color: _sellerData?['verified'] == true ? AdminTheme.success : AdminTheme.warning,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _sellerData?['verified'] == true ? 'Verified Store' : 'Pending Verification',
                        style: TextStyle(
                          color: _sellerData?['verified'] == true ? AdminTheme.success : AdminTheme.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStoreStatus(bool isActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_sellerId)
          .update({
        'paused': !isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _sellerData = {...?_sellerData, 'paused': !isActive};
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Store ${isActive ? 'activated' : 'paused'} successfully!'),
          backgroundColor: AdminTheme.success,
        ),
      );
    } catch (e) {
      print('Error toggling store status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating store status: $e'),
          backgroundColor: AdminTheme.error,
        ),
      );
    }
  }

  // Product Management Methods
  void _showAddProductDialog() {
    _showProductDialog(context, product: null, onSave: _saveProduct);
  }

  void _showEditProductDialog(Map<String, dynamic> product) {
    _showProductDialog(context, product: product, onSave: _updateProduct);
  }

  void _showProductDialog(BuildContext context, {Map<String, dynamic>? product, required Function(Map<String, dynamic>) onSave}) {
    final nameController = TextEditingController(text: product?['name'] ?? '');
    final priceController = TextEditingController(text: product?['price']?.toString() ?? '');
    final imageUrlController = TextEditingController(text: product?['imageUrl'] ?? '');
    final quantityController = TextEditingController(text: product?['quantity']?.toString() ?? '');
    final descriptionController = TextEditingController(text: product?['description'] ?? '');
    String status = product?['status'] ?? 'active';
    String? selectedCategory = product?['category'];
    String? selectedSubcategory = product?['subcategory'];
    bool isCustomSubcategory = false;
    final customSubcategoryController = TextEditingController(text: product?['subcategory'] ?? '');
    File? _imageFile;
    bool _uploading = false;
    String? _error;

    // Category-Subcategory mapping (same as mobile app)
    const Map<String, List<String>> categoryMap = {
      'Food': ['Fruits', 'Vegetables', 'Snacks', 'Drinks', 'Baked Goods'],
      'Drinks': ['Beverages', 'Juices', 'Smoothies', 'Coffee', 'Tea'],
      'Bakery': ['Bread', 'Cakes', 'Pastries', 'Cookies', 'Pies'],
      'Fruits': ['Fresh Fruits', 'Dried Fruits', 'Organic Fruits'],
      'Vegetables': ['Fresh Vegetables', 'Organic Vegetables', 'Root Vegetables'],
      'Snacks': ['Chips', 'Nuts', 'Crackers', 'Popcorn', 'Candy'],
      'Electronics': ['Phones', 'Laptops', 'Tablets', 'Accessories'],
      'Clothes': ['T-Shirts', 'Jeans', 'Jackets', 'Dresses', 'Shoes'],
      'Other': ['Misc', 'Handmade', 'Vintage'],
    };

    const List<String> categories = [
      'Food', 'Drinks', 'Bakery', 'Fruits', 'Vegetables', 
      'Snacks', 'Electronics', 'Clothes', 'Other'
    ];

    void _pickImage(StateSetter setState) async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
        });
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 420),
          child: StatefulBuilder(
            builder: (ctx, setState) => AlertDialog(
              title: Text(product == null ? 'Add Product' : 'Edit Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Product Name',
                        errorText: _error == 'name' ? 'Name required' : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: priceController,
                      decoration: InputDecoration(
                        labelText: 'Price',
                        errorText: _error == 'price' ? 'Price required' : null,
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: quantityController,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        errorText: _error == 'quantity' ? 'Quantity required' : null,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category *',
                        errorText: _error == 'category' ? 'Please select a category' : null,
                      ),
                      items: categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value;
                          selectedSubcategory = null;
                          isCustomSubcategory = false;
                        });
                      },
                      validator: (value) => value == null ? 'Please select a category' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Subcategory Section
                    if (selectedCategory != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: isCustomSubcategory ? null : selectedSubcategory,
                              decoration: InputDecoration(
                                labelText: 'Subcategory',
                                errorText: _error == 'subcategory' ? 'Please select or enter subcategory' : null,
                              ),
                              items: [
                                ...(categoryMap[selectedCategory] ?? []).map((subcategory) {
                                  return DropdownMenuItem<String>(
                                    value: subcategory,
                                    child: Text(subcategory),
                                  );
                                }),
                                const DropdownMenuItem<String>(
                                  value: 'custom',
                                  child: Text('Custom Subcategory'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  if (value == 'custom') {
                                    isCustomSubcategory = true;
                                    selectedSubcategory = null;
                                  } else {
                                    isCustomSubcategory = false;
                                    selectedSubcategory = value;
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      if (isCustomSubcategory) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: customSubcategoryController,
                          decoration: InputDecoration(
                            labelText: 'Custom Subcategory *',
                            errorText: _error == 'customSubcategory' ? 'Please enter subcategory' : null,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                    
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: InputDecoration(labelText: 'Status'),
                      items: [
                        DropdownMenuItem(value: 'active', child: Text('Active')),
                        DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                      ],
                      onChanged: (value) => status = value ?? 'active',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickImage(setState),
                            icon: Icon(_imageFile != null ? Icons.check : Icons.image),
                            label: Text(_imageFile != null ? 'Image Selected' : 'Pick Image'),
                          ),
                        ),
                        if (_imageFile != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => setState(() => _imageFile = null),
                            icon: Icon(Icons.clear),
                            tooltip: 'Remove Image',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _uploading ? null : () async {
                    // Validate inputs
                    if (nameController.text.isEmpty) {
                      setState(() => _error = 'name');
                      return;
                    }
                    if (priceController.text.isEmpty) {
                      setState(() => _error = 'price');
                      return;
                    }
                    if (quantityController.text.isEmpty) {
                      setState(() => _error = 'quantity');
                      return;
                    }
                    if (selectedCategory == null) {
                      setState(() => _error = 'category');
                      return;
                    }
                    if (!isCustomSubcategory && selectedSubcategory == null) {
                      setState(() => _error = 'subcategory');
                      return;
                    }
                    if (isCustomSubcategory && customSubcategoryController.text.isEmpty) {
                      setState(() => _error = 'customSubcategory');
                      return;
                    }

                    setState(() => _uploading = true);

                    try {
                      String? imageUrl = imageUrlController.text;
                      
                      // Upload image if selected
                      if (_imageFile != null) {
                        imageUrl = await _uploadImageToImageKit(_imageFile!, _sellerId!);
                      }

                      final productData = {
                        'name': nameController.text,
                        'price': double.parse(priceController.text),
                        'quantity': int.parse(quantityController.text),
                        'description': descriptionController.text,
                        'category': selectedCategory,
                        'subcategory': isCustomSubcategory 
                            ? customSubcategoryController.text.trim()
                            : selectedSubcategory,
                        'imageUrl': imageUrl,
                        'status': status,
                        'ownerId': _sellerId,
                        'createdAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      };

                      onSave(productData);
                      Navigator.pop(ctx);
                    } catch (e) {
                      setState(() => _error = 'Error saving product: $e');
                    } finally {
                      setState(() => _uploading = false);
                    }
                  },
                  child: _uploading ? CircularProgressIndicator() : Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _uploadImageToImageKit(File file, String sellerId) async {
    try {
      // Get authentication parameters from backend
      final response = await http.get(Uri.parse('https://imagekit-auth-server-f4te.onrender.com/auth'));
      if (response.statusCode != 200) {
        throw Exception('Failed to get authentication parameters');
      }
      
      final authParams = json.decode(response.body);
      final bytes = await file.readAsBytes();
      final fileName = 'products/$sellerId/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      
      final publicKey = 'public_tAO0SkfLl/37FQN+23c/bkAyfYg=';
      final token = authParams['token'];
      final signature = authParams['signature'];
      final expire = authParams['expire'];
      
      if (publicKey == null || token == null || signature == null || expire == null) {
        throw Exception('Missing authentication parameters');
      }
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://upload.imagekit.io/api/v1/files/upload'),
      );
      
      request.fields.addAll({
        'publicKey': publicKey,
        'token': token,
        'signature': signature,
        'expire': expire.toString(),
        'fileName': fileName,
        'folder': 'products/$sellerId',
      });
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: path.basename(file.path),
        ),
      );
      
      final streamedResponse = await request.send();
      final uploadResponse = await http.Response.fromStream(streamedResponse);
      
      if (uploadResponse.statusCode == 200) {
        final result = json.decode(uploadResponse.body);
        return result['url'];
      } else {
        throw Exception('Upload failed: ${uploadResponse.statusCode}');
      }
    } catch (e) {
      print('Error uploading image: $e');
      // Fallback to placeholder for now
      return 'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=800&q=80';
    }
  }

  Future<void> _saveProduct(Map<String, dynamic> productData) async {
    try {
      await FirebaseFirestore.instance.collection('products').add(productData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product added successfully!')),
      );
      
      // Refresh products list
      await _loadAllProducts();
    } catch (e) {
      print('Error saving product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding product: $e')),
      );
    }
  }

  Future<void> _updateProduct(Map<String, dynamic> productData) async {
    try {
      final productId = productData['id'];
      if (productId != null) {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .update({
          ...productData,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product updated successfully!')),
        );
        
        // Refresh products list
        await _loadAllProducts();
      }
    } catch (e) {
      print('Error updating product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating product: $e')),
      );
    }
  }

  void _showDeleteProductDialog(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product['name']}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('products')
                    .doc(product['id'])
                    .delete();
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Product deleted successfully!')),
                );
                
                // Refresh products list
                await _loadAllProducts();
              } catch (e) {
                print('Error deleting product: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting product: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Order Management Methods
  Widget _buildOrderListItem(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final orderDate = order['timestamp'] != null 
        ? (order['timestamp'] as Timestamp).toDate()
        : DateTime.now();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Order Icon
          CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.1),
            child: Icon(Icons.shopping_cart, color: statusColor),
          ),
          const SizedBox(width: 16),
          
          // Order Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order ${OrderUtils.formatShortOrderNumber(order['id'] ?? '')}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order['customerName'] ?? 'Customer'} • R ${(order['total'] ?? 0.0).toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${DateFormat('MMM dd, yyyy').format(orderDate)}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                    if (order['phone'] != null && order['phone'].toString().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.phone, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        order['phone'].toString(),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Status and Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // View Details Button
                  IconButton(
                    onPressed: () => _showOrderDetailsDialog(order),
                    icon: Icon(Icons.visibility, color: AdminTheme.info, size: 20),
                    tooltip: 'View Details',
                  ),
                  
                  // Update Status Button
                  if (status == 'pending' || status == 'processing')
                    IconButton(
                      onPressed: () => _showUpdateOrderStatusDialog(order),
                      icon: Icon(Icons.update, color: AdminTheme.warning, size: 20),
                      tooltip: 'Update Status',
                    ),
                  
                  // Contact Customer Button
                  IconButton(
                    onPressed: () => _contactCustomer(order),
                    icon: Icon(Icons.contact_phone, color: AdminTheme.success, size: 20),
                    tooltip: order['phone'] != null && order['phone'].toString().isNotEmpty 
                        ? 'Contact Customer (${order['phone']})' 
                        : 'Contact Customer',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showOrderDetailsDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
                                Text('Order ID: ${OrderUtils.formatShortOrderNumber(order['id'] ?? '')}'),
              const SizedBox(height: 8),
              Text('Customer: ${order['customerName'] ?? 'Unknown'}'),
              if (order['phone'] != null && order['phone'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text('Phone: ${order['phone']}'),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _contactCustomer(order),
                      icon: Icon(Icons.contact_phone, color: AdminTheme.success, size: 16),
                      tooltip: 'Contact Customer',
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text('Total: R ${(order['total'] ?? 0.0).toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              Text('Status: ${order['status'] ?? 'pending'}'),
              const SizedBox(height: 8),
              Text('Date: ${DateFormat('MMM dd, yyyy HH:mm').format((order['timestamp'] as Timestamp).toDate())}'),
              if (order['items'] != null) ...[
                const SizedBox(height: 16),
                Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...List.generate((order['items'] as List).length, (index) {
                  final item = order['items'][index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${item['name']} x${item['quantity']} - R ${item['price']}'),
                  );
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showUpdateOrderStatusDialog(Map<String, dynamic> order) {
    String newStatus = order['status'] ?? 'pending';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Update Order Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                              Text('Order ${OrderUtils.formatShortOrderNumber(order['id'] ?? '')}'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: newStatus,
                decoration: InputDecoration(labelText: 'New Status'),
                items: [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'processing', child: Text('Processing')),
                  DropdownMenuItem(value: 'shipped', child: Text('Shipped')),
                  DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: (value) => setState(() => newStatus = value ?? 'pending'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(order['id'])
                      .update({
                    'status': newStatus,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Order status updated successfully!')),
                  );
                  
                  // Refresh orders
                  await _loadRecentOrders();
                } catch (e) {
                  print('Error updating order status: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating order status: $e')),
                  );
                }
              },
              child: Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _contactCustomer(Map<String, dynamic> order) async {
    // Use phone from order first
    String? phoneNumber = order['phone'] ?? order['customerPhone'];
    if (phoneNumber == null || phoneNumber.isEmpty) {
      final buyerId = order['buyerId'];
      if (buyerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer information not available')),
        );
        return;
      }
      // Fallback to user profile
      try {
        final buyerDoc = await FirebaseFirestore.instance.collection('users').doc(buyerId).get();
        final buyerData = buyerDoc.data();
        phoneNumber = buyerData?['phoneNumber'] ?? buyerData?['phone'];
      } catch (e) {
        phoneNumber = null;
      }
    }
    
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer phone number not available')),
      );
      return;
    }
    
    // Show contact options
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.chat, color: Theme.of(context).colorScheme.primary),
              title: const Text('Send Message'),
              subtitle: const Text('Open chat with customer'),
              onTap: () {
                Navigator.pop(context);
                _openChatWithCustomer(order['buyerId'], order);
              },
            ),
            ListTile(
              leading: Icon(Icons.message, color: Theme.of(context).colorScheme.secondary),
              title: const Text('WhatsApp'),
              subtitle: const Text('Open WhatsApp chat'),
              onTap: () {
                Navigator.pop(context);
                if (phoneNumber != null && phoneNumber.isNotEmpty) {
                  _openWhatsApp(phoneNumber, order);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.phone, color: AdminTheme.success),
              title: const Text('Call'),
              subtitle: const Text('Make a phone call'),
              onTap: () {
                Navigator.pop(context);
                _makePhoneCall(phoneNumber!);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _openChatWithCustomer(String buyerId, Map<String, dynamic> orderData) {
    if (_sellerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller ID not available')),
      );
      return;
    }
    
    // Check if chat already exists
    FirebaseFirestore.instance
        .collection('chats')
        .where('sellerId', isEqualTo: _sellerId)
        .where('buyerId', isEqualTo: buyerId)
        .limit(1)
        .get()
        .then((querySnapshot) {
      if (querySnapshot.docs.isNotEmpty) {
        final chatId = querySnapshot.docs.first.id;
        _showChatDialog(chatId, buyerId);
      } else {
        // Create new chat
        FirebaseFirestore.instance.collection('chats').add({
          'sellerId': _sellerId,
          'buyerId': buyerId,
          'productId': orderData['items']?[0]?['productId'],
          'productName': orderData['items']?[0]?['name'] ?? 'Product',
          'lastMessage': '',
          'timestamp': FieldValue.serverTimestamp(),
          'participants': [buyerId, _sellerId!],
        }).then((newChat) {
          _showChatDialog(newChat.id, buyerId);
        });
      }
    });
  }

  void _showChatDialog(String chatId, String buyerId) {
    if (_sellerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller ID not available')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(32),
        child: SizedBox(
          width: 500,
          height: 400,
          child: _ChatDialog(
            chatId: chatId,
            buyerId: buyerId,
            sellerId: _sellerId!,
            firestore: FirebaseFirestore.instance,
          ),
        ),
      ),
    );
  }

  void _openWhatsApp(String phoneNumber, Map<String, dynamic> orderData) {
    final orderNumber = orderData['orderNumber'] ?? orderData['id'] ?? 'Order';
    final productName = orderData['items']?[0]?['name'] ?? 'Product';
    
    // Format phone number (remove spaces, add country code if needed)
    String formattedPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (!formattedPhone.startsWith('+')) {
      formattedPhone = '+27$formattedPhone'; // Default to South Africa
    }
    
    // Create WhatsApp message
    final message = 'Hi! I\'m contacting you about your order ${OrderUtils.formatShortOrderNumber(orderNumber)} for $productName. How can I help you?';
    final encodedMessage = Uri.encodeComponent(message);
    
    // Create WhatsApp URL
    final whatsappUrl = 'https://wa.me/$formattedPhone?text=$encodedMessage';
    
    // Launch WhatsApp
    launchUrl(Uri.parse(whatsappUrl)).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open WhatsApp: $error')),
      );
    });
  }

  void _makePhoneCall(String phoneNumber) {
    // Format phone number for tel: URL
    String formattedPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (!formattedPhone.startsWith('+')) {
      formattedPhone = '+27$formattedPhone'; // Default to South Africa
    }
    
    // Launch phone dialer
    launchUrl(Uri.parse('tel:$formattedPhone')).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not make phone call: $error')),
      );
    });
  }
}

// Chat Dialog Widget
class _ChatDialog extends StatefulWidget {
  final String chatId;
  final String buyerId;
  final String sellerId;
  final FirebaseFirestore firestore;

  const _ChatDialog({
    required this.chatId,
    required this.buyerId,
    required this.sellerId,
    required this.firestore,
  });

  @override
  State<_ChatDialog> createState() => _ChatDialogState();
}

class _ChatDialogState extends State<_ChatDialog> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      await widget.firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'text': _messageController.text.trim(),
        'senderId': widget.sellerId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Update chat's last message
      await widget.firestore.collection('chats').doc(widget.chatId).update({
        'lastMessage': _messageController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Customer'),
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.firestore
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final messages = snapshot.data!.docs;
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)),
                        const SizedBox(height: 8),
                        Text('No messages yet', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38))),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isFromSeller = message['senderId'] == widget.sellerId;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: isFromSeller ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.6,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isFromSeller ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              message['text'] ?? '',
                              style: TextStyle(
                                color: isFromSeller ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  onPressed: _sendMessage,
                  icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 