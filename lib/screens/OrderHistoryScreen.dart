import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'OrderTrackingScreen.dart';
import 'SellerOrdersListScreen.dart';
import '../theme/app_theme.dart';
import '../utils/order_utils.dart';
import '../widgets/home_navigation_button.dart';
import 'dart:math' as math;

// Responsive utilities
class ResponsiveUtils {
  static bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < 600;
  static bool isTablet(BuildContext context) => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1200;
  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= 1200;
  static bool isSmallScreen(BuildContext context) => MediaQuery.of(context).size.width < 400;
  
  static double getHorizontalPadding(BuildContext context) {
    if (isMobile(context)) return 16;
    if (isTablet(context)) return 24;
    return 32;
  }
  
  static double getVerticalPadding(BuildContext context) {
    if (isMobile(context)) return 8;
    if (isTablet(context)) return 12;
    return 16;
  }
  
  static double getCardWidth(BuildContext context) {
    if (isMobile(context)) return double.infinity;
    if (isTablet(context)) return 500;
    return 600;
  }
  
  static double getIconSize(BuildContext context, {double baseSize = 16}) {
    if (isSmallScreen(context)) return baseSize * 0.8;
    if (isMobile(context)) return baseSize;
    if (isTablet(context)) return baseSize * 1.1;
    return baseSize * 1.2;
  }
  
  static TextStyle safeTextStyle(BuildContext context, TextStyle? baseStyle) {
    final fontSize = isSmallScreen(context) ? 12.0 : (isMobile(context) ? 14.0 : 16.0);
    return baseStyle?.copyWith(fontSize: fontSize) ?? TextStyle(fontSize: fontSize);
  }
}

// Safe UI utilities
class SafeUI {
  static Widget safeText(String text, {
    required TextStyle style,
    int maxLines = 1,
    TextOverflow overflow = TextOverflow.ellipsis,
  }) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> 
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _floatingController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _floatingAnimation;
  
  User? get currentUser => FirebaseAuth.instance.currentUser;

  // Pagination state
  final ScrollController _scrollController = ScrollController();
  final List<DocumentSnapshot> _orders = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  static const int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _floatingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );
    
    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
    _shimmerController.repeat();
    _floatingController.repeat(reverse: true);

    // Load initial orders and set up pagination
    _loadInitialOrders();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMoreOrders();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _floatingController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialOrders() async {
    if (_isLoading) return;
    if (currentUser == null) return;
    setState(() { _isLoading = true; _orders.clear(); _lastDoc = null; _hasMore = true; });
    try {
      Query q = FirebaseFirestore.instance
          .collection('orders')
          .where('buyerId', isEqualTo: currentUser!.uid)
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);
      final snap = await q.get();
      if (snap.docs.isNotEmpty) {
        _orders.addAll(snap.docs);
        _lastDoc = snap.docs.last;
        _hasMore = snap.docs.length >= _pageSize;
      } else {
        _hasMore = false;
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_isLoading || !_hasMore) return;
    if (currentUser == null) return;
    setState(() { _isLoading = true; });
    try {
      Query q = FirebaseFirestore.instance
          .collection('orders')
          .where('buyerId', isEqualTo: currentUser!.uid)
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);
      if (_lastDoc != null) {
        q = q.startAfter([_lastDoc!['timestamp']]);
      }
      final snap = await q.get();
      if (snap.docs.isNotEmpty) {
        _orders.addAll(snap.docs);
        _lastDoc = snap.docs.last;
        _hasMore = snap.docs.length >= _pageSize;
      } else {
        _hasMore = false;
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _onRefresh() async {
    await _loadInitialOrders();
  }

  Color _statusColor(String status) {
    return AppTheme.getStatusColor(status);
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Icons.pending_actions;
      case 'confirmed': return Icons.check_circle_outline;
      case 'preparing': return Icons.restaurant;
      case 'ready': return Icons.local_shipping;
      case 'shipped': return Icons.local_shipping;
      case 'delivered': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400; // Consistent with ResponsiveUtils
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: AppTheme.angel,
        actions: [
          HomeNavigationButton(
            backgroundColor: AppTheme.deepTeal,
            iconColor: AppTheme.angel,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Builder(builder: (context) {
        if (currentUser == null) {
          return _buildAuthRequiredScreen();
        }
        if (_orders.isEmpty && _isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 64,
                    color: AppTheme.mediumGrey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No orders yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.deepTeal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your order history will appear here',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ],
              ),
            );
          }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppTheme.deepTeal,
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 8.0 : 16.0),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _orders.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _orders.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final orderDoc = _orders[index];
                final orderId = orderDoc.id;
                final orderData = orderDoc.data() as Map<String, dynamic>;
                return _buildOrderCard(orderId, orderData, isSmallScreen);
              },
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAnimatedBackground() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _floatingAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: 0.05 * _floatingAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDelightfulTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getHorizontalPadding(context),
        vertical: ResponsiveUtils.getVerticalPadding(context),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 40,
            offset: const Offset(0, 16),
            spreadRadius: 0,
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.deepTeal,
              AppTheme.deepTeal.withOpacity(0.8),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepTeal.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.cloud,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: ResponsiveUtils.isMobile(context) ? 14 : 15,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: ResponsiveUtils.isMobile(context) ? 14 : 15,
          letterSpacing: 0.3,
        ),
        indicatorPadding: EdgeInsets.all(4),
        tabs: [
          // Animated tab with micro-interaction
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _tabController.index == 0 ? 1.0 + (0.02 * _pulseAnimation.value) : 1.0,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.isMobile(context) ? 16 : 20,
                    vertical: ResponsiveUtils.isMobile(context) ? 12 : 16,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: ResponsiveUtils.getIconSize(context, baseSize: 16),
                        color: _tabController.index == 0 ? Colors.white : AppTheme.cloud,
                      ),
                      SizedBox(width: ResponsiveUtils.isMobile(context) ? 6 : 8),
                      Text('My Purchases'),
                    ],
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _tabController.index == 1 ? 1.0 + (0.02 * _pulseAnimation.value) : 1.0,
                child: GestureDetector(
                  onTap: () {
                    // If user is a seller, navigate to SellerOrdersListScreen
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      // Check user role
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .get()
                          .then((doc) {
                        final userData = doc.data();
                        final userRole = userData?['role'] ?? 'buyer';
                        
                        if (userRole == 'seller') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SellerOrdersListScreen(sellerId: user.uid),
                            ),
                          );
                        } else {
                          // For buyers, just switch to the "My Sales" tab content
                          _tabController.animateTo(1);
                        }
                      });
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.isMobile(context) ? 16 : 20,
                      vertical: ResponsiveUtils.isMobile(context) ? 12 : 16,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.store_outlined,
                          size: ResponsiveUtils.getIconSize(context, baseSize: 16),
                          color: _tabController.index == 1 ? Colors.white : AppTheme.cloud,
                        ),
                        SizedBox(width: ResponsiveUtils.isMobile(context) ? 6 : 8),
                        Text('My Sales'),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersListView(Stream<QuerySnapshot> ordersStream, String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: ordersStream,
      builder: (context, snapshot) {
        print('🔍 DEBUG: OrderHistoryScreen - StreamBuilder state: ${snapshot.connectionState}');
        print('🔍 DEBUG: OrderHistoryScreen - Has error: ${snapshot.hasError}');
        print('🔍 DEBUG: OrderHistoryScreen - Has data: ${snapshot.hasData}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          print('🔍 DEBUG: OrderHistoryScreen - Error: ${snapshot.error}');
          return _buildErrorState(snapshot.error.toString());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          print('🔍 DEBUG: OrderHistoryScreen - Found 0 orders');
          print('🔍 DEBUG: OrderHistoryScreen - No orders found, showing empty state');
          return _buildEmptyState(type);
        }
        
        final orders = snapshot.data!.docs;
        print('🔍 DEBUG: OrderHistoryScreen - Found ${orders.length} orders');

                  return ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 4),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final orderData = orders[index].data() as Map<String, dynamic>;
              final orderId = orders[index].id;
              final screenWidth = MediaQuery.of(context).size.width;
              final isSmallScreen = screenWidth < 400; // Consistent with ResponsiveUtils
              return _buildOrderCard(orderId, orderData, isSmallScreen);
            },
          );
                },
              );
  }

  Widget _buildOrderCard(String orderId, Map<String, dynamic> orderData, bool isSmallScreen) {
    final rawOrderNumber = (orderData['orderNumber'] as String?) ?? orderId;
    // Use more readable formatting - only use very short format for very small screens
    final displayOrderNumber = MediaQuery.of(context).size.width < 400
        ? OrderUtils.formatVeryShortOrderNumber(rawOrderNumber)
        : OrderUtils.formatShortOrderNumber(rawOrderNumber);
    final timestamp = orderData['timestamp'] as Timestamp?;
    final status = orderData['status'] ?? 'pending';
    final totalPrice = (orderData['totalPrice'] as num?)?.toDouble() ?? 0.0;
    final items = orderData['items'] as List<dynamic>? ?? [];
    
    // Format date
    final formattedDate = timestamp != null 
        ? DateFormat('MMM dd, yyyy - HH:mm').format(timestamp.toDate())
        : 'Date not available';
    
    // Create product summary
    final productNames = items.map((item) => item['name'] ?? 'Unknown Product').toList();
    final productSummary = productNames.isNotEmpty 
        ? productNames.join(', ')
        : 'No products listed';
    
    final itemCount = items.length;
    
    // Responsive layout - stack vertically on very small screens
    return Container(
      margin: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 2.0 : 4.0,
        horizontal: isSmallScreen ? 4.0 : 8.0,
      ),
      child: isSmallScreen
          ? _buildVerticalLayout(orderId, displayOrderNumber, productSummary, formattedDate, itemCount, status, totalPrice)
          : _buildHorizontalLayout(orderId, displayOrderNumber, productSummary, formattedDate, itemCount, status, totalPrice),
    );
  }

  Widget _buildHorizontalLayout(String orderId, String displayOrderNumber, String productSummary, String formattedDate, int itemCount, String status, double totalPrice) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderTrackingScreen(orderId: orderId),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Product info (left side)
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productSummary,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.tag,
                            size: 14,
                            color: AppTheme.mediumGrey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Order $displayOrderNumber',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.mediumGrey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.mediumGrey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 16,
                            color: AppTheme.mediumGrey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$itemCount item${itemCount != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.mediumGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Status and price (right side)
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _statusColor(status).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(status),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'R${totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepTeal,
                        ),
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

  Widget _buildVerticalLayout(String orderId, String displayOrderNumber, String productSummary, String formattedDate, int itemCount, String status, double totalPrice) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderTrackingScreen(orderId: orderId),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product summary
                Text(
                  productSummary,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.tag,
                      size: 14,
                      color: AppTheme.mediumGrey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Order $displayOrderNumber',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.mediumGrey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                
                // Date and item count
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppTheme.mediumGrey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.mediumGrey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 14,
                      color: AppTheme.mediumGrey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$itemCount item${itemCount != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.mediumGrey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Status and price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _statusColor(status).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(status),
                        ),
                      ),
                    ),
                    Text(
                      'R${totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepTeal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Responsive loading icon
            Container(
              padding: EdgeInsets.all(ResponsiveUtils.isMobile(context) ? 16 : 20),
              decoration: BoxDecoration(
                color: AppTheme.deepTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.isMobile(context) ? 16 : 20,
                ),
              ),
              child: SizedBox(
                width: ResponsiveUtils.isMobile(context) ? 32 : 40,
                height: ResponsiveUtils.isMobile(context) ? 32 : 40,
                child: const CircularProgressIndicator(
                  color: AppTheme.deepTeal,
                  strokeWidth: 3,
                ),
              ),
            ),
            SizedBox(height: ResponsiveUtils.isMobile(context) ? 20 : 24),
            SafeUI.safeText(
              'Loading your orders...',
              style: ResponsiveUtils.safeTextStyle(
                context,
                TextStyle(
                  fontSize: ResponsiveUtils.isMobile(context) ? 14 : 16,
                  color: AppTheme.cloud,
                  fontWeight: FontWeight.w500,
                ),
              ),
              maxLines: 1,
            ),
            SizedBox(height: ResponsiveUtils.isMobile(context) ? 6 : 8),
            SafeUI.safeText(
              'Please wait while we fetch your order history',
              style: ResponsiveUtils.safeTextStyle(
                context,
                TextStyle(
                  fontSize: ResponsiveUtils.isMobile(context) ? 12 : 14,
                  color: AppTheme.cloud.withOpacity(0.7),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        margin: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
        padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
        constraints: BoxConstraints(
          maxWidth: ResponsiveUtils.getCardWidth(context),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.red.withOpacity(0.05),
              AppTheme.angel,
            ],
          ),
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.isMobile(context) ? 16 : 20,
          ),
          border: Border.all(
            color: Colors.red.withOpacity(0.1),
            width: ResponsiveUtils.isMobile(context) ? 0.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Responsive error icon
            Container(
              padding: EdgeInsets.all(ResponsiveUtils.isMobile(context) ? 20 : 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.withOpacity(0.1),
                    Colors.red.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.isMobile(context) ? 16 : 20,
                ),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                  width: ResponsiveUtils.isMobile(context) ? 0.5 : 1,
                ),
              ),
              child: Icon(
                Icons.error_outline,
                size: ResponsiveUtils.isMobile(context) ? 48 : 64,
                color: Colors.red,
              ),
            ),
            SizedBox(height: ResponsiveUtils.isMobile(context) ? 20 : 24),
            SafeUI.safeText(
              'Something went wrong',
              style: ResponsiveUtils.safeTextStyle(
                context,
                TextStyle(
                  fontSize: ResponsiveUtils.isMobile(context) ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              maxLines: 2,
            ),
            SizedBox(height: ResponsiveUtils.isMobile(context) ? 10 : 12),
            SafeUI.safeText(
              'We couldn\'t load your orders.\nPlease try again.',
              style: ResponsiveUtils.safeTextStyle(
                context,
                TextStyle(
                  fontSize: ResponsiveUtils.isMobile(context) ? 13 : 16,
                  color: AppTheme.cloud,
                  height: 1.5,
                ),
              ),
              maxLines: 3,
            ),
            SizedBox(height: ResponsiveUtils.isMobile(context) ? 12 : 16),
            Container(
              padding: EdgeInsets.all(ResponsiveUtils.isMobile(context) ? 8 : 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.isMobile(context) ? 6 : 8,
                ),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                  width: ResponsiveUtils.isMobile(context) ? 0.5 : 1,
                ),
              ),
              child: SafeUI.safeText(
                error,
                style: ResponsiveUtils.safeTextStyle(
                  context,
                  TextStyle(
                    fontSize: ResponsiveUtils.isMobile(context) ? 10 : 12,
                    color: Colors.red,
                    fontFamily: 'monospace',
                  ),
                ),
                maxLines: 3,
              ),
            ),
            SizedBox(height: ResponsiveUtils.isMobile(context) ? 24 : 32),
            // Responsive retry button
            Container(
              width: double.infinity,
              height: ResponsiveUtils.isMobile(context) ? 44 : 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.red, Colors.red.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.isMobile(context) ? 10 : 12,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: ResponsiveUtils.isMobile(context) ? 6 : 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.isMobile(context) ? 10 : 12,
                  ),
                  onTap: () {
                    setState(() {}); // Refresh the screen
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.getHorizontalPadding(context),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: ResponsiveUtils.getIconSize(context, baseSize: 20),
                        ),
                        SizedBox(width: ResponsiveUtils.isMobile(context) ? 8 : 12),
                        SafeUI.safeText(
                          'Try Again',
                          style: ResponsiveUtils.safeTextStyle(
                            context,
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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

  Widget _buildEmptyState(String type) {
    final isPurchases = type == 'purchases';
    final icon = isPurchases ? Icons.shopping_bag_outlined : Icons.store_outlined;
    final title = isPurchases ? 'No Purchases Yet' : 'No Sales Yet';
    final subtitle = isPurchases 
        ? 'You haven\'t made any purchases yet.\nStart shopping to see your orders here!'
        : 'You haven\'t made any sales yet.\nStart selling to see your orders here!';
    final actionText = isPurchases ? 'Start Shopping' : 'Start Selling';
    
    return Center(
      child: Container(
        margin: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
        padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
        constraints: BoxConstraints(
          maxWidth: ResponsiveUtils.getCardWidth(context),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.breeze.withOpacity(0.05),
              AppTheme.angel,
            ],
          ),
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.isMobile(context) ? 16 : 20,
          ),
          border: Border.all(
            color: AppTheme.cloud.withOpacity(0.1),
            width: ResponsiveUtils.isMobile(context) ? 0.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Responsive empty state icon
            Container(
              padding: EdgeInsets.all(ResponsiveUtils.isMobile(context) ? 20 : 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.deepTeal.withOpacity(0.1),
                    AppTheme.cloud.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.isMobile(context) ? 16 : 20,
                ),
                border: Border.all(
                  color: AppTheme.deepTeal.withOpacity(0.2),
                  width: ResponsiveUtils.isMobile(context) ? 0.5 : 1,
                ),
              ),
              child: Icon(
                icon,
                size: ResponsiveUtils.isMobile(context) ? 48 : 64,
                color: AppTheme.deepTeal,
              ),
            ),
            SizedBox(height: ResponsiveUtils.isMobile(context) ? 20 : 24),
            SafeUI.safeText(
              title,
              style: ResponsiveUtils.safeTextStyle(
                context,
                TextStyle(
                  fontSize: ResponsiveUtils.isMobile(context) ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepTeal,
                ),
              ),
              maxLines: 2,
            ),
            SizedBox(height: ResponsiveUtils.isMobile(context) ? 10 : 12),
            SafeUI.safeText(
              subtitle,
              style: ResponsiveUtils.safeTextStyle(
                context,
                TextStyle(
                  fontSize: ResponsiveUtils.isMobile(context) ? 13 : 16,
                  color: AppTheme.cloud,
                  height: 1.5,
                ),
              ),
              maxLines: 3,
            ),
            SizedBox(height: ResponsiveUtils.isMobile(context) ? 24 : 32),
            // Responsive action button
            Container(
              width: double.infinity,
              height: ResponsiveUtils.isMobile(context) ? 44 : 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.deepTeal, AppTheme.cloud],
                ),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.isMobile(context) ? 10 : 12,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.deepTeal.withOpacity(0.3),
                    blurRadius: ResponsiveUtils.isMobile(context) ? 6 : 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.isMobile(context) ? 10 : 12,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.getHorizontalPadding(context),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isPurchases ? Icons.shopping_bag : Icons.store,
                          color: Colors.white,
                          size: ResponsiveUtils.getIconSize(context, baseSize: 20),
                        ),
                        SizedBox(width: ResponsiveUtils.isMobile(context) ? 8 : 12),
                        SafeUI.safeText(
                          actionText,
                          style: ResponsiveUtils.safeTextStyle(
                            context,
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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

  Widget _buildAuthRequiredScreen() {
    return Scaffold(
      backgroundColor: AppTheme.whisper,
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.breeze.withOpacity(0.1), AppTheme.angel],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cloud.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.breeze.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.lock_outline,
                  color: AppTheme.deepTeal,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Login Required',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please log in to view your order history',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.cloud,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDelightfulAppBar() {
    return Container(
      height: ResponsiveUtils.isMobile(context) ? 200 : 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.deepTeal,
            AppTheme.deepTeal.withOpacity(0.9),
            AppTheme.cloud,
            AppTheme.breeze,
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // Animated floating particles
            ...List.generate(6, (index) {
              return Positioned(
                left: (index * 80.0) % 400,
                top: (index * 60.0) % 220,
                child: AnimatedBuilder(
                  animation: _floatingAnimation,
                  builder: (context, child) {
                    final offset = math.sin((_floatingAnimation.value * 2 * math.pi) + index) * 15;
                    return Transform.translate(
                      offset: Offset(offset, 0),
                      child: Opacity(
                        opacity: 0.3 * _fadeAnimation.value,
                        child: Container(
                          width: 4 + (index % 3),
                          height: 4 + (index % 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.6),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
            
            // Content with delightful animations
            Padding(
              padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Delightful back button with micro-interactions
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    child: const Icon(
                                      Icons.arrow_back_ios,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(width: ResponsiveUtils.isMobile(context) ? 20 : 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Animated title with slide effect
                            AnimatedBuilder(
                              animation: _fadeAnimation,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _fadeAnimation.value,
                                  child: SafeUI.safeText(
                                    'Your Orders',
                                    style: ResponsiveUtils.safeTextStyle(
                                      context,
                                      Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: ResponsiveUtils.isMobile(context) ? 28 : 32,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(0.3),
                                            offset: const Offset(0.0, 2.0),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                    maxLines: 2,
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: ResponsiveUtils.isMobile(context) ? 8 : 12),
                            // Animated subtitle with fade effect
                            AnimatedBuilder(
                              animation: _fadeAnimation,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _fadeAnimation.value,
                                  child: SafeUI.safeText(
                                    'Track your purchases and manage your sales',
                                    style: ResponsiveUtils.safeTextStyle(
                                      context,
                                      Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: ResponsiveUtils.isMobile(context) ? 15 : 17,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(0.2),
                                            offset: const Offset(0.0, 1.0),
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                    maxLines: 2,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

