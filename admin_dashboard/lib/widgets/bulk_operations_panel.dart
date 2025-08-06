import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum BulkOperationType {
  approve,
  reject,
  suspend,
  activate,
  delete,
  archive,
  notify,
  export,
}

enum BulkEntityType {
  users,
  sellers,
  orders,
  products,
  reviews,
}

class BulkOperationsPanel extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final List<String> selectedItems;
  final BulkEntityType entityType;
  final VoidCallback? onOperationComplete;

  const BulkOperationsPanel({
    Key? key,
    required this.firestore,
    required this.auth,
    required this.selectedItems,
    required this.entityType,
    this.onOperationComplete,
  }) : super(key: key);

  @override
  State<BulkOperationsPanel> createState() => _BulkOperationsPanelState();
}

class _BulkOperationsPanelState extends State<BulkOperationsPanel> {
  bool _isProcessing = false;
  double _progress = 0.0;
  String _currentOperation = '';
  List<String> _completedItems = [];
  List<String> _failedItems = [];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 450,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          if (_isProcessing) _buildProgressSection() else _buildOperationsSection(),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1F4654), Color(0xFF7FB2BF)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(Icons.playlist_add_check, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulk Operations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.selectedItems.length} ${_getEntityDisplayName()} selected',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (!_isProcessing)
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildOperationsSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Operations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildOperationGrid(),
        ],
      ),
    );
  }

  Widget _buildOperationGrid() {
    final operations = _getAvailableOperations();
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: operations.map((operation) => _buildOperationCard(operation)).toList(),
    );
  }

  Widget _buildOperationCard(BulkOperation operation) {
    return InkWell(
      onTap: () => _executeOperation(operation),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: operation.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: operation.color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: operation.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                operation.icon,
                color: operation.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    operation.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: operation.color,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    operation.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircularProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1F4654)),
          ),
          const SizedBox(height: 16),
          Text(
            _currentOperation,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_progress * 100).toInt()}% Complete',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1F4654)),
          ),
          if (_completedItems.isNotEmpty || _failedItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildResultsSummary(),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (_completedItems.isNotEmpty)
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_completedItems.length} completed successfully',
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
              ],
            ),
          if (_failedItems.isNotEmpty) ...[
            if (_completedItems.isNotEmpty) const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_failedItems.length} failed',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          if (_isProcessing) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _cancelOperation,
                child: const Text('Cancel'),
              ),
            ),
          ] else ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: widget.selectedItems.isNotEmpty ? () => _showBulkNotificationDialog() : null,
                icon: const Icon(Icons.notifications_active, size: 16),
                label: const Text('Notify Selected'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1F4654),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<BulkOperation> _getAvailableOperations() {
    switch (widget.entityType) {
      case BulkEntityType.sellers:
        return [
          BulkOperation(
            type: BulkOperationType.approve,
            title: 'Approve',
            description: 'Approve selected sellers',
            icon: Icons.check_circle,
            color: Colors.green,
          ),
          BulkOperation(
            type: BulkOperationType.reject,
            title: 'Reject',
            description: 'Reject applications',
            icon: Icons.cancel,
            color: Colors.red,
          ),
          BulkOperation(
            type: BulkOperationType.suspend,
            title: 'Suspend',
            description: 'Temporarily suspend accounts',
            icon: Icons.pause_circle,
            color: Colors.orange,
          ),
          BulkOperation(
            type: BulkOperationType.export,
            title: 'Export',
            description: 'Export data to CSV',
            icon: Icons.download,
            color: Colors.blue,
          ),
        ];
      case BulkEntityType.users:
        return [
          BulkOperation(
            type: BulkOperationType.activate,
            title: 'Activate',
            description: 'Activate user accounts',
            icon: Icons.person_add,
            color: Colors.green,
          ),
          BulkOperation(
            type: BulkOperationType.suspend,
            title: 'Suspend',
            description: 'Suspend user accounts',
            icon: Icons.person_off,
            color: Colors.orange,
          ),
          BulkOperation(
            type: BulkOperationType.export,
            title: 'Export',
            description: 'Export user data',
            icon: Icons.download,
            color: Colors.blue,
          ),
          BulkOperation(
            type: BulkOperationType.notify,
            title: 'Send Message',
            description: 'Send bulk notification',
            icon: Icons.email,
            color: Colors.purple,
          ),
        ];
      case BulkEntityType.orders:
        return [
          BulkOperation(
            type: BulkOperationType.archive,
            title: 'Archive',
            description: 'Archive completed orders',
            icon: Icons.archive,
            color: Colors.grey,
          ),
          BulkOperation(
            type: BulkOperationType.export,
            title: 'Export',
            description: 'Export order data',
            icon: Icons.download,
            color: Colors.blue,
          ),
        ];
      default:
        return [
          BulkOperation(
            type: BulkOperationType.export,
            title: 'Export',
            description: 'Export selected data',
            icon: Icons.download,
            color: Colors.blue,
          ),
        ];
    }
  }

  Future<void> _executeOperation(BulkOperation operation) async {
    final confirmed = await _showConfirmationDialog(operation);
    if (!confirmed) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _currentOperation = operation.title;
      _completedItems.clear();
      _failedItems.clear();
    });

    try {
      switch (operation.type) {
        case BulkOperationType.approve:
          await _bulkApprove();
          break;
        case BulkOperationType.reject:
          await _bulkReject();
          break;
        case BulkOperationType.suspend:
          await _bulkSuspend();
          break;
        case BulkOperationType.activate:
          await _bulkActivate();
          break;
        case BulkOperationType.delete:
          await _bulkDelete();
          break;
        case BulkOperationType.archive:
          await _bulkArchive();
          break;
        case BulkOperationType.export:
          await _bulkExport();
          break;
        case BulkOperationType.notify:
          await _bulkNotify();
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Operation failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
        _progress = 1.0;
      });
      
      // Show completion dialog
      await _showCompletionDialog(operation);
      
      widget.onOperationComplete?.call();
      Navigator.of(context).pop();
    }
  }

  Future<bool> _showConfirmationDialog(BulkOperation operation) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm ${operation.title}'),
        content: Text(
          'Are you sure you want to ${operation.title.toLowerCase()} ${widget.selectedItems.length} ${_getEntityDisplayName()}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: operation.color),
            child: Text(operation.title),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _showCompletionDialog(BulkOperation operation) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _failedItems.isEmpty ? Icons.check_circle : Icons.warning,
              color: _failedItems.isEmpty ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text('Operation Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${operation.title} operation completed:'),
            const SizedBox(height: 12),
            if (_completedItems.isNotEmpty)
              Text('✅ ${_completedItems.length} items processed successfully'),
            if (_failedItems.isNotEmpty)
              Text('❌ ${_failedItems.length} items failed'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkApprove() async {
    for (int i = 0; i < widget.selectedItems.length; i++) {
      try {
        await widget.firestore.collection(_getCollectionName()).doc(widget.selectedItems[i]).update({
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': widget.auth.currentUser?.uid,
        });
        _completedItems.add(widget.selectedItems[i]);
      } catch (e) {
        _failedItems.add(widget.selectedItems[i]);
      }
      setState(() => _progress = (i + 1) / widget.selectedItems.length);
      await Future.delayed(const Duration(milliseconds: 100)); // Simulate processing time
    }
  }

  Future<void> _bulkReject() async {
    for (int i = 0; i < widget.selectedItems.length; i++) {
      try {
        await widget.firestore.collection(_getCollectionName()).doc(widget.selectedItems[i]).update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectedBy': widget.auth.currentUser?.uid,
        });
        _completedItems.add(widget.selectedItems[i]);
      } catch (e) {
        _failedItems.add(widget.selectedItems[i]);
      }
      setState(() => _progress = (i + 1) / widget.selectedItems.length);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _bulkSuspend() async {
    for (int i = 0; i < widget.selectedItems.length; i++) {
      try {
        await widget.firestore.collection(_getCollectionName()).doc(widget.selectedItems[i]).update({
          'status': 'suspended',
          'suspendedAt': FieldValue.serverTimestamp(),
          'suspendedBy': widget.auth.currentUser?.uid,
        });
        _completedItems.add(widget.selectedItems[i]);
      } catch (e) {
        _failedItems.add(widget.selectedItems[i]);
      }
      setState(() => _progress = (i + 1) / widget.selectedItems.length);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _bulkActivate() async {
    for (int i = 0; i < widget.selectedItems.length; i++) {
      try {
        await widget.firestore.collection(_getCollectionName()).doc(widget.selectedItems[i]).update({
          'status': 'active',
          'activatedAt': FieldValue.serverTimestamp(),
          'activatedBy': widget.auth.currentUser?.uid,
        });
        _completedItems.add(widget.selectedItems[i]);
      } catch (e) {
        _failedItems.add(widget.selectedItems[i]);
      }
      setState(() => _progress = (i + 1) / widget.selectedItems.length);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _bulkDelete() async {
    for (int i = 0; i < widget.selectedItems.length; i++) {
      try {
        await widget.firestore.collection(_getCollectionName()).doc(widget.selectedItems[i]).delete();
        _completedItems.add(widget.selectedItems[i]);
      } catch (e) {
        _failedItems.add(widget.selectedItems[i]);
      }
      setState(() => _progress = (i + 1) / widget.selectedItems.length);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _bulkArchive() async {
    for (int i = 0; i < widget.selectedItems.length; i++) {
      try {
        await widget.firestore.collection(_getCollectionName()).doc(widget.selectedItems[i]).update({
          'archived': true,
          'archivedAt': FieldValue.serverTimestamp(),
          'archivedBy': widget.auth.currentUser?.uid,
        });
        _completedItems.add(widget.selectedItems[i]);
      } catch (e) {
        _failedItems.add(widget.selectedItems[i]);
      }
      setState(() => _progress = (i + 1) / widget.selectedItems.length);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _bulkExport() async {
    // In a real implementation, this would generate a CSV/Excel file
    setState(() => _currentOperation = 'Preparing export...');
    await Future.delayed(const Duration(seconds: 2));
    
    // Simulate export completion
    _completedItems.addAll(widget.selectedItems);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export completed. ${widget.selectedItems.length} records exported.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _bulkNotify() async {
    // This would be implemented with Firebase Cloud Messaging or similar
    setState(() => _currentOperation = 'Sending notifications...');
    await Future.delayed(const Duration(seconds: 1));
    _completedItems.addAll(widget.selectedItems);
  }

  void _showBulkNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Bulk Notification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Send notification logic here
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Notifications sent to ${widget.selectedItems.length} recipients'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _cancelOperation() {
    setState(() {
      _isProcessing = false;
      _progress = 0.0;
    });
  }

  String _getEntityDisplayName() {
    switch (widget.entityType) {
      case BulkEntityType.users: return 'users';
      case BulkEntityType.sellers: return 'sellers';
      case BulkEntityType.orders: return 'orders';
      case BulkEntityType.products: return 'products';
      case BulkEntityType.reviews: return 'reviews';
    }
  }

  String _getCollectionName() {
    switch (widget.entityType) {
      case BulkEntityType.users: return 'users';
      case BulkEntityType.sellers: return 'users';
      case BulkEntityType.orders: return 'orders';
      case BulkEntityType.products: return 'products';
      case BulkEntityType.reviews: return 'reviews';
    }
  }
}

class BulkOperation {
  final BulkOperationType type;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  BulkOperation({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
} 