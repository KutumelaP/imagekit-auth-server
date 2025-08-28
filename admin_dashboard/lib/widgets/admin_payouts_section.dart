import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class AdminPayoutsSection extends StatefulWidget {
  const AdminPayoutsSection({super.key});

  @override
  State<AdminPayoutsSection> createState() => _AdminPayoutsSectionState();
}

class _AdminPayoutsSectionState extends State<AdminPayoutsSection> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _payoutDocs = [];
  final List<DocumentSnapshot> _pageCursors = [];
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _loading = false;

  String _statusFilter = 'requested'; // requested|processing|paid|failed|cancelled|all
  String _search = '';
  
  // Cache for seller emails to avoid repeated API calls
  final Map<String, String> _sellerEmails = {};

  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _payoutDocs.clear();
      _pageCursors.clear();
      _lastDoc = null;
      _hasMore = true;
    });
    await _loadNextPage(skipLoadingCheck: true);  // Skip the loading check
  }

  Query<Map<String, dynamic>> _baseQuery() {
    Query<Map<String, dynamic>> q = _firestore
        .collection('payouts')
        .orderBy(FieldPath.documentId, descending: true)  // Use document ID to avoid index issues
        .limit(_pageSize);
    if (_statusFilter != 'all') {
      q = q.where('status', isEqualTo: _statusFilter);
    }
    return q;
  }

  Future<void> _loadNextPage({bool skipLoadingCheck = false}) async {
    if (!skipLoadingCheck && (_loading || !_hasMore)) return;
    
    setState(() => _loading = true);
    
    try {
      // Add timeout to prevent hanging
      await _performLoad().timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw TimeoutException('Payout loading timed out after 45 seconds');
        },
      );
    } catch (e) {
      print('Error loading payouts: $e');
      _hasMore = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load payouts: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _performLoad() async {
    try {
      // First check if collection exists and has any documents
      final collectionCheck = await _firestore
          .collection('payouts')
          .limit(1)
          .get();
      
      if (collectionCheck.docs.isEmpty) {
        // No payouts exist - this is fine, not an error
        print('No payouts found in collection');
        _hasMore = false;
        return;
      }
      
      // Build the query
      Query<Map<String, dynamic>> q = _baseQuery();
      if (_lastDoc != null) {
        q = q.startAfterDocument(_lastDoc!);
      }
      
      // Execute the query
      final snap = await q.get();
      
      if (snap.docs.isNotEmpty) {
        _payoutDocs.addAll(snap.docs);
        _lastDoc = snap.docs.last;
        _pageCursors.add(_lastDoc!);
        print('Loaded ${snap.docs.length} payouts');
        
        // Fetch seller emails for new payouts
        await _fetchSellerEmails(snap.docs);
      }
      
      if (snap.docs.length < _pageSize) {
        _hasMore = false;
      }
      
    } catch (e) {
      print('Database query error: $e');
      rethrow; // Let the outer catch handle it
    }
  }

  Future<void> _fetchSellerEmails(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    try {
      // Extract unique seller IDs from the new payouts
      final sellerIds = <String>{};
      for (final doc in docs) {
        final sellerId = doc.data()['sellerId']?.toString();
        if (sellerId != null && sellerId.isNotEmpty && !_sellerEmails.containsKey(sellerId)) {
          sellerIds.add(sellerId);
        }
      }
      
      if (sellerIds.isEmpty) return;
      
      // Fetch emails in batches
      final batchSize = 10;
      final allIds = sellerIds.toList();
      
      for (int i = 0; i < allIds.length; i += batchSize) {
        final batch = allIds.skip(i).take(batchSize).toList();
        try {
          final result = await _functions
              .httpsCallable('getSellerEmailsForPayouts')
              .call({'sellerIds': batch});
          
          final emails = Map<String, String>.from(result.data ?? {});
          _sellerEmails.addAll(emails);
        } catch (e) {
          print('Error fetching seller emails for batch: $e');
        }
      }
      
      // Trigger UI update to show emails
      if (mounted) setState(() {});
      
    } catch (e) {
      print('Error fetching seller emails: $e');
    }
  }

  Future<void> _refresh() async {
    await _loadFirstPage();
  }

  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> get _filteredRows {
    if (_search.trim().isEmpty) return _payoutDocs;
    final s = _search.trim().toLowerCase();
         return _payoutDocs.where((d) {
       final m = d.data();
       return d.id.toLowerCase().contains(s) ||
           (m['sellerId']?.toString().toLowerCase().contains(s) ?? false) ||
           (m['sellerEmail']?.toString().toLowerCase().contains(s) ?? false) ||
           (m['reference']?.toString().toLowerCase().contains(s) ?? false);
     });
  }

  Future<void> _updateStatusDialog(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    String status = (data['status'] ?? 'requested').toString();
    String reference = (data['reference'] ?? '').toString();
    String failureReason = (data['failureReason'] ?? '').toString();
    final allowed = const ['requested', 'processing', 'paid', 'failed', 'cancelled'];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Update Payout Status'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: status,
                    items: allowed
                        .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      setDialogState(() => status = v ?? status);
                    },
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                  const SizedBox(height: 8),
                  // Failure reason field - only show when status is 'failed'
                  if (status == 'failed') ...[
                    DropdownButtonFormField<String>(
                      value: failureReason.isEmpty ? null : failureReason,
                      items: const [
                        DropdownMenuItem(value: 'bank_account_closed', child: Text('Bank account closed')),
                        DropdownMenuItem(value: 'invalid_account_number', child: Text('Invalid account number')),
                        DropdownMenuItem(value: 'insufficient_funds', child: Text('Insufficient funds')),
                        DropdownMenuItem(value: 'bank_rejected_compliance', child: Text('Bank rejected (compliance)')),
                        DropdownMenuItem(value: 'expired_payout_request', child: Text('Expired payout request')),
                        DropdownMenuItem(value: 'wrong_account_details', child: Text('Wrong account details')),
                        DropdownMenuItem(value: 'technical_error', child: Text('Technical error')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) {
                        setDialogState(() => failureReason = v ?? '');
                      },
                      decoration: const InputDecoration(
                        labelText: 'Failure Reason *',
                        helperText: 'Required when marking as failed',
                      ),
                      validator: (value) {
                        if (status == 'failed' && (value == null || value.isEmpty)) {
                          return 'Please select a failure reason';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    // Additional notes field for failure
                    TextFormField(
                      initialValue: data['failureNotes'] ?? '',
                      onChanged: (v) => data['failureNotes'] = v,
                      decoration: const InputDecoration(
                        labelText: 'Additional Notes (optional)',
                        hintText: 'Provide more details about the failure...',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    // Warning about reversal
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '⚠️ Marking as failed will automatically reverse the payout and return funds to your account.',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: reference,
                    onChanged: (v) => reference = v,
                    decoration: const InputDecoration(labelText: 'Payment Reference (optional)'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    // Validate failure reason if status is failed
                    if (status == 'failed' && failureReason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a failure reason'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    try {
                      // Prepare update data
                      final Map<String, dynamic> updateData = {
                        'payoutId': doc.id, 
                        'status': status, 
                        'reference': reference.trim().isEmpty ? null : reference.trim()
                      };

                      // Add failure details if status is failed
                      if (status == 'failed') {
                        updateData['failureReason'] = failureReason;
                        updateData['failureNotes'] = data['failureNotes'] ?? '';
                        updateData['failedAt'] = FieldValue.serverTimestamp();
                      }

                      await _functions
                          .httpsCallable('adminUpdatePayoutStatus')
                          .call(updateData);
                      
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(status == 'failed' 
                              ? 'Payout marked as failed and funds reversed' 
                              : 'Payout updated'),
                            backgroundColor: status == 'failed' ? Colors.orange : Colors.green,
                          ),
                        );
                        _refresh();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<HttpsCallableResult?>(
          future: (() async {
            try {
              return await _functions.httpsCallable('getPayoutProviderStatus').call(<String, dynamic>{});
            } catch (_) {
              return null;
            }
          })(),
          builder: (context, snap) {
            final Map<String, dynamic> data = (snap.data?.data is Map) ? (snap.data!.data as Map).cast<String, dynamic>() : {};
            final provider = (data['provider'] ?? 'payfast').toString();
            final live = data['live'] == true;
            final hasKeys = (data['effective']?['hasMerchantId'] == true) && (data['effective']?['hasMerchantKey'] == true);
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.account_balance, color: Colors.green),
                const SizedBox(width: 8),
                Text('Payout Provider: ${provider.toUpperCase()} • ${live ? 'LIVE' : 'SANDBOX'} • ${hasKeys ? 'Configured' : 'Missing keys'}'),
              ]),
            );
          },
        ),
        const SizedBox(height: 16),
        // Webhook URL helper
        Builder(builder: (context) {
          const webhookUrl = 'https://us-central1-marketplace-8d6bd.cloudfunctions.net/payfastPayoutWebhook';
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.indigo.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link, color: Colors.indigo),
                const SizedBox(width: 8),
                const Text('PayFast Payout Webhook:'),
                const SizedBox(width: 8),
                Expanded(child: SelectableText(webhookUrl, style: const TextStyle(fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(const ClipboardData(text: webhookUrl));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Webhook URL copied')));
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
        // Financial Flow Overview
        _buildFinancialFlowHeader(),
        const SizedBox(height: 24),
                 Row(
           children: [
             Text('Payouts', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
             const SizedBox(width: 16),
             // Status summary chips
             _buildStatusSummaryChips(),
             const Spacer(),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  final res = await _functions.httpsCallable('exportNedbankCsv').call(<String, dynamic>{});
                  final data = res.data ?? {};
                  final csv = (data['csv'] ?? '') as String;
                  if (csv.isEmpty) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No payouts to export')));
                    return;
                  }
                  // Show dialog with CSV and copy button
                  if (!mounted) return;
                  await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Nedbank CSV Export'),
                      content: SizedBox(
                        width: 700,
                        child: SelectableText(csv),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: csv));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copied to clipboard')));
                            }
                          },
                          child: const Text('Copy'),
                        ),
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                      ],
                    ),
                  );
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
                }
              },
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export Nedbank CSV'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () async {
                try {
                  final res = await _functions.httpsCallable('createPayoutBatch').call({});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Batch created: ${res.data?['created'] ?? 0} payouts')));
                    _refresh();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Batch failed: $e')));
                  }
                }
              },
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('Approve all eligible'),
            ),
            const SizedBox(width: 8),
            IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 16),
                 ExpansionTile(
           initiallyExpanded: false,
           leading: const Icon(Icons.attach_file),
           title: const Text('Bank CSV Reconciliation'),
           childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
           children: [
            Text('Paste bank CSV (must contain reference and amount columns):', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            _CsvReconcileForm(functions: _functions, onDone: _refresh),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: 'requested', child: Text('Requested')),
                  DropdownMenuItem(value: 'processing', child: Text('Processing')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'failed', child: Text('Failed')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                  DropdownMenuItem(value: 'all', child: Text('All')),
                ],
                onChanged: (v) {
                  setState(() => _statusFilter = v ?? 'requested');
                  _loadFirstPage();
                },
                decoration: const InputDecoration(labelText: 'Status'),
              ),
            ),
            const SizedBox(width: 16),
                           Expanded(
                 child: TextField(
                   decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by payoutId / sellerId / email / reference'),
                   onChanged: (v) => setState(() => _search = v),
                 ),
               ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool showFooter = constraints.maxHeight > 120;
            return Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: _buildTable(),
                ),
                const SizedBox(height: 8),
                if (showFooter)
                  Row(
                    children: [
                      Text(_loading ? 'Loading…' : _hasMore ? 'More available' : 'End of list', style: Theme.of(context).textTheme.bodySmall),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _hasMore && !_loading ? _loadNextPage : null,
                        icon: const Icon(Icons.expand_more),
                        label: const Text('Load more'),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    ));
  }

  Widget _buildTable() {
    final rows = _filteredRows.toList();
    if (rows.isEmpty && _loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
    if (rows.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No payouts found')));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final d = rows[i];
        final m = d.data();
        final status = (m['status'] ?? '').toString();
        final amount = (m['amount'] ?? 0).toString();
        final gross = (m['gross'] ?? 0).toString();
        final commission = (m['commission'] ?? 0).toString();
                 final sellerId = (m['sellerId'] ?? '').toString();
         final sellerEmail = _sellerEmails[sellerId] ?? ''; // Get seller email from cache
         final createdAt = m['createdAt'] is Timestamp ? (m['createdAt'] as Timestamp).toDate() : null;
         final orderCount = (m['orderIds'] is List) ? (m['orderIds'] as List).length : null;
         final entryCount = (m['entryIds'] is List) ? (m['entryIds'] as List).length : null;
         final reference = (m['reference'] ?? '').toString();
         final failureReason = (m['failureReason'] ?? '').toString();
         final failureNotes = (m['failureNotes'] ?? '').toString();

                 return ListTile(
           title: Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
             SelectableText(d.id, style: const TextStyle(fontWeight: FontWeight.w600)),
             Tooltip(
               message: status == 'failed' && failureNotes.isNotEmpty 
                 ? 'Failure Notes: $failureNotes' 
                 : 'Status: $status',
               child: Chip(
                 label: Text(status),
                 backgroundColor: status == 'failed' ? Colors.red.shade100 : null,
                 labelStyle: TextStyle(
                   color: status == 'failed' ? Colors.red.shade800 : null,
                   fontWeight: status == 'failed' ? FontWeight.w600 : null,
                 ),
               ),
             ),
             if (createdAt != null) Text(
               _formatDate(createdAt),
               style: TextStyle(
                 color: Colors.grey.shade600,
                 fontSize: 12,
               ),
             ),
           ]),
          subtitle: Wrap(
            spacing: 16,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
                             Text('Seller: ${sellerEmail.isNotEmpty ? sellerEmail : sellerId}'),
              Text('Gross: R$gross'),
              Text('Commission: R$commission'),
              Text('Net: R$amount'),
                             if (orderCount != null) Text('Orders: $orderCount'),
               if (entryCount != null) Text('Entries: $entryCount'),
               if (reference.isNotEmpty) Text('Ref: $reference'),
               if (status == 'failed' && failureReason.isNotEmpty) 
                 Text('Failed: ${_getFailureReasonLabel(failureReason)}', 
                   style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Update status',
                onPressed: () => _updateStatusDialog(d),
                icon: const Icon(Icons.edit),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Send to PayFast',
                onPressed: () async {
                  try {
                    await _functions.httpsCallable('sendPayoutViaPayfast').call({'payoutId': d.id});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent to PayFast')));
                      _refresh();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e')));
                    }
                  }
                },
                icon: const Icon(Icons.flash_on),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFinancialFlowHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.indigo.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                'Financial Flow Overview',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.blue.shade600),
                onPressed: () {
                  // Refresh financial data - could add StreamBuilder later
                  setState(() {});
                },
                tooltip: 'Refresh Financial Data',
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, double>>(
            future: _getFinancialSummary(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              final data = snapshot.data ?? {};
              final totalGross = data['totalGross'] ?? 0.0;
              final totalCommission = data['totalCommission'] ?? 0.0;
              final totalNet = data['totalNet'] ?? 0.0;
              final pendingPayouts = data['pendingPayouts'] ?? 0.0;
              final outstandingReceivables = data['outstandingReceivables'] ?? 0.0;
              
              return Row(
                children: [
                  Expanded(
                    child: _buildFinancialCard(
                      'Total Gross Revenue',
                      'R${totalGross.toStringAsFixed(2)}',
                      Icons.trending_up,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFinancialCard(
                      'Platform Commission',
                      'R${totalCommission.toStringAsFixed(2)}',
                      Icons.business_center,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFinancialCard(
                      'Seller Net Payouts',
                      'R${totalNet.toStringAsFixed(2)}',
                      Icons.account_balance_wallet,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFinancialCard(
                      'Pending Payouts',
                      'R${pendingPayouts.toStringAsFixed(2)}',
                      Icons.schedule,
                      Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFinancialCard(
                      'Outstanding Receivables',
                      'R${outstandingReceivables.toStringAsFixed(2)}',
                      Icons.receipt_long,
                      Colors.red,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialCard(String title, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildStatusSummaryChips() {
    final statusCounts = <String, int>{};
    for (final doc in _payoutDocs) {
      final status = (doc.data()['status'] ?? 'unknown').toString();
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (statusCounts['requested'] != null && statusCounts['requested']! > 0)
          Chip(
            label: Text('${statusCounts['requested']} Requested'),
            backgroundColor: Colors.blue.shade100,
            labelStyle: TextStyle(color: Colors.blue.shade800),
          ),
        if (statusCounts['processing'] != null && statusCounts['processing']! > 0)
          Chip(
            label: Text('${statusCounts['processing']} Processing'),
            backgroundColor: Colors.orange.shade100,
            labelStyle: TextStyle(color: Colors.orange.shade800),
          ),
        if (statusCounts['paid'] != null && statusCounts['paid']! > 0)
          Chip(
            label: Text('${statusCounts['paid']} Paid'),
            backgroundColor: Colors.green.shade100,
            labelStyle: TextStyle(color: Colors.green.shade800),
          ),
        if (statusCounts['failed'] != null && statusCounts['failed']! > 0)
          Chip(
            label: Text('${statusCounts['failed']} Failed'),
            backgroundColor: Colors.red.shade100,
            labelStyle: TextStyle(color: Colors.red.shade800),
          ),
        if (statusCounts['cancelled'] != null && statusCounts['cancelled']! > 0)
          Chip(
            label: Text('${statusCounts['cancelled']} Cancelled'),
            backgroundColor: Colors.grey.shade100,
            labelStyle: TextStyle(color: Colors.grey.shade800),
          ),
      ],
    );
  }

  Future<Map<String, double>> _getFinancialSummary() async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      
      // Get payouts from last 30 days for summary
      final payoutsQuery = await _firestore
          .collection('payouts')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      
      double totalGross = 0.0;
      double totalCommission = 0.0;
      double totalNet = 0.0;
      double pendingPayouts = 0.0;
      
      for (final doc in payoutsQuery.docs) {
        final data = doc.data();
        final gross = (data['gross'] as num?)?.toDouble() ?? 0.0;
        final commission = (data['commission'] as num?)?.toDouble() ?? 0.0;
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final status = data['status'] as String? ?? '';
        
        totalGross += gross;
        totalCommission += commission;
        totalNet += amount;
        
        if (status == 'requested' || status == 'processing') {
          pendingPayouts += amount;
        }
      }
      
      // Get outstanding receivables (COD orders not yet collected)
      final codOrdersQuery = await _firestore
          .collection('orders')
          .where('paymentMethod', isEqualTo: 'cod')
          .where('status', whereIn: ['confirmed', 'processing', 'shipped'])
          .get();
      
      double outstandingReceivables = 0.0;
      for (final doc in codOrdersQuery.docs) {
        final data = doc.data();
        final total = (data['total'] as num?)?.toDouble() ?? 0.0;
        outstandingReceivables += total;
      }
      
      return {
        'totalGross': totalGross,
        'totalCommission': totalCommission,
        'totalNet': totalNet,
        'pendingPayouts': pendingPayouts,
        'outstandingReceivables': outstandingReceivables,
      };
    } catch (e) {
      debugPrint('Error getting financial summary: $e');
      return {};
    }
  }


}

class _CsvReconcileForm extends StatefulWidget {
  final FirebaseFunctions functions;
  final VoidCallback onDone;
  const _CsvReconcileForm({required this.functions, required this.onDone});
  @override
  State<_CsvReconcileForm> createState() => _CsvReconcileFormState();
}

class _CsvReconcileFormState extends State<_CsvReconcileForm> {
  final TextEditingController _csvController = TextEditingController();
  bool _loading = false;
  List<dynamic> _matched = [];
  List<dynamic> _unmatched = [];

  Future<void> _reconcile() async {
    if (_loading) return;
    setState(() { _loading = true; _matched = []; _unmatched = []; });
    try {
      final res = await widget.functions.httpsCallable('reconcileEftCsv').call({ 'csv': _csvController.text, 'delimiter': ',' });
      final data = res.data ?? {};
      setState(() {
        _matched = List.from(data['matched'] ?? []);
        _unmatched = List.from(data['unmatched'] ?? []);
      });
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reconcile failed: $e')));
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _markSinglePaid(Map<String, dynamic> row) async {
    final orderId = (row['orderId'] ?? row['reference'] ?? '').toString();
    final amount = double.tryParse((row['amount'] ?? row['expected'] ?? '0').toString()) ?? 0;
    if (orderId.isEmpty || amount <= 0) return;
    try {
      await widget.functions.httpsCallable('adminMarkEftPaid').call({ 'orderId': orderId, 'amount': amount, 'override': true });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order marked paid')));
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mark paid failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _csvController,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Paste CSV content here...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.icon(onPressed: _loading ? null : _reconcile, icon: const Icon(Icons.play_arrow), label: const Text('Reconcile')),
            const SizedBox(width: 8),
            if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 8),
        if (_matched.isNotEmpty) Text('Matched: ${_matched.length}', style: Theme.of(context).textTheme.labelMedium),
        if (_matched.isNotEmpty) Container(
          constraints: const BoxConstraints(maxHeight: 180),
          child: ListView.builder(
            itemCount: _matched.length,
            itemBuilder: (_, i) {
              final m = _matched[i] as Map<String, dynamic>;
              return ListTile(
                dense: true,
                title: Text('Order ${m['orderId'] ?? ''} R${m['amount'] ?? ''}'),
                subtitle: Text(m['note'] ?? ''),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        if (_unmatched.isNotEmpty) Text('Exceptions: ${_unmatched.length}', style: Theme.of(context).textTheme.labelMedium),
        if (_unmatched.isNotEmpty) Container(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.builder(
            itemCount: _unmatched.length,
            itemBuilder: (_, i) {
              final u = _unmatched[i] as Map<String, dynamic>;
              return ListTile(
                dense: true,
                title: Text('Ref ${u['orderId'] ?? u['reference'] ?? ''} R${u['amount'] ?? ''}'),
                subtitle: Text(u['reason'] ?? u['error'] ?? ''),
                trailing: TextButton(onPressed: () => _markSinglePaid(u), child: const Text('Mark paid')),
              );
            },
          ),
        ),
      ],
    );
  }
}



