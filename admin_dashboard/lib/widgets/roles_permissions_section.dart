import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RolesPermissionsSection extends StatefulWidget {
  @override
  State<RolesPermissionsSection> createState() => _RolesPermissionsSectionState();
}

class _RolesPermissionsSectionState extends State<RolesPermissionsSection> {
  String _selectedRole = 'admin';
  // removed unused loading flag
  
  final List<Map<String, dynamic>> _roles = [
    {
      'name': 'admin',
      'displayName': 'Administrator',
      'description': 'Full access to all features and data',
      'color': Colors.red,
      'permissions': [
        'manage_users',
        'manage_orders',
        'manage_products',
        'manage_categories',
        'view_analytics',
        'manage_settings',
        'manage_roles',
        'export_data',
        'manage_delivery',
        'manage_payments',
      ],
    },
    {
      'name': 'seller',
      'displayName': 'Seller',
      'description': 'Can manage their own products and orders',
      'color': Colors.blue,
      'permissions': [
        'manage_own_products',
        'view_own_orders',
        'manage_own_profile',
        'view_own_analytics',
      ],
    },
    {
      'name': 'customer',
      'displayName': 'Customer',
      'description': 'Can browse and purchase products',
      'color': Colors.green,
      'permissions': [
        'browse_products',
        'place_orders',
        'view_own_orders',
        'manage_own_profile',
        'write_reviews',
      ],
    },
    {
      'name': 'driver',
      'displayName': 'Driver',
      'description': 'Can manage deliveries and view assigned orders',
      'color': Colors.orange,
      'permissions': [
        'view_assigned_orders',
        'update_order_status',
        'manage_own_profile',
        'view_earnings',
      ],
    },
  ];

  final List<Map<String, dynamic>> _permissions = [
    {
      'id': 'manage_users',
      'name': 'Manage Users',
      'description': 'Create, edit, and delete user accounts',
      'category': 'User Management',
    },
    {
      'id': 'manage_orders',
      'name': 'Manage Orders',
      'description': 'View and manage all orders in the system',
      'category': 'Order Management',
    },
    {
      'id': 'manage_products',
      'name': 'Manage Products',
      'description': 'Create, edit, and delete all products',
      'category': 'Product Management',
    },
    {
      'id': 'manage_categories',
      'name': 'Manage Categories',
      'description': 'Create and manage product categories',
      'category': 'Product Management',
    },
    {
      'id': 'view_analytics',
      'name': 'View Analytics',
      'description': 'Access to analytics and reporting',
      'category': 'Analytics',
    },
    {
      'id': 'manage_settings',
      'name': 'Manage Settings',
      'description': 'Configure system settings',
      'category': 'System',
    },
    {
      'id': 'manage_roles',
      'name': 'Manage Roles',
      'description': 'Create and manage user roles',
      'category': 'User Management',
    },
    {
      'id': 'export_data',
      'name': 'Export Data',
      'description': 'Export system data',
      'category': 'System',
    },
    {
      'id': 'manage_delivery',
      'name': 'Manage Delivery',
      'description': 'Manage delivery settings and drivers',
      'category': 'Delivery',
    },
    {
      'id': 'manage_payments',
      'name': 'Manage Payments',
      'description': 'Manage payment settings and transactions',
      'category': 'Financial',
    },
    {
      'id': 'manage_own_products',
      'name': 'Manage Own Products',
      'description': 'Create and manage own products',
      'category': 'Product Management',
    },
    {
      'id': 'view_own_orders',
      'name': 'View Own Orders',
      'description': 'View orders placed by the user',
      'category': 'Order Management',
    },
    {
      'id': 'manage_own_profile',
      'name': 'Manage Own Profile',
      'description': 'Edit own profile information',
      'category': 'User Management',
    },
    {
      'id': 'view_own_analytics',
      'name': 'View Own Analytics',
      'description': 'View analytics for own products',
      'category': 'Analytics',
    },
    {
      'id': 'browse_products',
      'name': 'Browse Products',
      'description': 'Browse and search products',
      'category': 'Product Management',
    },
    {
      'id': 'place_orders',
      'name': 'Place Orders',
      'description': 'Place new orders',
      'category': 'Order Management',
    },
    {
      'id': 'write_reviews',
      'name': 'Write Reviews',
      'description': 'Write product reviews',
      'category': 'Product Management',
    },
    {
      'id': 'view_assigned_orders',
      'name': 'View Assigned Orders',
      'description': 'View orders assigned to the driver',
      'category': 'Order Management',
    },
    {
      'id': 'update_order_status',
      'name': 'Update Order Status',
      'description': 'Update delivery status of orders',
      'category': 'Order Management',
    },
    {
      'id': 'view_earnings',
      'name': 'View Earnings',
      'description': 'View delivery earnings',
      'category': 'Financial',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildRoleSelector(),
            const SizedBox(height: 24),
            _buildPermissionsGrid(),
            const SizedBox(height: 24),
            _buildUserManagement(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.indigo.shade500],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Roles & Permissions',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage user roles and access permissions',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.security,
              size: 32,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Role',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: _roles.map((role) {
                final isSelected = _selectedRole == role['name'];
                return Expanded(
                  child: Card(
                    elevation: isSelected ? 4 : 1,
                    color: isSelected ? role['color'].withOpacity(0.1) : null,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedRole = role['name'];
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: role['color'].withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getRoleIcon(role['name']),
                                color: role['color'],
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              role['displayName'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? role['color'] : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              role['description'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsGrid() {
    final selectedRole = _roles.firstWhere((role) => role['name'] == _selectedRole);
    final rolePermissions = selectedRole['permissions'] as List<String>;
    
    // Group permissions by category
    Map<String, List<Map<String, dynamic>>> groupedPermissions = {};
    for (var permission in _permissions) {
      final category = permission['category'];
      if (!groupedPermissions.containsKey(category)) {
        groupedPermissions[category] = [];
      }
      groupedPermissions[category]!.add(permission);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Permissions for ${selectedRole['displayName']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Text(
                  '${rolePermissions.length} permissions',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...groupedPermissions.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entry.value.map((permission) {
                      final hasPermission = rolePermissions.contains(permission['id']);
                      return Chip(
                        label: Text(permission['name']),
                        backgroundColor: hasPermission ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: hasPermission ? Colors.green : Colors.grey[600],
                          fontWeight: hasPermission ? FontWeight.bold : FontWeight.normal,
                        ),
                        avatar: Icon(
                          hasPermission ? Icons.check : Icons.close,
                          color: hasPermission ? Colors.green : Colors.grey,
                          size: 16,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserManagement() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Role Management',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('users').get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData) {
                  return Center(child: Text('No users found'));
                }

                final users = snapshot.data!.docs;
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'User',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Email',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Current Role',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Actions',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...users.map((userDoc) {
                      final userData = userDoc.data() as Map<String, dynamic>;
                      final currentRole = (userData['role'] ?? 'customer').toString();
                      final roleNames = _roles.map((r) => r['name'] as String).toList();
                      final dropdownValue = roleNames.contains(currentRole) ? currentRole : 'customer';
                      
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  userData['name'] ?? userData['email']?.split('@')[0] ?? 'Unknown',
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  userData['email'] ?? 'No email',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(dropdownValue).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getRoleDisplayName(dropdownValue),
                                    style: TextStyle(
                                      color: _getRoleColor(dropdownValue),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    DropdownButton<String>(
                                       value: dropdownValue,
                                       items: _roles.map((role) {
                                         return DropdownMenuItem<String>(
                                           value: role['name'] as String,
                                           child: Text(role['displayName'] as String),
                                         );
                                       }).toList(),
                                       onChanged: (newRole) {
                                         if (newRole != null) {
                                           _updateUserRole(userDoc.id, newRole);
                                         }
                                       },
                                     ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getRoleIcon(String roleName) {
    switch (roleName) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'seller':
        return Icons.store;
      case 'customer':
        return Icons.person;
      case 'driver':
        return Icons.delivery_dining;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor(String roleName) {
    final role = _roles.firstWhere((r) => r['name'] == roleName, orElse: () => _roles.last);
    return role['color'];
  }

  String _getRoleDisplayName(String roleName) {
    final role = _roles.firstWhere((r) => r['name'] == roleName, orElse: () => _roles.last);
    return role['displayName'];
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    // start update

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'role': newRole});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User role updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update user role: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {}
  }
} 