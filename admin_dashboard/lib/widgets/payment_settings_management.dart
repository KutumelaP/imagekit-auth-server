import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/admin_theme.dart';

class PaymentSettingsManagement extends StatefulWidget {
  const PaymentSettingsManagement({Key? key}) : super(key: key);

  @override
  State<PaymentSettingsManagement> createState() => _PaymentSettingsManagementState();
}

class _PaymentSettingsManagementState extends State<PaymentSettingsManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  Map<String, dynamic> _paymentSettings = {};
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for form fields
  final TextEditingController _platformFeeController = TextEditingController();
  final TextEditingController _holdbackPercentageController = TextEditingController();
  final TextEditingController _payfastFeePercentageController = TextEditingController();
  final TextEditingController _payfastFixedFeeController = TextEditingController();
  final TextEditingController _returnWindowController = TextEditingController();
  final TextEditingController _holdbackPeriodController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPaymentSettings();
  }

  @override
  void dispose() {
    _platformFeeController.dispose();
    _holdbackPercentageController.dispose();
    _payfastFeePercentageController.dispose();
    _payfastFixedFeeController.dispose();
    _returnWindowController.dispose();
    _holdbackPeriodController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DocumentSnapshot settingsDoc = await _firestore
          .collection('admin_settings')
          .doc('payment_settings')
          .get();

      if (settingsDoc.exists) {
        _paymentSettings = settingsDoc.data() as Map<String, dynamic>;
        
        // Populate form controllers
        _platformFeeController.text = (_paymentSettings['platformFeePercentage'] ?? 5.0).toString();
        _holdbackPercentageController.text = (_paymentSettings['holdbackPercentage'] ?? 10.0).toString();
        _payfastFeePercentageController.text = (_paymentSettings['payfastFeePercentage'] ?? 3.5).toString();
        _payfastFixedFeeController.text = (_paymentSettings['payfastFixedFee'] ?? 2.0).toString();
        _returnWindowController.text = (_paymentSettings['returnWindowDays'] ?? 7).toString();
        _holdbackPeriodController.text = (_paymentSettings['holdbackPeriodDays'] ?? 30).toString();
      } else {
        // Set default values
        _platformFeeController.text = '5.0';
        _holdbackPercentageController.text = '10.0';
        _payfastFeePercentageController.text = '3.5';
        _payfastFixedFeeController.text = '2.0';
        _returnWindowController.text = '7';
        _holdbackPeriodController.text = '30';
      }
    } catch (e) {
      print('Error loading payment settings: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePaymentSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> settings = {
        'platformFeePercentage': double.parse(_platformFeeController.text),
        'holdbackPercentage': double.parse(_holdbackPercentageController.text),
        'payfastFeePercentage': double.parse(_payfastFeePercentageController.text),
        'payfastFixedFee': double.parse(_payfastFixedFeeController.text),
        'returnWindowDays': int.parse(_returnWindowController.text),
        'holdbackPeriodDays': int.parse(_holdbackPeriodController.text),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'admin', // In real app, get from auth
      };

      await _firestore
          .collection('admin_settings')
          .doc('payment_settings')
          .set(settings, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment settings saved successfully!'),
          backgroundColor: AdminTheme.success,
        ),
      );

      await _loadPaymentSettings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving payment settings: $e'),
          backgroundColor: AdminTheme.error,
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
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildFeeStructureSection(),
                const SizedBox(height: 24),
                _buildHoldbackSettingsSection(),
                const SizedBox(height: 24),
                _buildReturnSettingsSection(),
                const SizedBox(height: 24),
                _buildSaveButton(),
              ],
            ),
          );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AdminTheme.deepTeal, AdminTheme.cloud],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminTheme.angel.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.payment,
              color: AdminTheme.angel,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Settings Management',
                  style: AdminTheme.headlineLarge.copyWith(
                    color: AdminTheme.angel,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure platform fees, holdback percentages, and payment policies',
                  style: AdminTheme.bodyMedium.copyWith(
                    color: AdminTheme.angel.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeStructureSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.cloud.withOpacity(0.3)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money, color: AdminTheme.deepTeal),
                const SizedBox(width: 8),
                Text(
                  'Fee Structure',
                  style: AdminTheme.headlineMedium.copyWith(
                    color: AdminTheme.deepTeal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _platformFeeController,
                    label: 'Platform Fee (%)',
                    hint: '5.0',
                    icon: Icons.percent,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter platform fee percentage';
                      }
                      double? fee = double.tryParse(value);
                      if (fee == null || fee < 0 || fee > 50) {
                        return 'Platform fee must be between 0% and 50%';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _payfastFeePercentageController,
                    label: 'PayFast Fee (%)',
                    hint: '3.5',
                    icon: Icons.credit_card,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter PayFast fee percentage';
                      }
                      double? fee = double.tryParse(value);
                      if (fee == null || fee < 0 || fee > 20) {
                        return 'PayFast fee must be between 0% and 20%';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _payfastFixedFeeController,
              label: 'PayFast Fixed Fee (R)',
              hint: '2.00',
              icon: Icons.money,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter PayFast fixed fee';
                }
                double? fee = double.tryParse(value);
                if (fee == null || fee < 0) {
                  return 'Fixed fee must be a positive number';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoldbackSettingsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.cloud.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: AdminTheme.deepTeal),
              const SizedBox(width: 8),
              Text(
                'Holdback Settings',
                style: AdminTheme.headlineMedium.copyWith(
                  color: AdminTheme.deepTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _holdbackPercentageController,
                  label: 'Holdback Percentage (%)',
                  hint: '10.0',
                  icon: Icons.lock,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter holdback percentage';
                    }
                    double? percentage = double.tryParse(value);
                    if (percentage == null || percentage < 0 || percentage > 50) {
                      return 'Holdback must be between 0% and 50%';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _holdbackPeriodController,
                  label: 'Holdback Period (Days)',
                  hint: '30',
                  icon: Icons.schedule,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter holdback period';
                    }
                    int? days = int.tryParse(value);
                    if (days == null || days < 1 || days > 365) {
                      return 'Holdback period must be between 1 and 365 days';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AdminTheme.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AdminTheme.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Holdback protects against returns and disputes. Funds are automatically released after the holdback period.',
                    style: AdminTheme.bodySmall.copyWith(
                      color: AdminTheme.deepTeal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnSettingsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.cloud.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_return, color: AdminTheme.deepTeal),
              const SizedBox(width: 8),
              Text(
                'Return Settings',
                style: AdminTheme.headlineMedium.copyWith(
                  color: AdminTheme.deepTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _returnWindowController,
            label: 'Return Window (Days)',
            hint: '7',
            icon: Icons.calendar_today,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter return window';
              }
              int? days = int.tryParse(value);
              if (days == null || days < 1 || days > 90) {
                return 'Return window must be between 1 and 90 days';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminTheme.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AdminTheme.info.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AdminTheme.info, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Return window applies to all products except food items. Food items have a 0-day return window for safety.',
                    style: AdminTheme.bodySmall.copyWith(
                      color: AdminTheme.deepTeal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AdminTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AdminTheme.deepTeal,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AdminTheme.cloud),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AdminTheme.cloud),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AdminTheme.cloud),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AdminTheme.deepTeal, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AdminTheme.error),
            ),
            filled: true,
            fillColor: AdminTheme.angel,
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _savePaymentSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminTheme.deepTeal,
          foregroundColor: AdminTheme.angel,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AdminTheme.angel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Saving...',
                    style: AdminTheme.titleMedium.copyWith(
                      color: AdminTheme.angel,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save, color: AdminTheme.angel),
                  const SizedBox(width: 8),
                  Text(
                    'Save Payment Settings',
                    style: AdminTheme.titleMedium.copyWith(
                      color: AdminTheme.angel,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
} 