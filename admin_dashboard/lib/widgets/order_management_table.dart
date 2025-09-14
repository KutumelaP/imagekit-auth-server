import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/advanced_memory_optimizer.dart';
import '../utils/order_utils.dart';
import 'dart:async';

class OrderManagementTable extends StatefulWidget {
  @override
  _OrderManagementTableState createState() => _OrderManagementTableState();
}

class _OrderManagementTableState extends State<OrderManagementTable> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Advanced pagination
  late OptimizedPagination<Map<String, dynamic>> _pagination;
  bool _isLoading = false;
  bool _hasMoreData = true;
  String? _selectedStatus;
  String? _selectedSeller;
  
  // Stream management
  StreamSubscription? _ordersStream;
  final ScrollController _scrollController = ScrollController();
  
  // Debounced search and filters
  String _searchQuery = '';
  Timer? _searchDebounceTimer;
  Timer? _filterDebounceTimer;
  
  // Cache for seller names
  final Map<String, String> _sellerNameCache = {};

  @override
  void initState() {
    super.initState();
    _pagination = OptimizedPagination<Map<String, dynamic>>(
      pageSize: 20, // Larger page size for admin view
      maxCachedPages: 5, // Keep more pages for admin
    );
    
    _loadOrders();
    _setupScrollListener();
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
    if (_isLoading || !mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Use optimized query with filters
      Query query = _firestore.collection('orders');
      
      if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
        query = query.where('status', isEqualTo: _selectedStatus);
      }
      
      if (_selectedSeller != null && _selectedSeller!.isNotEmpty) {
        query = query.where('sellerId', isEqualTo: _selectedSeller);
      }
      
      // Order by document ID to include both legacy (timestamp) and new (createdAt) orders
      query = query.orderBy(FieldPath.documentId, descending: true).limit(20);
      
      final snapshot = await query.get();
      final processedOrders = await _processOrders(snapshot.docs);
      
      // Clear existing data and add new items
      _pagination.clear();
      _pagination.addItems(processedOrders);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasMoreData = processedOrders.length >= 20;
        });
      }

    } catch (e) {
      print('❌ Error loading orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_isLoading || !_hasMoreData || !mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final currentOrders = _pagination.getCurrentPage();
      final lastOrder = currentOrders.isNotEmpty ? currentOrders.last : null;
      
      Query query = _firestore.collection('orders');
      
      if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
        query = query.where('status', isEqualTo: _selectedStatus);
      }
      
      if (_selectedSeller != null && _selectedSeller!.isNotEmpty) {
        query = query.where('sellerId', isEqualTo: _selectedSeller);
      }
      
      // Order by document ID to include both legacy (timestamp) and new (createdAt) orders
      query = query.orderBy(FieldPath.documentId, descending: true).limit(20);

      if (lastOrder != null) {
        query = query.startAfter([lastOrder['id']]);
      }

      final snapshot = await query.get();
      final newOrders = await _processOrders(snapshot.docs);

      if (newOrders.isNotEmpty) {
        _pagination.addItems(newOrders);
        _pagination.nextPage();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasMoreData = newOrders.length >= 20;
        });
      }

    } catch (e) {
      print('❌ Error loading more orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _processOrders(List<DocumentSnapshot> docs) async {
    final processedOrders = <Map<String, dynamic>>[];
    
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Get customer name using optimized method
      final customerName = _getCustomerName(data);
      
      // Get seller name using cache
      final sellerName = await _getSellerName(data['sellerId'] as String?);
      
      processedOrders.add({
        ...data,
        'customerName': customerName,
        'sellerName': sellerName,
        'id': doc.id,
      });
    }
    
    return processedOrders;
  }

  String _getCustomerName(Map<String, dynamic> data) {
    final buyerDetails = data['buyerDetails'] as Map<String, dynamic>?;
    if (buyerDetails != null) {
      if (buyerDetails['fullName'] != null && buyerDetails['fullName'].toString().isNotEmpty) {
        return buyerDetails['fullName'].toString();
      }
      final firstName = buyerDetails['firstName']?.toString() ?? '';
      final lastName = buyerDetails['lastName']?.toString() ?? '';
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        return '$firstName $lastName'.trim();
      }
      if (buyerDetails['displayName'] != null && buyerDetails['displayName'].toString().isNotEmpty) {
        return buyerDetails['displayName'].toString();
      }
      if (buyerDetails['email'] != null && buyerDetails['email'].toString().isNotEmpty) {
        return buyerDetails['email'].toString();
      }
    }
    // Fallback to legacy fields
    if (data['buyerName'] != null && data['buyerName'].toString().isNotEmpty) {
      return data['buyerName'].toString();
    }
    if (data['name'] != null && data['name'].toString().isNotEmpty) {
      return data['name'].toString();
    }
    if (data['buyerEmail'] != null && data['buyerEmail'].toString().isNotEmpty) {
      return data['buyerEmail'].toString();
    }
    // Finally try phone (top-level or buyerDetails)
    final phoneTop = data['phone']?.toString();
    final phoneBd = (data['buyerDetails'] is Map) ? (data['buyerDetails']['phone']?.toString()) : null;
    final phone = (phoneTop != null && phoneTop.isNotEmpty) ? phoneTop : (phoneBd ?? '');
    if (phone.isNotEmpty) {
      try {
        return phone.length >= 4 ? 'Customer (${phone.substring(phone.length - 4)})' : 'Customer ($phone)';
      } catch (_) {}
    }
    return 'Unknown Customer';
  }

  Future<String> _getSellerName(String? sellerId) async {
    if (sellerId == null || sellerId.isEmpty) return 'Unknown Seller';
    
    // Check cache first
    if (_sellerNameCache.containsKey(sellerId)) {
      return _sellerNameCache[sellerId]!;
    }
    
    try {
      // Use SmartCache to avoid repeated database calls
      final cacheKey = 'seller_$sellerId';
      final cachedName = SmartCache.get<String>(cacheKey);
      if (cachedName != null) {
        _sellerNameCache[sellerId] = cachedName;
        return cachedName;
      }
      
      final doc = await _firestore.collection('users').doc(sellerId).get();
      final data = doc.data();
      if (data == null) return 'Unknown Seller';
      
      final name = data['name'] ?? data['displayName'] ?? data['email'] ?? 'Unknown Seller';
      
      // Cache the result
      SmartCache.set(cacheKey, name);
      _sellerNameCache[sellerId] = name;
      
      return name;
    } catch (e) {
      print('Error loading seller name: $e');
      return 'Unknown Seller';
    }
  }

  void _onSearchChanged(String query) {
    // Debounce search to reduce database calls
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = query;
        });
        _loadOrders();
      }
    });
  }

  void _onStatusChanged(String? status) {
    // Debounce filter changes
    _filterDebounceTimer?.cancel();
    _filterDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _selectedStatus = status;
        });
        _loadOrders();
      }
    });
  }

  void _onSellerChanged(String? sellerId) {
    // Debounce filter changes
    _filterDebounceTimer?.cancel();
    _filterDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _selectedSeller = sellerId;
        });
        _loadOrders();
      }
    });
  }

  List<Map<String, dynamic>> _getFilteredOrders() {
    final allOrders = _pagination.getCurrentPage();
    
    return allOrders.where((order) {
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final customerName = order['customerName']?.toString().toLowerCase() ?? '';
        final sellerName = order['sellerName']?.toString().toLowerCase() ?? '';
        final orderId = order['id']?.toString().toLowerCase() ?? '';
        
        if (!customerName.contains(_searchQuery.toLowerCase()) &&
            !sellerName.contains(_searchQuery.toLowerCase()) &&
            !orderId.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _getFilteredOrders();
    
    return Column(
      children: [
        // Search and filter controls
        Container(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Search bar
                  Expanded(
                    flex: 2,
                    child: TextField(
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search orders, customers, or sellers...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  // Status filter
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      hint: Text('Status'),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(value: null, child: Text('All Status')),
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                        DropdownMenuItem(value: 'preparing', child: Text('Preparing')),
                        DropdownMenuItem(value: 'ready', child: Text('Ready')),
                        DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                      ],
                      onChanged: _onStatusChanged,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Orders table
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: DataTable(
              columns: [
                DataColumn(label: Text('Order ID')),
                DataColumn(label: Text('Customer')),
                DataColumn(label: Text('Seller')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Total')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Actions')),
              ],
              rows: filteredOrders.map((data) {
                return DataRow(
                  cells: [
                    DataCell(Text(
                      OrderUtils.formatShortOrderNumber(data['id']?.toString() ?? 'N/A'),
                      style: TextStyle(fontFamily: 'Inter', color: Theme.of(context).colorScheme.onSurface)
                    )),
                    DataCell(Text(
                      _getCustomerName(data),
                      style: TextStyle(fontFamily: 'Inter', color: Theme.of(context).colorScheme.onSurface)
                    )),
                    DataCell(Text(
                      data['sellerName']?.toString() ?? 'Unknown Seller',
                      style: TextStyle(fontFamily: 'Inter', color: Theme.of(context).colorScheme.onSurface)
                    )),
                    DataCell(Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(data['status'] ?? 'pending'),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (data['status'] ?? 'pending').toString().toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )),
                    DataCell(Text(
                      'R${(_extractTotal(data)).toStringAsFixed(2)}',
                      style: TextStyle(fontFamily: 'Inter', color: Theme.of(context).colorScheme.onSurface)
                    )),
                    DataCell(Text(
                      _formatTimestamp(data['createdAt'] ?? data['timestamp']),
                      style: TextStyle(fontFamily: 'Inter', color: Theme.of(context).colorScheme.onSurface)
                    )),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.visibility, size: 20),
                          onPressed: () => _viewOrderDetails(data),
                          tooltip: 'View Details',
                        ),
                        IconButton(
                          icon: Icon(Icons.edit, size: 20),
                          onPressed: () => _editOrder(data),
                          tooltip: 'Edit Order',
                        ),
                      ],
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        // Loading indicator
        if (_isLoading)
          Container(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.purple;
      case 'ready':
        return Colors.green;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year}';
      } else if (timestamp is DateTime) {
        final date = timestamp;
        return '${date.day}/${date.month}/${date.year}';
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  double _extractTotal(Map<String, dynamic> data) {
    try {
      // Prefer pricing.grandTotal, fallback to total or totalPrice
      if (data['pricing'] is Map) {
        final p = data['pricing'] as Map;
        final v = p['grandTotal'];
        if (v is num) return v.toDouble();
      }
      final total = data['total'] ?? data['totalPrice'] ?? 0.0;
      if (total is num) return total.toDouble();
      return double.tryParse(total.toString()) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  void _viewOrderDetails(Map<String, dynamic> order) {
    // Navigate to order details
    Navigator.pushNamed(
      context,
      '/admin-order-detail',
      arguments: order,
    );
  }

  void _editOrder(Map<String, dynamic> order) {
    // Show edit dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Order'),
        content: Text('Edit functionality coming soon...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Cancel all async operations and timers
    _ordersStream?.cancel();
    _searchDebounceTimer?.cancel();
    _filterDebounceTimer?.cancel();
    
    // Dispose controllers
    _scrollController.dispose();
    
    // Clear cache
    _sellerNameCache.clear();
    
    super.dispose();
  }
} 