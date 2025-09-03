import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'SellerRegistrationScreen.dart';

class SellerOnboardingScreen extends StatefulWidget {
  const SellerOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<SellerOnboardingScreen> createState() => _SellerOnboardingScreenState();
}

class _SellerOnboardingScreenState extends State<SellerOnboardingScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  late TabController _tabController;
  int _currentPage = 0;
  bool _hasReadTerms = false;
  bool _hasReadPaymentTerms = false;
  bool _hasReadReturnPolicy = false;
  double? _platformFeePct;
  // Live pricing settings
  double? _pickupPct;
  double? _merchantDeliveryPct;
  double? _platformDeliveryPct;
  double? _commissionMin;
  double? _capPickup;
  double? _capMerchant;
  double? _capPlatform;
  double? _buyerServiceFeePct;
  double? _buyerServiceFeeFixed;
  double? _smallOrderFee;
  double? _smallOrderThreshold;
  double? _payfastFeePercentage;
  double? _payfastFixedFee;

  List<OnboardingStep> get _steps => [
    OnboardingStep(
      title: 'Welcome to Mzansi Marketplace!',
      subtitle: 'Your journey to successful selling starts here',
      icon: Icons.store,
      color: AppTheme.primaryGreen,
      content: [
        'Join thousands of successful sellers',
        'Reach customers across South Africa',
        'Flexible delivery options',
        'Secure payment processing',
        '24/7 platform support'
      ],
    ),
    OnboardingStep(
      title: 'How Payments Work',
      subtitle: 'Transparent and secure payment system',
      icon: Icons.payment,
      color: AppTheme.deepTeal,
      content: [
        'Customers pay via PayFast (secure)',
        'You receive 100% of earnings after order completion',
        'No holdback period - money available immediately',
        'Platform fees handled separately by admin',
        'PayFast fees: ${_payfastFeePercentage?.toStringAsFixed(1) ?? "3.5"}% + R${_payfastFixedFee?.toStringAsFixed(0) ?? "2"} per transaction',
        'Request payouts when you want (minimum R100)'
      ],
    ),
    OnboardingStep(
      title: 'Fees & Payouts',
      subtitle: 'Transparent rates and payouts, always visible',
      icon: Icons.receipt_long,
      color: AppTheme.primaryGreen,
      content: [
        'Commission varies by order type',
        'Buyer pays a small service fee',
        'Weekly payouts (minimum R100)',
        'COD commission settled via payout/top-up',
      ],
    ),
    OnboardingStep(
      title: 'Return & Refund Policy',
      subtitle: 'Fair protection for both sellers and customers',
      icon: Icons.assignment_return,
      color: AppTheme.warmAccentColor,
      content: [
        '7-day return window for most products',
        'No returns for food items (safety)',
        'Returns must be valid (defective, wrong item, etc.)',
        'Returns affect your available balance directly',
        'Platform mediates all return disputes',
        'Admin reviews all returns for fairness'
      ],
    ),
    OnboardingStep(
      title: 'Your Responsibilities',
      subtitle: 'What we expect from our sellers',
      icon: Icons.check_circle,
      color: AppTheme.primaryGreen,
      content: [
        'Provide accurate product descriptions',
        'Maintain quality standards',
        'Respond to customer inquiries promptly',
        'Handle orders within agreed timeframes',
        'Follow platform guidelines and policies'
      ],
    ),
    OnboardingStep(
      title: 'Delivery Options',
      subtitle: 'Flexible delivery to suit your business',
      icon: Icons.delivery_dining,
      color: AppTheme.deepTeal,
      content: [
        'Platform delivery (our drivers)',
        'Seller delivery (your own delivery)',
        'Hybrid delivery (both options)',
        'Pickup only (customers collect)',
        'Nationwide pickup (Pargo/PAXI services)',
        'Set your own delivery fees and ranges',
        'Category-aware delivery caps (food: 20km, others: 50km)'
      ],
    ),
    OnboardingStep(
      title: 'Support & Success',
      subtitle: 'We\'re here to help you succeed',
      icon: Icons.support_agent,
      color: AppTheme.warmAccentColor,
      content: [
        '24/7 customer support',
        'Seller success resources',
        'Marketing and promotion tools',
        'Analytics and performance insights',
        'Regular platform updates and improvements'
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _tabController = TabController(length: _steps.length, vsync: this);
    _loadPricingSettings();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      setState(() {
        _currentPage++;
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _tabController.animateTo(_currentPage);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _tabController.animateTo(_currentPage);
    }
  }

  Future<void> _loadPricingSettings() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('admin_settings').doc('payment_settings').get();
      final data = doc.data() ?? {};
      setState(() {
        // legacy single percentage
        final pct = (data['platformFeePercentage'] is num)
            ? (data['platformFeePercentage'] as num).toDouble()
            : double.tryParse('${data['platformFeePercentage']}');
        _platformFeePct = pct;

        // per-mode commission + caps/min
        _pickupPct = (data['pickupPct'] as num?)?.toDouble();
        _merchantDeliveryPct = (data['merchantDeliveryPct'] as num?)?.toDouble();
        _platformDeliveryPct = (data['platformDeliveryPct'] as num?)?.toDouble();
        _commissionMin = (data['commissionMin'] as num?)?.toDouble();
        _capPickup = (data['commissionCapPickup'] as num?)?.toDouble();
        _capMerchant = (data['commissionCapDeliveryMerchant'] as num?)?.toDouble();
        _capPlatform = (data['commissionCapDeliveryPlatform'] as num?)?.toDouble();

        // buyer fees
        _buyerServiceFeePct = (data['buyerServiceFeePct'] as num?)?.toDouble();
        _buyerServiceFeeFixed = (data['buyerServiceFeeFixed'] as num?)?.toDouble();
        _smallOrderFee = (data['smallOrderFee'] as num?)?.toDouble();
        _smallOrderThreshold = (data['smallOrderThreshold'] as num?)?.toDouble();
        
        // PayFast fees
        _payfastFeePercentage = (data['payfastFeePercentage'] as num?)?.toDouble();
        _payfastFixedFee = (data['payfastFixedFee'] as num?)?.toDouble();
      });
    } catch (_) {}
  }

  void _proceedToRegistration() async {
    // Save that user has seen onboarding
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_seller_onboarding', true);
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SellerRegistrationScreen()),
      );
    }
  }

  Widget _buildStepContent(OnboardingStep step) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
      child: Column(
        children: [
          // Icon and Title
          Container(
            padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
            decoration: BoxDecoration(
              color: step.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              step.icon,
              size: ResponsiveUtils.getIconSize(context, baseSize: 48),
              color: step.color,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
          
          // Title
          Container(
            width: double.infinity,
            child: SafeUI.safeText(
              step.title,
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context),
                fontWeight: FontWeight.bold,
                color: AppTheme.deepTeal,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.visible,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
          
          // Subtitle
          Container(
            width: double.infinity,
            child: SafeUI.safeText(
              step.subtitle,
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                color: AppTheme.mediumGrey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.visible,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
          
          // Content List
          ...step.content.map((item) => Container(
            margin: EdgeInsets.only(bottom: ResponsiveUtils.getVerticalPadding(context) * 0.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(top: 6),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: step.color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                Expanded(
                  child: SafeUI.safeText(
                    item,
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                      color: AppTheme.darkGrey,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          )).toList(),

          if (step.title == 'How Payments Work') ...[
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.percent, color: AppTheme.primaryGreen, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _platformFeePct != null
                          ? 'Current platform commission: ${_platformFeePct!.toStringAsFixed(1)}% (may change)'
                          : 'Platform commission: set by platform (may change)',
                      style: TextStyle(
                        color: AppTheme.deepTeal,
                        fontSize: ResponsiveUtils.getTitleSize(context) - 6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (step.title == 'Fees & Payouts') ...[
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.deepTeal.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.deepTeal.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SafeUI.safeText('Commission (per order)', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.deepTeal)),
                  const SizedBox(height: 8),
                  _buildBullet('Pickup: ${_pickupPct?.toStringAsFixed(1) ?? (_platformFeePct?.toStringAsFixed(1) ?? '—')}% (min R${(_commissionMin ?? 0).toStringAsFixed(2)}, cap R${(_capPickup ?? 0).toStringAsFixed(2)})'),
                  _buildBullet('You deliver: ${_merchantDeliveryPct?.toStringAsFixed(1) ?? (_platformFeePct?.toStringAsFixed(1) ?? '—')}% (cap R${(_capMerchant ?? 0).toStringAsFixed(2)})'),
                  _buildBullet('We arrange courier: ${_platformDeliveryPct?.toStringAsFixed(1) ?? (_platformFeePct?.toStringAsFixed(1) ?? '—')}% (cap R${(_capPlatform ?? 0).toStringAsFixed(2)})'),
                  const SizedBox(height: 12),
                  SafeUI.safeText('Buyer fees', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.deepTeal)),
                  const SizedBox(height: 8),
                  _buildBullet('Service fee: ${_buyerServiceFeePct?.toStringAsFixed(1) ?? '—'}% + R${(_buyerServiceFeeFixed ?? 0).toStringAsFixed(2)} (min R3, max R15)'),
                  _buildBullet('Small-order fee: R${(_smallOrderFee ?? 0).toStringAsFixed(2)} under R${(_smallOrderThreshold ?? 0).toStringAsFixed(2)}'),
                  _buildBullet('Delivery fee: pass-through to buyer'),
                  const SizedBox(height: 12),
                  SafeUI.safeText('Payouts', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.deepTeal)),
                  const SizedBox(height: 8),
                  _buildBullet('Weekly payouts (minimum R100)'),
                  _buildBullet('Instant payouts available (optional fee)'),
                  _buildBullet('COD commission settled via payout/top-up'),
                  const SizedBox(height: 12),
                  SafeUI.safeText('Example (R200, you deliver)', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.deepTeal)),
                  const SizedBox(height: 8),
                  _buildBullet('Commission ${_merchantDeliveryPct?.toStringAsFixed(1) ?? '—'}% ≈ R18; Buyer service fee ≈ R5'),
                  _buildBullet('You receive ≈ R182'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _hasReadPaymentTerms,
                        onChanged: (v) => setState(() => _hasReadPaymentTerms = v ?? false),
                      ),
                      Expanded(
                        child: SafeUI.safeText(
                          'I have read and accept the Fees & Payouts policy.',
                          style: TextStyle(color: AppTheme.darkGrey),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 6, right: 8), decoration: BoxDecoration(color: AppTheme.deepTeal, shape: BoxShape.circle)),
          Expanded(child: Text(text, style: TextStyle(color: AppTheme.darkGrey))),
        ],
      ),
    );
  }

  Widget _buildTermsSection() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getHorizontalPadding(context),
        vertical: ResponsiveUtils.getVerticalPadding(context) * 0.5,
      ),
      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryGreen.withOpacity(0.1), AppTheme.angel],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGreen.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.primaryGreen,
                size: ResponsiveUtils.getIconSize(context, baseSize: 20),
              ),
              SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
              Expanded(
                child: SafeUI.safeText(
                  'Important Information',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
          SafeUI.safeText(
            'By proceeding, you agree to our Terms of Service, Payment Terms, and Return Policy. Please read all information carefully before registering.',
            style: TextStyle(
              fontSize: ResponsiveUtils.getTitleSize(context) - 6,
              color: AppTheme.darkGrey,
              height: 1.5,
            ),
            maxLines: 4,
            overflow: TextOverflow.visible,
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
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.arrow_back,
                        color: AppTheme.deepTeal,
                        size: ResponsiveUtils.getIconSize(context, baseSize: 24),
                      ),
                    ),
                    Expanded(
                      child: SafeUI.safeText(
                        'Seller Onboarding',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getTitleSize(context),
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepTeal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.getIconSize(context, baseSize: 24)),
                  ],
                ),
              ),
              
              // Progress Indicator
              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.getHorizontalPadding(context),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: AppTheme.primaryGreen,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppTheme.angel,
                  unselectedLabelColor: AppTheme.mediumGrey,
                  tabs: List.generate(_steps.length, (index) => Tab(
                    child: Text('${index + 1}'),
                  )),
                ),
              ),
              
              SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
              
              // Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                    _tabController.animateTo(index);
                  },
                  itemCount: _steps.length,
                  itemBuilder: (context, index) {
                    return _buildStepContent(_steps[index]);
                  },
                ),
              ),
              
              // Terms Section
              _buildTermsSection(),
              
              // Navigation Buttons
              Container(
                padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousPage,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.deepTeal,
                            side: BorderSide(color: AppTheme.deepTeal),
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveUtils.getVerticalPadding(context) * 0.8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_back, size: 20),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Previous',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    if (_currentPage > 0)
                      SizedBox(width: ResponsiveUtils.getHorizontalPadding(context)),
                    
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_steps[_currentPage].title == 'Fees & Payouts' && !_hasReadPaymentTerms)
                            ? null
                            : (_currentPage < _steps.length - 1 ? _nextPage : _proceedToRegistration),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: AppTheme.angel,
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveUtils.getVerticalPadding(context) * 0.8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                _currentPage < _steps.length - 1 ? 'Next' : 'Start Registration',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.visible,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (_currentPage < _steps.length - 1) ...[
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingStep {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> content;

  OnboardingStep({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.content,
  });
} 