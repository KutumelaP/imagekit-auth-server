import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class AdminRedirectScreen extends StatefulWidget {
  const AdminRedirectScreen({super.key});

  @override
  State<AdminRedirectScreen> createState() => _AdminRedirectScreenState();
}

class _AdminRedirectScreenState extends State<AdminRedirectScreen> {
  @override
  void initState() {
    super.initState();
    _redirectToAdminDashboard();
  }

  void _redirectToAdminDashboard() {
    // For web, redirect to the admin dashboard URL
    if (kIsWeb) {
      // Redirect to the admin dashboard hosted separately
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          // In production, this will redirect to the admin dashboard
          // For now, we'll show a message that admin is separate
          _showAdminInfo();
        }
      });
    } else {
      // For mobile apps, show admin info
      _showAdminInfo();
    }
  }

  void _showAdminInfo() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Admin Dashboard'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The admin dashboard is accessible at:'),
            SizedBox(height: 8),
            Text(
              'https://www.omniasa.co.za/admin',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 16),
            Text('Please use the web browser to access the admin panel.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/home');
            },
            child: const Text('Go to Home'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // For web, try to redirect
              if (kIsWeb) {
                // This will be handled by the hosting configuration
                Navigator.of(context).pushReplacementNamed('/home');
              }
            },
            child: const Text('Open Admin'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Redirecting to Admin Dashboard...'),
          ],
        ),
      ),
    );
  }
}






