import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class AdvancedAnalyticsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Advanced Analytics'),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Platform KPIs', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  _KpiCard(label: 'Users', collection: 'users'),
                  const SizedBox(width: 16),
                  _KpiCard(label: 'Sellers', collection: 'users', role: 'seller'),
                  const SizedBox(width: 16),
                  _KpiCard(label: 'Orders', collection: 'orders'),
                  const SizedBox(width: 16),
                  _KpiCard(label: 'Revenue', collection: 'orders', sumField: 'totalPrice'),
                ],
              ),
              const SizedBox(height: 32),
              Text('Trends (Orders Over Time)', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                ),
                padding: const EdgeInsets.all(16),
                child: _OrdersLineChart(),
              ),
              const SizedBox(height: 32),
              Text('Product Category Breakdown', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                ),
                padding: const EdgeInsets.all(16),
                child: _CategoryBarChart(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String collection;
  final String? role;
  final String? sumField;
  const _KpiCard({required this.label, required this.collection, this.role, this.sumField});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 140,
        height: 90,
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<QuerySnapshot>(
          future: role == null
              ? FirebaseFirestore.instance.collection(collection).get()
              : FirebaseFirestore.instance.collection(collection).where('role', isEqualTo: role).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
            if (sumField != null) {
              final String field = sumField!;
              double sum = 0;
              for (final doc in snapshot.data!.docs) {
                final val = doc[field] is num ? (doc[field] as num).toDouble() : double.tryParse(doc[field]?.toString() ?? '') ?? 0.0;
                sum += val;
              }
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('R 2${sum.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineSmall),
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                ],
              );
            }
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${snapshot.data!.docs.length}', style: Theme.of(context).textTheme.headlineSmall),
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrdersLineChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Example static data. Replace with Firestore data for real analytics.
    final spots = [
      FlSpot(1, 10),
      FlSpot(2, 12),
      FlSpot(3, 8),
      FlSpot(4, 14),
      FlSpot(5, 16),
      FlSpot(6, 13),
      FlSpot(7, 18),
    ];
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 1,
        maxX: 7,
        minY: 0,
        maxY: 20,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Color(0xFF388E3C),
            barWidth: 4,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: Color(0xFF388E3C).withOpacity(0.12)),
          ),
        ],
      ),
    );
  }
}

class _CategoryBarChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Example static data. Replace with Firestore data for real analytics.
    final categories = ['Food', 'Drinks', 'Bakery', 'Snacks'];
    final values = [12.0, 8.0, 15.0, 6.0];
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 20,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                return idx >= 0 && idx < categories.length
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(categories[idx], style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                      )
                    : SizedBox.shrink();
              },
              reservedSize: 40,
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(categories.length, (i) =>
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: values[i],
                color: Color(0xFF388E3C),
                width: 22,
                borderRadius: BorderRadius.circular(8),
                backDrawRodData: BackgroundBarChartRodData(show: true, toY: 20, color: Color(0xFF388E3C).withOpacity(0.08)),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 