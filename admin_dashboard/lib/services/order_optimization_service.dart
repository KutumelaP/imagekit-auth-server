import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class OrderOptimizationService {
  static final OrderOptimizationService _instance = OrderOptimizationService._internal();
  factory OrderOptimizationService() => _instance;
  OrderOptimizationService._internal();

  // Cache for order data
  final Map<String, Map<String, dynamic>> _orderCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 10);

  // Batch operations
  final List<Map<String, dynamic>> _pendingUpdates = [];
  Timer? _batchTimer;

  // Real-time listeners
  final Map<String, StreamSubscription> _activeListeners = {};

  /// Get optimized order data with caching
  Future<Map<String, dynamic>?> getOrderData(String orderId) async {
    // Check cache first
    if (_orderCache.containsKey(orderId)) {
      final timestamp = _cacheTimestamps[orderId];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _orderCache[orderId];
      }
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _orderCache[orderId] = data;
        _cacheTimestamps[orderId] = DateTime.now();
        return data;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching order data: $e');
      }
    }
    return null;
  }

  /// Batch update orders for better performance
  void queueOrderUpdate(String orderId, Map<String, dynamic> updates) {
    _pendingUpdates.add({
      'orderId': orderId,
      'updates': updates,
      'timestamp': DateTime.now(),
    });

    // Start batch timer if not already running
    _batchTimer ??= Timer(const Duration(seconds: 5), _processBatchUpdates);
  }

  Future<void> _processBatchUpdates() async {
    if (_pendingUpdates.isEmpty) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final processedUpdates = List<Map<String, dynamic>>.from(_pendingUpdates);
      _pendingUpdates.clear();

      for (final update in processedUpdates) {
        final orderRef = FirebaseFirestore.instance
            .collection('orders')
            .doc(update['orderId']);
        
        batch.update(orderRef, update['updates']);
        
        // Update cache
        if (_orderCache.containsKey(update['orderId'])) {
          _orderCache[update['orderId']]!.addAll(update['updates']);
        }
      }

      await batch.commit();
      
      if (kDebugMode) {
        print('✅ Processed ${processedUpdates.length} batch updates');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error processing batch updates: $e');
      }
      // Re-add failed updates
      _pendingUpdates.addAll(processedUpdates);
    } finally {
      _batchTimer = null;
    }
  }

  /// Optimized bulk order operations
  Future<void> bulkUpdateOrders(List<String> orderIds, Map<String, dynamic> updates) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (final orderId in orderIds) {
        final orderRef = FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId);
        batch.update(orderRef, updates);
        
        // Update cache
        if (_orderCache.containsKey(orderId)) {
          _orderCache[orderId]!.addAll(updates);
        }
      }

      await batch.commit();
      
      if (kDebugMode) {
        print('✅ Bulk updated ${orderIds.length} orders');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error bulk updating orders: $e');
      }
      rethrow;
    }
  }

  /// Real-time order monitoring with optimization
  Stream<QuerySnapshot> getOptimizedOrdersStream({
    String? sellerId,
    String? status,
    int limit = 50,
  }) {
    Query query = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (sellerId != null) {
      query = query.where('sellerId', isEqualTo: sellerId);
    }

    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots();
  }

  /// Optimized search with indexing
  Future<List<DocumentSnapshot>> searchOrders(String query, {
    String? sellerId,
    String? status,
    int limit = 20,
  }) async {
    try {
      Query firestoreQuery = FirebaseFirestore.instance
          .collection('orders')
          .limit(limit);

      if (sellerId != null) {
        firestoreQuery = firestoreQuery.where('sellerId', isEqualTo: sellerId);
      }

      if (status != null && status != 'all') {
        firestoreQuery = firestoreQuery.where('status', isEqualTo: status);
      }

      final snapshot = await firestoreQuery.get();
      
      // Client-side filtering for better performance
      return snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final orderId = doc.id.toLowerCase();
        final customerName = _getCustomerName(data).toLowerCase();
        final searchLower = query.toLowerCase();
        
        return orderId.contains(searchLower) || 
               customerName.contains(searchLower);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error searching orders: $e');
      }
      return [];
    }
  }

  String _getCustomerName(Map<String, dynamic> data) {
    if (data['buyerName'] != null && data['buyerName'].toString().isNotEmpty) {
      return data['buyerName'].toString();
    } else if (data['name'] != null && data['name'].toString().isNotEmpty) {
      return data['name'].toString();
    } else if (data['buyerEmail'] != null && data['buyerEmail'].toString().isNotEmpty) {
      return data['buyerEmail'].toString();
    }
    return 'Unknown Customer';
  }

  /// Memory optimization
  void optimizeMemory() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheExpiry) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _orderCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    if (kDebugMode) {
      print('🧹 Cleared ${expiredKeys.length} expired order cache entries');
    }
  }

  /// Clear all cache
  void clearCache() {
    _orderCache.clear();
    _cacheTimestamps.clear();
    
    if (kDebugMode) {
      print('🧹 Cleared all order cache');
    }
  }

  /// Dispose resources
  void dispose() {
    _batchTimer?.cancel();
    for (final listener in _activeListeners.values) {
      listener.cancel();
    }
    _activeListeners.clear();
    clearCache();
  }
} 