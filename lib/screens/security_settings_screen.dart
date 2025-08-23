import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _quickLoginEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _quickLoginEnabled = prefs.getBool('quick_login_biometrics') ?? true;
      _loading = false;
    });
  }

  Future<void> _setQuickLogin(bool v) async {
    setState(() => _quickLoginEnabled = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quick_login_biometrics', v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Settings'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppTheme.whisper,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SwitchListTile.adaptive(
                    value: _quickLoginEnabled,
                    onChanged: _setQuickLogin,
                    title: const Text('Quick login (fingerprint / Face ID)'),
                    subtitle: const Text('Sign in faster on supported devices'),
                    activeColor: AppTheme.deepTeal,
                  ),
                ),
              ],
            ),
    );
  }
}
