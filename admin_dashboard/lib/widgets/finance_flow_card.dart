import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class FinanceFlowCard extends StatefulWidget {
  final FirebaseFirestore firestore;
  final String sellerId;
  const FinanceFlowCard({Key? key, required this.firestore, required this.sellerId}) : super(key: key);

  @override
  State<FinanceFlowCard> createState() => _FinanceFlowCardState();
}

class _FinanceFlowCardState extends State<FinanceFlowCard> {
  int _selectedRange = 1; // 0: Today, 1: Week, 2: Month
  final List<String> _ranges = ['Today', 'Week', 'Month'];

  Future<Map<String, dynamic>> _fetchFinanceData() async {
    final now = DateTime.now();
    DateTime start;
    if (_selectedRange == 0) {
      start = DateTime(now.year, now.month, now.day);
    } else if (_selectedRange == 1) {
      start = now.subtract(Duration(days: 6));
      start = DateTime(start.year, start.month, start.day);
    } else {
      start = now.subtract(Duration(days: 29));
      start = DateTime(start.year, start.month, start.day);
    }
    final ordersSnap = await widget.firestore
        .collection('orders')
        .where('sellerId', isEqualTo: widget.sellerId)
        .where('timestamp', isGreaterThanOrEqualTo: start)
        .get();
    double revenue = 0;
    double platformFees = 0;
    double payouts = 0;
    final Map<String, double> revenueByDay = {};
    final Map<String, int> productCounts = {};
    for (var doc in ordersSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = (data['timestamp'] as Timestamp?)?.toDate();
      final total = (data['totalPrice'] ?? 0.0) as num;
      final fee = (data['platformFee'] ?? 0.0) as num;
      revenue += total.toDouble();
      platformFees += fee.toDouble();
      payouts += (total - fee).toDouble();
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
    return {
      'revenue': revenue,
      'platformFees': platformFees,
      'payouts': payouts,
      'net': payouts,
      'revenueByDay': revenueByDay,
      'productCounts': productCounts,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlight = theme.colorScheme.primary;
    final onHighlight = theme.colorScheme.onPrimary;
    final cardColor = theme.cardColor;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ToggleButtons(
                  isSelected: List.generate(_ranges.length, (i) => i == _selectedRange),
                  onPressed: (i) => setState(() => _selectedRange = i),
                  borderRadius: BorderRadius.circular(12),
                  selectedColor: onHighlight,
                  fillColor: highlight,
                  color: highlight,
                  children: _ranges.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(r, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  )).toList(),
                ),
                const SizedBox(width: 16),
                Text('Finance Flow', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 18),
            FutureBuilder<Map<String, dynamic>>(
              future: _fetchFinanceData(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final data = snapshot.data!;
                final revenue = data['revenue'] as double;
                final platformFees = data['platformFees'] as double;
                final payouts = data['payouts'] as double;
                final net = data['net'] as double;
                final revenueByDay = data['revenueByDay'] as Map<String, double>;
                final productCounts = data['productCounts'] as Map<String, int>;
                final days = revenueByDay.keys.toList()..sort();
                final List<FlSpot> spots = [];
                for (int i = 0; i < days.length; i++) {
                  spots.add(FlSpot(i.toDouble(), revenueByDay[days[i]]!));
                }
                // Sort and take top 3 products
                final topProducts = productCounts.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final top3 = topProducts.take(3).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _financeItem('Revenue', revenue, context),
                        const SizedBox(width: 18),
                        _financeItem('Platform Fees', platformFees, context),
                        const SizedBox(width: 18),
                        _financeItem('Payouts', payouts, context),
                        const SizedBox(width: 18),
                        _financeItem('Net', net, context),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 80,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: false),
                          titlesData: FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: Theme.of(context).colorScheme.primary,
                              barWidth: 3,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(show: true, color: Colors.green.shade100.withOpacity(0.4)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Top Products', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (top3.isEmpty)
                      Text('No product data available.', style: Theme.of(context).textTheme.bodyMedium)
                    else
                      SizedBox(
                        height: 220,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            barGroups: [
                              for (int i = 0; i < topProducts.length && i < 5; i++)
                                BarChartGroupData(x: i, barRods: [BarChartRodData(toY: topProducts[i].value.toDouble(), color: Theme.of(context).colorScheme.primary)]),
                            ],
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final idx = value.toInt();
                                    if (idx >= 0 && idx < topProducts.length && idx < 5) {
                                      return Text(topProducts[idx].key, style: const TextStyle(fontSize: 12));
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _financeItem(String label, double value, BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text('R${value.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
} 