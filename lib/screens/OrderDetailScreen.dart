import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'OrderTrackingScreen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class OrderDetailScreen extends StatelessWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: AppTheme.angel,
      ),
      backgroundColor: AppTheme.whisper,
      body: FutureBuilder<DocumentSnapshot>(
        future: orderRef.get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error loading order'));
          if (!snapshot.hasData || snapshot.data == null) return Center(
            child: CircularProgressIndicator(color: AppTheme.cloud),
          );

          final order = snapshot.data!.data()! as Map<String, dynamic>;
          final status = order['status'] as String? ?? 'pending';

          final deliveryFee = order['deliveryFee'] ?? 0.0;
          final deliveryTimeEstimate = order['deliveryTimeEstimate'] ?? '';
          final paymentMethods = (order['paymentMethods'] as List?)?.join(', ') ?? '';
          final deliveryInstructions = order['deliveryInstructions'] ?? '';
          final driver = order['driver'] as Map<String, dynamic>?;
          final excludedZones = (order['excludedZones'] as List?)?.join(', ') ?? '';
          final platformFee = order['platformFee'] ?? 0.0;
          final sellerPayout = order['sellerPayout'] ?? (order['totalPrice'] ?? 0.0) - platformFee;
          final orderType = (order['orderType'] as String?)?.toLowerCase() ?? '';
          final pickupAddress = order['pickupPointAddress'] as String?;
          final pickupName = order['pickupPointName'] as String?;
          final pickupType = order['pickupPointType'] as String?; // pargo, paxi, local_store

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                // Status Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getStatusIcon(status),
                            color: AppTheme.getStatusColor(status),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Status: ${status.toUpperCase()}',
                            style: AppTheme.headlineMedium.copyWith(
                              color: AppTheme.getStatusColor(status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Order Details Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order Details', style: AppTheme.headlineMedium),
                      const SizedBox(height: 12),
                      if (deliveryFee != 0.0)
                        _buildDetailRow('Delivery Fee', 'R${deliveryFee.toStringAsFixed(2)}'),
                      _buildDetailRow('Platform Fee', 'R${platformFee.toStringAsFixed(2)}'),
                      _buildDetailRow('Net Payout', 'R${sellerPayout.toStringAsFixed(2)}'),
                      if (deliveryTimeEstimate.isNotEmpty)
                        _buildDetailRow('Estimated Delivery', deliveryTimeEstimate),
                      if (paymentMethods.isNotEmpty)
                        _buildDetailRow('Payment Methods', paymentMethods),
                      if (deliveryInstructions.isNotEmpty)
                        _buildDetailRow('Instructions', deliveryInstructions),
                      if (excludedZones.isNotEmpty)
                        _buildDetailRow('Excluded Delivery Zones', excludedZones),
                      if (driver != null)
                        _buildDetailRow('Driver', '${driver['name'] ?? ''} (${driver['phone'] ?? ''})'),
                      if (orderType == 'pickup' && pickupAddress != null && pickupAddress.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Pickup Details', style: AppTheme.headlineMedium),
                        const SizedBox(height: 8),
                        if (pickupName != null && pickupName.isNotEmpty)
                          _buildDetailRow('Location', pickupName),
                        _buildDetailRow('Address', pickupAddress),
                        if (pickupType != null)
                          _buildDetailRow('Pickup Type', pickupType == 'local_store' ? 'Store pickup' : pickupType.toUpperCase()),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                
                // Tracking Updates Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tracking Updates', style: AppTheme.headlineMedium),
                      const SizedBox(height: 12),
                      StreamBuilder<DocumentSnapshot>(
                        stream: orderRef.snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) return Text(
                            'Error loading tracking updates',
                            style: TextStyle(color: AppTheme.error),
                          );
                          if (!snapshot.hasData || snapshot.data == null) return Center(
                            child: CircularProgressIndicator(color: AppTheme.cloud),
                          );
                          final order = snapshot.data!.data()! as Map<String, dynamic>;
                          final updates = List<Map<String, dynamic>>.from(order['trackingUpdates'] ?? []);
                          if (updates.isEmpty) return Text(
                            'No tracking information available yet.',
                            style: AppTheme.bodyMedium,
                          );
                          updates.sort((a, b) {
                            final ta = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                            final tb = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                            return ta.compareTo(tb);
                          });
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: updates.length,
                            itemBuilder: (context, i) {
                              final u = updates[i];
                              final ts = (u['timestamp'] as Timestamp).toDate();
                              return ListTile(
                                leading: Icon(
                                  i == 0 ? Icons.circle : Icons.check_circle_outline,
                                  color: AppTheme.cloud,
                                ),
                                title: Text(u['description'] ?? '', style: AppTheme.bodyLarge),
                                subtitle: Text('${ts.toLocal()}', style: AppTheme.bodySmall),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                
                // Action Buttons
                if (status == 'pending') ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: AppTheme.angel,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.cancel),
                    onPressed: () async {
                      await orderRef.update({'status': 'cancelled'});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Order cancelled'),
                          backgroundColor: AppTheme.deepTeal,
                        ),
                      );
                      Navigator.pop(context);
                    },
                    label: const Text('Cancel Order'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cloud,
                      foregroundColor: AppTheme.deepTeal,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.assignment_return),
                    onPressed: () async {
                      showDialog(
                        context: context,
                        builder: (ctx) => RequestReturnDialog(orderId: orderId),
                      );
                    },
                    label: const Text('Request Return'),
                  ),
                ] else if (status == 'shipped') ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.deepTeal,
                      foregroundColor: AppTheme.angel,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.local_shipping),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderTrackingScreen(orderId: orderId),
                        ),
                      );
                    },
                    label: const Text('Track Order'),
                  ),
                ] else ...[
                  Text(
                    'No further actions available for this order.',
                    style: AppTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  )
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: AppTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Icons.pending_actions;
      case 'confirmed': return Icons.check_circle_outline;
      case 'preparing': return Icons.restaurant;
      case 'ready': return Icons.local_shipping;
      case 'shipped': return Icons.local_shipping;
      case 'delivered': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      default: return Icons.help_outline;
    }
  }
}

class RequestReturnDialog extends StatefulWidget {
  final String orderId;
  const RequestReturnDialog({required this.orderId});
  @override
  State<RequestReturnDialog> createState() => _RequestReturnDialogState();
}

class _RequestReturnDialogState extends State<RequestReturnDialog> {
  final _reasonController = TextEditingController();
  final _commentsController = TextEditingController();
  List<XFile> _photos = [];
  bool _submitting = false;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null && _photos.length < 3) {
      setState(() => _photos.add(picked));
    }
  }

  Future<void> _submitReturn() async {
    setState(() => _submitting = true);
    // Upload photos to storage (skipped for brevity, add if needed)
    final photoUrls = <String>[];
    // Save return request to Firestore
    await FirebaseFirestore.instance.collection('returns').add({
      'orderId': widget.orderId,
      'reason': _reasonController.text.trim(),
      'comments': _commentsController.text.trim(),
      'photoUrls': photoUrls,
      'status': 'requested',
      'timestamp': FieldValue.serverTimestamp(),
      // Add buyerId, sellerId if available
    });
    setState(() => _submitting = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Return request submitted.'),
        backgroundColor: AppTheme.deepTeal,
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.angel,
      title: Text('Request Return', style: AppTheme.headlineMedium),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _reasonController,
              style: AppTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: 'Reason for return',
                labelStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.cloud),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.breeze),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.cloud, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentsController,
              style: AppTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: 'Additional comments (optional)',
                labelStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.cloud),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.breeze),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.cloud, width: 2),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Text('Photos (optional, up to 3):', style: AppTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                ..._photos.map((x) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Container(
                            width: 48,
                            height: 48,
                            color: Colors.grey.shade300,
                            child: Icon(Icons.image, color: Colors.grey, size: 24),
                          )
                        : kIsWeb 
                          ? Image.network(x.path, width: 48, height: 48, fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey[200], 
                                child: const Icon(Icons.error, size: 24, color: Colors.red)
                              ))
                          : Image.file(File(x.path), width: 48, height: 48, fit: BoxFit.cover),
                  ),
                )),
                if (_photos.length < 3)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.breeze),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.add_a_photo, color: AppTheme.cloud),
                      onPressed: _pickPhoto,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: AppTheme.cloud),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submitReturn,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.deepTeal,
            foregroundColor: AppTheme.angel,
          ),
          child: _submitting ? const Text('Submitting...') : const Text('Submit'),
        ),
      ],
    );
  }
}
