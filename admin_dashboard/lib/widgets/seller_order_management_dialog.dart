import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';

class SellerOrderManagementDialog extends StatefulWidget {
  final String orderId;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  const SellerOrderManagementDialog({Key? key, required this.orderId, required this.auth, required this.firestore}) : super(key: key);

  @override
  State<SellerOrderManagementDialog> createState() => _SellerOrderManagementDialogState();
}

class _SellerOrderManagementDialogState extends State<SellerOrderManagementDialog> {
  final _driverNameController = TextEditingController();
  final _driverPhoneController = TextEditingController();
  final _statusNoteController = TextEditingController();
  final _internalNoteController = TextEditingController();
  final _trackingUpdateController = TextEditingController();
  String? _selectedDriverId;
  bool _updating = false;
  bool _notifying = false;
  bool _flagging = false;
  bool _addingTracking = false;
  List<Map<String, dynamic>> _savedDrivers = [];

  @override
  void dispose() {
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _statusNoteController.dispose();
    _internalNoteController.dispose();
    _trackingUpdateController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedDrivers(String sellerId) async {
    final driversSnap = await widget.firestore
        .collection('users')
        .doc(sellerId)
        .collection('drivers')
        .get();
    setState(() {
      _savedDrivers = driversSnap.docs.map((d) => d.data()).toList().cast<Map<String, dynamic>>();
    });
  }

  Future<void> _addDriver(String sellerId, String name, String phone) async {
    await widget.firestore
        .collection('users')
        .doc(sellerId)
        .collection('drivers')
        .add({'name': name, 'phone': phone});
    await _loadSavedDrivers(sellerId);
  }

  Future<void> _notifyBuyer(String message) async {
    setState(() => _notifying = true);
    try {
      // Get order data to send notification
      final orderData = await widget.firestore
          .collection('orders')
          .doc(widget.orderId)
          .get();
      
      if (!orderData.exists) {
        throw Exception('Order not found');
      }
      
      final orderDoc = orderData.data() as Map<String, dynamic>;
      final buyerId = orderDoc['buyerId'] as String?;
      final orderNumber = orderDoc['orderNumber'] as String?;
      final status = orderDoc['status'] as String? ?? 'updated';
      
      if (buyerId != null && orderNumber != null) {
        // Send notification to buyer
        await AdminNotificationService().sendOrderUpdateNotification(
          recipientId: buyerId,
          orderId: widget.orderId,
          status: status,
          message: message,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Buyer notified: $message'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Missing order data for notification');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error notifying buyer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _notifying = false);
    }
  }

  Future<void> _printInvoice() async {
    // TODO: Implement invoice download/print
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice download/print (stub).')));
  }

  Future<void> _flagOrder() async {
    setState(() => _flagging = true);
    // TODO: Implement flag logic
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _flagging = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order flagged (stub).')));
  }

  Future<void> _addTrackingUpdate(DocumentReference orderRef, String sellerName) async {
    setState(() => _addingTracking = true);
    final update = {
      'description': _trackingUpdateController.text.trim(),
      'timestamp': DateTime.now(),
      'by': sellerName,
    };
    await orderRef.update({
      'trackingUpdates': FieldValue.arrayUnion([update])
    });
    setState(() => _addingTracking = false);
    _trackingUpdateController.clear();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Implement the full dialog UI as needed
    return AlertDialog(
      title: const Text('Order Management'),
      content: const Text('Order management dialog content goes here.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
} 