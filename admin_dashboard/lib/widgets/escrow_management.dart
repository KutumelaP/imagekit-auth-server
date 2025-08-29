import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// removed: import 'package:intl/intl.dart';
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
  // legacy fields removed

  @override
  void initState() {
    super.initState();
    _loadEscrowData();
  }

  Future<void> _loadEscrowData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Load ledger-based statistics (current system)
      await _loadLedgerStats();
    } catch (e) {
      print('Error loading escrow data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // removed legacy _loadEscrowStats

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  Future<void> _loadLedgerStats() async {
    try {
      double totalAvailable = 0;
      double totalLocked = 0;
      double totalSettled = 0;
      double pendingPayoutsAmount = 0;
      int pendingPayoutsCount = 0;

      // Use simpler queries that work with existing rules and indexes
      // Get data from platform_receivables collection which has proper subcollections
      final receivablesSnap = await _firestore.collection('platform_receivables').get();
      
      for (final receivableDoc in receivablesSnap.docs) {
        try {
          // Get entries for this seller
          final entriesSnap = await receivableDoc.reference.collection('entries').get();
          for (final entryDoc in entriesSnap.docs) {
            final entryData = entryDoc.data();
            final status = entryData['status'] ?? '';
            final amount = _toDouble(entryData['net'] ?? entryData['amount']);
            
            if (status == 'available') {
              totalAvailable += amount;
            } else if (status == 'locked') {
              totalLocked += amount;
            }
          }
          
          // Get settlements for this seller
          final settlementsSnap = await receivableDoc.reference.collection('settlements').get();
          for (final settlementDoc in settlementsSnap.docs) {
            final settlementData = settlementDoc.data();
            final paid = _toDouble(settlementData['amountPaid']);
            final collected = _toDouble(settlementData['amountCollected']);
            totalSettled += paid > 0 ? paid : collected;
          }
        } catch (e) {
          print('Error processing receivable ${receivableDoc.id}: $e');
          continue;
        }
      }

      // Get pending payouts
      try {
        final payoutsSnap = await _firestore.collection('payouts').where('status', whereIn: ['requested', 'processing']).get();
        for (final d in payoutsSnap.docs) {
          final m = d.data();
          pendingPayoutsAmount += _toDouble(m['amount']);
        }
        pendingPayoutsCount = payoutsSnap.size;
      } catch (e) {
        print('Error loading payouts: $e');
        // Continue without payout data if there's an error
      }

      if (mounted) {
        setState(() {
          _stats = {
            'totalAvailable': totalAvailable,
            'totalLocked': totalLocked,
            'totalSettled': totalSettled,
            'pendingPayoutsAmount': pendingPayoutsAmount,
            'pendingPayoutsCount': pendingPayoutsCount,
          };
        });
      }
    } catch (e) {
      print('Error loading ledger stats: $e');
    }
  }

  // removed legacy _loadRecentPayments

  // removed legacy _loadPendingHoldbacks

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
                // Removed legacy recent payments and holdbacks sections
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
                  'Ledger Overview',
                  style: AdminTheme.headlineLarge.copyWith(
                    color: AdminTheme.angel,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Platform receivables, payouts, and settlements',
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
          'Available Balance (All Sellers)',
          'R${(_stats['totalAvailable'] ?? 0.0).toStringAsFixed(2)}',
          Icons.account_balance_wallet,
          AdminTheme.deepTeal,
        ),
        _buildStatCard(
          'Locked (In Payout Flows)',
          'R${(_stats['totalLocked'] ?? 0.0).toStringAsFixed(2)}',
          Icons.lock_clock,
          AdminTheme.warning,
        ),
        _buildStatCard(
          'Settled To Sellers',
          'R${(_stats['totalSettled'] ?? 0.0).toStringAsFixed(2)}',
          Icons.payments,
          AdminTheme.success,
        ),
        _buildStatCard(
          'Pending Payouts',
          'R${(_stats['pendingPayoutsAmount'] ?? 0.0).toStringAsFixed(2)} (${_stats['pendingPayoutsCount'] ?? 0})',
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

  // removed legacy _buildRecentPayments

  // removed legacy _buildPaymentCard

  // removed legacy _buildPendingHoldbacks

  // removed legacy _buildHoldbackCard

  // removed unused legacy helpers
} 