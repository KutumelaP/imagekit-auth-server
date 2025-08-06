import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/admin_theme.dart';

class DriverManagementScreen extends StatefulWidget {
  const DriverManagementScreen({Key? key}) : super(key: key);

  @override
  State<DriverManagementScreen> createState() => _DriverManagementScreenState();
}

class _DriverManagementScreenState extends State<DriverManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoading = true);

    try {
      final querySnapshot = await _firestore.collection('drivers').get();

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
      print('Error loading drivers: $e');
      setState(() => _isLoading = false);
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
                    _buildStatsCards(),
                    const SizedBox(height: 24),
                    _buildDriversList(),
                    const SizedBox(height: 100), // Space for FAB
                  ],
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.extended(
                  onPressed: _showAddDriverDialog,
                  backgroundColor: AdminTheme.deepTeal,
                  foregroundColor: AdminTheme.angel,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Driver'),
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
              Icons.delivery_dining,
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
                  'Driver Management',
                  style: AdminTheme.headlineLarge.copyWith(
                    color: AdminTheme.angel,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage rural and urban delivery drivers',
                  style: AdminTheme.bodyMedium.copyWith(
                    color: AdminTheme.angel.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AdminTheme.angel.withOpacity(0.2),
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

  Widget _buildStatsCards() {
    final ruralDrivers = _drivers.where((d) => d['isRuralDriver'] == true).length;
    final urbanDrivers = _drivers.where((d) => d['isUrbanDriver'] == true).length;
    final availableDrivers = _drivers.where((d) => d['isAvailable'] == true).length;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Drivers',
          _drivers.length.toString(),
          Icons.people,
          AdminTheme.deepTeal,
        ),
        _buildStatCard(
          'Rural Drivers',
          ruralDrivers.toString(),
          Icons.location_on,
          AdminTheme.cloud,
        ),
        _buildStatCard(
          'Urban Drivers',
          urbanDrivers.toString(),
          Icons.location_city,
          AdminTheme.breeze,
        ),
        _buildStatCard(
          'Available',
          availableDrivers.toString(),
          Icons.check_circle,
          AdminTheme.success,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Icon(Icons.trending_up, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AdminTheme.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AdminTheme.deepTeal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AdminTheme.bodySmall.copyWith(
              color: AdminTheme.cloud,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversList() {
    return Container(
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
              Icon(Icons.list, color: AdminTheme.deepTeal),
              const SizedBox(width: 8),
              Text(
                'All Drivers (${_drivers.length})',
                style: AdminTheme.headlineMedium.copyWith(
                  color: AdminTheme.deepTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _drivers.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.delivery_dining,
                        size: 64,
                        color: AdminTheme.cloud,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No drivers found',
                        style: AdminTheme.headlineSmall.copyWith(
                          color: AdminTheme.cloud,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first driver to get started',
                        style: AdminTheme.bodyMedium.copyWith(
                          color: AdminTheme.cloud,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _drivers.length,
                  itemBuilder: (context, index) {
                    final driver = _drivers[index];
                    return _buildDriverCard(driver);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    final name = driver['name'] ?? 'Unknown';
    final phone = driver['phone'] ?? 'No phone';
    final vehicleType = driver['vehicleType'] ?? 'Unknown';
    final maxDistance = driver['maxDistance'] ?? 0.0;
    final rating = driver['rating'] ?? 0.0;
    final isAvailable = driver['isAvailable'] ?? false;
    final isRuralDriver = driver['isRuralDriver'] ?? false;
    final isUrbanDriver = driver['isUrbanDriver'] ?? false;
    final createdAt = driver['createdAt'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getDriverStatusColor(isAvailable).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getDriverStatusColor(isAvailable).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getDriverTypeColor(isRuralDriver, isUrbanDriver),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getDriverTypeIcon(isRuralDriver, isUrbanDriver),
              color: AdminTheme.angel,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: AdminTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getDriverStatusColor(isAvailable).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
                        style: AdminTheme.bodySmall.copyWith(
                          color: _getDriverStatusColor(isAvailable),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '📞 $phone • 🚗 $vehicleType • 📍 ${maxDistance.toStringAsFixed(1)}km',
                  style: AdminTheme.bodySmall.copyWith(
                    color: AdminTheme.cloud,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.orange, size: 16),
                    Text(
                      ' ${rating.toStringAsFixed(1)}',
                      style: AdminTheme.bodySmall.copyWith(
                        color: AdminTheme.cloud,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      isRuralDriver ? 'Rural' : isUrbanDriver ? 'Urban' : 'Unknown',
                      style: AdminTheme.bodySmall.copyWith(
                        color: _getDriverTypeColor(isRuralDriver, isUrbanDriver),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Added: ${DateFormat('MMM dd, yyyy').format(createdAt.toDate())}',
                    style: AdminTheme.bodySmall.copyWith(
                      color: AdminTheme.cloud,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _showEditDriverDialog(driver);
                  break;
                case 'toggle':
                  _toggleDriverAvailability(driver['id'], !isAvailable);
                  break;
                case 'delete':
                  _showDeleteDriverDialog(driver);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: AdminTheme.deepTeal, size: 16),
                    const SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: Row(
                  children: [
                    Icon(
                      isAvailable ? Icons.block : Icons.check_circle,
                      color: isAvailable ? AdminTheme.error : AdminTheme.success,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(isAvailable ? 'Set Unavailable' : 'Set Available'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: AdminTheme.error, size: 16),
                    const SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getDriverStatusColor(bool isAvailable) {
    return isAvailable ? AdminTheme.success : AdminTheme.error;
  }

  Color _getDriverTypeColor(bool isRural, bool isUrban) {
    if (isRural) return AdminTheme.cloud;
    if (isUrban) return AdminTheme.breeze;
    return AdminTheme.deepTeal;
  }

  IconData _getDriverTypeIcon(bool isRural, bool isUrban) {
    if (isRural) return Icons.location_on;
    if (isUrban) return Icons.location_city;
    return Icons.delivery_dining;
  }

  void _showAddDriverDialog() {
    showDialog(
      context: context,
      builder: (context) => AddDriverDialog(
        onDriverAdded: () {
          Navigator.pop(context);
          _loadDrivers();
        },
      ),
    );
  }

  void _showEditDriverDialog(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => EditDriverDialog(
        driver: driver,
        onDriverUpdated: () {
          Navigator.pop(context);
          _loadDrivers();
        },
      ),
    );
  }

  void _showDeleteDriverDialog(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Driver', style: AdminTheme.headlineSmall),
        content: Text(
          'Are you sure you want to delete ${driver['name']}? This action cannot be undone.',
          style: AdminTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AdminTheme.deepTeal)),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteDriver(driver['id']);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.error,
              foregroundColor: AdminTheme.angel,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDriverAvailability(String driverId, bool isAvailable) async {
    try {
      await _firestore.collection('drivers').doc(driverId).update({
        'isAvailable': isAvailable,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      await _loadDrivers();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Driver ${isAvailable ? 'set as available' : 'set as unavailable'}'),
          backgroundColor: isAvailable ? AdminTheme.success : AdminTheme.warning,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating driver: $e'),
          backgroundColor: AdminTheme.error,
        ),
      );
    }
  }

  Future<void> _deleteDriver(String driverId) async {
    try {
      await _firestore.collection('drivers').doc(driverId).delete();
      
      await _loadDrivers();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver deleted successfully'),
          backgroundColor: AdminTheme.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting driver: $e'),
          backgroundColor: AdminTheme.error,
        ),
      );
    }
  }
}

class AddDriverDialog extends StatefulWidget {
  final VoidCallback onDriverAdded;

  const AddDriverDialog({Key? key, required this.onDriverAdded}) : super(key: key);

  @override
  State<AddDriverDialog> createState() => _AddDriverDialogState();
}

class _AddDriverDialogState extends State<AddDriverDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _maxDistanceController = TextEditingController();
  String _selectedDriverType = 'rural';
  bool _isAvailable = true;
  double _rating = 4.0;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleTypeController.dispose();
    _maxDistanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add New Driver', style: AdminTheme.headlineSmall),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Driver Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter driver name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vehicleTypeController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter vehicle type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _maxDistanceController,
                decoration: const InputDecoration(
                  labelText: 'Max Distance (km)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter max distance';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedDriverType,
                decoration: const InputDecoration(
                  labelText: 'Driver Type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'rural', child: Text('Rural Driver')),
                  DropdownMenuItem(value: 'urban', child: Text('Urban Driver')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedDriverType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isAvailable,
                    onChanged: (value) {
                      setState(() {
                        _isAvailable = value!;
                      });
                    },
                  ),
                  const Text('Available for delivery'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Rating: '),
                  Expanded(
                    child: Slider(
                      value: _rating,
                      min: 0.0,
                      max: 5.0,
                      divisions: 10,
                      label: _rating.toStringAsFixed(1),
                      onChanged: (value) {
                        setState(() {
                          _rating = value;
                        });
                      },
                    ),
                  ),
                  Text(_rating.toStringAsFixed(1)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: AdminTheme.deepTeal)),
        ),
        ElevatedButton(
          onPressed: _addDriver,
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.deepTeal,
            foregroundColor: AdminTheme.angel,
          ),
          child: const Text('Add Driver'),
        ),
      ],
    );
  }

  Future<void> _addDriver() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final driverData = {
        'name': _nameController.text,
        'phone': _phoneController.text,
        'vehicleType': _vehicleTypeController.text,
        'maxDistance': double.parse(_maxDistanceController.text),
        'rating': _rating,
        'isAvailable': _isAvailable,
        'isRuralDriver': _selectedDriverType == 'rural',
        'isUrbanDriver': _selectedDriverType == 'urban',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('drivers').add(driverData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver added successfully!'),
          backgroundColor: AdminTheme.success,
        ),
      );

      widget.onDriverAdded();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding driver: $e'),
          backgroundColor: AdminTheme.error,
        ),
      );
    }
  }
}

class EditDriverDialog extends StatefulWidget {
  final Map<String, dynamic> driver;
  final VoidCallback onDriverUpdated;

  const EditDriverDialog({
    Key? key,
    required this.driver,
    required this.onDriverUpdated,
  }) : super(key: key);

  @override
  State<EditDriverDialog> createState() => _EditDriverDialogState();
}

class _EditDriverDialogState extends State<EditDriverDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _vehicleTypeController;
  late final TextEditingController _maxDistanceController;
  late String _selectedDriverType;
  late bool _isAvailable;
  late double _rating;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.driver['name'] ?? '');
    _phoneController = TextEditingController(text: widget.driver['phone'] ?? '');
    _vehicleTypeController = TextEditingController(text: widget.driver['vehicleType'] ?? '');
    _maxDistanceController = TextEditingController(text: (widget.driver['maxDistance'] ?? 0.0).toString());
    _selectedDriverType = widget.driver['isRuralDriver'] == true ? 'rural' : 'urban';
    _isAvailable = widget.driver['isAvailable'] ?? false;
    _rating = widget.driver['rating'] ?? 4.0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleTypeController.dispose();
    _maxDistanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Driver', style: AdminTheme.headlineSmall),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Driver Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter driver name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vehicleTypeController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter vehicle type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _maxDistanceController,
                decoration: const InputDecoration(
                  labelText: 'Max Distance (km)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter max distance';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedDriverType,
                decoration: const InputDecoration(
                  labelText: 'Driver Type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'rural', child: Text('Rural Driver')),
                  DropdownMenuItem(value: 'urban', child: Text('Urban Driver')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedDriverType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isAvailable,
                    onChanged: (value) {
                      setState(() {
                        _isAvailable = value!;
                      });
                    },
                  ),
                  const Text('Available for delivery'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Rating: '),
                  Expanded(
                    child: Slider(
                      value: _rating,
                      min: 0.0,
                      max: 5.0,
                      divisions: 10,
                      label: _rating.toStringAsFixed(1),
                      onChanged: (value) {
                        setState(() {
                          _rating = value;
                        });
                      },
                    ),
                  ),
                  Text(_rating.toStringAsFixed(1)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: AdminTheme.deepTeal)),
        ),
        ElevatedButton(
          onPressed: _updateDriver,
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.deepTeal,
            foregroundColor: AdminTheme.angel,
          ),
          child: const Text('Update Driver'),
        ),
      ],
    );
  }

  Future<void> _updateDriver() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final driverData = {
        'name': _nameController.text,
        'phone': _phoneController.text,
        'vehicleType': _vehicleTypeController.text,
        'maxDistance': double.parse(_maxDistanceController.text),
        'rating': _rating,
        'isAvailable': _isAvailable,
        'isRuralDriver': _selectedDriverType == 'rural',
        'isUrbanDriver': _selectedDriverType == 'urban',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driver['id'])
          .update(driverData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver updated successfully!'),
          backgroundColor: AdminTheme.success,
        ),
      );

      widget.onDriverUpdated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating driver: $e'),
          backgroundColor: AdminTheme.error,
        ),
      );
    }
  }
} 