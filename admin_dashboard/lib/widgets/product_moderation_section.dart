import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModerationSection extends StatefulWidget {
  @override
  State<ProductModerationSection> createState() => _ProductModerationSectionState();
}

class _ProductModerationSectionState extends State<ProductModerationSection> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  Set<String> _selectedIds = {};
  late List<DocumentSnapshot> _allDocs;

  Future<void> _approveProduct(DocumentSnapshot doc) async {
    await doc.reference.update({'status': 'approved', 'flagged': false});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product approved.')));
  }

  Future<void> _rejectProduct(DocumentSnapshot doc) async {
    await doc.reference.update({'status': 'rejected', 'flagged': false});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product rejected.')));
  }

  Future<void> _bulkResolve(List<DocumentSnapshot> selectedDocs) async {
    for (final doc in selectedDocs) {
      await doc.reference.update({'flagged': false});
    }
    setState(() => _selectedIds.clear());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Flagged products resolved.')));
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  void _showDetailsDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Product Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${data['name'] ?? ''}'),
            Text('Seller: ${data['sellerName'] ?? data['sellerId'] ?? ''}'),
            Text('Category: ${data['category'] ?? ''}'),
            Text('Status: ${data['status'] ?? ''}'),
            if (data['flagReason'] != null) Text('Reason: ${data['flagReason']}'),
            if (data['description'] != null) ...[
              const SizedBox(height: 8),
              Text('Description:'),
              Text(data['description']),
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
                      labelText: 'Search by name, seller, or category',
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
                    DropdownMenuItem(value: 'flagged', child: Text('Flagged')),
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
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Text('${_selectedIds.length} selected'),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.check_circle),
                      label: Text('Resolve'),
                      onPressed: () async {
                        final docs = _allDocs.where((d) => _selectedIds.contains(d.id)).toList();
                        await _bulkResolve(docs);
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
                stream: FirebaseFirestore.instance.collection('products').where('flagged', isEqualTo: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  _allDocs = snapshot.data!.docs;
                  final flagged = _allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final seller = (data['sellerName'] ?? data['sellerId'] ?? '').toString().toLowerCase();
                    final category = (data['category'] ?? '').toString().toLowerCase();
                    final status = (data['status'] ?? '').toString().toLowerCase();
                    if (_searchQuery.isNotEmpty && !name.contains(_searchQuery) && !seller.contains(_searchQuery) && !category.contains(_searchQuery)) return false;
                    if (_statusFilter == 'pending' && status != 'pending') return false;
                    if (_statusFilter == 'flagged' && data['flagged'] != true) return false;
                    return true;
                  }).toList();
                  if (flagged.isEmpty) return const Text('No flagged or pending products found.');
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
                        const DataColumn(label: Text('Name')),
                        const DataColumn(label: Text('Seller')),
                        const DataColumn(label: Text('Category')),
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
                            DataCell(Text(data['name'] ?? '')),
                            DataCell(Text(data['sellerName'] ?? data['sellerId'] ?? '')),
                            DataCell(Text(data['category'] ?? '')),
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
                                  onPressed: () => _approveProduct(doc),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close),
                                  tooltip: 'Reject',
                                  onPressed: () => _rejectProduct(doc),
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