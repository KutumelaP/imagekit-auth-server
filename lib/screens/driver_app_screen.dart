import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/delivery_fulfillment_service.dart';
import '../services/driver_authentication_service.dart';
import '../services/driver_simple_auth_service.dart';
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

      print('🔍 Loading orders for driver type: ${_driverProfile!['driverType']}');
      
      // Use comprehensive order loading
      final orders = await DriverAuthenticationService.getDriverOrders(_driverProfile!);
      
      setState(() {
        _pendingOrders = orders;
      });
      
      print('✅ Loaded ${orders.length} pending orders');
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
} 