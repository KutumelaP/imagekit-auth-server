import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/complete_auth_bypass.dart';
import '../services/emergency_fallback.dart';
import '../theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BypassLoginScreen extends StatefulWidget {
  @override
  _BypassLoginScreenState createState() => _BypassLoginScreenState();
}

class _BypassLoginScreenState extends State<BypassLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String _selectedRole = 'user';
  bool _isEmergencyMode = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _checkEmergencyMode();
    _checkPreviousSession();
  }

  Future<void> _checkEmergencyMode() async {
    final isEmergency = await EmergencyFallback.isEmergencyMode();
    setState(() {
      _isEmergencyMode = isEmergency;
    });
  }

  Future<void> _checkPreviousSession() async {
    try {
      // Check if there was a previous Firebase Auth session
      final prefs = await SharedPreferences.getInstance();
      final hadPreviousSession = prefs.getBool('had_previous_session') ?? false;
      
      if (hadPreviousSession) {
        setState(() {
          _status = 'Previous session cleared - please create new account';
        });
        // Clear the flag
        await prefs.setBool('had_previous_session', false);
      }
    } catch (e) {
      print('❌ Error checking previous session: $e');
    }
  }

  Future<void> _createBypassAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Create a new mock session with the provided details
      final userData = await CompleteAuthBypass.createMockSession(
        email: _emailController.text.trim(),
        role: _selectedRole,
        additionalData: {
          'displayName': _nameController.text.trim(),
          'phoneNumber': '',
          'createdAt': DateTime.now().toIso8601String(),
          'verified': true,
        },
      );

      // Load user data in the provider
      await context.read<UserProvider>().loadUserData();

      // Navigate to home screen
      Navigator.of(context).pushReplacementNamed('/');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Account created successfully!'),
          backgroundColor: AppTheme.deepTeal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error creating account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInAsGuest() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Create a guest session
      final userData = await CompleteAuthBypass.createMockSession(
        email: 'guest@example.com',
        role: 'user',
        additionalData: {
          'displayName': 'Guest User',
          'isGuest': true,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      // Load user data in the provider
      await context.read<UserProvider>().loadUserData();

      // Navigate to home screen
      Navigator.of(context).pushReplacementNamed('/');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Signed in as guest!'),
          backgroundColor: AppTheme.deepTeal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error signing in as guest: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bypass Login'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.security,
                        size: 48,
                        color: AppTheme.deepTeal,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bypass Authentication',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepTeal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a new account without Firebase Auth',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_isEmergencyMode) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '🚨 Emergency Mode Active',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (_status.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _status,
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Form Fields
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Role Selection
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Account Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('Customer')),
                  DropdownMenuItem(value: 'seller', child: Text('Seller')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Action Buttons
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                ElevatedButton(
                  onPressed: _createBypassAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deepTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Create Account'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _signInAsGuest,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.deepTeal,
                    side: BorderSide(color: AppTheme.deepTeal),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Continue as Guest'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/');
                  },
                  child: Text(
                    'Back to Home',
                    style: TextStyle(color: AppTheme.deepTeal),
                  ),
                ),
              ],

              const Spacer(),

              // Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About Bypass Authentication',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepTeal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• No Firebase Auth dependency\n'
                        '• Works offline\n'
                        '• No authentication errors\n'
                        '• All app features available\n'
                        '• Data stored locally',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
} 