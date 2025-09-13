import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import 'simple_home_screen.dart';
import 'SellerRegistrationScreen.dart';
import 'seller_onboarding_screen.dart';

class PostLoginScreen extends StatefulWidget {
  const PostLoginScreen({Key? key}) : super(key: key);

  @override
  State<PostLoginScreen> createState() => _PostLoginScreenState();
}

class _PostLoginScreenState extends State<PostLoginScreen> with TickerProviderStateMixin {
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
    super.dispose();
  }

  Widget _buildWelcomeCard() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getHorizontalPadding(context),
        ),
        padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 1.5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.angel, AppTheme.whisper],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepTeal.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: AppTheme.deepTeal.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Success Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withOpacity(0.8)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: AppTheme.angel,
                size: ResponsiveUtils.getIconSize(context, baseSize: 40),
              ),
            ),
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
            
            // Welcome Text
            SafeUI.safeText(
              'Welcome Back!',
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context) + 8,
                fontWeight: FontWeight.bold,
                color: AppTheme.deepTeal,
              ),
              maxLines: 1,
            ),
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
            SafeUI.safeText(
              'You\'ve successfully logged in to OmniaSA',
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                color: AppTheme.mediumGrey,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsCard() {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getHorizontalPadding(context),
        ),
        padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 1.5),
        decoration: BoxDecoration(
          color: AppTheme.angel,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepTeal.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            SafeUI.safeText(
              'What would you like to do?',
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context),
                fontWeight: FontWeight.w600,
                color: AppTheme.deepTeal,
              ),
              maxLines: 1,
            ),
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
            SafeUI.safeText(
              'Tap "Continue as Buyer" to access the marketplace',
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                color: AppTheme.mediumGrey,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 1.5),
            
            // Continue as Buyer Button
            _buildOptionButton(
              title: 'Continue as Buyer',
              subtitle: 'Browse and order products (Recommended)',
              icon: Icons.shopping_bag_outlined,
              color: AppTheme.deepTeal,
              onTap: () async {
                // Save user's choice to skip this screen in future logins
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('has_chosen_buyer_${user.uid}', true);
                }
                
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SimpleHomeScreen()),
                );
              },
            ),
            
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
            
            // Register as Seller Button
            _buildOptionButton(
              title: 'Register as Seller',
              subtitle: 'Start selling on OmniaSA',
              icon: Icons.store_outlined,
              color: AppTheme.primaryGreen,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SellerOnboardingScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: ResponsiveUtils.getIconSize(context, baseSize: 24),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getHorizontalPadding(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SafeUI.safeText(
                        title,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getTitleSize(context),
                          fontWeight: FontWeight.w600,
                          color: AppTheme.deepTeal,
                        ),
                        maxLines: 1,
                      ),
                      SizedBox(height: 4),
                      SafeUI.safeText(
                        subtitle,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                          color: AppTheme.mediumGrey,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color,
                  size: ResponsiveUtils.getIconSize(context, baseSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPlatformFeeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Platform Fee Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepTeal,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Before you register as a seller, please note our platform fee structure:',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.darkGrey,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance.collection('admin_settings').doc('payment_settings').get(),
                builder: (context, snapshot) {
                  double? pct;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() ?? {};
                    final v = data['platformFeePercentage'];
                    if (v is num) pct = v.toDouble();
                    if (pct == null) pct = double.tryParse('$v');
                  }
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryGreen.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.percent, color: AppTheme.primaryGreen, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pct != null
                                ? 'Current platform commission: ${pct.toStringAsFixed(1)}% (may change)'
                                : 'Platform commission is set by the platform and may change',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.deepTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                'This fee helps us maintain the platform and provide support to all sellers.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.mediumGrey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppTheme.mediumGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SellerRegistrationScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: AppTheme.angel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Continue',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
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
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveUtils.getVerticalPadding(context) * 2,
              ),
              child: Column(
                children: [
                  SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 2),
                  
                  // Welcome Card
                  _buildWelcomeCard(),
                  SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 2),
                  
                  // Options Card
                  _buildOptionsCard(),
                  
                  SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 