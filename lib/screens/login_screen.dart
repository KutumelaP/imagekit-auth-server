import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'simple_home_screen.dart';
import '../services/error_handler.dart';
import '../widgets/loading_widget.dart';

import '../providers/user_provider.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
import '../providers/cart_provider.dart';
import 'post_login_screen.dart';

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
      UserCredential userCredential;

      if (_isLogin) {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
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
      
      if (userProvider.isSeller) {
        // User is already a seller, go directly to home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SimpleHomeScreen()),
        );
      } else {
        // User is not a seller, show post-login options
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PostLoginScreen()),
        );
      }
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
            
            // Submit Button
            _buildBeautifulSubmitButton(),
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

