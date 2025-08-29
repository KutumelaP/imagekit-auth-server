import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';
import '../screens/CheckoutScreen.dart';

class SellerFinancialDashboard extends StatefulWidget {
  const SellerFinancialDashboard({Key? key}) : super(key: key);

  @override
  State<SellerFinancialDashboard> createState() => _SellerFinancialDashboardState();
}

class _SellerFinancialDashboardState extends State<SellerFinancialDashboard> {
  bool _isLoading = true;
  double _outstandingAmount = 0.0;
  String _outstandingType = '';
  String _description = '';
  DateTime? _lastUpdated;
  bool _codDisabled = false;
  List<Map<String, dynamic>> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    try {
      setState(() => _isLoading = true);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get outstanding fees
      final receivableDoc = await FirebaseFirestore.instance
          .collection('platform_receivables')
          .doc(user.uid)
          .get();

      if (receivableDoc.exists) {
        final data = receivableDoc.data()!;
        _outstandingAmount = (data['amount'] is num) 
            ? (data['amount'] as num).toDouble() 
            : double.tryParse('${data['amount']}') ?? 0.0;
        _outstandingType = data['type'] ?? '';
        _description = data['description'] ?? '';
        _lastUpdated = data['lastUpdated']?.toDate();
      }

      // Check COD status
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        _codDisabled = userData['codDisabled'] ?? false;
      }

      // Get recent financial transactions (last 10)
      final transactionsSnap = await FirebaseFirestore.instance
          .collection('seller_transactions')
          .where('sellerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      _recentTransactions = transactionsSnap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': data['type'] ?? '',
          'amount': data['amount'] ?? 0.0,
          'description': data['description'] ?? '',
          'createdAt': data['createdAt']?.toDate(),
          'status': data['status'] ?? 'pending',
        };
      }).toList();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading financial data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Dashboard'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadFinancialData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Outstanding Fees Card
                  _buildOutstandingFeesCard(),
                  
                  SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                  
                  // COD Status Card
                  _buildCodStatusCard(),
                  
                  SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                  
                  // Recent Transactions
                  _buildRecentTransactionsCard(),
                  
                  SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                  
                  // Financial Health Tips
                  _buildFinancialTipsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildOutstandingFeesCard() {
    final hasOutstanding = _outstandingAmount > 0;
    
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: hasOutstanding 
              ? LinearGradient(
                  colors: [Colors.red[50]!, Colors.red[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.green[50]!, Colors.green[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasOutstanding ? Icons.warning : Icons.check_circle,
                  color: hasOutstanding ? Colors.red : Colors.green,
                  size: ResponsiveUtils.getIconSize(context, baseSize: 24),
                ),
                SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                Text(
                  'Outstanding Fees',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context),
                    fontWeight: FontWeight.bold,
                    color: hasOutstanding ? Colors.red[800] : Colors.green[800],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
            
            Text(
              hasOutstanding 
                  ? 'R${_outstandingAmount.toStringAsFixed(2)}'
                  : 'R0.00',
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context) + 8,
                fontWeight: FontWeight.bold,
                color: hasOutstanding ? Colors.red[900] : Colors.green[900],
              ),
            ),
            
            if (hasOutstanding) ...[
              SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.3),
              Text(
                'Type: $_outstandingType',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getBodySize(context),
                  color: Colors.red[700],
                ),
              ),
              if (_description.isNotEmpty)
                Text(
                  _description,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getBodySize(context) - 1,
                    color: Colors.red[600],
                  ),
                ),
              if (_lastUpdated != null)
                Text(
                  'Last updated: ${_formatDate(_lastUpdated!)}',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getBodySize(context) - 2,
                    color: Colors.red[500],
                  ),
                ),
              
              SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
              
              ElevatedButton.icon(
                onPressed: _payOutstandingFees,
                icon: const Icon(Icons.payment),
                label: const Text('Pay Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ] else ...[
              SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.3),
              Text(
                'Your account is up to date!',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getBodySize(context),
                  color: Colors.green[700],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCodStatusCard() {
    return Card(
      elevation: 2,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _codDisabled ? Icons.block : Icons.check_circle,
                  color: _codDisabled ? Colors.orange : Colors.green,
                  size: ResponsiveUtils.getIconSize(context, baseSize: 20),
                ),
                SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                Text(
                  'Cash on Delivery Status',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getSubtitleSize(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
            
            Text(
              _codDisabled ? 'DISABLED' : 'ENABLED',
              style: TextStyle(
                fontSize: ResponsiveUtils.getBodySize(context) + 2,
                fontWeight: FontWeight.bold,
                color: _codDisabled ? Colors.orange : Colors.green,
              ),
            ),
            
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.3),
            
            Text(
              _codDisabled 
                  ? 'COD is disabled due to outstanding fees. Pay your dues to re-enable.'
                  : 'COD is enabled. Customers can pay cash on delivery.',
              style: TextStyle(
                fontSize: ResponsiveUtils.getBodySize(context),
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsCard() {
    return Card(
      elevation: 2,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: ResponsiveUtils.getSubtitleSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
            
            if (_recentTransactions.isEmpty)
              Text(
                'No recent transactions',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getBodySize(context),
                  color: Colors.grey[600],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentTransactions.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final transaction = _recentTransactions[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: _getTransactionColor(transaction['type']),
                      child: Icon(
                        _getTransactionIcon(transaction['type']),
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    title: Text(
                      transaction['description'],
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getBodySize(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      transaction['createdAt'] != null
                          ? _formatDate(transaction['createdAt'])
                          : 'Unknown date',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getBodySize(context) - 2,
                        color: Colors.grey[600],
                      ),
                    ),
                    trailing: Text(
                      'R${(transaction['amount'] as double).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getBodySize(context),
                        fontWeight: FontWeight.bold,
                        color: transaction['amount'] > 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialTipsCard() {
    return Card(
      elevation: 2,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Colors.blue,
                  size: ResponsiveUtils.getIconSize(context, baseSize: 20),
                ),
                SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                Text(
                  'Financial Tips',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getSubtitleSize(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
            
            ..._getFinancialTips().map((tip) => Padding(
              padding: EdgeInsets.only(bottom: ResponsiveUtils.getVerticalPadding(context) * 0.3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getBodySize(context),
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  List<String> _getFinancialTips() {
    final tips = <String>[
      'Pay outstanding fees promptly to maintain COD access',
      'Monitor your commission rates and transaction fees',
      'Keep your payment methods up to date',
    ];

    if (_outstandingAmount > 0) {
      tips.insert(0, 'Clear outstanding fees to re-enable Cash on Delivery');
    }

    return tips;
  }

  Color _getTransactionColor(String type) {
    switch (type.toLowerCase()) {
      case 'commission':
        return Colors.orange;
      case 'payment':
        return Colors.green;
      case 'refund':
        return Colors.blue;
      case 'fee':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTransactionIcon(String type) {
    switch (type.toLowerCase()) {
      case 'commission':
        return Icons.percent;
      case 'payment':
        return Icons.payment;
      case 'refund':
        return Icons.undo;
      case 'fee':
        return Icons.remove_circle;
      default:
        return Icons.attach_money;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _payOutstandingFees() {
    // Navigate to payment screen with pre-filled amount
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          isWalletTopUp: true,
          prefilledAmount: _outstandingAmount,
        ),
      ),
    );
  }
}
