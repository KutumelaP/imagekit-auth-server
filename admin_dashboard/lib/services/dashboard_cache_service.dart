import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../utils/order_utils.dart';

class DashboardCacheService extends ChangeNotifier {
  static final DashboardCacheService _instance = DashboardCacheService._internal();
  factory DashboardCacheService() => _instance;
  DashboardCacheService._internal();

  // Cache data
  DashboardStats? _cachedStats;
  DateTime? _lastCacheUpdate;
  List<Map<String, dynamic>>? _cachedRecentActivity;
  DateTime? _lastActivityUpdate;

  // Loading states
  bool _isLoadingStats = false;
  bool _isLoadingActivity = false;

  // Cache duration (5 minutes for stats, 1 minute for activity)
  static const Duration _statsCacheDuration = Duration(minutes: 5);
  static const Duration _activityCacheDuration = Duration(minutes: 1);

  // Getters
  DashboardStats? get cachedStats => _cachedStats;
  List<Map<String, dynamic>>? get cachedRecentActivity => _cachedRecentActivity;
  bool get isLoadingStats => _isLoadingStats;
  bool get isLoadingActivity => _isLoadingActivity;

  bool get _shouldRefreshStats {
    if (_cachedStats == null || _lastCacheUpdate == null) return true;
    return DateTime.now().difference(_lastCacheUpdate!) > _statsCacheDuration;
  }

  bool get _shouldRefreshActivity {
    if (_cachedRecentActivity == null || _lastActivityUpdate == null) return true;
    return DateTime.now().difference(_lastActivityUpdate!) > _activityCacheDuration;
  }

  /// Get dashboard stats with smart caching
  Future<DashboardStats> getDashboardStats(FirebaseFirestore firestore, {bool forceRefresh = false}) async {
    if (!forceRefresh && !_shouldRefreshStats && _cachedStats != null) {
      return _cachedStats!;
    }

    if (_isLoadingStats && _cachedStats != null) {
      return _cachedStats!; // Return cached while loading
    }

    _isLoadingStats = true;
    notifyListeners();

    try {
      final stats = await _fetchDashboardStats(firestore);
      _cachedStats = stats;
      _lastCacheUpdate = DateTime.now();
      
      debugPrint('📊 Dashboard stats cached at ${_lastCacheUpdate}');
      return stats;
    } catch (error) {
      debugPrint('❌ Error fetching dashboard stats: $error');
      // Return cached data if available, otherwise throw
      if (_cachedStats != null) {
        return _cachedStats!;
      }
      rethrow;
    } finally {
      _isLoadingStats = false;
      notifyListeners();
    }
  }

  /// Get recent activity with smart caching
  Future<List<Map<String, dynamic>>> getRecentActivity(FirebaseFirestore firestore, {bool forceRefresh = false}) async {
    if (!forceRefresh && !_shouldRefreshActivity && _cachedRecentActivity != null) {
      return _cachedRecentActivity!;
    }

    if (_isLoadingActivity && _cachedRecentActivity != null) {
      return _cachedRecentActivity!; // Return cached while loading
    }

    _isLoadingActivity = true;
    notifyListeners();

    try {
      final activity = await _fetchRecentActivity(firestore);
      _cachedRecentActivity = activity;
      _lastActivityUpdate = DateTime.now();
      
      debugPrint('🔄 Recent activity cached at ${_lastActivityUpdate}');
      return activity;
    } catch (error) {
      debugPrint('❌ Error fetching recent activity: $error');
      // Return cached data if available, otherwise throw
      if (_cachedRecentActivity != null) {
        return _cachedRecentActivity!;
      }
      rethrow;
    } finally {
      _isLoadingActivity = false;
      notifyListeners();
    }
  }

  /// Force refresh all cached data
  Future<void> refreshAll(FirebaseFirestore firestore) async {
    await Future.wait([
      getDashboardStats(firestore, forceRefresh: true),
      getRecentActivity(firestore, forceRefresh: true),
    ]);
  }

  /// Clear all cached data
  void clearCache() {
    _cachedStats = null;
    _cachedRecentActivity = null;
    _lastCacheUpdate = null;
    _lastActivityUpdate = null;
    notifyListeners();
    debugPrint('🗑️ Dashboard cache cleared');
  }

  /// Private method to fetch dashboard stats from Firestore
  Future<DashboardStats> _fetchDashboardStats(FirebaseFirestore firestore) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayTimestamp = Timestamp.fromDate(today);

    // Execute queries in parallel for better performance
    final futures = await Future.wait([
      firestore.collection('users').get(),
      firestore.collection('users').where('role', isEqualTo: 'seller').get(),
      firestore.collection('users').where('role', isEqualTo: 'seller').where('status', isEqualTo: 'pending').get(),
      firestore.collection('orders').where('timestamp', isGreaterThan: todayTimestamp).get(),
      firestore.collection('orders').get(),
      firestore.collection('reviews').where('timestamp', isGreaterThan: todayTimestamp).get(),
    ]);

    final allUsers = futures[0] as QuerySnapshot;
    final allSellers = futures[1] as QuerySnapshot;
    final pendingSellers = futures[2] as QuerySnapshot;
    final todayOrders = futures[3] as QuerySnapshot;
    final allOrders = futures[4] as QuerySnapshot;
    final todayReviews = futures[5] as QuerySnapshot;

    // Calculate platform fees
    double totalRevenue = 0;
    double todayRevenue = 0;
    
    for (var order in allOrders.docs) {
      final data = order.data() as Map<String, dynamic>;
      final fee = (data['platformFee'] ?? 0.0) as num;
      totalRevenue += fee.toDouble();
    }

    for (var order in todayOrders.docs) {
      final data = order.data() as Map<String, dynamic>;
      final fee = (data['platformFee'] ?? 0.0) as num;
      todayRevenue += fee.toDouble();
    }

    return DashboardStats(
      totalUsers: allUsers.docs.length,
      totalSellers: allSellers.docs.length,
      pendingApprovals: pendingSellers.docs.length,
      todayOrders: todayOrders.docs.length,
      totalOrders: allOrders.docs.length,
      totalRevenue: totalRevenue,
      todayRevenue: todayRevenue,
      todayReviews: todayReviews.docs.length,
      cacheTimestamp: DateTime.now(),
    );
  }

  /// Private method to fetch recent activity from Firestore
  Future<List<Map<String, dynamic>>> _fetchRecentActivity(FirebaseFirestore firestore) async {
    final ordersQuery = await firestore
        .collection('orders')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    final usersQuery = await firestore
        .collection('users')
        .where('role', isEqualTo: 'seller')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();

    List<Map<String, dynamic>> activities = [];

    // Add recent orders
    for (var order in ordersQuery.docs) {
      final data = order.data();
      activities.add({
        'type': 'order',
        'title': 'Order ${OrderUtils.formatShortOrderNumber(data['orderNumber'] ?? '')}',
        'subtitle': 'Total: R${(data['total'] ?? 0).toStringAsFixed(2)}',
        'timestamp': data['timestamp'] as Timestamp?,
        'icon': 'shopping_cart',
        'color': 'blue',
      });
    }

    // Add new sellers
    for (var seller in usersQuery.docs) {
      final data = seller.data();
      activities.add({
        'type': 'seller',
        'title': 'New seller: ${data['businessName'] ?? data['email'] ?? 'Unknown'}',
        'subtitle': 'Status: ${data['status'] ?? 'Unknown'}',
        'timestamp': data['createdAt'] as Timestamp?,
        'icon': 'store',
        'color': 'green',
      });
    }

    // Sort by timestamp
    activities.sort((a, b) {
      final aTime = a['timestamp'] as Timestamp?;
      final bTime = b['timestamp'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return activities.take(15).toList();
  }

  /// Get cache status for debugging
  Map<String, dynamic> getCacheStatus() {
    return {
      'stats_cached': _cachedStats != null,
      'stats_cache_age': _lastCacheUpdate != null 
          ? DateTime.now().difference(_lastCacheUpdate!).inMinutes
          : null,
      'activity_cached': _cachedRecentActivity != null,
      'activity_cache_age': _lastActivityUpdate != null 
          ? DateTime.now().difference(_lastActivityUpdate!).inMinutes
          : null,
      'is_loading_stats': _isLoadingStats,
      'is_loading_activity': _isLoadingActivity,
    };
  }
}

class DashboardStats {
  final int totalUsers;
  final int totalSellers;
  final int pendingApprovals;
  final int todayOrders;
  final int totalOrders;
  final double totalRevenue;
  final double todayRevenue;
  final int todayReviews;
  final DateTime cacheTimestamp;

  DashboardStats({
    required this.totalUsers,
    required this.totalSellers,
    required this.pendingApprovals,
    required this.todayOrders,
    required this.totalOrders,
    required this.totalRevenue,
    required this.todayRevenue,
    required this.todayReviews,
    required this.cacheTimestamp,
  });

  /// Get growth percentage (placeholder - would need historical data)
  double get userGrowth => 12.5; // Mock data
  double get revenueGrowth => 8.3; // Mock data
  double get orderGrowth => 15.7; // Mock data

  /// Get status indicators
  bool get hasHighPendingApprovals => pendingApprovals > 10;
  bool get hasLowDailyOrders => todayOrders < 5;
  bool get hasGoodRevenue => todayRevenue > 100;

  @override
  String toString() {
    return 'DashboardStats(users: $totalUsers, sellers: $totalSellers, '
           'pending: $pendingApprovals, todayOrders: $todayOrders, '
           'revenue: R${totalRevenue.toStringAsFixed(2)})';
  }
} 