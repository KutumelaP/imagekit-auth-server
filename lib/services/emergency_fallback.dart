import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Emergency fallback system - completely bypasses all Firebase services
class EmergencyFallback {
  static const String _emergencyModeKey = 'emergency_mode';
  static const String _offlineDataKey = 'offline_data';
  
  /// Enable emergency mode
  static Future<void> enableEmergencyMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_emergencyModeKey, true);
      print('🚨 Emergency mode enabled - all Firebase services disabled');
    } catch (e) {
      print('❌ Error enabling emergency mode: $e');
    }
  }
  
  /// Disable emergency mode
  static Future<void> disableEmergencyMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_emergencyModeKey, false);
      print('✅ Emergency mode disabled');
    } catch (e) {
      print('❌ Error disabling emergency mode: $e');
    }
  }
  
  /// Check if emergency mode is active
  static Future<bool> isEmergencyMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_emergencyModeKey) ?? false;
    } catch (e) {
      print('❌ Error checking emergency mode: $e');
      return false;
    }
  }
  
  /// Store offline data
  static Future<void> storeOfflineData(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$key', jsonEncode(data));
      print('✅ Offline data stored: $key');
    } catch (e) {
      print('❌ Error storing offline data: $e');
    }
  }
  
  /// Get offline data
  static Future<dynamic> getOfflineData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataString = prefs.getString('$key');
      if (dataString != null) {
        return jsonDecode(dataString);
      }
      return null;
    } catch (e) {
      print('❌ Error getting offline data: $e');
      return null;
    }
  }
  
  /// Show emergency mode dialog
  static void showEmergencyModeDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🚨 Emergency Mode'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The app is experiencing critical Firebase issues.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Emergency mode has been activated to prevent crashes.',
            ),
            SizedBox(height: 16),
            Text(
              'FEATURES AVAILABLE:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Browse products (offline data)'),
            Text('• View categories'),
            Text('• Basic navigation'),
            Text('• Settings'),
            SizedBox(height: 16),
            Text(
              'FEATURES DISABLED:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• User authentication'),
            Text('• Real-time data'),
            Text('• Chat functionality'),
            Text('• Order management'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
          ElevatedButton(
            onPressed: () async {
              await disableEmergencyMode();
              Navigator.of(context).pop();
              // Restart the app
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/home',
                (route) => false,
              );
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
  
  /// Initialize emergency mode with sample data
  static Future<void> initializeEmergencyData() async {
    try {
      // Sample categories
      final categories = [
        {'id': '1', 'name': 'Fruits & Vegetables', 'image': '🍎'},
        {'id': '2', 'name': 'Dairy & Eggs', 'image': '🥛'},
        {'id': '3', 'name': 'Bread & Bakery', 'image': '🍞'},
        {'id': '4', 'name': 'Meat & Fish', 'image': '🥩'},
      ];
      
      // Sample products
      final products = [
        {
          'id': '1',
          'name': 'Fresh Apples',
          'price': 2.99,
          'category': 'Fruits & Vegetables',
          'image': '🍎',
          'description': 'Fresh, crisp apples from local farms',
        },
        {
          'id': '2',
          'name': 'Organic Milk',
          'price': 3.49,
          'category': 'Dairy & Eggs',
          'image': '🥛',
          'description': 'Fresh organic milk from local dairy',
        },
        {
          'id': '3',
          'name': 'Artisan Bread',
          'price': 4.99,
          'category': 'Bread & Bakery',
          'image': '🍞',
          'description': 'Freshly baked artisan bread',
        },
      ];
      
      await storeOfflineData('categories', categories);
      await storeOfflineData('products', products);
      
      print('✅ Emergency data initialized');
    } catch (e) {
      print('❌ Error initializing emergency data: $e');
    }
  }
} 