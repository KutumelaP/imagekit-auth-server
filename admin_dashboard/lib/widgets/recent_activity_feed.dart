import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/order_utils.dart';

class RecentActivityFeed extends StatelessWidget {
  final FirebaseFirestore firestore;
  const RecentActivityFeed({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<List<ActivityEvent>>(
          future: _fetchRecentEvents(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final events = snapshot.data!;
            if (events.isEmpty) return const Text('No recent activity.');
            return Column(
              children: events.map((e) => _activityTile(e)).toList(),
            );
          },
        ),
      ),
    );
  }

  Future<List<ActivityEvent>> _fetchRecentEvents() async {
    final now = DateTime.now();
    final List<ActivityEvent> events = [];
    // Fetch recent orders
    final orderSnaps = await firestore.collection('orders').orderBy('timestamp', descending: true).limit(5).get();
    for (var doc in orderSnaps.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = (data['timestamp'] as Timestamp?)?.toDate();
      events.add(ActivityEvent(
        icon: Icons.shopping_cart,
        color: Colors.blue,
        title: 'Order ${OrderUtils.formatShortOrderNumber(doc.id)} (${data['status'] ?? 'placed'})',
        subtitle: 'Total: R${data['totalPrice'] ?? 0.0}',
        time: ts ?? now,
      ));
    }
    // Fetch recent users
    final userSnaps = await firestore.collection('users').orderBy('createdAt', descending: true).limit(3).get();
    for (var doc in userSnaps.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = (data['createdAt'] as Timestamp?)?.toDate();
      events.add(ActivityEvent(
        icon: Icons.person,
        color: Colors.green,
        title: 'User ${data['email'] ?? doc.id} registered',
        subtitle: data['role'] == 'seller' ? 'Seller' : 'Buyer',
        time: ts ?? now,
      ));
    }
    // Fetch recent products
    final prodSnaps = await firestore.collection('products').orderBy('createdAt', descending: true).limit(2).get();
    for (var doc in prodSnaps.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = (data['createdAt'] as Timestamp?)?.toDate();
      events.add(ActivityEvent(
        icon: Icons.inventory,
        color: Colors.purple,
        title: 'Product ${data['name'] ?? doc.id} added',
        subtitle: 'By: ${data['ownerId'] ?? ''}',
        time: ts ?? now,
      ));
    }
    // Sort all events by time descending
    events.sort((a, b) => b.time.compareTo(a.time));
    return events.take(10).toList();
  }

  Widget _activityTile(ActivityEvent e) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: e.color.withOpacity(0.15),
            child: Icon(e.icon, color: e.color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(e.subtitle, style: const TextStyle(color: Colors.black54, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(_timeAgo(e.time), style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return ' ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return ' ${diff.inHours} hr ago';
    return DateFormat('MMMd').format(dt);
  }
}

class ActivityEvent {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final DateTime time;
  ActivityEvent({required this.icon, required this.color, required this.title, required this.subtitle, required this.time});
} 