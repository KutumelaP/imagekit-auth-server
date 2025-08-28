import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marketplace_app/utils/web_js_stub.dart'
    if (dart.library.html) 'package:marketplace_app/utils/web_js_real.dart' as js;

/// 🚀 Service for smart PWA install prompts for non-installed users
class InstallPromptService {
  static final InstallPromptService _instance = InstallPromptService._internal();
  factory InstallPromptService() => _instance;
  InstallPromptService._internal();

  static const String _installDismissedKey = 'install_prompt_dismissed';
  static const String _installReminderKey = 'install_reminder_count';
  static const String _lastPromptKey = 'last_install_prompt';

  /// Check if user has PWA installed
  static bool get isPWAInstalled {
    if (!kIsWeb) return true;
    
    try {
      // Check if running in standalone mode
      final isStandalone = js.context.callMethod('eval', [
        'window.matchMedia && window.matchMedia("(display-mode: standalone)").matches'
      ]);
      
      // Check if iOS standalone
      final isIOSStandalone = js.context.callMethod('eval', [
        'window.navigator.standalone === true'
      ]);
      
      return isStandalone == true || isIOSStandalone == true;
    } catch (e) {
      return false;
    }
  }

  /// Show smart install prompt for store links
  static Future<void> showStoreInstallPrompt(BuildContext context, String storeName) async {
    if (isPWAInstalled) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool(_installDismissedKey) ?? false;
      final reminderCount = prefs.getInt(_installReminderKey) ?? 0;
      final lastPrompt = prefs.getInt(_lastPromptKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Don't show if permanently dismissed or shown recently
      if (dismissed || (now - lastPrompt) < Duration(hours: 24).inMilliseconds) {
        return;
      }
      
      // Show different prompts based on reminder count
      if (reminderCount < 3) {
        await _showStoreSpecificPrompt(context, storeName);
        await prefs.setInt(_installReminderKey, reminderCount + 1);
        await prefs.setInt(_lastPromptKey, now);
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error showing store install prompt: $e');
    }
  }

  /// Show store-specific install prompt
  static Future<void> _showStoreSpecificPrompt(BuildContext context, String storeName) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.store, color: Theme.of(context).primaryColor),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Install App for $storeName',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get the best shopping experience at $storeName:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            _buildBenefitRow('⚡', 'Faster loading and smoother navigation'),
            _buildBenefitRow('🔔', 'Real-time order and message notifications'),
            _buildBenefitRow('📱', 'Works offline and saves to home screen'),
            _buildBenefitRow('🛒', 'Better checkout and cart experience'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can still shop without installing, but the experience is much better with the app!',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _markInstallDismissed();
            },
            child: Text('No thanks'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Just dismiss for now, they can continue shopping
            },
            child: Text('Maybe later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              showInstallInstructions(context);
            },
            icon: Icon(Icons.download, size: 18),
            label: Text('Install App'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build benefit row widget
  static Widget _buildBenefitRow(String emoji, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Show device-specific install instructions
  static Future<void> showInstallInstructions(BuildContext context) async {
    final isIOS = await _isIOSDevice();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isIOS ? '📱 Install on iPhone/iPad' : '📱 Install on Android',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: isIOS 
            ? _buildIOSInstructions()
            : _buildAndroidInstructions(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Got it!'),
          ),
        ],
      ),
    );
  }

  /// Build iOS installation instructions
  static List<Widget> _buildIOSInstructions() {
    return [
      _buildInstructionStep('1', '🔗', 'Tap the Share button at the bottom of Safari'),
      _buildInstructionStep('2', '🏠', 'Scroll down and tap "Add to Home Screen"'),
      _buildInstructionStep('3', '✅', 'Tap "Add" to confirm'),
      _buildInstructionStep('4', '🚀', 'Open the app from your home screen!'),
      SizedBox(height: 12),
      Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '💡 Tip: The installed app is much faster and works offline!',
          style: TextStyle(
            fontSize: 13,
            color: Colors.green.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ];
  }

  /// Build Android installation instructions
  static List<Widget> _buildAndroidInstructions() {
    return [
      _buildInstructionStep('1', '⋮', 'Tap the menu (3 dots) in Chrome'),
      _buildInstructionStep('2', '🏠', 'Tap "Add to Home screen"'),
      _buildInstructionStep('3', '✅', 'Tap "Add" to confirm'),
      _buildInstructionStep('4', '🚀', 'Open the app from your home screen!'),
      SizedBox(height: 12),
      Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '💡 You may also see an automatic "Install" banner at the bottom!',
          style: TextStyle(
            fontSize: 13,
            color: Colors.blue.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ];
  }

  /// Build instruction step widget
  static Widget _buildInstructionStep(String number, String emoji, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          Text(emoji, style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Check if device is iOS
  static Future<bool> _isIOSDevice() async {
    if (!kIsWeb) return false;
    
    try {
      final userAgent = js.context.callMethod('eval', ['navigator.userAgent']);
      return userAgent?.toString().contains(RegExp(r'iPad|iPhone|iPod')) == true;
    } catch (e) {
      return false;
    }
  }

  /// Mark install prompt as permanently dismissed
  static Future<void> _markInstallDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_installDismissedKey, true);
    } catch (e) {
      if (kDebugMode) print('❌ Error marking install dismissed: $e');
    }
  }

  /// Show subtle install reminder in store
  static Widget buildInstallReminderBanner(BuildContext context, String storeName) {
    if (isPWAInstalled) return SizedBox.shrink();
    
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.indigo.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.download, color: Colors.blue.shade700),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Install App for Better Experience',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
                Text(
                  'Faster shopping, notifications, offline access',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => showStoreInstallPrompt(context, storeName),
            child: Text('Install'),
          ),
        ],
      ),
    );
  }
}
