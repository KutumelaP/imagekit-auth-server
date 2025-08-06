import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  
  bool _systemNotificationsEnabled = true;
  bool _audioNotificationsEnabled = true;
  bool _inAppNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    setState(() {
      _systemNotificationsEnabled = _notificationService.systemNotificationsEnabled;
      _audioNotificationsEnabled = _notificationService.audioNotificationsEnabled;
      _inAppNotificationsEnabled = _notificationService.inAppNotificationsEnabled;
    });
  }

  Future<void> _updateSetting(String setting, bool value) async {
    switch (setting) {
      case 'system':
        await _notificationService.updateNotificationPreferences(
          systemNotifications: value,
        );
        setState(() {
          _systemNotificationsEnabled = value;
        });
        break;
      case 'audio':
        await _notificationService.updateNotificationPreferences(
          audioNotifications: value,
        );
        setState(() {
          _audioNotificationsEnabled = value;
        });
        break;
      case 'inApp':
        await _notificationService.updateNotificationPreferences(
          inAppNotifications: value,
        );
        setState(() {
          _inAppNotificationsEnabled = value;
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification Preferences',
                      style: AppTheme.headlineMedium.copyWith(
                        color: AppTheme.deepTeal,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Choose how you want to receive notifications:',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // System Notifications
            Card(
              child: SwitchListTile(
                title: const Text('System Notifications'),
                subtitle: const Text('Show notifications in the system tray'),
                value: _systemNotificationsEnabled,
                onChanged: (value) => _updateSetting('system', value),
                activeColor: AppTheme.deepTeal,
                secondary: Icon(
                  Icons.notifications,
                  color: _systemNotificationsEnabled ? AppTheme.deepTeal : Colors.grey,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Audio Notifications
            Card(
              child: SwitchListTile(
                title: const Text('Audio Notifications'),
                subtitle: const Text('Play sound when receiving notifications'),
                value: _audioNotificationsEnabled,
                onChanged: (value) => _updateSetting('audio', value),
                activeColor: AppTheme.deepTeal,
                secondary: Icon(
                  Icons.volume_up,
                  color: _audioNotificationsEnabled ? AppTheme.deepTeal : Colors.grey,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // In-App Notifications
            Card(
              child: SwitchListTile(
                title: const Text('In-App Notifications'),
                subtitle: const Text('Show notification cards within the app'),
                value: _inAppNotificationsEnabled,
                onChanged: (value) => _updateSetting('inApp', value),
                activeColor: AppTheme.deepTeal,
                secondary: Icon(
                  Icons.message,
                  color: _inAppNotificationsEnabled ? AppTheme.deepTeal : Colors.grey,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Test Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Your Settings',
                      style: AppTheme.headlineSmall.copyWith(
                        color: AppTheme.deepTeal,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await _notificationService.sendLocalNotification(
                          title: 'Test Notification',
                          body: 'This is a test notification with your current settings!',
                          data: {'type': 'test'},
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.deepTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Send Test Notification'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Current Settings Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Settings',
                      style: AppTheme.headlineSmall.copyWith(
                        color: AppTheme.deepTeal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSettingRow('System Notifications', _systemNotificationsEnabled),
                    _buildSettingRow('Audio Notifications', _audioNotificationsEnabled),
                    _buildSettingRow('In-App Notifications', _inAppNotificationsEnabled),
                  ],
                ),
              ),
            ),
            
            const Spacer(),
            
            // Info Card
            Card(
              color: AppTheme.whisper,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.deepTeal),
                        const SizedBox(width: 8),
                        Text(
                          'Notification Types',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.deepTeal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• System: Appears in your device\'s notification tray\n'
                      '• Audio: Plays a sound when notifications arrive\n'
                      '• In-App: Shows notification cards within the app',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(String title, bool enabled) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.cancel,
            color: enabled ? AppTheme.success : AppTheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: enabled ? Colors.black87 : Colors.grey,
              fontWeight: enabled ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          const Spacer(),
          Text(
            enabled ? 'ON' : 'OFF',
            style: TextStyle(
              color: enabled ? AppTheme.success : AppTheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 