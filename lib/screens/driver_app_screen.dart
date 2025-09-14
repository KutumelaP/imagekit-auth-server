import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/delivery_fulfillment_service.dart';
import '../services/driver_authentication_service.dart';
import '../services/driver_simple_auth_service.dart';
import '../services/driver_location_service.dart';
import '../services/seller_delivery_management_service.dart';
import 'driver_login_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_action_bar.dart';

class DriverAppScreen extends StatefulWidget {
  const DriverAppScreen({Key? key}) : super(key: key);

  @override
  State<DriverAppScreen> createState() => _DriverAppScreenState();
}

class _DriverAppScreenState extends State<DriverAppScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? _driverId;
  Map<String, dynamic>? _driverData;
  Map<String, dynamic>? _driverProfile;
  List<Map<String, dynamic>> _pendingOrders = [];
  Map<String, dynamic>? _currentOrder;
  bool _isOnline = false;
  bool _isLoading = true;
  
  StreamSubscription<Position>? _locationSubscription;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _initializeDriver();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeDriver() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user - redirecting to login');
        setState(() => _isLoading = false);
        // Redirect to driver login
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const DriverLoginScreen(),
            ),
          );
        });
        return;
      }

      print('🔍 Initializing driver for user: ${user.uid}');

      // Use simple driver authentication first
      final simpleProfile = await DriverSimpleAuthService.getCurrentDriverProfile();
      
      final driverProfile = simpleProfile ?? await DriverAuthenticationService.detectDriverProfile();
      
      if (driverProfile != null) {
        print('✅ Driver profile detected: ${driverProfile['driverType']}');
        print('🔍 DEBUG: Full driver profile: $driverProfile');
        
        setState(() {
          _driverProfile = driverProfile;
          _driverId = driverProfile['driverId'];
          _driverData = driverProfile['driverData'];
          _isOnline = _driverData?['isOnline'] ?? false;
          _isLoading = false;
        });
        
        _loadPendingOrders();
        if (_isOnline) {
          _startLocationTracking();
        }
      } else {
        print('❌ No driver profile found - redirecting to login');
        setState(() => _isLoading = false);
        // Redirect to driver login
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const DriverLoginScreen(),
            ),
          );
        });
      }
    } catch (e) {
      print('❌ Error initializing driver: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPendingOrders() async {
    try {
      if (_driverProfile == null) {
        print('❌ No driver profile available');
        return;
      }

      print('🔍 DEBUG: Loading orders for driver type: ${_driverProfile!['driverType']}');
      print('🔍 DEBUG: Driver profile for order loading: $_driverProfile');
      
      // Use comprehensive order loading
      final orders = await DriverAuthenticationService.getDriverOrders(_driverProfile!);
      
      setState(() {
        _pendingOrders = orders;
      });
      
      print('✅ Loaded ${orders.length} pending orders');
      if (orders.isNotEmpty) {
        print('🔍 DEBUG: Orders found:');
        for (var order in orders) {
          print('  - Order ID: ${order['orderId']}, Status: ${order['status']}');
        }
      }
    } catch (e) {
      print('❌ Error loading pending orders: $e');
    }
  }

  void _startLocationTracking() {
    _locationTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _updateLocation();
    });
  }

  Future<void> _updateLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      
      // Update location based on driver type
      if (_driverProfile?['driverType'] == 'global') {
        await DeliveryFulfillmentService.updateDriverLocation(
          driverId: _driverId!,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } else if (_driverProfile?['driverType'] == 'seller_owned') {
        // Update seller-owned driver location
        final sellerId = _driverProfile!['sellerId'];
        final driverDocId = _driverProfile!['driverData']['driverDocId'];
        
        await _firestore
            .collection('users')
            .doc(sellerId)
            .collection('drivers')
            .doc(driverDocId)
            .update({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'lastLocationUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('🔍 DEBUG: Error updating driver location: $e');
    }
  }

  Future<void> _toggleOnlineStatus() async {
    try {
      final newStatus = !_isOnline;
      
      // Update global drivers collection if exists
      try {
        await _firestore.collection('drivers').doc(_driverId).update({
          'isOnline': newStatus,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Note: Driver not in global collection: $e');
      }

      // Update seller-owned driver status if applicable
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final sellerId = userData['linkedToSeller'];
          final driverDocId = userData['driverDocId'];
          
          if (sellerId != null && driverDocId != null) {
            await _firestore
                .collection('users')
                .doc(sellerId)
                .collection('drivers')
                .doc(driverDocId)
                .update({
              'isOnline': newStatus,
              'isAvailable': newStatus,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      setState(() {
        _isOnline = newStatus;
      });

      if (newStatus) {
        _startLocationTracking();
      } else {
        _locationTimer?.cancel();
      }
    } catch (e) {
      print('Error toggling online status: $e');
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      final success = await DeliveryFulfillmentService.driverAcceptsOrder(
        driverId: _driverId!,
        orderId: orderId,
      );

      if (success) {
        _loadPendingOrders();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order accepted successfully!')),
        );
      }
    } catch (e) {
      print('Error accepting order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting order: $e')),
      );
    }
  }

  Future<void> _rejectOrder(String orderId) async {
    try {
      // Remove driver assignment
      await _firestore.collection('orders').doc(orderId).update({
        'assignedDriverId': null,
        'driverAssigned': false,
      });

      _loadPendingOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order rejected')),
      );
    } catch (e) {
      print('Error rejecting order: $e');
    }
  }

  Future<void> _pickupOrder() async {
    if (_currentOrder == null) return;

    try {
      final success = await DeliveryFulfillmentService.driverPickedUpOrder(
        driverId: _driverId!,
        orderId: _currentOrder!['orderId'],
      );

      if (success) {
        setState(() {
          _currentOrder = null;
        });
        _loadPendingOrders();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order picked up!')),
        );
      }
    } catch (e) {
      print('Error picking up order: $e');
    }
  }

  Future<void> _deliverOrder() async {
    if (_currentOrder == null) return;

    try {
      final success = await DeliveryFulfillmentService.driverDeliveredOrder(
        driverId: _driverId!,
        orderId: _currentOrder!['orderId'],
      );

      if (success) {
        setState(() {
          _currentOrder = null;
        });
        _loadPendingOrders();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order delivered successfully!')),
        );
      }
    } catch (e) {
      print('Error delivering order: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryGreen),
              const SizedBox(height: 16),
              Text('Loading driver app...', style: AppTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    if (_driverData == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Driver Registration Required'),
          backgroundColor: AppTheme.deepTeal,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_shipping_outlined, size: 84, color: AppTheme.cloud),
                const SizedBox(height: 24),
                Text(
                  'Driver Profile Not Found',
                  style: AppTheme.headlineMedium.copyWith(
                    color: AppTheme.deepTeal,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'To use the driver app, you need to be registered as a driver.',
                  style: AppTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Contact your seller/admin to add you as a driver, or register as an independent driver.',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGrey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showDriverRegistrationDialog,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Register as Independent Driver'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.deepTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.deepTeal,
                      side: BorderSide(color: AppTheme.deepTeal),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.angel,
      appBar: AppBar(
        title: Text('Driver App', style: AppTheme.headlineSmall.copyWith(color: Colors.white)),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(
            icon: Icon(_isOnline ? Icons.circle : Icons.circle_outlined),
            onPressed: _toggleOnlineStatus,
            tooltip: _isOnline ? 'Go Offline' : 'Go Online',
            color: _isOnline ? AppTheme.success : Colors.white70,
          ),
        ],
      ),
      body: Column(
        children: [
          // Driver Status Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: AppTheme.primaryGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardElevation,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text(
                    _driverData!['name']?.substring(0, 1).toUpperCase() ?? 'D',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _driverData!['name'] ?? 'Unknown Driver',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isOnline ? '🟢 Online' : '🔴 Offline',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rating: ${(_driverData!['rating'] ?? 0.0).toStringAsFixed(1)}⭐',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isOnline,
                  onChanged: (value) => _toggleOnlineStatus(),
                  activeColor: Colors.white,
                  activeTrackColor: Colors.white.withOpacity(0.3),
                ),
              ],
            ),
          ),

          // Current Order (if any)
          if (_currentOrder != null) _buildCurrentOrderView(),

          // Pending Orders
          Expanded(
            child: _buildPendingOrdersView(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildCurrentOrderView() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.cardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warning, width: 2),
        boxShadow: AppTheme.cardElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(
                'Current Order',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Order #${_currentOrder!['orderNumber']}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('Store: ${_currentOrder!['storeName'] ?? 'Unknown Store'}'),
          Text('Customer: ${_currentOrder!['customerName'] ?? 'Unknown Customer'}'),
          Text('Total: R${_currentOrder!['totalAmount']?.toStringAsFixed(2) ?? '0.00'}'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickupOrder,
                  icon: const Icon(Icons.shopping_bag),
                  label: const Text('Pick Up'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deepTeal,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: AppTheme.deepTeal.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _deliverOrder,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Deliver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: AppTheme.success.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingOrdersView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Pending Orders (${_pendingOrders.length})',
            style: AppTheme.headlineSmall,
          ),
        ),
        Expanded(
          child: _pendingOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: AppTheme.lightGrey),
                      const SizedBox(height: 16),
                      Text(
                        'No pending orders',
                        style: AppTheme.bodyLarge.copyWith(color: AppTheme.mediumGrey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Orders will appear here when assigned',
                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.lightGrey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _pendingOrders.length,
                  itemBuilder: (context, index) {
                    final order = _pendingOrders[index];
                    return _buildOrderCard(order);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderNumber = order['orderNumber']?.toString() ?? order['orderId']?.toString().substring(0, 8) ?? 'N/A';
    final status = order['status']?.toString() ?? 'pending';
    final totalAmount = order['totalAmount']?.toDouble() ?? 0.0;
    final deliveryFee = order['deliveryFee']?.toDouble() ?? 0.0;
    final earnings = deliveryFee * 0.8;
    final itemCount = (order['items'] as List?)?.length ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppTheme.cardGradient,
          ),
          boxShadow: AppTheme.cardElevation,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with order number and status
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.deepTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          color: AppTheme.deepTeal,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #$orderNumber',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} Today',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor(status).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _getStatusDisplayText(status),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Store and Customer Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    Icons.store,
                    'Store',
                    order['storeName'] ?? 'Unknown Store',
                    Colors.blue.shade700,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.person,
                    'Customer',
                    order['customerName'] ?? 'Unknown Customer',
                    Colors.green.shade700,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.location_on,
                    'Address',
                    order['deliveryAddress'] ?? 'No address',
                    Colors.red.shade700,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Order Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildAmountCard(
                      'Items',
                      '$itemCount',
                      Icons.shopping_bag,
                      Colors.purple.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAmountCard(
                      'Total',
                      'R${totalAmount.toStringAsFixed(2)}',
                      Icons.receipt,
                      Colors.blue.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAmountCard(
                      'Your Cut',
                      'R${earnings.toStringAsFixed(2)}',
                      Icons.account_balance_wallet,
                      Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Action buttons
            _buildOrderActions(order),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountCard(String label, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusDisplayText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'NEW';
      case 'driver_assigned':
        return 'ASSIGNED';
      case 'delivery_in_progress':
        return 'IN PROGRESS';
      case 'picked_up':
        return 'PICKED UP';
      case 'out_for_delivery':
        return 'OUT FOR DELIVERY';
      case 'delivered':
        return 'DELIVERED';
      case 'completed':
        return 'COMPLETED';
      default:
        return status.toUpperCase();
    }
  }

  Widget _buildOrderActions(Map<String, dynamic> order) {
    final status = order['status']?.toString().toLowerCase() ?? 'pending';
    final orderId = order['orderId'];

    switch (status) {
      case 'pending':
        // Show Accept/Reject for truly pending orders
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _acceptOrder(orderId),
                icon: const Icon(Icons.check),
                label: const Text('Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: AppTheme.success.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _rejectOrder(orderId),
                icon: const Icon(Icons.close),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: BorderSide(color: AppTheme.error, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        );

      case 'driver_assigned':
        // Show Start Tracking for assigned orders (after seller confirmation)
        return Column(
          children: [
            // Primary action - Start Tracking
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _startTracking(orderId),
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text(
                  'Start Tracking',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.deepTeal,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: AppTheme.deepTeal.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Secondary action - Call Customer
            Container(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => _contactCustomer(order),
                icon: Icon(Icons.phone, size: 18, color: AppTheme.info),
                label: Text(
                  'Call Customer',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.info,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.info, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        );

      case 'delivery_in_progress':
      case 'picked_up':
      case 'out_for_delivery':
        // Show progress actions for in-progress orders
        return Column(
          children: [
            // Primary action - Mark Delivered
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _markDelivered(orderId),
                icon: const Icon(Icons.check_circle, size: 20),
                label: const Text(
                  'Mark Delivered',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: AppTheme.success.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Secondary action - Call Customer
            Container(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => _contactCustomer(order),
                icon: Icon(Icons.phone, size: 18, color: AppTheme.info),
                label: Text(
                  'Call Customer',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.info,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.info, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        );

      case 'delivered':
      case 'completed':
        // Show completion status with reset option for testing
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Order Completed',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      default:
        // Show status info for unknown states
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'Status: ${status.toUpperCase()}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
    }
  }

  Future<void> _contactCustomer(Map<String, dynamic> order) async {
    final customerPhone = order['customerPhone'] ?? order['phone'];
    if (customerPhone != null) {
      // You can implement phone calling here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calling customer: $customerPhone')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer phone number not available')),
      );
    }
  }

  Future<void> _markDelivered(String orderId) async {
    try {
      // Check if this is a seller-assigned order
      final order = _pendingOrders.firstWhere(
        (o) => o['orderId'] == orderId,
        orElse: () => {},
      );

      bool success = false;

      if (order['assignedBy'] == 'seller') {
        // 🚀 NEW: Handle seller-assigned order completion
        print('🔍 DEBUG: Completing seller-assigned order: $orderId');
        
        // Show OTP dialog for seller-assigned orders
        final otp = await _showOTPDialog();
        if (otp != null) {
          final result = await SellerDeliveryManagementService.completeDeliveryWithOTP(
            orderId: orderId,
            enteredOTP: otp,
            delivererId: _driverProfile?['driverData']?['name'] ?? 'Driver',
            deliveryNotes: 'Delivered by ${_driverProfile?['driverData']?['name']}',
          );
          success = result['success'] ?? false;
          
          if (!success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['message'] ?? 'Delivery completion failed')),
            );
            return;
          }
        } else {
          return; // User cancelled OTP entry
        }
      } else {
        // Handle platform-assigned order completion (existing logic)
        success = await DeliveryFulfillmentService.driverDeliveredOrder(
          driverId: _driverId!,
          orderId: orderId,
        );
      }

      if (success) {
        // 🚀 CRITICAL FIX: Stop GPS tracking when delivery is completed
        try {
          final locationService = DriverLocationService();
          await locationService.stopTracking();
          print('✅ GPS tracking stopped after delivery completion');
        } catch (e) {
          print('⚠️ Failed to stop GPS tracking: $e');
        }
        
        _loadPendingOrders();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Order delivered! GPS tracking stopped.')),
        );
      }
    } catch (e) {
      print('Error marking order as delivered: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  /// 🚀 NEW: Get earnings for seller-assigned drivers
  Future<Map<String, dynamic>> _getSellerDriverEarnings(String sellerId, String driverId) async {
    try {
      final driverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .collection('drivers')
          .doc(driverId)
          .get();
      
      final driverData = driverDoc.data() ?? {};
      
      // Calculate weekly and monthly earnings for seller drivers
      final weeklyEarnings = await _calculateSellerDriverWeeklyEarnings(sellerId, driverId);
      final monthlyEarnings = await _calculateSellerDriverMonthlyEarnings(sellerId, driverId);
      
      return {
        'totalEarnings': driverData['earnings']?.toDouble() ?? 0.0,
        'completedOrders': driverData['completedOrders'] ?? 0,
        'averageRating': driverData['rating']?.toDouble() ?? 0.0,
        'thisWeekEarnings': weeklyEarnings,
        'thisMonthEarnings': monthlyEarnings,
      };
    } catch (e) {
      print('❌ Error getting seller driver earnings: $e');
      return {
        'totalEarnings': 0.0,
        'completedOrders': 0,
        'averageRating': 0.0,
        'thisWeekEarnings': 0.0,
        'thisMonthEarnings': 0.0,
      };
    }
  }

  /// 🚀 NEW: Get delivery history for seller-assigned drivers
  Future<List<Map<String, dynamic>>> _getSellerDriverDeliveryHistory(String sellerId, String driverId) async {
    try {
      // Get delivery tasks completed by this driver
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('seller_delivery_tasks')
          .where('driverDetails.driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'delivered')
          .orderBy('completedAt', descending: true)
          .limit(20)
          .get();

      List<Map<String, dynamic>> deliveries = [];
      
      for (var taskDoc in tasksSnapshot.docs) {
        final taskData = taskDoc.data();
        final orderId = taskData['orderId'];
        
        // Get order details
        final orderDoc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .get();
        
        if (orderDoc.exists) {
          final orderData = orderDoc.data()!;
          final deliveryFee = (orderData['pricing'] as Map<String, dynamic>?)?['deliveryFee']?.toDouble() 
                           ?? orderData['deliveryFee']?.toDouble() 
                           ?? 0.0;
          final earnings = deliveryFee * 0.8;
          
          deliveries.add({
            'orderId': orderId,
            'orderNumber': orderId.substring(0, 8),
            'customerName': taskData['deliveryDetails']?['buyerName'] ?? 'Customer',
            'address': taskData['deliveryDetails']?['deliveryAddress'] ?? 'Unknown Address',
            'completedAt': taskData['completedAt'],
            'earnings': earnings,
            'status': 'delivered',
          });
        }
      }
      
      return deliveries;
    } catch (e) {
      print('❌ Error getting seller driver delivery history: $e');
      return [];
    }
  }

  /// Calculate weekly earnings for seller driver
  Future<double> _calculateSellerDriverWeeklyEarnings(String sellerId, String driverId) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartTimestamp = Timestamp.fromDate(DateTime(weekStart.year, weekStart.month, weekStart.day));
      
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('seller_delivery_tasks')
          .where('driverDetails.driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'delivered')
          .where('completedAt', isGreaterThanOrEqualTo: weekStartTimestamp)
          .get();

      double weeklyEarnings = 0.0;
      for (var taskDoc in tasksSnapshot.docs) {
        final taskData = taskDoc.data();
        final orderId = taskData['orderId'];
        
        final orderDoc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .get();
        
        if (orderDoc.exists) {
          final orderData = orderDoc.data()!;
          final deliveryFee = (orderData['pricing'] as Map<String, dynamic>?)?['deliveryFee']?.toDouble() 
                           ?? orderData['deliveryFee']?.toDouble() 
                           ?? 0.0;
          weeklyEarnings += deliveryFee * 0.8;
        }
      }
      
      return weeklyEarnings;
    } catch (e) {
      print('❌ Error calculating weekly earnings: $e');
      return 0.0;
    }
  }

  /// Calculate monthly earnings for seller driver
  Future<double> _calculateSellerDriverMonthlyEarnings(String sellerId, String driverId) async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthStartTimestamp = Timestamp.fromDate(monthStart);
      
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('seller_delivery_tasks')
          .where('driverDetails.driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'delivered')
          .where('completedAt', isGreaterThanOrEqualTo: monthStartTimestamp)
          .get();

      double monthlyEarnings = 0.0;
      for (var taskDoc in tasksSnapshot.docs) {
        final taskData = taskDoc.data();
        final orderId = taskData['orderId'];
        
        final orderDoc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .get();
        
        if (orderDoc.exists) {
          final orderData = orderDoc.data()!;
          final deliveryFee = (orderData['pricing'] as Map<String, dynamic>?)?['deliveryFee']?.toDouble() 
                           ?? orderData['deliveryFee']?.toDouble() 
                           ?? 0.0;
          monthlyEarnings += deliveryFee * 0.8;
        }
      }
      
      return monthlyEarnings;
    } catch (e) {
      print('❌ Error calculating monthly earnings: $e');
      return 0.0;
    }
  }


  /// 🚀 NEW: Show OTP dialog for seller-assigned deliveries
  Future<String?> _showOTPDialog() async {
    final otpController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Delivery OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please enter the 6-digit OTP from the customer:'),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'OTP Code',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final otp = otpController.text.trim();
              if (otp.length == 6) {
                Navigator.pop(context, otp);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
                );
              }
            },
            child: const Text('Complete Delivery'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return BottomActionBar(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        IconButton(
          onPressed: _showEarningsDialog,
          icon: const Icon(Icons.account_balance_wallet),
          tooltip: 'Earnings',
        ),
        IconButton(
          onPressed: _showProfileDialog,
          icon: const Icon(Icons.person),
          tooltip: 'Profile',
        ),
        IconButton(
          onPressed: () => _loadPendingOrders(),
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return AppTheme.warning;
      case 'driver_assigned':
        return AppTheme.info;
      case 'delivery_in_progress':
      case 'picked_up':
      case 'out_for_delivery':
        return AppTheme.primaryOrange;
      case 'delivered':
      case 'completed':
        return AppTheme.success;
      default:
        return AppTheme.mediumGrey;
    }
  }

  void _showEarningsDialog() async {
    if (_driverId == null) return;

    try {
      Map<String, dynamic> earnings = {};
      List<Map<String, dynamic>> deliveryHistory = [];
      
      // 🚀 CRITICAL FIX: Check driver type and get earnings from correct location
      if (_driverProfile?['driverType'] == 'seller_owned') {
        // For seller-assigned drivers, get earnings from seller's subcollection
        final sellerId = _driverProfile?['sellerId'];
        if (sellerId != null) {
          earnings = await _getSellerDriverEarnings(sellerId, _driverId!);
          deliveryHistory = await _getSellerDriverDeliveryHistory(sellerId, _driverId!);
          print('📊 Retrieved seller driver earnings: ${earnings['totalEarnings']}');
        } else {
          print('⚠️ Seller ID not found for seller-owned driver');
          earnings = {'totalEarnings': 0.0, 'completedOrders': 0, 'thisWeekEarnings': 0.0, 'thisMonthEarnings': 0.0};
          deliveryHistory = [];
        }
      } else {
        // For platform drivers, use existing method
        earnings = await DeliveryFulfillmentService.getDriverEarnings(_driverId!);
        deliveryHistory = await DeliveryFulfillmentService.getDriverDeliveryHistory(_driverId!);
      }
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.account_balance_wallet, color: Colors.green),
              SizedBox(width: 8),
              Text('Your Earnings'),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.6,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.analytics), text: 'Summary'),
                      Tab(icon: Icon(Icons.history), text: 'History'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Summary Tab
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildEarningsCard('This Week', 'R${earnings['thisWeekEarnings']?.toStringAsFixed(2) ?? '0.00'}', Icons.calendar_view_week, Colors.blue),
                              const SizedBox(height: 12),
                              _buildEarningsCard('This Month', 'R${earnings['thisMonthEarnings']?.toStringAsFixed(2) ?? '0.00'}', Icons.calendar_month, Colors.orange),
                              const SizedBox(height: 12),
                              _buildEarningsCard('Total Earnings', 'R${earnings['totalEarnings']?.toStringAsFixed(2) ?? '0.00'}', Icons.account_balance_wallet, Colors.green),
                              const SizedBox(height: 12),
                              _buildEarningsCard('Completed Orders', '${earnings['completedOrders'] ?? 0}', Icons.delivery_dining, Colors.purple),
                            ],
                          ),
                        ),
                        // History Tab
                        _buildDeliveryHistoryTab(deliveryHistory),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error loading earnings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading earnings: $e')),
      );
    }
  }

  Widget _buildEarningsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.bodyMedium),
          Text(value, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEarningsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodySmall.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryHistoryTab(List<Map<String, dynamic>> deliveries) {
    if (deliveries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No completed deliveries yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Your delivery history will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: deliveries.length,
      itemBuilder: (context, index) {
        final delivery = deliveries[index];
        final deliveredAt = delivery['deliveredAt']?.toDate();
        final dateString = deliveredAt != null 
            ? '${deliveredAt.day}/${deliveredAt.month}/${deliveredAt.year}'
            : 'Unknown date';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.2),
              child: const Icon(Icons.check_circle, color: Colors.green),
            ),
            title: Text(
              'Order #${delivery['orderNumber']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer: ${delivery['customerName']}'),
                Text('Date: $dateString'),
                Text('Total: R${delivery['totalAmount']?.toStringAsFixed(2) ?? '0.00'}'),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'R${delivery['earnings']?.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16,
                  ),
                ),
                const Text(
                  'earned',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Driver Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${_driverProfile?['driverType'] ?? 'Unknown'}'),
            Text('Name: ${_driverData!['name'] ?? 'Unknown'}'),
            Text('Phone: ${_driverData!['phone'] ?? 'No phone'}'),
            Text('Email: ${_driverData!['email'] ?? 'No email'}'),
            Text('Rating: ${(_driverData!['rating'] ?? 0.0).toStringAsFixed(1)}⭐'),
            Text('Vehicle: ${_driverData!['vehicle'] ?? 'No vehicle info'}'),
            Text('Status: ${_isOnline ? 'Online' : 'Offline'}'),
            if (_driverProfile?['sellerId'] != null)
              Text('Seller: ${_driverProfile!['sellerId']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDriverRegistrationDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedVehicleType = 'car';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Register as Driver'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedVehicleType,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'car', child: Text('Car')),
                  DropdownMenuItem(value: 'motorcycle', child: Text('Motorcycle')),
                  DropdownMenuItem(value: 'bicycle', child: Text('Bicycle')),
                  DropdownMenuItem(value: 'van', child: Text('Van')),
                  DropdownMenuItem(value: 'truck', child: Text('Truck')),
                ],
                onChanged: (value) => selectedVehicleType = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              
              if (name.isNotEmpty && phone.isNotEmpty) {
                Navigator.pop(context);
                await _registerAsDriver(name, phone, selectedVehicleType);
              }
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerAsDriver(String name, String phone, String vehicleType) async {
    try {
      final result = await DriverAuthenticationService.registerGlobalDriver(
        name: name,
        phone: phone,
        vehicleType: vehicleType,
      );

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Driver registration successful!'),
            backgroundColor: Colors.green,
          ),
        );
        // Reinitialize to load new driver profile
        _initializeDriver();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🚀 NEW: Start tracking delivery for assigned orders
  Future<void> _startTracking(String orderId) async {
    try {
      // Find the order
      final order = _pendingOrders.firstWhere(
        (o) => o['orderId'] == orderId,
        orElse: () => {},
      );

      if (order.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order not found')),
        );
        return;
      }

      // Check if this is a seller-assigned order
      if (order['assignedBy'] == 'seller') {
        // For seller-assigned orders, use the seller delivery service
        final result = await SellerDeliveryManagementService.startDelivery(
          orderId: orderId,
          driverName: _driverProfile?['driverData']?['name'] ?? 'Driver',
        );

        if (result['success']) {
          // 🚀 CRITICAL FIX: Start GPS location tracking when delivery tracking starts
          print('🛰️ Starting GPS location tracking for order: $orderId');
          
          try {
            final locationService = DriverLocationService();
            final trackingStarted = await locationService.startTracking(orderId);
            
            if (trackingStarted) {
              print('✅ GPS tracking started successfully');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🛰️ Delivery & GPS tracking started!'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              print('⚠️ GPS tracking failed to start');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ Delivery started but GPS tracking failed. Check location permissions.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } catch (e) {
            print('❌ GPS tracking error: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Delivery started but GPS tracking error. Check location permissions.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          
          _loadPendingOrders(); // Refresh orders to show updated status
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to start tracking: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // For platform-assigned orders, use the platform delivery service
        final success = await DeliveryFulfillmentService.driverAcceptsOrder(
          driverId: _driverId!,
          orderId: orderId,
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery tracking started!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadPendingOrders(); // Refresh orders to show updated status
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start tracking'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error starting tracking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting tracking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 