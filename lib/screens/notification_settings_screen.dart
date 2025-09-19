import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/enhanced_voice_notification_service.dart';
import '../theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  final EnhancedVoiceNotificationService _enhanced = EnhancedVoiceNotificationService();
  
  bool _systemNotificationsEnabled = true;
  bool _audioNotificationsEnabled = true;
  bool _inAppNotificationsEnabled = true;
  bool _voiceAnnouncementsEnabled = false;
  bool _assistantEnabled = true;
  bool _autoClearBadgeEnabled = false;
  bool _preferGoogleTts = true;
  String? _selectedLanguage;
  String? _selectedVoiceName;
  String _googleLanguage = 'en-US';
  String _googleVoiceName = 'en-US-Wavenet-C';
  double _rate = 0.45;
  double _pitch = 0.7;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  Future<void> _initSettings() async {
    try {
      await _enhanced.initialize();
      await _enhanced.fetchGoogleVoices();
    } catch (_) {}
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    setState(() {
      _systemNotificationsEnabled = _notificationService.systemNotificationsEnabled;
      _audioNotificationsEnabled = _notificationService.audioNotificationsEnabled;
      _inAppNotificationsEnabled = _notificationService.inAppNotificationsEnabled;
      _voiceAnnouncementsEnabled = _notificationService.voiceAnnouncementsEnabled;
      _assistantEnabled = _notificationService.assistantEnabled;
      _autoClearBadgeEnabled = _notificationService.autoClearBadgeOnNotificationsOpen;
      _selectedLanguage = _notificationService.ttsLanguage;
      _selectedVoiceName = _notificationService.ttsVoiceName;
      _rate = _notificationService.ttsRate;
      _pitch = _notificationService.ttsPitch;
      _volume = _notificationService.ttsVolume;
      _preferGoogleTts = _enhanced.preferGoogleTts;
      _googleLanguage = _enhanced.voiceLanguage ?? 'en-US';
      _googleVoiceName = _enhanced.voiceName;
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
      case 'preferGoogle':
        await _enhanced.updateVoicePreferences(preferGoogleTts: value);
        setState(() {
          _preferGoogleTts = value;
        });
        break;
      case 'assistant':
        await _notificationService.updateNotificationPreferences(
          assistantEnabled: value,
        );
        setState(() {
          _assistantEnabled = value;
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          },
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Container(
              decoration: AppTheme.primaryGradientDecoration(
                borderRadius: 16,
                boxShadow: AppTheme.complementaryGlow,
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white24,
                    ),
                    child: const Icon(Icons.notifications_active, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: AppTheme.displaySmall.copyWith(color: AppTheme.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Control alerts, sounds and voice announcements',
                          style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
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
                secondary: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _systemNotificationsEnabled
                          ? AppTheme.buttonGradient
                          : [AppTheme.veryLightGrey, AppTheme.veryLightGrey],
                    ),
                  ),
                  child: const Icon(Icons.notifications, color: Colors.white, size: 20),
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
                secondary: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _audioNotificationsEnabled
                          ? AppTheme.buttonGradient
                          : [AppTheme.veryLightGrey, AppTheme.veryLightGrey],
                    ),
                  ),
                  child: const Icon(Icons.volume_up, color: Colors.white, size: 20),
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
                secondary: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _inAppNotificationsEnabled
                          ? AppTheme.buttonGradient
                          : [AppTheme.veryLightGrey, AppTheme.veryLightGrey],
                    ),
                  ),
                  child: const Icon(Icons.message, color: Colors.white, size: 20),
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
                secondary: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _autoClearBadgeEnabled
                          ? AppTheme.buttonGradient
                          : [AppTheme.veryLightGrey, AppTheme.veryLightGrey],
                    ),
                  ),
                  child: const Icon(Icons.do_not_disturb_on_total_silence, color: Colors.white, size: 20),
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
                secondary: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _voiceAnnouncementsEnabled
                          ? AppTheme.buttonGradient
                          : [AppTheme.veryLightGrey, AppTheme.veryLightGrey],
                    ),
                  ),
                  child: const Icon(Icons.record_voice_over, color: Colors.white, size: 20),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Assistant
            Card(
              child: SwitchListTile(
                title: const Text('Assistant'),
                subtitle: const Text('Enable Nathan voice assistant'),
                value: _assistantEnabled,
                onChanged: (value) => _updateSetting('assistant', value),
                activeColor: AppTheme.deepTeal,
                secondary: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _assistantEnabled
                          ? AppTheme.buttonGradient
                          : [AppTheme.veryLightGrey, AppTheme.veryLightGrey],
                    ),
                  ),
                  child: const Icon(Icons.mic_none, color: Colors.white, size: 20),
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
                      Text('Voice & Language (Google first, local fallback)', style: AppTheme.headlineSmall.copyWith(color: AppTheme.deepTeal)),
                      const SizedBox(height: 12),
                      // Prefer Google TTS
                      SwitchListTile(
                        title: const Text('Use Google TTS (WaveNet)'),
                        subtitle: const Text('Higher quality voice; falls back to device TTS'),
                        value: _preferGoogleTts,
                        onChanged: (value) => _updateSetting('preferGoogle', value),
                        activeColor: AppTheme.deepTeal,
                      ),
                      const SizedBox(height: 8),
                      // Google language & voice
                      if (_preferGoogleTts) ...[
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final bool narrow = constraints.maxWidth < 360;

                            final Widget langDd = DropdownButtonFormField<String>(
                              value: _googleLanguage,
                              isDense: true,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Google Language', border: OutlineInputBorder()),
                              items: const [
                                'en-US', 'en-GB', 'en-AU'
                              ].map((lang) => DropdownMenuItem(value: lang, child: Text(lang, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) async {
                                if (v == null) return;
                                // Update language and reset voice to first valid option
                                final allVoices = _enhanced.availableGoogleVoices;
                                final fallbackPresets = const [
                                  // Neural2 voices (newest generation - ultra realistic)
                                  {'name': 'en-US-Wavenet-C', 'languageCodes': 'en-US', 'ssmlGender': 'FEMALE'},
                                  {'name': 'en-US-Neural2-D', 'languageCodes': 'en-US', 'ssmlGender': 'MALE'},
                                  {'name': 'en-US-Neural2-E', 'languageCodes': 'en-US', 'ssmlGender': 'MALE'},
                                  {'name': 'en-US-Neural2-A', 'languageCodes': 'en-US', 'ssmlGender': 'FEMALE'},
                                  {'name': 'en-US-Neural2-C', 'languageCodes': 'en-US', 'ssmlGender': 'FEMALE'},
                                  // WaveNet voices (high quality)
                                  {'name': 'en-US-Wavenet-D', 'languageCodes': 'en-US', 'ssmlGender': 'MALE'},
                                  {'name': 'en-US-Wavenet-C', 'languageCodes': 'en-US', 'ssmlGender': 'MALE'},
                                  {'name': 'en-US-Wavenet-B', 'languageCodes': 'en-US', 'ssmlGender': 'MALE'},
                                  {'name': 'en-US-Wavenet-A', 'languageCodes': 'en-US', 'ssmlGender': 'FEMALE'},
                                  // Other regions
                                  {'name': 'en-GB-Wavenet-B', 'languageCodes': 'en-GB', 'ssmlGender': 'MALE'},
                                  {'name': 'en-AU-Wavenet-B', 'languageCodes': 'en-AU', 'ssmlGender': 'MALE'},
                                ];
                                final filtered = allVoices.isEmpty
                                    ? fallbackPresets.where((m) => m['languageCodes'] == v).toList()
                                    : allVoices.where((m) => (m['languageCodes'] ?? '').contains(v)).toList();
                                setState(() {
                                  _googleLanguage = v;
                                  if (filtered.isNotEmpty) {
                                    _googleVoiceName = filtered.first['name'] ?? _googleVoiceName;
                                  }
                                });
                                await _enhanced.updateVoicePreferences(language: v);
                              },
                            );

                            final allVoices = _enhanced.availableGoogleVoices;
                            final fallbackPresets = const [
                              // Neural2 voices (newest generation - ultra realistic)
                              {'name': 'en-US-Wavenet-C', 'languageCodes': 'en-US', 'ssmlGender': 'FEMALE'},
                              {'name': 'en-US-Neural2-D', 'languageCodes': 'en-US', 'ssmlGender': 'MALE'},
                              {'name': 'en-US-Neural2-E', 'languageCodes': 'en-US', 'ssmlGender': 'MALE'},
                              {'name': 'en-US-Neural2-A', 'languageCodes': 'en-US', 'ssmlGender': 'FEMALE'},
                              {'name': 'en-US-Neural2-C', 'languageCodes': 'en-US', 'ssmlGender': 'FEMALE'},
                              // WaveNet voices (high quality)
                              {'name': 'en-US-Wavenet-D', 'languageCodes': 'en-US', 'ssmlGender': 'MALE'},
                              {'name': 'en-US-Wavenet-C', 'languageCodes': 'en-US', 'ssmlGender': 'MALE'},
                              {'name': 'en-US-Wavenet-B', 'languageCodes': 'en-US', 'ssmlGender': 'MALE'},
                              {'name': 'en-US-Wavenet-A', 'languageCodes': 'en-US', 'ssmlGender': 'FEMALE'},
                              // Other regions
                              {'name': 'en-GB-Wavenet-B', 'languageCodes': 'en-GB', 'ssmlGender': 'MALE'},
                              {'name': 'en-AU-Wavenet-B', 'languageCodes': 'en-AU', 'ssmlGender': 'MALE'},
                            ];
                            final filteredVoices = allVoices.isEmpty
                                ? fallbackPresets.where((m) => m['languageCodes'] == _googleLanguage).toList()
                                : allVoices.where((m) => (m['languageCodes'] ?? '').contains(_googleLanguage)).toList();
                            final names = filteredVoices.map((m) => (m['name'] ?? '').trim()).where((n) => n.isNotEmpty).toList();
                            final String? voiceValue = names.contains(_googleVoiceName)
                                ? _googleVoiceName
                                : (names.isNotEmpty ? names.first : null);

                            final Widget voiceDd = DropdownButtonFormField<String>(
                              value: voiceValue,
                              isDense: true,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Google Voice', border: OutlineInputBorder()),
                              items: filteredVoices
                                  .map((m) => DropdownMenuItem(
                                        value: m['name'],
                                        child: Text(
                                          m['name'] ?? '',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) async {
                                if (v == null) return;
                                setState(() => _googleVoiceName = v);
                                await _enhanced.updateVoicePreferences(voiceName: v);
                              },
                            );

                            final Widget voicePreviewBtn = ElevatedButton.icon(
                              onPressed: () async {
                                // Update voice config first
                                await _enhanced.updateVoicePreferences(voiceName: _googleVoiceName);
                                // Force Google TTS for preview
                                await _enhanced.forceGoogleTts('Hello! This is how I sound with the ${_googleVoiceName} voice. How do you like it?');
                              },
                              icon: const Icon(Icons.play_arrow, size: 18),
                              label: const Text('Preview Voice'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.deepTeal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            );

                            if (narrow) {
                              return Column(
                                children: [
                                  langDd,
                                  const SizedBox(height: 12),
                                  voiceDd,
                                  const SizedBox(height: 12),
                                  voicePreviewBtn,
                                ],
                              );
                            }

                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: langDd),
                                    const SizedBox(width: 12),
                                    Expanded(child: voiceDd),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                voicePreviewBtn,
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final bool stack = constraints.maxWidth < 360;

                          Widget langDropdown = Builder(
                            builder: (context) {
                              final rawLangs = _notificationService.availableLanguages.isEmpty
                                  ? const ['en-US']
                                  : _notificationService.availableLanguages.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
                              final langs = rawLangs.toSet().toList()..sort();
                              final String? langValue = langs.contains(_selectedLanguage)
                                  ? _selectedLanguage
                                  : (langs.isNotEmpty ? langs.first : 'en-US');
                              return DropdownButtonFormField<String>(
                                value: langValue,
                                isDense: true,
                                isExpanded: true,
                                decoration: const InputDecoration(labelText: 'Language', border: OutlineInputBorder()),
                                items: langs
                                    .map((lang) => DropdownMenuItem<String>(
                                          value: lang,
                                          child: Text(lang, overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: (v) async {
                                  setState(() => _selectedLanguage = v);
                                  await _notificationService.updateTtsPreferences(language: v);
                                },
                              );
                            },
                          );

                          Widget voiceDropdown = Builder(
                            builder: (context) {
                              final List<Map<String, String>> rawVoices = _notificationService.availableVoices.map((v) {
                                if (v is Map) {
                                  return {
                                    'name': (v['name']?.toString() ?? '').trim(),
                                    'locale': (v['locale']?.toString() ?? '').trim(),
                                  };
                                }
                                return {
                                  'name': v.toString().trim(),
                                  'locale': '',
                                };
                              }).toList();
                              final List<Map<String, String>> voices = [];
                              final seen = <String>{};
                              for (final m in rawVoices) {
                                final n = m['name'] ?? '';
                                if (n.isEmpty) continue;
                                if (seen.add(n)) voices.add(m);
                              }
                              final names = voices.map((e) => e['name']!).toList();
                              final String? voiceValue = names.contains(_selectedVoiceName)
                                  ? _selectedVoiceName
                                  : (names.isNotEmpty ? names.first : 'default');
                              return DropdownButtonFormField<String>(
                                value: voiceValue,
                                isDense: true,
                                isExpanded: true,
                                decoration: const InputDecoration(labelText: 'Voice', border: OutlineInputBorder()),
                                items: voices
                                    .map((m) {
                                      final n = m['name'] ?? '';
                                      final loc = m['locale'] ?? '';
                                      return DropdownMenuItem<String>(
                                        value: n,
                                        child: Text(loc.isNotEmpty ? '$n ($loc)' : n, overflow: TextOverflow.ellipsis),
                                      );
                                    })
                                    .toList(),
                                onChanged: (v) async {
                                  setState(() => _selectedVoiceName = v);
                                  String? locale;
                                  for (final m in voices) {
                                    if (m['name'] == v) {
                                      locale = m['locale'];
                                      break;
                                    }
                                  }
                                  await _notificationService.updateTtsPreferences(voiceName: v, voiceLocale: locale);
                                },
                              );
                            },
                          );

                          if (stack) {
                            return Column(
                              children: [
                                langDropdown,
                                const SizedBox(height: 12),
                                voiceDropdown,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: langDropdown),
                              const SizedBox(width: 12),
                              Expanded(child: voiceDropdown),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('Speed'),
                          const Spacer(),
                          TextButton(
                            onPressed: () async {
                              setState(() => _rate = 0.6);
                              await _notificationService.updateTtsPreferences(rate: 0.6);
                            },
                            child: Text('Natural', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      Text(
                        'Natural speed (0.6) sounds more conversational than robotic',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
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
                      Row(
                        children: [
                          Text('Pitch'),
                          const Spacer(),
                          TextButton(
                            onPressed: () async {
                              setState(() => _pitch = 0.9);
                              await _notificationService.updateTtsPreferences(pitch: 0.9);
                            },
                            child: Text('Natural', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      Text(
                        'Lower pitch (0.9) sounds less robotic and more human',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
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
                      
                      // Quick preset for human-like settings
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🎭 Human-like Voice Settings',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Apply optimal settings for natural, conversational voice with automatic text enhancement',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () async {
                                setState(() {
                                  _rate = 0.6;  // Natural conversation speed
                                  _pitch = 0.9; // Slightly lower, more human pitch
                                  _volume = 0.8; // Comfortable volume
                                });
                                await _notificationService.updateTtsPreferences(
                                  rate: 0.6,
                                  pitch: 0.9,
                                  volume: 0.8,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Applied human-like voice settings!')),
                                );
                              },
                              icon: Icon(Icons.psychology, size: 18),
                              label: Text('Make Voice Sound Human'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await _notificationService.speakPreview('Great news! Your order for R150 has been confirmed and will be delivered to Sandton in approximately 30 minutes.');
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Preview local TTS'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _preferGoogleTts
                                  ? () async {
                                      await _enhanced.previewGoogleTts('Great news! Your order for R150 has been confirmed and will be delivered to Sandton in approximately 30 minutes.');
                                    }
                                  : null,
                              icon: const Icon(Icons.cloud),
                              label: const Text('Preview Google TTS'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deepTeal, foregroundColor: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                    _buildSettingRow('Assistant', _assistantEnabled),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
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