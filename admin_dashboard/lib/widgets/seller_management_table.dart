import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:html' as html;
import 'package:cloud_functions/cloud_functions.dart';
import '../SellerOrderDetailScreen.dart';
import 'package:admin_dashboard/widgets/seller_order_management_dialog.dart';
import '../services/audit_log_service.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../theme/admin_theme.dart';

class SellerManagementTable extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  const SellerManagementTable({Key? key, required this.auth, required this.firestore}) : super(key: key);

  @override
  State<SellerManagementTable> createState() => _SellerManagementTableState();
}

class _SellerManagementTableState extends State<SellerManagementTable> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  Set<String> _selectedSellerIds = {};
  late List<DocumentSnapshot> _allDocs;

  void _showEditDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final emailController = TextEditingController(text: data['email'] ?? '');
    final storeNameController = TextEditingController(text: data['storeName'] ?? '');
    final status = ValueNotifier<String>(data['status'] ?? 'pending');
    final paused = ValueNotifier<bool>(data['paused'] == true);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Seller'),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
                readOnly: true,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: storeNameController,
                decoration: InputDecoration(labelText: 'Store Name'),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (context, value, _) => DropdownButtonFormField<String>(
                  value: value,
                  decoration: InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: (v) => status.value = v ?? 'pending',
                ),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<bool>(
                valueListenable: paused,
                builder: (context, value, _) => SwitchListTile(
                  title: Text('Paused (banned)'),
                  value: value,
                  onChanged: (v) => paused.value = v,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                // Set verified field based on status
                final verified = status.value == 'approved';
                await doc.reference.update({
                  'storeName': storeNameController.text.trim(),
                  'status': status.value,
                  'paused': paused.value,
                  'verified': verified,
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Seller updated')));
                await AuditLogService.logAdminAction(user: widget.auth.currentUser?.email ?? '', action: 'Updated Seller', details: 'Seller: ${emailController.text} (id: ${doc.id}), status: ${status.value}, paused: ${paused.value}, verified: $verified');
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

  Future<void> _bulkPause(List<DocumentSnapshot> selectedDocs, bool pause) async {
    for (final doc in selectedDocs) {
      await doc.reference.update({'paused': pause});
    }
    setState(() => _selectedSellerIds.clear());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pause ? 'Sellers paused' : 'Sellers reactivated')));
  }

  Future<void> _bulkApprove(List<DocumentSnapshot> selectedDocs) async {
    for (final doc in selectedDocs) {
      await doc.reference.update({
        'status': 'approved',
        'verified': true,
      });
    }
    setState(() => _selectedSellerIds.clear());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sellers approved and verified')));
  }

  void _clearSelection() {
    setState(() => _selectedSellerIds.clear());
  }

  void _showProductsDialog(String sellerId) async {
    final products = await widget.firestore.collection('products').where('ownerId', isEqualTo: sellerId).get();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Seller Products'),
        content: SizedBox(
          width: 400,
          child: products.docs.isEmpty
              ? Text('No products found.')
              : ListView(
                  shrinkWrap: true,
                  children: products.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['name'] ?? ''),
                      subtitle: Text('Category: ${data['category'] ?? ''} | Price: ${data['price'] ?? ''}'),
                    );
                  }).toList(),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close'))],
      ),
    );
  }

  void _showSellerDetailsDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('Seller Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    Spacer(),
                    IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 18),
                // Profile Section
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        if (data['profileImageUrl'] != null && data['profileImageUrl'].toString().isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              data['profileImageUrl'], 
                              height: 80, 
                              width: 80, 
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading seller profile image: $error');
                                return Container(
                                  height: 80,
                                  width: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.store, color: AdminTheme.mediumGrey, size: 40),
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 80,
                                  width: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          CircleAvatar(
                            radius: 40, 
                            backgroundColor: AdminTheme.lightGrey,
                            child: Icon(Icons.store, size: 40, color: AdminTheme.mediumGrey),
                          ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['storeName'] ?? '', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text(data['email'] ?? '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
                              if (data['contact'] != null && data['contact'].toString().isNotEmpty)
                                Text(data['contact'], style: Theme.of(context).textTheme.bodyMedium),
                              if ((data['status'] ?? '') == 'approved')
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    children: [
                                      Icon(Icons.verified, color: AdminTheme.success, size: 20),
                                      const SizedBox(width: 6),
                                      Text('Verified', style: TextStyle(color: AdminTheme.success, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Divider(),
                // Store Info
                Text('Store Information', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                _detailField('Location', data['location']),
                Row(
                  children: [
                    Expanded(child: _detailField('Latitude', data['latitude']?.toString())),
                    const SizedBox(width: 16),
                    Expanded(child: _detailField('Longitude', data['longitude']?.toString())),
                  ],
                ),
                _detailField('Is Store Open', data['isStoreOpen'] == true ? 'Yes' : 'No'),
                _detailField('Story', data['story']),
                _detailField('Passion', data['passion']),
                const SizedBox(height: 18),
                Divider(),
                // Delivery Info
                Text('Delivery & Visibility', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                _detailField('Delivery Available', data['deliveryAvailable'] == true ? 'Yes' : 'No'),
                _detailField('Deliver Everywhere', data['deliverEverywhere'] == true ? 'Yes' : 'No'),
                _detailField('Delivery Fee Per Km', data['deliveryFeePerKm']?.toString()),
                _detailField('Visibility Radius', data['visibilityRadius']?.toString()),
                _detailField('Min Order for Delivery', data['minOrderForDelivery']?.toString()),
                Row(
                  children: [
                    Expanded(child: _detailField('Delivery Start Hour', data['deliveryStartHour']?.toString())),
                    const SizedBox(width: 16),
                    Expanded(child: _detailField('Delivery End Hour', data['deliveryEndHour']?.toString())),
                  ],
                ),
                _chipField('Payment Methods', data['paymentMethods']),
                _chipField('Excluded Zones', data['excludedZones']),
                const SizedBox(height: 18),
                Divider(),
                // Specialties & Media
                Text('Specialties & Media', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                _chipField('Specialties', data['specialties']),
                if (data['extraPhotoUrls'] != null && (data['extraPhotoUrls'] as List).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Extra Photos', style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: (data['extraPhotoUrls'] as List).map<Widget>((url) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(url, height: 60, width: 60, fit: BoxFit.cover),
                        )).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                if (data['introVideoUrl'] != null && data['introVideoUrl'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(Icons.videocam, color: AdminTheme.mediumGrey),
                        const SizedBox(width: 8),
                        Flexible(
                          child: InkWell(
                            onTap: () => launchUrl(Uri.parse(data['introVideoUrl'])),
                            child: Text('View Intro Video', style: TextStyle(color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline)),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                Divider(),
                // Status & Role
                Text('Account', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                _detailField('Status', data['status']),
                _detailField('Role', data['role']),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSellerAuditLogDialog(String sellerId, String? email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Seller Audit Log'),
        content: SizedBox(
          width: 500,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('auditLogs')
                .where('details', isGreaterThanOrEqualTo: 'Seller: $sellerId')
                .where('details', isLessThanOrEqualTo: 'Seller: $sellerId\uf8ff')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Error loading audit log: ${snapshot.error}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text('No audit log entries for this seller.');
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
                        Text(data['user'] ?? '', style: Theme.of(context).textTheme.bodySmall),
                        Text(
                          data['timestamp'] != null
                              ? (data['timestamp'] as Timestamp).toDate().toString()
                              : '',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)),
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

  Future<void> _deleteSeller(DocumentSnapshot doc) async {
    final sellerData = doc.data() as Map<String, dynamic>;
    final docId = doc.id;
    await doc.reference.delete();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Seller deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await FirebaseFirestore.instance.collection('users').doc(docId).set(sellerData);
          },
        ),
        duration: Duration(seconds: 5),
      ),
    );
    setState(() {});
  }

  void _showReviewDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Review Seller Registration'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in data.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${entry.key}: ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Expanded(child: Text('${entry.value}', style: Theme.of(context).textTheme.bodyMedium)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close')),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.update({'status': 'approved'});
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Seller approved.')));
            },
            child: Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showBulkEmailDialog() {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send Bulk Email to Sellers'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subjectController,
              decoration: InputDecoration(labelText: 'Subject'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: messageController,
              decoration: InputDecoration(labelText: 'Message'),
              minLines: 3,
              maxLines: 6,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final sellers = await widget.firestore.collection('users').where('role', isEqualTo: 'seller').get();
              final emails = sellers.docs.map((doc) => doc['email']).where((e) => e != null && e.toString().contains('@')).toList();
              try {
                final callable = FirebaseFunctions.instance.httpsCallable('sendBulkEmailToSellers');
                await callable.call({
                  'emails': emails,
                  'subject': subjectController.text,
                  'message': messageController.text,
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bulk email sent to all sellers.')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending bulk email: $e')));
              }
            },
            child: Text('Send'),
          ),
        ],
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.email),
                    label: Text('Bulk Email Sellers'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: AdminTheme.angel,
                    ),
                    onPressed: _showBulkEmailDialog,
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: Icon(Icons.verified),
                    label: Text('Verify All Approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.success,
                      foregroundColor: AdminTheme.angel,
                    ),
                    onPressed: () async {
                      try {
                        final sellers = await widget.firestore
                            .collection('users')
                            .where('role', isEqualTo: 'seller')
                            .where('status', isEqualTo: 'approved')
                            .get();
                        
                        int updatedCount = 0;
                        for (final doc in sellers.docs) {
                          final data = doc.data();
                          if (!data['verified']) {
                            await doc.reference.update({'verified': true});
                            updatedCount++;
                          }
                        }
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Verified $updatedCount approved sellers'))
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'))
                        );
                      }
                    },
                  ),
                  Spacer(),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Search by email or store',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Tooltip(
                    message: 'Filter by seller status',
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'approved', child: Text('Approved')),
                        DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                        DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                      ],
                      onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                      autofocus: true,
                    ),
                  ),
                ],
              ),
              if (_selectedSellerIds.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Text('${_selectedSellerIds.length} selected'),
                      const SizedBox(width: 16),
                      Tooltip(
                        message: 'Pause selected sellers',
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.block),
                          label: Text('Pause'),
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                          onPressed: () async {
                            final docs = _allDocs.where((d) => _selectedSellerIds.contains(d.id)).toList();
                            await _bulkPause(docs, true);
                          },
                          autofocus: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Reactivate selected sellers',
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.check_circle),
                          label: Text('Reactivate'),
                          onPressed: () async {
                            final docs = _allDocs.where((d) => _selectedSellerIds.contains(d.id)).toList();
                            await _bulkPause(docs, false);
                          },
                          autofocus: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Approve and verify selected sellers',
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.verified),
                          label: Text('Approve'),
                          style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.success),
                          onPressed: () async {
                            final docs = _allDocs.where((d) => _selectedSellerIds.contains(d.id)).toList();
                            await _bulkApprove(docs);
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
              SizedBox(
                height: 500,
                child: StreamBuilder<QuerySnapshot>(
                  stream: widget.firestore.collection('users').where('role', isEqualTo: 'seller').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading sellers: ${snapshot.error}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)),
                            const SizedBox(height: 8),
                            Text('No sellers found.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38))),
                          ],
                        ),
                      );
                    }
                    _allDocs = snapshot.data!.docs;
                    final sellers = _allDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final email = (data['email'] ?? '').toString().toLowerCase();
                      final store = (data['storeName'] ?? '').toString().toLowerCase();
                      final status = (data['status'] ?? 'pending').toString().toLowerCase();
                      if (_searchQuery.isNotEmpty && !email.contains(_searchQuery) && !store.contains(_searchQuery)) return false;
                      if (_statusFilter != 'all' && status != _statusFilter) return false;
                      return true;
                    }).toList();
                    if (sellers.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)),
                            const SizedBox(height: 8),
                            Text('No sellers found.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38))),
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
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: [
                              DataColumn(label: Text('Name', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface))),
                              DataColumn(label: Text('Email', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface))),
                              DataColumn(label: Text('Status', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface))),
                              DataColumn(label: Text('Fee Exempt', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface))),
                              DataColumn(label: Text('Actions', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface))),
                            ],
                            rows: sellers.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return DataRow(
                                color: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                                  if (states.contains(MaterialState.hovered)) return Theme.of(context).colorScheme.primary.withOpacity(0.08);
                                  return null;
                                }),
                                cells: [
                                  DataCell(Row(
                                    children: [
                                      if ((data['profileImageUrl'] ?? '').toString().isNotEmpty)
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundImage: NetworkImage(data['profileImageUrl']),
                                          backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                                          onBackgroundImageError: (exception, stackTrace) {
                                            print('Error loading seller avatar: $exception');
                                          },
                                        )
                                      else
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                                          child: Icon(Icons.store, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)),
                                        ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(data['name'] ?? '', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                                          if ((data['storeName'] ?? '').toString().isNotEmpty)
                                            Text(
                                              data['storeName'],
                                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                color: Theme.of(context).colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  )),
                                  DataCell(Text(data['email'] ?? '', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface))),
                                  DataCell(Row(
                                    children: [
                                      Text(
                                        data['status'] ?? '',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                                      ),
                                      if ((data['status'] ?? '') == 'approved')
                                        Padding(
                                          padding: const EdgeInsets.only(left: 6.0),
                                          child: Icon(Icons.verified, color: AdminTheme.success, size: 20),
                                        ),
                                    ],
                                  )),
                                  DataCell(Row(
                                    children: [
                                      Tooltip(
                                        message: data['platformFeeExempt'] == true ? 'Seller is exempt from platform fee' : 'Seller pays platform fee',
                                        child: Row(
                                          children: [
                                            Switch(
                                              value: data['platformFeeExempt'] == true,
                                              onChanged: (val) async {
                                                await doc.reference.update({'platformFeeExempt': val});
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(val ? 'Seller exempted from platform fee.' : 'Platform fee applied to seller.')),
                                                );
                                                setState(() {});
                                              },
                                              activeColor: Theme.of(context).colorScheme.primary,
                                              inactiveThumbColor: Theme.of(context).colorScheme.error,
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              data['platformFeeExempt'] == true ? Icons.check_circle : Icons.cancel,
                                              color: data['platformFeeExempt'] == true ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )),
                                  DataCell(Row(
                                    children: [
                                      Tooltip(
                                        message: 'Edit seller',
                                        child: IconButton(
                                          icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.onSurface),
                                          tooltip: 'Edit',
                                          onPressed: () => _showEditDialog(doc),
                                          autofocus: true,
                                        ),
                                      ),
                                      Tooltip(
                                        message: 'View details',
                                        child: IconButton(
                                          icon: Icon(Icons.visibility, color: Theme.of(context).colorScheme.onSurface),
                                          tooltip: 'View Details',
                                          onPressed: () => _showSellerDetailsDialog(context, data),
                                        ),
                                      ),
                                      Tooltip(
                                        message: 'Delete seller',
                                        child: IconButton(
                                          icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.onSurface),
                                          tooltip: 'Delete',
                                          onPressed: () => _deleteSeller(doc),
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
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final theme = Theme.of(context);
    Color color;
    switch (status) {
      case 'approved':
        color = theme.colorScheme.primary;
        break;
      case 'pending':
        color = theme.colorScheme.secondary;
        break;
      case 'rejected':
        color = theme.colorScheme.error;
        break;
      case 'inactive':
        color = theme.colorScheme.onSurface.withOpacity(0.38);
        break;
      default:
        color = theme.colorScheme.secondary;
    }
    String label = status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _detailField(String label, String? value) {
    if (value == null || value.isEmpty) return SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _chipField(String label, dynamic values) {
    if (values == null || (values is List && values.isEmpty)) return SizedBox.shrink();
    final list = values is List ? values : [values];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: list.map<Widget>((v) => Chip(label: Text(v.toString()))).toList(),
            ),
          ),
        ],
      ),
    );
  }
} 