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
  // New: commission per mode and buyer fees
  final TextEditingController _pickupPctController = TextEditingController();
  final TextEditingController _merchantDeliveryPctController = TextEditingController();
  final TextEditingController _platformDeliveryPctController = TextEditingController();
  final TextEditingController _commissionMinController = TextEditingController();
  final TextEditingController _capPickupController = TextEditingController();
  final TextEditingController _capMerchantController = TextEditingController();
  final TextEditingController _capPlatformController = TextEditingController();
  final TextEditingController _buyerServiceFeePctController = TextEditingController();
  final TextEditingController _buyerServiceFeeFixedController = TextEditingController();
  final TextEditingController _smallOrderFeeController = TextEditingController();
  final TextEditingController _smallOrderThresholdController = TextEditingController();
  
  // Tiered pricing controllers
  final TextEditingController _tier1MaxController = TextEditingController();
  final TextEditingController _tier1CommissionController = TextEditingController();
  final TextEditingController _tier1SmallOrderFeeController = TextEditingController();
  final TextEditingController _tier2MaxController = TextEditingController();
  final TextEditingController _tier2CommissionController = TextEditingController();
  final TextEditingController _tier2SmallOrderFeeController = TextEditingController();
  final TextEditingController _tier3CommissionController = TextEditingController();

  // Platform Shipping Providers (PUDO)
  bool _spLoading = false;
  bool _pudoEnabled = false;
  // Standard pricing
  final TextEditingController _pudoStdS = TextEditingController();
  final TextEditingController _pudoStdM = TextEditingController();
  final TextEditingController _pudoStdL = TextEditingController();
  final TextEditingController _pudoStdXL = TextEditingController();
  // Express pricing
  final TextEditingController _pudoExpS = TextEditingController();
  final TextEditingController _pudoExpM = TextEditingController();
  final TextEditingController _pudoExpL = TextEditingController();
  final TextEditingController _pudoExpXL = TextEditingController();
  final TextEditingController _pudoNotes = TextEditingController();
  // Door pricing (Locker↔Door)
  final TextEditingController _pudoDoorXS = TextEditingController();
  final TextEditingController _pudoDoorS = TextEditingController();
  final TextEditingController _pudoDoorM = TextEditingController();
  final TextEditingController _pudoDoorL = TextEditingController();
  final TextEditingController _pudoDoorXL = TextEditingController();
  final TextEditingController _pudoDoorSurcharge = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPaymentSettings();
    _loadShippingProviders();
  }

  @override
  void dispose() {
    _platformFeeController.dispose();
    _holdbackPercentageController.dispose();
    _payfastFeePercentageController.dispose();
    _payfastFixedFeeController.dispose();
    _returnWindowController.dispose();
    _holdbackPeriodController.dispose();
    _pickupPctController.dispose();
    _merchantDeliveryPctController.dispose();
    _platformDeliveryPctController.dispose();
    _commissionMinController.dispose();
    _capPickupController.dispose();
    _capMerchantController.dispose();
    _capPlatformController.dispose();
    _buyerServiceFeePctController.dispose();
    _buyerServiceFeeFixedController.dispose();
    _smallOrderFeeController.dispose();
    _smallOrderThresholdController.dispose();
    
    // Dispose tiered pricing controllers
    _tier1MaxController.dispose();
    _tier1CommissionController.dispose();
    _tier1SmallOrderFeeController.dispose();
    _tier2MaxController.dispose();
    _tier2CommissionController.dispose();
    _tier2SmallOrderFeeController.dispose();
    _tier3CommissionController.dispose();
    // Shipping providers controllers
    _pudoStdS.dispose();
    _pudoStdM.dispose();
    _pudoStdL.dispose();
    _pudoStdXL.dispose();
    _pudoExpS.dispose();
    _pudoExpM.dispose();
    _pudoExpL.dispose();
    _pudoExpXL.dispose();
    _pudoNotes.dispose();
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

        // New fields
        _pickupPctController.text = (_paymentSettings['pickupPct'] ?? _paymentSettings['platformFeePercentage'] ?? 5.0).toString();
        _merchantDeliveryPctController.text = (_paymentSettings['merchantDeliveryPct'] ?? _paymentSettings['platformFeePercentage'] ?? 5.0).toString();
        _platformDeliveryPctController.text = (_paymentSettings['platformDeliveryPct'] ?? _paymentSettings['platformFeePercentage'] ?? 5.0).toString();
        _commissionMinController.text = (_paymentSettings['commissionMin'] ?? 0.0).toString();
        _capPickupController.text = (_paymentSettings['commissionCapPickup'] ?? 0.0).toString();
        _capMerchantController.text = (_paymentSettings['commissionCapDeliveryMerchant'] ?? 0.0).toString();
        _capPlatformController.text = (_paymentSettings['commissionCapDeliveryPlatform'] ?? 0.0).toString();
        _buyerServiceFeePctController.text = (_paymentSettings['buyerServiceFeePct'] ?? 0.0).toString();
        _buyerServiceFeeFixedController.text = (_paymentSettings['buyerServiceFeeFixed'] ?? 0.0).toString();
        _smallOrderFeeController.text = (_paymentSettings['smallOrderFee'] ?? 0.0).toString();
        _smallOrderThresholdController.text = (_paymentSettings['smallOrderThreshold'] ?? 0.0).toString();
        
        // Tiered pricing fields
        _tier1MaxController.text = (_paymentSettings['tier1Max'] ?? 15.0).toString();
        _tier1CommissionController.text = (_paymentSettings['tier1Commission'] ?? 15.0).toString();
        _tier1SmallOrderFeeController.text = (_paymentSettings['tier1SmallOrderFee'] ?? 0.0).toString();
        _tier2MaxController.text = (_paymentSettings['tier2Max'] ?? 50.0).toString();
        _tier2CommissionController.text = (_paymentSettings['tier2Commission'] ?? 10.0).toString();
        _tier2SmallOrderFeeController.text = (_paymentSettings['tier2SmallOrderFee'] ?? 2.0).toString();
        _tier3CommissionController.text = (_paymentSettings['tier3Commission'] ?? 6.0).toString();
      } else {
        // Set default values
        _platformFeeController.text = '5.0';
        _holdbackPercentageController.text = '10.0';
        _payfastFeePercentageController.text = '3.5';
        _payfastFixedFeeController.text = '2.0';
        _returnWindowController.text = '7';
        _holdbackPeriodController.text = '30';

        // New defaults
        _pickupPctController.text = '6.0';
        _merchantDeliveryPctController.text = '9.0';
        _platformDeliveryPctController.text = '11.0';
        _commissionMinController.text = '5.0';
        _capPickupController.text = '30.0';
        _capMerchantController.text = '40.0';
        _capPlatformController.text = '50.0';
        _buyerServiceFeePctController.text = '1.0';
        _buyerServiceFeeFixedController.text = '3.0';
        _smallOrderFeeController.text = '7.0';
        _smallOrderThresholdController.text = '100.0';
        
        // Tiered pricing defaults
        _tier1MaxController.text = '15.0';
        _tier1CommissionController.text = '15.0';
        _tier1SmallOrderFeeController.text = '0.0';
        _tier2MaxController.text = '50.0';
        _tier2CommissionController.text = '10.0';
        _tier2SmallOrderFeeController.text = '2.0';
        _tier3CommissionController.text = '6.0';
      }
    } catch (e) {
      print('Error loading payment settings: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadShippingProviders() async {
    setState(() { _spLoading = true; });
    try {
      final doc = await _firestore.collection('admin_settings').doc('shipping_providers').get();
      final data = doc.data() ?? {};
      final pudo = (data['pudo'] as Map?) ?? {};
      _pudoEnabled = (pudo['enabled'] ?? false) == true;
      final pricing = (pudo['pricing'] as Map?) ?? {};
      final std = (pricing['standard'] as Map?) ?? {};
      final exp = (pricing['express'] as Map?) ?? {};
      _pudoStdS.text = '${std['s'] ?? ''}';
      _pudoStdM.text = '${std['m'] ?? ''}';
      _pudoStdL.text = '${std['l'] ?? ''}';
      _pudoStdXL.text = '${std['xl'] ?? ''}';
      _pudoExpS.text = '${exp['s'] ?? ''}';
      _pudoExpM.text = '${exp['m'] ?? ''}';
      _pudoExpL.text = '${exp['l'] ?? ''}';
      _pudoExpXL.text = '${exp['xl'] ?? ''}';
      final door = (pudo['pricingDoor'] as Map?) ?? {};
      _pudoDoorXS.text = '${door['xs'] ?? ''}';
      _pudoDoorS.text = '${door['s'] ?? ''}';
      _pudoDoorM.text = '${door['m'] ?? ''}';
      _pudoDoorL.text = '${door['l'] ?? ''}';
      _pudoDoorXL.text = '${door['xl'] ?? ''}';
      _pudoDoorSurcharge.text = '${pudo['doorSurcharge'] ?? ''}';
      _pudoNotes.text = '${pudo['notes'] ?? ''}';
      setState(() {});
    } catch (e) {
      // ignore errors for now
    } finally {
      setState(() { _spLoading = false; });
    }
  }

  double? _parseNullableDouble(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _saveShippingProviders() async {
    setState(() { _spLoading = true; });
    try {
      final standard = {
        's': _parseNullableDouble(_pudoStdS.text),
        'm': _parseNullableDouble(_pudoStdM.text),
        'l': _parseNullableDouble(_pudoStdL.text),
        'xl': _parseNullableDouble(_pudoStdXL.text),
      }..removeWhere((k, v) => v == null);
      final express = {
        's': _parseNullableDouble(_pudoExpS.text),
        'm': _parseNullableDouble(_pudoExpM.text),
        'l': _parseNullableDouble(_pudoExpL.text),
        'xl': _parseNullableDouble(_pudoExpXL.text),
      }..removeWhere((k, v) => v == null);

      final payload = {
        'pudo': {
          'enabled': _pudoEnabled,
          'pricing': {
            if (standard.isNotEmpty) 'standard': standard,
            if (express.isNotEmpty) 'express': express,
          },
          'pricingDoor': {
            if (_parseNullableDouble(_pudoDoorXS.text) != null) 'xs': _parseNullableDouble(_pudoDoorXS.text),
            if (_parseNullableDouble(_pudoDoorS.text) != null) 's': _parseNullableDouble(_pudoDoorS.text),
            if (_parseNullableDouble(_pudoDoorM.text) != null) 'm': _parseNullableDouble(_pudoDoorM.text),
            if (_parseNullableDouble(_pudoDoorL.text) != null) 'l': _parseNullableDouble(_pudoDoorL.text),
            if (_parseNullableDouble(_pudoDoorXL.text) != null) 'xl': _parseNullableDouble(_pudoDoorXL.text),
          }..removeWhere((k, v) => v == null),
          'doorSurcharge': _parseNullableDouble(_pudoDoorSurcharge.text),
          'notes': _pudoNotes.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        }
      };

      await _firestore.collection('admin_settings').doc('shipping_providers').set(payload, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Shipping providers saved'), backgroundColor: AdminTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving shipping providers: $e'), backgroundColor: AdminTheme.error),
        );
      }
    } finally {
      setState(() { _spLoading = false; });
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
        // New fields persisted
        'pickupPct': double.parse(_pickupPctController.text),
        'merchantDeliveryPct': double.parse(_merchantDeliveryPctController.text),
        'platformDeliveryPct': double.parse(_platformDeliveryPctController.text),
        'commissionMin': double.parse(_commissionMinController.text),
        'commissionCapPickup': double.parse(_capPickupController.text),
        'commissionCapDeliveryMerchant': double.parse(_capMerchantController.text),
        'commissionCapDeliveryPlatform': double.parse(_capPlatformController.text),
        'buyerServiceFeePct': double.parse(_buyerServiceFeePctController.text),
        'buyerServiceFeeFixed': double.parse(_buyerServiceFeeFixedController.text),
        'smallOrderFee': double.parse(_smallOrderFeeController.text),
        'smallOrderThreshold': double.parse(_smallOrderThresholdController.text),
        
        // Tiered pricing fields
        'tier1Max': double.parse(_tier1MaxController.text),
        'tier1Commission': double.parse(_tier1CommissionController.text),
        'tier1SmallOrderFee': double.parse(_tier1SmallOrderFeeController.text),
        'tier2Max': double.parse(_tier2MaxController.text),
        'tier2Commission': double.parse(_tier2CommissionController.text),
        'tier2SmallOrderFee': double.parse(_tier2SmallOrderFeeController.text),
        'tier3Commission': double.parse(_tier3CommissionController.text),
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
                _buildCommissionSettingsSection(),
                const SizedBox(height: 24),
                _buildBuyerFeesSection(),
                const SizedBox(height: 24),
                _buildTieredPricingSection(),
                const SizedBox(height: 24),
                _buildHoldbackSettingsSection(),
                const SizedBox(height: 24),
                _buildReturnSettingsSection(),
                const SizedBox(height: 24),
                _buildShippingProvidersSection(),
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
                  'Payment Processing Fees',
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
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Platform fees now use tiered pricing system below',
                            style: AdminTheme.bodyMedium.copyWith(
                              color: Colors.blue.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
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

  Widget _buildShippingProvidersSection() {
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
          Row(children: [
            Icon(Icons.local_shipping, color: AdminTheme.deepTeal),
            const SizedBox(width: 8),
            Text('Platform Shipping Providers', style: AdminTheme.headlineMedium.copyWith(color: AdminTheme.deepTeal, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (_spLoading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Enable PUDO (prepaid wallet)'),
            subtitle: const Text('Sellers book via PUDO app; shipping reimbursement applies if buyer is charged.'),
            value: _pudoEnabled,
            onChanged: (v) => setState(() => _pudoEnabled = v),
            contentPadding: EdgeInsets.zero,
            activeColor: AdminTheme.success,
          ),
          if (_pudoEnabled) ...[
            const SizedBox(height: 12),
            Text('PUDO Pricing (optional)', style: AdminTheme.titleMedium.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _priceRow('Standard', _pudoStdS, _pudoStdM, _pudoStdL, _pudoStdXL),
            const SizedBox(height: 8),
            _priceRow('Express', _pudoExpS, _pudoExpM, _pudoExpL, _pudoExpXL),
            const SizedBox(height: 12),
            Text('PUDO Door-to-Door (Locker↔Door) Pricing', style: AdminTheme.titleMedium.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _priceRowDoor(_pudoDoorXS, _pudoDoorS, _pudoDoorM, _pudoDoorL, _pudoDoorXL),
            const SizedBox(height: 8),
            TextField(
              controller: _pudoDoorSurcharge,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Door Surcharge (R, optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pudoNotes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (admins only)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _spLoading ? null : _saveShippingProviders,
                icon: const Icon(Icons.save),
                label: const Text('Save Shipping Providers'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceRow(String label, TextEditingController s, TextEditingController m, TextEditingController l, TextEditingController xl) {
    InputDecoration dec(String hint) => InputDecoration(labelText: hint, border: const OutlineInputBorder());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: TextField(controller: s, decoration: dec('S (R)'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: m, decoration: dec('M (R)'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: l, decoration: dec('L (R)'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: xl, decoration: dec('XL (R)'))),
        ]),
      ],
    );
  }

  Widget _priceRowDoor(TextEditingController xs, TextEditingController s, TextEditingController m, TextEditingController l, TextEditingController xl) {
    InputDecoration dec(String hint) => InputDecoration(labelText: hint, border: const OutlineInputBorder());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: TextField(controller: xs, decoration: dec('XS (R)'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: s, decoration: dec('S (R)'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: m, decoration: dec('M (R)'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: l, decoration: dec('L (R)'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: xl, decoration: dec('XL (R)'))),
        ]),
      ],
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

  Widget _buildCommissionSettingsSection() {
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
              Icon(Icons.percent, color: AdminTheme.deepTeal),
              const SizedBox(width: 8),
              Text(
                'Commission Settings',
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
                  controller: _pickupPctController,
                  label: 'Pickup Commission (%)',
                  hint: '6.0',
                  icon: Icons.store,
                  validator: _validatePct,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _merchantDeliveryPctController,
                  label: 'You Deliver Commission (%)',
                  hint: '9.0',
                  icon: Icons.delivery_dining,
                  validator: _validatePct,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _platformDeliveryPctController,
                  label: 'We Arrange Courier (%)',
                  hint: '11.0',
                  icon: Icons.local_shipping,
                  validator: _validatePct,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _commissionMinController,
                  label: 'Commission Minimum (R)',
                  hint: '5.00',
                  icon: Icons.price_change,
                  validator: _validateMoney,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _capPickupController,
                  label: 'Pickup Cap (R)',
                  hint: '30.00',
                  icon: Icons.price_check,
                  validator: _validateMoney,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _capMerchantController,
                  label: 'You Deliver Cap (R)',
                  hint: '40.00',
                  icon: Icons.price_check,
                  validator: _validateMoney,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _capPlatformController,
                  label: 'We Arrange Courier Cap (R)',
                  hint: '50.00',
                  icon: Icons.price_check,
                  validator: _validateMoney,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerFeesSection() {
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
              Icon(Icons.receipt_long, color: AdminTheme.deepTeal),
              const SizedBox(width: 8),
              Text(
                'Buyer Fees',
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
                  controller: _buyerServiceFeePctController,
                  label: 'Service Fee (%)',
                  hint: '1.0',
                  icon: Icons.percent,
                  validator: _validatePct,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _buyerServiceFeeFixedController,
                  label: 'Service Fee Fixed (R)',
                  hint: '3.00',
                  icon: Icons.attach_money,
                  validator: _validateMoney,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _smallOrderFeeController,
                  label: 'Small-Order Fee (R)',
                  hint: '7.00',
                  icon: Icons.price_change,
                  validator: _validateMoney,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _smallOrderThresholdController,
                  label: 'Small-Order Threshold (R)',
                  hint: '100.00',
                  icon: Icons.stacked_bar_chart,
                  validator: _validateMoney,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTieredPricingSection() {
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
              Icon(Icons.layers, color: AdminTheme.deepTeal),
              const SizedBox(width: 8),
              Text(
                'Tiered Pricing (Smart Commission)',
                style: AdminTheme.headlineMedium.copyWith(
                  color: AdminTheme.deepTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Automatically adjust commission and fees based on order size for fair pricing',
            style: AdminTheme.bodyMedium.copyWith(
              color: AdminTheme.cloud,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.security, color: Colors.blue.shade600, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Legacy platform fee is hidden but kept as emergency fallback for system stability',
                    style: AdminTheme.bodySmall.copyWith(
                      color: Colors.blue.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Tier 1: Small Orders (R0 - R25)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_down, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Tier 1: Small Orders (R0 - R25)',
                      style: AdminTheme.titleMedium.copyWith(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _tier1MaxController,
                        label: 'Max Amount (R)',
                        hint: '25.00',
                        icon: Icons.arrow_upward,
                        validator: _validateMoney,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _tier1CommissionController,
                        label: 'Commission (%)',
                        hint: '4.0',
                        icon: Icons.percent,
                        validator: _validatePct,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _tier1SmallOrderFeeController,
                        label: 'Small Order Fee (R)',
                        hint: '3.00',
                        icon: Icons.price_change,
                        validator: _validateMoney,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Tier 2: Medium Orders (R25 - R100)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_flat, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Tier 2: Medium Orders (R25 - R100)',
                      style: AdminTheme.titleMedium.copyWith(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _tier2MaxController,
                        label: 'Max Amount (R)',
                        hint: '100.00',
                        icon: Icons.arrow_upward,
                        validator: _validateMoney,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _tier2CommissionController,
                        label: 'Commission (%)',
                        hint: '6.0',
                        icon: Icons.percent,
                        validator: _validatePct,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _tier2SmallOrderFeeController,
                        label: 'Small Order Fee (R)',
                        hint: '5.00',
                        icon: Icons.price_change,
                        validator: _validateMoney,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Tier 3: Large Orders (R100+)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 16),
                    Text(
                      'Tier 3: Large Orders (R100+)',
                      style: AdminTheme.titleMedium.copyWith(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _tier3CommissionController,
                        label: 'Commission (%)',
                        hint: '6.0',
                        icon: Icons.percent,
                        validator: _validatePct,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'No Small Order Fee',
                              style: AdminTheme.bodyMedium.copyWith(
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Example calculation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminTheme.deepTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminTheme.deepTeal.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calculate, color: AdminTheme.deepTeal),
                    const SizedBox(width: 8),
                    Text(
                      'Example: R10 Order with Tiered Pricing',
                      style: AdminTheme.titleMedium.copyWith(
                        color: AdminTheme.deepTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• R10 order falls in Tier 1 (R0-R25)\n'
                  '• Commission: 4% = R0.40 (min R2.00 applies)\n'
                  '• Small Order Fee: R3.00\n'
                  '• Total Platform Take: R5.40\n'
                  '• Seller Receives: R4.60\n'
                  '• Much fairer than old system!',
                  style: AdminTheme.bodyMedium.copyWith(
                    color: AdminTheme.cloud,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _validatePct(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final n = double.tryParse(value);
    if (n == null || n < 0 || n > 50) return 'Must be 0–50%';
    return null;
  }

  String? _validateMoney(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final n = double.tryParse(value);
    if (n == null || n < 0) return 'Must be ≥ 0';
    return null;
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