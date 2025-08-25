import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
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
  
  // Payout (bank) controllers
  final TextEditingController _payoutAccountHolderController = TextEditingController();
  final TextEditingController _payoutBankNameController = TextEditingController();
  final TextEditingController _payoutAccountNumberController = TextEditingController();
  final TextEditingController _payoutBranchCodeController = TextEditingController();
  // Canonical account type keys used across app: 'cheque','savings','business'
  String _payoutAccountType = 'cheque';
  bool _loadingPayout = false;
  bool _savingPayout = false;
  // Payout balance state
  bool _loadingAvailable = false;
  bool _requestingPayout = false;
  double _availableGross = 0.0;
  double _availableCommission = 0.0;
  double _availableNet = 0.0;
  double _minPayoutAmount = 0.0;
  double _commissionPct = 0.0;
  List<Map<String, dynamic>> _payoutHistory = [];
  // Compliance & COD
  double _codOutstanding = 0.0;
  String _kycStatus = 'none';
  bool _codDisabled = false;
  
  // Subscription for auth changes
  late Stream<User?> _authStateChanges;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _authStateChanges = FirebaseAuth.instance.authStateChanges();
    _authStateChanges.listen((_) { /* keep-alive */ });
    _initializeDashboard();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeDescriptionController.dispose();
    _storeCategoryController.dispose();
    _storeLocationController.dispose();
    _payoutAccountHolderController.dispose();
    _payoutBankNameController.dispose();
    _payoutAccountNumberController.dispose();
    _payoutBranchCodeController.dispose();
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
        _loadPayoutDetails(),
        _loadAvailableBalance(),
        _loadPayoutHistory(),
        _loadComplianceAndCOD(),
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

  Future<void> _loadPayoutDetails() async {
    if (_sellerId == null) return;
    try {
      _loadingPayout = true;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_sellerId)
          .collection('payout')
          .doc('bank')
          .get();
      if (doc.exists) {
        final d = doc.data();
        if (d != null) {
          _payoutAccountHolderController.text = (d['accountHolder'] ?? '').toString();
          _payoutBankNameController.text = (d['bankName'] ?? '').toString();
          _payoutAccountNumberController.text = (d['accountNumber'] ?? '').toString();
          _payoutBranchCodeController.text = (d['branchCode'] ?? '').toString();
          // Normalize stored/display values to canonical keys
          final at = (d['accountType'] ?? _payoutAccountType).toString().toLowerCase();
          switch (at) {
            case 'cheque/current':
            case 'cheque':
            case 'current':
              _payoutAccountType = 'cheque';
              break;
            case 'savings':
              _payoutAccountType = 'savings';
              break;
            case 'business cheque':
            case 'business':
              _payoutAccountType = 'business';
              break;
            default:
              _payoutAccountType = 'cheque';
          }
        }
      }
    } catch (e) {
      print('Error loading payout details: $e');
    } finally {
      if (mounted) setState(() { _loadingPayout = false; });
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
        // final isDesktop = constraints.maxWidth >= 1024; // Not used

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
          _buildCodKycPanel(),
          const SizedBox(height: 16),
          // COD receivables summary (dues)
          FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: _sellerId == null
                ? null
                : FirebaseFirestore.instance
                    .collection('users')
                    .doc(_sellerId)
                    .collection('platform_receivables')
                    .where('status', isEqualTo: 'outstanding')
                    .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              double totalDue = 0;
              for (final d in snapshot.data!.docs) {
                totalDue += (d.data()['amount'] ?? 0.0).toDouble();
              }
              if (totalDue <= 0) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.18)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('COD fees outstanding: R${totalDue.toStringAsFixed(2)}. Settle to re-enable features.'),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        // For now, push to settings where wallet top-up is typically surfaced in the buyer app; here we just inform
                        setState(() { _selectedIndex = 8; });
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('View'),
                    ),
                  ],
                ),
              );
            },
          ),
          if ((_sellerData?['kycStatus'] ?? 'none') != 'approved') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_user, color: Colors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Identity verification required',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.orange[800]),
                        ),
                        const SizedBox(height: 4),
                        const Text('To accept Cash on Delivery and payouts, please complete KYC.'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushNamed('/kyc');
                              },
                              icon: const Icon(Icons.upload),
                              label: const Text('Complete KYC'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          // Earnings & Payouts
          Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2))],
            ),
            margin: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                  const Text('Earnings & Payouts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                            Text('Available (after commission)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            const SizedBox(height: 6),
                            Text('R ${_availableNet.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text('Gross R ${_availableGross.toStringAsFixed(2)} • Commission R ${_availableCommission.toStringAsFixed(2)} (${(_commissionPct * 100).toStringAsFixed(0)}%)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
                      const SizedBox(width: 12),
              ElevatedButton.icon(
                        onPressed: (_requestingPayout || _availableNet < _minPayoutAmount) ? null : _onRequestPayout,
                        icon: _requestingPayout
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.payments),
                        label: Text(_requestingPayout
                            ? 'Requesting...'
                            : (_availableNet < _minPayoutAmount
                                ? 'Min R ${_minPayoutAmount.toStringAsFixed(0)}'
                                : 'Request Payout')),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
              ),
            ],
          ),
                          const SizedBox(height: 16),
                Row(
                  children: [
                      TextButton.icon(onPressed: _loadAvailableBalance, icon: const Icon(Icons.refresh), label: const Text('Refresh balance')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(),
                  const SizedBox(height: 12),
                  Text('Recent Payouts', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                  if (_payoutHistory.isEmpty) Text('No payouts yet', style: TextStyle(color: Colors.grey[600])),
                  if (_payoutHistory.isNotEmpty)
                  Column(
                      children: _payoutHistory.take(5).map((p) {
                        final amount = (p['amount'] ?? 0).toDouble();
                        final status = (p['status'] ?? 'requested').toString();
                        final ref = (p['reference'] ?? '').toString();
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.receipt_long),
                          title: Text('R ${amount.toStringAsFixed(2)}  •  ${status.toUpperCase()}'),
                          subtitle: ref.isNotEmpty ? Text(ref) : null,
                        );
                      }).toList(),
                ),
              ],
            ),
          ),
          ),

          // Payout (Bank) Details Editor
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2)),
              ],
            ),
            margin: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payout (Bank) Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (_loadingPayout) ...[
                    const SizedBox(height: 8),
                    Row(children: const [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Loading payout details...'),
                    ]),
                  ],
                  const SizedBox(height: 8),
                  Text('Your details are stored securely. Required to receive payouts.', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: _payoutAccountHolderController,
                      decoration: InputDecoration(
                        labelText: 'Account Holder',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.person),
                      ),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: _payoutBankNameController,
                      decoration: InputDecoration(
                        labelText: 'Bank Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.account_balance),
                      ),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: _payoutAccountNumberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Account Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(
                      controller: _payoutBranchCodeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Branch Code',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.pin),
                      ),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: DropdownButtonFormField<String>(
                      value: const ['cheque','savings','business'].contains(_payoutAccountType) ? _payoutAccountType : 'cheque',
                      items: const [
                        DropdownMenuItem(value: 'cheque', child: Text('Cheque/Current')),
                        DropdownMenuItem(value: 'savings', child: Text('Savings')),
                        DropdownMenuItem(value: 'business', child: Text('Business Cheque')),
                      ],
                      onChanged: (v) => setState(() => _payoutAccountType = (const ['cheque','savings','business'].contains(v) ? v! : 'cheque')),
                      decoration: InputDecoration(
                        labelText: 'Account Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.account_balance_wallet),
                      ),
                    )),
                  ]),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: _savingPayout ? null : () async {
                        if (_sellerId == null) return;
                        setState(() { _savingPayout = true; });
                        try {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(_sellerId)
                              .collection('payout')
                              .doc('bank')
                              .set({
                                'accountHolder': _payoutAccountHolderController.text.trim(),
                                'bankName': _payoutBankNameController.text.trim(),
                                'accountNumber': _payoutAccountNumberController.text.trim(),
                                'branchCode': _payoutBranchCodeController.text.trim(),
                                'accountType': _payoutAccountType,
                                'updatedAt': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout details saved')));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
                          }
                        } finally {
                          if (mounted) setState(() { _savingPayout = false; });
                        }
                      },
                      icon: _savingPayout
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(_savingPayout ? 'Saving...' : 'Save Payout Details'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Pickup services toggles
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2)),
              ],
            ),
            margin: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pickup Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _sellerData?['pargoEnabled'] == true,
                    onChanged: (val) async {
                      await FirebaseFirestore.instance.collection('users').doc(_sellerId).update({'pargoEnabled': val});
                      setState(() { _sellerData = {...?_sellerData, 'pargoEnabled': val}; });
                    },
                    title: const Text('Enable PARGO pickup points'),
                    subtitle: const Text('Customers can pick up at PARGO points'),
                  ),
                  SwitchListTile(
                    value: _sellerData?['paxiEnabled'] == true,
                    onChanged: (val) async {
                      await FirebaseFirestore.instance.collection('users').doc(_sellerId).update({'paxiEnabled': val});
                      setState(() { _sellerData = {...?_sellerData, 'paxiEnabled': val}; });
                    },
                    title: const Text('Enable PAXI pickup points'),
                    subtitle: const Text('Customers can pick up at PAXI points'),
                  ),
                ],
              ),
            ),
          ),

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

  Future<void> _uploadKycDocuments() async {
    try {
      // Imports required: cloud_functions, image_picker, http, convert
      // ignore: unused_local_variable
      // Get upload auth from callable
      final functions = FirebaseFunctions.instance;
      final authRes = await functions.httpsCallable('getImageKitUploadAuth').call();
      final auth = authRes.data as Map;
      final token = auth['token'];
      final expire = auth['expire'];
      final signature = auth['signature'];
      final publicKey = auth['publicKey'];
      // ignore: unused_local_variable
      final urlEndpoint = auth['urlEndpoint'];

      // Pick files
      final ImagePicker picker = ImagePicker();
      final List<XFile> files = await picker.pickMultiImage(imageQuality: 90);
      if (files.isEmpty) return;

      // Upload sequentially to ImageKit REST API
      for (final f in files) {
        final bytes = await f.readAsBytes();
        final b64 = base64Encode(bytes);
        final form = {
          'file': b64,
          'fileName': f.name,
          'token': token,
          'expire': expire.toString(),
          'signature': signature,
          'publicKey': publicKey,
          'folder': '/kyc/${_sellerId ?? 'unknown'}/',
        };

        final resp = await http.post(
          Uri.parse('https://upload.imagekit.io/api/v1/files/upload'),
          body: form,
        );
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final url = data['url'] as String?;
          // Save to Firestore under user->kyc and central submissions
          if (_sellerId != null && url != null) {
            final now = DateTime.now();
            await FirebaseFirestore.instance.collection('users').doc(_sellerId).collection('kyc').add({
              'url': url,
              'fileId': data['fileId'] ?? data['file_id'] ?? '',
              'filePath': data['filePath'] ?? data['file_path'] ?? '',
              'type': 'image',
              'uploadedAt': now.toIso8601String(),
            });
            await FirebaseFirestore.instance.collection('kyc_submissions').add({
              'userId': _sellerId,
              'url': url,
              'fileId': data['fileId'] ?? data['file_id'] ?? '',
              'filePath': data['filePath'] ?? data['file_path'] ?? '',
              'status': 'pending',
              'submittedAt': now.toIso8601String(),
            });
          }
        } else {
          // surface error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('KYC upload failed: ${resp.statusCode}')),
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('KYC documents uploaded')), 
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('KYC upload error: $e')),
        );
      }
    }
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
      // Get authentication parameters from Firebase callable
      final callable = FirebaseFunctions.instance.httpsCallable('getImageKitUploadAuth');
      final result = await callable.call();
      final authParams = result.data as Map;
      final bytes = await file.readAsBytes();
      final fileName = 'products/$sellerId/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      
      final publicKey = (authParams['publicKey'] ?? '').toString();
      final token = authParams['token'];
      final signature = authParams['signature'];
      final expire = authParams['expire'];
      
      if (token == null || signature == null || expire == null) {
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
                  
                  // Quick actions
                  if (status == 'pending')
                    IconButton(
                      onPressed: () => _updateOrderStatusQuick(order, 'processing'),
                      icon: Icon(Icons.inventory_2_outlined, color: AdminTheme.warning, size: 20),
                      tooltip: 'Mark as Processing (Pack)',
                    ),
                  if (status == 'processing')
                    IconButton(
                      onPressed: () => _updateOrderStatusQuick(order, 'ready'),
                      icon: Icon(Icons.inventory_rounded, color: AdminTheme.success, size: 20),
                      tooltip: 'Mark as Ready for pickup',
                    ),
                  if (status == 'ready')
                    IconButton(
                      onPressed: () => _updateOrderStatusQuick(order, 'shipped'),
                      icon: Icon(Icons.local_shipping_outlined, color: AdminTheme.info, size: 20),
                      tooltip: 'Mark as Shipped',
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

  Future<void> _updateOrderStatusQuick(Map<String, dynamic> order, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order['id'])
          .update({'status': newStatus, 'updatedAt': FieldValue.serverTimestamp()});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order updated to $newStatus')),
      );
      await _loadRecentOrders();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    }
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
      return false;
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
      return false;
    });
  }

  Future<void> _loadAvailableBalance() async {
    if (_sellerId == null) return;
    try {
      setState(() { _loadingAvailable = true; });
      final functions = FirebaseFunctions.instance;
      final res = await functions.httpsCallable('getSellerAvailableBalance').call({ 'userId': _sellerId });
      final data = Map<String, dynamic>.from(res.data as Map);
      setState(() {
        _availableGross = (data['gross'] ?? 0).toDouble();
        _availableCommission = (data['commission'] ?? 0).toDouble();
        _availableNet = (data['net'] ?? 0).toDouble();
        _minPayoutAmount = (data['minPayoutAmount'] ?? 0).toDouble();
        _commissionPct = ((data['commissionPct'] ?? 0) as num).toDouble();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load balance: $e')));
      }
    } finally {
      if (mounted) setState(() { _loadingAvailable = false; });
    }
  }

  Future<void> _loadPayoutHistory() async {
    if (_sellerId == null) return;
    try {
      final qs = await FirebaseFirestore.instance
          .collection('users')
          .doc(_sellerId)
          .collection('payouts')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      setState(() {
        _payoutHistory = qs.docs.map((d) => { 'id': d.id, ...?d.data() }).toList().cast<Map<String, dynamic>>();
      });
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadComplianceAndCOD() async {
    if (_sellerId == null) return;
    try {
      // KYC status from user doc
      final u = await FirebaseFirestore.instance.collection('users').doc(_sellerId).get();
      if (u.exists) {
        final d = u.data() ?? {};
        _kycStatus = (d['kycStatus'] ?? 'none').toString();
      }
      // Sum platform receivables with status == 'due'
      final qs = await FirebaseFirestore.instance
          .collection('platform_receivables')
          .doc(_sellerId)
          .collection('entries')
          .where('status', isEqualTo: 'due')
          .get();
      double totalDue = 0.0;
      for (final doc in qs.docs) {
        final d = doc.data();
        final amt = (d['amount'] is num)
            ? (d['amount'] as num).toDouble()
            : ((d['net'] ?? 0) as num?)?.toDouble() ?? 0.0;
        totalDue += amt;
      }
      setState(() {
        _codOutstanding = totalDue;
        _codDisabled = totalDue > 300.0 || _kycStatus.toLowerCase() != 'approved';
      });
    } catch (_) {}
  }

  Future<void> _onRequestPayout() async {
    if (_sellerId == null) return;
    try {
      setState(() { _requestingPayout = true; });
      final functions = FirebaseFunctions.instance;
      final res = await functions.httpsCallable('requestPayout').call({});
      final data = Map<String, dynamic>.from(res.data as Map);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payout requested: R${(_availableNet).toStringAsFixed(2)}')));
      }
      await _loadAvailableBalance();
      await _loadPayoutHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request failed: $e')));
      }
    } finally {
      if (mounted) setState(() { _requestingPayout = false; });
    }
  }
  // ===== Placeholder implementations to restore build for missing sections =====
  Widget _buildMyProducts() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Navigate to full product management')),
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('ownerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No products yet', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final product = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        product['imageUrl'] ?? '',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                    ),
                    title: Text(product['name'] ?? 'Unknown Product'),
                    subtitle: Text('R${(product['price'] ?? 0).toStringAsFixed(2)}'),
                    trailing: Text(product['category'] ?? ''),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInventory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Inventory Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('ownerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final products = snapshot.hasData ? snapshot.data!.docs : [];
              final totalProducts = products.length;
              final activeProducts = products.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] != 'inactive';
              }).length;
              final lowStockProducts = products.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['stock'] ?? 0) < 5;
              }).length;
              
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInventoryCard('Total Products', totalProducts.toString(), Icons.inventory),
                  _buildInventoryCard('Active', activeProducts.toString(), Icons.check_circle, Colors.green),
                  _buildInventoryCard('Low Stock', lowStockProducts.toString(), Icons.warning, Colors.orange),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(String title, String value, IconData icon, [Color? color]) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color ?? Colors.blue),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color ?? Colors.blue)),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildCustomerReviews() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Navigate to all reviews')),
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reviews')
                .where('sellerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                .orderBy('timestamp', descending: true)
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    children: [
                      Icon(Icons.star_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No reviews yet', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final review = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(review['userName']?.toString().substring(0, 1).toUpperCase() ?? 'U'),
                    ),
                    title: Text(review['userName'] ?? 'Anonymous'),
                    subtitle: Text(review['comment'] ?? 'No comment'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (starIndex) => Icon(
                        starIndex < (review['rating'] ?? 0) ? Icons.star : Icons.star_border,
                        color: Colors.orange,
                        size: 16,
                      )),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.centerLeft,
      child: const Text('Store settings appear above.'),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  Widget _buildCodKycPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _codDisabled ? Icons.block : Icons.check_circle,
                  color: _codDisabled ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text('COD & KYC', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loadComplianceAndCOD,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.verified_user, size: 16),
                  label: Text('KYC: ${_kycStatus.toUpperCase()}'),
                ),
                Chip(
                  avatar: const Icon(Icons.payments, size: 16),
                  label: Text('Outstanding: R${_codOutstanding.toStringAsFixed(2)}'),
                ),
                Chip(
                  avatar: const Icon(Icons.local_shipping, size: 16),
                  label: Text(_codDisabled ? 'COD: DISABLED' : 'COD: ENABLED'),
                  backgroundColor: _codDisabled ? Colors.orange.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: (_codOutstanding > 0 && _sellerId != null) ? () async {
                    final url = Uri.parse('https://functions-redirect'); // placeholder
                    try {
                      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
                      if (!ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open payment link (stub).')));
                      }
                    } catch (_) {}
                  } : null,
                  icon: const Icon(Icons.link),
                  label: const Text('Generate top-up link'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: (_codOutstanding > 0 && _sellerId != null) ? () async {
                    // Admin manual mark-paid (stub): in real impl, write a settlement entry
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as paid (stub).')));
                  } : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Mark as paid'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/kyc'),
                  icon: const Icon(Icons.assignment_ind),
                  label: const Text('Open KYC Review'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildAnalyticsCard('Total Revenue', 'R${_totalRevenue.toStringAsFixed(2)}', Icons.receipt, AdminTheme.success),
        _buildAnalyticsCard('Orders', '$_totalOrders', Icons.shopping_bag, Colors.blue),
      ],
    );
  }

  Widget _buildSalesChart() {
    return Container(
      height: 200,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: const Text('Sales chart (coming soon)'),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: const Text('Recent activity (coming soon)'),
    );
  }

  Widget _buildRecentOrders() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: const Text('Recent orders (coming soon)'),
    );
  }

  Widget _buildTopProducts() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: const Text('Top products (coming soon)'),
    );
  }

  Widget _buildStatusCard(String title, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
          Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('pending')) return AdminTheme.warning;
    if (s.contains('processing')) return AdminTheme.info;
    if (s.contains('completed') || s.contains('delivered')) return AdminTheme.success;
    if (s.contains('cancel')) return AdminTheme.error;
    return Colors.grey;
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