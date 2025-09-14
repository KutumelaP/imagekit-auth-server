import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/seller_delivery_management_service.dart';
import '../services/driver_location_service.dart';
import '../theme/app_theme.dart';
import 'live_delivery_tracking.dart';

class SellerDeliveryDashboard extends StatefulWidget {
  const SellerDeliveryDashboard({Key? key}) : super(key: key);

  @override
  State<SellerDeliveryDashboard> createState() => _SellerDeliveryDashboardState();
}

class _SellerDeliveryDashboardState extends State<SellerDeliveryDashboard> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  String? _sellerId;
  final DriverLocationService _locationService = DriverLocationService();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _sellerId = user.uid;
      await _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    if (_sellerId == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final result = await SellerDeliveryManagementService.getSellerDeliveryDashboard(_sellerId!);
      
      if (result['success']) {
        setState(() {
          _dashboardData = result;
          _isLoading = false;
        });
        
        // Debug: Show loaded tasks
        final pendingTasks = result['pendingTasks'] ?? [];
        final activeDeliveries = result['activeDeliveries'] ?? [];
        print('✅ Dashboard loaded: ${pendingTasks.length} pending tasks, ${activeDeliveries.length} active deliveries');
        
        for (final task in pendingTasks) {
          print('🔍 PENDING: ${task['orderId']} - Status: ${task['status']} - Order: ${task['orderStatus']}');
        }
        
        for (final delivery in activeDeliveries) {
          print('🔍 ACTIVE: ${delivery['orderId']} - Status: ${delivery['status']} - Order: ${delivery['orderStatus']}');
        }
        
        // 🚀 Additional debugging
        if (activeDeliveries.isEmpty && pendingTasks.isEmpty) {
          print('⚠️ NO TASKS FOUND - This suggests either:');
          print('   1. No delivery tasks exist for this seller');
          print('   2. Tasks exist but don\'t meet payment/fulfillment criteria');
          print('   3. Status filtering is too restrictive');
        }
      } else {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load delivery dashboard');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error loading dashboard: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Delivery Management'),
          backgroundColor: AppTheme.deepTeal,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.deepTeal),
        ),
      );
    }

    final pendingTasks = _dashboardData?['pendingTasks'] as List? ?? [];
    final activeDeliveries = _dashboardData?['activeDeliveries'] as List? ?? [];
    final recentDeliveries = _dashboardData?['recentDeliveries'] as List? ?? [];
    final stats = _dashboardData?['stats'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text('Delivery Management'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.person_add),
            onPressed: _showAddDriverDialog,
            tooltip: 'Add Driver',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Overview
              _buildStatsOverview(stats),
              
              SizedBox(height: 24),
              
              // Pending Delivery Tasks (needs seller action)
              _buildPendingTasksSection(pendingTasks),
              
              SizedBox(height: 24),

              // 🚀 NEW: Active Deliveries (confirmed & in progress)
              if (activeDeliveries.isNotEmpty) ...[
                _buildActiveDeliveriesSection(activeDeliveries),
                SizedBox(height: 24),
              ],
              
              // Recent Deliveries
              _buildRecentDeliveriesSection(recentDeliveries),
              
              SizedBox(height: 24),
              
              // Driver Management Section
              _buildSimpleDriverSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsOverview(Map<String, dynamic> stats) {
    final pendingCount = stats['pendingCount'] ?? 0;
    final totalDeliveries = stats['totalDeliveries'] ?? 0;
    final avgDeliveryTime = (stats['averageDeliveryTime'] ?? 0.0) as double;

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.deepTeal,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Pending',
                    pendingCount.toString(),
                    Icons.pending_actions,
                    Colors.orange,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Completed',
                    totalDeliveries.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Avg Time',
                    '${avgDeliveryTime.round()}min',
                    Icons.timer,
                    AppTheme.deepTeal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTasksSection(List pendingTasks) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping, color: AppTheme.deepTeal),
                SizedBox(width: 8),
                Text(
                  'Pending Deliveries',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepTeal,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            if (pendingTasks.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No delivery tasks ready',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Orders will appear here when they are paid and ready for delivery',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: pendingTasks.length,
                separatorBuilder: (context, index) => Divider(),
                itemBuilder: (context, index) {
                  final task = pendingTasks[index];
                  return _buildPendingTaskCard(task);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingTaskCard(Map<String, dynamic> task) {
    final orderId = task['orderId'] ?? '';
    final status = task['status'] ?? '';
    final deliveryDetails = task['deliveryDetails'] as Map<String, dynamic>? ?? {};
    final productInstructions = task['productHandlingInstructions'] as Map<String, dynamic>? ?? {};
    final otp = task['deliveryOTP'] ?? '';
    

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.whisper.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.deepTeal.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${orderId.substring(0, 8).toUpperCase()}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepTeal,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        if (task['orderStatus'] != null) ...[
                          Icon(Icons.receipt_long, size: 14, color: Colors.green),
                          SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              '${task['orderStatus']?.toString().toUpperCase()}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8),
                        ],
                        if (task['paymentStatus'] != null) ...[
                          Icon(Icons.payment, size: 14, color: Colors.blue),
                          SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              '${task['paymentStatus']?.toString().toUpperCase()}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              _buildStatusChip(status),
            ],
          ),
          
          SizedBox(height: 8),
          
          // Customer Details
          if (deliveryDetails['buyerName'] != null)
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Customer: ${deliveryDetails['buyerName']}',
                    style: TextStyle(color: Colors.grey[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          
          if (deliveryDetails['address'] != null && deliveryDetails['address'].toString().isNotEmpty)
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    deliveryDetails['address'],
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          
          // Phone number row with missing phone warning
          Row(
            children: [
              Icon(Icons.phone, size: 16, color: Colors.grey[600]),
              SizedBox(width: 4),
              Expanded(
                child: deliveryDetails['buyerPhone'] != null && deliveryDetails['buyerPhone'].toString().isNotEmpty
                  ? Text(
                      deliveryDetails['buyerPhone'],
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    )
                  : Row(
                      children: [
                        Text(
                          'No phone number',
                          style: TextStyle(color: Colors.orange[700], fontSize: 13),
                        ),
                        SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showAddPhoneDialog(task),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Add',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
              ),
            ],
          ),
          
          // Product Instructions
          if (productInstructions['generalInstructions'] != null)
            Container(
              margin: EdgeInsets.only(top: 8),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.amber[700]),
                      SizedBox(width: 4),
                      Text(
                        'Special Instructions:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  ...(productInstructions['generalInstructions'] as List?)
                      ?.cast<String>()
                      .map((instruction) => Text(
                        '• $instruction',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber[800],
                        ),
                      ))
                      .toList() ?? [],
                ],
              ),
            ),
          
          SizedBox(height: 12),
          
          // OTP Display
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.deepTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.security, color: AppTheme.deepTeal, size: 16),
                SizedBox(width: 8),
                Text(
                  'Delivery OTP: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  otp,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepTeal,
                    fontSize: 16,
                  ),
                ),
                Spacer(),
                TextButton(
                  onPressed: () => _copyToClipboard(otp),
                  child: Text('Copy'),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 12),
          
          // Action Buttons
          Row(
            children: [
              if (status == 'pending_seller_action')
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showConfirmDeliveryDialog(task),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.deepTeal,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Confirm Delivery'),
                  ),
                ),
              
              
              if (status != 'delivery_in_progress')
                SizedBox(width: 8),
              
              if (status != 'delivery_in_progress')
                OutlinedButton(
                  onPressed: () => _showTaskDetails(task),
                  child: Text('Details'),
                ),
            ],
          ),
          
          // Full-width delivery tracking buttons (positioned at bottom)
          if (status == 'delivery_in_progress') ...[
            SizedBox(height: 12),
            // Track button (full card width)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showTrackingDialog(orderId),
                icon: Icon(Icons.location_pin, color: AppTheme.deepTeal, size: 18),
                label: Text('Track Live Location', style: TextStyle(color: AppTheme.deepTeal)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.deepTeal),
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            SizedBox(height: 8),
            // Complete Delivery button (full card width)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCompleteDeliveryDialog(task),
                icon: Icon(Icons.check_circle, size: 18),
                label: Text('Complete Delivery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    
    switch (status) {
      case 'pending_seller_action':
        color = Colors.orange;
        label = 'Action Required';
        break;
      case 'confirmed_by_seller':
        color = Colors.blue;
        label = 'Confirmed';
        break;
      case 'delivery_in_progress':
        color = Colors.green;
        label = 'In Progress';
        break;
      default:
        color = Colors.grey;
        label = status.replaceAll('_', ' ').toUpperCase();
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActiveDeliveriesSection(List activeDeliveries) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.delivery_dining, color: AppTheme.primaryOrange),
                SizedBox(width: 8),
                Text(
                  'Active Deliveries',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryOrange,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${activeDeliveries.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: activeDeliveries.length,
              separatorBuilder: (context, index) => Divider(),
              itemBuilder: (context, index) {
                final delivery = activeDeliveries[index];
                return _buildActiveDeliveryCard(delivery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDeliveryCard(Map<String, dynamic> delivery) {
    final orderId = delivery['orderId'] ?? '';
    final status = delivery['status'] ?? '';
    final deliveryDetails = delivery['deliveryDetails'] as Map<String, dynamic>? ?? {};
    final driverDetails = delivery['driverDetails'] as Map<String, dynamic>? ?? {};
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order #${orderId.substring(0, 8).toUpperCase()}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepTeal,
                  ),
                ),
              ),
              _buildStatusChip(status),
            ],
          ),
          
          SizedBox(height: 8),
          
          // Customer & Driver Info
          if (deliveryDetails['buyerName'] != null)
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Customer: ${deliveryDetails['buyerName']}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          
          if (driverDetails['name'] != null)
            Row(
              children: [
                Icon(Icons.local_shipping, size: 16, color: AppTheme.primaryOrange),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Driver: ${driverDetails['name']}',
                    style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          
          SizedBox(height: 12),
          
          // Action Buttons for Active Deliveries
          Row(
            children: [
              
              if (status == 'delivery_in_progress') ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showTrackingDialog(orderId),
                    icon: Icon(Icons.location_pin, size: 16),
                    label: Text('Track'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryOrange,
                      side: BorderSide(color: AppTheme.primaryOrange),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showCompleteDeliveryDialog(delivery),
                    icon: Icon(Icons.check_circle, size: 16),
                    label: Text('Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
              
              if (!['confirmed_by_seller', 'delivery_in_progress'].contains(status))
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showTaskDetails(delivery),
                    child: Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.deepTeal,
                      side: BorderSide(color: AppTheme.deepTeal),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDeliveriesSection(List recentDeliveries) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: AppTheme.deepTeal),
                SizedBox(width: 8),
                Text(
                  'Recent Deliveries',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepTeal,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            if (recentDeliveries.isEmpty)
              Center(
                child: Text(
                  'No recent deliveries',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: recentDeliveries.length,
                separatorBuilder: (context, index) => Divider(),
                itemBuilder: (context, index) {
                  final delivery = recentDeliveries[index];
                  return _buildRecentDeliveryCard(delivery);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentDeliveryCard(Map<String, dynamic> delivery) {
    final orderId = delivery['orderId'] ?? '';
    final completedAt = delivery['completedAt'] as Timestamp?;
    final deliveryMethod = delivery['actualDeliveryMethod'] ?? 'Unknown';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green.withOpacity(0.2),
        child: Icon(Icons.check, color: Colors.green),
      ),
      title: Text('Order #${orderId.substring(0, 8).toUpperCase()}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Method: ${deliveryMethod.replaceAll('_', ' ')}'),
          if (completedAt != null)
            Text(
              'Completed: ${_formatDateTime(completedAt.toDate())}',
              style: TextStyle(fontSize: 12),
            ),
        ],
      ),
      trailing: Icon(Icons.chevron_right),
      onTap: () => _showDeliveryHistory(delivery),
    );
  }

  // Action Methods

  void _showConfirmDeliveryDialog(Map<String, dynamic> task) {
    final orderId = task['orderId'];
    
    showDialog(
      context: context,
      builder: (context) => _ConfirmDeliveryDialog(
        orderId: orderId,
        sellerId: _sellerId!,
        onConfirmed: () {
          Navigator.of(context).pop();
          setState(() {
            task['status'] = 'confirmed_by_seller';
          });
          _showSuccessSnackBar('Delivery confirmed. Driver will start tracking from their app.');
          _loadDashboardData();
        },
      ),
    );
  }

  void _showCompleteDeliveryDialog(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (context) => _CompleteDeliveryDialog(
        task: task,
        onCompleted: () {
          Navigator.of(context).pop();
          _loadDashboardData();
        },
      ),
    );
  }

  void _showTaskDetails(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (context) => _TaskDetailsDialog(task: task),
    );
  }

  void _showTrackingDialog(String orderId) {
    // Find the task to get delivery address - check both pending and active deliveries
    final pendingTasks = (_dashboardData?['pendingTasks'] as List?) ?? [];
    final activeDeliveries = (_dashboardData?['activeDeliveries'] as List?) ?? [];
    final allTasks = [...pendingTasks, ...activeDeliveries];
    
    final task = allTasks.isNotEmpty 
        ? allTasks.firstWhere(
            (t) => t['orderId'] == orderId,
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};
    
    // 🚀 DEBUG: Check what's in deliveryDetails
    print('🔍 TRACKING DIALOG DEBUG for $orderId:');
    print('   - Task found: ${task.isNotEmpty}');
    if (task.isNotEmpty) {
      print('   - Task keys: ${task.keys.toList()}');
      final deliveryDetails = task['deliveryDetails'];
      print('   - DeliveryDetails: $deliveryDetails');
      if (deliveryDetails != null) {
        print('   - DeliveryDetails keys: ${(deliveryDetails as Map).keys.toList()}');
      }
    }
    
    // Try multiple possible field names for the delivery address
    final deliveryDetails = task['deliveryDetails'] as Map<String, dynamic>?;
    final deliveryAddress = deliveryDetails?['address'] 
                         ?? deliveryDetails?['deliveryAddress'] 
                         ?? deliveryDetails?['buyerAddress']
                         ?? deliveryDetails?['fullAddress']
                         ?? 'Unknown address';
    final coordinates = deliveryDetails?['coordinates'] 
                     ?? deliveryDetails?['deliveryCoordinates'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.location_pin, color: Colors.teal),
            SizedBox(width: 8),
            Flexible(child: Text('Live Delivery Tracking')),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.5,
          child: LiveDeliveryTracking(
            orderId: orderId,
            deliveryAddress: deliveryAddress,
            deliveryCoordinates: coordinates,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }
  
  void _showAddPhoneDialog(Map<String, dynamic> task) {
    final phoneController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Customer Phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add phone number for this customer:'),
            SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixText: '+27 ',
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final phone = phoneController.text.trim();
              if (phone.isNotEmpty) {
                await _addPhoneToTask(task['orderId'], phone);
                Navigator.of(context).pop();
                _loadDashboardData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.deepTeal,
              foregroundColor: Colors.white,
            ),
            child: Text('Add Phone'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPhoneToTask(String orderId, String phone) async {
    try {
      // Update the seller delivery task with the phone number
      await FirebaseFirestore.instance
          .collection('seller_delivery_tasks')
          .doc(orderId)
          .update({
        'deliveryDetails.buyerPhone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      _showSuccessSnackBar('Phone number added successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to add phone number: $e');
    }
  }

  void _showDeliveryHistory(Map<String, dynamic> delivery) {
    showDialog(
      context: context,
      builder: (context) => _DeliveryHistoryDialog(delivery: delivery),
    );
  }

  void _copyToClipboard(String text) {
    // In a real app, you'd use Clipboard.setData()
    _showSuccessSnackBar('OTP copied to clipboard!');
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showAddDriverDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Driver'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Driver Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              
              if (name.isNotEmpty && phone.isNotEmpty) {
                await _addDriver(name, phone);
                Navigator.pop(context);
              } else {
                _showErrorSnackBar('Please fill in both name and phone');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.deepTeal,
              foregroundColor: Colors.white,
            ),
            child: Text('Add Driver'),
          ),
        ],
      ),
    );
  }

  Future<void> _addDriver(String name, String phone) async {
    try {
      print('🔍 Adding driver - sellerId: $_sellerId, name: $name, phone: $phone');
      
      final driverData = {
        'name': name,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'isAvailable': true,
        'isOnline': false,
      };
      
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(_sellerId)
          .collection('drivers')
          .add(driverData);
      
      print('✅ Driver added successfully with ID: ${docRef.id}');
      _showSuccessSnackBar('Driver "$name" added successfully!');
      
    } catch (e) {
      print('❌ Failed to add driver: $e');
      _showErrorSnackBar('Failed to add driver: $e');
    }
  }

  void _showDeleteDriverDialog(String driverId, String driverName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Driver'),
        content: Text('Are you sure you want to delete $driverName? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDriver(driverId, driverName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDriver(String driverId, String driverName) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_sellerId)
          .collection('drivers')
          .doc(driverId)
          .delete();
      
      _showSuccessSnackBar('$driverName deleted successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to delete driver: $e');
    }
  }

  Widget _buildSimpleDriverSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Driver Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.deepTeal,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Use + button above to add drivers',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Your saved drivers will appear here and can be assigned to delivery tasks.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cloud.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.cloud.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.deepTeal,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Driver Login Instructions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepTeal,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tell your drivers to:\n'
                    '• Download the app and tap "Driver App"\n'
                    '• Login using their NAME as username\n'
                    '• Login using their PHONE as password\n'
                    '• Use the exact name and phone you entered above',
                    style: TextStyle(
                      color: AppTheme.darkGrey,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            if (_sellerId == null) ...[
              Text(
                'Sign in required to view drivers',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ] else ...[
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(_sellerId)
                    .collection('drivers')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(color: AppTheme.deepTeal),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.person_add, color: AppTheme.primaryOrange, size: 32),
                          SizedBox(height: 8),
                          Text(
                            'No drivers yet',
                            style: TextStyle(
                              color: AppTheme.primaryOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Add your first driver to start assigning deliveries',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _showAddDriverDialog,
                            icon: Icon(Icons.add, size: 18),
                            label: Text('Add Driver'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryOrange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => Divider(height: 12),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '').toString();
                      final phone = (data['phone'] ?? '').toString();
                      final status = (data['status'] ?? 'active').toString();

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.deepTeal,
                          child: Icon(Icons.person, color: Colors.white, size: 18),
                        ),
                        title: Text(
                          name.isNotEmpty ? name : 'Unnamed Driver',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: phone.isNotEmpty ? Text(phone) : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (status == 'active' ? Colors.green : Colors.grey).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: status == 'active' ? Colors.green : Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () => _showDeleteDriverDialog(docs[index].id, name),
                              padding: EdgeInsets.all(4),
                              constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Confirm Delivery Dialog
class _ConfirmDeliveryDialog extends StatefulWidget {
  final String orderId;
  final String sellerId;
  final VoidCallback onConfirmed;

  const _ConfirmDeliveryDialog({
    required this.orderId,
    required this.sellerId,
    required this.onConfirmed,
  });

  @override
  State<_ConfirmDeliveryDialog> createState() => _ConfirmDeliveryDialogState();
}

class _ConfirmDeliveryDialogState extends State<_ConfirmDeliveryDialog> {
  String _selectedMethod = 'own_driver';
  final _driverNameController = TextEditingController();
  final _driverPhoneController = TextEditingController();
  final _estimatedTimeController = TextEditingController();
  bool _isLoading = false;
  String? _selectedDriverId;
  Map<String, dynamic>? _selectedDriver;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Confirm Delivery Method'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedMethod,
              decoration: InputDecoration(labelText: 'Delivery Method'),
              items: [
                DropdownMenuItem(value: 'own_driver', child: Text('My own driver')),
                DropdownMenuItem(value: 'taxi', child: Text('Taxi/Uber/Bolt')),
                DropdownMenuItem(value: 'family_friend', child: Text('Family/Friend')),
                DropdownMenuItem(value: 'third_party_service', child: Text('Third-party service')),
              ],
              onChanged: (value) => setState(() => _selectedMethod = value!),
            ),
            SizedBox(height: 16),
            // Driver Selection Section
            if (_selectedMethod == 'own_driver') ...[
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.sellerId)
                    .collection('drivers')
                    .where('status', isEqualTo: 'active')
                    .snapshots(),
                builder: (context, snapshot) {
                  // 🚀 ENHANCED: Better debugging and error handling
                  print('🔍 Driver dropdown StreamBuilder state: ${snapshot.connectionState}');
                  
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Loading drivers...', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    print('❌ Driver query error: ${snapshot.error}');
                    return Column(
                      children: [
                        Text(
                          'Error loading drivers: ${snapshot.error}',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _driverNameController,
                          decoration: InputDecoration(labelText: 'Driver Name (Manual Entry)'),
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _driverPhoneController,
                          decoration: InputDecoration(labelText: 'Driver Phone'),
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    );
                  }

                  final drivers = snapshot.data?.docs ?? [];
                  print('🔍 Found ${drivers.length} drivers for seller ${widget.sellerId}');
                  
                  if (drivers.isEmpty) {
                    return Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                              SizedBox(height: 4),
                              Text(
                                'No drivers found',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Add drivers using the + button above, then try again.',
                                style: TextStyle(color: Colors.orange[600], fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        Text('Or enter driver details manually:', 
                             style: TextStyle(fontWeight: FontWeight.w500)),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _driverNameController,
                          decoration: InputDecoration(
                            labelText: 'Driver Name (Manual Entry)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _driverPhoneController,
                          decoration: InputDecoration(
                            labelText: 'Driver Phone',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select Driver:', style: TextStyle(fontWeight: FontWeight.w500)),
                      SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedDriverId,
                        decoration: InputDecoration(
                          labelText: 'Choose Driver',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text('Manual Entry'),
                          ),
                          ...drivers.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = data['name'] ?? 'Unnamed';
                            final phone = data['phone'] ?? '';
                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text('$name${phone.isNotEmpty ? ' ($phone)' : ''}'),
                            );
                          }).toList(),
                        ],
                        onChanged: (String? driverId) {
                          setState(() {
                            _selectedDriverId = driverId;
                            if (driverId != null) {
                              _selectedDriver = drivers
                                  .firstWhere((doc) => doc.id == driverId)
                                  .data() as Map<String, dynamic>;
                              _driverNameController.text = _selectedDriver!['name'] ?? '';
                              _driverPhoneController.text = _selectedDriver!['phone'] ?? '';
                            } else {
                              _selectedDriver = null;
                              _driverNameController.clear();
                              _driverPhoneController.clear();
                            }
                          });
                        },
                      ),
                      SizedBox(height: 16),
                      if (_selectedDriverId == null) ...[
                        TextFormField(
                          controller: _driverNameController,
                          decoration: InputDecoration(labelText: 'Driver Name'),
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _driverPhoneController,
                          decoration: InputDecoration(labelText: 'Driver Phone'),
                          keyboardType: TextInputType.phone,
                        ),
                      ] else ...[
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Selected Driver:', style: TextStyle(fontWeight: FontWeight.w500)),
                              SizedBox(height: 4),
                              Text('Name: ${_selectedDriver!['name'] ?? 'N/A'}'),
                              if (_selectedDriver!['phone']?.isNotEmpty == true)
                                Text('Phone: ${_selectedDriver!['phone']}'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ] else ...[
              TextFormField(
                controller: _driverNameController,
                decoration: InputDecoration(labelText: 'Driver Name'),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _driverPhoneController,
                decoration: InputDecoration(labelText: 'Driver Phone (Optional)'),
                keyboardType: TextInputType.phone,
              ),
            ],
            SizedBox(height: 16),
            TextFormField(
              controller: _estimatedTimeController,
              decoration: InputDecoration(
                labelText: 'Estimated Delivery Time',
                hintText: 'e.g., 30 minutes, 1 hour',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _confirmDelivery,
          child: _isLoading 
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Confirm'),
        ),
      ],
    );
  }

  Future<void> _confirmDelivery() async {
    if (_driverNameController.text.trim().isEmpty || 
        _estimatedTimeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Debug: Check dialog parameters before calling service
      print('🔍 DIALOG DEBUG - Parameters before service call:');
      print('  widget.orderId: ${widget.orderId} (${widget.orderId.runtimeType})');
      print('  widget.sellerId: ${widget.sellerId} (${widget.sellerId.runtimeType})');
      print('  _selectedMethod: $_selectedMethod ($_selectedMethod.runtimeType)');
      print('  _driverNameController.text: "${_driverNameController.text.trim()}"');
      print('  _driverPhoneController.text: "${_driverPhoneController.text.trim()}"');
      print('  _estimatedTimeController.text: "${_estimatedTimeController.text.trim()}"');
      print('  _selectedDriverId: $_selectedDriverId');
      
      final result = await SellerDeliveryManagementService.sellerConfirmDelivery(
        orderId: widget.orderId,
        sellerId: widget.sellerId,
        deliveryMethod: _selectedMethod,
        driverDetails: {
          'driverId': _selectedDriverId,
          'name': _driverNameController.text.trim(),
          'phone': _driverPhoneController.text.trim(),
        },
        estimatedDeliveryTime: _estimatedTimeController.text.trim(),
      );

      if (result['success']) {
        widget.onConfirmed();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to confirm delivery')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// Complete Delivery Dialog
class _CompleteDeliveryDialog extends StatefulWidget {
  final Map<String, dynamic> task;
  final VoidCallback onCompleted;

  const _CompleteDeliveryDialog({
    required this.task,
    required this.onCompleted,
  });

  @override
  State<_CompleteDeliveryDialog> createState() => _CompleteDeliveryDialogState();
}

class _CompleteDeliveryDialogState extends State<_CompleteDeliveryDialog> {
  final _otpController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  final DriverLocationService _locationService = DriverLocationService();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Complete Delivery'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Enter the OTP provided by the customer:'),
          SizedBox(height: 16),
          TextFormField(
            controller: _otpController,
            decoration: InputDecoration(
              labelText: 'Customer OTP',
              hintText: 'Enter 6-digit code',
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Delivery Notes (Optional)',
              hintText: 'Any additional notes...',
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _completeDelivery,
          child: _isLoading 
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Complete'),
        ),
      ],
    );
  }

  Future<void> _completeDelivery() async {
    if (_otpController.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await SellerDeliveryManagementService.completeDeliveryWithOTP(
        orderId: widget.task['orderId'],
        enteredOTP: _otpController.text.trim(),
        delivererId: widget.task['driverDetails']?['name'] ?? 'Unknown Driver',
        deliveryNotes: _notesController.text.trim(),
      );

      if (result['success']) {
        // Stop GPS tracking when delivery is completed
        await _locationService.stopTracking();
        
        widget.onCompleted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Delivery completed! GPS tracking stopped.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to complete delivery')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// Task Details Dialog
class _TaskDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> task;

  const _TaskDetailsDialog({required this.task});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Task Details'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ID: ${task['orderId']}'),
            Text('Status: ${task['status']}'),
            Text('OTP: ${task['deliveryOTP']}'),
            // Add more details as needed
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }
}

// Delivery History Dialog
class _DeliveryHistoryDialog extends StatelessWidget {
  final Map<String, dynamic> delivery;

  const _DeliveryHistoryDialog({required this.delivery});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Delivery History'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ID: ${delivery['orderId']}'),
            Text('Method: ${delivery['actualDeliveryMethod']}'),
            Text('Completed: ${delivery['completedAt']}'),
            // Add more history details
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }
}
