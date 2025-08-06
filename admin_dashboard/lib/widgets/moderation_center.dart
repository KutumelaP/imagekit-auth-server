import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ModerationCenter extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  const ModerationCenter({Key? key, required this.auth, required this.firestore}) : super(key: key);

  @override
  State<ModerationCenter> createState() => _ModerationCenterState();
}

class _ModerationCenterState extends State<ModerationCenter> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  Set<String> _selectedIds = {};
  late List<DocumentSnapshot> _allDocs;
  Map<String, Map<String, dynamic>> _recentlyRejectedReviews = {};

  Future<void> _approveReview(DocumentSnapshot doc) async {
    await doc.reference.update({'status': 'approved', 'flagged': false});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review approved.')));
  }

  Future<void> _rejectReview(DocumentSnapshot doc) async {
    final prevData = doc.data() as Map<String, dynamic>;
    await doc.reference.update({'status': 'rejected', 'flagged': false});
    _recentlyRejectedReviews[doc.id] = prevData;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Review rejected.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await doc.reference.set(prevData);
            _recentlyRejectedReviews.remove(doc.id);
            setState(() {});
          },
        ),
        duration: Duration(seconds: 5),
        onVisible: () {
          Future.delayed(Duration(seconds: 5), () {
            _recentlyRejectedReviews.remove(doc.id);
          });
        },
      ),
    );
    setState(() {});
  }

  Future<void> _bulkResolve(List<DocumentSnapshot> selectedDocs) async {
    for (final doc in selectedDocs) {
      await doc.reference.update({'flagged': false});
    }
    setState(() => _selectedIds.clear());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Flagged items resolved.')));
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  void _showDetailsDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Flagged Review Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${data['userEmail'] ?? data['userId'] ?? ''}'),
            Text('Product: ${data['productName'] ?? data['productId'] ?? ''}'),
            Text('Content: ${data['content'] ?? ''}'),
            Text('Status: ${data['status'] ?? ''}'),
            if (data['flagReason'] != null) Text('Reason: ${data['flagReason']}'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(Icons.receipt_long),
              label: Text('View Audit Log'),
              onPressed: () => _showReviewAuditLogDialog(doc.id),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close'))],
      ),
    );
  }

  void _showReviewAuditLogDialog(String reviewId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Review Audit Log'),
        content: SizedBox(
          width: 500,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('auditLogs')
                .where('details', isGreaterThanOrEqualTo: 'Review: $reviewId')
                .where('details', isLessThanOrEqualTo: 'Review: $reviewId\uf8ff')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Error loading audit log: \\${snapshot.error}', style: TextStyle(color: Colors.red));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text('No audit log entries for this review.');
              }
              return ListView.separated(
                shrinkWrap: true,
                itemCount: docs.length,
                separatorBuilder: (_, __) => Divider(),
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['action'] ?? ''),
                    subtitle: Text(data['details'] ?? ''),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(data['user'] ?? '', style: TextStyle(fontSize: 12)),
                        Text(
                          data['timestamp'] != null
                              ? (data['timestamp'] as Timestamp).toDate().toString()
                              : '',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Search by user, product, or content',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                ),
              ],
            ),
            if (_selectedIds.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: Row(
                  children: [
                    Text('${_selectedIds.length} selected'),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary),
                      label: Text('Resolve', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                      onPressed: () async {
                        final docs = _allDocs.where((d) => _selectedIds.contains(d.id)).toList();
                        await _bulkResolve(docs);
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      tooltip: 'Clear selection',
                      onPressed: _clearSelection,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Tip: You can scroll horizontally to see more columns.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontStyle: FontStyle.italic, fontSize: 13),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: widget.firestore.collection('reviews').where('flagged', isEqualTo: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                _allDocs = snapshot.data!.docs;
                final flagged = _allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final user = (data['userEmail'] ?? data['userId'] ?? '').toString().toLowerCase();
                  final product = (data['productName'] ?? data['productId'] ?? '').toString().toLowerCase();
                  final content = (data['content'] ?? '').toString().toLowerCase();
                  final status = (data['status'] ?? '').toString().toLowerCase();
                  if (_searchQuery.isNotEmpty && !user.contains(_searchQuery) && !product.contains(_searchQuery) && !content.contains(_searchQuery)) return false;
                  if (_statusFilter != 'all' && status != _statusFilter) return false;
                  return true;
                }).toList();
                if (flagged.isEmpty) return const Text('No flagged content found.');
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      DataColumn(
                        label: Checkbox(
                          value: flagged.isNotEmpty && _selectedIds.length == flagged.length,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedIds.addAll(flagged.map((d) => d.id));
                              } else {
                                _selectedIds.removeWhere((id) => flagged.any((d) => d.id == id));
                              }
                            });
                          },
                        ),
                      ),
                      const DataColumn(label: Text('User')),
                      const DataColumn(label: Text('Product')),
                      const DataColumn(label: Text('Content')),
                      const DataColumn(label: Text('Status')),
                      const DataColumn(label: Text('Actions')),
                    ],
                    rows: flagged.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DataRow(
                        selected: _selectedIds.contains(doc.id),
                        onSelectChanged: (selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedIds.add(doc.id);
                            } else {
                              _selectedIds.remove(doc.id);
                            }
                          });
                        },
                        cells: [
                          DataCell(
                            Checkbox(
                              value: _selectedIds.contains(doc.id),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedIds.add(doc.id);
                                  } else {
                                    _selectedIds.remove(doc.id);
                                  }
                                });
                              },
                            ),
                          ),
                          DataCell(Text(data['userEmail'] ?? data['userId'] ?? '')),
                          DataCell(Text(data['productName'] ?? data['productId'] ?? '')),
                          DataCell(Text(data['content'] ?? '')),
                          DataCell(Text(data['status'] ?? '')),
                          DataCell(Row(
                            children: [
                              Tooltip(
                                message: 'View details',
                                child: IconButton(
                                  icon: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  tooltip: 'View Details',
                                  onPressed: () => _showDetailsDialog(doc),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.check, color: Theme.of(context).colorScheme.onPrimary),
                                tooltip: 'Approve',
                                onPressed: () => _approveReview(doc),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onError),
                                tooltip: 'Reject',
                                onPressed: () => _rejectReview(doc),
                              ),
                            ],
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 