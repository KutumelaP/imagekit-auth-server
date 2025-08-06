import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/admin_theme.dart';

class EscrowManagement extends StatefulWidget {
  const EscrowManagement({Key? key}) : super(key: key);

  @override
  State<EscrowManagement> createState() => _EscrowManagementState();
}

class _EscrowManagementState extends State<EscrowManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentPayments = [];
  List<Map<String, dynamic>> _pendingHoldbacks = [];

  @override
  void initState() {
    super.initState();
    _loadEscrowData();
  }

  Future<void> _loadEscrowData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load escrow statistics
      await _loadEscrowStats();
      
      // Load recent payments
      await _loadRecentPayments();
      
      // Load pending holdbacks
      await _loadPendingHoldbacks();
    } catch (e) {
      print('Error loading escrow data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEscrowStats() async {
    try {
      // Get escrow payments collection
      QuerySnapshot escrowQuery = await _firestore
          .collection('escrow_payments')
          .get();

      double totalEscrowAmount = 0;
      double totalHoldbackAmount = 0;
      double totalReleasedAmount = 0;
      int pendingPayments = 0;
      int completedPayments = 0;

      for (var doc in escrowQuery.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        if (data['paymentStatus'] == 'completed') {
          totalEscrowAmount += (data['orderTotal'] ?? 0.0);
          totalHoldbackAmount += (data['holdbackAmount'] ?? 0.0);
          completedPayments++;
        } else if (data['paymentStatus'] == 'pending') {
          pendingPayments++;
        }
      }

      // Get holdback schedules
      QuerySnapshot holdbackQuery = await _firestore
          .collection('holdback_schedules')
          .where('status', isEqualTo: 'released')
          .get();

      for (var doc in holdbackQuery.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        totalReleasedAmount += (data['holdbackAmount'] ?? 0.0);
      }

      setState(() {
        _stats = {
          'totalEscrowAmount': totalEscrowAmount,
          'totalHoldbackAmount': totalHoldbackAmount,
          'totalReleasedAmount': totalReleasedAmount,
          'pendingPayments': pendingPayments,
          'completedPayments': completedPayments,
        };
      });
    } catch (e) {
      print('Error loading escrow stats: $e');
    }
  }

  Future<void> _loadRecentPayments() async {
    try {
      QuerySnapshot paymentsQuery = await _firestore
          .collection('seller_payments')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> payments = [];
      for (var doc in paymentsQuery.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        payments.add({
          'id': doc.id,
          ...data,
        });
      }

      setState(() {
        _recentPayments = payments;
      });
    } catch (e) {
      print('Error loading recent payments: $e');
    }
  }

  Future<void> _loadPendingHoldbacks() async {
    try {
      QuerySnapshot holdbackQuery = await _firestore
          .collection('holdback_schedules')
          .where('status', isEqualTo: 'scheduled')
          .orderBy('releaseDate')
          .limit(10)
          .get();

      List<Map<String, dynamic>> holdbacks = [];
      for (var doc in holdbackQuery.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        holdbacks.add({
          'id': doc.id,
          ...data,
        });
      }

      setState(() {
        _pendingHoldbacks = holdbacks;
      });
    } catch (e) {
      print('Error loading pending holdbacks: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildStatsCards(),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildRecentPayments()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildPendingHoldbacks()),
                  ],
                ),
              ],
            ),
          );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AdminTheme.deepTeal, AdminTheme.cloud],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminTheme.angel.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.account_balance,
              color: AdminTheme.angel,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Escrow Management',
                  style: AdminTheme.headlineLarge.copyWith(
                    color: AdminTheme.angel,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monitor payments, holdbacks, and escrow balances',
                  style: AdminTheme.bodyMedium.copyWith(
                    color: AdminTheme.angel.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Escrow',
          'R${_stats['totalEscrowAmount']?.toStringAsFixed(2) ?? '0.00'}',
          Icons.account_balance_wallet,
          AdminTheme.deepTeal,
        ),
        _buildStatCard(
          'Holdback Amount',
          'R${_stats['totalHoldbackAmount']?.toStringAsFixed(2) ?? '0.00'}',
          Icons.lock,
          AdminTheme.warning,
        ),
        _buildStatCard(
          'Released Amount',
          'R${_stats['totalReleasedAmount']?.toStringAsFixed(2) ?? '0.00'}',
          Icons.payment,
          AdminTheme.success,
        ),
        _buildStatCard(
          'Pending Payments',
          '${_stats['pendingPayments'] ?? 0}',
          Icons.schedule,
          AdminTheme.info,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Icon(Icons.trending_up, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AdminTheme.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AdminTheme.deepTeal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AdminTheme.bodySmall.copyWith(
              color: AdminTheme.cloud,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPayments() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.cloud.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: AdminTheme.deepTeal),
              const SizedBox(width: 8),
              Text(
                'Recent Payments',
                style: AdminTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _recentPayments.isEmpty
              ? Center(
                  child: Text(
                    'No recent payments',
                    style: AdminTheme.bodyMedium.copyWith(
                      color: AdminTheme.cloud,
                    ),
                  ),
                )
              : Column(
                  children: _recentPayments.map((payment) {
                    return _buildPaymentCard(payment);
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final amount = payment['amount'] ?? 0.0;
    final status = payment['status'] ?? 'pending';
    final createdAt = payment['createdAt'] as Timestamp?;
    final sellerId = payment['sellerId'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            _getStatusIcon(status),
            color: _getStatusColor(status),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'R${amount.toStringAsFixed(2)}',
                  style: AdminTheme.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Seller: ${sellerId.substring(0, 8)}...',
                  style: AdminTheme.bodySmall.copyWith(
                    color: AdminTheme.cloud,
                  ),
                ),
                if (createdAt != null)
                  Text(
                    DateFormat('MMM dd, yyyy').format(createdAt.toDate()),
                    style: AdminTheme.bodySmall.copyWith(
                      color: AdminTheme.cloud,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status.toUpperCase(),
              style: AdminTheme.bodySmall.copyWith(
                color: _getStatusColor(status),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingHoldbacks() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.cloud.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: AdminTheme.deepTeal),
              const SizedBox(width: 8),
              Text(
                'Pending Holdbacks',
                style: AdminTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _pendingHoldbacks.isEmpty
              ? Center(
                  child: Text(
                    'No pending holdbacks',
                    style: AdminTheme.bodyMedium.copyWith(
                      color: AdminTheme.cloud,
                    ),
                  ),
                )
              : Column(
                  children: _pendingHoldbacks.map((holdback) {
                    return _buildHoldbackCard(holdback);
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildHoldbackCard(Map<String, dynamic> holdback) {
    final amount = holdback['holdbackAmount'] ?? 0.0;
    final releaseDate = holdback['releaseDate'] as Timestamp?;
    final sellerId = holdback['sellerId'] ?? 'Unknown';
    final orderId = holdback['orderId'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminTheme.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminTheme.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock,
            color: AdminTheme.warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'R${amount.toStringAsFixed(2)}',
                  style: AdminTheme.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Order: ${orderId.substring(0, 8)}...',
                  style: AdminTheme.bodySmall.copyWith(
                    color: AdminTheme.cloud,
                  ),
                ),
                if (releaseDate != null)
                  Text(
                    'Release: ${DateFormat('MMM dd, yyyy').format(releaseDate.toDate())}',
                    style: AdminTheme.bodySmall.copyWith(
                      color: AdminTheme.cloud,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _releaseHoldback(holdback['id']),
            icon: Icon(Icons.lock_open, color: AdminTheme.success),
            tooltip: 'Release Holdback',
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AdminTheme.success;
      case 'pending':
        return AdminTheme.warning;
      case 'failed':
        return AdminTheme.error;
      default:
        return AdminTheme.cloud;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'failed':
        return Icons.error;
      default:
        return Icons.payment;
    }
  }

  Future<void> _releaseHoldback(String holdbackId) async {
    try {
      await _firestore
          .collection('holdback_schedules')
          .doc(holdbackId)
          .update({
        'status': 'released',
        'releasedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Holdback released successfully!'),
          backgroundColor: AdminTheme.success,
        ),
      );

      await _loadEscrowData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error releasing holdback: $e'),
          backgroundColor: AdminTheme.error,
        ),
      );
    }
  }
} 