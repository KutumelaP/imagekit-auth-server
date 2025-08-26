import 'package:flutter/material.dart';
import 'services/awesome_notification_service.dart';

/// Temporary widget to test notifications
/// Add this to any screen to test if notifications are working
class TestNotificationButton extends StatelessWidget {
  const TestNotificationButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () async {
        print('🔔 Testing awesome notifications...');
        await AwesomeNotificationService().showTestNotification();
        
        // Also check permissions
        final hasPermission = await AwesomeNotificationService().requestPermissions();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hasPermission 
              ? '🔔 Test notification sent! Check permissions: $hasPermission'
              : '❌ Notification permission denied: $hasPermission'),
            backgroundColor: hasPermission ? Colors.green : Colors.red,
          ),
        );
      },
      icon: const Icon(Icons.notification_add),
      label: const Text('Test Notification'),
      backgroundColor: Colors.orange,
    );
  }
}
