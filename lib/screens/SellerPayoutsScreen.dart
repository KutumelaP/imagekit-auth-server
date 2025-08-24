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

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadBalance(),
      _loadHistory(),
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
      setState(() {
        _gross = (data['gross'] ?? 0).toDouble();
        _commission = (data['commission'] ?? 0).toDouble();
        _net = (data['net'] ?? 0).toDouble();
        _min = (data['minPayoutAmount'] ?? 0).toDouble();
        _commissionPct = ((data['commissionPct'] ?? 0) as num).toDouble();
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
      setState(() { _history = qs.docs.map((d) => { 'id': d.id, ...?d.data() }).toList().cast<Map<String, dynamic>>(); });
    } catch (_) {}
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
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
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
                  const SizedBox(height: 8),
                  if (_loading) const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 8),
                  LayoutBuilder(builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 380;
                    final stats = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('R ${_net.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'Gross R ${_gross.toStringAsFixed(2)} • Commission R ${_commission.toStringAsFixed(2)} (${(_commissionPct * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    );
                    final button = SizedBox(
                      width: narrow ? double.infinity : null,
                      child: ElevatedButton.icon(
                        onPressed: (_requesting || _net < _min) ? null : _requestPayout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.deepTeal,
                          foregroundColor: AppTheme.angel,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _requesting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.payments),
                        label: Text(_requesting
                            ? 'Requesting...'
                            : (_net < _min ? 'Minimum R ${_min.toStringAsFixed(0)}' : 'Request Payout')),
                      ),
                    );
                    if (narrow) {
                      return Column(children: [stats, const SizedBox(height: 12), button]);
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: stats),
                        const SizedBox(width: 12),
                        button,
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                  const SizedBox(height: 8),
                  if (_history.isEmpty)
                    Text('No payouts yet', style: TextStyle(color: Colors.grey[600])),
                  ..._history.map((p) {
                    final amount = (p['amount'] ?? 0).toDouble();
                    final status = (p['status'] ?? 'requested').toString();
                    final ref = (p['reference'] ?? '').toString();
                    final ts = p['createdAt'];
                    String date = '';
                    try {
                      if (ts is Timestamp) date = ts.toDate().toLocal().toString();
                    } catch (_) {}
                    return ListTile(
                      dense: MediaQuery.of(context).size.width < 360,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.payments_outlined),
                      title: Text('R ${amount.toStringAsFixed(2)}  •  ${status.toUpperCase()}'),
                      subtitle: Text([if (date.isNotEmpty) date, if (ref.isNotEmpty) 'Ref: $ref'].join('  \u2022  ')),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
