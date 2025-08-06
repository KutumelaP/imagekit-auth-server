import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/order_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/audit_log_service.dart';
import '../constants/app_constants.dart';
import 'dart:async';
import '../services/dashboard_cache_service.dart';

class OptimizedOrderManagementTable extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  const OptimizedOrderManagementTable({Key? key, required this.auth, required this.firestore}) : super(key: key);

  @override
  State<OptimizedOrderManagementTable> createState() => _OptimizedOrderManagementTableState();
}

class _OptimizedOrderManagementTableState extends State<OptimizedOrderManagementTable>
    with AutomaticKeepAliveClientMixin {
  String _searchQuery = '';
  String _statusFilter = 'all';
  Set<String> _selectedOrderIds = {};
  
  // Advanced pagination with dynamic sizing
  int _pageSize = 20;
  int _currentPage = 0;
  bool _hasMoreData = true;
  bool _isLoading = false;
  bool _isInitialLoad = true;
  
  // Performance optimization
  List<DocumentSnapshot> _cachedDocs = [];
  DocumentSnapshot? _lastDocument;
  Timer? _debounceTimer;
  Timer? _autoRefreshTimer;
  
  // Virtual scrolling optimization
  final ScrollController _scrollController = ScrollController();
  final Map<int, Widget> _rowCache = {};
  
  // Search optimization
  final TextEditingController _searchController = TextEditingController();
  String _lastSearchQuery = '';
  
  // Cache service
  final DashboardCacheService _cacheService = DashboardCacheService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeOptimizations();
    _loadInitialData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _autoRefreshTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initializeOptimizations() {
    // Auto-refresh every 30 seconds for real-time updates
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_isLoading) {
        _refreshData();
      }
    });

    // Scroll listener for infinite scrolling
    _scrollController.addListener(_onScroll);

    // Dynamic page size based on screen size
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenHeight = MediaQuery.of(context).size.height;
      if (screenHeight > 800) {
        _pageSize = 30;
      } else if (screenHeight > 600) {
        _pageSize = 25;
      } else {
        _pageSize = 20;
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _isInitialLoad = true;
      _currentPage = 0;
      _cachedDocs.clear();
      _lastDocument = null;
      _rowCache.clear();
    });

    try {
      await _loadMoreData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading orders: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialLoad = false;
        });
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (!_hasMoreData || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      Query query = widget.firestore.collection('orders')
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();
      
      if (mounted) {
        setState(() {
          _cachedDocs.addAll(snapshot.docs);
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _hasMoreData = snapshot.docs.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more orders: $e')),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    _cachedDocs.clear();
    _lastDocument = null;
    _hasMoreData = true;
    _rowCache.clear();
    await _loadMoreData();
  }

  void _debounceSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_lastSearchQuery != query) {
        setState(() {
          _searchQuery = query;
          _lastSearchQuery = query;
          _selectedOrderIds.clear();
          _rowCache.clear(); // Clear cache when search changes
        });
      }
    });
  }

  List<DocumentSnapshot> _getFilteredOrders() {
    return _cachedDocs.where((doc) {
      try {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;
        
        final orderId = doc.id.toLowerCase();
        final customerName = _getCustomerName(data).toLowerCase();
        final status = (data['status']?.toString() ?? 'pending').toLowerCase();
        
        // Search filter
        if (_searchQuery.isNotEmpty) {
          final searchLower = _searchQuery.toLowerCase();
          if (!orderId.contains(searchLower) && 
              !customerName.contains(searchLower)) {
            return false;
          }
        }
        
        // Status filter
        if (_statusFilter != 'all' && status != _statusFilter) {
          return false;
        }
        
        return true;
      } catch (e) {
        print('Error filtering order: $e');
        return false;
      }
    }).toList();
  }

  String _getCustomerName(Map<String, dynamic> data) {
    // First try buyerName from order data
    if (data['buyerName'] != null && data['buyerName'].toString().isNotEmpty) {
      return data['buyerName'].toString();
    }
    // Then try name field (legacy)
    else if (data['name'] != null && data['name'].toString().isNotEmpty) {
      return data['name'].toString();
    }
    // Then try buyerEmail
    else if (data['buyerEmail'] != null && data['buyerEmail'].toString().isNotEmpty) {
      return data['buyerEmail'].toString();
    }
    // Finally return Unknown
    return 'Unknown Customer';
  }

  Widget _buildOptimizedRow(DocumentSnapshot doc, int index) {
    // Use cached row if available
    if (_rowCache.containsKey(index)) {
      return _rowCache[index]!;
    }

    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) {
        return const DataRow(cells: [
          DataCell(Text('Error: Invalid data')),
          DataCell(Text('')),
          DataCell(Text('')),
          DataCell(Text('')),
          DataCell(Text('')),
        ]);
      }
      
      final totalPrice = data['totalPrice'] ?? data['total'] ?? 0.0;
      final status = data['status']?.toString() ?? 'pending';
      final customerName = _getCustomerName(data);
      
      final row = DataRow(
        color: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.hovered)) return Theme.of(context).colorScheme.primary.withOpacity(0.08);
          return null;
        }),
        cells: [
          DataCell(Text(
            OrderUtils.formatShortOrderNumber(data['orderNumber']?.toString() ?? doc.id), 
            style: TextStyle(fontFamily: 'Inter', color: Theme.of(context).colorScheme.onSurface)
          )),
          DataCell(Text(
            customerName, 
            style: TextStyle(fontFamily: 'Inter', color: Theme.of(context).colorScheme.onSurface)
          )),
          DataCell(Text(
            'R${(totalPrice is num ? totalPrice.toStringAsFixed(2) : totalPrice.toString())}', 
            style: TextStyle(fontFamily: 'Inter', color: Theme.of(context).colorScheme.onSurface)
          )),
          DataCell(_statusBadge(status)),
          DataCell(Row(
            children: [
              Tooltip(
                message: 'View order',
                child: IconButton(
                  icon: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSurface),
                  tooltip: 'View',
                  onPressed: () => _showOrderDetailsDialog(doc),
                ),
              ),
              Tooltip(
                message: 'Edit order',
                child: IconButton(
                  icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.onSurface),
                  tooltip: 'Edit',
                  onPressed: () => _showEditDialog(doc),
                ),
              ),
              Tooltip(
                message: 'Delete order',
                child: IconButton(
                  icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.onSurface),
                  tooltip: 'Delete',
                  onPressed: () => _deleteOrder(doc),
                ),
              ),
            ],
          )),
        ],
      );

      // Cache the row
      _rowCache[index] = row;
      return row;
    } catch (e) {
      return DataRow(cells: [
        DataCell(Text('Error: $e')),
        const DataCell(Text('')),
        const DataCell(Text('')),
        const DataCell(Text('')),
        const DataCell(Text('')),
      ]);
    }
  }

  void _showOrderDetailsDialog(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Invalid order data')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Order Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Order ${OrderUtils.formatShortOrderNumber(doc.id)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Buyer: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () {/* TODO: Link to buyer profile */},
                      child: Text(
                        _getCustomerName(data), 
                        style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Seller: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () {/* TODO: Link to seller profile */},
                      child: Text(
                        data['sellerEmail']?.toString() ?? data['sellerId']?.toString() ?? 'Unknown', 
                        style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Status: ${data['status']?.toString() ?? 'pending'}'),
                Text('Total: R${(data['totalPrice'] ?? data['total'] ?? 0.0).toStringAsFixed(2)}'),
                if (data['createdAt'] != null)
                  Text('Created: ${data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate().toString() : data['createdAt'].toString()}'),
                if (data['updatedAt'] != null)
                  Text('Updated: ${data['updatedAt'] is Timestamp ? (data['updatedAt'] as Timestamp).toDate().toString() : data['updatedAt'].toString()}'),
                
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('View Audit Log'),
                      onPressed: () => _showOrderAuditLogDialog(doc.id),
                    ),
                    const SizedBox(width: 8),
                    if ((data['status']?.toString() ?? '') != 'refunded')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.reply),
                        label: const Text('Refund'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(context).colorScheme.onError,
                        ),
                        onPressed: () {/* TODO: Implement refund */},
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error showing order details: $e')),
      );
    }
  }

  void _showEditDialog(DocumentSnapshot doc) {
    // TODO: Implement edit dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality coming soon')),
    );
  }

  void _deleteOrder(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Order'),
        content: Text('Are you sure you want to delete order ${OrderUtils.formatShortOrderNumber(doc.id)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement delete
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete functionality coming soon')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showOrderAuditLogDialog(String orderId) {
    // TODO: Implement audit log dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Audit log functionality coming soon')),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label = status == 'approved'
        ? 'Verified'
        : status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : 'Unknown';
        
    switch (status) {
      case 'approved':
        color = Theme.of(context).colorScheme.primary;
        break;
      case 'delivered':
        color = Theme.of(context).colorScheme.primary;
        break;
      case 'shipped':
        color = Theme.of(context).colorScheme.secondary;
        break;
      case 'processing':
        color = Theme.of(context).colorScheme.primaryContainer;
        break;
      case 'pending':
        color = Theme.of(context).colorScheme.secondaryContainer;
        break;
      case 'cancelled':
        color = Theme.of(context).colorScheme.error;
        break;
      case 'refunded':
        color = Theme.of(context).colorScheme.primary;
        break;
      default:
        color = Theme.of(context).colorScheme.onSurface;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'approved') ...[
            Icon(Icons.verified, color: color, size: 18),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final filteredOrders = _getFilteredOrders();

    return Column(
      children: [
        // Search and filter controls
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search orders...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: _debounceSearch,
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _statusFilter,
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All Status')),
                  const DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  const DropdownMenuItem(value: 'processing', child: Text('Processing')),
                  const DropdownMenuItem(value: 'shipped', child: Text('Shipped')),
                  const DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                  const DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                  const DropdownMenuItem(value: 'refunded', child: Text('Refunded')),
                ],
                onChanged: (value) {
                  setState(() {
                    _statusFilter = value ?? 'all';
                    _rowCache.clear(); // Clear cache when filter changes
                  });
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshData,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        
        // Orders table
        Expanded(
          child: _isInitialLoad
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  controller: _scrollController,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Order ID')),
                      DataColumn(label: Text('Customer')),
                      DataColumn(label: Text('Total')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: filteredOrders.asMap().entries.map((entry) {
                      final index = entry.key;
                      final doc = entry.value;
                      return _buildOptimizedRow(doc, index);
                    }).toList(),
                  ),
                ),
        ),
        
        // Loading indicator for pagination
        if (_isLoading && !_isInitialLoad)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
} 