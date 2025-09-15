import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' as math;
import '../theme/admin_theme.dart';

class EnhancedOrderManagement extends StatefulWidget {
  final FirebaseFirestore firestore;

  const EnhancedOrderManagement({
    Key? key,
    required this.firestore,
  }) : super(key: key);

  @override
  State<EnhancedOrderManagement> createState() => _EnhancedOrderManagementState();
}

class _EnhancedOrderManagementState extends State<EnhancedOrderManagement>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  
  // Filter states
  String _selectedStatus = 'All';
  String _selectedSeller = 'All';
  String _selectedDateRange = 'All';
  String _searchQuery = '';
  
  final List<String> _statuses = ['All', 'pending', 'confirmed', 'preparing', 'ready', 'delivered', 'cancelled'];
  final List<String> _dateRanges = ['All', 'Today', 'This Week', 'This Month', 'Last 30 Days'];
  
  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 20;
  bool _hasMoreData = true;
  
  // Real-time updates
  StreamSubscription<QuerySnapshot>? _ordersSubscription;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadOrders();
    _setupRealTimeUpdates();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _ordersSubscription?.cancel();
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

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    
    try {
      final snapshot = await widget.firestore
          .collection('orders')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      _orders = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading orders: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupRealTimeUpdates() {
    _ordersSubscription = widget.firestore
        .collection('orders')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _orders = snapshot.docs.map((doc) {
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
    _filteredOrders = _orders.where((order) {
      // Status filter
      if (_selectedStatus != 'All' && order['status'] != _selectedStatus) {
        return false;
      }
      
      // Seller filter
      if (_selectedSeller != 'All' && order['sellerId'] != _selectedSeller) {
        return false;
      }
      
      // Date range filter
      if (_selectedDateRange != 'All') {
        final orderDate = (order['timestamp'] as Timestamp?)?.toDate();
        if (orderDate != null) {
          final now = DateTime.now();
          switch (_selectedDateRange) {
            case 'Today':
              if (!_isSameDay(orderDate, now)) return false;
              break;
            case 'This Week':
              if (!_isThisWeek(orderDate)) return false;
              break;
            case 'This Month':
              if (!_isThisMonth(orderDate)) return false;
              break;
            case 'Last 30 Days':
              if (orderDate.isBefore(now.subtract(const Duration(days: 30)))) return false;
              break;
          }
        }
      }
      
      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final orderId = order['id']?.toString().toLowerCase() ?? '';
        final customerName = order['customerName']?.toString().toLowerCase() ?? '';
        final sellerName = order['sellerName']?.toString().toLowerCase() ?? '';
        
        if (!orderId.contains(query) && 
            !customerName.contains(query) && 
            !sellerName.contains(query)) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  bool _isThisWeek(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return date.isAfter(startOfWeek.subtract(const Duration(days: 1)));
  }

  bool _isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await widget.firestore
          .collection('orders')
          .doc(orderId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // 🔔 STOCK REDUCTION LOGIC - Only reduce stock when admin confirms order fulfillment
      if (['confirmed'].contains(newStatus.toLowerCase())) {
        try {
          // Get order data to access items
          final orderDoc = await widget.firestore
              .collection('orders')
              .doc(orderId)
              .get();
          
          if (orderDoc.exists) {
            final orderData = orderDoc.data() as Map<String, dynamic>;
            final items = orderData['items'] as List<dynamic>?;
            
            if (items != null && items.isNotEmpty) {
              print('📦 Processing stock reduction for ${items.length} items');
              
              // Use batch write for atomic stock reduction
              final batch = widget.firestore.batch();
              int reducedItems = 0;
              
              for (var item in items) {
                final itemData = item as Map<String, dynamic>;
                final String? productId = (itemData['id'] ?? itemData['productId'])?.toString();
                if (productId == null || productId.isEmpty) continue;
                
                final int qty = ((itemData['quantity'] ?? 1) as num).toInt();
                final productRef = widget.firestore.collection('products').doc(productId);
                
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
                
                // Use the same logic as UI - take the maximum of both fields
                final int stockValue = resolveStock(productData['stock'] ?? 0);
                final int quantityValue = resolveStock(productData['quantity'] ?? 0);
                final int current = math.max(stockValue, quantityValue);
                
                final int next = (current - qty).clamp(0, 1 << 31);
                
                // Update both stock fields if they exist (keep them synchronized)
                if (productData.containsKey('stock')) {
                  batch.update(productRef, {'stock': next});
                  print('📦 Reducing stock for ${productData['name'] ?? productId}: $current → $next (qty: $qty)');
                }
                if (productData.containsKey('quantity')) {
                  batch.update(productRef, {'quantity': next});
                  print('📦 Reducing quantity for ${productData['name'] ?? productId}: $current → $next (qty: $qty)');
                }
                
                reducedItems++;
              }
              
              // Commit all stock reductions atomically
              if (reducedItems > 0) {
                await batch.commit();
                print('✅ Stock reduced for $reducedItems products in order ${orderData['orderNumber'] ?? 'unknown'}');
              } else {
                print('ℹ️ No products required stock reduction');
              }
            }
          }
        } catch (stockError) {
          print('❌ Error reducing stock: $stockError');
          // Don't fail the entire status update if stock reduction fails
          // Just log the error and continue
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to $newStatus'),
          backgroundColor: AdminTheme.deepTeal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update order status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
              _buildOrderStats(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildOrderList(),
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
                'Enhanced Order Management',
                style: AdminTheme.headlineLarge.copyWith(
                  color: AdminTheme.deepTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Real-time order tracking and management',
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
                  Icons.shopping_cart,
                  color: AdminTheme.angel,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_filteredOrders.length} Orders',
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
        color: AdminTheme.breeze,
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
                hintText: 'Search orders by ID, customer, or seller...',
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
                  'Date Range',
                  _selectedDateRange,
                  _dateRanges,
                  (value) {
                    setState(() {
                      _selectedDateRange = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AdminTheme.angel,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminTheme.silverGray),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSeller,
                      isExpanded: true,
                      hint: Text(
                        'All Sellers',
                        style: AdminTheme.bodyMedium,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'All',
                          child: Text('All Sellers'),
                        ),
                        ..._getUniqueSellers().map((seller) {
                          return DropdownMenuItem(
                            value: seller,
                            child: Text(seller),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedSeller = value;
                          });
                          _applyFilters();
                        }
                      },
                    ),
                  ),
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
                item,
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

  List<String> _getUniqueSellers() {
    final sellers = <String>{};
    for (final order in _orders) {
      final sellerId = order['sellerId']?.toString();
      if (sellerId != null) {
        sellers.add(sellerId);
      }
    }
    return sellers.toList();
  }

  Widget _buildOrderStats() {
    final stats = _calculateOrderStats();
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Orders',
              stats['total'].toString(),
              Icons.shopping_cart,
              AdminTheme.deepTeal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Pending',
              stats['pending'].toString(),
              Icons.pending,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Completed',
              stats['completed'].toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Revenue',
              'R${stats['revenue'].toStringAsFixed(2)}',
              Icons.attach_money,
              AdminTheme.cloud,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Platform Revenue',
              'R${(stats['platformRevenue'] as double).toStringAsFixed(2)}',
              Icons.payments,
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateOrderStats() {
    int total = _filteredOrders.length;
    int pending = 0;
    int completed = 0;
    double revenue = 0.0;
    double platformRevenue = 0.0;
    
    for (final order in _filteredOrders) {
      final status = order['status'] as String? ?? '';
      final totalAmount = (order['total'] as num?)?.toDouble() ?? 0.0;
      final platformFee = (order['platformFee'] as num?)?.toDouble() ?? 0.0;
      final buyerFees = ((order['buyerServiceFee'] as num?)?.toDouble() ?? 0.0) +
          ((order['smallOrderFee'] as num?)?.toDouble() ?? 0.0);
      
      if (status == 'pending' || status == 'confirmed' || status == 'preparing') {
        pending++;
      } else if (status == 'delivered' || status == 'completed') {
        completed++;
        revenue += totalAmount;
        platformRevenue += platformFee + buyerFees;
      }
    }
    
    return {
      'total': total,
      'pending': pending,
      'completed': completed,
      'revenue': revenue,
      'platformRevenue': platformRevenue,
    };
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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

  Widget _buildOrderList() {
    if (_filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: AdminTheme.darkGrey,
            ),
            const SizedBox(height: 16),
            Text(
              'No orders found',
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
      itemCount: _filteredOrders.length,
      itemBuilder: (context, index) {
        final order = _filteredOrders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['id'] as String? ?? '';
    final status = order['status'] as String? ?? 'pending';
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final timestamp = (order['timestamp'] as Timestamp?)?.toDate();
    final customerName = order['customerName'] as String? ?? 'Unknown Customer';
    final sellerId = order['sellerId'] as String? ?? 'Unknown Seller';
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'confirmed':
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'preparing':
        statusColor = Colors.purple;
        statusIcon = Icons.restaurant;
        break;
      case 'ready':
        statusColor = Colors.green;
        statusIcon = Icons.done;
        break;
      case 'delivered':
        statusColor = Colors.green;
        statusIcon = Icons.local_shipping;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.silverGray.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AdminTheme.indigo.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
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
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${orderId.length > 8 ? orderId.substring(0, 8) + '...' : orderId}',
                    style: AdminTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    customerName,
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
                  'R${total.toStringAsFixed(2)}',
                  style: AdminTheme.titleMedium.copyWith(
                    color: AdminTheme.deepTeal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: AdminTheme.labelSmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        subtitle: timestamp != null
            ? Text(
                DateFormat('MMM dd, yyyy - HH:mm').format(timestamp),
                style: AdminTheme.bodySmall.copyWith(
                  color: AdminTheme.darkGrey,
                ),
              )
            : null,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildOrderDetails(order),
                const SizedBox(height: 16),
                _buildStatusActions(orderId, status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(Map<String, dynamic> order) {
    final items = order['items'] as List<dynamic>? ?? [];
    final deliveryAddress = order['deliveryAddress'] as String? ?? 'No address provided';
    final paymentMethod = order['paymentMethod'] as String? ?? 'Unknown';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Details',
          style: AdminTheme.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) {
          final name = item['name'] as String? ?? 'Unknown Item';
          final quantity = item['quantity'] as int? ?? 0;
          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$name x$quantity',
                  style: AdminTheme.bodySmall,
                ),
                Text(
                  'R${price.toStringAsFixed(2)}',
                  style: AdminTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Delivery Address:',
              style: AdminTheme.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: Text(
                deliveryAddress,
                style: AdminTheme.bodySmall,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Payment Method:',
              style: AdminTheme.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              paymentMethod,
              style: AdminTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusActions(String orderId, String currentStatus) {
    final nextStatuses = _getNextStatuses(currentStatus);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Update Status',
          style: AdminTheme.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: nextStatuses.map((status) {
            return ElevatedButton(
              onPressed: () => _updateOrderStatus(orderId, status),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.deepTeal,
                foregroundColor: AdminTheme.angel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                status.toUpperCase(),
                style: AdminTheme.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<String> _getNextStatuses(String currentStatus) {
    switch (currentStatus) {
      case 'pending':
        return ['confirmed', 'cancelled'];
      case 'confirmed':
        return ['preparing', 'cancelled'];
      case 'preparing':
        return ['ready'];
      case 'ready':
        return ['delivered'];
      case 'delivered':
        return [];
      case 'cancelled':
        return [];
      default:
        return ['confirmed', 'cancelled'];
    }
  }
} 