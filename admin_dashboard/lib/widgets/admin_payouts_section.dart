import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

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
    await _loadNextPage();
  }

  Query<Map<String, dynamic>> _baseQuery() {
    Query<Map<String, dynamic>> q = _firestore
        .collection('payouts')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);
    if (_statusFilter != 'all') {
      q = q.where('status', isEqualTo: _statusFilter);
    }
    return q;
  }

  Future<void> _loadNextPage() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      Query<Map<String, dynamic>> q = _baseQuery();
      if (_lastDoc != null) {
        q = q.startAfterDocument(_lastDoc!);
      }
      final snap = await q.get();
      if (snap.docs.isNotEmpty) {
        _payoutDocs.addAll(snap.docs);
        _lastDoc = snap.docs.last;
        _pageCursors.add(_lastDoc!);
      }
      if (snap.docs.length < _pageSize) {
        _hasMore = false;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
          (m['reference']?.toString().toLowerCase().contains(s) ?? false);
    });
  }

  Future<void> _updateStatusDialog(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    String status = (data['status'] ?? 'requested').toString();
    String reference = (data['reference'] ?? '').toString();
    final allowed = const ['requested', 'processing', 'paid', 'failed', 'cancelled'];

    await showDialog(
      context: context,
      builder: (ctx) {
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
                onChanged: (v) => status = v ?? status,
                decoration: const InputDecoration(labelText: 'Status'),
              ),
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
                try {
                  await _functions
                      .httpsCallable('adminUpdatePayoutStatus')
                      .call({'payoutId': doc.id, 'status': status, 'reference': reference.trim().isEmpty ? null : reference.trim()});
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout updated')));
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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Payouts', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
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
          title: const Text('EFT Reconciliation'),
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
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by payoutId / sellerId / reference'),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: _buildTable(),
          ),
        ),
        const SizedBox(height: 8),
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
        final createdAt = m['createdAt'] is Timestamp ? (m['createdAt'] as Timestamp).toDate() : null;
        final orderCount = (m['orderIds'] is List) ? (m['orderIds'] as List).length : null;
        final entryCount = (m['entryIds'] is List) ? (m['entryIds'] as List).length : null;
        final reference = (m['reference'] ?? '').toString();

        return ListTile(
          title: Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SelectableText(d.id, style: const TextStyle(fontWeight: FontWeight.w600)),
            Chip(label: Text(status)),
            if (createdAt != null) Text(createdAt.toString()),
          ]),
          subtitle: Wrap(
            spacing: 16,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Seller: $sellerId'),
              Text('Gross: R$gross'),
              Text('Commission: R$commission'),
              Text('Net: R$amount'),
              if (orderCount != null) Text('Orders: $orderCount'),
              if (entryCount != null) Text('Entries: $entryCount'),
              if (reference.isNotEmpty) Text('Ref: $reference'),
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
            ],
          ),
        );
      },
    );
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



