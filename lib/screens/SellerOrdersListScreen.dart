import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/advanced_memory_optimizer.dart';
import '../utils/order_utils.dart';
import '../theme/app_theme.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:async' show TimeoutException;

class SellerOrdersListScreen extends StatefulWidget {
  final String? sellerId;
  
  const SellerOrdersListScreen({Key? key, this.sellerId}) : super(key: key);

  @override
  _SellerOrdersListScreenState createState() => _SellerOrdersListScreenState();
}

class _SellerOrdersListScreenState extends State<SellerOrdersListScreen> 
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Advanced pagination
  late OptimizedPagination<Map<String, dynamic>> _pagination;
  bool _isLoading = false;
  bool _hasMoreData = true;
  String? _selectedStatus;
  
  // Filtered orders list
  List<Map<String, dynamic>> filteredOrders = [];
  
  // Stream management
  StreamSubscription? _ordersStream;
  final ScrollController _scrollController = ScrollController();
  
  // Debounced search
  String _searchQuery = '';
  Timer? _searchDebounceTimer;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  // Stats
  int _totalOrders = 0;
  double _totalRevenue = 0.0;
  Map<String, int> _statusCounts = {};

  @override
  void initState() {
    super.initState();
    try {
      _initializeAnimations();
      _pagination = OptimizedPagination<Map<String, dynamic>>(
        pageSize: 15,
        maxCachedPages: 3,
      );
      
      // Initialize filtered orders list
      filteredOrders = [];
      
      _loadOrders();
      _setupScrollListener();
      _loadStats();
      // Removed _checkAllOrders() to avoid permission errors
    } catch (e) {
      print('❌ Error in initState: $e');
      // Initialize with empty state to prevent crashes
      filteredOrders = [];
      _pagination = OptimizedPagination<Map<String, dynamic>>(
        pageSize: 15,
        maxCachedPages: 3,
      );
    }
  }

  void _initializeAnimations() {
    try {
      _fadeController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      _slideController = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      );

      _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
      );
      _slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
      _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
      );

      _fadeController.forward();
      _slideController.forward();
      _pulseController.repeat(reverse: true);
    } catch (e) {
      print('❌ Error initializing animations: $e');
      // Create default animations to prevent crashes
      _fadeController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      _slideController = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      );

      _fadeAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(_fadeController);
      _slideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(_slideController);
      _pulseAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(_pulseController);
    }
  }

  Future<void> _checkAllOrders() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('🔍 DEBUG: No current user found in checkAllOrders');
        return;
      }

      final correctSellerId = user.uid;
      final wrongSellerId = "g41xPIkwRic3qcdqTjtuyF6gjc52"; // The wrong sellerId from the order data
      
      print('🔍 DEBUG: Checking for orders with wrong sellerId: $wrongSellerId');
      print('🔍 DEBUG: Current user UID: $correctSellerId');
      
      // Check for orders with wrong sellerId (only if user has permission)
      try {
        final wrongOrdersSnapshot = await _firestore
            .collection('orders')
            .where('sellerId', isEqualTo: wrongSellerId)
            .get();
        
        if (wrongOrdersSnapshot.docs.isNotEmpty) {
          print('🔍 DEBUG: Found ${wrongOrdersSnapshot.docs.length} orders with wrong sellerId: $wrongSellerId');
          
          // Ask user if they want to fix these orders
          if (mounted) {
            _showFixOrdersDialog(wrongOrdersSnapshot.docs.length, wrongSellerId, correctSellerId);
          }
        } else {
          print('🔍 DEBUG: No orders found with wrong sellerId');
        }
      } catch (e) {
        print('🔍 DEBUG: Could not check for wrong orders (likely permission issue): $e');
      }
    } catch (e) {
      print('❌ Error checking all orders: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('🔍 DEBUG: No current user found in stats loading');
        return;
      }

      final sellerId = widget.sellerId ?? user.uid;
      print('🔍 DEBUG: Loading stats for seller: $sellerId');
      
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('sellerId', isEqualTo: sellerId)
          .get()
          .timeout(
            Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Stats query timed out after 10 seconds');
            },
          );

      print('🔍 DEBUG: Stats query found ${ordersSnapshot.docs.length} orders');

      double revenue = 0.0;
      Map<String, int> counts = {};

      for (final doc in ordersSnapshot.docs) {
        try {
          final data = doc.data();
          final total = (data['totalPrice'] ?? data['total'] ?? 0.0).toDouble();
          final status = data['status'] ?? 'pending';
          
          revenue += total;
          counts[status] = (counts[status] ?? 0) + 1;
          
          print('🔍 DEBUG: Order ${doc.id} - Status: $status, Total: $total');
        } catch (e) {
          print('❌ Error processing order ${doc.id} for stats: $e');
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _totalOrders = ordersSnapshot.docs.length;
          _totalRevenue = revenue;
          _statusCounts = counts;
        });
      }
      
      print('🔍 DEBUG: Final stats - Total orders: $_totalOrders, Revenue: $_totalRevenue, Status counts: $_statusCounts');
    } catch (e) {
      print('❌ Error loading stats: $e');
      // Don't crash the app if stats fail to load
      if (mounted) {
        setState(() {
          _totalOrders = 0;
          _totalRevenue = 0.0;
          _statusCounts = {};
        });
      }
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreOrders();
      }
    });
  }

  Future<void> _loadOrders() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('🔍 DEBUG: No current user found');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Use sellerId from widget if provided, otherwise use current user
      final sellerId = widget.sellerId ?? user.uid;
      print('🔍 DEBUG: Loading orders for seller: $sellerId');
      print('🔍 DEBUG: Current user UID: ${user.uid}');
      print('🔍 DEBUG: Widget sellerId: ${widget.sellerId}');

      // Use direct Firestore query instead of OptimizedFirestoreQuery for now
      Query query = _firestore.collection('orders')
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('timestamp', descending: true)
          .limit(15);

      final snapshot = await query.get().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Query timed out after 10 seconds');
        },
      );
      final orders = snapshot.docs;

      print('🔍 DEBUG: Found ${orders.length} orders for seller $sellerId');
      
      // Debug: Print order details
      for (final doc in orders) {
        final data = doc.data() as Map<String, dynamic>?;
        print('🔍 DEBUG: Order ${doc.id} - sellerId: ${data?['sellerId']}, timestamp: ${data?['timestamp']}, orderNumber: ${data?['orderNumber']}');
      }

      // Process orders with customer names
      final processedOrders = await _processOrders(orders);
      
      print('🔍 DEBUG: Processed ${processedOrders.length} orders');
      
      // Clear existing data and add new items
      _pagination.clear();
      _pagination.addItems(processedOrders);
      
      // Update filtered orders
      filteredOrders = List.from(processedOrders);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasMoreData = processedOrders.length >= 15;
        });
      }

    } catch (e) {
      print('❌ Error loading orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          filteredOrders = []; // Clear orders on error
        });
        
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading orders. Please try again.'),
            backgroundColor: AppTheme.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_isLoading || !_hasMoreData) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Use sellerId from widget if provided, otherwise use current user
      final sellerId = widget.sellerId ?? user.uid;

      // Get last order timestamp for pagination
      final currentOrders = _pagination.getCurrentPage();
      final lastOrder = currentOrders.isNotEmpty ? currentOrders.last : null;
      
      Query query = _firestore.collection('orders')
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('timestamp', descending: true)
          .limit(15);

      if (lastOrder != null) {
        query = query.startAfter([lastOrder['timestamp']]);
      }

      final snapshot = await query.get().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Load more query timed out after 10 seconds');
        },
      );
      final newOrders = await _processOrders(snapshot.docs);

      if (newOrders.isNotEmpty) {
        _pagination.addItems(newOrders);
        _pagination.nextPage();
      }

      setState(() {
        _isLoading = false;
        _hasMoreData = newOrders.length >= 15;
      });

    } catch (e) {
      print('❌ Error loading more orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading more orders. Please try again.'),
            backgroundColor: AppTheme.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _processOrders(List<DocumentSnapshot> docs) async {
    final processedOrders = <Map<String, dynamic>>[];
    
    for (final doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>?;
        
        if (data == null) {
          print('🔍 DEBUG: Skipping order ${doc.id} - no data');
          continue;
        }
        
        // Validate required fields
        if (data['sellerId'] == null) {
          print('🔍 DEBUG: Skipping order ${doc.id} - missing sellerId');
          continue;
        }
        
        // Get customer name using optimized method with better fallback
        String customerName = 'Customer';
        try {
          customerName = await _getCustomerName(data);
        } catch (e) {
          print('❌ Error getting customer name for order ${doc.id}: $e');
          customerName = 'Customer';
        }
        
        // Format order number using OrderUtils
        final orderId = doc.id;
        final orderNumber = data['orderNumber'] ?? orderId;
        String formattedOrderNumber = 'Unknown';
        try {
          formattedOrderNumber = OrderUtils.formatOrderNumber(orderNumber);
        } catch (e) {
          print('❌ Error formatting order number for order ${doc.id}: $e');
          formattedOrderNumber = '#$orderNumber';
        }
        
        // Ensure all required fields are present with proper type handling
        final processedOrder = {
          ...data,
          'customerName': customerName,
          'formattedOrderNumber': formattedOrderNumber,
          'id': doc.id,
          'status': data['status'] ?? 'pending',
          'totalPrice': (data['totalPrice'] ?? data['total'] ?? 0.0).toDouble(),
          'items': data['items'] ?? [],
          'timestamp': data['timestamp'] ?? Timestamp.now(),
          'orderNumber': data['orderNumber'] ?? doc.id,
          'buyerName': data['buyerName'] ?? data['name'] ?? 'Customer',
          'phone': data['phone'] ?? '',
          'deliveryAddress': data['address'] ?? data['deliveryAddress'] ?? '',
          'paymentMethod': data['paymentMethod'] ?? 'Not specified',
          'paymentStatus': data['paymentStatus'] ?? 'pending',
        };
        
        processedOrders.add(processedOrder);
      } catch (e) {
        print('❌ Error processing order ${doc.id}: $e');
        // Continue with next order instead of crashing
        continue;
      }
    }
    
    return processedOrders;
  }

  Future<String> _getCustomerName(Map<String, dynamic> data) async {
    try {
      // First try buyerName from order data (most reliable)
      if (data['buyerName'] != null && data['buyerName'].toString().isNotEmpty) {
        return data['buyerName'].toString();
      }
      
      // Then try name field (legacy field)
      if (data['name'] != null && data['name'].toString().isNotEmpty) {
        return data['name'].toString();
      }
      
      // Then try buyerEmail
      if (data['buyerEmail'] != null && data['buyerEmail'].toString().isNotEmpty) {
        try {
          final email = data['buyerEmail'].toString();
          // Extract name from email (before @)
          if (email.contains('@')) {
            final nameFromEmail = email.split('@')[0];
            return nameFromEmail.isNotEmpty ? nameFromEmail : email;
          }
          return email;
        } catch (e) {
          print('Error processing email: $e');
        }
      }
      
      // Finally try to fetch from users collection
      final buyerId = data['buyerId'] as String?;
      if (buyerId != null && buyerId.isNotEmpty) {
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(buyerId)
              .get()
              .timeout(
                Duration(seconds: 5),
                onTimeout: () {
                  throw TimeoutException('User data query timed out');
                },
              );
          
          if (userDoc.exists) {
            final userData = userDoc.data();
            final name = userData?['name'] ?? 
                        userData?['displayName'] ?? 
                        userData?['username'] ??
                        userData?['email'] ?? 
                        '';
            
            if (name.isNotEmpty) {
              return name;
            }
          }
        } catch (e) {
          print('Error fetching user data: $e');
        }
      }
      
      // If all else fails, try to extract from phone number
      if (data['phone'] != null && data['phone'].toString().isNotEmpty) {
        try {
          final phone = data['phone'].toString();
          if (phone.length >= 4) {
            return 'Customer (${phone.substring(phone.length - 4)})';
          }
          return 'Customer ($phone)';
        } catch (e) {
          print('Error processing phone: $e');
        }
      }
      
      return 'Customer';
    } catch (e) {
      print('❌ Error getting customer name: $e');
      return 'Customer';
    }
  }

  void _onSearchChanged(String query) {
    // Debounce search to reduce database calls
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query;
      });
      _loadOrders(); // Reload with new search
    });
  }

  void _onStatusChanged(String? status) {
    setState(() {
      _selectedStatus = status;
    });
    _loadOrders(); // Reload with new filter
  }

  List<Map<String, dynamic>> _getFilteredOrders() {
    final allOrders = _pagination.getCurrentPage();
    
    return allOrders.where((order) {
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final customerName = order['customerName']?.toString().toLowerCase() ?? '';
        final orderId = order['id']?.toString().toLowerCase() ?? '';
        if (!customerName.contains(_searchQuery.toLowerCase()) &&
            !orderId.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }
      
      // Apply status filter
      if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
        if (order['status'] != _selectedStatus) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  void _filterOrders() {
    setState(() {
      final allOrders = _pagination.getAllItems();
      if (_selectedStatus == null) {
        filteredOrders = List.from(allOrders);
      } else {
        filteredOrders = allOrders.where((order) {
          final status = order['status']?.toString().toLowerCase() ?? '';
          return status == _selectedStatus!.toLowerCase();
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.angel,
      appBar: AppBar(
        backgroundColor: AppTheme.deepTeal,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppTheme.heroGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Order Management',
          style: AppTheme.headlineLarge.copyWith(
            color: AppTheme.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppTheme.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh, color: AppTheme.white),
              onPressed: () {
                _loadOrders();
                _loadStats();
              },
            ),
          ),

        ],
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: AppTheme.backgroundGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Filter Orders Section
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.deepTeal.withOpacity(0.08),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(
                  color: AppTheme.breeze.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.deepTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.filter_list,
                          color: AppTheme.deepTeal,
                          size: 14,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Filter Orders',
                        style: AppTheme.headlineMedium.copyWith(
                          color: AppTheme.deepTeal,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _buildFilterButton('All', null, Icons.list, _selectedStatus == null),
                      _buildFilterButton('Pending', 'pending', Icons.schedule, _selectedStatus == 'pending'),
                      _buildFilterButton('Confirmed', 'confirmed', Icons.check_circle, _selectedStatus == 'confirmed'),
                      _buildFilterButton('Preparing', 'preparing', Icons.restaurant, _selectedStatus == 'preparing'),
                      _buildFilterButton('Ready', 'ready', Icons.local_shipping, _selectedStatus == 'ready'),
                      _buildFilterButton('Delivered', 'delivered', Icons.done_all, _selectedStatus == 'delivered'),
                    ],
                  ),
                ],
              ),
            ),
            
            // Summary Statistics Section
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: AppTheme.cardGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.deepTeal.withOpacity(0.1),
                    blurRadius: 15,
                    offset: Offset(0, 6),
                    spreadRadius: 1,
                  ),
                ],
                border: Border.all(
                  color: AppTheme.breeze.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      Icons.receipt_long,
                      _totalOrders.toString(),
                      'Total Orders',
                      AppTheme.deepTeal,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.cloud, AppTheme.breeze],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      Icons.receipt,
                      'R${_totalRevenue.toStringAsFixed(0)}',
                      'Revenue',
                      AppTheme.deepTeal,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 8),
            
            // Orders List
            Expanded(
              child: filteredOrders.isEmpty && !_isLoading
                  ? Center(
                      child: Container(
                        padding: EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppTheme.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.deepTeal.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.cloud.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Icon(
                                Icons.shopping_bag_outlined,
                                size: 48,
                                color: AppTheme.cloud,
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              'No orders found',
                              style: AppTheme.headlineMedium.copyWith(
                                color: AppTheme.mediumGrey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Orders will appear here when customers place them',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.lightGrey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 20),

                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: (filteredOrders?.length ?? 0) + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= (filteredOrders?.length ?? 0)) {
                          return Container(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Column(
                                children: [
                                  CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
                                    strokeWidth: 3,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Loading more orders...',
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.cloud,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        
                        try {
                          final order = filteredOrders?[index];
                          if (order == null) {
                            return Container(
                              padding: EdgeInsets.all(20),
                              child: Center(
                                child: Text(
                                  'Error loading order',
                                  style: TextStyle(color: AppTheme.error),
                                ),
                              ),
                            );
                          }
                          return _buildCleanOrderCard(order);
                        } catch (e) {
                          print('❌ Error building order at index $index: $e');
                          return Container(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                'Error loading order',
                                style: TextStyle(color: AppTheme.error),
                              ),
                            ),
                          );
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String text, String? status, IconData icon, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = status;
        });
        _filterOrders();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected 
            ? LinearGradient(
                colors: AppTheme.buttonGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
          color: isSelected ? null : AppTheme.whisper,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppTheme.deepTeal.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ] : [
            BoxShadow(
              color: AppTheme.deepTeal.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isSelected ? AppTheme.deepTeal.withOpacity(0.3) : AppTheme.breeze.withOpacity(0.5),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected ? AppTheme.white : AppTheme.deepTeal,
            ),
            SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: isSelected ? AppTheme.white : AppTheme.deepTeal,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 16,
          ),
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: AppTheme.mediumGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCleanOrderCard(Map<String, dynamic> order) {
    try {
      final status = order['status'] ?? 'pending';
      final customerName = order['buyerName'] ?? order['name'] ?? order['customerName'] ?? 'Customer';
      final total = (order['totalPrice'] ?? order['total'] ?? 0.0).toDouble();
      final timestamp = order['timestamp'];
      final orderId = order['id'] ?? '';
      final orderNumber = order['orderNumber'] ?? orderId;
      final formattedOrderNumber = order['formattedOrderNumber'] ?? OrderUtils.formatOrderNumber(orderNumber);
      final items = order['items'] as List<dynamic>? ?? [];
      final itemCount = items.length;
    
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/seller-order-detail',
          arguments: {'orderId': orderId},
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepTeal.withOpacity(0.08),
              blurRadius: 12,
              offset: Offset(0, 4),
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: AppTheme.breeze.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.success, AppTheme.lightGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.local_shipping,
                    color: AppTheme.white,
                    size: 18,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Order #$formattedOrderNumber',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.deepTeal,
                      fontSize: 16,
                    ),
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.whisper,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                OrderUtils.formatTimestamp(timestamp),
                style: TextStyle(
                  color: AppTheme.mediumGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.deepTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    size: 14,
                    color: AppTheme.deepTeal,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Customer: $customerName',
                    style: TextStyle(
                      color: AppTheme.deepTeal,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.cloud.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.shopping_bag,
                    size: 14,
                    color: AppTheme.cloud,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Items: $itemCount item${itemCount != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: AppTheme.deepTeal,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.success, AppTheme.lightGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'R${total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.cloud.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.cloud.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: AppTheme.cloud,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'View Details',
                        style: TextStyle(
                          color: AppTheme.cloud,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    } catch (e) {
      print('❌ Error building order card: $e');
      // Return a fallback card if there's an error
      return Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.error.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.error, color: AppTheme.error, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error loading order',
                    style: TextStyle(
                      color: AppTheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'There was an error loading this order. Please try again.',
              style: TextStyle(
                color: AppTheme.mediumGrey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    String displayStatus;
    
    switch (status.toLowerCase()) {
      case 'pending':
        badgeColor = AppTheme.warning;
        displayStatus = 'PENDING';
        break;
      case 'confirmed':
        badgeColor = AppTheme.info;
        displayStatus = 'CONFIRMED';
        break;
      case 'preparing':
        badgeColor = AppTheme.primaryPurple;
        displayStatus = 'PREPARING';
        break;
      case 'ready':
        badgeColor = AppTheme.success;
        displayStatus = 'READY';
        break;
      case 'delivered':
        badgeColor = AppTheme.success;
        displayStatus = 'DELIVERED';
        break;
      case 'shipped':
        badgeColor = AppTheme.success;
        displayStatus = 'SHIPPED';
        break;
      case 'cancelled':
        badgeColor = AppTheme.error;
        displayStatus = 'CANCELLED';
        break;
      default:
        badgeColor = AppTheme.mediumGrey;
        displayStatus = status.toUpperCase();
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          color: badgeColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppTheme.cloud,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(text, style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppTheme.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepTeal,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.cloud,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value) {
    final isSelected = _selectedStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = selected ? value : null;
        });
        _onStatusChanged(value);
      },
      backgroundColor: AppTheme.angel,
      selectedColor: AppTheme.deepTeal.withOpacity(0.2),
      checkmarkColor: AppTheme.deepTeal,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.deepTeal : AppTheme.cloud,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppTheme.deepTeal : AppTheme.cloud,
        ),
      ),
    );
  }

  void _showStatusUpdateDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Order Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Order #${OrderUtils.formatShortOrderNumber(order['id'] ?? '')}'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: order['status'] ?? 'pending',
              decoration: InputDecoration(
                labelText: 'New Status',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                DropdownMenuItem(value: 'preparing', child: Text('Preparing')),
                DropdownMenuItem(value: 'ready', child: Text('Ready')),
                DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
              ],
              onChanged: (newStatus) async {
                if (newStatus != null) {
                  try {
                    await _firestore
                        .collection('orders')
                        .doc(order['id'])
                        .update({'status': newStatus});
                    Navigator.pop(context);
                    _loadOrders();
                    _loadStats();

                    // 🔔 STOCK REDUCTION LOGIC - Only reduce stock when seller confirms order fulfillment
                    if (['confirmed'].contains(newStatus.toLowerCase())) {
                      try {
                        final items = order['items'] as List<dynamic>?;
                        if (items != null && items.isNotEmpty) {
                          print('📦 Processing stock reduction for ${items.length} items');
                          
                          // Use batch write for atomic stock reduction
                          final batch = FirebaseFirestore.instance.batch();
                          int reducedItems = 0;
                          
                          for (var item in items) {
                            final itemData = item as Map<String, dynamic>;
                            final String? productId = (itemData['id'] ?? itemData['productId'])?.toString();
                            if (productId == null || productId.isEmpty) continue;
                            
                            final int qty = ((itemData['quantity'] ?? 1) as num).toInt();
                            final productRef = FirebaseFirestore.instance.collection('products').doc(productId);
                            
                            // Get current product data to check stock fields
                            final productDoc = await productRef.get();
                            if (!productDoc.exists) {
                              print('⚠️ Product $productId not found, skipping stock reduction');
                              continue;
                            }
                            
                            final productData = productDoc.data() as Map<String, dynamic>;
                            
                            // Check if product has stock tracking enabled
                            final bool hasExplicitStock = productData.containsKey('stock') || productData.containsKey('quantity');
                            if (!hasExplicitStock) {
                              print('ℹ️ Product ${productData['name'] ?? productId} has no stock tracking, skipping');
                              continue;
                            }
                            
                            // Determine which stock field to use and current value
                            int resolveStock(dynamic value) {
                              if (value is int) return value;
                              if (value is num) return value.toInt();
                              if (value is String) return int.tryParse(value) ?? 0;
                              return 0;
                            }
                            
                            final int current = productData.containsKey('stock')
                              ? resolveStock(productData['stock'])
                              : resolveStock(productData['quantity']);
                            
                            final int next = (current - qty).clamp(0, 1 << 31);
                            
                            // Update the appropriate stock field
                            if (productData.containsKey('stock')) {
                              batch.update(productRef, {'stock': next});
                              print('📦 Reducing stock for ${productData['name'] ?? productId}: $current → $next (qty: $qty)');
                            } else if (productData.containsKey('quantity')) {
                              batch.update(productRef, {'quantity': next});
                              print('📦 Reducing quantity for ${productData['name'] ?? productId}: $current → $next (qty: $qty)');
                            }
                            
                            reducedItems++;
                          }
                          
                          // Commit all stock reductions atomically
                          if (reducedItems > 0) {
                            await batch.commit();
                            print('✅ Stock reduced for $reducedItems products in order ${order['orderNumber'] ?? 'unknown'}');
                          } else {
                            print('ℹ️ No products required stock reduction');
                          }
                        }
                      } catch (stockError) {
                        print('❌ Error reducing stock: $stockError');
                        // Don't fail the entire status update if stock reduction fails
                        // Just log the error and continue
                      }
                    }
                  } catch (e) {
                    print('Error updating status: $e');
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showFixOrdersDialog(int orderCount, String wrongSellerId, String correctSellerId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Fix Order Data'),
        content: Text(
          'Found $orderCount order(s) with incorrect seller ID.\n\n'
          'Wrong ID: $wrongSellerId\n'
          'Correct ID: $correctSellerId\n\n'
          'Would you like to fix these orders so you can see them?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _fixOrders(wrongSellerId, correctSellerId);
            },
            child: Text('Fix Orders'),
          ),
        ],
      ),
    );
  }

  Future<void> _fixOrders(String wrongSellerId, String correctSellerId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get all orders with wrong sellerId
      final wrongOrdersSnapshot = await _firestore
          .collection('orders')
          .where('sellerId', isEqualTo: wrongSellerId)
          .get();

      print('🔍 DEBUG: Fixing ${wrongOrdersSnapshot.docs.length} orders...');

      // Update each order
      for (final doc in wrongOrdersSnapshot.docs) {
        await doc.reference.update({
          'sellerId': correctSellerId,
        });
        print('🔍 DEBUG: Fixed order ${doc.id}');
      }

      print('🔍 DEBUG: All orders fixed successfully');

      // Reload orders
      await _loadOrders();
      await _loadStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fixed ${wrongOrdersSnapshot.docs.length} order(s)! You should now see your orders.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      print('❌ Error fixing orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fixing orders: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  @override
  void dispose() {
    try {
      _fadeController.dispose();
      _slideController.dispose();
      _pulseController.dispose();
      _ordersStream?.cancel();
      _scrollController.dispose();
      _searchDebounceTimer?.cancel();
    } catch (e) {
      print('❌ Error in dispose: $e');
    }
    super.dispose();
  }
} 

// Animated background pattern painter
class _AnimatedPatternPainter extends CustomPainter {
  final Animation<double> animation;

  _AnimatedPatternPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.white.withOpacity(0.1)
      ..strokeWidth = 2;

    final path = Path();
    final waveHeight = 20.0 * animation.value;
    final waveWidth = size.width / 8;

    for (double x = 0; x < size.width; x += waveWidth) {
      final y = size.height * 0.5 + math.sin((x + animation.value * 100) * 0.01) * waveHeight;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 