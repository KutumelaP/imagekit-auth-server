import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogsSection extends StatefulWidget {
  @override
  State<AuditLogsSection> createState() => _AuditLogsSectionState();
}

class _AuditLogsSectionState extends State<AuditLogsSection> {
  String _searchQuery = '';
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: 'Search by user, action, or details',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Tip: You can scroll horizontally to see more columns.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontStyle: FontStyle.italic, fontSize: 13),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('auditLogs').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final logs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final user = (data['user'] ?? '').toString().toLowerCase();
                  final action = (data['action'] ?? '').toString().toLowerCase();
                  final details = (data['details'] ?? '').toString().toLowerCase();
                  if (_searchQuery.isNotEmpty && !user.contains(_searchQuery) && !action.contains(_searchQuery) && !details.contains(_searchQuery)) return false;
                  return true;
                }).toList();
                if (logs.isEmpty) return const Text('No audit logs found.');
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Timestamp')),
                      DataColumn(label: Text('User')),
                      DataColumn(label: Text('Action')),
                      DataColumn(label: Text('Details')),
                    ],
                    rows: logs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DataRow(cells: [
                        DataCell(Text(data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate().toString() : '')),
                        DataCell(Text(data['user'] ?? '')),
                        DataCell(Text(data['action'] ?? '')),
                        DataCell(Text(data['details'] ?? '')),
                      ]);
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 