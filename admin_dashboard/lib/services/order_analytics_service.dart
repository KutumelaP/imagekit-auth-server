import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class OrderAnalyticsService {
  static final OrderAnalyticsService _instance = OrderAnalyticsService._internal();
  factory OrderAnalyticsService() => _instance;
  OrderAnalyticsService._internal();

  // Analytics cache
  final Map<String, dynamic> _analyticsCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 15);

  // Real-time analytics
  StreamSubscription? _analyticsSubscription;
  final StreamController<Map<String, dynamic>> _analyticsController = 
      StreamController<Map<String, dynamic>>.broadcast();

  /// Get optimized order analytics
  Future<Map<String, dynamic>> getOrderAnalytics({
    String? sellerId,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'analytics_${sellerId ?? 'all'}_${startDate?.millisecondsSinceEpoch ?? 0}_${endDate?.millisecondsSinceEpoch ?? 0}';
    
    // Check cache first
    if (!forceRefresh && _analyticsCache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _analyticsCache[cacheKey];
      }
    }

    try {
      final analytics = await _calculateAnalytics(sellerId, startDate, endDate);
      
      // Cache results
      _analyticsCache[cacheKey] = analytics;
      _cacheTimestamps[cacheKey] = DateTime.now();
      
      return analytics;
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating order analytics: $e');
      }
      return _getDefaultAnalytics();
    }
  }

  Future<Map<String, dynamic>> _calculateAnalytics(
    String? sellerId,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    final now = DateTime.now();
    final start = startDate ?? DateTime(now.year, now.month, 1);
    final end = endDate ?? now;
    
    Query query = FirebaseFirestore.instance.collection('orders');
    
    if (sellerId != null) {
      query = query.where('sellerId', isEqualTo: sellerId);
    }
    
    query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                 .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end));

    final snapshot = await query.get();
    
    final orders = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();

    return _processAnalytics(orders, start, end);
  }

  Map<String, dynamic> _processAnalytics(List<Map<String, dynamic>> orders, DateTime start, DateTime end) {
    if (orders.isEmpty) {
      return _getDefaultAnalytics();
    }

    // Calculate key metrics
    double totalRevenue = 0;
    double totalPlatformFees = 0;
    int totalOrders = orders.length;
    int pendingOrders = 0;
    int completedOrders = 0;
    int cancelledOrders = 0;
    
    final statusCounts = <String, int>{};
    final dailyRevenue = <String, double>{};
    final topProducts = <String, int>{};

    for (final order in orders) {
      final status = order['status']?.toString() ?? 'pending';
      final revenue = (order['totalPrice'] ?? order['total'] ?? 0.0) as num;
      final platformFee = (order['platformFee'] ?? 0.0) as num;
      final timestamp = order['timestamp'] as Timestamp?;
      
      totalRevenue += revenue.toDouble();
      totalPlatformFees += platformFee.toDouble();
      
      // Status counts
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      
      switch (status) {
        case 'pending':
          pendingOrders++;
          break;
        case 'delivered':
        case 'completed':
          completedOrders++;
          break;
        case 'cancelled':
          cancelledOrders++;
          break;
      }
      
      // Daily revenue
      if (timestamp != null) {
        final dateKey = '${timestamp.toDate().year}-${timestamp.toDate().month.toString().padLeft(2, '0')}-${timestamp.toDate().day.toString().padLeft(2, '0')}';
        dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0) + revenue.toDouble();
      }
      
      // Top products
      final items = order['items'] as List?;
      if (items != null) {
        for (final item in items) {
          final productName = item['name']?.toString() ?? 'Unknown';
          topProducts[productName] = (topProducts[productName] ?? 0) + 1;
        }
      }
    }

    // Calculate averages and trends
    final avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;
    final completionRate = totalOrders > 0 ? (completedOrders / totalOrders) * 100 : 0;
    final cancellationRate = totalOrders > 0 ? (cancelledOrders / totalOrders) * 100 : 0;

    // Sort top products
    final sortedTopProducts = topProducts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'totalRevenue': totalRevenue,
      'totalPlatformFees': totalPlatformFees,
      'totalOrders': totalOrders,
      'pendingOrders': pendingOrders,
      'completedOrders': completedOrders,
      'cancelledOrders': cancelledOrders,
      'avgOrderValue': avgOrderValue,
      'completionRate': completionRate,
      'cancellationRate': cancellationRate,
      'statusCounts': statusCounts,
      'dailyRevenue': dailyRevenue,
      'topProducts': sortedTopProducts.take(10).map((e) => {
        'name': e.key,
        'count': e.value,
      }).toList(),
      'period': {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      },
    };
  }

  Map<String, dynamic> _getDefaultAnalytics() {
    return {
      'totalRevenue': 0.0,
      'totalPlatformFees': 0.0,
      'totalOrders': 0,
      'pendingOrders': 0,
      'completedOrders': 0,
      'cancelledOrders': 0,
      'avgOrderValue': 0.0,
      'completionRate': 0.0,
      'cancellationRate': 0.0,
      'statusCounts': {},
      'dailyRevenue': {},
      'topProducts': [],
      'period': {
        'start': DateTime.now().toIso8601String(),
        'end': DateTime.now().toIso8601String(),
      },
    };
  }

  /// Get real-time order analytics stream
  Stream<Map<String, dynamic>> getRealTimeAnalytics({
    String? sellerId,
    Duration updateInterval = const Duration(minutes: 5),
  }) {
    _analyticsSubscription?.cancel();
    
    _analyticsSubscription = Stream.periodic(updateInterval).asyncMap((_) async {
      return await getOrderAnalytics(sellerId: sellerId, forceRefresh: true);
    }).listen((analytics) {
      _analyticsController.add(analytics);
    });

    return _analyticsController.stream;
  }

  /// Get optimized order trends
  Future<List<Map<String, dynamic>>> getOrderTrends({
    String? sellerId,
    int days = 30,
  }) async {
    final now = DateTime.now();
    final trends = <Map<String, dynamic>>[];
    
    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      final nextDate = date.add(const Duration(days: 1));
      
      final analytics = await getOrderAnalytics(
        sellerId: sellerId,
        startDate: date,
        endDate: nextDate,
      );
      
      trends.add({
        'date': date.toIso8601String(),
        'orders': analytics['totalOrders'],
        'revenue': analytics['totalRevenue'],
        'avgOrderValue': analytics['avgOrderValue'],
      });
    }
    
    return trends;
  }

  /// Get performance insights
  Future<Map<String, dynamic>> getPerformanceInsights({
    String? sellerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final analytics = await getOrderAnalytics(
      sellerId: sellerId,
      startDate: startDate,
      endDate: endDate,
    );
    
    final insights = <String, dynamic>{};
    
    // Revenue insights
    if (analytics['totalRevenue'] > 0) {
      insights['revenueGrowth'] = _calculateGrowthRate(analytics['totalRevenue']);
      insights['revenueTrend'] = analytics['totalRevenue'] > 1000 ? 'Strong' : 'Moderate';
    }
    
    // Order insights
    if (analytics['totalOrders'] > 0) {
      insights['orderEfficiency'] = analytics['completionRate'] > 80 ? 'Excellent' : 'Good';
      insights['orderTrend'] = analytics['totalOrders'] > 50 ? 'High Volume' : 'Moderate Volume';
    }
    
    // Performance recommendations
    final recommendations = <String>[];
    
    if (analytics['cancellationRate'] > 10) {
      recommendations.add('High cancellation rate detected. Review order processing workflow.');
    }
    
    if (analytics['avgOrderValue'] < 100) {
      recommendations.add('Consider upselling strategies to increase average order value.');
    }
    
    if (analytics['pendingOrders'] > analytics['totalOrders'] * 0.3) {
      recommendations.add('High number of pending orders. Review order fulfillment process.');
    }
    
    insights['recommendations'] = recommendations;
    
    return insights;
  }

  double _calculateGrowthRate(double currentValue) {
    // Simplified growth calculation - in real app, compare with previous period
    return currentValue > 0 ? 15.0 : 0.0; // Placeholder
  }

  /// Clear analytics cache
  void clearCache() {
    _analyticsCache.clear();
    _cacheTimestamps.clear();
    
    if (kDebugMode) {
      print('🧹 Cleared analytics cache');
    }
  }

  /// Dispose resources
  void dispose() {
    _analyticsSubscription?.cancel();
    _analyticsController.close();
    clearCache();
  }
} 