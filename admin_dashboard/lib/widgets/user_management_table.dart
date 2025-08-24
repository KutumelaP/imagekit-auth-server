import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/audit_log_service.dart';

class UserManagementTable extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  const UserManagementTable({Key? key, required this.auth, required this.firestore}) : super(key: key);

  @override
  State<UserManagementTable> createState() => _UserManagementTableState();
}

class _UserManagementTableState extends State<UserManagementTable> {
  String _searchQuery = '';
  String _roleFilter = 'all';
  Set<String> _selectedUserIds = {};
  late List<DocumentSnapshot> _allDocs;

  void _showEditDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final emailController = TextEditingController(text: data['email'] ?? '');
    final role = ValueNotifier<String>(data['role'] ?? 'user');
    final paused = ValueNotifier<bool>(data['paused'] == true);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
              readOnly: true,
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<String>(
              valueListenable: role,
              builder: (context, value, _) => DropdownButtonFormField<String>(
                value: value,
                decoration: InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('User')),
                  DropdownMenuItem(value: 'seller', child: Text('Seller')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) => role.value = v ?? 'user',
              ),
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<bool>(
              valueListenable: paused,
              builder: (context, value, _) => SwitchListTile(
                title: Text('Paused (banned)'),
                value: value,
                onChanged: (v) => paused.value = v,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final updateData = {
                  'role': role.value,
                  'paused': paused.value,
                };
                await doc.reference.update(updateData);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User updated')));
                await AuditLogService.logAdminAction(user: widget.auth.currentUser?.email ?? '', action: 'Updated User', details: 'User: ${emailController.text} (id: ${doc.id}), role: ${role.value}, subRole: ${updateData['subRole']}, paused: ${paused.value}');
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showUserDetailsDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...data.entries.map((entry) {
                final key = entry.key;
                final value = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text('$key: ${value is Timestamp ? value.toDate() : value}'),
                );
              }).toList(),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.receipt_long),
                    label: Text('View Audit Log'),
                    onPressed: () => _showUserAuditLogDialog(doc.id, data['email']),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: Icon(data['paused'] == true ? Icons.check_circle : Icons.block),
                    label: Text(data['paused'] == true ? 'Reactivate' : 'Pause'),
                    style: ElevatedButton.styleFrom(backgroundColor: data['paused'] == true ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error),
                    onPressed: () async {
                      await doc.reference.update({'paused': !(data['paused'] == true)});
                      Navigator.pop(ctx);
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: Icon(Icons.edit),
                    label: Text('Edit'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showEditDialog(doc);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close'))],
      ),
    );
  }

  void _showUserAuditLogDialog(String userId, String? email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('User Audit Log'),
        content: SizedBox(
          width: 500,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('auditLogs')
                .where('details', isGreaterThanOrEqualTo: 'User: $userId')
                .where('details', isLessThanOrEqualTo: 'User: $userId\uf8ff')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Error loading audit log: ${snapshot.error}', style: TextStyle(color: Theme.of(context).colorScheme.error));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text('No audit log entries for this user.');
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
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
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

  Future<void> _bulkPause(List<DocumentSnapshot> selectedDocs, bool pause) async {
    for (final doc in selectedDocs) {
      await doc.reference.update({'paused': pause});
    }
    setState(() => _selectedUserIds.clear());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pause ? 'Users paused' : 'Users reactivated')));
  }

  void _clearSelection() {
    setState(() => _selectedUserIds.clear());
  }

  Future<void> _deleteUser(DocumentSnapshot doc) async {
    final docId = doc.id;
    final callable = FirebaseFunctions.instance.httpsCallable('adminDeleteUser');
    try {
      await callable.call({'userId': docId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User account deleted (Auth + Firestore)')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Search by email',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Tooltip(
                    message: 'Filter by user role',
                    child: DropdownButton<String>(
                      value: _roleFilter,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Roles')),
                        DropdownMenuItem(value: 'user', child: Text('User')),
                        DropdownMenuItem(value: 'seller', child: Text('Seller')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (v) => setState(() => _roleFilter = v ?? 'all'),
                      autofocus: true,
                    ),
                  ),
                ],
              ),
              if (_selectedUserIds.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.primaryContainer),
                  ),
                  child: Row(
                    children: [
                      Text('${_selectedUserIds.length} selected'),
                      const SizedBox(width: 16),
                      Tooltip(
                        message: 'Pause selected users',
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.block),
                          label: Text('Pause'),
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                          onPressed: () async {
                            final docs = _allDocs.where((d) => _selectedUserIds.contains(d.id)).toList();
                            await _bulkPause(docs, true);
                          },
                          autofocus: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Reactivate selected users',
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.check_circle),
                          label: Text('Reactivate'),
                          onPressed: () async {
                            final docs = _allDocs.where((d) => _selectedUserIds.contains(d.id)).toList();
                            await _bulkPause(docs, false);
                          },
                          autofocus: true,
                        ),
                      ),
                      const Spacer(),
                      Tooltip(
                        message: 'Clear selection',
                        child: IconButton(
                          icon: Icon(Icons.clear),
                          tooltip: 'Clear selection',
                          onPressed: _clearSelection,
                          autofocus: true,
                        ),
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
                stream: widget.firestore.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading users: ${snapshot.error}', style: TextStyle(color: Theme.of(context).colorScheme.error)));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                          const SizedBox(height: 8),
                          Text('No users found.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                        ],
                      ),
                    );
                  }
                  _allDocs = snapshot.data!.docs;
                  final users = _allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final email = (data['email'] ?? '').toString().toLowerCase();
                    final role = (data['role'] ?? 'user').toString().toLowerCase();
                    if (_searchQuery.isNotEmpty && !email.contains(_searchQuery)) return false;
                    if (_roleFilter != 'all' && role != _roleFilter) return false;
                    return true;
                  }).toList();
                  if (users.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                          const SizedBox(height: 8),
                          Text('No users found.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                        ],
                      ),
                    );
                  }
                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    margin: const EdgeInsets.only(top: 8),
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth, // Fill available width
                                minHeight: 300,
                                maxHeight: constraints.maxHeight,
                              ),
                              child: DataTable(
                                columns: [
                                  DataColumn(label: Text('Email', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface))),
                                  DataColumn(label: Text('Role', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface))),
                                  DataColumn(label: Text('Actions', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface))),
                                ],
                                rows: users.map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  return DataRow(
                                    color: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                                      if (states.contains(MaterialState.hovered)) return Theme.of(context).colorScheme.primary.withOpacity(0.08);
                                      return null;
                                    }),
                                    cells: [
                                      DataCell(Text(data['email'] ?? '', style: TextStyle(fontFamily: 'Inter', color: Theme.of(context).colorScheme.onSurface))),
                                      DataCell(Text(data['role'] ?? '', style: TextStyle(fontFamily: 'Inter', color: Theme.of(context).colorScheme.onSurface))),
                                      DataCell(Row(
                                        children: [
                                          Tooltip(
                                            message: 'Edit user',
                                            child: IconButton(
                                              icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.onSurface),
                                              tooltip: 'Edit',
                                              onPressed: () => _showEditDialog(doc),
                                              autofocus: true,
                                            ),
                                          ),
                                          Tooltip(
                                            message: 'Delete user',
                                            child: IconButton(
                                              icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.onSurface),
                                              tooltip: 'Delete',
                                              onPressed: () => _deleteUser(doc),
                                              autofocus: true,
                                            ),
                                          ),
                                        ],
                                      )),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(bool paused) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: paused ? Theme.of(context).colorScheme.error.withOpacity(0.15) : Theme.of(context).colorScheme.secondary.withOpacity(0.15),
        border: Border.all(color: paused ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.secondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        paused ? 'Paused' : 'Active',
        style: TextStyle(color: paused ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold),
      ),
    );
  }
} 