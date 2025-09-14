import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/admin_theme.dart';

class SellerDeliveryManagement extends StatefulWidget {
  const SellerDeliveryManagement({super.key});

  @override
  State<SellerDeliveryManagement> createState() => _SellerDeliveryManagementState();
}

class _SellerDeliveryManagementState extends State<SellerDeliveryManagement> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _sellers = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSellers();
  }

  Future<void> _loadSellers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sellersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'seller')
          .where('status', isEqualTo: 'approved')
          .get();

      setState(() {
        _sellers = sellersSnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load sellers: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSellerDeliverySettings(String sellerId, Map<String, dynamic> settings) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .update(settings);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delivery settings updated successfully')),
      );
      
      _loadSellers(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update settings: $e')),
      );
    }
  }

  void _showDeliverySettingsDialog(Map<String, dynamic> seller) {
    final deliveryMode = seller['deliveryMode'] ?? 'hybrid';
    final sellerDeliveryEnabled = seller['sellerDeliveryEnabled'] ?? false;
    final platformDeliveryEnabled = seller['platformDeliveryEnabled'] ?? true;
    final sellerDeliveryBaseFee = seller['sellerDeliveryBaseFee'] ?? 25.0;
    final sellerDeliveryFeePerKm = seller['sellerDeliveryFeePerKm'] ?? 2.0;
    final sellerDeliveryMaxFee = seller['sellerDeliveryMaxFee'] ?? 50.0;
    final sellerDeliveryTime = seller['sellerDeliveryTime'] ?? '30-45 minutes';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Delivery Settings - ${seller['storeName']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivery Mode:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  value: deliveryMode,
                  items: [
                    DropdownMenuItem(value: 'platform', child: Text('Platform Only')),
                    DropdownMenuItem(value: 'seller', child: Text('Seller Only')),
                    DropdownMenuItem(value: 'hybrid', child: Text('Hybrid')),
                    DropdownMenuItem(value: 'pickup', child: Text('Pickup Only')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      // Update local state
                    });
                  },
                ),
                SizedBox(height: 16),
                
                Text('Delivery Options:', style: TextStyle(fontWeight: FontWeight.bold)),
                CheckboxListTile(
                  title: Text('Enable Seller Delivery'),
                  value: sellerDeliveryEnabled,
                  onChanged: (value) {
                    setState(() {
                      // Update local state
                    });
                  },
                ),
                CheckboxListTile(
                  title: Text('Enable Platform Delivery'),
                  value: platformDeliveryEnabled,
                  onChanged: (value) {
                    setState(() {
                      // Update local state
                    });
                  },
                ),
                
                if (sellerDeliveryEnabled) ...[
                  SizedBox(height: 16),
                  Text('Seller Delivery Settings:', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextFormField(
                    initialValue: sellerDeliveryBaseFee.toString(),
                    decoration: InputDecoration(labelText: 'Base Fee (R)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    initialValue: sellerDeliveryFeePerKm.toString(),
                    decoration: InputDecoration(labelText: 'Fee per km (R)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    initialValue: sellerDeliveryMaxFee.toString(),
                    decoration: InputDecoration(labelText: 'Max Fee (R)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    initialValue: sellerDeliveryTime,
                    decoration: InputDecoration(labelText: 'Delivery Time'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Update seller delivery settings
                _updateSellerDeliverySettings(seller['id'], {
                  'deliveryMode': deliveryMode,
                  'sellerDeliveryEnabled': sellerDeliveryEnabled,
                  'platformDeliveryEnabled': platformDeliveryEnabled,
                  'sellerDeliveryBaseFee': sellerDeliveryBaseFee,
                  'sellerDeliveryFeePerKm': sellerDeliveryFeePerKm,
                  'sellerDeliveryMaxFee': sellerDeliveryMaxFee,
                  'sellerDeliveryTime': sellerDeliveryTime,
                });
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seller Delivery Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AdminTheme.deepTeal,
            ),
          ),
          SizedBox(height: 16),
          
          // Statistics Cards
          Row(
            children: [
              Expanded(
                                  child: _buildStatCard(
                    'Total Sellers',
                    _sellers.length.toString(),
                    Icons.store,
                    AdminTheme.deepTeal,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Seller Delivery',
                    _sellers.where((s) => s['sellerDeliveryEnabled'] == true).length.toString(),
                    Icons.local_shipping,
                    AdminTheme.success,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Platform Only',
                    _sellers.where((s) => s['deliveryMode'] == 'platform').length.toString(),
                    Icons.delivery_dining,
                    AdminTheme.warning,
                  ),
              ),
            ],
          ),
          
          SizedBox(height: 24),
          
          // Sellers List
          Text(
            'Seller Delivery Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          
          if (_isLoading)
            Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Card(
              color: AdminTheme.error.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_errorMessage!, style: TextStyle(color: AdminTheme.error)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _sellers.length,
              itemBuilder: (context, index) {
                final seller = _sellers[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AdminTheme.deepTeal,
                      child: Text(
                        (seller['storeName'] ?? 'Store')[0].toUpperCase(),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(seller['storeName'] ?? 'Unknown Store'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(seller['contact'] ?? 'No contact'),
                        Text('Delivery Mode: ${seller['deliveryMode'] ?? 'hybrid'}'),
                        Row(
                          children: [
                            if (seller['sellerDeliveryEnabled'] == true)
                              Chip(
                                label: Text('Seller Delivery'),
                                backgroundColor: AdminTheme.success.withOpacity(0.2),
                                labelStyle: TextStyle(color: AdminTheme.success),
                              ),
                            if (seller['platformDeliveryEnabled'] == true)
                              Chip(
                                label: Text('Platform Delivery'),
                                backgroundColor: AdminTheme.deepTeal.withOpacity(0.2),
                                labelStyle: TextStyle(color: AdminTheme.deepTeal),
                              ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.people_outline, color: AdminTheme.deepTeal),
                          onPressed: () => _showSellerDriversDialog(seller),
                          tooltip: 'View Drivers',
                        ),
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () => _showDeliverySettingsDialog(seller),
                          tooltip: 'Edit Delivery Settings',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSellerDriversDialog(Map<String, dynamic> seller) {
    final sellerId = seller['id'];
    final storeName = seller['storeName'] ?? 'Unknown Store';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 600,
          height: 500,
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.people_outline, color: AdminTheme.deepTeal, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Drivers for $storeName',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AdminTheme.deepTeal,
                          ),
                        ),
                        Text(
                          'Seller ID: $sellerId',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Divider(),
              SizedBox(height: 16),
              
              // Drivers List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(sellerId)
                      .collection('drivers')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delivery_dining,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No drivers found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'This seller hasn\'t added any drivers yet.',
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final drivers = snapshot.data!.docs;
                    return ListView.separated(
                      itemCount: drivers.length,
                      separatorBuilder: (_, __) => Divider(height: 1),
                      itemBuilder: (context, index) {
                        final driver = drivers[index];
                        final data = driver.data() as Map<String, dynamic>;
                        final name = data['name'] ?? 'Unknown Driver';
                        final phone = data['phone'] ?? 'No phone';
                        final status = data['status'] ?? 'active';
                        final vehicleType = data['vehicleType'] ?? 'Unknown';
                        final createdAt = data['createdAt'] as Timestamp?;

                        return Container(
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          child: Row(
                            children: [
                              // Driver Avatar
                              CircleAvatar(
                                backgroundColor: status == 'active' 
                                    ? AdminTheme.success.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                                child: Icon(
                                  Icons.person,
                                  color: status == 'active' 
                                      ? AdminTheme.success
                                      : Colors.grey,
                                ),
                              ),
                              SizedBox(width: 16),
                              
                              // Driver Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                                        SizedBox(width: 4),
                                        Text(
                                          phone,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (vehicleType != 'Unknown') ...[
                                          SizedBox(width: 12),
                                          Icon(Icons.directions_car, size: 14, color: Colors.grey[600]),
                                          SizedBox(width: 4),
                                          Text(
                                            vehicleType,
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (createdAt != null) ...[
                                      SizedBox(height: 4),
                                      Text(
                                        'Added: ${_formatDate(createdAt.toDate())}',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              
                              // Status Badge
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: status == 'active' 
                                      ? AdminTheme.success.withOpacity(0.15)
                                      : Colors.grey.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: status == 'active' 
                                        ? AdminTheme.success
                                        : Colors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              
              // Footer
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminTheme.cloud.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AdminTheme.cloud),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'These drivers were added by the seller and can only be managed from their seller dashboard.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AdminTheme.cloud,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
} 