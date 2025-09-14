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
  Map<String, int>? _cachedQuickCounts;
  DateTime? _lastQuickCountsUpdate;
  List<Map<String, dynamic>>? _cachedRecentActivity;
  DateTime? _lastActivityUpdate;

  // Loading states
  bool _isLoadingStats = false;
  bool _isLoadingActivity = false;
  bool _isLoadingQuickCounts = false;

  // Cache duration (5 minutes for stats, 1 minute for activity)
  static const Duration _statsCacheDuration = Duration(minutes: 5);
  static const Duration _activityCacheDuration = Duration(minutes: 1);
  static const Duration _quickCountsCacheDuration = Duration(seconds: 20);

  // Getters
  DashboardStats? get cachedStats => _cachedStats;
  List<Map<String, dynamic>>? get cachedRecentActivity => _cachedRecentActivity;
  bool get isLoadingStats => _isLoadingStats;
  bool get isLoadingActivity => _isLoadingActivity;
  Map<String, int>? get cachedQuickCounts => _cachedQuickCounts;
  bool get isLoadingQuickCounts => _isLoadingQuickCounts;

  bool get _shouldRefreshStats {
    if (_cachedStats == null || _lastCacheUpdate == null) return true;
    return DateTime.now().difference(_lastCacheUpdate!) > _statsCacheDuration;
  }

  bool get _shouldRefreshActivity {
    if (_cachedRecentActivity == null || _lastActivityUpdate == null) return true;
    return DateTime.now().difference(_lastActivityUpdate!) > _activityCacheDuration;
  }

  bool get _shouldRefreshQuickCounts {
    if (_cachedQuickCounts == null || _lastQuickCountsUpdate == null) return true;
    return DateTime.now().difference(_lastQuickCountsUpdate!) > _quickCountsCacheDuration;
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

  /// Quick counts to show while full stats load
  Future<Map<String, int>> getQuickCounts(FirebaseFirestore firestore, {bool forceRefresh = false}) async {
    if (!forceRefresh && !_shouldRefreshQuickCounts && _cachedQuickCounts != null) {
      return _cachedQuickCounts!;
    }

    if (_isLoadingQuickCounts && _cachedQuickCounts != null) {
      return _cachedQuickCounts!;
    }

    _isLoadingQuickCounts = true;
    notifyListeners();

    try {
      final users = await firestore.collection('users').count().get();
      final sellers = await firestore.collection('users').where('role', isEqualTo: 'seller').count().get();
      final pendingSellers = await firestore.collection('users').where('role', isEqualTo: 'seller').where('status', isEqualTo: 'pending').count().get();

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final todayOrders = await firestore
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .count()
          .get();

      final pendingKyc = await firestore.collection('users').where('kycStatus', isEqualTo: 'pending').count().get();

      _cachedQuickCounts = {
        'totalUsers': users.count ?? 0,
        'totalSellers': sellers.count ?? 0,
        'pendingApprovals': pendingSellers.count ?? 0,
        'todayOrders': todayOrders.count ?? 0,
        'pendingKyc': pendingKyc.count ?? 0,
      };
      _lastQuickCountsUpdate = DateTime.now();
      return _cachedQuickCounts!;
    } catch (e) {
      debugPrint('❌ Error fetching quick counts: $e');
      if (_cachedQuickCounts != null) return _cachedQuickCounts!;
      rethrow;
    } finally {
      _isLoadingQuickCounts = false;
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
    // Fetch all users and sellers
    final allUsers = await firestore.collection('users').get();
    final allSellers = await firestore.collection('users').where('role', isEqualTo: 'seller').get();
    final pendingSellers = await firestore.collection('users').where('role', isEqualTo: 'seller').where('status', isEqualTo: 'pending').get();
    
    // Fetch orders for today, last 30 days, and total
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOf30Days = now.subtract(const Duration(days: 30));
    final todayOrders = await firestore
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();
    final allOrders = await firestore.collection('orders').get();
    final last30Orders = await firestore
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOf30Days))
        .get();
    
    // Fetch reviews for today
    final todayReviews = await firestore
        .collection('reviews')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();
    
    // Fetch KYC data
    final pendingKycUsers = await firestore.collection('users').where('kycStatus', isEqualTo: 'pending').get();
    final approvedKycUsers = await firestore.collection('users').where('kycStatus', isEqualTo: 'approved').get();
    final rejectedKycUsers = await firestore.collection('users').where('kycStatus', isEqualTo: 'rejected').get();
    
    // Calculate revenue and GMV windows
    double totalRevenue = 0.0;
    double todayRevenue = 0.0;
    double last30Gmv = 0.0;
    double last30PlatformFee = 0.0;
    
    for (var doc in allOrders.docs) {
      final data = doc.data();
      final fee = (data['platformFee'] ?? 0.0) as num;
      totalRevenue += fee.toDouble();
    }
    
    for (var doc in todayOrders.docs) {
      final data = doc.data();
      final fee = (data['platformFee'] ?? 0.0) as num;
      todayRevenue += fee.toDouble();
    }

    for (var doc in last30Orders.docs) {
      final data = doc.data();
      // GMV approximation: prefer pricing.grandTotal, then totalPrice, else orderTotal, else totalAmount
      final num gmvComponent = (data['pricing']?['grandTotal'] ?? data['totalPrice'] ?? data['orderTotal'] ?? data['totalAmount'] ?? 0.0) as num;
      last30Gmv += gmvComponent.toDouble();
      final fee = (data['platformFee'] ?? 0.0) as num;
      if (fee == 0.0) {
        // fallback compute if needed
        final pfPct = (data['platformFeePercent'] ?? 0.0) as num;
        last30PlatformFee += (gmvComponent.toDouble() * (pfPct.toDouble() / 100.0));
      } else {
        last30PlatformFee += fee.toDouble();
      }
    }

    return DashboardStats(
      totalUsers: allUsers.docs.length,
      totalSellers: allSellers.docs.length,
      pendingApprovals: pendingSellers.docs.length,
      todayOrders: todayOrders.docs.length,
      totalOrders: allOrders.docs.length,
      totalRevenue: totalRevenue,
      todayRevenue: todayRevenue,
      last30Gmv: last30Gmv,
      last30PlatformFee: last30PlatformFee,
      todayReviews: todayReviews.docs.length,
      pendingKycSubmissions: pendingKycUsers.docs.length,
      totalKycApproved: approvedKycUsers.docs.length,
      totalKycRejected: rejectedKycUsers.docs.length,
      cacheTimestamp: DateTime.now(),
    );
  }

  /// Private method to fetch recent activity from Firestore
  Future<List<Map<String, dynamic>>> _fetchRecentActivity(FirebaseFirestore firestore) async {
    final ordersQuery = await firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
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
      'quick_counts_cached': _cachedQuickCounts != null,
      'quick_counts_age_secs': _lastQuickCountsUpdate != null 
          ? DateTime.now().difference(_lastQuickCountsUpdate!).inSeconds
          : null,
      'is_loading_quick_counts': _isLoadingQuickCounts,
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
  final double last30Gmv;
  final double last30PlatformFee;
  final int todayReviews;
  final int pendingKycSubmissions;
  final int totalKycApproved;
  final int totalKycRejected;
  final DateTime cacheTimestamp;

  DashboardStats({
    required this.totalUsers,
    required this.totalSellers,
    required this.pendingApprovals,
    required this.todayOrders,
    required this.totalOrders,
    required this.totalRevenue,
    required this.todayRevenue,
    required this.last30Gmv,
    required this.last30PlatformFee,
    required this.todayReviews,
    required this.pendingKycSubmissions,
    required this.totalKycApproved,
    required this.totalKycRejected,
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
  bool get hasPendingKyc => pendingKycSubmissions > 0;

  @override
  String toString() {
    return 'DashboardStats(users: $totalUsers, sellers: $totalSellers, '
           'pending: $pendingApprovals, todayOrders: $todayOrders, '
           'revenue: R${totalRevenue.toStringAsFixed(2)}, '
           'pendingKyc: $pendingKycSubmissions)';
  }
} 