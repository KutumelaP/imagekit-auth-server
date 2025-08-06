import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellerAnalyticsScreen extends StatefulWidget {
  const SellerAnalyticsScreen({super.key});

  @override
  State<SellerAnalyticsScreen> createState() => _SellerAnalyticsScreenState();
}

class _SellerAnalyticsScreenState extends State<SellerAnalyticsScreen> {
  int _totalOrders = 0;
  double _totalRevenue = 0.0;
  Map<String, int> _statusCounts = {};
  List<Map<String, dynamic>> _bestSellers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Fetch all orders for this seller
    final ordersSnap = await FirebaseFirestore.instance
        .collection('orders')
        .where('sellerId', isEqualTo: user.uid)
        .get();
    _totalOrders = ordersSnap.docs.length;
    _totalRevenue = 0.0;
    _statusCounts = {};
    final productSales = <String, int>{};
    final productNames = <String, String>{};
    for (final doc in ordersSnap.docs) {
      final data = doc.data();
      _totalRevenue += (data['sellerPayout'] ?? 0.0) is int
          ? (data['sellerPayout'] ?? 0.0).toDouble()
          : (data['sellerPayout'] ?? 0.0) as double;
      final status = data['status'] ?? 'unknown';
      _statusCounts[status] = (_statusCounts[status] ?? 0) + 1;
      // Count product sales
      if (data['items'] is List) {
        for (final item in data['items']) {
          final pid = item['productId'] ?? item['id'];
          final qty = item['quantity'] ?? 1;
          final name = item['name'] ?? 'Product';
          if (pid != null) {
            final intQty = qty is int ? qty : (qty is num ? qty.toInt() : 1);
            productSales[pid] = (productSales[pid] ?? 0) + intQty;
            productNames[pid] = name;
          }
        }
      }
    }
    // Get best sellers
    final sorted = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _bestSellers = sorted.take(5).map((e) => {
      'productId': e.key,
      'name': productNames[e.key] ?? 'Product',
      'sales': e.value,
    }).toList();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seller Analytics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  Row(
                    children: [
                      _buildSummaryCard('Total Orders', '$_totalOrders', Icons.shopping_bag),
                      const SizedBox(width: 16),
                      _buildSummaryCard('Revenue', 'R${_totalRevenue.toStringAsFixed(2)}', Icons.receipt),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Order Status Breakdown', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: _statusCounts.entries
                        .map((e) => Chip(label: Text('${e.key}: ${e.value}')))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  Text('Best-Selling Products', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ..._bestSellers.map((p) => ListTile(
                        leading: const Icon(Icons.star, color: Colors.amber),
                        title: Text(p['name']),
                        trailing: Text('Sold: ${p['sales']}'),
                      )),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: Colors.deepPurple),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
} 