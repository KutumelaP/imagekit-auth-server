import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'skeleton_loading.dart';

class StatisticsSection extends StatefulWidget {
  const StatisticsSection({Key? key}) : super(key: key);

  @override
  State<StatisticsSection> createState() => _StatisticsSectionState();
}

class _StatisticsSectionState extends State<StatisticsSection> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentOrders = [];
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _userGrowth = [];
  List<Map<String, dynamic>> _revenueData = [];

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _loadBasicStats(),
        _loadRecentOrders(),
        _loadTopProducts(),
        _loadUserGrowth(),
        _loadRevenueData(),
      ]);
    } catch (e) {
      debugPrint('Error loading statistics: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadBasicStats() async {
    try {
      // Simplified queries without complex filters to avoid index requirements
      final usersSnapshot = await _firestore.collection('users').limit(1000).get();
      final productsSnapshot = await _firestore.collection('products').limit(1000).get();
      final ordersSnapshot = await _firestore.collection('orders').limit(1000).get();
      final reviewsSnapshot = await _firestore.collection('reviews').limit(1000).get();
      final categoriesSnapshot = await _firestore.collection('categories').limit(100).get();
      
      // Count in memory to avoid index requirements
      int userCount = 0;
      int sellerCount = 0;
      
      for (final doc in usersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['role'] == 'user') userCount++;
        if (data['role'] == 'seller') sellerCount++;
      }
      
      final totalProducts = productsSnapshot.docs.length;
      final totalOrders = ordersSnapshot.docs.length;
      final totalReviews = reviewsSnapshot.docs.length;
      final totalCategories = categoriesSnapshot.docs.length;
      
      // Calculate revenue in memory
      double totalRevenue = 0;
      double totalPlatformFees = 0;
      
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalRevenue += (data['totalAmount'] ?? 0.0) as double;
        totalPlatformFees += (data['platformFee'] ?? 0.0) as double;
      }
      
      // Calculate averages
      final avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;
      final avgRating = totalReviews > 0 ? _calculateAverageRating(reviewsSnapshot.docs) : 0;
      
      if (mounted) {
        setState(() {
          _stats = {
            'totalUsers': userCount,
            'totalSellers': sellerCount,
            'totalProducts': totalProducts,
            'totalOrders': totalOrders,
            'totalRevenue': totalRevenue,
            'totalPlatformFees': totalPlatformFees,
            'totalReviews': totalReviews,
            'totalCategories': totalCategories,
            'avgOrderValue': avgOrderValue,
            'avgRating': avgRating,
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading basic stats: $e');
    }
  }

  double _calculateAverageRating(List<QueryDocumentSnapshot> reviews) {
    if (reviews.isEmpty) return 0;
    double totalRating = 0;
    for (var doc in reviews) {
      final data = doc.data() as Map<String, dynamic>;
      totalRating += (data['rating'] ?? 0) as double;
    }
    return totalRating / reviews.length;
  }

  Future<void> _loadRecentOrders() async {
    try {
      // Simplified query without orderBy to avoid index requirements
      final snapshot = await _firestore
          .collection('orders')
          .limit(20) // Get more and sort in memory
          .get();
      
      if (mounted) {
        setState(() {
          // Sort in memory by createdAt timestamp
          final sortedDocs = snapshot.docs.toList()
            ..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['createdAt'] as Timestamp?;
              final bTime = bData['createdAt'] as Timestamp?;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime); // Descending order
            });
          
          _recentOrders = sortedDocs.take(10).map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'buyerName': data['buyerName'] ?? data['customerName'] ?? data['userName'] ?? 'Customer',
              'totalAmount': data['totalAmount'] ?? data['amount'] ?? 0.0,
              'status': data['status'] ?? 'pending',
              'createdAt': data['createdAt'],
              'items': data['items'] ?? [],
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading recent orders: $e');
    }
  }

  Future<void> _loadTopProducts() async {
    try {
      // Simplified query without orderBy to avoid index requirements
      final snapshot = await _firestore
          .collection('products')
          .limit(50) // Get more and sort in memory
          .get();
      
      if (mounted) {
        setState(() {
          // Sort in memory by salesCount
          final sortedDocs = snapshot.docs.toList()
            ..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aSales = aData['salesCount'] ?? 0;
              final bSales = bData['salesCount'] ?? 0;
              return bSales.compareTo(aSales); // Descending order
            });
          
          _topProducts = sortedDocs.take(10).map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'] ?? 'Unknown Product',
              'price': data['price'] ?? 0.0,
              'salesCount': data['salesCount'] ?? 0,
              'rating': data['rating'] ?? 0.0,
              'imageUrl': data['imageUrl'],
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading top products: $e');
    }
  }

  Future<void> _loadUserGrowth() async {
    try {
      // Simplified approach - get all users and calculate growth in memory
      final snapshot = await _firestore
          .collection('users')
          .limit(1000)
          .get();
      
      if (mounted) {
        final now = DateTime.now();
        final List<Map<String, dynamic>> growth = [];
        
        // Calculate growth for last 30 days
        for (int i = 30; i >= 0; i--) {
          final date = now.subtract(Duration(days: i));
          final startOfDay = DateTime(date.year, date.month, date.day);
          final endOfDay = startOfDay.add(const Duration(days: 1));
          
          int count = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final createdAt = data['createdAt'] as Timestamp?;
            if (createdAt != null) {
              final userDate = createdAt.toDate();
              if (userDate.isAfter(startOfDay) && userDate.isBefore(endOfDay)) {
                count++;
              }
            }
          }
          
          growth.add({
            'date': startOfDay,
            'count': count,
          });
        }
        
        setState(() {
          _userGrowth = growth;
        });
      }
    } catch (e) {
      debugPrint('Error loading user growth: $e');
    }
  }

  Future<void> _loadRevenueData() async {
    try {
      // Simplified approach - get all orders and calculate revenue in memory
      final snapshot = await _firestore
          .collection('orders')
          .limit(1000)
          .get();
      
      if (mounted) {
        final now = DateTime.now();
        final List<Map<String, dynamic>> revenue = [];
        
        // Calculate revenue for last 7 days
        for (int i = 7; i >= 0; i--) {
          final date = now.subtract(Duration(days: i));
          final startOfDay = DateTime(date.year, date.month, date.day);
          final endOfDay = startOfDay.add(const Duration(days: 1));
          
          double dailyRevenue = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final createdAt = data['createdAt'] as Timestamp?;
            if (createdAt != null) {
              final orderDate = createdAt.toDate();
              if (orderDate.isAfter(startOfDay) && orderDate.isBefore(endOfDay)) {
                dailyRevenue += (data['totalAmount'] ?? 0.0) as double;
              }
            }
          }
          
          revenue.add({
            'date': startOfDay,
            'revenue': dailyRevenue,
          });
        }
        
        setState(() {
          _revenueData = revenue;
        });
      }
    } catch (e) {
      debugPrint('Error loading revenue data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildStatsGrid(),
          const SizedBox(height: 24),
          // Responsive chart layout
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1200) {
                // Desktop: Side by side
                return Row(
                  children: [
                    Expanded(child: _buildRevenueChart()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildUserGrowthChart()),
                  ],
                );
              } else {
                // Mobile/Tablet: Stacked
                return Column(
                  children: [
                    _buildRevenueChart(),
                    const SizedBox(height: 24),
                    _buildUserGrowthChart(),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),
          // Responsive data tables layout
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1000) {
                // Desktop: Side by side
                return Row(
                  children: [
                    Expanded(child: _buildRecentOrders()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildTopProducts()),
                  ],
                );
              } else {
                // Mobile/Tablet: Stacked
                return Column(
                  children: [
                    _buildRecentOrders(),
                    const SizedBox(height: 24),
                    _buildTopProducts(),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoading(
            isLoading: true,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount;
              double childAspectRatio;
              
              if (constraints.maxWidth > 1400) {
                crossAxisCount = 4;
                childAspectRatio = 2.5;
              } else if (constraints.maxWidth > 1000) {
                crossAxisCount = 3;
                childAspectRatio = 2.2;
              } else if (constraints.maxWidth > 600) {
                crossAxisCount = 2;
                childAspectRatio = 2.0;
              } else {
                crossAxisCount = 1;
                childAspectRatio = 1.8;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: 8,
                itemBuilder: (context, index) => SkeletonCard(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          // Desktop: Side by side
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Platform Statistics',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Comprehensive overview of marketplace performance',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _loadStatistics,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        } else {
          // Mobile: Stacked
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Platform Statistics',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Comprehensive overview of marketplace performance',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loadStatistics,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      {
        'title': 'Total Users',
        'value': _stats['totalUsers']?.toString() ?? '0',
        'icon': Icons.people,
        'color': Colors.blue,
        'change': '+12%',
      },
      {
        'title': 'Total Sellers',
        'value': _stats['totalSellers']?.toString() ?? '0',
        'icon': Icons.store,
        'color': Colors.green,
        'change': '+8%',
      },
      {
        'title': 'Total Products',
        'value': _stats['totalProducts']?.toString() ?? '0',
        'icon': Icons.inventory,
        'color': Colors.orange,
        'change': '+15%',
      },
      {
        'title': 'Total Orders',
        'value': _stats['totalOrders']?.toString() ?? '0',
        'icon': Icons.shopping_cart,
        'color': Colors.purple,
        'change': '+23%',
      },
      {
        'title': 'Total Revenue',
        'value': 'R${NumberFormat('#,##0').format(_stats['totalRevenue'] ?? 0)}',
                    'icon': Icons.receipt,
        'color': Colors.teal,
        'change': '+18%',
      },
      {
        'title': 'Platform Fees',
        'value': 'R${NumberFormat('#,##0').format(_stats['totalPlatformFees'] ?? 0)}',
        'icon': Icons.account_balance,
        'color': Colors.indigo,
        'change': '+20%',
      },
      {
        'title': 'Total Reviews',
        'value': _stats['totalReviews']?.toString() ?? '0',
        'icon': Icons.star,
        'color': Colors.amber,
        'change': '+14%',
      },
      {
        'title': 'Avg Order Value',
        'value': '\$${NumberFormat('#,##0').format(_stats['avgOrderValue'] ?? 0)}',
        'icon': Icons.trending_up,
        'color': Colors.red,
        'change': '+5%',
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        double childAspectRatio;
        
        if (constraints.maxWidth > 1400) {
          // Large desktop: 4 columns
          crossAxisCount = 4;
          childAspectRatio = 2.5;
        } else if (constraints.maxWidth > 1000) {
          // Medium desktop: 3 columns
          crossAxisCount = 3;
          childAspectRatio = 2.2;
        } else if (constraints.maxWidth > 600) {
          // Tablet: 2 columns
          crossAxisCount = 2;
          childAspectRatio = 2.0;
        } else {
          // Mobile: 1 column
          crossAxisCount = 1;
          childAspectRatio = 1.8;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final stat = stats[index];
            final color = stat['color'] as Color;
            final icon = stat['icon'] as IconData;
            final title = stat['title'] as String;
            final value = stat['value'] as String;
            final change = stat['change'] as String;

            return Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            change,
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRevenueChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Revenue Trend (Last 7 Days)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _revenueData.isNotEmpty
                  ? LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text('\$${value.toInt()}'),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= 0 && value.toInt() < _revenueData.length) {
                                  final date = _revenueData[value.toInt()]['date'] as DateTime;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      DateFormat('MMM dd').format(date),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _revenueData.asMap().entries.map((entry) {
                              return FlSpot(entry.key.toDouble(), entry.value['revenue'] as double);
                            }).toList(),
                            isCurved: true,
                            color: Theme.of(context).colorScheme.primary,
                            barWidth: 3,
                            dotData: FlDotData(show: true),
                          ),
                        ],
                      ),
                    )
                  : const Center(child: Text('No revenue data available')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserGrowthChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'User Growth (Last 30 Days)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _userGrowth.isNotEmpty
                  ? BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _userGrowth.isNotEmpty 
                            ? _userGrowth.map((e) => e['count'] as double).reduce((a, b) => a > b ? a : b) + 5
                            : 10,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(value.toInt().toString()),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= 0 && value.toInt() < _userGrowth.length) {
                                  final date = _userGrowth[value.toInt()]['date'] as DateTime;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      DateFormat('MMM dd').format(date),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: true),
                        barGroups: _userGrowth.asMap().entries.map((entry) {
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value['count'] as double,
                                color: Theme.of(context).colorScheme.primary,
                                width: 8,
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    )
                  : const Center(child: Text('No user growth data available')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Recent Orders',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _recentOrders.isNotEmpty
                ? ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentOrders.length,
                    itemBuilder: (context, index) {
                      final order = _recentOrders[index];
                      return ListTile(
                        title: Text(order['buyerName']),
                        subtitle: Text('R${order['totalAmount'].toStringAsFixed(2)}'),
                        trailing: Chip(
                          label: Text(order['status']),
                          backgroundColor: order['status'] == 'completed' 
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                        ),
                      );
                    },
                  )
                : const Center(child: Text('No recent orders')),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProducts() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Top Products',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _topProducts.isNotEmpty
                ? ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _topProducts.length,
                    itemBuilder: (context, index) {
                      final product = _topProducts[index];
                      return ListTile(
                        title: Text(product['name']),
                        subtitle: Text('R${product['price'].toStringAsFixed(2)}'),
                        trailing: Text('${product['salesCount']} sales'),
                      );
                    },
                  )
                : const Center(child: Text('No top products data')),
          ],
        ),
      ),
    );
  }
} 