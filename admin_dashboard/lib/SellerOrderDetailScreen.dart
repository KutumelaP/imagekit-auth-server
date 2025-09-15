import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellerOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const SellerOrderDetailScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<SellerOrderDetailScreen> createState() => _SellerOrderDetailScreenState();
}

class _SellerOrderDetailScreenState extends State<SellerOrderDetailScreen> {
  final _driverNameController = TextEditingController();
  final _driverPhoneController = TextEditingController();
  final _statusNoteController = TextEditingController();
  final _internalNoteController = TextEditingController();
  final _trackingUpdateController = TextEditingController();
  bool _updating = false;
  bool _notifying = false;
  bool _flagging = false;
  bool _addingTracking = false;

  @override
  void dispose() {
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _statusNoteController.dispose();
    _internalNoteController.dispose();
    _trackingUpdateController.dispose();
    super.dispose();
  }

  Future<void> _notifyBuyer(String message) async {
    setState(() => _notifying = true);
    try {
      // Get order data to send notification
      final orderData = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();
      
      if (!orderData.exists) {
        throw Exception('Order not found');
      }
      
      final orderDoc = orderData.data() as Map<String, dynamic>;
      final buyerId = orderDoc['buyerId'] as String?;
      final orderNumber = orderDoc['orderNumber'] as String?;
      final totalPrice = (orderDoc['totalPrice'] as num?)?.toDouble() ?? 0.0;
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
      case 'confirmed': return Colors.blueGrey;
      case 'preparing': return Colors.amber;
      case 'ready': return Colors.blue;
      case 'shipped': return Colors.purple;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getCustomerName(Map<String, dynamic> order) {
    final buyerDetails = order['buyerDetails'] as Map<String, dynamic>?;
    if (buyerDetails != null) {
      if (buyerDetails['fullName'] != null && buyerDetails['fullName'].toString().isNotEmpty) {
        return buyerDetails['fullName'].toString();
      }
      final firstName = buyerDetails['firstName']?.toString() ?? '';
      final lastName = buyerDetails['lastName']?.toString() ?? '';
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        return '$firstName $lastName'.trim();
      }
      if (buyerDetails['displayName'] != null && buyerDetails['displayName'].toString().isNotEmpty) {
        return buyerDetails['displayName'].toString();
      }
      if (buyerDetails['email'] != null && buyerDetails['email'].toString().isNotEmpty) {
        return buyerDetails['email'].toString();
      }
    }
    // Fallback to legacy fields
    if (order['buyerName'] != null && order['buyerName'].toString().isNotEmpty) {
      return order['buyerName'].toString();
    }
    if (order['name'] != null && order['name'].toString().isNotEmpty) {
      return order['name'].toString();
    }
    if (order['buyerEmail'] != null && order['buyerEmail'].toString().isNotEmpty) {
      return order['buyerEmail'].toString();
    }
    // Finally try phone (top-level or buyerDetails)
    final phoneTop = order['phone']?.toString();
    final phoneBd = (order['buyerDetails'] is Map) ? (order['buyerDetails']['phone']?.toString()) : null;
    final phone = (phoneTop != null && phoneTop.isNotEmpty) ? phoneTop : (phoneBd ?? '');
    if (phone.isNotEmpty) {
      try {
        return phone.length >= 4 ? 'Customer (${phone.substring(phone.length - 4)})' : 'Customer ($phone)';
      } catch (_) {}
    }
    return 'Unknown Customer';
  }

  @override
  Widget build(BuildContext context) {
    final orderRef = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        actions: [
          if (MediaQuery.of(context).size.width > 700)
            IconButton(
              icon: Icon(Icons.close),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: orderRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load order details.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final order = snapshot.data!.data()! as Map<String, dynamic>;
          final status = order['status'] as String? ?? 'pending';
          final items = (order['items'] as List?) ?? [];
          String productSummary = '';
          if (items.isNotEmpty) {
            if (items.length == 1) {
              final name = items[0]['name'] ?? 'Product';
              final qty = items[0]['quantity'] ?? 1;
              productSummary = '$name x$qty';
            } else {
              final name = items[0]['name'] ?? 'Product';
              final qty = items[0]['quantity'] ?? 1;
              productSummary = '$name x$qty (+${items.length - 1} more)';
            }
          }
          final total = order['totalPrice'] ?? order['total'] ?? '';
          final driver = order['driver'] as Map<String, dynamic>?;
          final buyerId = order['buyerId'] as String?;
          final buyerPhone = order['buyerPhone'] ?? '';
          final deliveryAddress = order['deliveryAddress'] ?? '';
          final paymentMethod = (order['paymentMethods'] as List?)?.join(', ') ?? '';
          final paymentStatus = order['paymentStatus'] ?? 'unpaid';
          final deliveryInstructions = order['deliveryInstructions'] ?? '';
          final platformFee = order['platformFee'] ?? 0.0;
          final sellerPayout = order['sellerPayout'] ?? (order['totalPrice'] ?? 0.0) - platformFee;
          final trackingUpdates = List<Map<String, dynamic>>.from(order['trackingUpdates'] ?? []);
          final sellerId = order['sellerId'] as String?;
          final sellerName = order['sellerName'] ?? '';
          final internalNote = order['internalNote'] ?? '';
          final ts = order['timestamp'] is Timestamp ? (order['timestamp'] as Timestamp).toDate() : null;

          // Extract enhanced delivery information
          final deliveryType = order['deliveryType']?.toString().toLowerCase() ?? '';
          final paxiDetails = order['paxiDetails'] as Map<String, dynamic>?;
          final paxiPickupPoint = order['paxiPickupPoint'] as Map<String, dynamic>?;
          final paxiDeliverySpeed = order['paxiDeliverySpeed']?.toString() ?? '';
          final pargoPickupDetails = order['pargoPickupDetails'] as Map<String, dynamic>?;
          final pickupPointAddress = order['pickupPointAddress'] as String?;
          final pickupPointName = order['pickupPointName'] as String?;
          final pickupPointType = order['pickupPointType'] as String?;

          // Change the icon for Total from Icons.attach_money to Icons.currency_exchange
          // And make driver fields always visible
          bool showDriverFields = true;

          final isWide = MediaQuery.of(context).size.width > 900;

          Widget headerSection = Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade100.withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, color: Colors.green.shade700, size: 36),
                const SizedBox(width: 18),
                Flexible(
                  child: Text(
                    productSummary.isNotEmpty ? 'Order: $productSummary' : 'Order',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 18),
                Flexible(
                  child: Chip(
                    label: Text(status.toUpperCase()),
                    backgroundColor: _statusColor(status).withOpacity(0.18),
                    labelStyle: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold, fontSize: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  ),
                ),
                const Spacer(),
                if (ts != null)
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 20, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(DateFormat('yyyy-MM-dd – kk:mm').format(ts), style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
                    ],
                  ),
              ],
            ),
          );

          Widget customerSection = Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.green.shade100,
                    child: Icon(Icons.person, color: Colors.green.shade700, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getCustomerName(order), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        if (buyerPhone.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.phone, size: 16, color: Colors.green.shade700),
                              const SizedBox(width: 4),
                              Text(buyerPhone, style: TextStyle(color: Colors.green.shade700)),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (buyerPhone.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.phone),
                      color: Colors.green.shade700,
                      onPressed: () => launchUrl(Uri.parse('tel:$buyerPhone')),
                      tooltip: 'Call Buyer',
                    ),
                ],
              );

          Widget summarySection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt, color: Colors.green.shade700, size: 24),
                  const SizedBox(width: 8),
                  const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(width: 4),
                  Flexible(child: Text('R${total is num ? total.toDouble().toStringAsFixed(2) : total}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.percent, color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  Flexible(child: Text('Platform Fee: R${platformFee.toStringAsFixed(2)}', style: TextStyle(color: Colors.deepPurple))),
                  const SizedBox(width: 16),
                  Icon(Icons.account_balance_wallet, color: Colors.teal),
                  const SizedBox(width: 8),
                  Flexible(child: Text('Net Payout: R${sellerPayout.toStringAsFixed(2)}', style: TextStyle(color: Colors.teal))),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.payment, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Flexible(child: Text('Payment: $paymentMethod (${paymentStatus.toUpperCase()})', style: TextStyle(color: Colors.blueGrey))),
                ],
              ),
              if (deliveryAddress.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 20, color: Colors.deepOrange),
                      const SizedBox(width: 8),
                      Expanded(child: Text(deliveryAddress)),
                      IconButton(
                        icon: Icon(Icons.map),
                        color: Colors.deepOrange,
                        onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(deliveryAddress)}')),
                        tooltip: 'Open in Maps',
                      ),
                    ],
                  ),
                ),
              if (deliveryInstructions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Instructions: $deliveryInstructions', style: TextStyle(color: Colors.grey)),
                ),
            ],
          );

          // Enhanced Delivery Information Section
          Widget deliverySection = _buildEnhancedDeliverySection(
            deliveryType: deliveryType,
            paxiDetails: paxiDetails,
            paxiPickupPoint: paxiPickupPoint,
            paxiDeliverySpeed: paxiDeliverySpeed,
            pargoPickupDetails: pargoPickupDetails,
            pickupPointAddress: pickupPointAddress,
            pickupPointName: pickupPointName,
            pickupPointType: pickupPointType,
            deliveryAddress: deliveryAddress,
          );

          Widget statusSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Update Status:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: status,
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                  DropdownMenuItem(value: 'preparing', child: Text('Preparing')),
                  DropdownMenuItem(value: 'ready', child: Text('Ready for Pickup/Delivery')),
                  DropdownMenuItem(value: 'shipped', child: Text('Shipped/Out for Delivery')),
                  DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: (newStatus) async {
                  if (newStatus != null && newStatus != status) {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Change Order Status'),
                        content: Text('Change status to ${newStatus.toUpperCase()}?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Change')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      setState(() => _updating = true);
                      
                      // Get seller name for tracking update
                      String sellerName = 'Admin';
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser != null) {
                        final userDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUser.uid)
                            .get();
                        if (userDoc.exists) {
                          final userData = userDoc.data() as Map<String, dynamic>;
                          sellerName = userData['displayName'] ?? 
                                      userData['storeName'] ?? 
                                      userData['email']?.split('@')[0] ?? 
                                      'Admin';
                        }
                      }
                      
                      // Create tracking update
                      final trackingUpdate = {
                        'description': 'Order status updated to ${newStatus.toUpperCase()}',
                        'timestamp': Timestamp.now(),
                        'status': newStatus,
                        'by': sellerName,
                      };
                      
                      // Update order status and add tracking update
                      await orderRef.update({
                        'status': newStatus, 
                        'statusNote': _statusNoteController.text.trim(),
                        'trackingUpdates': FieldValue.arrayUnion([trackingUpdate])
                      });
                      
                      setState(() => _updating = false);
                      await _notifyBuyer('Order status updated to $newStatus');
                      
                      // 🔔 STOCK REDUCTION LOGIC - Only reduce stock when admin confirms order fulfillment
                      if (['confirmed'].contains(newStatus.toLowerCase())) {
                        try {
                          final items = order['items'] as List<dynamic>?;
                          if (items != null && items.isNotEmpty) {
                            print('📦 Processing stock reduction for ${items.length} items');
                            
                            // Use batch write for atomic stock reduction
                            final batch = FirebaseFirestore.instance.batch();
                            int reducedItems = 0;
                            
                            for (var item in items) {
                              final itemData = item as Map<String, dynamic>;
                              final String? productId = (itemData['id'] ?? itemData['productId'])?.toString();
                              if (productId == null || productId.isEmpty) continue;
                              
                              final int qty = ((itemData['quantity'] ?? 1) as num).toInt();
                              final productRef = FirebaseFirestore.instance.collection('products').doc(productId);
                              
                              // Get current product data to check stock fields
                              final productDoc = await productRef.get();
                              if (!productDoc.exists) {
                                print('⚠️ Product $productId not found, skipping stock reduction');
                                continue;
                              }
                              
                              final productData = productDoc.data() as Map<String, dynamic>;
                              
                              // Check if product has stock tracking enabled
                              final bool hasExplicitStock = productData.containsKey('stock') || productData.containsKey('quantity');
                              if (!hasExplicitStock) {
                                print('ℹ️ Product ${productData['name'] ?? productId} has no stock tracking, skipping');
                                continue;
                              }
                              
                              // Determine which stock field to use and current value
                              int resolveStock(dynamic value) {
                                if (value is int) return value;
                                if (value is num) return value.toInt();
                                if (value is String) return int.tryParse(value) ?? 0;
                                return 0;
                              }
                              
                              // Use the same logic as UI - take the maximum of both fields
                              final int stockValue = resolveStock(productData['stock'] ?? 0);
                              final int quantityValue = resolveStock(productData['quantity'] ?? 0);
                              final int current = math.max(stockValue, quantityValue);
                              
                              final int next = (current - qty).clamp(0, 1 << 31);
                              
                            // Update both stock fields if they exist (keep them synchronized)
                            if (productData.containsKey('stock')) {
                              batch.update(productRef, {'stock': next});
                              print('📦 Reducing stock for ${productData['name'] ?? productId}: $current → $next (qty: $qty)');
                            }
                            if (productData.containsKey('quantity')) {
                              batch.update(productRef, {'quantity': next});
                              print('📦 Reducing quantity for ${productData['name'] ?? productId}: $current → $next (qty: $qty)');
                            }
                              
                              reducedItems++;
                            }
                            
                            // Commit all stock reductions atomically
                            if (reducedItems > 0) {
                              await batch.commit();
                              print('✅ Stock reduced for $reducedItems products in order ${order['orderNumber'] ?? 'unknown'}');
                            } else {
                              print('ℹ️ No products required stock reduction');
                            }
                          }
                        } catch (stockError) {
                          print('❌ Error reducing stock: $stockError');
                          // Don't fail the entire status update if stock reduction fails
                          // Just log the error and continue
                        }
                      }
                    }
                  }
                },
              ),
              TextField(
                controller: _statusNoteController,
                decoration: const InputDecoration(labelText: 'Status update note (optional)'),
              ),
              if (_updating) const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );

          Widget driverSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showDriverFields)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _driverNameController,
                      decoration: const InputDecoration(labelText: 'Driver Name'),
                    ),
                    TextField(
                      controller: _driverPhoneController,
                      decoration: const InputDecoration(labelText: 'Driver Phone'),
                      keyboardType: TextInputType.phone,
                    ),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Assign Driver'),
                                content: const Text('Assign this driver to the order?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Assign')),
                                ],
                              ),
                            );
                            if (confirmed == true && sellerId != null) {
                              setState(() => _updating = true);
                              await orderRef.update({
                                'driver': {
                                  'name': _driverNameController.text.trim(),
                                  'phone': _driverPhoneController.text.trim(),
                                }
                              });
                              setState(() => _updating = false);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Driver assigned.')));
                            }
                          },
                          child: const Text('Assign Driver'),
                        ),
                      ],
                    ),
                  ],
                ),
              if (driver != null && (driver['name']?.isNotEmpty ?? false))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Assigned Driver: ${driver['name']} (${driver['phone']})'),
                ),
            ],
          );

          Widget notesSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _internalNoteController..text = internalNote,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Add internal note (not visible to buyer)'),
                onSubmitted: (val) async {
                  await orderRef.update({'internalNote': val.trim()});
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved.')));
                },
              ),
            ],
          );

          Widget actionsSection = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _printInvoice,
                icon: Icon(Icons.print),
                label: const Text('Invoice'),
              ),
              ElevatedButton.icon(
                onPressed: _notifying ? null : () => _notifyBuyer('Order update from seller'),
                icon: Icon(Icons.notifications),
                label: _notifying ? const Text('Notifying...') : const Text('Notify Buyer'),
              ),
              ElevatedButton.icon(
                onPressed: _flagging ? null : _flagOrder,
                icon: Icon(Icons.flag),
                label: _flagging ? const Text('Flagging...') : const Text('Flag Order'),
              ),
            ],
          );

          Widget leftColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              customerSection,
              const SizedBox(height: 32),
              summarySection,
              const SizedBox(height: 32),
              Text('Order Status', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 16)),
              const SizedBox(height: 8),
              statusSection,
              const SizedBox(height: 32),
              Text('Driver', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 16)),
              const SizedBox(height: 8),
              driverSection,
              const SizedBox(height: 32),
              Text('Internal Note', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 16)),
              const SizedBox(height: 8),
              notesSection,
              const SizedBox(height: 32),
              MouseRegion(cursor: SystemMouseCursors.click, child: actionsSection),
            ],
          );

          Widget itemsSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Items', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.fastfood, size: 18, color: Colors.teal.shade400),
                          const SizedBox(width: 8),
                          Text('${item['name']} x${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          );

          Widget timelineSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order Timeline', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Vertical Stepper for tracking updates
                    ...trackingUpdates.asMap().entries.map((entry) {
                      final i = entry.key;
                      final u = entry.value;
                      final ts = u['timestamp'] is Timestamp ? (u['timestamp'] as Timestamp).toDate() : (u['timestamp'] is DateTime ? u['timestamp'] : null);
                      final by = u['by'] ?? 'system';
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              if (i < trackingUpdates.length - 1)
                                Container(
                                  width: 2,
                                  height: 32,
                                  color: Colors.blue.shade200,
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(u['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (ts != null)
                                          Text(DateFormat('yyyy-MM-dd HH:mm').format(ts), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        const SizedBox(width: 8),
                                        Text('by $by', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _trackingUpdateController,
                              decoration: const InputDecoration(labelText: 'Add tracking update'),
                            ),
                          ),
                          IconButton(
                            icon: _addingTracking ? const CircularProgressIndicator() : const Icon(Icons.add),
                            color: Colors.blue,
                            onPressed: _addingTracking || _trackingUpdateController.text.trim().isEmpty
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Add Tracking Update'),
                                        content: Text('Add this update to the order timeline?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      await _addTrackingUpdate(orderRef, sellerName);
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // --- Order History Log (Collapsible) ---
              ExpansionTile(
                title: const Text('Order History Log', style: TextStyle(fontWeight: FontWeight.bold)),
                children: [
                  // TODO: Replace with real history log if available
                  if (order['history'] is List && (order['history'] as List).isNotEmpty)
                    ...List<Map<String, dynamic>>.from(order['history']).map((h) {
                      final ts = h['timestamp'] is Timestamp ? (h['timestamp'] as Timestamp).toDate() : (h['timestamp'] is DateTime ? h['timestamp'] : null);
                      return ListTile(
                        leading: const Icon(Icons.history, color: Colors.grey),
                        title: Text(h['action'] ?? ''),
                        subtitle: ts != null ? Text(DateFormat('yyyy-MM-dd HH:mm').format(ts)) : null,
                      );
                    })
                  else
                    const ListTile(title: Text('No history available.')),
                ],
              ),
              // --- Attachments Section ---
              const SizedBox(height: 16),
              Card(
                elevation: 1,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Attachments', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      // TODO: Implement file upload and list
                      Text('No attachments yet.'),
                    ],
                  ),
                ),
              ),
            ],
          );

          Widget rightColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              itemsSection,
              const SizedBox(height: 32),
              timelineSection,
            ],
          );

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isWide) headerSection,
                  customerSection,
                  const SizedBox(height: 32),
                  summarySection,
                  const SizedBox(height: 32),
                  if (deliveryType.isNotEmpty || paxiDetails != null || pargoPickupDetails != null || pickupPointName != null) ...[
                    Text('Delivery Information', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 16)),
                    const SizedBox(height: 8),
                    deliverySection,
                    const SizedBox(height: 32),
                  ],
                  Text('Order Status', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 16)),
                  const SizedBox(height: 8),
                  statusSection,
                  const SizedBox(height: 32),
                  Text('Driver', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 16)),
                  const SizedBox(height: 8),
                  driverSection,
                  const SizedBox(height: 32),
                  Text('Internal Note', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 16)),
                  const SizedBox(height: 8),
                  notesSection,
                  const SizedBox(height: 32),
                  MouseRegion(cursor: SystemMouseCursors.click, child: actionsSection),
                  const SizedBox(height: 32),
                  itemsSection,
                  const SizedBox(height: 32),
                  timelineSection,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedDeliverySection({
    required String deliveryType,
    Map<String, dynamic>? paxiDetails,
    Map<String, dynamic>? paxiPickupPoint,
    String? paxiDeliverySpeed,
    Map<String, dynamic>? pargoPickupDetails,
    String? pickupPointAddress,
    String? pickupPointName,
    String? pickupPointType,
    String? deliveryAddress,
  }) {
    // Determine the appropriate icon and title based on delivery type
    IconData deliveryIcon;
    String deliveryTitle;
    Color iconColor;

    if (deliveryType == 'paxi') {
      deliveryIcon = Icons.local_shipping;
      deliveryTitle = '🚚 PAXI Pickup Details';
      iconColor = Colors.blue;
    } else if (deliveryType == 'pargo') {
      deliveryIcon = Icons.store;
      deliveryTitle = '📦 Pargo Pickup Details';
      iconColor = Colors.green;
    } else if (deliveryType == 'pickup') {
      deliveryIcon = Icons.storefront;
      deliveryTitle = '🏪 Store Pickup Details';
      iconColor = Colors.orange;
    } else if (deliveryType == 'delivery') {
      deliveryIcon = Icons.delivery_dining;
      deliveryTitle = '🚚 Delivery Details';
      iconColor = Colors.red;
    } else {
      deliveryIcon = Icons.info_outline;
      deliveryTitle = '📋 Delivery Information';
      iconColor = Colors.grey;
    }

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(deliveryIcon, color: iconColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  deliveryTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // PAXI Delivery Details
            if (deliveryType == 'paxi' && paxiPickupPoint != null) ...[
              _buildDeliveryInfoRow('Pickup Point', paxiPickupPoint['name'] ?? 'PAXI Pickup Point'),
              _buildDeliveryInfoRow('Address', paxiPickupPoint['address'] ?? 'Address not specified'),
              if (paxiDeliverySpeed != null && paxiDeliverySpeed.isNotEmpty)
                _buildDeliveryInfoRow(
                  'Delivery Speed', 
                  paxiDeliverySpeed == 'express' ? 'Express (3-5 days)' : 'Standard (7-9 days)'
                ),
              _buildDeliveryInfoRow('Package Size', 'Maximum 10kg'),
              _buildDeliveryInfoRow('Service', 'PAXI - Reliable pickup point delivery'),
            ] else if (deliveryType == 'pargo' && pargoPickupDetails != null) ...[
              // Pargo Pickup Details
              _buildDeliveryInfoRow('Pickup Point', pargoPickupDetails['pickupPointName'] ?? 'Pargo Pickup Point'),
              _buildDeliveryInfoRow('Address', pargoPickupDetails['pickupPointAddress'] ?? 'Address not specified'),
              _buildDeliveryInfoRow('Service', 'Pargo - Convenient pickup point delivery'),
            ] else if (deliveryType == 'pickup' && pickupPointName != null) ...[
              // Store Pickup Details
              _buildDeliveryInfoRow('Pickup Location', pickupPointName),
              if (pickupPointAddress != null && pickupPointAddress.isNotEmpty)
                _buildDeliveryInfoRow('Address', pickupPointAddress),
              _buildDeliveryInfoRow('Service', 'Store Pickup - Collect from our store'),
            ] else if (deliveryType == 'delivery' && deliveryAddress != null && deliveryAddress.isNotEmpty) ...[
              // Merchant Delivery Details
              _buildDeliveryInfoRow('Delivery Address', deliveryAddress),
              _buildDeliveryInfoRow('Service', 'Merchant Delivery - We deliver to your address'),
            ] else ...[
              // Fallback for unknown delivery types
              _buildDeliveryInfoRow('Delivery Type', deliveryType.isNotEmpty ? deliveryType.toUpperCase() : 'Not specified'),
              if (deliveryAddress != null && deliveryAddress.isNotEmpty)
                _buildDeliveryInfoRow('Address', deliveryAddress),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
} 