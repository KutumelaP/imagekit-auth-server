import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _updateConfigDoc = 'app_config';
  static const String _updateConfigId = 'app_updates';
  static const String _lastUpdateCheckKey = 'last_update_check';
  static const String _updateDismissedKey = 'update_dismissed_';

  // Current app version
  String? _currentVersion;
  String? _currentBuildNumber;

  // Update configuration from Firestore
  Map<String, dynamic>? _updateConfig;

  /// Initialize the update service
  Future<void> initialize() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;
      _currentBuildNumber = packageInfo.buildNumber;
      
      print('📱 Current app version: $_currentVersion+$_currentBuildNumber');
      
      // Load update configuration from Firestore
      await _loadUpdateConfig();
    } catch (e) {
      print('❌ Error initializing AppUpdateService: $e');
    }
  }

  /// Load update configuration from Firestore
  Future<void> _loadUpdateConfig() async {
    try {
      final doc = await _firestore
          .collection(_updateConfigDoc)
          .doc(_updateConfigId)
          .get();
      
      if (doc.exists) {
        _updateConfig = doc.data();
        print('✅ Loaded update config: $_updateConfig');
      } else {
        print('⚠️ No update config found in Firestore');
      }
    } catch (e) {
      print('❌ Error loading update config: $e');
    }
  }

  /// Check if app update is available
  Future<bool> isUpdateAvailable() async {
    if (_updateConfig == null) return false;
    
    final latestVersion = _updateConfig!['latest_version'] as String?;
    final latestBuildNumber = _updateConfig!['latest_build_number'] as String?;
    final updateEnabled = _updateConfig!['update_enabled'] as bool? ?? true;
    
    if (!updateEnabled || latestVersion == null || latestBuildNumber == null) {
      return false;
    }

    // Compare versions
    final currentVersionParts = _currentVersion?.split('.') ?? ['0', '0', '0'];
    final latestVersionParts = latestVersion.split('.');
    
    // Compare major.minor.patch
    for (int i = 0; i < 3; i++) {
      final current = int.tryParse(currentVersionParts[i]) ?? 0;
      final latest = int.tryParse(latestVersionParts[i]) ?? 0;
      
      if (latest > current) {
        return true;
      } else if (latest < current) {
        return false;
      }
    }
    
    // If versions are equal, compare build numbers
    final currentBuild = int.tryParse(_currentBuildNumber ?? '0') ?? 0;
    final latestBuild = int.tryParse(latestBuildNumber) ?? 0;
    
    return latestBuild > currentBuild;
  }

  /// Check if update should be shown (respects cooldown and dismissal)
  Future<bool> shouldShowUpdate() async {
    if (!await isUpdateAvailable()) return false;
    
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_lastUpdateCheckKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cooldownHours = _updateConfig?['check_cooldown_hours'] as int? ?? 24;
    final cooldownMs = cooldownHours * 60 * 60 * 1000;
    
    // Check cooldown
    if (now - lastCheck < cooldownMs) {
      return false;
    }
    
    // Check if user dismissed this version
    final latestVersion = _updateConfig!['latest_version'] as String?;
    if (latestVersion != null) {
      final dismissed = prefs.getBool('${_updateDismissedKey}$latestVersion') ?? false;
      if (dismissed) return false;
    }
    
    return true;
  }

  /// Show update dialog
  Future<void> checkAndShowUpdate(BuildContext context) async {
    if (!await shouldShowUpdate()) return;
    
    final latestVersion = _updateConfig!['latest_version'] as String?;
    final latestBuildNumber = _updateConfig!['latest_build_number'] as String?;
    final forceUpdate = _updateConfig!['force_update'] as bool? ?? false;
    final updateTitle = _updateConfig!['update_title'] as String? ?? 'App Update Available';
    final updateMessage = _updateConfig!['update_message'] as String? ?? 
        'A new version of OmniaSA is available with bug fixes and improvements.';
    final downloadUrl = _updateConfig!['download_url'] as String? ?? 
        'https://github.com/KutumelaP/imagekit-auth-server/releases/latest';
    
    // Update last check time
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastUpdateCheckKey, DateTime.now().millisecondsSinceEpoch);
    
    if (context.mounted) {
      _showUpdateDialog(
        context: context,
        title: updateTitle,
        message: updateMessage,
        currentVersion: '$_currentVersion+$_currentBuildNumber',
        latestVersion: '$latestVersion+$latestBuildNumber',
        downloadUrl: downloadUrl,
        forceUpdate: forceUpdate,
      );
    }
  }

  /// Show the update dialog
  void _showUpdateDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String currentVersion,
    required String latestVersion,
    required String downloadUrl,
    required bool forceUpdate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => WillPopScope(
        onWillPop: () async => !forceUpdate,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.system_update, color: Colors.blue, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 20))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Current Version:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(currentVersion, style: const TextStyle(fontFamily: 'monospace')),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Latest Version:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(latestVersion, style: const TextStyle(fontFamily: 'monospace', color: Colors.green)),
                      ],
                    ),
                  ],
                ),
              ),
              if (forceUpdate) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange[700], size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This update is required for the app to function properly.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () async {
                  // Mark as dismissed for this version
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('${_updateDismissedKey}$latestVersion', true);
                  Navigator.of(context).pop();
                },
                child: const Text('Later'),
              ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await _launchDownloadUrl(downloadUrl);
              },
              icon: const Icon(Icons.download),
              label: const Text('Update Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Launch download URL
  Future<void> _launchDownloadUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('❌ Could not launch download URL: $url');
      }
    } catch (e) {
      print('❌ Error launching download URL: $e');
    }
  }

  /// Force check for updates (for admin or manual check)
  Future<void> forceCheckForUpdates(BuildContext context) async {
    await _loadUpdateConfig();
    await checkAndShowUpdate(context);
  }

  /// Get update information for display
  Map<String, dynamic>? getUpdateInfo() {
    if (_updateConfig == null) return null;
    
    return {
      'current_version': '$_currentVersion+$_currentBuildNumber',
      'latest_version': '${_updateConfig!['latest_version']}+${_updateConfig!['latest_build_number']}',
      'update_available': _updateConfig!['update_enabled'] as bool? ?? false,
      'force_update': _updateConfig!['force_update'] as bool? ?? false,
      'update_title': _updateConfig!['update_title'] as String? ?? 'App Update Available',
      'update_message': _updateConfig!['update_message'] as String? ?? 'A new version is available.',
      'download_url': _updateConfig!['download_url'] as String? ?? '',
    };
  }
}
