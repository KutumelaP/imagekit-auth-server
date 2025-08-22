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
  bool _voiceAnnouncementsEnabled = false;
  bool _autoClearBadgeEnabled = false;
  String? _selectedLanguage;
  String? _selectedVoiceName;
  String? _selectedVoiceLocale;
  double _rate = 0.45;
  double _pitch = 1.0;
  double _volume = 1.0;

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
      _voiceAnnouncementsEnabled = _notificationService.voiceAnnouncementsEnabled;
      _autoClearBadgeEnabled = _notificationService.autoClearBadgeOnNotificationsOpen;
      _selectedLanguage = _notificationService.ttsLanguage;
      _selectedVoiceName = _notificationService.ttsVoiceName;
      _selectedVoiceLocale = _notificationService.ttsVoiceLocale;
      _rate = _notificationService.ttsRate;
      _pitch = _notificationService.ttsPitch;
      _volume = _notificationService.ttsVolume;
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
      case 'voice':
        await _notificationService.updateNotificationPreferences(
          voiceAnnouncements: value,
        );
        setState(() {
          _voiceAnnouncementsEnabled = value;
        });
        break;
      case 'autoClearBadge':
        await _notificationService.updateNotificationPreferences(
          autoClearBadgeOnNotificationsOpen: value,
        );
        setState(() {
          _autoClearBadgeEnabled = value;
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

            const SizedBox(height: 8),

            // Auto-Clear Badge
            Card(
              child: SwitchListTile(
                title: const Text('Auto Clear Badge on Open'),
                subtitle: const Text('Mark notifications read and clear badge when opening list'),
                value: _autoClearBadgeEnabled,
                onChanged: (value) => _updateSetting('autoClearBadge', value),
                activeColor: AppTheme.deepTeal,
                secondary: Icon(
                  Icons.do_not_disturb_on_total_silence,
                  color: _autoClearBadgeEnabled ? AppTheme.deepTeal : Colors.grey,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Voice Announcements
            Card(
              child: SwitchListTile(
                title: const Text('Voice Announcements'),
                subtitle: const Text('Spoken alerts like “You have a new order”'),
                value: _voiceAnnouncementsEnabled,
                onChanged: (value) => _updateSetting('voice', value),
                activeColor: AppTheme.deepTeal,
                secondary: Icon(
                  Icons.record_voice_over,
                  color: _voiceAnnouncementsEnabled ? AppTheme.deepTeal : Colors.grey,
                ),
              ),
            ),

            if (_voiceAnnouncementsEnabled) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Voice & Language', style: AppTheme.headlineSmall.copyWith(color: AppTheme.deepTeal)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedLanguage,
                              decoration: const InputDecoration(labelText: 'Language', border: OutlineInputBorder()),
                              items: (_notificationService.availableLanguages.isEmpty
                                      ? const ['en-US']
                                      : _notificationService.availableLanguages.cast<String>())
                                  .map((lang) => DropdownMenuItem<String>(value: lang, child: Text(lang)))
                                  .toList(),
                              onChanged: (v) async {
                                setState(() => _selectedLanguage = v);
                                await _notificationService.updateTtsPreferences(language: v);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedVoiceName,
                              decoration: const InputDecoration(labelText: 'Voice', border: OutlineInputBorder()),
                              items: (_notificationService.availableVoices)
                                  .map((v) {
                                    final name = (v is Map) ? (v['name']?.toString() ?? '') : v.toString();
                                    final locale = (v is Map) ? (v['locale']?.toString() ?? '') : '';
                                    return DropdownMenuItem<String>(
                                      value: name.isEmpty ? null : name,
                                      child: Text(name.isEmpty ? 'Default' : '$name ${locale.isNotEmpty ? '($locale)' : ''}'),
                                    );
                                  })
                                  .where((i) => i.value != null)
                                  .cast<DropdownMenuItem<String>>()
                                  .toList(),
                              onChanged: (v) async {
                                setState(() => _selectedVoiceName = v);
                                // Find selected locale from voices list if present
                                String? locale;
                                for (final vv in _notificationService.availableVoices) {
                                  if (vv is Map && vv['name'] == v) { locale = vv['locale']?.toString(); break; }
                                }
                                _selectedVoiceLocale = locale;
                                await _notificationService.updateTtsPreferences(voiceName: v, voiceLocale: locale);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Speed'),
                      Slider(
                        value: _rate,
                        min: 0.1,
                        max: 1.0,
                        divisions: 18,
                        label: _rate.toStringAsFixed(2),
                        onChanged: (v) async {
                          setState(() => _rate = v);
                          await _notificationService.updateTtsPreferences(rate: v);
                        },
                      ),
                      const SizedBox(height: 8),
                      Text('Pitch'),
                      Slider(
                        value: _pitch,
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        label: _pitch.toStringAsFixed(2),
                        onChanged: (v) async {
                          setState(() => _pitch = v);
                          await _notificationService.updateTtsPreferences(pitch: v);
                        },
                      ),
                      const SizedBox(height: 8),
                      Text('Volume'),
                      Slider(
                        value: _volume,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        label: _volume.toStringAsFixed(2),
                        onChanged: (v) async {
                          setState(() => _volume = v);
                          await _notificationService.updateTtsPreferences(volume: v);
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await _notificationService.speakPreview('Voice announcements enabled. This is a preview of your settings.');
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Preview'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deepTeal, foregroundColor: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
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
                    _buildSettingRow('Voice Announcements', _voiceAnnouncementsEnabled),
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