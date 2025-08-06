import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class SellerAnalyticsSection extends StatelessWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  const SellerAnalyticsSection({Key? key, required this.auth, required this.firestore}) : super(key: key);

  Future<Map<String, dynamic>> _fetchAnalytics(String sellerId) async {
    final orders = await firestore.collection('orders').where('sellerId', isEqualTo: sellerId).get();
    double totalRevenue = 0;
    int totalOrders = 0;
    final Map<String, double> revenueByDay = {};
    final Map<String, int> productCounts = {};
    final now = DateTime.now();
    for (var doc in orders.docs) {
      final data = doc.data();
      final ts = (data['timestamp'] as Timestamp?)?.toDate();
      final total = (data['totalPrice'] ?? 0.0) as num;
      totalRevenue += total.toDouble();
      totalOrders++;
      if (ts != null) {
        final dayKey = DateFormat('yyyy-MM-dd').format(ts);
        revenueByDay[dayKey] = (revenueByDay[dayKey] ?? 0) + total.toDouble();
      }
      final items = data['items'] as List?;
      if (items != null) {
        for (var item in items) {
          final prod = item['name'] ?? 'Unknown Product';
          productCounts[prod] = (productCounts[prod] ?? 0) + 1;
        }
      }
    }
    // Fill missing days for the last 30 days
    for (int i = 29; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayKey = DateFormat('yyyy-MM-dd').format(day);
      revenueByDay[dayKey] = revenueByDay[dayKey] ?? 0;
    }
    return {
      'totalRevenue': totalRevenue,
      'totalOrders': totalOrders,
      'revenueByDay': revenueByDay,
      'productCounts': productCounts,
    };
  }

  @override
  Widget build(BuildContext context) {
    final sellerId = auth.currentUser?.uid;
    return sellerId == null
        ? Center(child: Text('No seller ID found.'))
        : FutureBuilder<Map<String, dynamic>>(
            future: _fetchAnalytics(sellerId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load analytics.'));
              }
              final data = snapshot.data!;
              final totalRevenue = data['totalRevenue'] as double;
              final totalOrders = data['totalOrders'] as int;
              final revenueByDay = data['revenueByDay'] as Map<String, double>;
              final productCounts = data['productCounts'] as Map<String, int>;
              final hasData = totalOrders > 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analytics', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _SummaryCard(label: 'Total Revenue', value: 'R${totalRevenue.toStringAsFixed(2)}', icon: Icons.receipt),
                      const SizedBox(width: 18),
                      _SummaryCard(label: 'Total Orders', value: '$totalOrders', icon: Icons.shopping_bag),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text('Revenue Trend (Last 30 Days)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (!hasData)
                    Center(child: Text('No revenue data available.'))
                  else
                    SizedBox(
                      height: 220,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1, getDrawingHorizontalLine: (v) => FlLine(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), strokeWidth: 1)),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, meta) => Text('R${v.toInt()}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 11))),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 7,
                                getTitlesWidget: (v, meta) {
                                  final idx = v.toInt();
                                  final days = revenueByDay.keys.toList();
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
                          maxX: revenueByDay.length > 0 ? (revenueByDay.length - 1).toDouble() : 0,
                          minY: 0,
                          lineBarsData: [
                            LineChartBarData(
                              spots: [
                                for (int i = 0; i < revenueByDay.length; i++)
                                  FlSpot(i.toDouble(), revenueByDay.values.elementAt(i)),
                              ],
                              isCurved: true,
                              color: Theme.of(context).colorScheme.primary,
                              barWidth: 3,
                              dotData: FlDotData(show: false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  Text('Top Products', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (productCounts.isEmpty)
                    Center(child: Text('No product data available.'))
                  else
                    SizedBox(
                      height: 220,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          barGroups: [
                            for (int i = 0; i < productCounts.length; i++)
                              BarChartGroupData(x: i, barRods: [BarChartRodData(toY: productCounts.values.elementAt(i).toDouble(), color: Theme.of(context).colorScheme.primary)]),
                          ],
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  final prods = productCounts.keys.toList();
                                  if (idx >= 0 && idx < prods.length) {
                                    return Text(prods[idx], style: const TextStyle(fontSize: 12));
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: false),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _SummaryCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 6),
                Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 