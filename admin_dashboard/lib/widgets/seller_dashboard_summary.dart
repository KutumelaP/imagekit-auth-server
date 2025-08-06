import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Added for StreamSubscription
import '../theme/admin_theme.dart';

class SellerDashboardSummary extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  const SellerDashboardSummary({Key? key, required this.auth, required this.firestore}) : super(key: key);

  @override
  State<SellerDashboardSummary> createState() => _SellerDashboardSummaryState();
}

class _SellerDashboardSummaryState extends State<SellerDashboardSummary> {
  int _customerCount = 0;
  double _income = 0.0;
  int _productsSold = 0;
  String? sellerId;

  @override
  void initState() {
    super.initState();
    _loadSellerData();
  }

  Future<void> _loadSellerData() async {
    final user = widget.auth.currentUser;
    if (user != null) {
      setState(() {
        sellerId = user.uid;
      });
      // Check if there are any orders in the database
      await _checkForSampleData();
    }
  }

  Future<void> _checkForSampleData() async {
    try {
      final ordersSnapshot = await widget.firestore.collection('orders').limit(1).get();
      if (ordersSnapshot.docs.isEmpty) {
        print('Debug: No orders found in database. Consider adding sample data for demonstration.');
      } else {
        print('Debug: Found ${ordersSnapshot.docs.length} orders in database');
      }
    } catch (e) {
      print('Error checking for sample data: $e');
    }
  }

  Future<int> _fetchCustomerCount(String sellerId) async {
    try {
      final orders = await widget.firestore.collection('orders').where('sellerId', isEqualTo: sellerId).get();
      final buyers = orders.docs.map((doc) => doc['buyerId']).toSet();
      print('Debug: Found ${buyers.length} customers for seller $sellerId');
      return buyers.length;
    } catch (e) {
      print('Error fetching customer count: $e');
      return 0;
    }
  }

  Future<double> _fetchIncome(String sellerId) async {
    try {
      final orders = await widget.firestore.collection('orders').where('sellerId', isEqualTo: sellerId).get();
      double total = 0;
      for (var doc in orders.docs) {
        total += (doc['totalPrice'] ?? 0.0) as double;
      }
      print('Debug: Found total income R$total for seller $sellerId');
      return total;
    } catch (e) {
      print('Error fetching income: $e');
      return 0.0;
    }
  }

  Future<int> _fetchProductsSold(String sellerId) async {
    try {
      final orders = await widget.firestore.collection('orders').where('sellerId', isEqualTo: sellerId).get();
      int count = 0;
      for (var doc in orders.docs) {
        final items = doc['items'] as List?;
        if (items != null) count += items.length;
      }
      print('Debug: Found $count products sold for seller $sellerId');
      return count;
    } catch (e) {
      print('Error fetching products sold: $e');
      return 0;
    }
  }

  Future<Map<String, double>> _fetchRevenueTrends(String sellerId) async {
    final orders = await widget.firestore.collection('orders').where('sellerId', isEqualTo: sellerId).get();
    final Map<String, double> revenueByDay = {};
    for (var doc in orders.docs) {
      final data = doc.data();
      final ts = (data['timestamp'] as Timestamp?)?.toDate();
      final total = (data['totalPrice'] ?? 0.0) as num;
      if (ts != null) {
        final dayKey = '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
        revenueByDay[dayKey] = (revenueByDay[dayKey] ?? 0) + total.toDouble();
      }
    }
    return revenueByDay;
  }

  Future<Map<String, dynamic>> _fetchFinancialFlow(String sellerId) async {
    final orders = await widget.firestore.collection('orders').where('sellerId', isEqualTo: sellerId).get();
    double totalRevenue = 0;
    double pendingRevenue = 0;
    double monthlyRevenue = 0;
    
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    
    for (var doc in orders.docs) {
      final data = doc.data();
      final total = (data['totalPrice'] ?? 0.0) as num;
      final status = (data['status'] ?? 'pending').toString();
      final ts = (data['timestamp'] as Timestamp?)?.toDate();
      
      totalRevenue += total.toDouble();
      
      if (status == 'pending' || status == 'confirmed') {
        pendingRevenue += total.toDouble();
      }
      
      if (ts != null && ts.isAfter(thisMonth)) {
        monthlyRevenue += total.toDouble();
      }
    }
    
    return {
      'totalRevenue': totalRevenue,
      'pendingRevenue': pendingRevenue,
      'monthlyRevenue': monthlyRevenue,
    };
  }

  Future<Map<String, int>> _fetchTopProducts(String sellerId) async {
    final orders = await widget.firestore.collection('orders').where('sellerId', isEqualTo: sellerId).get();
    final Map<String, int> productCounts = {};
    for (var doc in orders.docs) {
      final items = doc['items'] as List?;
      if (items != null) {
        for (var item in items) {
          final prod = item['name'] ?? 'Unknown Product';
          productCounts[prod] = (productCounts[prod] ?? 0) + 1;
        }
      }
    }
    return productCounts;
  }

  Future<List<Map<String, dynamic>>> _fetchRecentChats(String sellerId) async {
    try {
      final chatsSnapshot = await widget.firestore
          .collection('chats')
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('timestamp', descending: true)
          .limit(10) // Increased limit for better management
          .get();
      
      final List<Map<String, dynamic>> chats = [];
      for (var doc in chatsSnapshot.docs) {
        final data = doc.data();
        final buyerId = data['buyerId'];
        
        // Get buyer's name and avatar
        String customerName = 'Customer';
        String? customerAvatar;
        if (buyerId != null) {
          try {
            final buyerDoc = await widget.firestore.collection('users').doc(buyerId).get();
            final buyerData = buyerDoc.data();
            customerName = buyerData?['displayName'] ?? 
                          buyerData?['email']?.split('@')[0] ?? 
                          'Customer';
            customerAvatar = buyerData?['photoURL'];
          } catch (e) {
            // If buyer data not found, use default name
          }
        }
        
        // Get unread count for this chat
        int unreadCount = 0;
        try {
          final messagesSnapshot = await widget.firestore
              .collection('chats')
              .doc(doc.id)
              .collection('messages')
              .where('senderId', isNotEqualTo: sellerId)
              .where('read', isEqualTo: false)
              .get();
          unreadCount = messagesSnapshot.docs.length;
        } catch (e) {
          // If read field doesn't exist, assume all are read
        }
        
        chats.add({
          'id': doc.id,
          'customerName': customerName,
          'customerAvatar': customerAvatar,
          'lastMessage': data['lastMessage'] ?? 'No messages yet',
          'lastMessageTime': data['timestamp'],
          'unreadCount': unreadCount,
          'customerId': buyerId,
          'sellerId': sellerId,
          'productName': data['productName'] ?? 'Product',
        });
      }
      return chats;
    } catch (e) {
      return [];
    }
  }

  void _openChat(BuildContext context, Map<String, dynamic> chat) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(32),
        child: SizedBox(
          width: 600,
          height: 500,
          child: _ChatDialog(
            chat: chat, 
            firestore: widget.firestore,
            auth: widget.auth,
          ),
        ),
      ),
    );
  }

  // Enhanced chat item with better UI
  Widget _buildChatItem(Map<String, dynamic> chat) {
    final timestamp = chat['lastMessageTime'] as Timestamp?;
    final timeAgo = timestamp != null 
        ? _getTimeAgo(timestamp.toDate())
        : 'Just now';
    
    return Card(
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: chat['customerAvatar'] != null 
              ? NetworkImage(chat['customerAvatar'])
              : null,
          child: chat['customerAvatar'] == null 
              ? Text(chat['customerName'][0].toUpperCase())
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                chat['customerName'],
                style: TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (chat['unreadCount'] > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${chat['unreadCount']}',
                  style: TextStyle(color: AdminTheme.angel, fontSize: 12),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chat['productName'],
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 12),
            ),
            Text(
              chat['lastMessage'],
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Text(
          timeAgo,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
        ),
        onTap: () => _openChat(context, chat),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with notification bell
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dashboard Overview',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                _NotificationBell(auth: widget.auth, firestore: widget.firestore),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: FutureBuilder<int>(
                  future: sellerId != null ? _fetchCustomerCount(sellerId!) : Future.value(0),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                    final value = snapshot.hasData ? snapshot.data.toString() : '0';
                    final isLoading = snapshot.connectionState == ConnectionState.waiting;
                    return _SummaryCard(
                      label: 'Customers', 
                      value: value, 
                      icon: Icons.people,
                      isLoading: isLoading,
                    );
                  },
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: FutureBuilder<double>(
                  future: sellerId != null ? _fetchIncome(sellerId!) : Future.value(0.0),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                    final value = snapshot.hasData ? 'R${snapshot.data!.toStringAsFixed(2)}' : 'R0.00';
                    final isLoading = snapshot.connectionState == ConnectionState.waiting;
                    return _SummaryCard(
                      label: 'Income', 
                      value: value, 
                      icon: Icons.receipt,
                      isLoading: isLoading,
                    );
                  },
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: FutureBuilder<int>(
                  future: sellerId != null ? _fetchProductsSold(sellerId!) : Future.value(0),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                    final value = snapshot.hasData ? snapshot.data.toString() : '0';
                    final isLoading = snapshot.connectionState == ConnectionState.waiting;
                    return _SummaryCard(
                      label: 'Products Sold', 
                      value: value, 
                      icon: Icons.shopping_bag,
                      isLoading: isLoading,
                    );
                  },
                ),
              ),
            ],
          ),
          // Add a note about sample data if no real data exists
          FutureBuilder<int>(
            future: sellerId != null ? _fetchCustomerCount(sellerId!) : Future.value(0),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data == 0) {
                return Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No data available. Add orders to see dashboard metrics.',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  // Refresh the dashboard data
                  setState(() {});
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Revenue Trends Section
          Card(
            color: Theme.of(context).cardColor,
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Revenue Trends', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  const SizedBox(height: 16),
                  FutureBuilder<Map<String, double>>(
                    future: sellerId != null ? _fetchRevenueTrends(sellerId!) : Future.value({}),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                      if (!snapshot.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                      final trends = snapshot.data!;
                      if (trends.isEmpty) return const SizedBox(height: 200, child: Center(child: Text('No revenue data available')));
                      
                      final days = trends.keys.toList()..sort();
                      final spots = <FlSpot>[];
                      for (int i = 0; i < days.length; i++) {
                        spots.add(FlSpot(i.toDouble(), trends[days[i]]!));
                      }
                      
                      return SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1, getDrawingHorizontalLine: (v) => FlLine(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2), strokeWidth: 1)),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, meta) => Text('R${v.toInt()}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 11))),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, meta) {
                                    final idx = v.toInt();
                                    if (idx < 0 || idx >= days.length) return const SizedBox();
                                    final d = days[idx];
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(d.substring(5), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 11)),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            minX: 0,
                            maxX: days.length > 0 ? (days.length - 1).toDouble() : 0,
                            minY: 0,
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                color: Theme.of(context).colorScheme.primary,
                                barWidth: 3,
                                dotData: FlDotData(show: false),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Financial Flow and Chats Section
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 900) {
                // Small screen: stack vertically
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Financial Flow Section
                    Card(
                      color: Theme.of(context).cardColor,
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Financial Flow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Flexible(
                                  child: FutureBuilder<Map<String, dynamic>>(
                                    future: sellerId != null ? _fetchFinancialFlow(sellerId!) : Future.value({}),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                                      final data = snapshot.data!;
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _FinancialItem(
                                            label: 'Total Revenue',
                                            value: 'R${data['totalRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                                            color: Theme.of(context).colorScheme.primary,
                                            icon: Icons.trending_up,
                                          ),
                                          const SizedBox(height: 12),
                                          _FinancialItem(
                                            label: 'Pending Orders',
                                            value: 'R${data['pendingRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                                            color: Theme.of(context).colorScheme.secondary,
                                            icon: Icons.schedule,
                                          ),
                                          const SizedBox(height: 12),
                                          _FinancialItem(
                                            label: 'This Month',
                                            value: 'R${data['monthlyRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                                            color: Theme.of(context).colorScheme.primary,
                                            icon: Icons.calendar_today,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Flexible(
                                  child: FutureBuilder<Map<String, int>>(
                                    future: sellerId != null ? _fetchTopProducts(sellerId!) : Future.value({}),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                                      final products = snapshot.data!;
                                      if (products.isEmpty) return const Center(child: Text('No product data'));
                                      final sorted = products.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Top Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          const SizedBox(height: 12),
                                          ...sorted.take(5).map((entry) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(entry.key),
                                                Text('${entry.value} orders', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                                              ],
                                            ),
                                          )),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Chats Section
                    Card(
                      color: Theme.of(context).cardColor,
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Customer Chats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                IconButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Opening full chat interface...')),
                                    );
                                  },
                                  icon: const Icon(Icons.open_in_new),
                                  tooltip: 'Open Full Chat',
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: sellerId != null ? _fetchRecentChats(sellerId!) : Future.value([]),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                                final chats = snapshot.data!;
                                if (chats.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.chat_bubble_outline, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                                        SizedBox(height: 8),
                                        Text('No recent chats', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                                      ],
                                    ),
                                  );
                                }
                                return Column(
                                  children: chats.map((chat) => _buildChatItem(chat)).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                // Large screen: side by side
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      flex: 2,
                      child: Card(
                        color: Theme.of(context).cardColor,
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Financial Flow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Flexible(
                                    child: FutureBuilder<Map<String, dynamic>>(
                                      future: sellerId != null ? _fetchFinancialFlow(sellerId!) : Future.value({}),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                                        final data = snapshot.data!;
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _FinancialItem(
                                              label: 'Total Revenue',
                                              value: 'R${data['totalRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                                              color: Theme.of(context).colorScheme.primary,
                                              icon: Icons.trending_up,
                                            ),
                                            const SizedBox(height: 12),
                                            _FinancialItem(
                                              label: 'Pending Orders',
                                              value: 'R${data['pendingRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                                              color: Theme.of(context).colorScheme.secondary,
                                              icon: Icons.schedule,
                                            ),
                                            const SizedBox(height: 12),
                                            _FinancialItem(
                                              label: 'This Month',
                                              value: 'R${data['monthlyRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                                              color: Theme.of(context).colorScheme.primary,
                                              icon: Icons.calendar_today,
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Flexible(
                                    child: FutureBuilder<Map<String, int>>(
                                      future: sellerId != null ? _fetchTopProducts(sellerId!) : Future.value({}),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                                        final products = snapshot.data!;
                                        if (products.isEmpty) return const Center(child: Text('No product data'));
                                        final sorted = products.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Top Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            const SizedBox(height: 12),
                                            ...sorted.take(5).map((entry) => Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(entry.key),
                                                  Text('${entry.value} orders', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                                                ],
                                              ),
                                            )),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Flexible(
                      flex: 1,
                      child: Card(
                        color: Theme.of(context).cardColor,
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Customer Chats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                  IconButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Opening full chat interface...')),
                                      );
                                    },
                                    icon: const Icon(Icons.open_in_new),
                                    tooltip: 'Open Full Chat',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              FutureBuilder<List<Map<String, dynamic>>>(
                                future: sellerId != null ? _fetchRecentChats(sellerId!) : Future.value([]),
                                builder: (context, snapshot) {
                                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                                  final chats = snapshot.data!;
                                  if (chats.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.chat_bubble_outline, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                                          SizedBox(height: 8),
                                          Text('No recent chats', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                                        ],
                                      ),
                                    );
                                  }
                                  return Column(
                                    children: chats.map((chat) => _buildChatItem(chat)).toList(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
} 

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isLoading;
  const _SummaryCard({required this.label, required this.value, required this.icon, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            isLoading 
              ? SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}

class _FinancialItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _FinancialItem({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: AdminTheme.mediumGrey)),
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Full _NotificationBell implementation
class _NotificationBell extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  const _NotificationBell({required this.auth, required this.firestore});

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  int _notificationCount = 0;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _setupNotificationListener() {
    final user = widget.auth.currentUser;
    if (user != null) {
      _notificationSubscription = widget.firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        setState(() {
          _notificationCount = snapshot.docs.length;
        });
      });
    }
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => _NotificationsDialog(
        auth: widget.auth,
        firestore: widget.firestore,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          onPressed: _showNotifications,
          icon: const Icon(Icons.notifications, size: 28),
          tooltip: 'Notifications',
        ),
        if (_notificationCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                '$_notificationCount',
                style: TextStyle(
                  color: AdminTheme.angel,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// Full _ChatDialog implementation
class _ChatDialog extends StatefulWidget {
  final Map<String, dynamic> chat;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  const _ChatDialog({required this.chat, required this.firestore, required this.auth});

  @override
  State<_ChatDialog> createState() => _ChatDialogState();
}

class _ChatDialogState extends State<_ChatDialog> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    final currentUser = widget.auth.currentUser;
    if (currentUser == null) return;
    widget.firestore
        .collection('chats')
        .doc(widget.chat['id'])
        .collection('messages')
        .add({
          'text': message,
          'senderId': currentUser.uid,
          'timestamp': Timestamp.now(),
        });
    widget.firestore.collection('chats').doc(widget.chat['id']).update({
      'lastMessage': message,
      'timestamp': Timestamp.now(),
    });
    _messageController.clear();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Buyer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.firestore
                  .collection('chats')
                  .doc(widget.chat['id'])
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!.docs;
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                        SizedBox(height: 8),
                        Text('No messages yet', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final currentUserId = widget.auth.currentUser?.uid;
                    final isFromCustomer = message['senderId'] != currentUserId;
                    return _MessageBubble(
                      message: message['text'] as String,
                      isFromCustomer: isFromCustomer,
                      timestamp: (message['timestamp'] as Timestamp).toDate(),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// _MessageBubble for chat dialog
class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isFromCustomer;
  final DateTime timestamp;
  const _MessageBubble({required this.message, required this.isFromCustomer, required this.timestamp});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isFromCustomer ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isFromCustomer ? Theme.of(context).colorScheme.onSurface.withOpacity(0.1) : Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isFromCustomer ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(timestamp),
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// _NotificationsDialog for notification bell
class _NotificationsDialog extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  const _NotificationsDialog({required this.auth, required this.firestore});

  @override
  State<_NotificationsDialog> createState() => _NotificationsDialogState();
}

class _NotificationsDialogState extends State<_NotificationsDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: widget.firestore
                    .collection('notifications')
                    .where('userId', isEqualTo: widget.auth.currentUser?.uid)
                    .orderBy('timestamp', descending: true)
                    .limit(20)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final notifications = snapshot.data!.docs;
                  if (notifications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                          SizedBox(height: 8),
                          Text('No notifications', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index].data() as Map<String, dynamic>;
                      final isRead = notification['read'] ?? false;
                      return ListTile(
                        leading: Icon(
                          _getNotificationIcon(notification['type']),
                          color: isRead ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6) : Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          notification['title'] ?? 'Notification',
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          notification['body'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          _getTimeAgo((notification['timestamp'] as Timestamp).toDate()),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                        ),
                        onTap: () => _handleNotificationTap(notification),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'chat_message':
        return Icons.chat;
      case 'order_status':
        return Icons.shopping_cart;
      case 'order':
        return Icons.shopping_cart;
      case 'review':
        return Icons.star;
      case 'product_upload':
        return Icons.upload;
      case 'product_edit':
        return Icons.edit;
      default:
        return Icons.notifications;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) async {
    // Mark as read
    final docRef = widget.firestore.collection('notifications').doc(notification['id']);
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.update({'read': true});
    }
    // Handle navigation based on type
    final type = notification['type'];
    final data = notification['data'] ?? {};
    if (type == 'chat_message' && data['chatId'] != null) {
      Navigator.pop(context); // Close notification dialog
      // TODO: Navigate to specific chat
    } else if (type == 'order_status' && data['orderId'] != null) {
      Navigator.pop(context);
      // TODO: Navigate to order details
    } else if (type == 'order' && data['orderId'] != null) {
      Navigator.pop(context);
      // TODO: Navigate to order details
    } else if (type == 'review') {
      Navigator.pop(context);
      // TODO: Navigate to reviews
    }
  }
} 