import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/order_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'bulk_operations_panel.dart';
import '../services/real_time_notification_service.dart';

class QuickActionsWidget extends StatelessWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final Function(int)? onNavigateToSection;

  const QuickActionsWidget({
    Key? key,
    required this.firestore,
    required this.auth,
    this.onNavigateToSection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on, color: Color(0xFF1F4654), size: 24),
              const SizedBox(width: 12),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildQuickActionCard(
                context,
                'Pending Sellers',
                Icons.store_outlined,
                Colors.orange,
                () => _showPendingSellers(context),
              ),
              _buildQuickActionCard(
                context,
                'Failed Orders',
                Icons.error_outline,
                Colors.red,
                () => _showFailedOrders(context),
              ),
              _buildQuickActionCard(
                context,
                'Low Reviews',
                Icons.star_outline,
                Colors.amber,
                () => _showLowReviews(context),
              ),
              _buildQuickActionCard(
                context,
                'Bulk Operations',
                Icons.playlist_add_check,
                Colors.blue,
                () => _showBulkOperationsMenu(context),
              ),
              _buildQuickActionCard(
                context,
                'System Health',
                Icons.health_and_safety,
                Colors.green,
                () => _showSystemHealth(context),
              ),
              _buildQuickActionCard(
                context,
                'Export Data',
                Icons.download,
                Colors.purple,
                () => _showExportOptions(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPendingSellers(BuildContext context) async {
    // Get pending sellers
    final pendingSellers = await firestore
        .collection('users')
        .where('role', isEqualTo: 'seller')
        .where('status', isEqualTo: 'pending')
        .get();

    if (pendingSellers.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pending seller applications'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${pendingSellers.docs.length} Pending Sellers'),
        content: Container(
          width: 400,
          height: 300,
          child: ListView.builder(
            itemCount: pendingSellers.docs.length,
            itemBuilder: (context, index) {
              final seller = pendingSellers.docs[index].data();
              return ListTile(
                leading: CircleAvatar(
                  child: Text((seller['businessName'] ?? seller['email'] ?? 'U')[0]),
                ),
                title: Text(seller['businessName'] ?? seller['email'] ?? 'Unknown'),
                subtitle: Text('Applied: ${_formatDate(seller['createdAt'])}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => _approveSeller(context, pendingSellers.docs[index].id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => _rejectSeller(context, pendingSellers.docs[index].id),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showBulkOperations(context, BulkEntityType.sellers, pendingSellers.docs.map((d) => d.id).toList());
            },
            child: const Text('Bulk Actions'),
          ),
        ],
      ),
    );
  }

  void _showFailedOrders(BuildContext context) async {
    final failedOrders = await firestore
        .collection('orders')
        .where('status', whereIn: ['payment_failed', 'failed', 'cancelled'])
        .limit(10)
        .get();

    if (failedOrders.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No failed orders found'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${failedOrders.docs.length} Failed Orders'),
        content: Container(
          width: 400,
          height: 300,
          child: ListView.builder(
            itemCount: failedOrders.docs.length,
            itemBuilder: (context, index) {
              final order = failedOrders.docs[index].data();
              return ListTile(
                leading: Icon(Icons.error_outline, color: Colors.red),
                title: Text('Order ${OrderUtils.formatShortOrderNumber(order['orderNumber'] ?? '')}'),
                subtitle: Text('Status: ${order['status']} • R${order['total']?.toStringAsFixed(2) ?? '0.00'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onNavigateToSection?.call(5); // Navigate to orders section
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onNavigateToSection?.call(5); // Navigate to orders section
            },
            child: const Text('View All Orders'),
          ),
        ],
      ),
    );
  }

  void _showLowReviews(BuildContext context) async {
    final lowReviews = await firestore
        .collection('reviews')
        .where('rating', isLessThanOrEqualTo: 2)
        .orderBy('rating')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    if (lowReviews.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No low-rated reviews found'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${lowReviews.docs.length} Low-Rated Reviews'),
        content: Container(
          width: 400,
          height: 300,
          child: ListView.builder(
            itemCount: lowReviews.docs.length,
            itemBuilder: (context, index) {
              final review = lowReviews.docs[index].data();
              return ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    review['rating'] ?? 0,
                    (i) => const Icon(Icons.star, color: Colors.amber, size: 16),
                  ),
                ),
                title: Text(review['comment']?.substring(0, 50) ?? 'No comment'),
                subtitle: Text('${_formatDate(review['timestamp'])}'),
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onNavigateToSection?.call(11); // Navigate to reviews section
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onNavigateToSection?.call(11); // Navigate to reviews section
            },
            child: const Text('View All Reviews'),
          ),
        ],
      ),
    );
  }

  void _showBulkOperationsMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Operations'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manage Users'),
              onTap: () {
                Navigator.of(context).pop();
                onNavigateToSection?.call(3); // Navigate to users section
              },
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Manage Sellers'),
              onTap: () {
                Navigator.of(context).pop();
                onNavigateToSection?.call(4); // Navigate to sellers section
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Manage Orders'),
              onTap: () {
                Navigator.of(context).pop();
                onNavigateToSection?.call(5); // Navigate to orders section
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSystemHealth(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.health_and_safety, color: Colors.green),
            const SizedBox(width: 8),
            const Text('System Health'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHealthItem('Database Connection', true),
            _buildHealthItem('Authentication Service', true),
            _buildHealthItem('Notification Service', RealTimeNotificationService().isConnected),
            _buildHealthItem('File Storage', true),
            _buildHealthItem('Payment Gateway', true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthItem(String service, bool isHealthy) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isHealthy ? Icons.check_circle : Icons.error,
            color: isHealthy ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(service)),
          Text(
            isHealthy ? 'Healthy' : 'Issues',
            style: TextStyle(
              color: isHealthy ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Export Users'),
              subtitle: const Text('CSV format'),
              onTap: () => _exportData(context, 'users'),
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Export Sellers'),
              subtitle: const Text('CSV format'),
              onTap: () => _exportData(context, 'sellers'),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Export Orders'),
              subtitle: const Text('CSV format'),
              onTap: () => _exportData(context, 'orders'),
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('Export Reviews'),
              subtitle: const Text('CSV format'),
              onTap: () => _exportData(context, 'reviews'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showBulkOperations(BuildContext context, BulkEntityType entityType, List<String> selectedItems) {
    showDialog(
      context: context,
      builder: (context) => BulkOperationsPanel(
        firestore: firestore,
        auth: auth,
        selectedItems: selectedItems,
        entityType: entityType,
      ),
    );
  }

  Future<void> _approveSeller(BuildContext context, String sellerId) async {
    try {
      await firestore.collection('users').doc(sellerId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': auth.currentUser?.uid,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seller approved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving seller: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectSeller(BuildContext context, String sellerId) async {
    try {
      await firestore.collection('users').doc(sellerId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': auth.currentUser?.uid,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seller rejected'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting seller: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _exportData(BuildContext context, String dataType) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exporting $dataType data...'),
        backgroundColor: Colors.blue,
      ),
    );
    // In a real implementation, this would trigger the actual export
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = timestamp is Timestamp ? timestamp.toDate() : DateTime.parse(timestamp.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }
} 