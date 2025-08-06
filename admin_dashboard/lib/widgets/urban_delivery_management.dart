import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../theme/admin_theme.dart';
import '../services/urban_delivery_service.dart';

class UrbanDeliveryManagement extends StatefulWidget {
  const UrbanDeliveryManagement({Key? key}) : super(key: key);

  @override
  State<UrbanDeliveryManagement> createState() => _UrbanDeliveryManagementState();
}

class _UrbanDeliveryManagementState extends State<UrbanDeliveryManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  Map<String, List<Map<String, dynamic>>> _urbanZones = {};
  Map<String, dynamic> _deliveryStats = {};

  @override
  void initState() {
    super.initState();
    _loadUrbanDeliveryData();
  }

  Future<void> _loadUrbanDeliveryData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load urban zones info
      _urbanZones = UrbanDeliveryService.getUrbanZonesInfo();
      
      // Load delivery statistics
      _deliveryStats = UrbanDeliveryService.getUrbanDeliveryStats();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading urban delivery data: $e');
      setState(() {
        _isLoading = false;
      });
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
                    _buildStatisticsCards(),
                    const SizedBox(height: 24),
                    _buildUrbanZonesSection(),
                    const SizedBox(height: 24),
                    _buildCategoryManagement(),
                    const SizedBox(height: 24),
                    _buildPartnershipSection(),
                    const SizedBox(height: 100), // Space for FABs
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
                       onPressed: _showAddUrbanDriverDialog,
                       backgroundColor: AdminTheme.deepTeal,
                       foregroundColor: AdminTheme.angel,
                       icon: const Icon(Icons.person_add),
                       label: const Text('Add Real Driver'),
                     ),
                     const SizedBox(height: 16),
                     FloatingActionButton(
                       onPressed: _createTestUrbanDrivers,
                       backgroundColor: Colors.orange,
                       heroTag: 'add_urban_drivers',
                       child: const Icon(Icons.delivery_dining, color: AdminTheme.angel),
                     ),
                     const SizedBox(height: 16),
                     FloatingActionButton(
                       onPressed: _showAddZoneDialog,
                       backgroundColor: AdminTheme.breeze,
                       heroTag: 'add_zone',
                       child: const Icon(Icons.add, color: AdminTheme.angel),
                     ),
                   ],
                 ),
               ),
            ],
          );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AdminTheme.deepTeal, AdminTheme.cloud],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminTheme.angel.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.location_city,
              color: AdminTheme.angel,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Urban Delivery Management',
                  style: AdminTheme.headlineLarge.copyWith(
                    color: AdminTheme.angel,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage delivery zones, pricing, and partnerships for Gauteng and Cape Town',
                  style: AdminTheme.bodyMedium.copyWith(
                    color: AdminTheme.angel.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Zones',
          _deliveryStats['totalZones']?.toString() ?? '0',
          Icons.location_on,
          AdminTheme.deepTeal,
        ),
        _buildStatCard(
          'Provinces',
          _deliveryStats['provinces']?.length.toString() ?? '0',
          Icons.map,
          AdminTheme.cloud,
        ),
        _buildStatCard(
          'Categories',
          _deliveryStats['categories']?.length.toString() ?? '0',
          Icons.category,
          AdminTheme.breeze,
        ),
        _buildStatCard(
          'Peak Hours',
          '2',
          Icons.schedule,
          AdminTheme.whisper,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AdminTheme.headlineMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AdminTheme.bodySmall.copyWith(
              color: AdminTheme.deepTeal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUrbanZonesSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.cloud.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: AdminTheme.deepTeal),
              const SizedBox(width: 8),
              Text(
                'Urban Delivery Zones',
                style: AdminTheme.headlineMedium.copyWith(
                  color: AdminTheme.deepTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._urbanZones.entries.map((entry) => _buildProvinceZones(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildProvinceZones(String province, List<Map<String, dynamic>> zones) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getProvinceDisplayName(province),
          style: AdminTheme.titleLarge.copyWith(
            color: AdminTheme.deepTeal,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...zones.map((zone) => _buildZoneCard(zone)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildZoneCard(Map<String, dynamic> zone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getZoneTypeColor(zone['type']).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getZoneTypeColor(zone['type']).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getZoneTypeColor(zone['type']),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getZoneTypeIcon(zone['type']),
              color: AdminTheme.angel,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zone['name'],
                  style: AdminTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${zone['type'].toUpperCase()} • ${zone['radius']}km radius',
                  style: AdminTheme.bodySmall.copyWith(
                    color: AdminTheme.breeze,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: (zone['categories'] as List).map((category) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminTheme.cloud.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category,
                        style: AdminTheme.bodySmall.copyWith(
                          color: AdminTheme.deepTeal,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _editZone(zone),
            icon: Icon(Icons.edit, color: AdminTheme.deepTeal),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryManagement() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.cloud.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category, color: AdminTheme.deepTeal),
              const SizedBox(width: 8),
              Text(
                'Category-Specific Delivery',
                style: AdminTheme.headlineMedium.copyWith(
                  color: AdminTheme.deepTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCategoryCards(),
        ],
      ),
    );
  }

  Widget _buildCategoryCards() {
    final categories = [
      {'name': 'Electronics', 'icon': '💻', 'color': AdminTheme.deepTeal},
      {'name': 'Food', 'icon': '🍕', 'color': AdminTheme.cloud},
      {'name': 'Clothes', 'icon': '👕', 'color': AdminTheme.breeze},
      {'name': 'Other', 'icon': '📦', 'color': AdminTheme.whisper},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.5,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final color = category['color'] as Color;
        final name = category['name'] as String;
        final icon = category['icon'] as String;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: AdminTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Specialized delivery',
                      style: AdminTheme.bodySmall.copyWith(
                        color: AdminTheme.breeze,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _editCategoryPricing(name),
                icon: Icon(Icons.settings, color: color),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPartnershipSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.cloud.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.handshake, color: AdminTheme.deepTeal),
              const SizedBox(width: 8),
              Text(
                'Urban Partnerships',
                style: AdminTheme.headlineMedium.copyWith(
                  color: AdminTheme.deepTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPartnershipCards(),
        ],
      ),
    );
  }

  Widget _buildPartnershipCards() {
    final partnerships = [
      {
        'name': 'Electronics Stores',
        'description': 'Best Buy, HiFi Corp, local tech shops',
        'icon': Icons.computer,
        'color': AdminTheme.deepTeal,
      },
      {
        'name': 'Restaurants',
        'description': 'Local restaurants, cafes, food chains',
        'icon': Icons.restaurant,
        'color': AdminTheme.cloud,
      },
      {
        'name': 'Fashion Boutiques',
        'description': 'Local boutiques, mall stores',
        'icon': Icons.checkroom,
        'color': AdminTheme.breeze,
      },
      {
        'name': 'Delivery Services',
        'description': 'Uber Eats API, local delivery companies',
        'icon': Icons.delivery_dining,
        'color': AdminTheme.whisper,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.8,
      ),
      itemCount: partnerships.length,
      itemBuilder: (context, index) {
        final partnership = partnerships[index];
        final color = partnership['color'] as Color;
        final name = partnership['name'] as String;
        final description = partnership['description'] as String;
        final icon = partnership['icon'] as IconData;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: AdminTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: AdminTheme.bodySmall.copyWith(
                  color: AdminTheme.breeze,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _managePartnership(name),
                    child: Text(
                      'Manage',
                      style: TextStyle(color: color),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _getProvinceDisplayName(String province) {
    switch (province) {
      case 'gauteng':
        return 'Gauteng';
      case 'cape_town':
        return 'Cape Town';
      default:
        return province;
    }
  }

  Color _getZoneTypeColor(String type) {
    switch (type) {
      case 'premium':
        return AdminTheme.deepTeal;
      case 'standard':
        return AdminTheme.cloud;
      case 'student':
        return AdminTheme.breeze;
      default:
        return AdminTheme.whisper;
    }
  }

  IconData _getZoneTypeIcon(String type) {
    switch (type) {
      case 'premium':
        return Icons.star;
      case 'standard':
        return Icons.location_on;
      case 'student':
        return Icons.school;
      default:
        return Icons.location_on;
    }
  }

  void _showAddZoneDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Urban Zone', style: AdminTheme.headlineSmall),
        content: const Text('Zone management dialog will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AdminTheme.deepTeal)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Add Zone', style: TextStyle(color: AdminTheme.angel)),
          ),
        ],
      ),
    );
  }

  void _editZone(Map<String, dynamic> zone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Zone: ${zone['name']}', style: AdminTheme.headlineSmall),
        content: const Text('Zone editing dialog will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AdminTheme.deepTeal)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Save', style: TextStyle(color: AdminTheme.angel)),
          ),
        ],
      ),
    );
  }

  void _editCategoryPricing(String category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Pricing: $category', style: AdminTheme.headlineSmall),
        content: const Text('Category pricing dialog will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AdminTheme.deepTeal)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Save', style: TextStyle(color: AdminTheme.angel)),
          ),
        ],
      ),
    );
  }

  void _managePartnership(String partnershipName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage Partnership: $partnershipName', style: AdminTheme.headlineSmall),
        content: const Text('Partnership management dialog will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AdminTheme.deepTeal)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Save', style: TextStyle(color: AdminTheme.angel)),
          ),
        ],
      ),
    );
  }

  Future<void> _createTestUrbanDrivers() async {
    final random = Random();
    final names = ['Alex Johnson', 'Sarah Wilson', 'Mike Davis', 'Lisa Brown', 'Tom Anderson'];
    final phoneNumbers = ['111-222-3333', '444-555-6666', '777-888-9999', '000-111-2222', '333-444-5555'];
    final vehicleTypes = ['Car', 'Bike', 'Motorcycle', 'Van', 'Scooter'];
    final maxDistances = [15.0, 25.0, 35.0, 45.0, 55.0];

    for (int i = 0; i < 5; i++) {
      final name = names[random.nextInt(names.length)];
      final phone = phoneNumbers[random.nextInt(phoneNumbers.length)];
      final vehicleType = vehicleTypes[random.nextInt(vehicleTypes.length)];
      final maxDistance = maxDistances[random.nextInt(maxDistances.length)];

      await _addUrbanDriver({
        'name': name,
        'phone': phone,
        'vehicleType': vehicleType,
        'maxDistance': maxDistance,
        'isUrbanDriver': true,
        'isAvailable': true,
        'rating': 4.2, // Example rating
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('5 urban test drivers added successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

       Future<void> _addUrbanDriver(Map<String, dynamic> driverData) async {
    try {
      await _firestore.collection('drivers').add(driverData);
    } catch (e) {
      print('Error adding urban driver: $e');
    }
  }

     void _showAddUrbanDriverDialog() {
     final nameController = TextEditingController();
     final phoneController = TextEditingController();
     final vehicleController = TextEditingController();
     final maxDistanceController = TextEditingController();

     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: Text('Add Urban Driver', style: AdminTheme.headlineSmall),
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
               await _addUrbanDriver({
                 'name': nameController.text,
                 'phone': phoneController.text,
                 'vehicleType': vehicleController.text,
                 'maxDistance': double.tryParse(maxDistanceController.text) ?? 20.0,
                 'isUrbanDriver': true,
                 'isAvailable': true,
                 'rating': 0.0,
                 'createdAt': FieldValue.serverTimestamp(),
               });
               Navigator.pop(context);
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(
                   content: Text('Urban driver added successfully!'),
                   backgroundColor: Colors.green,
                 ),
               );
             },
             child: const Text('Add'),
           ),
         ],
       ),
     );
   }
} 