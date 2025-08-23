import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/delivery_fulfillment_service.dart';
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
        // Handle driver login
        return;
      }

      // Get driver data
      final driverDoc = await _firestore.collection('drivers').doc(user.uid).get();
      if (driverDoc.exists) {
        setState(() {
          _driverId = user.uid;
          _driverData = driverDoc.data();
          _isOnline = _driverData?['isOnline'] ?? false;
          _isLoading = false;
        });
        
        _loadPendingOrders();
        if (_isOnline) {
          _startLocationTracking();
        }
      } else {
        // Driver not found in database
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error initializing driver: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPendingOrders() async {
    try {
      final ordersQuery = await _firestore
          .collection('orders')
          .where('assignedDriverId', isEqualTo: _driverId)
          .where('status', whereIn: ['pending', 'confirmed', 'ready'])
          .get();

      setState(() {
        _pendingOrders = ordersQuery.docs.map((doc) {
          final data = doc.data();
          return {
            'orderId': doc.id,
            ...data,
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading pending orders: $e');
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
      await DeliveryFulfillmentService.updateDriverLocation(
        driverId: _driverId!,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  Future<void> _toggleOnlineStatus() async {
    try {
      final newStatus = !_isOnline;
      await _firestore.collection('drivers').doc(_driverId).update({
        'isOnline': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppTheme.error),
              const SizedBox(height: 16),
              Text('Driver not found', style: AppTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('Please contact admin to register as a driver', 
                   style: AppTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Driver App', style: AppTheme.headlineSmall),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isOnline ? Icons.circle : Icons.circle_outlined),
            onPressed: _toggleOnlineStatus,
            tooltip: _isOnline ? 'Go Offline' : 'Go Online',
          ),
        ],
      ),
      body: Column(
        children: [
          // Driver Status Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryGreen, AppTheme.secondaryGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
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
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _deliverOrder,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Deliver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order['orderNumber']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order['status']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order['status']?.toUpperCase() ?? 'PENDING',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(order['status']),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Store: ${order['storeName'] ?? 'Unknown Store'}'),
            Text('Customer: ${order['customerName'] ?? 'Unknown Customer'}'),
            Text('Address: ${order['deliveryAddress'] ?? 'No address'}'),
            Text('Items: ${(order['items'] as List?)?.length ?? 0} items'),
            Text('Total: R${order['totalAmount']?.toStringAsFixed(2) ?? '0.00'}'),
            Text('Delivery Fee: R${order['deliveryFee']?.toStringAsFixed(2) ?? '0.00'}'),
            Text('Your Earnings: R${((order['deliveryFee'] ?? 0) * 0.8).toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptOrder(order['orderId']),
                    icon: const Icon(Icons.check),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectOrder(order['orderId']),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: BorderSide(color: AppTheme.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'ready':
        return Colors.green;
      case 'picked_up':
        return Colors.purple;
      case 'delivered':
        return AppTheme.success;
      default:
        return AppTheme.mediumGrey;
    }
  }

  void _showEarningsDialog() async {
    if (_driverId == null) return;

    try {
      final earnings = await DeliveryFulfillmentService.getDriverEarnings(_driverId!);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Your Earnings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEarningsRow('Today', 'R${earnings['today']?.toStringAsFixed(2) ?? '0.00'}'),
              _buildEarningsRow('This Week', 'R${earnings['thisWeek']?.toStringAsFixed(2) ?? '0.00'}'),
              _buildEarningsRow('This Month', 'R${earnings['thisMonth']?.toStringAsFixed(2) ?? '0.00'}'),
              _buildEarningsRow('Total', 'R${earnings['total']?.toStringAsFixed(2) ?? '0.00'}'),
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
    } catch (e) {
      print('Error loading earnings: $e');
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

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Driver Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${_driverData!['name'] ?? 'Unknown'}'),
            Text('Phone: ${_driverData!['phone'] ?? 'No phone'}'),
            Text('Email: ${_driverData!['email'] ?? 'No email'}'),
            Text('Rating: ${(_driverData!['rating'] ?? 0.0).toStringAsFixed(1)}⭐'),
            Text('Vehicle: ${_driverData!['vehicle'] ?? 'No vehicle info'}'),
            Text('Status: ${_isOnline ? 'Online' : 'Offline'}'),
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
} 