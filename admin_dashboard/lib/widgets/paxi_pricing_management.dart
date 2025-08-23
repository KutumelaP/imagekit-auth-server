import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/admin_theme.dart';

class PaxiPricingManagement extends StatefulWidget {
  const PaxiPricingManagement({Key? key}) : super(key: key);

  @override
  State<PaxiPricingManagement> createState() => _PaxiPricingManagementState();
}

class _PaxiPricingManagementState extends State<PaxiPricingManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  Map<String, dynamic> _paxiPricing = {};
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for form fields - delivery speeds only
  final TextEditingController _standardController = TextEditingController();
  final TextEditingController _expressController = TextEditingController();
  final TextEditingController _standardDaysController = TextEditingController();
  final TextEditingController _expressDaysController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPaxiPricing();
  }

  @override
  void dispose() {
    _standardController.dispose();
    _expressController.dispose();
    _standardDaysController.dispose();
    _expressDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadPaxiPricing() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DocumentSnapshot pricingDoc = await _firestore
          .collection('admin_settings')
          .doc('paxi_pricing')
          .get();

      if (pricingDoc.exists) {
        _paxiPricing = pricingDoc.data() as Map<String, dynamic>;
        
        // Populate form controllers
        _standardController.text = (_paxiPricing['standard'] ?? 59.95).toString();
        _expressController.text = (_paxiPricing['express'] ?? 109.95).toString();
        _standardDaysController.text = (_paxiPricing['standardDays'] ?? '7-9').toString();
        _expressDaysController.text = (_paxiPricing['expressDays'] ?? '3-5').toString();
      } else {
        // Set default values
        _standardController.text = '59.95';
        _expressController.text = '109.95';
        _standardDaysController.text = '7-9';
        _expressDaysController.text = '3-5';
      }
    } catch (e) {
      print('Error loading PAXI pricing: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePaxiPricing() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> pricing = {
        'standard': double.parse(_standardController.text),
        'express': double.parse(_expressController.text),
        'standardDays': _standardDaysController.text,
        'expressDays': _expressDaysController.text,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'admin',
      };

      await _firestore
          .collection('admin_settings')
          .doc('paxi_pricing')
          .set(pricing);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PAXI pricing updated successfully!'),
          backgroundColor: AdminTheme.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating PAXI pricing: $e'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('PAXI Delivery Speed Pricing'),
        backgroundColor: AdminTheme.deepTeal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AdminTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AdminTheme.primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.local_shipping,
                                color: AdminTheme.primaryColor,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'PAXI Delivery Speed Pricing',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AdminTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Configure pricing for different PAXI delivery speeds. Same bag size, different delivery times.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AdminTheme.textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Standard Delivery Speed
                    _buildPricingCard(
                      title: 'Standard Delivery Speed',
                      subtitle: '7-9 Business Days',
                      icon: Icons.schedule,
                      color: AdminTheme.primaryColor,
                      priceController: _standardController,
                      daysController: _standardDaysController,
                      defaultPrice: '59.95',
                      defaultDays: '7-9',
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Express Delivery Speed
                    _buildPricingCard(
                      title: 'Express Delivery Speed',
                      subtitle: '3-5 Business Days',
                      icon: Icons.flash_on,
                      color: AdminTheme.accentColor,
                      priceController: _expressController,
                      daysController: _expressDaysController,
                      defaultPrice: '109.95',
                      defaultDays: '3-5',
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _savePaxiPricing,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.primaryColor,
                          foregroundColor: AdminTheme.onPrimaryColor,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AdminTheme.onPrimaryColor,
                                  ),
                                ),
                              )
                            : Text(
                                'Save PAXI Pricing',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Info Card
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AdminTheme.infoColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AdminTheme.infoColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AdminTheme.infoColor,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'PAXI uses the same bag size (10kg) for all delivery speeds. '
                              'The price difference reflects the delivery time priority.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AdminTheme.textColor,
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

  Widget _buildPricingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required TextEditingController priceController,
    required TextEditingController daysController,
    required String defaultPrice,
    required String defaultDays,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: AdminTheme.textColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price (R)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AdminTheme.textColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    TextFormField(
                      controller: priceController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: defaultPrice,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Price is required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid price';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              
              SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Days',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AdminTheme.textColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    TextFormField(
                      controller: daysController,
                      decoration: InputDecoration(
                        hintText: defaultDays,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Delivery days required';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
