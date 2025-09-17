import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import '../utils/order_utils.dart';
import '../services/whatsapp_cloud_service.dart';
import '../models/order_status.dart';
import '../services/pargo_tracking_service.dart';
import '../services/paxi_pudo_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _cartClearedOnPayment = false;

  // Add new fields for Pargo and PUDO tracking
  Map<String, dynamic>? _orderData;
  PargoPickupDetails? _pargoPickupDetails;
  Map<String, dynamic>? _pudoDeliveryDetails;
  List<TrackingEvent> _trackingTimeline = [];
  bool _isLoadingTimeline = false;

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
    _loadOrderData();
    _loadTrackingTimeline();
  }

  // Load order data
  Future<void> _loadOrderData() async {
    final orderRef = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);
    final snapshot = await orderRef.get();
    if (snapshot.exists) {
      final data = snapshot.data()!;
      setState(() {
        _orderData = data;
        
        // Load Pargo pickup details if available
        if (data['pargoPickupDetails'] != null) {
          _pargoPickupDetails = PargoPickupDetails.fromMap(data['pargoPickupDetails']);
        }
        
        // Load PUDO delivery details if available
        if (data['pudoDeliveryAddress'] != null) {
          _pudoDeliveryDetails = data['pudoDeliveryAddress'];
        }
      });
    }
  }

  // Load tracking timeline
  Future<void> _loadTrackingTimeline() async {
    setState(() {
      _isLoadingTimeline = true;
    });

    try {
      // Listen to tracking timeline
      PargoTrackingService.getOrderTimeline(widget.orderId).listen((timeline) {
        setState(() {
          _trackingTimeline = timeline;
          _isLoadingTimeline = false;
        });
      });
    } catch (e) {
      print('Error loading tracking timeline: $e');
      setState(() {
        _isLoadingTimeline = false;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        print('🔍 DEBUG: Error parsing timestamp string: $timestamp');
        return null;
      }
    } else if (timestamp is DateTime) {
      return timestamp;
    }
    
    return null;
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

  List<Map<String, dynamic>> _getOrderStatusSteps() {
    return [
      {
        'status': 'pending',
        'title': 'Order Placed',
        'description': 'Your order has been received',
        'icon': Icons.receipt_long,
      },
      {
        'status': 'confirmed',
        'title': 'Order Confirmed',
        'description': 'Seller has confirmed your order',
        'icon': Icons.check_circle_outline,
      },
      {
        'status': 'preparing',
        'title': 'Preparing',
        'description': 'Your order is being prepared',
        'icon': Icons.restaurant,
      },
      {
        'status': 'ready',
        'title': 'Ready for Pickup/Delivery',
        'description': 'Your order is ready',
        'icon': Icons.local_shipping,
      },
      {
        'status': 'shipped',
        'title': 'On the Way',
        'description': 'Your order is being delivered',
        'icon': Icons.directions_car,
      },
      {
        'status': 'delivered',
        'title': 'Delivered',
        'description': 'Order has been delivered',
        'icon': Icons.check_circle,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final orderRef = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppTheme.screenBackgroundGradient,
          color: AppTheme.whisper, // Fallback color
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: StreamBuilder<DocumentSnapshot>(
          stream: orderRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _buildErrorState();
            if (!snapshot.hasData || snapshot.data == null) return _buildLoadingState();

            final data = snapshot.data?.data() as Map<String, dynamic>?;
            if (data == null) return _buildErrorState();
            
            final currentStatus = (data['status'] as String?) ?? 'pending';
            final updates = List<Map<String, dynamic>>.from(data['trackingUpdates'] ?? []);
            final orderItems = (data['items'] as List?) ?? [];
            final total = (data['totalPrice'] ?? data['total'] ?? 0.0) as double;
            final timestamp = _parseTimestamp(data['timestamp']);

            updates.sort((a, b) {
              final ta = _parseTimestamp(a['timestamp']) ?? DateTime.now();
              final tb = _parseTimestamp(b['timestamp']) ?? DateTime.now();
              return tb.compareTo(ta); // Most recent first
            });

            // Auto-clear buyer cart once payment is confirmed/complete
            _maybeClearCartOnPayment(data);
            _maybeNotifyWhatsApp(data);

            return CustomScrollView(
              slivers: [
                // Beautiful App Bar
                _buildSliverAppBar(currentStatus, data),
                
                // Order Summary Card
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((data['deliveryMode'] as String?) == 'pudo_locker_to_door')
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.deepTeal.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.deepTeal.withOpacity(0.25), width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock, color: AppTheme.deepTeal, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Delivery: Locker-to-door (PUDO) — ${(data['pudoSpeed'] ?? 'standard').toString().toUpperCase()}, ${(data['pudoSize'] ?? 'm').toString().toUpperCase()}',
                                  style: const TextStyle(color: AppTheme.deepTeal, fontSize: 13, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      FutureBuilder<Widget>(
                        future: _buildOrderSummaryCard(data, timestamp, orderItems, total),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          return snapshot.data ?? const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
                
                // Driver Status Card (if driver is assigned)
                if ((data['driverAssigned'] as bool?) == true && data['assignedDriverId'] != null)
                  SliverToBoxAdapter(
                    child: FutureBuilder<Widget>(
                      future: _buildDriverStatusCard(data['assignedDriverId'] as String),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        return snapshot.data ?? const SizedBox.shrink();
                      },
                    ),
                  ),
                
                // Progress Timeline
                SliverToBoxAdapter(
                  child: _buildProgressTimeline(currentStatus),
                ),
                
                // Tracking Updates
                if (updates.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildTrackingUpdates(updates),
                  ),
                
                // Contact Support
                SliverToBoxAdapter(
                  child: _buildContactSupportCard(),
                ),
                
                // Add Pargo pickup section
                SliverToBoxAdapter(
                  child: _buildPargoPickupSection(),
                ),
                
                // Add PUDO delivery section
                SliverToBoxAdapter(
                  child: _buildPudoDeliverySection(),
                ),
                
                // Add tracking timeline
                SliverToBoxAdapter(
                  child: _buildTrackingTimeline(),
                ),
                
                SliverToBoxAdapter(
                  child: const SizedBox(height: 20), // Minimal bottom padding
                ),
              ],
            );
          },
        ),
      ),
      ),
    );
  }

  Future<void> _maybeClearCartOnPayment(Map<String, dynamic> data) async {
    if (_cartClearedOnPayment) return;
    final paymentStatus = (data['paymentStatus'] as String?)?.toLowerCase() ?? '';
    final status = (data['status'] as String?)?.toLowerCase() ?? '';
    final isPaid = paymentStatus == 'paid' || status == 'complete' || status == 'confirmed';
    if (!isPaid) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      // Clear Firestore cart
      final cartRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('cart');
      final items = await cartRef.get();
      final batch = FirebaseFirestore.instance.batch();
      for (final d in items.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      // Clear provider cart if context available
      if (mounted) {
        final cart = Provider.of<CartProvider>(context, listen: false);
        cart.clearCart();
        setState(() { _cartClearedOnPayment = true; });
      } else {
        _cartClearedOnPayment = true;
      }
    } catch (_) {}
  }

  bool _waNotified = false;
  Future<void> _maybeNotifyWhatsApp(Map<String, dynamic> data) async {
    if (_waNotified) return;
    final paymentStatus = (data['paymentStatus'] as String?)?.toLowerCase() ?? '';
    final status = (data['status'] as String?)?.toLowerCase() ?? '';
    final isPaid = paymentStatus == 'paid' || status == 'confirmed' || status == 'complete';
    if (!isPaid) return;
    final phone = (data['buyerPhone'] as String?)?.trim();
    if (phone == null || phone.isEmpty) return;
    
    // Use FREE wa.me method instead of paid Business API
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '27${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('27')) {
      cleanPhone = '27$cleanPhone';
    }
    
    final orderNo = (data['orderNumber'] as String?) ?? (data['orderId'] as String?) ?? widget.orderId;
    final formattedOrderNo = OrderUtils.formatOrderNumber(orderNo);
    
    // Create order confirmation message
    final message = '''✅ *Order Confirmed!*

Your order has been confirmed and is being processed!

📋 *Order Number:* $formattedOrderNo
🏪 *Store:* OmniaSA Store
💰 *Payment:* Received successfully

📱 Track your order: https://www.omniasa.co.za/#/track/$orderNo

Thank you for shopping with OmniaSA! 🛒''';

    // Use FREE wa.me URL
    final encodedMessage = Uri.encodeComponent(message);
    final waMeUrl = 'https://wa.me/$cleanPhone?text=$encodedMessage';
    
    try {
      final uri = Uri.parse(waMeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _waNotified = true;
        print('✅ WhatsApp notification sent via wa.me');
      } else {
        print('❌ Cannot launch WhatsApp URL');
      }
    } catch (e) {
      print('❌ Error launching WhatsApp: $e');
    }
  }

  Widget _buildSliverAppBar(String status, Map<String, dynamic> orderData) {
    final color = _statusColor(status);
    // Get proper order number from order data, fallback to orderId if not available
    final orderNumber = orderData['orderNumber'] ?? widget.orderId;
    print('🔍 DEBUG: Order number for app bar: $orderNumber');
    
    return SliverSafeArea(
      top: true,
      sliver: SliverAppBar(
        expandedHeight: 180,
        floating: false,
        pinned: true,
        backgroundColor: color,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () {
            print('🔙 Back button pressed');
            try {
              // Check if we can pop
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
                print('✅ Popped back successfully');
              } else {
                // If can't pop, navigate to home
                print('⚠️ Cannot pop, navigating to home');
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                );
              }
            } catch (e) {
              print('❌ Back navigation error: $e');
              // Fallback to home
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/',
                (route) => false,
              );
            }
          },
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.home, color: Colors.white, size: 20),
            onPressed: () {
              // Clear cart and navigate to home
              try {
                final cartProvider = Provider.of<CartProvider>(context, listen: false);
                cartProvider.clearCart();
                print('🧺 Cart cleared');
                
                // Navigate to home screen
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                );
                print('🏠 Navigated to home');
              } catch (e) {
                print('❌ Home navigation error: $e');
                // Fallback navigation
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                );
              }
            },
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                color.withOpacity(0.8),
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
                      'Order ${OrderUtils.formatShortOrderNumber(orderNumber)}',
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

  Future<Widget> _buildOrderSummaryCard(Map<String, dynamic> data, DateTime? timestamp, List orderItems, dynamic total) async {
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
                'Order Details',
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
            Icons.store,
            'Store',
            await _getStoreName(data['sellerId']),
          ),
          _buildInfoRow(
            Icons.shopping_bag,
            'Items',
            '${orderItems.length} item${orderItems.length != 1 ? 's' : ''}',
          ),
          _buildInfoRow(
            Icons.receipt,
            'Total',
            'R${(total is num ? total.toDouble() : 0.0).toStringAsFixed(2)}',
          ),
          // Add driver information if available
          if (data['driverAssigned'] == true && data['assignedDriverId'] != null)
            await _buildDriverInfoRow(data['assignedDriverId']),
        ],
      ),
    );
  }

  Future<Widget> _buildDriverStatusCard(String driverId) async {
    try {
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();
      
      if (driverDoc.exists) {
        final driverData = driverDoc.data();
        final driverName = driverData?['name'] ?? 'Unknown Driver';
        final String driverPhone = driverData?['phone'] ?? 'No phone available';
        final driverRating = driverData?['rating'] ?? 0.0;
        final isOnline = driverData?['isOnline'] ?? false;
        final currentLocation = driverData?['currentLocation'];
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50,
                Colors.blue.shade100,
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
                  Icon(Icons.delivery_dining, color: Colors.blue.shade700, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Driver Status',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                Icons.person,
                'Driver',
                '$driverName (${driverRating.toStringAsFixed(1)}⭐)',
              ),
              if (driverPhone != 'No phone available')
                _buildInfoRow(
                  Icons.phone,
                  'Contact',
                  driverPhone,
                ),
              if (currentLocation != null)
                _buildInfoRow(
                  Icons.location_on,
                  'Location',
                  'Driver is on the way',
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your driver will contact you when they arrive at the pickup location.',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      } else {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.delivery_dining, color: Colors.grey.shade600, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Driver assigned - details loading...',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('🔍 DEBUG: Error building driver status card: $e');
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(Icons.delivery_dining, color: Colors.grey.shade600, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Driver assigned - unable to load details',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<Widget> _buildDriverInfoRow(String driverId) async {
    try {
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();
      
      if (driverDoc.exists) {
        final driverData = driverDoc.data();
        final driverName = driverData?['name'] ?? 'Unknown Driver';
        final driverPhone = driverData?['phone'] ?? 'No phone available';
        final driverRating = driverData?['rating'] ?? 0.0;
        
        return _buildInfoRow(
          Icons.delivery_dining,
          'Driver',
          '$driverName (${driverRating.toStringAsFixed(1)}⭐)',
        );
      } else {
        return _buildInfoRow(
          Icons.delivery_dining,
          'Driver',
          'Driver assigned (ID: ${driverId.substring(0, 8)}...)',
        );
      }
    } catch (e) {
      print('🔍 DEBUG: Error fetching driver info: $e');
      return _buildInfoRow(
        Icons.delivery_dining,
        'Driver',
        'Driver assigned',
      );
    }
  }

  Future<String> _getStoreName(String? sellerId) async {
    print('🔍 DEBUG: Getting store name for sellerId: $sellerId');
    
    if (sellerId == null || sellerId.isEmpty) {
      print('🔍 DEBUG: sellerId is null or empty');
      return 'Unknown Store';
    }
    
    try {
      // First try to get the store name from the users collection
      final sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .get();
      
      print('🔍 DEBUG: Seller document exists: ${sellerDoc.exists}');
      
      if (sellerDoc.exists) {
        final sellerData = sellerDoc.data();
        final storeName = sellerData?['storeName'] ?? 'Unknown Store';
        print('🔍 DEBUG: Store name from document: $storeName');
        return storeName;
      }
      
      print('🔍 DEBUG: Seller document does not exist');
      
      // If not found in users collection, try to find by email or other fields
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: sellerId) // In case sellerId is actually an email
          .limit(1)
          .get();
      
      if (usersQuery.docs.isNotEmpty) {
        final userData = usersQuery.docs.first.data();
        final storeName = userData['storeName'] ?? 'Unknown Store';
        print('🔍 DEBUG: Found store by email query: $storeName');
        return storeName;
      }
      
      // If still not found, return a more descriptive name
      return 'Store ID: $sellerId';
    } catch (e) {
      print('🔍 DEBUG: Error fetching store name: $e');
      return 'Store ID: $sellerId';
    }
  }

  Widget _buildProgressTimeline(String currentStatus) {
    final steps = _getOrderStatusSteps();
    final currentIndex = steps.indexWhere((step) => step['status'] == currentStatus);
    
    // Handle case where current status is not in predefined steps
    final effectiveCurrentIndex = currentIndex >= 0 ? currentIndex : 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.08),
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
              Icon(Icons.timeline, color: AppTheme.deepTeal, size: 24),
              const SizedBox(width: 8),
              Text(
                'Order Progress',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isCompleted = index <= effectiveCurrentIndex;
            final isCurrent = index == effectiveCurrentIndex;
            final isLast = index == steps.length - 1;
            
            return Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline indicator
                  Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? _statusColor(step['status'])
                              : AppTheme.cloud.withOpacity(0.3),
                          shape: BoxShape.circle,
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: _statusColor(step['status']).withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          isCompleted ? Icons.check : step['icon'],
                          color: isCompleted ? AppTheme.angel : AppTheme.cloud,
                          size: 20,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 40,
                          color: isCompleted ? _statusColor(step['status']) : AppTheme.cloud.withOpacity(0.3),
                        ),
                    ],
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Step content
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step['title'],
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                              color: isCompleted
                                  ? Theme.of(context).colorScheme.onSurface
                                  : AppTheme.cloud,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            step['description'],
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isCompleted
                                  ? AppTheme.cloud
                                  : AppTheme.cloud.withOpacity(0.7),
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(height: 8),
                  Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                                color: _statusColor(step['status']).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                                'Current Status',
                      style: TextStyle(
                                  color: _statusColor(step['status']),
                        fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
                ],
              ),
            );
          }

  Widget _buildTrackingUpdates(List<Map<String, dynamic>> updates) {
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
              Icon(Icons.update, color: AppTheme.success, size: 24),
              const SizedBox(width: 8),
              Text(
                'Live Updates',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ...updates.asMap().entries.map((entry) {
            final index = entry.key;
            final update = entry.value;
            final timestamp = update['timestamp'];
            DateTime? dateTime;
            
            if (timestamp != null) {
              if (timestamp is Timestamp) {
                dateTime = timestamp.toDate();
              } else if (timestamp is String) {
                try {
                  dateTime = DateTime.parse(timestamp);
                } catch (e) {
                  print('🔍 DEBUG: Error parsing timestamp string: $timestamp');
                }
              } else if (timestamp is DateTime) {
                dateTime = timestamp;
              }
            }
            
            final formattedTime = dateTime != null
                ? DateFormat('MMM dd, yyyy • HH:mm').format(dateTime)
                : 'Unknown time';
            
            return Container(
              margin: EdgeInsets.only(bottom: index < updates.length - 1 ? 16 : 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.withOpacity(0.05),
                    Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.access_time, size: 16, color: Colors.green),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formattedTime,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (update['by'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            update['by'],
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildContactSupportCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.withOpacity(0.05),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent, color: AppTheme.deepTeal, size: 24),
              const SizedBox(width: 8),
              Text(
                'Need Help?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Have questions about your order? Our support team is here to help!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _contactSupport(),
              icon: Icon(Icons.chat),
              label: Text('Contact Support'),
              style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.deepTeal,
                        foregroundColor: AppTheme.angel,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build Pargo pickup details section
  Widget _buildPargoPickupSection() {
    if (_pargoPickupDetails == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  'Pargo Pickup Point Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Pickup point info
            _buildPickupInfoRow('📍 Location', _pargoPickupDetails!.pickupPointName),
            _buildPickupInfoRow('🏠 Address', _pargoPickupDetails!.pickupPointAddress),
            _buildPickupInfoRow('💰 Pickup Fee', 'R${_pargoPickupDetails!.pickupFee.toStringAsFixed(0)}'),
            
            if (_pargoPickupDetails!.trackingNumber != null)
              _buildPickupInfoRow('📦 Tracking', _pargoPickupDetails!.trackingNumber!),
            
            if (_pargoPickupDetails!.estimatedArrival != null)
              _buildPickupInfoRow('📅 Estimated Arrival', 
                _formatDate(_pargoPickupDetails!.estimatedArrival!)),
            
            const SizedBox(height: 16),
            
            // Collection instructions
            if (_orderData?['status'] == OrderStatus.readyForCollection.name)
              _buildCollectionInstructions(),
            
            // Collection QR code
            if (_orderData?['status'] == OrderStatus.readyForCollection.name)
              _buildCollectionQRCode(),
          ],
        ),
      ),
    );
  }

  // Build PUDO delivery details section
  Widget _buildPudoDeliverySection() {
    if (_pudoDeliveryDetails == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Text(
                  'PUDO Locker-to-Door Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // PUDO delivery info
            _buildPickupInfoRow('🏠 Final Address', _pudoDeliveryDetails!['address'] ?? 'Not specified'),
            _buildPickupInfoRow('🏙️ City', _pudoDeliveryDetails!['city'] ?? 'Not specified'),
            _buildPickupInfoRow('📱 Contact', _pudoDeliveryDetails!['phone'] ?? 'Not specified'),
            _buildPickupInfoRow('💰 Service Fee', 'R35.00'),
            
            const SizedBox(height: 16),
            
            // PUDO process info
            _buildPudoProcessInfo(),
          ],
        ),
      ),
    );
  }

  // Build pickup info row
  Widget _buildPickupInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  // Build collection instructions
  Widget _buildCollectionInstructions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'Collection Instructions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            PargoTrackingService.getCollectionInstructions(_pargoPickupDetails!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  // Build collection QR code
  Widget _buildCollectionQRCode() {
    final qrData = PargoTrackingService.generateCollectionQRData(
      widget.orderId,
      _orderData?['orderNumber'] ?? '',
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[200]!,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Collection QR Code',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 120,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Show this QR code to pickup point staff',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Build PUDO process information
  Widget _buildPudoProcessInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'PUDO Process',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1. Seller drops your package at their chosen PUDO locker\n'
            '2. PUDO collects from the locker\n'
            '3. PUDO delivers to your final address above\n'
            '4. You will receive delivery notifications',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  // Build tracking timeline
  Widget _buildTrackingTimeline() {
    if (_trackingTimeline.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Text(
                  'Tracking Timeline',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_isLoadingTimeline)
              const Center(child: CircularProgressIndicator())
            else
              ..._trackingTimeline.map((event) => _buildTimelineEvent(event)),
          ],
        ),
      ),
    );
  }

  // Build individual timeline event
  Widget _buildTimelineEvent(TrackingEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: event.status.color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: event.status.color, width: 2),
            ),
            child: Icon(
              event.status.icon,
              color: event.status.color,
              size: 20,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Event details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.status.displayName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (event.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (event.location != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        event.location!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatDate(event.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today at ${_formatTime(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${_formatTime(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago at ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month}/${date.year} at ${_formatTime(date)}';
    }
  }

  // Format time for display
  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                                        Icon(icon, size: 18, color: AppTheme.deepTeal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.deepTeal,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
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
          CircularProgressIndicator(color: AppTheme.deepTeal),
          const SizedBox(height: 16),
          Text(
            'Loading order details...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.deepTeal,
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load order details. Please try again.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.deepTeal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _contactSupport() async {
    try {
      // Get seller's contact number from order data
      String? sellerContact;
      String? sellerName;
      
      if (orderData != null) {
        sellerContact = orderData!['sellerContact']?.toString();
        sellerName = orderData!['sellerName']?.toString();
      }
      
      // Fallback to general support if no seller contact
      if (sellerContact == null || sellerContact.isEmpty) {
        sellerContact = '27693617576'; // 069 361 7576 - general support
        sellerName = 'Support';
      }
      
      // Format phone number for WhatsApp
      String phoneNumber = sellerContact;
      // Remove all non-digit characters
      String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      // If it starts with 0, replace with 27 (South Africa country code)
      if (cleaned.startsWith('0')) {
        cleaned = '27${cleaned.substring(1)}';
      }
      // If it doesn't start with 27, add it
      if (!cleaned.startsWith('27')) {
        cleaned = '27$cleaned';
      }
      
      final String message = 'Hi! I need help with my order. Order ID: ${widget.orderId}';
      final Uri whatsappUrl = Uri.parse('https://wa.me/$cleaned?text=${Uri.encodeComponent(message)}');
      
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to open WhatsApp. Please contact ${sellerName ?? 'support'} manually.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Error handling
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening WhatsApp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
