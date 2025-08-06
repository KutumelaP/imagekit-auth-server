import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/admin_theme.dart';

class ReturnsManagement extends StatefulWidget {
  const ReturnsManagement({Key? key}) : super(key: key);

  @override
  State<ReturnsManagement> createState() => _ReturnsManagementState();
}

class _ReturnsManagementState extends State<ReturnsManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingReturns = [];
  List<Map<String, dynamic>> _processedReturns = [];
  Map<String, dynamic> _returnStats = {};

  @override
  void initState() {
    super.initState();
    _loadReturnsData();
  }

  Future<void> _loadReturnsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadPendingReturns(),
        _loadProcessedReturns(),
        _loadReturnStats(),
      ]);
    } catch (e) {
      print('Error loading returns data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPendingReturns() async {
    try {
      QuerySnapshot returnsQuery = await _firestore
          .collection('returns')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> returns = [];
      for (var doc in returnsQuery.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        returns.add({
          'id': doc.id,
          ...data,
        });
      }

      setState(() {
        _pendingReturns = returns;
      });
    } catch (e) {
      print('Error loading pending returns: $e');
    }
  }

  Future<void> _loadProcessedReturns() async {
    try {
      QuerySnapshot returnsQuery = await _firestore
          .collection('returns')
          .where('status', whereIn: ['approved', 'rejected', 'completed'])
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> returns = [];
      for (var doc in returnsQuery.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        returns.add({
          'id': doc.id,
          ...data,
        });
      }

      setState(() {
        _processedReturns = returns;
      });
    } catch (e) {
      print('Error loading processed returns: $e');
    }
  }

  Future<void> _loadReturnStats() async {
    try {
      QuerySnapshot returnsQuery = await _firestore
          .collection('returns')
          .get();

      int totalReturns = returnsQuery.docs.length;
      int pendingReturns = 0;
      int approvedReturns = 0;
      int rejectedReturns = 0;
      double totalRefundAmount = 0;

      for (var doc in returnsQuery.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String status = data['status'] ?? 'pending';
        
        switch (status) {
          case 'pending':
            pendingReturns++;
            break;
          case 'approved':
          case 'completed':
            approvedReturns++;
            totalRefundAmount += (data['refundAmount'] ?? 0.0);
            break;
          case 'rejected':
            rejectedReturns++;
            break;
        }
      }

      setState(() {
        _returnStats = {
          'totalReturns': totalReturns,
          'pendingReturns': pendingReturns,
          'approvedReturns': approvedReturns,
          'rejectedReturns': rejectedReturns,
          'totalRefundAmount': totalRefundAmount,
        };
      });
    } catch (e) {
      print('Error loading return stats: $e');
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
                    Expanded(child: _buildPendingReturns()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildProcessedReturns()),
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
              Icons.assignment_return,
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
                  'Returns Management',
                  style: AdminTheme.headlineLarge.copyWith(
                    color: AdminTheme.angel,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Process returns, approve refunds, and manage customer disputes',
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
          'Total Returns',
          '${_returnStats['totalReturns'] ?? 0}',
          Icons.assignment_return,
          AdminTheme.deepTeal,
        ),
        _buildStatCard(
          'Pending',
          '${_returnStats['pendingReturns'] ?? 0}',
          Icons.schedule,
          AdminTheme.warning,
        ),
        _buildStatCard(
          'Approved',
          '${_returnStats['approvedReturns'] ?? 0}',
          Icons.check_circle,
          AdminTheme.success,
        ),
        _buildStatCard(
          'Total Refunds',
          'R${_returnStats['totalRefundAmount']?.toStringAsFixed(2) ?? '0.00'}',
          Icons.payment,
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

  Widget _buildPendingReturns() {
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
                'Pending Returns',
                style: AdminTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _pendingReturns.isEmpty
              ? Center(
                  child: Text(
                    'No pending returns',
                    style: AdminTheme.bodyMedium.copyWith(
                      color: AdminTheme.cloud,
                    ),
                  ),
                )
              : Column(
                  children: _pendingReturns.map((returnItem) {
                    return _buildReturnCard(returnItem, true);
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildProcessedReturns() {
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
              Icon(Icons.history, color: AdminTheme.deepTeal),
              const SizedBox(width: 8),
              Text(
                'Processed Returns',
                style: AdminTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _processedReturns.isEmpty
              ? Center(
                  child: Text(
                    'No processed returns',
                    style: AdminTheme.bodyMedium.copyWith(
                      color: AdminTheme.cloud,
                    ),
                  ),
                )
              : Column(
                  children: _processedReturns.map((returnItem) {
                    return _buildReturnCard(returnItem, false);
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildReturnCard(Map<String, dynamic> returnItem, bool isPending) {
    final orderId = returnItem['orderId'] ?? 'Unknown';
    final customerId = returnItem['customerId'] ?? 'Unknown';
    final sellerId = returnItem['sellerId'] ?? 'Unknown';
    final refundAmount = returnItem['refundAmount'] ?? 0.0;
    final reason = returnItem['reason'] ?? 'No reason provided';
    final status = returnItem['status'] ?? 'pending';
    final createdAt = returnItem['createdAt'] as Timestamp?;
    final returnNotes = returnItem['returnNotes'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      'Order: ${orderId.substring(0, 8)}...',
                      style: AdminTheme.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'R${refundAmount.toStringAsFixed(2)}',
                      style: AdminTheme.titleSmall.copyWith(
                        color: AdminTheme.deepTeal,
                        fontWeight: FontWeight.w600,
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
          const SizedBox(height: 8),
          Text(
            'Reason: $reason',
            style: AdminTheme.bodySmall.copyWith(
              color: AdminTheme.cloud,
            ),
          ),
          if (returnNotes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Notes: $returnNotes',
              style: AdminTheme.bodySmall.copyWith(
                color: AdminTheme.cloud,
              ),
            ),
          ],
          if (createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Requested: ${DateFormat('MMM dd, yyyy').format(createdAt.toDate())}',
              style: AdminTheme.bodySmall.copyWith(
                color: AdminTheme.cloud,
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _processReturn(returnItem['id'], 'approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.success,
                      foregroundColor: AdminTheme.angel,
                    ),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _processReturn(returnItem['id'], 'rejected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.error,
                      foregroundColor: AdminTheme.angel,
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
        return AdminTheme.success;
      case 'pending':
        return AdminTheme.warning;
      case 'rejected':
        return AdminTheme.error;
      default:
        return AdminTheme.cloud;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.assignment_return;
    }
  }

  Future<void> _processReturn(String returnId, String action) async {
    try {
      // Update return status
      await _firestore
          .collection('returns')
          .doc(returnId)
          .update({
        'status': action,
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': 'admin', // In real app, get from auth
      });

      // If approved, process the refund
      if (action == 'approved') {
        await _processRefund(returnId);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Return ${action} successfully!'),
          backgroundColor: action == 'approved' ? AdminTheme.success : AdminTheme.error,
        ),
      );

      await _loadReturnsData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing return: $e'),
          backgroundColor: AdminTheme.error,
        ),
      );
    }
  }

  Future<void> _processRefund(String returnId) async {
    try {
      // Get return details
      DocumentSnapshot returnDoc = await _firestore
          .collection('returns')
          .doc(returnId)
          .get();

      if (!returnDoc.exists) return;

      Map<String, dynamic> returnData = returnDoc.data() as Map<String, dynamic>;
      
      // Process refund using PayFast service
      // This would integrate with your PayFastService.processReturn method
      print('Processing refund for return: $returnId');
      
      // Update return status to completed
      await _firestore
          .collection('returns')
          .doc(returnId)
          .update({
        'status': 'completed',
        'refundProcessedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error processing refund: $e');
    }
  }
} 