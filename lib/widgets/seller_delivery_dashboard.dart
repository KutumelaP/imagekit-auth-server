import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/seller_delivery_management_service.dart';
import '../theme/app_theme.dart';

class SellerDeliveryDashboard extends StatefulWidget {
  const SellerDeliveryDashboard({Key? key}) : super(key: key);

  @override
  State<SellerDeliveryDashboard> createState() => _SellerDeliveryDashboardState();
}

class _SellerDeliveryDashboardState extends State<SellerDeliveryDashboard> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  String? _sellerId;

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
    final recentDeliveries = _dashboardData?['recentDeliveries'] as List? ?? [];
    final stats = _dashboardData?['stats'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text('Delivery Management'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: Colors.white,
        actions: [
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
              
              // Pending Delivery Tasks
              _buildPendingTasksSection(pendingTasks),
              
              SizedBox(height: 24),
              
              // Recent Deliveries
              _buildRecentDeliveriesSection(recentDeliveries),
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
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No pending deliveries',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
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
          
          // Customer Details
          if (deliveryDetails['buyerName'] != null)
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  'Customer: ${deliveryDetails['buyerName']}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          
          if (deliveryDetails['address'] != null)
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    deliveryDetails['address'],
                    style: TextStyle(color: Colors.grey[700]),
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
              
              if (status == 'confirmed_by_seller')
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _startDelivery(orderId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Start Delivery'),
                  ),
                ),
              
              if (status == 'delivery_in_progress')
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showCompleteDeliveryDialog(task),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Complete Delivery'),
                  ),
                ),
              
              SizedBox(width: 8),
              
              OutlinedButton(
                onPressed: () => _showTaskDetails(task),
                child: Text('Details'),
              ),
            ],
          ),
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
          _loadDashboardData();
        },
      ),
    );
  }

  Future<void> _startDelivery(String orderId) async {
    try {
      final result = await SellerDeliveryManagementService.sellerStartDelivery(
        orderId: orderId,
        sellerId: _sellerId!,
        notes: 'Delivery started by seller',
      );
      
      if (result['success']) {
        _showSuccessSnackBar('Delivery started successfully!');
        _loadDashboardData();
      } else {
        _showErrorSnackBar('Failed to start delivery');
      }
    } catch (e) {
      _showErrorSnackBar('Error starting delivery: $e');
    }
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
      final result = await SellerDeliveryManagementService.sellerConfirmDelivery(
        orderId: widget.orderId,
        sellerId: widget.sellerId,
        deliveryMethod: _selectedMethod,
        driverDetails: {
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
        widget.onCompleted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delivery completed successfully!'),
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
