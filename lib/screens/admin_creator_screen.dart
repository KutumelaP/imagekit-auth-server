import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class AdminCreatorScreen extends StatefulWidget {
  const AdminCreatorScreen({super.key});

  @override
  State<AdminCreatorScreen> createState() => _AdminCreatorScreenState();
}

class _AdminCreatorScreenState extends State<AdminCreatorScreen> {
  bool _isLoading = false;
  String _status = 'Ready to create admin user';

  Future<void> _createAdminUser() async {
    setState(() {
      _isLoading = true;
      _status = 'Creating admin user...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _status = '❌ No user authenticated. Please log in first.';
          _isLoading = false;
        });
        return;
      }

      // Create the user document
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'notificationsEnabled': true,
        'paused': false,
        'verified': true,
        'adminLevel': 'super',
        'permissions': [
          'canViewOrders',
          'canEditOrders',
          'canViewUsers',
          'canEditUsers',
          'canViewSettings',
          'canEditSettings',
          'canViewAuditLogs',
          'canModerate'
        ]
      });

      setState(() {
        _status = '✅ Admin user created successfully!\n\nUID: ${user.uid}\nEmail: ${user.email}\nRole: admin\n\nYou can now access the admin dashboard.';
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _status = '❌ Error creating admin user: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkCurrentUser() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking current user...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _status = '❌ No user authenticated. Please log in first.';
          _isLoading = false;
        });
        return;
      }

      // Check if document exists
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _status = '✅ User document exists!\n\nUID: ${user.uid}\nEmail: ${user.email}\nRole: ${data['role'] ?? 'Not set'}\n\nIf role is not "admin", click "Make Admin" below.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _status = '❌ User document NOT found!\n\nUID: ${user.uid}\nEmail: ${user.email}\n\nClick "Create Admin User" to create the missing document.';
          _isLoading = false;
        });
      }

    } catch (e) {
      setState(() {
        _status = '❌ Error checking user: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _makeCurrentUserAdmin() async {
    setState(() {
      _isLoading = true;
      _status = 'Making current user admin...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _status = '❌ No user authenticated.';
          _isLoading = false;
        });
        return;
      }

      // Update the user document to make them admin
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'role': 'admin',
        'lastUpdated': FieldValue.serverTimestamp(),
        'adminLevel': 'super',
        'permissions': [
          'canViewOrders',
          'canEditOrders',
          'canViewUsers',
          'canEditUsers',
          'canViewSettings',
          'canEditSettings',
          'canViewAuditLogs',
          'canModerate'
        ]
      });

      // Refresh user data in provider to reflect the role change
      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.loadUserData();
      }

      setState(() {
        _status = '✅ User role updated to admin!\n\nUID: ${user.uid}\nEmail: ${user.email}\nRole: admin\n\nYou can now access the admin dashboard.';
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _status = '❌ Error updating user role: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Creator'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin User Creator',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This tool helps create or update admin users in your Firebase database.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _status,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _createAdminUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Create Admin User'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _makeCurrentUserAdmin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Make Current User Admin'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _checkCurrentUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Refresh Status'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
} 