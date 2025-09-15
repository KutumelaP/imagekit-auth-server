import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../services/firebase_admin_service.dart';
import '../utils/order_utils.dart';
import 'package:flutter/services.dart';

class SellerOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const SellerOrderDetailScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<SellerOrderDetailScreen> createState() => _SellerOrderDetailScreenState();
}

class _SellerOrderDetailScreenState extends State<SellerOrderDetailScreen>
    with TickerProviderStateMixin {
  
  /// Helper function to safely parse timestamps from different formats
  DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return null;
      }
    } else if (timestamp is DateTime) {
      return timestamp;
    }
    return null;
  }
  
  final _driverNameController = TextEditingController();
  final _driverPhoneController = TextEditingController();
  final _statusNoteController = TextEditingController();
  final _trackingUpdateController = TextEditingController();
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  String? _selectedDriverId;
  bool _updating = false;
  bool _notifying = false;
  bool _addingTracking = false;
  List<Map<String, dynamic>> _savedDrivers = [];
  String? _currentOrderNumber;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _statusNoteController.dispose();
    _trackingUpdateController.dispose();
    super.dispose();
  }

  // Helper function to get appropriate icon for product category
  IconData _getCategoryIcon(String? category) {
    if (category == null) return Icons.category;
    
    switch (category.toLowerCase()) {
      case 'food':
      case 'fruits':
      case 'vegetables':
      case 'bakery':
      case 'snacks':
      case 'beverages':
      case 'dairy':
      case 'meat':
        return Icons.restaurant;
      case 'clothes':
      case 'clothing':
        return Icons.shopping_bag;
      case 'electronics':
        return Icons.devices;
      case 'home':
      case 'furniture':
        return Icons.home;
      case 'beauty':
      case 'cosmetics':
        return Icons.face;
      case 'sports':
      case 'fitness':
        return Icons.sports_soccer;
      case 'books':
      case 'education':
        return Icons.book;
      case 'other':
        return Icons.category;
      default:
        return Icons.category;
    }
  }

  Future<void> _loadSavedDrivers(String sellerId) async {
    try {
    final driversSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(sellerId)
        .collection('drivers')
        .get();
    setState(() {
      _savedDrivers = driversSnap.docs.map((d) => d.data()).toList().cast<Map<String, dynamic>>();
    });
    } catch (e) {
      print('Error loading drivers: $e');
    }
  }

  Future<void> _addTrackingUpdate(DocumentReference orderRef, String sellerName) async {
    if (_trackingUpdateController.text.trim().isEmpty) return;
    
    setState(() => _addingTracking = true);
    try {
    final update = {
      'description': _trackingUpdateController.text.trim(),
      'timestamp': DateTime.now(),
      'by': sellerName,
    };
    await orderRef.update({
      'trackingUpdates': FieldValue.arrayUnion([update])
    });
      _trackingUpdateController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tracking update added successfully'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding tracking update: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
    setState(() => _addingTracking = false);
    }
  }

  Color _statusColor(String status) {
    return AppTheme.getStatusColor(status);
  }

  IconData _statusIcon(String status) {
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

  @override
  Widget build(BuildContext context) {
    // Validate orderId before proceeding
    if (widget.orderId.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.whisper,
        appBar: AppBar(
          backgroundColor: AppTheme.error,
          foregroundColor: Colors.white,
          title: const Text('Invalid Order'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Invalid Order ID',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The order ID provided is invalid or missing.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.breeze,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final orderRef = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);
    
    return Scaffold(
      backgroundColor: AppTheme.whisper,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: StreamBuilder<DocumentSnapshot>(
        stream: orderRef.snapshots(),
        builder: (context, snapshot) {
            if (snapshot.hasError) return _buildErrorState();
            if (!snapshot.hasData || snapshot.data == null) return _buildLoadingState();
            
          final order = snapshot.data!.data()! as Map<String, dynamic>;
          final status = order['status'] as String? ?? 'pending';
          _currentOrderNumber = order['orderNumber']?.toString();
          final items = (order['items'] as List?) ?? [];
            final total = order['totalPrice'] ?? order['total'] ?? 0.0;
            final buyerName = _getCustomerName(order);
          final buyerPhone = order['buyerPhone'] ?? '';
          final deliveryAddress = order['deliveryAddress'] ?? '';
            final paymentMethod = (() {
              // Prefer new structure under payment.map
              if (order['payment'] is Map) {
                final pm = (order['payment']['method'] ?? order['payment']['gateway'] ?? '').toString();
                if (pm.isNotEmpty) return pm;
              }
              // Legacy fields
              final list = (order['paymentMethods'] as List?)?.map((e) => e.toString()).toList();
              if (list != null && list.isNotEmpty) return list.join(', ');
              final single = order['paymentMethod']?.toString();
              if (single != null && single.isNotEmpty) return single;
              return 'Not specified';
            })();
            final paymentStatus = order['paymentStatus'] ?? (order['payment']?['status'] ?? 'unpaid');
          final deliveryInstructions = order['deliveryInstructions'] ?? '';
            final timestamp = order['timestamp'] is Timestamp ? (order['timestamp'] as Timestamp).toDate() : null;
          final trackingUpdates = List<Map<String, dynamic>>.from(order['trackingUpdates'] ?? []);
          final sellerId = order['sellerId'] as String?;
          final sellerName = order['sellerName'] ?? '';

          // Extract enhanced delivery information (derive from order if missing)
          String deliveryType = order['deliveryType']?.toString().toLowerCase() ?? '';
          final orderType = order['orderType']?.toString().toLowerCase() ?? '';
          final pickupPointType = order['pickupPointType']?.toString().toLowerCase();
          if (deliveryType.isEmpty) {
            if (pickupPointType == 'paxi') deliveryType = 'paxi';
            else if (pickupPointType == 'pargo') deliveryType = 'pargo';
            else if (orderType.isNotEmpty) deliveryType = orderType;
          }

          final paxiDetails = order['paxiDetails'] as Map<String, dynamic>?;
          Map<String, dynamic>? paxiPickupPoint = order['paxiPickupPoint'] as Map<String, dynamic>?;
          final pickupPointName = order['pickupPointName'] as String?;
          final pickupPointAddress = order['pickupPointAddress'] as String?;
          if (paxiPickupPoint == null && (pickupPointName != null || pickupPointAddress != null)) {
            paxiPickupPoint = {
              if (pickupPointName != null) 'name': pickupPointName,
              if (pickupPointAddress != null) 'address': pickupPointAddress,
            };
          }
          final paxiDeliverySpeed = (order['paxiDeliverySpeed'] ?? '')?.toString() ?? '';
          final pargoPickupDetails = order['pargoPickupDetails'] as Map<String, dynamic>?;

          if (_savedDrivers.isEmpty && sellerId != null) {
            _loadSavedDrivers(sellerId);
          }

            return CustomScrollView(
              slivers: [
                // Beautiful App Bar
                _buildSliverAppBar(status),
                
                // Order Details
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Order Summary Card
                      _buildOrderSummaryCard(order, timestamp),
                      
                      // Customer Information Card
                      _buildCustomerInfoCard(buyerName, buyerPhone, deliveryAddress, deliveryInstructions),
                      
                      // Delivery Information Card (Enhanced)
                      if (deliveryType.isNotEmpty || paxiDetails != null || pargoPickupDetails != null || pickupPointName != null)
                        _buildDeliveryInfoCard(
                          deliveryType: deliveryType,
                          paxiDetails: paxiDetails,
                          paxiPickupPoint: paxiPickupPoint,
                          paxiDeliverySpeed: paxiDeliverySpeed,
                          pargoPickupDetails: pargoPickupDetails,
                          pickupPointAddress: pickupPointAddress,
                          pickupPointName: pickupPointName,
                          pickupPointType: pickupPointType,
                          deliveryAddress: deliveryAddress,
                        ),
                      
                      // Order Items Card
                      _buildOrderItemsCard(items, total),
                      
                      // Payment Information Card
                      _buildPaymentInfoCard(orderRef, order, paymentMethod, paymentStatus, total),
                      
                      // Status Management Card
                      _buildStatusManagementCard(orderRef, status, sellerName),
                      
                      // Tracking Updates Card
                      _buildTrackingUpdatesCard(orderRef, trackingUpdates, sellerName),
                      
                      const SizedBox(height: 100), // Bottom padding
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(String status) {
    return SliverSafeArea(
      top: true,
      sliver: SliverAppBar(
        expandedHeight: 180,
        floating: false,
        pinned: true,
        backgroundColor: _statusColor(status),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _statusColor(status),
                _statusColor(status).withOpacity(0.8),
              ],
            ),
          ),
          child: Stack(
              children: [
              // Background Icon
              Positioned(
                top: 60,
                right: -20,
                child: Opacity(
                  opacity: 0.1,
                  child: Icon(
                    _statusIcon(status),
                    size: 150,
                    color: Colors.white,
                  ),
                ),
              ),
              
              // Content
              Positioned(
                bottom: 60,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon(status), color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Order #${OrderUtils.formatOrderNumber(_currentOrderNumber ?? widget.orderId)}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
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
      ),
    );
  }

  Widget _buildOrderSummaryCard(Map<String, dynamic> order, DateTime? timestamp) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                Row(
                  children: [
              Icon(Icons.info_outline, color: AppTheme.primaryGreen, size: 24),
                    const SizedBox(width: 8),
              Text(
                'Order Summary',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (timestamp != null)
            _buildInfoRow(
              Icons.schedule,
              'Placed on',
              DateFormat('MMMM dd, yyyy • HH:mm').format(timestamp),
            ),
          _buildInfoRow(
            Icons.receipt_long,
            'Order Number',
            OrderUtils.formatOrderNumber(order['orderNumber']?.toString() ?? widget.orderId),
          ),
          if ((order['shippingCreditMethod'] ?? '') == 'paxi' && (order['shippingCreditAmount'] ?? 0) is num)
            _buildInfoRow(
              Icons.local_shipping,
              'Shipping Credit',
              'R${((order['shippingCreditAmount'] as num).toDouble()).toStringAsFixed(2)} • PAXI delivery (seller pays at drop-off)'
            ),
          if ((order['shippingCreditMethod'] ?? '') == 'pudo' && (order['shippingCreditAmount'] ?? 0) is num)
            _buildInfoRow(
              Icons.lock,
              'Shipping Reimbursement',
              'R${((order['shippingCreditAmount'] as num).toDouble()).toStringAsFixed(2)} • PUDO locker (prepaid wallet)'
            ),
          _buildInfoRow(
            Icons.store,
            'Store',
            order['sellerName'] ?? 'Your Store',
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoCard(String buyerName, String buyerPhone, String deliveryAddress, String deliveryInstructions) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              Text(
                'Customer Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.person_outline, 'Name', buyerName),
          if (buyerPhone.isNotEmpty)
            _buildInfoRow(Icons.phone, 'Phone', buyerPhone, isPhoneNumber: true),
                if (deliveryAddress.isNotEmpty)
            _buildInfoRow(Icons.location_on, 'Delivery Address', deliveryAddress),
          if (deliveryInstructions.isNotEmpty)
            _buildInfoRow(Icons.note, 'Special Instructions', deliveryInstructions),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfoCard({
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(deliveryIcon, color: iconColor, size: 24),
              const SizedBox(width: 8),
              Text(
                deliveryTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // PAXI Delivery Details
          if (deliveryType == 'paxi' && paxiPickupPoint != null) ...[
            _buildInfoRow(Icons.location_on, 'Pickup Point', paxiPickupPoint['name'] ?? 'PAXI Pickup Point'),
            _buildInfoRow(Icons.home, 'Address', paxiPickupPoint['address'] ?? 'Address not specified'),
            if (paxiDeliverySpeed != null && paxiDeliverySpeed.isNotEmpty)
              _buildInfoRow(
                Icons.speed, 
                'Delivery Speed', 
                paxiDeliverySpeed == 'express' ? 'Express (3-5 days)' : 'Standard (7-9 days)'
              ),
            _buildInfoRow(Icons.inventory, 'Package Size', 'Maximum 10kg'),
            _buildInfoRow(Icons.info, 'Service', 'PAXI - Reliable pickup point delivery'),
          ] else if (deliveryType == 'pargo' && pargoPickupDetails != null) ...[
            // Pargo Pickup Details
            _buildInfoRow(Icons.store, 'Pickup Point', pargoPickupDetails['pickupPointName'] ?? 'Pargo Pickup Point'),
            _buildInfoRow(Icons.home, 'Address', pargoPickupDetails['pickupPointAddress'] ?? 'Address not specified'),
            _buildInfoRow(Icons.info, 'Service', 'Pargo - Convenient pickup point delivery'),
          ] else if (deliveryType == 'pickup' && pickupPointName != null) ...[
            // Store Pickup Details
            _buildInfoRow(Icons.storefront, 'Pickup Location', pickupPointName),
            if (pickupPointAddress != null && pickupPointAddress.isNotEmpty)
              _buildInfoRow(Icons.home, 'Address', pickupPointAddress),
            _buildInfoRow(Icons.info, 'Service', 'Store Pickup - Collect from our store'),
          ] else if (deliveryType == 'delivery' && deliveryAddress != null && deliveryAddress.isNotEmpty) ...[
            // Merchant Delivery Details
            _buildInfoRow(Icons.location_on, 'Delivery Address', deliveryAddress),
            _buildInfoRow(Icons.info, 'Service', 'Merchant Delivery - We deliver to your address'),
          ] else ...[
            // Fallback for unknown delivery types
            _buildInfoRow(Icons.help_outline, 'Delivery Type', deliveryType.isNotEmpty ? deliveryType.toUpperCase() : 'Not specified'),
            if (deliveryAddress != null && deliveryAddress.isNotEmpty)
              _buildInfoRow(Icons.location_on, 'Address', deliveryAddress),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderItemsCard(List items, dynamic total) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                  Row(
                    children: [
              Icon(Icons.shopping_bag, color: Colors.orange, size: 24),
                      const SizedBox(width: 8),
              Text(
                'Order Items',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length} item${items.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value as Map<String, dynamic>;
            return Container(
              margin: EdgeInsets.only(bottom: index < items.length - 1 ? 12 : 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(item['category']),
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] ?? 'Unknown Item',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Qty: ${item['quantity'] ?? 1}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'R${((item['price'] ?? 0.0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
                  );
                }).toList(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryGreen.withOpacity(0.1), AppTheme.primaryGreen.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'R${(total is num ? total.toDouble() : 0.0).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfoCard(DocumentReference orderRef, Map<String, dynamic> order, String paymentMethod, String paymentStatus, dynamic total) {
    final isPaid = paymentStatus.toString().toLowerCase() == 'paid' || paymentStatus.toString().toLowerCase() == 'completed';
    final methods = (order['paymentMethods'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? [];
    final methodStr = paymentMethod.toString().toLowerCase();
    final isCOD = methods.any((m) => m.contains('cash')) || methodStr.contains('cod') || methodStr.contains('cash');
    final isEFT = methods.any((m) => m.contains('eft') || m.contains('bank') || m.contains('transfer'))
        || methodStr.contains('eft') || methodStr.contains('bank') || methodStr.contains('transfer');
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: Colors.purple, size: 24),
              const SizedBox(width: 8),
              Text(
                'Payment Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.credit_card, 'Payment Method', paymentMethod),
          Row(
            children: [
              Icon(Icons.account_balance_wallet, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Payment Status: ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.loose,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    paymentStatus.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPaid ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.receipt, 'Total Amount', 'R${(total is num ? total.toDouble() : 0.0).toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          if (isCOD && !isPaid)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _updating ? null : () => _markCashAsPaid(orderRef),
                icon: _updating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle),
                label: Text(_updating ? 'Updating...' : 'Mark as Paid (Cash)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          if (isEFT && !isPaid)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _updating ? null : () => _markEftAsPaid(orderRef),
                icon: _updating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_updating ? 'Updating...' : 'Mark as Paid (EFT)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _markCashAsPaid(DocumentReference orderRef) async {
    setState(() => _updating = true);
    try {
      await orderRef.update({
        'paymentStatus': 'completed',
        'codPaid': true,
        'paidAt': FieldValue.serverTimestamp(),
      });

      // Credit receivable ledger for COD so earnings reflect immediately
      try {
        final result = await FirebaseFunctions.instance.httpsCallable('markCodPaid').call({ 'orderId': orderRef.id });
        print('✅ markCodPaid succeeded: ${result.data}');
      } catch (e) {
        // Non-fatal: UI will still show paid; balance may refresh on finalize
        print('❌ markCodPaid failed: $e');
        
        // Show user that earnings calculation might be delayed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Payment marked, but earnings calculation may be delayed. Check your balance later.'),
              backgroundColor: AppTheme.warning,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      // Optional: add a timeline update for transparency
      final currentUser = FirebaseAuth.instance.currentUser;
      String sellerName = 'Seller';
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          sellerName = data['displayName'] ?? data['storeName'] ?? data['email']?.split('@')[0] ?? 'Seller';
        }
      }
      await orderRef.update({
        'trackingUpdates': FieldValue.arrayUnion([
          {
            'description': 'Cash payment received. Marked PAID.',
            'timestamp': Timestamp.now(),
            'by': sellerName,
          }
        ]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Marked as paid (cash)'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as paid: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _markEftAsPaid(DocumentReference orderRef) async {
    setState(() => _updating = true);
    try {
      await orderRef.update({
        'paymentStatus': 'completed',
        'eftPaid': true,
        'paidAt': FieldValue.serverTimestamp(),
      });

      // Create or ensure receivable entry for this paid order
      try {
        await FirebaseFunctions.instance
            .httpsCallable('createReceivableEntry')
            .call({'orderId': orderRef.id});
      } catch (e) {
        // Non-fatal: log and continue
        debugPrint('createReceivableEntry failed: $e');
      }

      // Timeline update
      final currentUser = FirebaseAuth.instance.currentUser;
      String sellerName = 'Seller';
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          sellerName = data['displayName'] ?? data['storeName'] ?? data['email']?.split('@')[0] ?? 'Seller';
        }
      }
      await orderRef.update({
        'trackingUpdates': FieldValue.arrayUnion([
          {
            'description': 'EFT received. Marked PAID.',
            'timestamp': Timestamp.now(),
            'by': sellerName,
          }
        ]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Marked as paid (EFT)'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as paid: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Widget _buildStatusManagementCard(DocumentReference orderRef, String currentStatus, String sellerName) {
    final statuses = ['pending', 'confirmed', 'preparing', 'ready', 'shipped', 'delivered'];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, color: AppTheme.primaryGreen, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Order Status Management',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Update Order Status',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statuses.map((status) {
              final isCurrentStatus = status == currentStatus;
              final color = _statusColor(status);
              
              return GestureDetector(
                onTap: isCurrentStatus ? null : () => _updateOrderStatus(orderRef, status),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isCurrentStatus
                        ? LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.1)])
                        : null,
                    color: isCurrentStatus ? null : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrentStatus ? color : Colors.grey.withOpacity(0.3),
                      width: isCurrentStatus ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _statusIcon(status),
                        size: 18,
                        color: isCurrentStatus ? color : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: isCurrentStatus ? color : Colors.grey[600],
                          fontWeight: isCurrentStatus ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      if (isCurrentStatus) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.check, size: 16, color: color),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
                          ],
                        ),
                      );
  }

  Widget _buildTrackingUpdatesCard(DocumentReference orderRef, List<Map<String, dynamic>> trackingUpdates, String sellerName) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              Text(
                'Tracking Updates',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Add New Update
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Tracking Update',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _trackingUpdateController,
                  decoration: InputDecoration(
                    hintText: 'Enter tracking update...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addingTracking ? null : () => _addTrackingUpdate(orderRef, sellerName),
                    icon: _addingTracking 
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(Icons.add),
                    label: Text(_addingTracking ? 'Adding...' : 'Add Update'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (trackingUpdates.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Update History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...trackingUpdates.asMap().entries.map((entry) {
              final index = entry.key;
              final update = entry.value;
              final timestamp = update['timestamp'];
              final parsedTimestamp = _parseTimestamp(timestamp);
              final formattedTime = parsedTimestamp != null 
                  ? DateFormat('MMM dd, yyyy • HH:mm').format(parsedTimestamp)
                  : 'Unknown time';
              
              return Container(
                margin: EdgeInsets.only(bottom: index < trackingUpdates.length - 1 ? 12 : 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.update, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          formattedTime,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            update['by'] ?? 'System',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      update['description'] ?? 'No description',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isPhoneNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                isPhoneNumber
                    ? GestureDetector(
                        onTap: () => _launchPhone(value),
                        child: Text(
                          value,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : Text(
                        value,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.primaryGreen),
          const SizedBox(height: 16),
          Text(
            'Loading order details...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
                ),
              ],
            ),
          );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error Loading Order',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load order details. Please try again.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getCustomerName(Map<String, dynamic> order) {
    // First try buyerName from order data
    if (order['buyerName'] != null && order['buyerName'].toString().isNotEmpty) {
      return order['buyerName'].toString();
    }
    // New structure: buyerDetails map
    if (order['buyerDetails'] is Map) {
      final bd = Map<String, dynamic>.from(order['buyerDetails'] as Map);
      final full = (bd['fullName'] ?? '').toString();
      if (full.isNotEmpty) return full;
      final first = (bd['firstName'] ?? '').toString();
      final last = (bd['lastName'] ?? '').toString();
      final combined = ('$first $last').trim();
      if (combined.isNotEmpty) return combined;
      final display = (bd['displayName'] ?? '').toString();
      if (display.isNotEmpty) return display;
      final emailInBd = (bd['email'] ?? '').toString();
      if (emailInBd.isNotEmpty) return emailInBd;
    }
    // Then try name field (legacy)
    if (order['name'] != null && order['name'].toString().isNotEmpty) {
      return order['name'].toString();
    }
    // Then try buyerEmail
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
    // Finally return Unknown
    return 'Unknown Customer';
  }

  Future<void> _updateOrderStatus(DocumentReference orderRef, String newStatus) async {
    setState(() => _updating = true);
    try {
      // Get order data to send notification
      final orderData = await orderRef.get();
      final orderDoc = orderData.data() as Map<String, dynamic>;
      
      // Resolve essential fields with safe fallbacks for new schema
      final buyerId = (orderDoc['buyerId'] as String?) ?? '';
      final resolvedOrderNumber = (orderDoc['orderNumber']?.toString() ?? orderDoc['orderId']?.toString() ?? orderRef.id);
      double? resolvedTotal;
      try {
        if (orderDoc['pricing'] is Map && (orderDoc['pricing']['grandTotal'] is num)) {
          resolvedTotal = (orderDoc['pricing']['grandTotal'] as num).toDouble();
        } else if (orderDoc['totalPrice'] is num) {
          resolvedTotal = (orderDoc['totalPrice'] as num).toDouble();
        } else if (orderDoc['total'] is num) {
          resolvedTotal = (orderDoc['total'] as num).toDouble();
        }
      } catch (_) {}
      
      print('🔍 Order data normalization:');
      print('  - Buyer ID: ${buyerId.isEmpty ? 'NULL' : buyerId}');
      print('  - Order Number: ${resolvedOrderNumber.isEmpty ? 'NULL' : resolvedOrderNumber}');
      print('  - Total: ${resolvedTotal ?? 'NULL'}');
      
      if (buyerId.isEmpty) {
        throw Exception('Buyer ID is missing or empty');
      }
      final currentUser = FirebaseAuth.instance.currentUser;
      
      // Get seller name for tracking update
      String sellerName = 'Seller';
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
                      'Seller';
        }
      }
      
      // 🚫 STATUS FLOW VALIDATION - Always validate status transitions BEFORE updating
      final currentStatus = orderDoc['status'] as String? ?? 'pending';
      final validTransitions = {
        'pending': ['confirmed', 'cancelled'],
        'confirmed': ['preparing', 'cancelled'],
        'preparing': ['ready', 'cancelled'],
        'ready': ['shipped', 'delivered', 'cancelled'],
        'shipped': ['delivered', 'cancelled'],
      };
      
      if (validTransitions.containsKey(currentStatus) && 
          !validTransitions[currentStatus]!.contains(newStatus.toLowerCase())) {
        final errorMessage = 'Invalid status transition: $currentStatus → $newStatus. Valid transitions: ${validTransitions[currentStatus]}';
        print('❌ $errorMessage');
        
        // Show error to user without updating the database
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        
        throw Exception(errorMessage);
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
        'trackingUpdates': FieldValue.arrayUnion([trackingUpdate])
      });
      
      // 🔔 STOCK REDUCTION LOGIC - Only reduce stock when seller confirms order fulfillment
      if (['confirmed'].contains(newStatus.toLowerCase())) {
        try {
          final items = orderDoc['items'] as List<dynamic>?;
          if (items != null && items.isNotEmpty) {
            print('📦 Processing stock reduction for ${items.length} items');
            
            // INVENTORY VALIDATION - Check if we have enough stock before reducing
            bool hasInsufficientStock = false;
            List<String> insufficientProducts = [];
            
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
              
              // Check if we have enough stock
              if (current < qty) {
                hasInsufficientStock = true;
                insufficientProducts.add('${productData['name'] ?? productId} (needs: $qty, available: $current)');
                print('❌ Insufficient stock for ${productData['name'] ?? productId}: needs $qty, available $current');
              }
            }
            
            // If insufficient stock, prevent status update and notify seller
            if (hasInsufficientStock) {
              final errorMessage = 'Cannot update status to $newStatus: Insufficient stock for:\n${insufficientProducts.join('\n')}';
              print('❌ $errorMessage');
              
              // Revert the status update
              await orderRef.update({
                'status': orderDoc['status'], // Revert to previous status
                'trackingUpdates': FieldValue.arrayUnion([{
                  'description': 'Status update failed: Insufficient stock',
                  'timestamp': Timestamp.now(),
                  'status': 'update_failed',
                  'by': sellerName,
                  'error': errorMessage,
                }])
              });
              
              throw Exception(errorMessage);
            }
            
            // STOCK REDUCTION - Proceed with reducing stock
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
              print('✅ Stock reduced for $reducedItems products in order $resolvedOrderNumber');
              
              // Add stock reduction note to tracking
              final stockUpdate = {
                'description': 'Stock reduced for $reducedItems products',
                'timestamp': Timestamp.now(),
                'status': 'stock_reduced',
                'by': sellerName,
                'previousStatus': currentStatus,
                'newStatus': newStatus,
              };
              
              await orderRef.update({
                'trackingUpdates': FieldValue.arrayUnion([stockUpdate])
              });
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
      
      // Send notification to buyer about status update
      try {
        print('🔔 Sending status update notification to buyer: $buyerId');
        print('🔔 Order ID: ${orderRef.id}');
        print('🔔 New Status: $newStatus');
        
        await FirebaseAdminService().sendOrderStatusNotification(
          userId: buyerId,
          orderId: orderRef.id,
          orderNumber: resolvedOrderNumber,
          status: newStatus,
          totalPrice: resolvedTotal ?? 0.0,
        );
        
        print('✅ Status update notification sent successfully');
        
        // Show immediate feedback to seller
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Status updated to ${newStatus.toUpperCase()} - Buyer notified'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View Order',
              textColor: Colors.white,
              onPressed: () {
                // Could navigate to order tracking or refresh the screen
              },
            ),
          ),
        );
      } catch (notificationError) {
        print('❌ Error sending status update notification: $notificationError');
        // Don't fail the entire status update if notification fails
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated but notification failed: $notificationError'),
            backgroundColor: AppTheme.warning,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to ${newStatus.toUpperCase()}'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      setState(() => _updating = false);
    }
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
} 