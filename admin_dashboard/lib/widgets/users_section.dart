import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UsersSection extends StatefulWidget {
  const UsersSection({Key? key}) : super(key: key);

  @override
  State<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<UsersSection> {
  String _searchQuery = '';
  String _selectedRole = 'all';
  String _selectedStatus = 'all';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildFilters(),
          const SizedBox(height: 24),
          _buildUsersList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
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
                  'User Management',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage user accounts, roles, and permissions',
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
              Icons.people,
              size: 32,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Search Users',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('All Roles')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'seller', child: Text('Seller')),
                      DropdownMenuItem(value: 'customer', child: Text('Customer')),
                      DropdownMenuItem(value: 'driver', child: Text('Driver')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('All Status')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                      DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Users',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addNewUser,
                  icon: Icon(Icons.add),
                  label: Text('Add User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
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

                final users = snapshot.data!.docs.where((doc) {
                  final userData = doc.data() as Map<String, dynamic>;
                  final name = (userData['name'] ?? '').toString().toLowerCase();
                  final email = (userData['email'] ?? '').toString().toLowerCase();
                  final role = userData['role'] ?? 'customer';
                  final status = userData['status'] ?? 'active';
                  
                  // Apply filters
                  if (_searchQuery.isNotEmpty && !name.contains(_searchQuery) && !email.contains(_searchQuery)) {
                    return false;
                  }
                  if (_selectedRole != 'all' && role != _selectedRole) {
                    return false;
                  }
                  if (_selectedStatus != 'all' && status != _selectedStatus) {
                    return false;
                  }
                  
                  return true;
                }).toList();

                return Column(
                  children: [
                    // Header row
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(child: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(child: Text('Joined', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // User rows
                    ...users.map((userDoc) {
                      final userData = userDoc.data() as Map<String, dynamic>;
                      return _buildUserRow(userDoc.id, userData);
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

  Widget _buildUserRow(String userId, Map<String, dynamic> userData) {
    final name = userData['name'] ?? userData['email']?.split('@')[0] ?? 'Unknown';
    final email = userData['email'] ?? 'No email';
    final role = userData['role'] ?? 'customer';
    final status = userData['status'] ?? 'active';
    final createdAt = userData['createdAt'] as Timestamp?;
    final joinedDate = createdAt != null ? DateFormat('MMM dd, yyyy').format(createdAt.toDate()) : 'Unknown';

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getRoleColor(role),
                    child: Text(
                      name[0].toUpperCase(),
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          email,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(email),
            ),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRoleColor(role).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getRoleDisplayName(role),
                  style: TextStyle(
                    color: _getRoleColor(role),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusDisplayName(status),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                joinedDate,
                style: TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _editUser(userId, userData),
                    icon: Icon(Icons.edit, color: Colors.blue),
                    tooltip: 'Edit User',
                  ),
                  IconButton(
                    onPressed: () => _viewUserDetails(userId, userData),
                    icon: Icon(Icons.visibility, color: Colors.green),
                    tooltip: 'View Details',
                  ),
                  IconButton(
                    onPressed: () => _toggleUserStatus(userId, status),
                    icon: Icon(
                      status == 'active' ? Icons.block : Icons.check_circle,
                      color: status == 'active' ? Colors.red : Colors.green,
                    ),
                    tooltip: status == 'active' ? 'Suspend User' : 'Activate User',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'seller':
        return Colors.blue;
      case 'customer':
        return Colors.green;
      case 'driver':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'seller':
        return 'Seller';
      case 'customer':
        return 'Customer';
      case 'driver':
        return 'Driver';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.grey;
      case 'suspended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      case 'suspended':
        return 'Suspended';
      default:
        return 'Unknown';
    }
  }

  void _addNewUser() {
    // Implement add user functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Add user functionality coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _editUser(String userId, Map<String, dynamic> userData) {
    // Implement edit user functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit user functionality coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _viewUserDetails(String userId, Map<String, dynamic> userData) {
    // Implement view user details functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View user details functionality coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _toggleUserStatus(String userId, String currentStatus) async {
    try {
      final newStatus = currentStatus == 'active' ? 'suspended' : 'active';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'status': newStatus});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User status updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update user status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 