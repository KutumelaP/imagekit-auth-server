import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import '../theme/app_theme.dart';
import '../services/receipt_service.dart';
import '../services/payfast_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SellerPayoutsScreen extends StatefulWidget {
  const SellerPayoutsScreen({super.key});

  @override
  State<SellerPayoutsScreen> createState() => _SellerPayoutsScreenState();
}

class _SellerPayoutsScreenState extends State<SellerPayoutsScreen> {
  bool _loading = false;
  bool _requesting = false;
  bool _generatingStatement = false;
  bool _exportingCsv = false;
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

  // Statement date range
  DateTime _rangeFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _rangeTo = DateTime.now();

  // History pagination
  static const int _historyPageSize = 20;
  DocumentSnapshot? _lastUserPayoutDoc;
  DocumentSnapshot? _lastMainPayoutDoc;
  bool _hasMoreUser = true;
  bool _hasMoreMain = true;
  bool _loadingHistory = false;
  final Set<String> _historySeenIds = <String>{};

  Future<void> _initialize() async {
    await _loadPersistedRange();
    await _refreshAll();
  }

  

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadBalance(),
      _loadHistory(),
      _loadOutstandingFees(),
    ]);
  }

  Future<void> _loadPersistedRange() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fromMs = prefs.getInt('statement_from_ms');
      final toMs = prefs.getInt('statement_to_ms');
      if (fromMs != null && toMs != null) {
        setState(() {
          _rangeFrom = DateTime.fromMillisecondsSinceEpoch(fromMs);
          _rangeTo = DateTime.fromMillisecondsSinceEpoch(toMs);
        });
      }
    } catch (_) {}
  }

  Future<void> _persistRange(DateTime from, DateTime to) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('statement_from_ms', from.millisecondsSinceEpoch);
      await prefs.setInt('statement_to_ms', to.millisecondsSinceEpoch);
    } catch (_) {}
  }

  String _formatCurrency(double value) {
    try {
      final locale = Localizations.localeOf(context).toString();
      final fmt = NumberFormat.currency(locale: locale, symbol: 'R ', decimalDigits: 2);
      return fmt.format(value);
    } catch (_) {
      return 'R ${value.toStringAsFixed(2)}';
    }
  }

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  Future<File> _saveTempFile(Uint8List bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _loadBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      setState(() { _loading = true; });
      final functions = FirebaseFunctions.instance;
      final res = await functions.httpsCallable('getSellerAvailableBalance').call({ 'userId': user.uid });
      final data = Map<String, dynamic>.from(res.data as Map);
      
      // Minimal logging in production — remove verbose debug
      
      setState(() {
        _gross = (data['gross'] ?? 0).toDouble();
        _commission = (data['commission'] ?? 0).toDouble();
        _net = (data['net'] ?? 0).toDouble();
        _min = (data['minPayoutAmount'] ?? 0).toDouble();
        _commissionPct = ((data['commissionPct'] ?? 0) as num).toDouble();
        _codWallet = Map<String, dynamic>.from(data['codWallet'] ?? {});
        
        // Minimal logging in production
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
    
    print('🔍 DEBUG: Starting payout history load for user: ${user.uid}');
    
    try {
      // Reset pagination
      setState(() {
        _history.clear();
        _historySeenIds.clear();
        _lastUserPayoutDoc = null;
        _lastMainPayoutDoc = null;
        _hasMoreUser = true;
        _hasMoreMain = true;
      });

      await _loadNextHistoryPage();
      
      // Debug logging
      print('🔍 DEBUG: Payout History Loading Summary:');
      print('  Final history count: ${_history.length}');
      print('  Has more user: $_hasMoreUser  •  Has more main: $_hasMoreMain');
      if (_history.isNotEmpty) {
        print('  First payout: ${_history.first}');
      } else {
        print('  ⚠️ No payouts found in either collection!');
        print('  🔍 This could mean:');
        print('    1. No payouts have been requested yet');
        print('    2. Payouts are stored in a different collection');
        print('    3. Firebase permissions issue');
        print('    4. Query error due to missing indexes');
      }
    } catch (e) {
      print('❌ Error loading payout history: $e');
      print('🔍 DEBUG: Error details: ${e.toString()}');
      
      // Try a simpler query to check if collection exists
      try {
        print('🔍 DEBUG: Testing if payouts collection exists...');
        final testQuery = await FirebaseFirestore.instance
            .collection('payouts')
            .limit(1)
            .get();
        print('🔍 DEBUG: Payouts collection exists with ${testQuery.docs.length} documents');
      } catch (testError) {
        print('❌ ERROR: Cannot access payouts collection: $testError');
      }
    }
  }

  Future<void> _loadNextHistoryPage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_loadingHistory) return;
    if (!_hasMoreUser && !_hasMoreMain) return;
    setState(() { _loadingHistory = true; });
    try {
      // Build queries
      Query<Map<String, dynamic>> userQuery = FirebaseFirestore.instance
          .collection('users').doc(user.uid)
          .collection('payouts')
          .orderBy('createdAt', descending: true)
          .limit(_historyPageSize);
      if (_lastUserPayoutDoc != null) {
        userQuery = userQuery.startAfterDocument(_lastUserPayoutDoc!);
      }

      Query<Map<String, dynamic>> mainQuery = FirebaseFirestore.instance
          .collection('payouts')
          .where('sellerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(_historyPageSize);
      if (_lastMainPayoutDoc != null) {
        mainQuery = mainQuery.startAfterDocument(_lastMainPayoutDoc!);
      }

      final userPayouts = _hasMoreUser ? await userQuery.get() : null;
      final mainPayouts = _hasMoreMain ? await mainQuery.get() : null;

      // Track cursors and hasMore flags
      if (userPayouts != null) {
        if (userPayouts.docs.isNotEmpty) {
          _lastUserPayoutDoc = userPayouts.docs.last;
        }
        if (userPayouts.docs.length < _historyPageSize) _hasMoreUser = false;
      for (final doc in userPayouts.docs) {
          if (_historySeenIds.add(doc.id)) {
            _history.add({'id': doc.id, ...doc.data()});
          }
        }
      }

      if (mainPayouts != null) {
        if (mainPayouts.docs.isNotEmpty) {
          _lastMainPayoutDoc = mainPayouts.docs.last;
        }
        if (mainPayouts.docs.length < _historyPageSize) _hasMoreMain = false;
      for (final doc in mainPayouts.docs) {
          if (_historySeenIds.add(doc.id)) {
            _history.add({'id': doc.id, ...doc.data()});
          }
        }
      }

      // Sort combined results
      _history.sort((a, b) {
        final aDate = a['createdAt'];
        final bDate = b['createdAt'];
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        try { return (bDate as Timestamp).compareTo(aDate as Timestamp); } catch (_) { return 0; }
      });

      setState(() {});
    } catch (e) {
      print('❌ Error loading next history page: $e');
    } finally {
      if (mounted) setState(() { _loadingHistory = false; });
    }
  }

  Future<void> _pickRangeAndGenerateStatement() async {
    // Quick presets dialog
    final preset = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.calendar_view_week),
              title: const Text('Last 7 days'),
              onTap: () => Navigator.pop(ctx, '7'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_month),
              title: const Text('Last 30 days'),
              onTap: () => Navigator.pop(ctx, '30'),
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Custom range...'),
              onTap: () => Navigator.pop(ctx, 'custom'),
            ),
          ]),
        );
      },
    );

    DateTime from = _rangeFrom;
    DateTime to = _rangeTo;
    if (preset == '7') {
      from = DateTime.now().subtract(const Duration(days: 7));
      to = DateTime.now();
    } else if (preset == '30') {
      from = DateTime.now().subtract(const Duration(days: 30));
      to = DateTime.now();
    } else if (preset == 'custom') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
        lastDate: DateTime.now().add(const Duration(days: 1)),
        initialDateRange: DateTimeRange(start: _rangeFrom, end: _rangeTo),
      );
      if (picked != null) {
        from = picked.start;
        to = picked.end.add(const Duration(hours: 23, minutes: 59));
      }
    }

    setState(() { _rangeFrom = from; _rangeTo = to; });
    await _persistRange(from, to);
    setState(() { _generatingStatement = true; });
    await _generateStatement(from, to);
    if (mounted) setState(() { _generatingStatement = false; });
  }

  Future<void> _pickRangeAndPreviewStatement() async {
    await _pickRangeAndGenerateStatement(); // reuse range picker
    // After range is set, open preview
    await _openStatementPreview(_rangeFrom, _rangeTo);
  }

  Future<void> _openStatementPreview(DateTime from, DateTime to) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // Fetch seller profile
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final sellerName = userDoc.data()?['businessName'] ?? userDoc.data()?['name'] ?? 'Unknown Seller';

      // Fetch data
      final entriesSnap = await FirebaseFirestore.instance
          .collection('platform_receivables')
          .doc(user.uid)
          .collection('entries')
          .where('createdAt', isGreaterThanOrEqualTo: from)
          .where('createdAt', isLessThanOrEqualTo: to)
          .get();
      final payoutsSnap = await FirebaseFirestore.instance
          .collection('payouts')
          .where('sellerId', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: from)
          .where('createdAt', isLessThanOrEqualTo: to)
          .get();
      final moneyIn = entriesSnap.docs.map((d) => { ...d.data(), 'id': d.id }).toList();
      final moneyOut = payoutsSnap.docs.map((d) => { ...d.data(), 'id': d.id }).toList();

      final double windowIn = moneyIn.fold<double>(0.0, (p, e) {
        final gross = _asDouble(e['gross'] ?? e['amount']);
        final comm = _asDouble(e['commission']);
        final net = _asDouble(e['net']);
        final effective = net == 0.0 ? (gross - comm) : net;
        return p + effective;
      });
      final double windowOut = moneyOut.fold<double>(0.0, (p, e) => p + _asDouble(e['net'] ?? e['amount']));
      final startingBalance = (_net - windowIn + windowOut);

      // Build preview rows
      final totalFees = moneyIn.fold<double>(0.0, (p, e) => p + _asDouble(e['commission']));

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.visibility),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Statement Preview – $sellerName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${DateFormat('MMM dd, yyyy').format(from)} to ${DateFormat('MMM dd, yyyy').format(to)}', style: TextStyle(color: Colors.grey[700])),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kv('Opening Balance (before period)', _formatCurrency(startingBalance)),
                        _kv('Money In (sales)', _formatCurrency(windowIn + totalFees)),
                        _kv('Platform Fees', _formatCurrency(totalFees)),
                        _kv('Money Out (payouts)', _formatCurrency(windowOut)),
                        const Divider(),
                        _kv('Net Movement', _formatCurrency(windowIn - totalFees - windowOut)),
                        _kv('Ending Balance', _formatCurrency(startingBalance + windowIn - totalFees - windowOut)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _generateStatement(from, to);
                      },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Download PDF'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Preview failed: $e')));
    }
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(v),
        ],
      ),
    );
  }

  Future<void> _generateStatement(DateTime from, DateTime to) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // Fetch seller profile
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final sellerName = userDoc.data()?['businessName'] ?? userDoc.data()?['name'] ?? 'Unknown Seller';
      final sellerEmail = userDoc.data()?['email'] ?? '';
      final bankDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('payout').doc('bank').get();
      final bank = bankDoc.data();

      // Money In: receivable entries in period
      final entriesSnap = await FirebaseFirestore.instance
          .collection('platform_receivables')
          .doc(user.uid)
          .collection('entries')
          .where('createdAt', isGreaterThanOrEqualTo: from)
          .where('createdAt', isLessThanOrEqualTo: to)
          .get();

      final moneyIn = entriesSnap.docs.map((d) => {
        ...d.data(),
        'id': d.id,
      }).toList();

      // Money Out: payouts in period
      final payoutsSnap = await FirebaseFirestore.instance
            .collection('payouts')
          .where('sellerId', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: from)
          .where('createdAt', isLessThanOrEqualTo: to)
          .orderBy('createdAt', descending: true)
            .get();

      final moneyOut = payoutsSnap.docs.map((d) => {
        ...d.data(),
        'id': d.id,
      }).toList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating statement...')));
      }

      // Rough starting balance: current net - inflows + fees + outflows in window
      // If you have a true ledger, compute from it; this is a simple estimate.
      double startingBalance = _net;
      final double windowIn = moneyIn.fold<double>(0.0, (p, e) {
        final gross = _asDouble(e['gross'] ?? e['amount']);
        final comm = _asDouble(e['commission']);
        final net = _asDouble(e['net']);
        final effective = net == 0.0 ? (gross - comm) : net;
        return p + effective;
      });
      final double windowOut = moneyOut.fold<double>(0.0, (p, e) {
        final amt = _asDouble(e['net'] ?? e['amount']);
        return p + amt;
      });
      startingBalance = (_net - windowIn + windowOut).toDouble();

      final bytes = await ReceiptService.generateSellerStatement(
        sellerName: sellerName,
        sellerEmail: sellerEmail,
        from: from,
        to: to,
        moneyInEntries: moneyIn,
        moneyOutEntries: moneyOut,
        startingBalance: startingBalance,
        statementNumber: 'ST-${DateTime.now().millisecondsSinceEpoch}',
        bankDetails: bank,
        brandName: 'Food Marketplace',
      );

      if (bytes != null && mounted) {
        await Printing.layoutPdf(onLayout: (format) async => bytes);
        final filename = 'statement_${DateFormat('yyyy-MM-dd').format(from)}_to_${DateFormat('yyyy-MM-dd').format(to)}.pdf';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Statement ready: $filename')));
        try {
          await FirebaseAnalytics.instance.logEvent(name: 'statement_pdf_generated', parameters: {
            'from': from.toIso8601String(),
            'to': to.toIso8601String(),
            'count_in': moneyIn.length,
            'count_out': moneyOut.length,
          });
        } catch (_) {}
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate statement')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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

      // Cross-check with COD wallet commission owed (more accurate aggregate)
      final codCommissionOwed = (_codWallet['commissionOwed'] is num)
          ? (_codWallet['commissionOwed'] as num).toDouble()
          : double.tryParse('${_codWallet['commissionOwed']}') ?? 0.0;
      if (codCommissionOwed > outstandingAmount) {
        outstandingAmount = codCommissionOwed;
        if (outstandingType.isEmpty) outstandingType = 'commission';
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
                          _formatCurrency(_net),
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
                                _formatCurrency(_gross),
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
                                _formatCurrency(_commission),
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

                  const SizedBox(height: 8),

                  // Statement Buttons
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickRangeAndGenerateStatement,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.deepTeal,
                        side: BorderSide(color: AppTheme.deepTeal.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Semantics(
                        label: 'Generate PDF statement',
                        button: true,
                        child: const Icon(Icons.picture_as_pdf),
                      ),
                      label: Text(_generatingStatement
                          ? 'Preparing statement...'
                          : 'Download statement (choose range)'),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Preview Statement Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _pickRangeAndPreviewStatement();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.deepTeal,
                        side: BorderSide(color: AppTheme.deepTeal.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.visibility),
                      label: const Text('Preview statement (choose range)'),
                    ),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _exportingCsv ? null : () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) return;
                        try {
                          setState(() { _exportingCsv = true; });
                          final entriesSnap = await FirebaseFirestore.instance
                              .collection('platform_receivables')
                              .doc(user.uid)
                              .collection('entries')
                              .where('createdAt', isGreaterThanOrEqualTo: _rangeFrom)
                              .where('createdAt', isLessThanOrEqualTo: _rangeTo)
                              .get();
                          final payoutsSnap = await FirebaseFirestore.instance
                              .collection('payouts')
                              .where('sellerId', isEqualTo: user.uid)
                              .where('createdAt', isGreaterThanOrEqualTo: _rangeFrom)
                              .where('createdAt', isLessThanOrEqualTo: _rangeTo)
                              .get();
                          final moneyIn = entriesSnap.docs.map((d) => { ...d.data(), 'id': d.id }).toList();
                          final moneyOut = payoutsSnap.docs.map((d) => { ...d.data(), 'id': d.id }).toList();
                          final bytes = await ReceiptService.generateSellerStatementCsv(
                            sellerName: user.displayName ?? 'Seller',
                            from: _rangeFrom,
                            to: _rangeTo,
                            moneyInEntries: moneyIn,
                            moneyOutEntries: moneyOut,
                            startingBalance: _net, // best-effort
                          );
                          if (bytes != null) {
                            final tmp = await _saveTempFile(bytes, 'seller_statement_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv');
                            await Share.shareXFiles([XFile(tmp.path)], subject: 'Seller Statement CSV');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV exported: ${tmp.path.split('/').last}')));
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV error: $e')));
                          }
                        } finally {
                          if (mounted) setState(() { _exportingCsv = false; });
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.deepTeal,
                        side: BorderSide(color: AppTheme.deepTeal.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Semantics(
                        label: 'Export statement CSV',
                        button: true,
                        child: const Icon(Icons.table_view),
                      ),
                      label: const Text('Export CSV for selected range'),
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
                   if (_history.isNotEmpty) ...[
                     Container(
                       padding: const EdgeInsets.all(12),
                       decoration: BoxDecoration(
                         color: AppTheme.deepTeal.withOpacity(0.1),
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3)),
                       ),
                       child: Row(
                         children: [
                           Icon(Icons.receipt, color: AppTheme.deepTeal, size: 16),
                           const SizedBox(width: 8),
                           Expanded(
                             child: Text(
                               'Click the receipt icon 📄 to generate a PDF receipt for completed payouts',
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
                     const SizedBox(height: 12),
                   ],
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
                        child: Text('${_formatCurrency(amount)}  •  ${status.toUpperCase()}'),
                      ),
                                             trailing: (status == 'paid' || status == 'completed' || status == 'processing') ? Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           if (status != 'paid') 
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                               decoration: BoxDecoration(
                                 color: Colors.orange.shade100,
                                 borderRadius: BorderRadius.circular(8),
                                 border: Border.all(color: Colors.orange.shade300),
                               ),
                               child: Text(
                                 'Draft',
                                 style: TextStyle(
                                   fontSize: 10,
                                   color: Colors.orange.shade700,
                                   fontWeight: FontWeight.w500,
                                 ),
                               ),
                             ),
                           const SizedBox(width: 4),
                           IconButton(
                             icon: const Icon(Icons.receipt),
                             onPressed: () => _generateReceipt(p),
                             tooltip: 'Generate Receipt',
                           ),
                         ],
                       ) : null,
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [if (date.isNotEmpty) date, if (ref.isNotEmpty) 'Ref: $ref'].join('  \u2022  '),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          // Show money flow breakdown
                          if (p['gross'] != null && p['commission'] != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.deepTeal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.account_balance_wallet, color: AppTheme.deepTeal, size: 14),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'From buyers: R${(p['gross'] ?? 0).toStringAsFixed(2)} • Fees: R${(p['commission'] ?? 0).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: AppTheme.deepTeal,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                  const SizedBox(height: 8),
                  if (_loadingHistory) const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2))),
                  if (!_loadingHistory && (_hasMoreUser || _hasMoreMain)) Center(
                    child: OutlinedButton.icon(
                      onPressed: _loadNextHistoryPage,
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Load more'),
                    ),
                  ),
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
    // Initiate wallet top-up directly for outstanding fees using PayFast
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final double amount = _outstandingAmount > 0 ? _outstandingAmount : 50.0;
    // Use same creation flow as checkout top-up (server form redirect)
    PayFastService.createPayment(
      amount: amount.toStringAsFixed(2),
      itemName: 'Wallet Top-up: Outstanding Fees',
      itemDescription: 'Pay outstanding platform fees',
      customerEmail: user.email ?? 'user@example.com',
      customerFirstName: (user.displayName ?? 'User').split(' ').first,
      customerLastName: (user.displayName ?? '').split(' ').skip(1).join(' '),
      customerPhone: '0606304683',
      customString1: 'WALLET_${user.uid}',
      customString2: user.uid, // settle this seller's dues
      customString3: user.uid,
      customString4: 'wallet_topup',
    ).then((paymentResult) async {
      if (paymentResult['success'] == true) {
        try {
          final url = paymentResult['paymentUrl'] as String;
          final Map<String, dynamic> pd = Map<String, dynamic>.from(paymentResult['paymentData'] as Map);
          final qp = pd.map((k, v) => MapEntry(k, v.toString()));
          final redirect = Uri.parse(url).replace(queryParameters: qp).toString();
          await launchUrl(Uri.parse(redirect), webOnlyWindowName: '_self');
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment redirect failed: $e')));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment setup failed: ${paymentResult['error'] ?? 'Unknown error'}')),
          );
        }
      }
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

  Future<void> _generateReceipt(Map<String, dynamic> payoutData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get seller info
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final sellerName = userDoc.data()?['businessName'] ?? userDoc.data()?['name'] ?? 'Unknown Seller';
      final sellerEmail = userDoc.data()?['email'] ?? '';

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generating receipt...')),
        );
      }

      // Generate receipt
      final bytes = await ReceiptService.generatePayoutReceipt(
        payoutData: payoutData,
        sellerName: sellerName,
        sellerEmail: sellerEmail,
      );

      if (bytes != null && mounted) {
        // Open the PDF
        await Printing.layoutPdf(onLayout: (format) async => bytes);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt generated successfully!')),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate receipt')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating receipt: $e')),
        );
      }
    }
  }
}
