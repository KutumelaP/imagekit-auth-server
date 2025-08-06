import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class ReturnPolicyScreen extends StatefulWidget {
  const ReturnPolicyScreen({Key? key}) : super(key: key);

  @override
  State<ReturnPolicyScreen> createState() => _ReturnPolicyScreenState();
}

class _ReturnPolicyScreenState extends State<ReturnPolicyScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic> _returnSettings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReturnSettings();
  }

  Future<void> _loadReturnSettings() async {
    try {
      DocumentSnapshot settingsDoc = await _firestore
          .collection('admin_settings')
          .doc('payment_settings')
          .get();

      if (settingsDoc.exists) {
        _returnSettings = settingsDoc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error loading return settings: $e');
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
        title: Text('Return Policy', style: AppTheme.headlineSmall),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.angel,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildReturnWindowSection(),
                  const SizedBox(height: 24),
                  _buildReturnProcessSection(),
                  const SizedBox(height: 24),
                  _buildReturnReasonsSection(),
                  const SizedBox(height: 24),
                  _buildRefundSection(),
                  const SizedBox(height: 24),
                  _buildContactSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.secondaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_return, color: AppTheme.angel, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Return Policy',
                  style: AppTheme.headlineLarge.copyWith(
                    color: AppTheme.angel,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'We want you to be completely satisfied with your purchase. If you\'re not happy, we\'re here to help.',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.angel.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnWindowSection() {
    int returnWindow = _returnSettings['returnWindowDays'] ?? 7;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cloud.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text(
                'Return Window',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildReturnWindowCard('Electronics', '$returnWindow days', Icons.computer, AppTheme.primaryGreen),
          const SizedBox(height: 8),
          _buildReturnWindowCard('Clothes', '$returnWindow days', Icons.checkroom, AppTheme.secondaryGreen),
          const SizedBox(height: 8),
          _buildReturnWindowCard('Other Items', '$returnWindow days', Icons.inventory, AppTheme.accentGreen),
          const SizedBox(height: 8),
          _buildReturnWindowCard('Food Items', 'No returns', Icons.restaurant, AppTheme.error, isNoReturn: true),
        ],
      ),
    );
  }

  Widget _buildReturnWindowCard(String category, String window, IconData icon, Color color, {bool isNoReturn = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  window,
                  style: AppTheme.bodySmall.copyWith(
                    color: isNoReturn ? AppTheme.error : AppTheme.cloud,
                    fontWeight: isNoReturn ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (isNoReturn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Safety',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReturnProcessSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cloud.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_list_numbered, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text(
                'How to Return',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProcessStep(1, 'Request Return', 'Contact us within the return window', Icons.message),
          _buildProcessStep(2, 'Get Approval', 'We\'ll review your request within 24 hours', Icons.check_circle),
          _buildProcessStep(3, 'Return Item', 'Send item back in original condition', Icons.local_shipping),
          _buildProcessStep(4, 'Get Refund', 'Receive refund within 3-5 business days', Icons.payment),
        ],
      ),
    );
  }

  Widget _buildProcessStep(int step, String title, String description, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                '$step',
                style: AppTheme.titleSmall.copyWith(
                  color: AppTheme.angel,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.cloud,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: AppTheme.primaryGreen, size: 20),
        ],
      ),
    );
  }

  Widget _buildReturnReasonsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cloud.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text(
                'Valid Return Reasons',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildReasonCard('Defective Product', 'Item arrived damaged or not working', Icons.error),
          _buildReasonCard('Wrong Item', 'Received different item than ordered', Icons.swap_horiz),
          _buildReasonCard('Size/Fit Issues', 'Clothing doesn\'t fit as expected', Icons.accessibility),
          _buildReasonCard('Quality Issues', 'Item quality not as described', Icons.star),
        ],
      ),
    );
  }

  Widget _buildReasonCard(String reason, String description, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason,
                  style: AppTheme.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.cloud,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cloud.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text(
                'Refund Information',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRefundInfo('Full Refund', 'Original payment method', Icons.refresh),
          _buildRefundInfo('Processing Time', '3-5 business days', Icons.schedule),
          _buildRefundInfo('Delivery Fee', 'Non-refundable', Icons.local_shipping),
          _buildRefundInfo('Return Shipping', 'Customer responsibility', Icons.send),
        ],
      ),
    );
  }

  Widget _buildRefundInfo(String title, String description, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.info.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.cloud,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cloud.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.contact_support, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text(
                'Need Help?',
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildContactOption('Email Support', 'support@yourapp.com', Icons.email),
          _buildContactOption('WhatsApp', '+27 12 345 6789', Icons.phone),
          _buildContactOption('Live Chat', 'Available 24/7', Icons.chat),
        ],
      ),
    );
  }

  Widget _buildContactOption(String title, String contact, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  contact,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.cloud,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 