import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../theme/admin_theme.dart';
import '../services/rural_delivery_service.dart';

class RuralDriverManagement extends StatefulWidget {
  const RuralDriverManagement({Key? key}) : super(key: key);

  @override
  State<RuralDriverManagement> createState() => _RuralDriverManagementState();
}

class _RuralDriverManagementState extends State<RuralDriverManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoading = true);

    try {
      final querySnapshot = await _firestore
          .collection('drivers')
          .where('isRuralDriver', isEqualTo: true)
          .get();

      setState(() {
        _drivers = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading rural drivers: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showPartnershipDialog() {
    final opportunities = RuralDeliveryService.getPartnershipOpportunities();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.handshake, color: AdminTheme.deepTeal),
            const SizedBox(width: 8),
            Text('Partnership Opportunities', style: AdminTheme.headlineSmall),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: opportunities.map((opportunity) => _buildPartnershipCard(opportunity)).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AdminTheme.deepTeal)),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnershipCard(Map<String, dynamic> opportunity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.cloud.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getPartnershipIcon(opportunity['type']),
                color: AdminTheme.deepTeal,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  opportunity['type'],
                  style: AdminTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AdminTheme.deepTeal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            opportunity['description'],
            style: AdminTheme.bodyMedium.copyWith(color: AdminTheme.cloud),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Benefits:',
                      style: AdminTheme.labelMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AdminTheme.deepTeal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...opportunity['benefits'].map((benefit) => Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 2),
                      child: Text(
                        '• $benefit',
                        style: AdminTheme.bodySmall.copyWith(color: AdminTheme.cloud),
                      ),
                    )),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Requirements:',
                      style: AdminTheme.labelMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AdminTheme.deepTeal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...opportunity['requirements'].map((req) => Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 2),
                      child: Text(
                        '• $req',
                        style: AdminTheme.bodySmall.copyWith(color: AdminTheme.cloud),
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getPartnershipIcon(String type) {
    switch (type) {
      case 'Student Partnerships':
        return Icons.school;
      case 'Local Business Partnerships':
        return Icons.business;
      case 'Community Driver Program':
        return Icons.people;
      default:
        return Icons.handshake;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildStatsSection(),
                    const SizedBox(height: 24),
                    _buildDriversList(),
                    const SizedBox(height: 80), // Space for FAB
                  ],
                ),
              ),
                             Positioned(
                 bottom: 16,
                 right: 16,
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.end,
                   children: [
                     FloatingActionButton.extended(
                       onPressed: _showAddDriverDialog,
                       backgroundColor: AdminTheme.deepTeal,
                       foregroundColor: AdminTheme.angel,
                       icon: const Icon(Icons.person_add),
                       label: const Text('Add Real Driver'),
                     ),
                     const SizedBox(height: 16),
                     FloatingActionButton.extended(
                       onPressed: _createTestDrivers,
                       backgroundColor: Colors.orange,
                       foregroundColor: AdminTheme.angel,
                       icon: const Icon(Icons.add),
                       label: const Text('Add Test Drivers'),
                     ),
                   ],
                 ),
               ),
            ],
          );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            color: AdminTheme.deepTeal,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rural Driver Management',
                  style: AdminTheme.headlineMedium.copyWith(
                    color: AdminTheme.deepTeal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Manage local delivery drivers',
                  style: AdminTheme.bodyMedium.copyWith(
                    color: AdminTheme.cloud,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AdminTheme.deepTeal,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_drivers.length} Drivers',
              style: AdminTheme.labelMedium.copyWith(
                color: AdminTheme.angel,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Active Drivers',
              _drivers.where((d) => d['isAvailable'] == true).length.toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Total Drivers',
              _drivers.length.toString(),
              Icons.people,
              AdminTheme.deepTeal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Avg Rating',
              _calculateAverageRating(),
              Icons.star,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            'Filter:',
            style: AdminTheme.labelLarge.copyWith(
              color: AdminTheme.deepTeal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedFilter,
              isExpanded: true,
              style: AdminTheme.bodyMedium.copyWith(
                color: AdminTheme.deepTeal,
              ),
              items: [
                'All',
                'Available',
                'Unavailable',
                'High Rating',
                'Low Rating',
              ].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedFilter = newValue!;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _getFilteredDrivers().length,
      itemBuilder: (context, index) {
        final driver = _getFilteredDrivers()[index];
        return _buildDriverCard(driver);
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AdminTheme.headlineSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: AdminTheme.labelSmall.copyWith(
              color: AdminTheme.cloud,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    final isAvailable = driver['isAvailable'] ?? false;
    final rating = driver['rating'] ?? 0.0;
    final vehicleType = driver['vehicleType'] ?? 'Car';
    final maxDistance = driver['maxDistance'] ?? 20.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAvailable ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAvailable ? Colors.green : Colors.grey,
          child: Text(
            driver['name']?.substring(0, 1).toUpperCase() ?? 'D',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          driver['name'] ?? 'Driver',
          style: AdminTheme.titleMedium.copyWith(
            color: AdminTheme.deepTeal,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${vehicleType} • ${maxDistance.toStringAsFixed(0)}km max',
              style: AdminTheme.bodySmall.copyWith(color: AdminTheme.cloud),
            ),
            Row(
              children: [
                Icon(Icons.star, color: Colors.orange, size: 16),
                Text(
                  rating.toStringAsFixed(1),
                  style: AdminTheme.bodySmall.copyWith(color: AdminTheme.cloud),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAvailable ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
                    style: AdminTheme.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleDriverAction(value, driver),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: isAvailable ? 'disable' : 'enable',
              child: Row(
                children: [
                  Icon(
                    isAvailable ? Icons.block : Icons.check_circle,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(isAvailable ? 'Disable' : 'Enable'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            size: 64,
            color: AdminTheme.cloud,
          ),
          const SizedBox(height: 16),
          Text(
            'No Rural Drivers Found',
            style: AdminTheme.headlineSmall.copyWith(
              color: AdminTheme.deepTeal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add local drivers to serve rural areas',
            style: AdminTheme.bodyMedium.copyWith(
              color: AdminTheme.cloud,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddDriverDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Driver'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.deepTeal,
              foregroundColor: AdminTheme.angel,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDriverDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final vehicleController = TextEditingController();
    final maxDistanceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Rural Driver', style: AdminTheme.headlineSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Driver Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: vehicleController,
              decoration: const InputDecoration(
                labelText: 'Vehicle Type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maxDistanceController,
              decoration: const InputDecoration(
                labelText: 'Max Distance (km)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AdminTheme.cloud)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _addDriver({
                'name': nameController.text,
                'phone': phoneController.text,
                'vehicleType': vehicleController.text,
                'maxDistance': double.tryParse(maxDistanceController.text) ?? 20.0,
                'isRuralDriver': true,
                'isAvailable': true,
                'rating': 0.0,
                'createdAt': FieldValue.serverTimestamp(),
              });
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addDriver(Map<String, dynamic> driverData) async {
    try {
      await _firestore.collection('drivers').add(driverData);
      _loadDrivers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Driver added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding driver: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleDriverAction(String action, Map<String, dynamic> driver) {
    switch (action) {
      case 'edit':
        _showEditDriverDialog(driver);
        break;
      case 'enable':
      case 'disable':
        _toggleDriverAvailability(driver);
        break;
      case 'delete':
        _deleteDriver(driver);
        break;
    }
  }

  void _showEditDriverDialog(Map<String, dynamic> driver) {
    // Implementation for editing driver
  }

  Future<void> _toggleDriverAvailability(Map<String, dynamic> driver) async {
    try {
      await _firestore.collection('drivers').doc(driver['id']).update({
        'isAvailable': !(driver['isAvailable'] ?? false),
      });
      _loadDrivers();
    } catch (e) {
      print('Error toggling driver availability: $e');
    }
  }

  Future<void> _deleteDriver(Map<String, dynamic> driver) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Driver', style: AdminTheme.headlineSmall),
        content: Text('Are you sure you want to delete ${driver['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('drivers').doc(driver['id']).delete();
        _loadDrivers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Driver deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting driver: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredDrivers() {
    switch (_selectedFilter) {
      case 'Available':
        return _drivers.where((d) => d['isAvailable'] == true).toList();
      case 'Unavailable':
        return _drivers.where((d) => d['isAvailable'] == false).toList();
      case 'High Rating':
        return _drivers.where((d) => (d['rating'] ?? 0.0) >= 4.0).toList();
      case 'Low Rating':
        return _drivers.where((d) => (d['rating'] ?? 0.0) < 4.0).toList();
      default:
        return _drivers;
    }
  }

  String _calculateAverageRating() {
    if (_drivers.isEmpty) return '0.0';
    
    double totalRating = 0.0;
    int count = 0;
    
    for (var driver in _drivers) {
      if (driver['rating'] != null) {
        totalRating += driver['rating'];
        count++;
      }
    }
    
    return count > 0 ? (totalRating / count).toStringAsFixed(1) : '0.0';
  }

     Future<void> _createTestDrivers() async {
     final random = Random();
     final names = ['John Doe', 'Jane Smith', 'Peter Jones', 'Mary Brown', 'David Lee'];
     final phoneNumbers = ['123-456-7890', '987-654-3210', '112-357-4680', '999-888-7777', '555-123-4567'];
     final vehicleTypes = ['Car', 'Bike', 'Truck', 'Van', 'Motorcycle'];
     final maxDistances = [10.0, 20.0, 30.0, 40.0, 50.0];

     for (int i = 0; i < 5; i++) {
       final name = names[random.nextInt(names.length)];
       final phone = phoneNumbers[random.nextInt(phoneNumbers.length)];
       final vehicleType = vehicleTypes[random.nextInt(vehicleTypes.length)];
       final maxDistance = maxDistances[random.nextInt(maxDistances.length)];

       await _addDriver({
         'name': name,
         'phone': phone,
         'vehicleType': vehicleType,
         'maxDistance': maxDistance,
         'isRuralDriver': true,
         'isAvailable': true,
         'rating': 4.5, // Example rating
         'createdAt': FieldValue.serverTimestamp(),
       });
     }
     
     await _loadDrivers(); // Reload the drivers list
     
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(
         content: Text('5 test drivers added successfully!'),
         backgroundColor: Colors.green,
       ),
     );
   }


} 