import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReturnsRefundsSection extends StatefulWidget {
  @override
  State<ReturnsRefundsSection> createState() => _ReturnsRefundsSectionState();
}

class _ReturnsRefundsSectionState extends State<ReturnsRefundsSection> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  Set<String> _selectedIds = {};
  late List<DocumentSnapshot> _allDocs;

  Future<void> _updateStatus(DocumentSnapshot doc, String status) async {
    await doc.reference.update({'status': status});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request $status.')));
  }

  Future<void> _bulkUpdateStatus(List<DocumentSnapshot> docs, String status) async {
    for (final doc in docs) {
      await doc.reference.update({'status': status});
    }
    setState(() => _selectedIds.clear());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bulk status updated to $status.')));
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  void _showDetailsDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Return/Refund Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order: ${data['orderId'] ?? ''}'),
            Text('User: ${data['userEmail'] ?? data['userId'] ?? ''}'),
            Text('Reason: ${data['reason'] ?? ''}'),
            Text('Status: ${data['status'] ?? ''}'),
            if (data['details'] != null) ...[
              const SizedBox(height: 8),
              Text('Details:'),
              Text(data['details']),
            ],
          ],
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
                      labelText: 'Search by order, user, or reason',
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
                    DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
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
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Text('${_selectedIds.length} selected'),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.check_circle),
                      label: Text('Approve'),
                      onPressed: () async {
                        final docs = _allDocs.where((d) => _selectedIds.contains(d.id)).toList();
                        await _bulkUpdateStatus(docs, 'approved');
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: Icon(Icons.close),
                      label: Text('Reject'),
                      onPressed: () async {
                        final docs = _allDocs.where((d) => _selectedIds.contains(d.id)).toList();
                        await _bulkUpdateStatus(docs, 'rejected');
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: Icon(Icons.done_all),
                      label: Text('Resolve'),
                      onPressed: () async {
                        final docs = _allDocs.where((d) => _selectedIds.contains(d.id)).toList();
                        await _bulkUpdateStatus(docs, 'resolved');
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.clear),
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
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('returns').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  _allDocs = snapshot.data!.docs;
                  final filtered = _allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final order = (data['orderId'] ?? '').toString().toLowerCase();
                    final user = (data['userEmail'] ?? data['userId'] ?? '').toString().toLowerCase();
                    final reason = (data['reason'] ?? '').toString().toLowerCase();
                    final status = (data['status'] ?? '').toString().toLowerCase();
                    if (_searchQuery.isNotEmpty && !order.contains(_searchQuery) && !user.contains(_searchQuery) && !reason.contains(_searchQuery)) return false;
                    if (_statusFilter != 'all' && status != _statusFilter) return false;
                    return true;
                  }).toList();
                  if (filtered.isEmpty) return const Text('No return/refund requests found.');
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        DataColumn(
                          label: Checkbox(
                            value: filtered.isNotEmpty && _selectedIds.length == filtered.length,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedIds.addAll(filtered.map((d) => d.id));
                                } else {
                                  _selectedIds.removeWhere((id) => filtered.any((d) => d.id == id));
                                }
                              });
                            },
                          ),
                        ),
                        const DataColumn(label: Text('Order')),
                        const DataColumn(label: Text('User')),
                        const DataColumn(label: Text('Reason')),
                        const DataColumn(label: Text('Status')),
                        const DataColumn(label: Text('Actions')),
                      ],
                      rows: filtered.map((doc) {
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
                            DataCell(Text(data['orderId'] ?? '')),
                            DataCell(Text(data['userEmail'] ?? data['userId'] ?? '')),
                            DataCell(Text(data['reason'] ?? '')),
                            DataCell(Text(data['status'] ?? '')),
                            DataCell(Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.info_outline),
                                  tooltip: 'View Details',
                                  onPressed: () => _showDetailsDialog(doc),
                                ),
                                IconButton(
                                  icon: Icon(Icons.check),
                                  tooltip: 'Approve',
                                  onPressed: () => _updateStatus(doc, 'approved'),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close),
                                  tooltip: 'Reject',
                                  onPressed: () => _updateStatus(doc, 'rejected'),
                                ),
                                IconButton(
                                  icon: Icon(Icons.done_all),
                                  tooltip: 'Resolve',
                                  onPressed: () => _updateStatus(doc, 'resolved'),
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
            ),
          ],
        ),
      ),
    );
  }
} 