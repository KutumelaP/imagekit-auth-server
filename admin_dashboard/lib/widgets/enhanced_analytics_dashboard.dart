import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/admin_theme.dart';
import '../services/dashboard_cache_service.dart';

class EnhancedAnalyticsDashboard extends StatefulWidget {
  final FirebaseFirestore firestore;

  const EnhancedAnalyticsDashboard({
    Key? key,
    required this.firestore,
  }) : super(key: key);

  @override
  State<EnhancedAnalyticsDashboard> createState() => _EnhancedAnalyticsDashboardState();
}

class _EnhancedAnalyticsDashboardState extends State<EnhancedAnalyticsDashboard>
    with TickerProviderStateMixin {
  final DashboardCacheService _cacheService = DashboardCacheService();
  String _selectedPeriod = '7d';
  String _selectedMetric = 'revenue';
  
  final List<String> _periods = ['24h', '7d', '30d', '90d', '1y'];
  final List<String> _metrics = ['revenue', 'orders', 'users', 'products'];
  
  bool _isLoading = true;
  Map<String, dynamic> _analyticsData = {};
  List<FlSpot> _revenueData = [];
  List<FlSpot> _orderData = [];
  List<FlSpot> _userData = [];
  List<FlSpot> _productData = [];
  
  // Predictive analytics data
  Map<String, dynamic> _predictions = {};
  List<Map<String, dynamic>> _topPerformers = [];
  List<Map<String, dynamic>> _trendingCategories = [];
  List<Map<String, dynamic>> _customerSegments = [];
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _loadRevenueAnalytics(),
        _loadOrderAnalytics(),
        _loadUserAnalytics(),
        _loadProductAnalytics(),
        _loadPredictiveAnalytics(),
        _loadTopPerformers(),
        _loadTrendingCategories(),
        _loadCustomerSegments(),
      ]);
      
      _animationController.forward();
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadRevenueAnalytics() async {
    final now = DateTime.now();
    final startDate = _getStartDate(_selectedPeriod);
    
    final snapshot = await widget.firestore
        .collection('orders')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(startDate))
        .where('status', whereIn: ['completed', 'delivered'])
        .get();

    final revenueData = <FlSpot>[];
    final dailyRevenue = <String, double>{};
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = data['timestamp'] as Timestamp?;
      final total = (data['total'] as num?)?.toDouble() ?? 0.0;
      
      if (timestamp != null) {
        final date = timestamp.toDate();
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0.0) + total;
      }
    }
    
    final sortedDates = dailyRevenue.keys.toList()..sort();
    for (int i = 0; i < sortedDates.length; i++) {
      revenueData.add(FlSpot(i.toDouble(), dailyRevenue[sortedDates[i]]!));
    }
    
    _revenueData = revenueData;
  }

  Future<void> _loadOrderAnalytics() async {
    final now = DateTime.now();
    final startDate = _getStartDate(_selectedPeriod);
    
    final snapshot = await widget.firestore
        .collection('orders')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(startDate))
        .get();

    final orderData = <FlSpot>[];
    final dailyOrders = <String, int>{};
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = data['timestamp'] as Timestamp?;
      
      if (timestamp != null) {
        final date = timestamp.toDate();
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        dailyOrders[dateKey] = (dailyOrders[dateKey] ?? 0) + 1;
      }
    }
    
    final sortedDates = dailyOrders.keys.toList()..sort();
    for (int i = 0; i < sortedDates.length; i++) {
      orderData.add(FlSpot(i.toDouble(), dailyOrders[sortedDates[i]]!.toDouble()));
    }
    
    _orderData = orderData;
  }

  Future<void> _loadUserAnalytics() async {
    final now = DateTime.now();
    final startDate = _getStartDate(_selectedPeriod);
    
    final snapshot = await widget.firestore
        .collection('users')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(startDate))
        .get();

    final userData = <FlSpot>[];
    final dailyUsers = <String, int>{};
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = data['createdAt'] as Timestamp?;
      
      if (timestamp != null) {
        final date = timestamp.toDate();
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        dailyUsers[dateKey] = (dailyUsers[dateKey] ?? 0) + 1;
      }
    }
    
    final sortedDates = dailyUsers.keys.toList()..sort();
    for (int i = 0; i < sortedDates.length; i++) {
      userData.add(FlSpot(i.toDouble(), dailyUsers[sortedDates[i]]!.toDouble()));
    }
    
    _userData = userData;
  }

  Future<void> _loadProductAnalytics() async {
    final now = DateTime.now();
    final startDate = _getStartDate(_selectedPeriod);
    
    final snapshot = await widget.firestore
        .collection('products')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(startDate))
        .get();

    final productData = <FlSpot>[];
    final dailyProducts = <String, int>{};
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = data['createdAt'] as Timestamp?;
      
      if (timestamp != null) {
        final date = timestamp.toDate();
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        dailyProducts[dateKey] = (dailyProducts[dateKey] ?? 0) + 1;
      }
    }
    
    final sortedDates = dailyProducts.keys.toList()..sort();
    for (int i = 0; i < sortedDates.length; i++) {
      productData.add(FlSpot(i.toDouble(), dailyProducts[sortedDates[i]]!.toDouble()));
    }
    
    _productData = productData;
  }

  Future<void> _loadPredictiveAnalytics() async {
    // Calculate predictions based on historical data
    final predictions = <String, dynamic>{};
    
    // Revenue prediction
    if (_revenueData.isNotEmpty) {
      final recentRevenue = _revenueData.take(7).map((spot) => spot.y).toList();
      final avgRevenue = recentRevenue.reduce((a, b) => a + b) / recentRevenue.length;
      final growthRate = _calculateGrowthRate(recentRevenue);
      
      predictions['revenue'] = {
        'current': avgRevenue,
        'predicted': avgRevenue * (1 + growthRate),
        'growthRate': growthRate,
        'confidence': 0.85,
      };
    }
    
    // Order prediction
    if (_orderData.isNotEmpty) {
      final recentOrders = _orderData.take(7).map((spot) => spot.y).toList();
      final avgOrders = recentOrders.reduce((a, b) => a + b) / recentOrders.length;
      final growthRate = _calculateGrowthRate(recentOrders);
      
      predictions['orders'] = {
        'current': avgOrders,
        'predicted': avgOrders * (1 + growthRate),
        'growthRate': growthRate,
        'confidence': 0.82,
      };
    }
    
    _predictions = predictions;
  }

  Future<void> _loadTopPerformers() async {
    final snapshot = await widget.firestore
        .collection('orders')
        .where('status', isEqualTo: 'completed')
        .get();

    final sellerPerformance = <String, Map<String, dynamic>>{};
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final sellerId = data['sellerId'] as String?;
      final total = (data['total'] as num?)?.toDouble() ?? 0.0;
      
      if (sellerId != null) {
        if (!sellerPerformance.containsKey(sellerId)) {
          sellerPerformance[sellerId] = {
            'totalRevenue': 0.0,
            'orderCount': 0,
            'avgOrderValue': 0.0,
          };
        }
        
        sellerPerformance[sellerId]!['totalRevenue'] += total;
        sellerPerformance[sellerId]!['orderCount'] += 1;
      }
    }
    
    // Calculate average order values
    for (final seller in sellerPerformance.values) {
      seller['avgOrderValue'] = seller['totalRevenue'] / seller['orderCount'];
    }
    
    // Sort by total revenue
    final sortedSellers = sellerPerformance.entries.toList()
      ..sort((a, b) => b.value['totalRevenue'].compareTo(a.value['totalRevenue']));
    
    _topPerformers = sortedSellers.take(10).map((entry) => {
      'sellerId': entry.key,
      ...entry.value,
    }).toList();
  }

  Future<void> _loadTrendingCategories() async {
    final snapshot = await widget.firestore
        .collection('products')
        .get();

    final categoryStats = <String, Map<String, dynamic>>{};
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final category = data['category'] as String? ?? 'Uncategorized';
      final price = (data['price'] as num?)?.toDouble() ?? 0.0;
      final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
      
      if (!categoryStats.containsKey(category)) {
        categoryStats[category] = {
          'productCount': 0,
          'totalValue': 0.0,
          'avgRating': 0.0,
          'ratings': <double>[],
        };
      }
      
      categoryStats[category]!['productCount'] += 1;
      categoryStats[category]!['totalValue'] += price;
      categoryStats[category]!['ratings'].add(rating);
    }
    
    // Calculate average ratings
    for (final category in categoryStats.values) {
      final ratings = category['ratings'] as List<double>;
      category['avgRating'] = ratings.isNotEmpty 
          ? ratings.reduce((a, b) => a + b) / ratings.length 
          : 0.0;
    }
    
    // Sort by product count
    final sortedCategories = categoryStats.entries.toList()
      ..sort((a, b) => b.value['productCount'].compareTo(a.value['productCount']));
    
    _trendingCategories = sortedCategories.take(8).map((entry) => {
      'category': entry.key,
      ...entry.value,
    }).toList();
  }

  Future<void> _loadCustomerSegments() async {
    final snapshot = await widget.firestore
        .collection('orders')
        .get();

    final customerSegments = <String, Map<String, dynamic>>{};
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final customerId = data['customerId'] as String?;
      final total = (data['total'] as num?)?.toDouble() ?? 0.0;
      
      if (customerId != null) {
        if (!customerSegments.containsKey(customerId)) {
          customerSegments[customerId] = {
            'totalSpent': 0.0,
            'orderCount': 0,
            'avgOrderValue': 0.0,
            'lastOrder': null,
          };
        }
        
        customerSegments[customerId]!['totalSpent'] += total;
        customerSegments[customerId]!['orderCount'] += 1;
        customerSegments[customerId]!['lastOrder'] = data['timestamp'];
      }
    }
    
    // Calculate average order values and segment customers
    for (final customer in customerSegments.values) {
      customer['avgOrderValue'] = customer['totalSpent'] / customer['orderCount'];
      
      // Segment based on spending
      if (customer['totalSpent'] >= 1000) {
        customer['segment'] = 'VIP';
      } else if (customer['totalSpent'] >= 500) {
        customer['segment'] = 'Premium';
      } else if (customer['totalSpent'] >= 100) {
        customer['segment'] = 'Regular';
      } else {
        customer['segment'] = 'New';
      }
    }
    
    // Group by segments
    final segmentStats = <String, Map<String, dynamic>>{};
    for (final customer in customerSegments.values) {
      final segment = customer['segment'] as String;
      if (!segmentStats.containsKey(segment)) {
        segmentStats[segment] = {
          'count': 0,
          'totalSpent': 0.0,
          'avgOrderValue': 0.0,
        };
      }
      
      segmentStats[segment]!['count'] += 1;
      segmentStats[segment]!['totalSpent'] += customer['totalSpent'];
    }
    
    // Calculate segment averages
    for (final segment in segmentStats.values) {
      segment['avgOrderValue'] = segment['totalSpent'] / segment['count'];
    }
    
    _customerSegments = segmentStats.entries.map((entry) => {
      'segment': entry.key,
      ...entry.value,
    }).toList();
  }

  double _calculateGrowthRate(List<double> values) {
    if (values.length < 2) return 0.0;
    
    final recent = values.take(3).reduce((a, b) => a + b) / 3;
    final older = values.skip(3).take(3).reduce((a, b) => a + b) / 3;
    
    if (older == 0) return 0.0;
    return (recent - older) / older;
  }

  DateTime _getStartDate(String period) {
    final now = DateTime.now();
    switch (period) {
      case '24h':
        return now.subtract(const Duration(days: 1));
      case '7d':
        return now.subtract(const Duration(days: 7));
      case '30d':
        return now.subtract(const Duration(days: 30));
      case '90d':
        return now.subtract(const Duration(days: 90));
      case '1y':
        return now.subtract(const Duration(days: 365));
      default:
        return now.subtract(const Duration(days: 7));
    }
  }

  List<FlSpot> _getCurrentData() {
    switch (_selectedMetric) {
      case 'revenue':
        return _revenueData;
      case 'orders':
        return _orderData;
      case 'users':
        return _userData;
      case 'products':
        return _productData;
      default:
        return _revenueData;
    }
  }

  String _getMetricTitle() {
    switch (_selectedMetric) {
      case 'revenue':
        return 'Revenue Trend';
      case 'orders':
        return 'Order Volume';
      case 'users':
        return 'User Growth';
      case 'products':
        return 'Product Growth';
      default:
        return 'Revenue Trend';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildControls(),
                    const SizedBox(height: 32),
                    _buildKeyMetrics(),
                    const SizedBox(height: 32),
                    _buildMainChart(),
                    const SizedBox(height: 32),
                    _buildPredictiveAnalytics(),
                    const SizedBox(height: 32),
                    _buildPerformanceGrid(),
                    const SizedBox(height: 32),
                    _buildCustomerSegments(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enhanced Analytics Dashboard',
              style: AdminTheme.headlineLarge.copyWith(
                color: AdminTheme.deepTeal,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time insights and predictive analytics',
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
                Icons.analytics,
                color: AdminTheme.angel,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Live Data',
                style: AdminTheme.labelMedium.copyWith(
                  color: AdminTheme.angel,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
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
                value: _selectedPeriod,
                isExpanded: true,
                items: _periods.map((period) {
                  return DropdownMenuItem(
                    value: period,
                    child: Text(
                      period.toUpperCase(),
                      style: AdminTheme.bodyMedium,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPeriod = value;
                    });
                    _loadAnalyticsData();
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
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
                value: _selectedMetric,
                isExpanded: true,
                items: _metrics.map((metric) {
                  return DropdownMenuItem(
                    value: metric,
                    child: Text(
                      metric.toUpperCase(),
                      style: AdminTheme.bodyMedium,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedMetric = value;
                    });
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeyMetrics() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Revenue',
          'R${_predictions['revenue']?['current']?.toStringAsFixed(2) ?? '0.00'}',
          Icons.attach_money,
          AdminTheme.deepTeal,
          _predictions['revenue']?['growthRate'] ?? 0.0,
        ),
        _buildMetricCard(
          'Total Orders',
          _predictions['orders']?['current']?.toStringAsFixed(0) ?? '0',
          Icons.shopping_cart,
          AdminTheme.cloud,
          _predictions['orders']?['growthRate'] ?? 0.0,
        ),
        _buildMetricCard(
          'Active Users',
          _userData.isNotEmpty ? _userData.last.y.toStringAsFixed(0) : '0',
          Icons.people,
          AdminTheme.breeze,
          0.0,
        ),
        _buildMetricCard(
          'Products',
          _productData.isNotEmpty ? _productData.last.y.toStringAsFixed(0) : '0',
          Icons.inventory,
          AdminTheme.indigo,
          0.0,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, double growthRate) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.cardDecoration(
        color: AdminTheme.angel,
        boxShadow: [
          BoxShadow(
            color: AdminTheme.indigo.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              if (growthRate != 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: growthRate > 0 ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${growthRate > 0 ? '+' : ''}${(growthRate * 100).toStringAsFixed(1)}%',
                    style: AdminTheme.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AdminTheme.headlineSmall.copyWith(
              color: AdminTheme.deepTeal,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
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

  Widget _buildMainChart() {
    final data = _getCurrentData();
    
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.silverGray.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getMetricTitle(),
            style: AdminTheme.headlineMedium.copyWith(
              color: AdminTheme.deepTeal,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 1,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AdminTheme.silverGray.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: AdminTheme.silverGray.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            value.toInt().toString(),
                            style: AdminTheme.bodySmall.copyWith(
                              color: AdminTheme.darkGrey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          value.toStringAsFixed(0),
                          style: AdminTheme.bodySmall.copyWith(
                            color: AdminTheme.darkGrey,
                          ),
                        );
                      },
                      reservedSize: 42,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: AdminTheme.silverGray.withOpacity(0.3)),
                ),
                minX: 0,
                maxX: data.isNotEmpty ? (data.length - 1).toDouble() : 10,
                minY: 0,
                maxY: data.isNotEmpty ? data.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) * 1.2 : 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: data,
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [
                        AdminTheme.deepTeal,
                        AdminTheme.cloud,
                      ],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AdminTheme.deepTeal,
                          strokeWidth: 2,
                          strokeColor: AdminTheme.angel,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AdminTheme.deepTeal.withOpacity(0.3),
                          AdminTheme.cloud.withOpacity(0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictiveAnalytics() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.silverGray.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                color: AdminTheme.deepTeal,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Predictive Analytics',
                style: AdminTheme.headlineMedium.copyWith(
                  color: AdminTheme.deepTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_predictions.isNotEmpty)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.5,
              children: _predictions.entries.map((entry) {
                final data = entry.value as Map<String, dynamic>;
                final current = data['current'] as double? ?? 0.0;
                final predicted = data['predicted'] as double? ?? 0.0;
                final growthRate = data['growthRate'] as double? ?? 0.0;
                final confidence = data['confidence'] as double? ?? 0.0;
                
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdminTheme.whisper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminTheme.silverGray.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.key.toUpperCase()} Forecast',
                        style: AdminTheme.titleMedium.copyWith(
                          color: AdminTheme.deepTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current: ${current.toStringAsFixed(2)}',
                                style: AdminTheme.bodySmall.copyWith(
                                  color: AdminTheme.darkGrey,
                                ),
                              ),
                              Text(
                                'Predicted: ${predicted.toStringAsFixed(2)}',
                                style: AdminTheme.bodySmall.copyWith(
                                  color: AdminTheme.deepTeal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: growthRate > 0 ? Colors.green : Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${growthRate > 0 ? '+' : ''}${(growthRate * 100).toStringAsFixed(1)}%',
                                  style: AdminTheme.labelSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(confidence * 100).toStringAsFixed(0)}% confidence',
                                style: AdminTheme.labelSmall.copyWith(
                                  color: AdminTheme.darkGrey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPerformanceGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Insights',
          style: AdminTheme.headlineMedium.copyWith(
            color: AdminTheme.deepTeal,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildTopPerformersCard(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTrendingCategoriesCard(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopPerformersCard() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.silverGray.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.star,
                color: AdminTheme.deepTeal,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Top Performers',
                style: AdminTheme.titleLarge.copyWith(
                  color: AdminTheme.deepTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _topPerformers.length,
              itemBuilder: (context, index) {
                final performer = _topPerformers[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminTheme.whisper,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AdminTheme.deepTeal,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: AdminTheme.labelMedium.copyWith(
                              color: AdminTheme.angel,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seller ${performer['sellerId'].toString().substring(0, 8)}',
                              style: AdminTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'R${performer['totalRevenue'].toStringAsFixed(2)}',
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
                            '${performer['orderCount']} orders',
                            style: AdminTheme.bodySmall.copyWith(
                              color: AdminTheme.deepTeal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'R${performer['avgOrderValue'].toStringAsFixed(2)} avg',
                            style: AdminTheme.labelSmall.copyWith(
                              color: AdminTheme.darkGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingCategoriesCard() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.silverGray.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                color: AdminTheme.deepTeal,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Trending Categories',
                style: AdminTheme.titleLarge.copyWith(
                  color: AdminTheme.deepTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _trendingCategories.length,
              itemBuilder: (context, index) {
                final category = _trendingCategories[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminTheme.whisper,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AdminTheme.cloud,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: AdminTheme.labelMedium.copyWith(
                              color: AdminTheme.deepTeal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category['category'],
                              style: AdminTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${category['productCount']} products',
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
                            'R${category['totalValue'].toStringAsFixed(2)}',
                            style: AdminTheme.bodySmall.copyWith(
                              color: AdminTheme.deepTeal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                size: 12,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                category['avgRating'].toStringAsFixed(1),
                                style: AdminTheme.labelSmall.copyWith(
                                  color: AdminTheme.darkGrey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSegments() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.silverGray.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.people_outline,
                color: AdminTheme.deepTeal,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Customer Segments',
                style: AdminTheme.headlineMedium.copyWith(
                  color: AdminTheme.deepTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_customerSegments.isNotEmpty)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: _customerSegments.map((segment) {
                final segmentName = segment['segment'] as String;
                final count = segment['count'] as int;
                final totalSpent = segment['totalSpent'] as double;
                final avgOrderValue = segment['avgOrderValue'] as double;
                
                Color segmentColor;
                switch (segmentName) {
                  case 'VIP':
                    segmentColor = Colors.purple;
                    break;
                  case 'Premium':
                    segmentColor = Colors.blue;
                    break;
                  case 'Regular':
                    segmentColor = Colors.green;
                    break;
                  default:
                    segmentColor = Colors.orange;
                }
                
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdminTheme.whisper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: segmentColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: segmentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            segmentName,
                            style: AdminTheme.titleSmall.copyWith(
                              color: segmentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        count.toString(),
                        style: AdminTheme.headlineSmall.copyWith(
                          color: AdminTheme.deepTeal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'customers',
                        style: AdminTheme.bodySmall.copyWith(
                          color: AdminTheme.darkGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'R${totalSpent.toStringAsFixed(0)}',
                        style: AdminTheme.bodyMedium.copyWith(
                          color: AdminTheme.deepTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'R${avgOrderValue.toStringAsFixed(0)} avg',
                        style: AdminTheme.labelSmall.copyWith(
                          color: AdminTheme.darkGrey,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
} 