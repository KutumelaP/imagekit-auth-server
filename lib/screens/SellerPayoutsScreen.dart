import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../theme/app_theme.dart';

class SellerPayoutsScreen extends StatefulWidget {
  const SellerPayoutsScreen({super.key});

  @override
  State<SellerPayoutsScreen> createState() => _SellerPayoutsScreenState();
}

class _SellerPayoutsScreenState extends State<SellerPayoutsScreen> {
  bool _loading = false;
  bool _requesting = false;
  double _gross = 0.0;
  double _commission = 0.0;
  double _net = 0.0;
  double _min = 0.0;
  double _commissionPct = 0.0;
  List<Map<String, dynamic>> _history = [];
  
  // COD wallet balance
  Map<String, dynamic> _codWallet = {};
  
  // Outstanding fees
  double _outstandingAmount = 0.0;
  String _outstandingType = '';
  bool _codDisabled = false;

  

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadBalance(),
      _loadHistory(),
      _loadOutstandingFees(),
    ]);
  }

  Future<void> _loadBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      setState(() { _loading = true; });
      final functions = FirebaseFunctions.instance;
      final res = await functions.httpsCallable('getSellerAvailableBalance').call({ 'userId': user.uid });
      final data = Map<String, dynamic>.from(res.data as Map);
      
      // Debug logging
      print('🔍 DEBUG: Cloud Function Response:');
      print('  Raw response: ${res.data}');
      print('  Parsed data: $data');
      print('  Gross: ${data['gross']}');
      print('  Commission: ${data['commission']}');
      print('  Net: ${data['net']}');
      print('  Min: ${data['minPayoutAmount']}');
      
      setState(() {
        _gross = (data['gross'] ?? 0).toDouble();
        _commission = (data['commission'] ?? 0).toDouble();
        _net = (data['net'] ?? 0).toDouble();
        _min = (data['minPayoutAmount'] ?? 0).toDouble();
        _commissionPct = ((data['commissionPct'] ?? 0) as num).toDouble();
        _codWallet = Map<String, dynamic>.from(data['codWallet'] ?? {});
        
        // Debug logging after setState
        print('🔍 DEBUG: Values set in setState:');
        print('  _gross: $_gross');
        print('  _commission: $_commission');
        print('  _net: $_net');
        print('  _min: $_min');
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load balance: $e')));
      }
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _loadHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final qs = await FirebaseFirestore.instance
          .collection('users').doc(user.uid)
          .collection('payouts')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      setState(() { _history = qs.docs.map((d) => { 'id': d.id, ...d.data() }).toList().cast<Map<String, dynamic>>(); });
    } catch (_) {}
  }

  Future<void> _loadOutstandingFees() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // Get outstanding fees
      final receivableDoc = await FirebaseFirestore.instance
          .collection('platform_receivables')
          .doc(user.uid)
          .get();

      double outstandingAmount = 0.0;
      String outstandingType = '';
      
      if (receivableDoc.exists) {
        final data = receivableDoc.data()!;
        outstandingAmount = (data['amount'] is num) 
            ? (data['amount'] as num).toDouble() 
            : double.tryParse('${data['amount']}') ?? 0.0;
        outstandingType = data['type'] ?? '';
      }

      // Check COD status
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      bool codDisabled = false;
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        codDisabled = userData['codDisabled'] ?? false;
      }

      setState(() {
        _outstandingAmount = outstandingAmount;
        _outstandingType = outstandingType;
        _codDisabled = codDisabled;
      });
    } catch (e) {
      print('Error loading outstanding fees: $e');
    }
  }

  

  Future<void> _requestPayout() async {
    try {
      setState(() { _requesting = true; });
      final functions = FirebaseFunctions.instance;
      await functions.httpsCallable('requestPayout').call({});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout requested')));
      }
      await _refreshAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request failed: $e')));
      }
    } finally {
      if (mounted) setState(() { _requesting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.whisper,
      appBar: AppBar(
        title: const Text('Earnings & Payouts'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: AppTheme.angel,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate to simple home screen instead of just popping
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/home',
              (route) => false,
            );
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive padding based on screen width
            final horizontalPadding = constraints.maxWidth > 600 
                ? (constraints.maxWidth - 600) / 2 + 16 
                : 16.0;
            
            return ListView(
              padding: EdgeInsets.only(
                left: horizontalPadding,
                right: horizontalPadding,
                top: 16,
                bottom: 32, // Reduced bottom padding to minimize white space
              ),
              children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.account_balance_wallet, color: AppTheme.deepTeal),
                    const SizedBox(width: 8),
                    const Text('Available Balance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(onPressed: _loadBalance, icon: const Icon(Icons.refresh)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    'Money you\'ve earned from completed orders that can be withdrawn',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 8),
                  if (_loading) const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 16),
                  
                  // Main Available Balance
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.deepTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: AppTheme.deepTeal, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '💰 AVAILABLE TO WITHDRAW',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.deepTeal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'R ${_net.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.deepTeal,
                          ),
                        ),
                        Text(
                          'This is your money after platform fees - ready to withdraw!',
                          style: TextStyle(
                            color: AppTheme.deepTeal.withOpacity(0.7),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Detailed Breakdown
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.receipt_long, color: AppTheme.deepTeal, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Total Sales',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.deepTeal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'R ${_gross.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.deepTeal,
                                ),
                              ),
                              Text(
                                'What customers paid',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.percent, color: AppTheme.deepTeal, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Platform Fee',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.deepTeal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'R ${_commission.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.deepTeal,
                                ),
                              ),
                              Text(
                                '${(_commissionPct * 100).toStringAsFixed(0)}% of sales',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Minimum payout info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.deepTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.deepTeal, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Minimum payout: R${_min.toStringAsFixed(2)}. Commission covers platform costs (payment processing, hosting, support).',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.deepTeal,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Payout Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_requesting || _net < _min) ? null : _requestPayout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.deepTeal,
                        foregroundColor: AppTheme.angel,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _requesting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.payments),
                      label: Text(_requesting
                          ? 'Requesting...'
                          : (_net < _min ? 'Minimum R ${_min.toStringAsFixed(0)}' : 'Request Payout')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // COD Wallet Section
            if (_codWallet.isNotEmpty && (_codWallet['cashCollected'] ?? 0) > 0) Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
                border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3), width: 1),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.account_balance_wallet, color: AppTheme.deepTeal),
                    const SizedBox(width: 8),
                    const Text('COD Wallet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(onPressed: _loadBalance, icon: const Icon(Icons.refresh, size: 20)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    'Cash collected from customers vs commission owed to platform',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 12),
                  
                  // COD Summary - Vertical List
                  Column(
                    children: [
                      // Cash Collected
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.deepTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.money, color: AppTheme.deepTeal, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Cash Collected', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                  Text('R${(_codWallet['cashCollected'] ?? 0).toStringAsFixed(2)}', 
                                       style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.deepTeal)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Commission Owed
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.deepTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.account_balance, color: AppTheme.deepTeal, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Commission Owed to Platform', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                  Text('R${(_codWallet['commissionOwed'] ?? 0).toStringAsFixed(2)}', 
                                       style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.deepTeal)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Your Share
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.deepTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.savings, color: AppTheme.deepTeal, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Your Share (After Commission)', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                  Text('R${((_codWallet['cashCollected'] ?? 0) - (_codWallet['commissionOwed'] ?? 0)).toStringAsFixed(2)}', 
                                       style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.deepTeal)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  if ((_codWallet['commissionOwed'] ?? 0) > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.deepTeal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: AppTheme.deepTeal, size: 16),
                              const SizedBox(width: 6),
                              const Text('Platform Commission Due', style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You collected R${(_codWallet['cashCollected'] ?? 0).toStringAsFixed(2)} in cash but owe R${(_codWallet['commissionOwed'] ?? 0).toStringAsFixed(2)} in platform commission. Pay this to keep your earnings available for payout.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _payOutstandingFees(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.deepTeal,
                          foregroundColor: AppTheme.angel,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.payment),
                        label: Text('Pay Commission R${(_codWallet['commissionOwed'] ?? 0).toStringAsFixed(2)}'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            if (_codWallet.isNotEmpty && (_codWallet['cashCollected'] ?? 0) > 0) const SizedBox(height: 16),
            
            // Outstanding Fees Section
            if (_outstandingAmount > 0 || _codDisabled) Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
                border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3), width: 1),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.warning, color: AppTheme.deepTeal),
                    const SizedBox(width: 8),
                    Text('Outstanding Fees', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.deepTeal)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    'Platform fees that need to be paid to maintain full access',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 8),
                  if (_outstandingAmount > 0) ...[
                                            FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('R ${_outstandingAmount.toStringAsFixed(2)}', 
                               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.deepTeal)),
                        ),
                    const SizedBox(height: 4),
                    Text('Type: $_outstandingType', style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 8),
                  ],
                  if (_codDisabled) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.deepTeal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block, color: AppTheme.deepTeal, size: 16),
                          const SizedBox(width: 6),
                          Text('Cash on Delivery Disabled', style: TextStyle(color: AppTheme.deepTeal, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.deepTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: AppTheme.deepTeal, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('Why are there outstanding fees?', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.deepTeal)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _outstandingAmount > 0 
                              ? '• Platform commission from recent sales\n• Payment processing fees\n• Service charges for marketplace features\n\nPaying these fees re-enables Cash on Delivery for your customers.'
                              : '• Complete your identity verification in Profile settings\n• This ensures secure transactions for all users\n• Required by South African financial regulations',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  if (_outstandingAmount > 0) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _payOutstandingFees(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.deepTeal,
                          foregroundColor: AppTheme.angel,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.payment),
                        label: const Text('Pay Outstanding Fees'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            if (_outstandingAmount > 0 || _codDisabled) const SizedBox(height: 16),
            
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long, color: AppTheme.deepTeal),
                      const SizedBox(width: 8),
                      const Text('Payout History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Record of money withdrawn to your bank account',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 8),
                  if (_history.isEmpty)
                    Text('No payouts yet', style: TextStyle(color: Colors.grey[600])),
                  ..._history.map((p) {
                    final amount = (p['amount'] ?? 0).toDouble();
                    final status = (p['status'] ?? 'requested').toString();
                    final ref = (p['reference'] ?? '').toString();
                    final failureReason = (p['failureReason'] ?? '').toString();
                    final failureNotes = (p['failureNotes'] ?? '').toString();
                    final ts = p['createdAt'];
                    String date = '';
                    try {
                      if (ts is Timestamp) date = ts.toDate().toLocal().toString();
                    } catch (_) {}
                    
                    // Get status color and icon - using standard theme
                    Color statusColor = AppTheme.deepTeal;
                    IconData statusIcon = Icons.payments_outlined;
                    
                    switch (status) {
                      case 'paid':
                        statusColor = AppTheme.deepTeal;
                        statusIcon = Icons.check_circle;
                        break;
                      case 'failed':
                        statusColor = AppTheme.deepTeal;
                        statusIcon = Icons.error;
                        break;
                      case 'cancelled':
                        statusColor = AppTheme.deepTeal;
                        statusIcon = Icons.cancel;
                        break;
                      case 'processing':
                        statusColor = AppTheme.deepTeal;
                        statusIcon = Icons.sync;
                        break;
                      default:
                        statusColor = AppTheme.deepTeal;
                        statusIcon = Icons.pending;
                    }
                    
                    return ListTile(
                      dense: MediaQuery.of(context).size.width < 360,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(statusIcon, color: statusColor),
                      title: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('R ${amount.toStringAsFixed(2)}  •  ${status.toUpperCase()}'),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [if (date.isNotEmpty) date, if (ref.isNotEmpty) 'Ref: $ref'].join('  \u2022  '),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          // Show failure reason if payout failed
                          if (status == 'failed' && failureReason.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.red.shade700, size: 16),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _getFailureReasonLabel(failureReason),
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // Show failure notes if available
                          if (status == 'failed' && failureNotes.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Note: $failureNotes',
                              style: TextStyle(
                                color: Colors.red.shade600,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            

          ],
            );
          },
        ),
      ),
    );
  }



  void _payOutstandingFees() {
    // Navigate to payment screen for outstanding fees
    Navigator.pushNamed(context, '/checkout', arguments: {
      'isWalletTopUp': true,
      'prefilledAmount': _outstandingAmount,
      'paymentReason': 'outstanding_fees',
    });
  }

  String _getFailureReasonLabel(String reason) {
    switch (reason) {
      case 'bank_account_closed':
        return 'Bank account closed';
      case 'invalid_account_number':
        return 'Invalid account number';
      case 'insufficient_funds':
        return 'Insufficient funds';
      case 'bank_rejected_compliance':
        return 'Bank rejected (compliance)';
      case 'expired_payout_request':
        return 'Expired payout request';
      case 'wrong_account_details':
        return 'Wrong account details';
      case 'technical_error':
        return 'Technical error';
      case 'other':
        return 'Other';
      default:
        return reason;
    }
  }
}
