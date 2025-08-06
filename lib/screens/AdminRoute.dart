import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../screens/login_screen.dart';

class AdminRoute extends StatelessWidget {
  final Widget child;

  const AdminRoute({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    if (!userProvider.isLoggedIn) {
      // Not logged in → send to login
      return const LoginScreen();
    }

    if (!userProvider.isAdmin) {
      // Logged in but not admin → show unauthorized or redirect home
      return Scaffold(
        appBar: AppBar(title: const Text('Unauthorized')),
        body: const Center(child: Text('You do not have permission to view this page.')),
      );
    }

    // Admin → show the admin screen
    return child;
  }
}
