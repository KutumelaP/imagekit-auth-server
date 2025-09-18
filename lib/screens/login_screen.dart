import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'simple_home_screen.dart';
import '../services/error_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/biometric_stepup.dart';
import 'driver_login_screen.dart';

import '../providers/user_provider.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
import '../providers/cart_provider.dart';
import 'post_login_screen.dart';
import '../services/notification_service.dart';
import '../services/secure_credential_store.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _quickLoginEnabled = true; // opt-in; default on

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();

    _loadQuickLoginPref();
  }

  Future<void> _loadQuickLoginPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _quickLoginEnabled = prefs.getBool('quick_login_biometrics') ?? true;
      });
    } catch (_) {}
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(text: _emailController.text.trim());
    final ok = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Reset password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Enter your account email. We will send a reset link.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'you@example.com',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Send')),
              ],
            );
          },
        ) ??
        false;

    if (!ok) return;

    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your email')));
      return;
    }

    try {
      setState(() => _loading = true);
      await _callRiskGate('password_reset');
      try {
        final callable = FirebaseFunctions.instance.httpsCallable('sendPasswordResetEmail');
        await callable.call(<String, dynamic>{ 'email': email });
      } catch (_) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset email sent. Check your inbox.')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = ErrorHandler.handleAuthException(e);
      ErrorHandler.showError(context, message);
    } catch (e) {
      if (!mounted) return;
      final message = ErrorHandler.handleGeneralException(e);
      ErrorHandler.showError(context, message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      Map<String, dynamic> gate = {};
      try {
        gate = await _callRiskGate(_isLogin ? 'login' : 'signup');
        if (kDebugMode) {
          print('🔐 Auth gate result: $gate');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Auth gate failed: $e');
        }
      }

      UserCredential userCredential;

      if (_isLogin) {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // Save credentials for quick login if enabled
        try {
          if (_quickLoginEnabled) {
            await SecureCredentialStore.saveCredentials(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );
          }
        } catch (_) {}
      } else {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = userCredential.user;
        if (user != null) {
          final userDoc = FirebaseFirestore.instance.collection(AppConstants.usersCollection).doc(user.uid);
          final docSnapshot = await userDoc.get();
          if (!docSnapshot.exists) {
            await userDoc.set({
              'email': user.email,
              'role': AppConstants.roleUser,
              'createdAt': FieldValue.serverTimestamp(),
              'suspended': false,
            });
          }
          // TTS welcome (buyer/user)
          try {
            await NotificationService().speakPreview('Welcome aboard! Let’s find something lekker today.');
          } catch (_) {}
        }
      }

      // Step-up if risky (vpn or gate not ok)
      final isRisky = (gate['ok'] == false) || (gate['ipInfo'] != null && gate['ipInfo']['vpn'] == true);
      if (isRisky) {
        // 1) Biometric
        final bioOk = await _performBiometricStepUpLogin();
        if (!bioOk) {
          final choice = await showModalBottomSheet<String>(
            context: context,
            builder: (context) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Verify via Email'), onTap: () => Navigator.pop(context, 'email')),
                  ],
                ),
              );
            },
          );

          if (choice == 'email') {
            final ok = await _performEmailOtpStepUpLogin(_emailController.text.trim());
            if (!ok) {
              await FirebaseAuth.instance.signOut();
              if (mounted) ErrorHandler.showError(context, 'Verification failed.');
              return;
            }
          }
        }
      }

      // Load user data in provider (only once)
      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.loadUserData();
        
        // Sync cart to Firestore when user logs in
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        await cartProvider.syncCartToFirestore();
      }

      // Navigate to SimpleHomeScreen on successful login/signup
      if (!mounted) return;
      
      // Check if user is already a seller (user data already loaded above)
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // Return success result instead of navigating away
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      final message = ErrorHandler.handleAuthException(e);
      if (mounted) {
        ErrorHandler.showError(context, message);
      }
    } catch (e) {
      final message = ErrorHandler.handleGeneralException(e);
      if (mounted) {
        ErrorHandler.showError(context, message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('device_id');
    if (existing != null && existing.isNotEmpty) return existing;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final micro = DateTime.now().microsecondsSinceEpoch % 1000000;
    final newId = 'dev_${timestamp}_$micro';
    await prefs.setString('device_id', newId);
    return newId;
  }

  Future<Map<String, dynamic>> _callRiskGate(String action) async {
    try {
      final deviceId = await _getOrCreateDeviceId();
      final callable = FirebaseFunctions.instance.httpsCallable('riskGate');
      final result = await callable.call<Map<String, dynamic>>({
        'action': action,
        'deviceId': deviceId,
      });
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      return {'error': e.message, 'code': e.code};
    } catch (e) {
      return {'error': e.toString(), 'code': 'unknown'};
    }
  }

  Future<bool> _performBiometricStepUpLogin() async {
    return await BiometricStepUp.authenticate(reason: 'Confirm it’s you with fingerprint/Face ID');
  }

  Future<void> _tryBiometricQuickLogin() async {
    try {
      if (!_quickLoginEnabled) return;
      setState(() => _loading = true);
      final ok = await BiometricStepUp.authenticate(reason: 'Quick login with biometrics');
      if (!ok) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometric check failed')));
        return;
      }
      // If email is filled, attempt sign-in; else try secure store
      String email = _emailController.text.trim();
      String pass = _passwordController.text.trim();
      if (email.isEmpty || pass.isEmpty) {
        final creds = await SecureCredentialStore.readCredentials();
        if (creds != null) {
          email = creds['email'] ?? '';
          pass = creds['password'] ?? '';
        }
      }
      if (email.isEmpty || pass.isEmpty) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter email and password once, then use Quick login.')));
        return;
      }
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
      if (!mounted) return;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadUserData();
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.syncCartToFirestore();
      // Return success result instead of navigating away
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, ErrorHandler.handleGeneralException(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _performEmailOtpStepUpLogin(String email) async {
    try {
      final callableCreate = FirebaseFunctions.instance.httpsCallable('createEmailOtp');
      await callableCreate.call(<String, dynamic>{ 'email': email });
      if (!mounted) return false;
      final codeController = TextEditingController();
      final ok = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Enter email code'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('We sent a 6‑digit code to your email.'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(counterText: '', border: OutlineInputBorder(), hintText: '123456'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Verify')),
                ],
              );
            },
          ) ??
          false;
      if (!ok) return false;
      final code = codeController.text.trim();
      if (code.length != 6) return false;
      final callableVerify = FirebaseFunctions.instance.httpsCallable('verifyEmailOtp');
      final result = await callableVerify.call<Map<String, dynamic>>({ 'code': code });
      return (result.data['ok'] == true);
    } catch (_) {
      return false;
    }
  }

  // SMS step-up removed to keep free options only

  Widget _buildBeautifulLogo() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.angel, AppTheme.whisper],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.deepTeal.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: AppTheme.deepTeal.withOpacity(0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
              border: Border.all(
                color: AppTheme.deepTeal.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/logo.png',
                width: ResponsiveUtils.isMobile(context) ? 100 : 120,
                height: ResponsiveUtils.isMobile(context) ? 100 : 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to icon if logo image fails to load
                  return Container(
                    width: ResponsiveUtils.isMobile(context) ? 100 : 120,
                    height: ResponsiveUtils.isMobile(context) ? 100 : 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.deepTeal, AppTheme.cloud],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: ResponsiveUtils.getIconSize(context, baseSize: 50),
                      color: AppTheme.angel,
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.8),
          // Brand tagline
          SafeUI.safeText(
            'Fresh • Local • Delivered',
            style: TextStyle(
              fontSize: ResponsiveUtils.getTitleSize(context) - 4,
              fontWeight: FontWeight.w500,
              color: AppTheme.deepTeal.withOpacity(0.7),
              letterSpacing: 2.0,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
                  SafeUI.safeText(
            AppConstants.appName,
            style: TextStyle(
              fontSize: ResponsiveUtils.getTitleSize(context) + 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepTeal,
              letterSpacing: 1.2,
            ),
            maxLines: 1,
          ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
          SafeUI.safeText(
            _isLogin ? 'Welcome back! Sign in to continue' : 'Join our amazing marketplace community',
            style: TextStyle(
              fontSize: ResponsiveUtils.getTitleSize(context) - 6,
              color: AppTheme.mediumGrey,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _buildEnhancedFormCard() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getHorizontalPadding(context),
      ),
      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 1.5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.05),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
        border: Border.all(
          color: AppTheme.breeze.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Email Field
            _buildEnhancedTextField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'Enter your email',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: ErrorHandler.validateEmail,
            ),
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
            
            // Password Field
            _buildEnhancedTextField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Enter your password',
              prefixIcon: Icons.lock_outlined,
              obscureText: _obscurePassword,
              validator: ErrorHandler.validatePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppTheme.mediumGrey,
                  size: ResponsiveUtils.getIconSize(context, baseSize: 20),
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 1.5),

            // Forgot Password and Driver Login links
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _loading ? null : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DriverLoginScreen()),
                    );
                  },
                  child: SafeUI.safeText(
                    'Login as Driver',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                      color: AppTheme.deepTeal,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                  ),
                ),
                TextButton(
                  onPressed: _loading ? null : _showForgotPasswordDialog,
                  child: SafeUI.safeText(
                    'Forgot password?',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                      color: AppTheme.deepTeal,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),

            // Submit Button
            _buildBeautifulSubmitButton(),

            // Quick login row
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Switch(
                        value: _quickLoginEnabled,
                        onChanged: _loading ? null : (v) async {
                          setState(() { _quickLoginEnabled = v; });
                          try { final p = await SharedPreferences.getInstance(); await p.setBool('quick_login_biometrics', v); } catch (_) {}
                        },
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: SafeUI.safeText(
                          'Use fingerprint/Face ID',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                            color: AppTheme.darkGrey,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: (_loading || !_quickLoginEnabled) ? null : _tryBiometricQuickLogin,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Quick login'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.deepTeal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                    SafeUI.safeText(
              label,
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGrey,
              ),
              maxLines: 1,
            ),
        SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.3),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.cloud.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            enabled: !_loading,
            style: TextStyle(
              fontSize: ResponsiveUtils.getTitleSize(context) - 2,
              color: AppTheme.darkGrey,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AppTheme.mediumGrey,
                fontSize: ResponsiveUtils.getTitleSize(context) - 2,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.whisper, AppTheme.angel],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  prefixIcon,
                  color: AppTheme.darkGrey,
                  size: ResponsiveUtils.getIconSize(context, baseSize: 20),
                ),
              ),
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: AppTheme.angel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.warmAccentColor),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.getHorizontalPadding(context),
                vertical: ResponsiveUtils.getVerticalPadding(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBeautifulSubmitButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: _loading 
          ? LinearGradient(colors: [AppTheme.breeze, AppTheme.cloud])
          : AppTheme.primaryButtonGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _loading ? [] : AppTheme.complementaryElevation,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _loading ? null : _submit,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.getHorizontalPadding(context),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_loading) ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.angel),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                ] else ...[
                  Icon(
                    _isLogin ? Icons.login_outlined : Icons.person_add_outlined,
                    color: AppTheme.angel,
                    size: ResponsiveUtils.getIconSize(context, baseSize: 22),
                  ),
                  SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                ],
                SafeUI.safeText(
                  _loading 
                    ? (_isLogin ? 'Signing in...' : 'Creating account...')
                    : (_isLogin ? 'Sign In' : 'Create Account'),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.angel,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleSection() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getHorizontalPadding(context),
      ),
      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.whisper, AppTheme.angel],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.breeze.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SafeUI.safeText(
            _isLogin ? "Don't have an account? " : "Already have an account? ",
            style: TextStyle(
              fontSize: ResponsiveUtils.getTitleSize(context) - 2,
              color: AppTheme.breeze,
            ),
            maxLines: 1,
          ),
          TextButton(
            onPressed: _loading ? null : () {
              setState(() => _isLogin = !_isLogin);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: SafeUI.safeText(
              _isLogin ? 'Sign Up' : 'Sign In',
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                color: AppTheme.deepTeal,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection() {
    if (_isLogin) return const SizedBox.shrink();
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getHorizontalPadding(context),
      ),
      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.warmAccentColor.withOpacity(0.1), AppTheme.angel],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.warmAccentColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AppTheme.warmAccentColor,
            size: ResponsiveUtils.getIconSize(context, baseSize: 20),
          ),
          SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
          Expanded(
            child: SafeUI.safeText(
              'By creating an account, you agree to our Terms of Service and Privacy Policy.',
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context) - 6,
                color: AppTheme.warmAccentColor,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.angel,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.screenBackgroundGradient,
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveUtils.getVerticalPadding(context) * 2,
                ),
                child: Column(
                  children: [
                    SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 2),
                    
                    // Beautiful Logo
                    _buildBeautifulLogo(),
                    SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 1.5),
                    
                    // Welcome Text
                    _buildWelcomeText(),
                    SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 2),
                    
                    // Enhanced Form Card
                    _buildEnhancedFormCard(),
                    SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 1.5),
                    
                    // Toggle Section
                    _buildToggleSection(),
                    SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                    
                    // Terms Section
                    _buildTermsSection(),
                    
                    SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                    
                    
                    SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 2),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

