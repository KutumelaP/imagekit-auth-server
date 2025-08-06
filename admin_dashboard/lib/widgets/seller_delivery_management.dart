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
                    trailing: IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => _showDeliverySettingsDialog(seller),
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
} 