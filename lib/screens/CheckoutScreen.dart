import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../config/paxi_config.dart';
import '../config/here_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/rural_delivery_widget.dart';
import '../services/rural_delivery_service.dart';
import '../widgets/urban_delivery_widget.dart';
import '../services/urban_delivery_service.dart';
import '../services/delivery_fulfillment_service.dart';
import '../widgets/home_navigation_button.dart';
import '../services/courier_quote_service.dart';
import '../widgets/paxi_delivery_speed_selector.dart';
import '../config/paxi_config.dart';

import '../providers/cart_provider.dart';
import 'login_screen.dart';
import 'OrderTrackingScreen.dart';

class CheckoutScreen extends StatefulWidget {
  final double totalPrice;

  const CheckoutScreen({super.key, required this.totalPrice});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _deliveryInstructionsController = TextEditingController();
  final _specialRequestsController = TextEditingController();
  final _addressFocusNode = FocusNode();

  bool _isLoading = false;
  bool _orderCompleted = false; // Prevent duplicate orders
  String? _validatedAddress;
  bool _paymentMethodsLoaded = false;
  double? _deliveryFee;
  double _deliveryDistance = 0.0;
  bool? _storeOpen;
  String? _storeName;
  double? _minOrderForDelivery;
  String? _deliveryTimeEstimate;
  int? _deliveryStartHour;
  int? _deliveryEndHour;
  String? _storeOpenHour;
  String? _storeCloseHour;
  List<String> _paymentMethods = [];
  List<String> _excludedZones = [];
  double? _platformFeePercent;
  double _platformFee = 0.0;
  bool _isStoreFeeExempt = false;
  int? _deliveryTimeMinutes;
  String? _selectedPaymentMethod;
  bool _isDelivery = true; // Default to delivery, user can change to pickup
  
  // Rural delivery variables
  bool _isRuralArea = false;
  String? _selectedRuralDeliveryType;
  double _ruralDeliveryFee = 0.0;
  
  // Urban delivery variables
  bool _isUrbanArea = false;
  String? _selectedUrbanDeliveryType;
  double _urbanDeliveryFee = 0.0;
  String _productCategory = 'other'; // Default category - will be set based on cart items
  String? _sellerDeliveryPreference; // 'custom' or 'system'
  
  // Mixed cart handling
  bool _hasFoodItems = false;
  bool _hasNonFoodItems = false;
  List<Map<String, dynamic>> _foodItems = [];
  List<Map<String, dynamic>> _nonFoodItems = [];
  
  // Pickup address search
  final TextEditingController _pickupAddressController = TextEditingController();
  List<Placemark> _pickupAddressSuggestions = [];
  
  // Address search variables
  List<Placemark> _addressSuggestions = [];
  Timer? _addressSearchTimer;
  bool _isSearchingAddress = false;
  // Pickup points (Pargo)
  List<PickupPoint> _pickupPoints = [];
  List<PickupPoint> _allPickupPoints = []; // Store all pickup points
  bool _isLoadingPickupPoints = false;
  PickupPoint? _selectedPickupPoint;
  String? _selectedServiceFilter; // 'pargo', 'paxi', or null for all
  double? _selectedLat;
  double? _selectedLng;
  
  // Seller service availability
  bool _sellerPargoEnabled = false;
  bool _sellerPaxiEnabled = false;
  
  // PAXI delivery speed selection
  String? _selectedPaxiDeliverySpeed; // 'standard' or 'express'

  User? get currentUser => FirebaseAuth.instance.currentUser;

  // Web: HERE Autocomplete for pickup address
  Future<void> _herePickupAutocomplete(String query) async {
    try {
      final double atLat = (_selectedLat ?? -33.9249);
      final double atLng = (_selectedLng ?? 18.4241);
      final uri = Uri.parse(
        '${HereConfig.autocompleteUrl}?q=${Uri.encodeComponent(query)}&at=$atLat,$atLng&limit=${HereConfig.defaultSearchLimit}&apiKey=${HereConfig.validatedApiKey}',
      );
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final items = (data['items'] as List?) ?? [];
        final suggestions = items.map((raw) {
          final m = raw as Map<String, dynamic>;
          final title = (m['title'] as String?) ?? '';
          final addr = (m['address'] as Map<String, dynamic>?) ?? {};
          final street = (addr['street'] as String?) ?? '';
          final city = (addr['city'] as String?) ?? '';
          final admin = (addr['state'] as String?) ?? (addr['county'] as String?) ?? '';
          return Placemark(
            name: title,
            street: street,
            locality: city,
            administrativeArea: admin,
          );
        }).toList();
        setState(() {
          _pickupAddressSuggestions = suggestions.cast<Placemark>();
        });
      }
    } catch (e) {
      debugPrint('HERE autocomplete error: $e');
    }
  }

  // PayFast configuration for production
  static const String payfastMerchantId = '23918934';
  static const String payfastMerchantKey = 'fxuj8ymlgqwra';
  static const String payfastReturnUrl = 'https://us-central1-marketplace-8d6bd.cloudfunctions.net/payfastReturn';
  static const String payfastCancelUrl = 'https://us-central1-marketplace-8d6bd.cloudfunctions.net/payfastCancel';
  static const String payfastNotifyUrl = 'https://us-central1-marketplace-8d6bd.cloudfunctions.net/payfastNotify';
  static const bool payfastSandbox = false; // Set to false for production

  // System delivery model pricing (South African market rates)
  static const Map<String, Map<String, dynamic>> _systemDeliveryModel = {
    'food_delivery': {
      'name': 'Food Delivery (Uber Eats, Mr D)',
      'feePerKm': 4.5, // R3-R6 per km average
      'maxFee': 6.0,
      'minFee': 15.0,
      'description': 'Fast food delivery service',
      'features': ['Hot food delivery', 'Real-time tracking', 'SMS updates'],
      'icon': '🍕',
      'maxDistance': 15.0, // Food delivery typically limited to 15km
    },
    'motorcycle': {
      'name': 'Motorcycle Delivery',
      'feePerKm': 6.0, // R4-R8 per km average
      'maxFee': 8.0,
      'minFee': 20.0,
      'description': 'Fast motorcycle delivery',
      'features': ['Quick delivery', 'Traffic navigation', 'Small packages'],
      'icon': '🏍️',
      'maxDistance': 25.0,
    },
    'local_courier': {
      'name': 'Local Courier Service',
      'feePerKm': 7.5, // R5-R10 per km average
      'maxFee': 10.0,
      'minFee': 25.0,
      'description': 'Reliable local courier service',
      'features': ['Package protection', 'Delivery confirmation', 'Customer support'],
      'icon': '📦',
      'maxDistance': 50.0,
    },
    'premium_courier': {
      'name': 'Premium Courier Van',
      'feePerKm': 9.0, // R6-R12 per km average
      'maxFee': 12.0,
      'minFee': 35.0,
      'description': 'Premium delivery with van',
      'features': ['Large packages', 'Cold chain', 'Priority handling', 'Insurance'],
      'icon': '🚐',
      'maxDistance': 100.0,
    },
    'rural_delivery': {
      'name': 'Rural Area Delivery',
      'feePerKm': 12.0, // Higher rates for rural areas
      'maxFee': 15.0,
      'minFee': 50.0,
      'description': 'Rural area delivery service',
      'features': ['Extended coverage', 'Flexible timing', 'Local knowledge'],
      'icon': '🌾',
      'maxDistance': 200.0,
    },
  };

  @override
  void initState() {
    super.initState();
    _orderCompleted = false; // Reset order completion flag
    if (currentUser != null) {
      _detectProductCategory();
      _calculateDeliveryFeeAndCheckStore();
    }
    _addressFocusNode.addListener(() {
      if (!_addressFocusNode.hasFocus) {
        _calculateDeliveryFeeAndCheckStore();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _deliveryInstructionsController.dispose();
    _specialRequestsController.dispose();
    _addressFocusNode.dispose();
    _addressSearchTimer?.cancel();
    super.dispose();
  }

  // Calculate delivery fee using system model
  double _calculateSystemDeliveryFee(double distance, String modelType) {
    final model = _systemDeliveryModel[modelType];
    if (model == null) {
      // Fallback to local courier if model not found
      return _calculateFallbackDeliveryFee(distance);
    }
    
    final baseFee = model['feePerKm'] as double;
    final maxFee = model['maxFee'] as double;
    final minFee = model['minFee'] as double;
    final maxDistance = model['maxDistance'] as double;
    
    // Check if distance exceeds model's maximum
    if (distance > maxDistance) {
      // Use rural delivery model for long distances
      return _calculateSystemDeliveryFee(distance, 'rural_delivery');
    }
    
    // Calculate fee with distance multiplier
    double fee = distance * baseFee;
    
    // Apply max fee limit
    if (fee > maxFee * distance) {
      fee = maxFee * distance;
    }
    
    // Ensure minimum fee
    if (fee < minFee) fee = minFee;
    
    // Apply South African market adjustments
    if (distance <= 5.0) {
      // Close deliveries get 10% discount
      fee *= 0.9;
    } else if (distance > 20.0) {
      // Long deliveries get 15% premium
      fee *= 1.15;
    }
    
    return fee;
  }
  
  // Calculate fallback delivery fee when system model is unavailable
  double _calculateFallbackDeliveryFee(double distance) {
    // Use South African market rates as fallback
    double baseFee;
    double minFee;
    
    if (_productCategory.toLowerCase() == 'food') {
      // Food delivery fallback rates
      baseFee = 5.0; // R5 per km average
      minFee = 20.0;
    } else if (distance > 50.0) {
      // Rural/long distance fallback
      baseFee = 12.0; // R12 per km for rural areas
      minFee = 60.0;
    } else if (distance > 25.0) {
      // Medium distance fallback
      baseFee = 8.0; // R8 per km for medium distances
      minFee = 35.0;
    } else {
      // Local delivery fallback
      baseFee = 6.0; // R6 per km for local deliveries
      minFee = 25.0;
    }
    
    double fee = distance * baseFee;
    
    // Apply minimum fee
    if (fee < minFee) fee = minFee;
    
    // Add fuel surcharge for longer distances (South African fuel costs)
    if (distance > 30.0) {
      fee += (distance - 30.0) * 0.5; // R0.50 per km fuel surcharge
    }
    
    return fee;
  }
  
  // Get optimal delivery model based on distance and product type
  String _getOptimalDeliveryModel(double distance, String productCategory) {
    if (productCategory.toLowerCase() == 'food') {
      if (distance <= 15.0) return 'food_delivery';
      if (distance <= 25.0) return 'motorcycle';
      return 'local_courier';
    } else {
      if (distance <= 25.0) return 'motorcycle';
      if (distance <= 50.0) return 'local_courier';
      if (distance <= 100.0) return 'premium_courier';
      return 'rural_delivery';
    }
  }

  // Get delivery model display text
  String _getDeliveryModelDisplayText() {
    if (_sellerDeliveryPreference == 'system') {
      final optimalModel = _getOptimalDeliveryModel(_deliveryDistance ?? 0.0, _productCategory);
      final model = _systemDeliveryModel[optimalModel];
      return model?['name'] ?? 'South African Delivery Model';
    } else {
      return 'Custom Delivery Rate';
    }
  }

  // Get delivery model description
  String _getDeliveryModelDescription() {
    if (_sellerDeliveryPreference == 'system') {
      final optimalModel = _getOptimalDeliveryModel(_deliveryDistance ?? 0.0, _productCategory);
      final model = _systemDeliveryModel[optimalModel];
      final icon = model?['icon'] ?? '🚚';
      final description = model?['description'] ?? 'Professional delivery service';
      return '$icon $description - Market competitive rates';
    } else {
      return 'Using seller\'s custom delivery rate per kilometer';
    }
  }
  
  // Get current delivery model details for display
  Map<String, dynamic>? _getCurrentDeliveryModel() {
    if (_sellerDeliveryPreference == 'system') {
      final optimalModel = _getOptimalDeliveryModel(_deliveryDistance ?? 0.0, _productCategory);
      return _systemDeliveryModel[optimalModel];
    }
    return null;
  }

  // Detect product category from cart items
  Future<void> _detectProductCategory() async {
    try {
      final cartSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('cart')
          .get();
      
      if (cartSnapshot.docs.isNotEmpty) {
        print('🔍 DEBUG: Cart has ${cartSnapshot.docs.length} items');
        
        // Separate food and non-food items
        List<Map<String, dynamic>> foodItems = [];
        List<Map<String, dynamic>> nonFoodItems = [];
        bool hasFood = false;
        bool hasNonFood = false;
        
        for (var doc in cartSnapshot.docs) {
          final data = doc.data();
          print('🔍 DEBUG: Cart item data: ${data.toString()}');
          final category = data['category']?.toString().toLowerCase() ?? '';
          print('🔍 DEBUG: Checking category: "$category" from data: ${data['category']}');
          
          if (category == 'food') {
            hasFood = true;
            foodItems.add(data);
            print('🔍 DEBUG: Found food item: ${data['name'] ?? 'Unknown'}');
          } else {
            hasNonFood = true;
            nonFoodItems.add(data);
            print('🔍 DEBUG: Found non-food item: ${data['name'] ?? 'Unknown'}');
          }
        }
        
        setState(() {
          _hasFoodItems = hasFood;
          _hasNonFoodItems = hasNonFood;
          _foodItems = foodItems;
          _nonFoodItems = nonFoodItems;
          
          // Set primary category based on majority or mixed
          if (hasFood && hasNonFood) {
            _productCategory = 'mixed';
          } else if (hasFood) {
            _productCategory = 'food';
          } else {
            _productCategory = 'other';
          }
        });
        
        print('🔍 DEBUG: Product category detected: $_productCategory');
        print('🔍 DEBUG: Has food: $_hasFoodItems, Has non-food: $_hasNonFoodItems');
      }
    } catch (e) {
      print('❌ Error detecting product category: $e');
    }
  }

  // Show Pargo pickup point modal
  void _showPargoPickupModal(PickupPoint point) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: point.isPargoPoint 
                    ? [
                        AppTheme.deepTeal.withOpacity(0.15),
                        AppTheme.deepTeal.withOpacity(0.05),
                        AppTheme.angel,
                      ]
                    : [
                        AppTheme.deepTeal.withOpacity(0.15),
                        AppTheme.deepTeal.withOpacity(0.05),
                        AppTheme.angel,
                      ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: point.isPargoPoint 
                    ? AppTheme.deepTeal.withOpacity(0.4)
                    : AppTheme.deepTeal.withOpacity(0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                color: point.isPargoPoint 
                    ? AppTheme.deepTeal.withOpacity(0.3)
                    : AppTheme.deepTeal.withOpacity(0.3),
                  blurRadius: 20,
                  offset: Offset(0, 10),
              ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Enhanced Header with gradient background
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: point.isPargoPoint 
                          ? [
                              AppTheme.deepTeal.withOpacity(0.3),
                              AppTheme.deepTeal.withOpacity(0.1),
                            ]
                          : [
                              AppTheme.deepTeal.withOpacity(0.3),
                              AppTheme.deepTeal.withOpacity(0.1),
                            ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Icon with animated background
                      Container(
                        padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: point.isPargoPoint 
                        ? AppTheme.deepTeal.withOpacity(0.2)
                        : AppTheme.deepTeal.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: point.isPargoPoint 
                                ? AppTheme.deepTeal.withOpacity(0.5)
                                : AppTheme.deepTeal.withOpacity(0.5),
                            width: 2,
                          ),
                  ),
                  child: Icon(
                    point.isPargoPoint 
                        ? Icons.local_shipping
                        : Icons.storefront,
                    color: point.isPargoPoint 
                        ? AppTheme.deepTeal
                        : AppTheme.deepTeal,
                          size: 40,
                  ),
                ),
                SizedBox(height: 16),
                
                      // Pickup point name with enhanced typography
                SafeUI.safeText(
                  point.name,
                  style: TextStyle(
                          fontSize: ResponsiveUtils.getTitleSize(context) + 2,
                          fontWeight: FontWeight.w800,
                    color: point.isPargoPoint 
                        ? AppTheme.deepTeal
                        : AppTheme.deepTeal,
                          letterSpacing: 0.5,
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
                      SizedBox(height: 12),
                
                      // Enhanced type badge with gradient
                Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: point.isPargoPoint 
                                ? [
                                    AppTheme.deepTeal.withOpacity(0.3),
                                    AppTheme.deepTeal.withOpacity(0.1),
                                  ]
                                : [
                                    AppTheme.deepTeal.withOpacity(0.3),
                                    AppTheme.deepTeal.withOpacity(0.1),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: point.isPargoPoint 
                                ? AppTheme.deepTeal.withOpacity(0.6)
                                : AppTheme.deepTeal.withOpacity(0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              point.isPargoPoint 
                                  ? Icons.verified
                                  : Icons.store,
                              color: point.isPargoPoint 
                                  ? AppTheme.deepTeal
                                  : AppTheme.deepTeal,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            SafeUI.safeText(
                              point.isPargoPoint ? '🚚 Pargo Verified Point' : 
                point.isPaxiPoint ? '📦 PAXI Point' : '🏪 Pickup',
                    style: TextStyle(
                                fontSize: ResponsiveUtils.getTitleSize(context) - 3,
                                fontWeight: FontWeight.w700,
                      color: point.isPargoPoint 
                          ? AppTheme.deepTeal
                          : AppTheme.deepTeal,
                    ),
                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Enhanced Details Section
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Key Information Cards
                Container(
                          padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.angel,
                            borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.breeze.withOpacity(0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.breeze.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                  ),
                  child: Column(
                    children: [
                              // Address with map icon
                              _buildEnhancedDetailRow(
                                '📍 Location',
                                point.address,
                                Icons.location_on,
                                point.isPargoPoint 
                                    ? AppTheme.deepTeal
                                    : AppTheme.deepTeal,
                              ),
                              SizedBox(height: 16),
                              
                              // Distance with route icon
                              _buildEnhancedDetailRow(
                                '📏 Distance',
                                '${point.distance.toStringAsFixed(1)} km from your location',
                                Icons.straighten,
                                point.isPargoPoint 
                                    ? AppTheme.deepTeal
                                    : AppTheme.deepTeal,
                              ),
                              SizedBox(height: 16),
                              
                              // Fee with payment icon
                              _buildEnhancedDetailRow(
                                '💰 Pickup Fee',
                                'R${point.fee.toStringAsFixed(2)}',
                                Icons.payment,
                                point.isPargoPoint 
                                    ? AppTheme.deepTeal
                                    : AppTheme.deepTeal,
                              ),
                              SizedBox(height: 16),
                              
                              // Service Type
                              _buildEnhancedDetailRow(
                                '🏷️ Service Type',
                                point.type,
                                Icons.category,
                                point.isPargoPoint 
                                    ? AppTheme.deepTeal
                                    : AppTheme.deepTeal,
                              ),
                              SizedBox(height: 16),
                              
                              // Operating Hours - CRITICAL INFORMATION
                              _buildEnhancedDetailRow(
                                '⏰ Operating Hours',
                                point.operatingHours,
                                Icons.access_time,
                                point.isPargoPoint 
                                    ? AppTheme.deepTeal
                                    : AppTheme.deepTeal,
                              ),
                              SizedBox(height: 16),
                              
                              // Coordinates for reference
                              _buildEnhancedDetailRow(
                                '🌐 Coordinates',
                                '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
                                Icons.gps_fixed,
                                point.isPargoPoint 
                                    ? AppTheme.deepTeal
                                    : AppTheme.deepTeal,
                              ),
                              
                              // Pargo-specific details
                              if (point.isPargoPoint && point.pargoId != null) ...[
                                SizedBox(height: 16),
                                _buildEnhancedDetailRow(
                                  '🆔 Pargo ID',
                                  point.pargoId!,
                                  Icons.qr_code,
                                  AppTheme.deepTeal,
                                ),
                              ],
                    ],
                  ),
                ),
                        
                        SizedBox(height: 20),
                        
                        // Operating Hours Highlight Section
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.warning.withOpacity(0.1),
                                AppTheme.warning.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.warning.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    color: AppTheme.warning,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  SafeUI.safeText(
                                    '📅 Operating Schedule',
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.warning,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.angel,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.warning.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      color: AppTheme.warning,
                                      size: 16,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: SafeUI.safeText(
                                        point.operatingHours,
                                        style: TextStyle(
                                          fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.deepTeal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 20),
                        
                        // Additional Information for Pargo points
                        if (point.isPargoPoint) ...[
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.deepTeal.withOpacity(0.1),
                                  AppTheme.deepTeal.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.deepTeal.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: AppTheme.deepTeal,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    SafeUI.safeText(
                                      'Why Choose Pargo?',
                                      style: TextStyle(
                                        fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.deepTeal,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                _buildBenefitRow('🔒 Secure & Safe', 'Your package is stored securely'),
                                _buildBenefitRow('📱 SMS Notifications', 'Get notified when your package arrives'),
                                _buildBenefitRow('⏰ Flexible Pickup', 'Collect at your convenience'),
                                _buildBenefitRow('📍 Convenient Locations', 'Multiple pickup points near you'),
                                _buildBenefitRow('💳 No Extra Fees', 'Transparent pricing with no hidden costs'),
                                _buildBenefitRow('🚚 Professional Service', 'Reliable and trusted pickup service'),
                              ],
                            ),
                          ),
                        ],
                        
                        // Store-specific information for non-Pargo points
                        if (!point.isPargoPoint) ...[
                          SizedBox(height: 20),
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.deepTeal.withOpacity(0.1),
                                  AppTheme.deepTeal.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.deepTeal.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.store,
                                      color: AppTheme.deepTeal,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    SafeUI.safeText(
                                      'Store Information',
                                      style: TextStyle(
                                        fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.deepTeal,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                _buildBenefitRow('🏪 Local Business', 'Support local community businesses'),
                                _buildBenefitRow('💬 Personal Service', 'Direct communication with store staff'),
                                _buildBenefitRow('🔍 Product Inspection', 'Check your items before pickup'),
                                _buildBenefitRow('💰 Competitive Pricing', 'Often lower fees than courier services'),
                              ],
                            ),
                          ),
                        ],
                        
                        SizedBox(height: 20),
                        
                        // Important Notes Section
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.info.withOpacity(0.1),
                                AppTheme.info.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.info.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    color: AppTheme.info,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  SafeUI.safeText(
                                    '💡 Important Notes',
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.info,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              _buildInstructionRow('Bring valid ID for pickup verification'),
                              _buildInstructionRow('Check operating hours before visiting'),
                              _buildInstructionRow('Keep your order reference number handy'),
                              if (point.isPargoPoint) ...[
                                _buildInstructionRow('SMS notification will be sent when ready'),
                                _buildInstructionRow('Package held for 7 days after arrival'),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Enhanced Action Buttons
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.angel,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: AppTheme.breeze.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: AppTheme.breeze.withOpacity(0.3),
                                width: 1,
                              ),
                          ),
                        ),
                        child: SafeUI.safeText(
                          'Cancel',
                          style: TextStyle(
                            color: AppTheme.breeze,
                            fontWeight: FontWeight.w600,
                              fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                          ),
                        ),
                      ),
                    ),
                      SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedPickupPoint = point;
                            _deliveryFee = point.fee;
                          });
                          Navigator.of(context).pop();
                            
                            // Show success message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      point.isPargoPoint 
                                          ? Icons.local_shipping
                                          : Icons.storefront,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Selected: ${point.name}',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: point.isPargoPoint 
                                    ? AppTheme.deepTeal
                                    : AppTheme.deepTeal,
                                duration: Duration(seconds: 3),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: point.isPargoPoint 
                              ? AppTheme.deepTeal
                              : AppTheme.deepTeal,
                          foregroundColor: AppTheme.angel,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            shadowColor: point.isPargoPoint 
                                ? AppTheme.deepTeal.withOpacity(0.4)
                                : AppTheme.deepTeal.withOpacity(0.4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                point.isPargoPoint 
                                    ? Icons.check_circle
                                    : Icons.store,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              SafeUI.safeText(
                          'Select This Point',
                          style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                          ),
                              ),
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
        );
      },
    );
  }

  // Enhanced detail row with better styling
  Widget _buildEnhancedDetailRow(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.whisper,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: iconColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
      children: [
        Container(
            padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: iconColor.withOpacity(0.3),
                width: 1,
              ),
          ),
          child: Icon(
            icon,
              color: iconColor,
              size: 18,
          ),
        ),
          SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeUI.safeText(
                label,
                style: TextStyle(
                  fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                  color: AppTheme.breeze,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                ),
              ),
                SizedBox(height: 4),
              SafeUI.safeText(
                value,
                style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                  color: AppTheme.deepTeal,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Benefit row for Pargo advantages
  Widget _buildBenefitRow(String title, String description) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.deepTeal,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                  fontWeight: FontWeight.w600,
                    color: AppTheme.deepTeal,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context) - 5,
                    color: AppTheme.breeze,
                    height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }

  // Show all pickup points in a comprehensive modal
  void _showAllPickupPointsModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.95,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.deepTeal.withOpacity(0.15),
                  AppTheme.deepTeal.withOpacity(0.1),
                  AppTheme.angel,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.deepTeal.withOpacity(0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.deepTeal.withOpacity(0.3),
                  blurRadius: 25,
                  offset: Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              children: [
                // Enhanced Header
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.deepTeal.withOpacity(0.4),
                        AppTheme.deepTeal.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.angel.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.angel.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.list_alt,
                              color: AppTheme.deepTeal,
                              size: 32,
                            ),
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SafeUI.safeText(
                                  '🚚 All Pickup Points',
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.getTitleSize(context) + 4,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.deepTeal,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                ),
                                SafeUI.safeText(
                                  '${_pickupPoints.length} locations available near you',
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.getTitleSize(context) - 1,
                                    color: AppTheme.angel,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      
                      // Filter options
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.angel.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.angel.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.filter_list,
                                    color: AppTheme.deepTeal,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  SafeUI.safeText(
                                    'All Types',
                                    style: TextStyle(
                                      color: AppTheme.deepTeal,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.deepTeal.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.deepTeal.withOpacity(0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.local_shipping,
                                    color: AppTheme.deepTeal,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  SafeUI.safeText(
                                    'Pargo Only',
                                    style: TextStyle(
                                      color: AppTheme.deepTeal,
                                      fontWeight: FontWeight.w600,
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
                
                // Pickup Points List
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(20),
                    itemCount: _pickupPoints.length,
                    itemBuilder: (context, index) {
                      final point = _pickupPoints[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: point.isPargoPoint 
                                ? [
                                    AppTheme.deepTeal.withOpacity(0.15),
                                    AppTheme.deepTeal.withOpacity(0.05),
                                    AppTheme.angel,
                                  ]
                                : [
                                    AppTheme.deepTeal.withOpacity(0.15),
                                    AppTheme.deepTeal.withOpacity(0.05),
                                    AppTheme.angel,
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: point.isPargoPoint 
                                ? AppTheme.deepTeal.withOpacity(0.4)
                                : AppTheme.deepTeal.withOpacity(0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: point.isPargoPoint 
                                  ? AppTheme.deepTeal.withOpacity(0.15)
                                  : AppTheme.deepTeal.withOpacity(0.15),
                              blurRadius: 15,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              Navigator.of(context).pop();
                              _showPargoPickupModal(point);
                            },
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  // Enhanced Icon Container
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: point.isPargoPoint 
                                            ? [
                                                AppTheme.deepTeal.withOpacity(0.4),
                                                AppTheme.deepTeal.withOpacity(0.1),
                                              ]
                                            : [
                                                AppTheme.deepTeal.withOpacity(0.4),
                                                AppTheme.deepTeal.withOpacity(0.1),
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: point.isPargoPoint 
                                            ? AppTheme.deepTeal.withOpacity(0.6)
                                            : AppTheme.deepTeal.withOpacity(0.6),
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      point.isPargoPoint 
                                          ? Icons.local_shipping
                                          : Icons.storefront,
                                      color: point.isPargoPoint 
                                          ? AppTheme.deepTeal
                                          : AppTheme.deepTeal,
                                      size: 28,
                                    ),
                                  ),
                                  SizedBox(width: 20),
                                  
                                  // Content Section
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Name with enhanced styling
                                        SafeUI.safeText(
                                          point.name,
                                          style: TextStyle(
                                            fontSize: ResponsiveUtils.getTitleSize(context) + 1,
                                            fontWeight: FontWeight.w900,
                                            color: point.isPargoPoint 
                                                ? AppTheme.deepTeal
                                                : AppTheme.deepTeal,
                                            letterSpacing: 0.3,
                                          ),
                                          maxLines: 1,
                                        ),
                                        SizedBox(height: 12),
                                        
                                        // Address with location icon
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              color: AppTheme.breeze,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: SafeUI.safeText(
                                                point.address,
                                                style: TextStyle(
                                                  color: AppTheme.breeze,
                                                  fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                                                  height: 1.3,
                                                ),
                                                maxLines: 2,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 12),
                                        
                                        // Service details row
                                        Row(
                                          children: [
                                            // Service type badge
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: point.isPargoPoint 
                                                    ? AppTheme.deepTeal.withOpacity(0.3)
                                                    : AppTheme.deepTeal.withOpacity(0.3),
                                                borderRadius: BorderRadius.circular(15),
                                                border: Border.all(
                                                  color: point.isPargoPoint 
                                                      ? AppTheme.deepTeal.withOpacity(0.5)
                                                      : AppTheme.deepTeal.withOpacity(0.5),
                                                ),
                                              ),
                                              child: SafeUI.safeText(
                                                point.isPargoPoint 
                                                    ? '🚚 Pargo Service'
                                                    : '🏪 Pickup',
                                                style: TextStyle(
                                                  fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                                                  fontWeight: FontWeight.w700,
                                                  color: point.isPargoPoint 
                                                      ? AppTheme.deepTeal
                                                      : AppTheme.deepTeal,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 16),
                                            
                                            // Distance
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppTheme.breeze.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(15),
                                                border: Border.all(
                                                  color: AppTheme.breeze.withOpacity(0.4),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.straighten,
                                                    color: AppTheme.breeze,
                                                    size: 16,
                                                  ),
                                                  SizedBox(width: 6),
                                                  SafeUI.safeText(
                                                    '${point.distance.toStringAsFixed(1)} km',
                                                    style: TextStyle(
                                                      fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppTheme.breeze,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(width: 16),
                                            
                                            // Fee
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    AppTheme.success.withOpacity(0.3),
                                                    AppTheme.success.withOpacity(0.1),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.circular(15),
                                                border: Border.all(
                                                  color: AppTheme.success.withOpacity(0.5),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.payment,
                                                    color: AppTheme.success,
                                                    size: 16,
                                                  ),
                                                  SizedBox(width: 6),
                                                  SafeUI.safeText(
                                                    'R${point.fee.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppTheme.success,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Arrow indicator
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: point.isPargoPoint 
                                        ? AppTheme.deepTeal.withOpacity(0.6)
                                        : AppTheme.deepTeal.withOpacity(0.6),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Close Button
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.angel,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: AppTheme.breeze.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.deepTeal,
                        foregroundColor: AppTheme.angel,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: SafeUI.safeText(
                        'Close',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: ResponsiveUtils.getTitleSize(context) - 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Inline address search functionality
  void _searchAddressesInline(String query) {
    _addressSearchTimer?.cancel();
    _addressSearchTimer = Timer(const Duration(milliseconds: 500), () async {
      if (query.trim().length < 3) {
        setState(() {
          _addressSuggestions = [];
          _isSearchingAddress = false;
        });
      return;
    }
    
      setState(() {
        _isSearchingAddress = true;
      });

      print('🔍 Searching for address: $query');

      try {
        // For web platform, use free OpenStreetMap Nominatim API
        if (kIsWeb) {
          print('🌐 Web platform detected - using free Nominatim geocoding');
          
          await _searchWithNominatim(query);
          return;
        }
        
        // For mobile platforms, use geocoding API
        final locations = await locationFromAddress(query);
        print('🔍 Found ${locations.length} locations for query: $query');
        
        if (locations.isNotEmpty) {
          // Get detailed address information for each location
          List<Placemark> placemarks = [];
          for (final location in locations.take(5)) { // Limit to 5 results
            try {
              // Check for null coordinates
              if (location.latitude == null || location.longitude == null) {
                print('⚠️ Warning: Location has null coordinates');
                continue;
              }
              
              print('🔍 Getting placemark for coordinates: ${location.latitude}, ${location.longitude}');
              final placemarkList = await placemarkFromCoordinates(
                location.latitude!,
                location.longitude!,
              );
              if (placemarkList.isNotEmpty) {
                placemarks.addAll(placemarkList);
                print('🔍 Added ${placemarkList.length} placemarks');
              }
            } catch (e) {
              print('❌ Error getting placemark for location: $e');
            }
          }
          
          print('🔍 Total placemarks found: ${placemarks.length}');
          setState(() {
            _addressSuggestions = placemarks;
            _isSearchingAddress = false;
          });
          if (!_isDelivery && locations.isNotEmpty) {
            final loc = locations.first;
            // Check for null coordinates before proceeding
            if (loc.latitude != null && loc.longitude != null) {
              _selectedLat = loc.latitude;
              _selectedLng = loc.longitude;
              _loadPickupPointsForCoordinates(loc.latitude!, loc.longitude!);
            }
          }
        } else {
          print('🔍 No locations found for query: $query');
          setState(() {
            _addressSuggestions = [];
            _isSearchingAddress = false;
          });
      }
    } catch (e) {
        print('❌ Error searching addresses: $e');
        // Fallback for any platform: allow user to use entered address
        setState(() {
          _addressSuggestions = [
            Placemark(
              name: query,
              locality: query,
              administrativeArea: '',
              country: 'South Africa',
              street: query,
              postalCode: '',
            ),
          ];
          _isSearchingAddress = false;
        });
      }
    });
  }

  // Free OpenStreetMap Nominatim geocoding for web
  Future<void> _searchWithNominatim(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent('$query, South Africa');
      final url = 'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=5&countrycodes=za&addressdetails=1';
      
      print('🌐 Nominatim request: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'MzansiMarketplace/1.0 (https://marketplace-8d6bd.web.app)',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('🌐 Nominatim response: ${data.length} results');
        
        List<Placemark> suggestions = [];
        
        for (final item in data) {
          final address = item['address'] ?? {};
          final displayName = item['display_name'] ?? '';
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lon = double.tryParse(item['lon']?.toString() ?? '');
          
          if (lat != null && lon != null) {
            suggestions.add(
              Placemark(
                name: displayName,
                street: address['road'] ?? address['house_number'] ?? '',
                locality: address['city'] ?? address['town'] ?? address['village'] ?? address['suburb'] ?? '',
                administrativeArea: address['state'] ?? address['province'] ?? '',
                postalCode: address['postcode'] ?? '',
                country: 'South Africa',
              ),
            );
            
            // Store coordinates for pickup points loading
            if (suggestions.length == 1) {
              _selectedLat = lat;
              _selectedLng = lon;
              if (!_isDelivery) {
                _loadPickupPointsForCoordinates(lat, lon);
              }
            }
          }
        }
        
        // If no results, allow user to use their entered address
        if (suggestions.isEmpty) {
          suggestions.add(
            Placemark(
              name: query,
              locality: query,
              administrativeArea: '',
              country: 'South Africa',
              street: query,
              postalCode: '',
            ),
          );
        }
        
        setState(() {
          _addressSuggestions = suggestions;
          _isSearchingAddress = false;
        });
        
        print('🌐 Created ${suggestions.length} Nominatim suggestions');
      } else {
        throw Exception('Nominatim API returned ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Nominatim geocoding error: $e');
      
      // Fallback to manual suggestions
      List<Placemark> fallbackSuggestions = [];
      final queryLower = query.toLowerCase();
      
      // Major South African cities for fallback
      final locations = [
        'Cape Town, Western Cape',
        'Johannesburg, Gauteng', 
        'Durban, KwaZulu-Natal',
        'Pretoria, Gauteng',
        'Port Elizabeth, Eastern Cape',
        'Bloemfontein, Free State',
        'East London, Eastern Cape',
        'Nelspruit, Mpumalanga',
        'Polokwane, Limpopo',
        'Kimberley, Northern Cape',
      ];
      
      // Filter locations that match the query
      for (final loc in locations) {
        if (loc.toLowerCase().contains(queryLower)) {
          fallbackSuggestions.add(
            Placemark(
              name: loc,
              locality: loc.split(',').first,
              administrativeArea: loc.split(',').last.trim(),
              country: 'South Africa',
              street: '',
              postalCode: '',
            ),
          );
        }
      }
      
      // Always allow user to use their entered address
      fallbackSuggestions.add(
        Placemark(
          name: query,
          locality: query,
          administrativeArea: '',
          country: 'South Africa',
          street: query,
          postalCode: '',
        ),
      );
      
      setState(() {
        _addressSuggestions = fallbackSuggestions;
        _isSearchingAddress = false;
      });
      
      print('🔍 Used fallback suggestions: ${fallbackSuggestions.length} items');
    }
  }

  Future<void> _loadPickupPointsForCurrentAddress() async {
    try {
      if (_addressController.text.trim().length < 3) return;
      setState(() => _isLoadingPickupPoints = true);
      final locs = await locationFromAddress(_addressController.text.trim());
      if (locs.isNotEmpty) {
        final loc = locs.first;
        _selectedLat = loc.latitude;
        _selectedLng = loc.longitude;
        await _loadPickupPointsForCoordinates(loc.latitude!, loc.longitude!);
      }
    } catch (_) {
      // ignore
    } finally {
      setState(() => _isLoadingPickupPoints = false);
    }
  }

  // Search for pickup addresses
  Future<void> _searchPickupAddress(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _pickupAddressSuggestions = [];
      });
      return;
    }

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final location = locations.first;
        
        // Check for null coordinates before proceeding
        if (location.latitude == null || location.longitude == null) {
          print('⚠️ Warning: Location has null coordinates for query: $query');
          setState(() {
            _pickupAddressSuggestions = [];
          });
          return;
        }
        
        List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude!, 
          location.longitude!
        );
        setState(() {
          _pickupAddressSuggestions = placemarks.take(5).toList();
        });
      }
    } catch (e) {
      print('❌ Error searching pickup address: $e');
      setState(() {
        _pickupAddressSuggestions = [];
      });
    }
  }

  // Format address from placemark
  String _formatAddress(Placemark placemark) {
    final parts = [
      placemark.name,
      placemark.locality,
      placemark.subAdministrativeArea,
      placemark.administrativeArea,
    ].where((part) => part != null && part.isNotEmpty).toList();
    return parts.join(', ');
  }

  // Show pickup point details dialog
  void _showPickupPointDetails(PickupPoint point) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                point.isPargoPoint ? Icons.store : Icons.location_on,
                color: AppTheme.deepTeal,
                size: 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  point.name,
                  style: TextStyle(
                    color: AppTheme.deepTeal,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, color: AppTheme.breeze, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        point.address,
                        style: TextStyle(
                          color: AppTheme.angel,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                
                // Pickup fee
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.deepTeal,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'R',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Pickup Fee: R${point.fee.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppTheme.deepTeal,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                
                // Operating hours (if available)
                if (point.operatingHours != null && point.operatingHours!.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.access_time, color: AppTheme.breeze, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Operating Hours:',
                              style: TextStyle(
                                color: AppTheme.angel,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              point.operatingHours!,
                              style: TextStyle(
                                color: AppTheme.breeze,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                ],
                
                // Pickup instructions
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.deepTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppTheme.deepTeal, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Pickup Instructions:',
                            style: TextStyle(
                              color: AppTheme.deepTeal,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        point.isPargoPoint 
                            ? '📦 Collect from Pargo counter with ID verification. Bring your order confirmation and a valid ID. Items are held for 7 days.'
                            : '🏪 Collect from store counter. Show your order confirmation to the staff. Please call ahead to confirm availability.',
                        style: TextStyle(
                          color: AppTheme.deepTeal,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Pargo ID (if available)
                if (point.pargoId != null && point.pargoId!.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.qr_code, color: AppTheme.deepTeal, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Pargo ID: ${point.pargoId}',
                        style: TextStyle(
                          color: AppTheme.deepTeal,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: AppTheme.breeze),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedPickupPoint = point;
                  _deliveryFee = point.fee;
                });
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.deepTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Select This Point'),
            ),
          ],
        );
      },
    );
  }

  // Load pickup points for specific address
  Future<void> _loadPickupPointsForAddress(String address) async {
    print('🚚 DEBUG: Loading pickup points for address: $address');
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        await _loadPickupPointsForCoordinates(
          locations.first.latitude,
          locations.first.longitude,
        );
      }
    } catch (e) {
      print('❌ Error loading pickup points for address: $e');
    }
  }

  Future<void> _loadPickupPointsForCurrentLocation() async {
    try {
      print('🚚 DEBUG: Loading pickup points for current location...');
      setState(() => _isLoadingPickupPoints = true);
      
      // Try to get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );
      
      print('🚚 DEBUG: Got current position: ${position.latitude}, ${position.longitude}');
      
      // Set coordinates and load pickup points
      _selectedLat = position.latitude;
      _selectedLng = position.longitude;
      
      await _loadPickupPointsForCoordinates(position.latitude, position.longitude);
      
    } catch (e) {
      print('❌ DEBUG: Could not get current location: $e');
      // Fallback: Load pickup points for a default location (Pretoria)
      print('🚚 DEBUG: Using fallback location (Pretoria)');
      _selectedLat = -26.0625279;
      _selectedLng = 28.227473;
      await _loadPickupPointsForCoordinates(-26.0625279, 28.227473);
    } finally {
      setState(() => _isLoadingPickupPoints = false);
    }
  }

  Future<void> _loadPickupPointsForCoordinates(double latitude, double longitude) async {
    print('🚚 DEBUG: Loading pickup points for coordinates: $latitude, $longitude');
    setState(() {
      _isLoadingPickupPoints = true;
      _pickupPoints = [];
      _selectedPickupPoint = null;
      _selectedServiceFilter = null; // Reset filter when loading new points
    });
    try {
      final points = await CourierQuoteService.getPickupPoints(
        latitude: latitude,
        longitude: longitude,
      );
      print('🚚 DEBUG: Found ${points.length} pickup points');
      
      // Debug: Check the types of points we received
      for (int i = 0; i < points.length && i < 3; i++) {
        final point = points[i];
        print('🚚 DEBUG: Point $i: ${point.name} - isPargo: ${point.isPargoPoint}, isPaxi: ${point.isPaxiPoint}');
      }
      
      setState(() {
        _allPickupPoints = points; // Store all points
        _pickupPoints = points; // Initially show all points
        if (_pickupPoints.isNotEmpty) {
          _selectedPickupPoint = _pickupPoints.first;
          _deliveryFee = _selectedPickupPoint!.fee;
          print('🚚 DEBUG: Selected pickup point: ${_selectedPickupPoint!.name}');
          print('🚚 DEBUG: After loading pickup points - UI visibility check:');
          print('  - _isDelivery: $_isDelivery');
          print('  - _productCategory: $_productCategory');
          print('  - _hasNonFoodItems: $_hasNonFoodItems');
          print('  - UI should show: ${!_isDelivery && (_productCategory.toLowerCase() != 'food' || _hasNonFoodItems)}');
        }
      });
    } catch (e) {
      print('❌ DEBUG: Error loading pickup points: $e');
    } finally {
      setState(() => _isLoadingPickupPoints = false);
    }
  }

  void _filterPickupPointsByService(String? service) {
    print('🔍 DEBUG: Filtering pickup points by service: $service');
    print('🔍 DEBUG: Total pickup points available: ${_allPickupPoints.length}');
    print('🔍 DEBUG: Pargo points: ${_allPickupPoints.where((point) => point.isPargoPoint).length}');
    print('🔍 DEBUG: PAXI points: ${_allPickupPoints.where((point) => point.isPaxiPoint).length}');
    
    setState(() {
      _selectedServiceFilter = service;
      if (service == null) {
        // Show all points
        _pickupPoints = _allPickupPoints;
        print('🔍 DEBUG: Showing all points: ${_pickupPoints.length}');
      } else if (service == 'pargo') {
        // Show only Pargo points
        _pickupPoints = _allPickupPoints.where((point) => point.isPargoPoint).toList();
        print('🔍 DEBUG: Showing Pargo points: ${_pickupPoints.length}');
      } else if (service == 'paxi') {
        // Show only PAXI points
        _pickupPoints = _allPickupPoints.where((point) => point.isPaxiPoint).toList();
        print('🔍 DEBUG: Showing PAXI points: ${_pickupPoints.length}');
      }
      
      // Update selected pickup point if current selection is not in filtered list
      if (_pickupPoints.isNotEmpty) {
        if (_selectedPickupPoint == null || !_pickupPoints.contains(_selectedPickupPoint)) {
          _selectedPickupPoint = _pickupPoints.first;
          _deliveryFee = _selectedPickupPoint!.fee;
          print('🔍 DEBUG: Updated selected pickup point: ${_selectedPickupPoint!.name}');
        }
      } else {
        _selectedPickupPoint = null;
        _deliveryFee = null;
        print('🔍 DEBUG: No pickup points available for selected service');
      }
      
      // Reset PAXI delivery speed when service filter changes
      if (service != 'paxi') {
        _selectedPaxiDeliverySpeed = null;
        print('🔍 DEBUG: Reset PAXI delivery speed - service changed to: $service');
      }
    });
  }

  Future<void> _calculateDeliveryFeeAndCheckStore() async {
    if (currentUser == null) {
      print('🔍 DEBUG: No current user, skipping delivery calculation');
      // Set default payment methods and mark as loaded even without user
      setState(() {
        _paymentMethods = ['Cash on Delivery', 'PayFast (Card)', 'Bank Transfer (EFT)'];
        _paymentMethodsLoaded = true;
        _deliveryFee = 15.0;
        _deliveryDistance = 5.0;
      });
      return;
    }
    
    try {
      print('🔍 DEBUG: Starting delivery fee calculation...');
      
      // Fetch cart items to get seller info
      final cartSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('cart')
          .get();
      
      if (cartSnapshot.docs.isEmpty) {
        print('🔍 DEBUG: No cart items found');
        // Set default values and mark as loaded even without cart items
        setState(() {
          _paymentMethods = ['Cash on Delivery', 'PayFast (Card)', 'Bank Transfer (EFT)'];
          _paymentMethodsLoaded = true;
          _deliveryFee = 15.0;
          _deliveryDistance = 5.0;
        });
        return;
      }
    
      final firstItem = cartSnapshot.docs.first.data();
      final ownerId = firstItem['sellerId'] ?? firstItem['ownerId'];
      if (ownerId == null) {
        print('🔍 DEBUG: No seller ID found in cart item');
        // Set default values and mark as loaded even without seller ID
        setState(() {
          _paymentMethods = ['Cash on Delivery', 'PayFast (Card)', 'Bank Transfer (EFT)'];
          _paymentMethodsLoaded = true;
          _deliveryFee = 15.0;
          _deliveryDistance = 5.0;
        });
        return;
      }
      
      print('🔍 DEBUG: Seller ID: $ownerId');
      
      final sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .get();
      
      if (!sellerDoc.exists) {
        print('🔍 DEBUG: Seller document does not exist');
        // Set default values and mark as loaded even without seller document
        setState(() {
          _paymentMethods = ['Cash on Delivery', 'PayFast (Card)', 'Bank Transfer (EFT)'];
          _paymentMethodsLoaded = true;
          _deliveryFee = 15.0;
          _deliveryDistance = 5.0;
        });
        return;
      }
      
      final seller = sellerDoc.data()!;
      _storeName = seller['storeName'] ?? 'Store';
      _storeOpen = seller['isStoreOpen'] ?? false;
      final storeLat = seller['latitude'];
      final storeLng = seller['longitude'];
      // Check seller's delivery fee preference
      _sellerDeliveryPreference = seller['deliveryFeePreference'] ?? 'custom'; // 'custom' or 'system'
      final deliveryFeePerKm = (seller['deliveryFeePerKm'] ?? 5.0).toDouble();
      
      print('🔍 DEBUG: Seller delivery preference: $_sellerDeliveryPreference');
      print('🔍 DEBUG: Raw deliveryFeePerKm from seller: ${seller['deliveryFeePerKm']}');
      print('🔍 DEBUG: Converted deliveryFeePerKm: $deliveryFeePerKm');
      _minOrderForDelivery = (seller['minOrderForDelivery'] ?? 0.0).toDouble();
      _deliveryTimeEstimate = seller['deliveryTimeEstimate'] ?? '';
      // Convert string time to hour integer
      final deliveryStartHourStr = seller['deliveryStartHour'] ?? '08:00';
      final deliveryEndHourStr = seller['deliveryEndHour'] ?? '17:00';
      
      _deliveryStartHour = int.tryParse(deliveryStartHourStr.split(':')[0]) ?? 8;
      _deliveryEndHour = int.tryParse(deliveryEndHourStr.split(':')[0]) ?? 17;
      _storeOpenHour = seller['storeOpenHour'] ?? '08:00';
      _storeCloseHour = seller['storeCloseHour'] ?? '18:00';
      
      // Debug operating hours loading
      print('🔍 DEBUG: Operating hours loaded:');
      print('  - storeOpenHour: $_storeOpenHour');
      print('  - storeCloseHour: $_storeCloseHour');
      print('  - seller storeOpenHour: ${seller['storeOpenHour']}');
      print('  - seller storeCloseHour: ${seller['storeCloseHour']}');
      _paymentMethods = List<String>.from(seller['paymentMethods'] ?? ['Cash on Delivery', 'PayFast']);
      _excludedZones = List<String>.from(seller['excludedZones'] ?? []);
      
      // Get seller service availability
      _sellerPargoEnabled = seller['pargoEnabled'] ?? false;
      _sellerPaxiEnabled = seller['paxiEnabled'] ?? false;
      
      // Handle PAXI delivery speed pricing if PAXI is enabled
      if (_sellerPaxiEnabled && _selectedPaxiDeliverySpeed != null) {
        final paxiPricing = PaxiConfig.getAllOptions();
        final selectedOption = paxiPricing.firstWhere(
          (option) => option['deliverySpeed'] == _selectedPaxiDeliverySpeed,
          orElse: () => paxiPricing.first,
        );
        
        // Update delivery fee based on PAXI speed selection
        if (_selectedPaxiDeliverySpeed == 'express') {
          _deliveryFee = selectedOption['price'].toDouble();
          print('🚀 PAXI Express delivery selected: R${_deliveryFee?.toStringAsFixed(2)}');
        } else {
          _deliveryFee = selectedOption['price'].toDouble();
          print('🚀 PAXI Standard delivery selected: R${_deliveryFee?.toStringAsFixed(2)}');
        }
      }
      
      // Debug payment methods loading
      print('🔍 DEBUG: Payment methods loaded: $_paymentMethods');
      print('🔍 DEBUG: Seller data: ${seller['paymentMethods']}');
      print('🔍 DEBUG: Payment methods count: ${_paymentMethods.length}');
      print('🔍 DEBUG: Seller Pargo enabled: $_sellerPargoEnabled');
      print('🔍 DEBUG: Seller PAXI enabled: $_sellerPaxiEnabled');
      
      if (storeLat == null || storeLng == null) {
        print('🔍 DEBUG: Store location not available, using default delivery fee');
        _deliveryFee = 15.0; // Default delivery fee
        _deliveryDistance = 5.0; // Default distance
        setState(() {});
          return;
      }
      
      print('🔍 DEBUG: Store location - Lat: $storeLat, Lng: $storeLng');
      
      // Get user location and calculate delivery
      try {
        Position userPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        print('🔍 DEBUG: User location - Lat: ${userPos.latitude}, Lng: ${userPos.longitude}');
        
        _deliveryDistance = Geolocator.distanceBetween(
          userPos.latitude, userPos.longitude, storeLat, storeLng,
        ) / 1000;
        
        // Calculate delivery fee based on seller preference
        if (_sellerDeliveryPreference == 'system') {
          // Use system delivery model with South African rates
          final optimalModel = _getOptimalDeliveryModel(_deliveryDistance, _productCategory);
          _deliveryFee = _calculateSystemDeliveryFee(_deliveryDistance, optimalModel);
          
          print('🔍 DEBUG: System delivery model calculation:');
          print('  - Optimal model: $optimalModel');
          print('  - Distance: ${(_deliveryDistance ?? 0.0).toStringAsFixed(2)} km');
          print('  - Product category: $_productCategory');
          print('  - System fee: R${(_deliveryFee ?? 0.0).toStringAsFixed(2)}');
        } else {
          // Use seller's custom delivery fee with validation
          double customFee = _deliveryDistance * deliveryFeePerKm;
          
          // Validate custom fee against South African market rates
          final fallbackFee = _calculateFallbackDeliveryFee(_deliveryDistance);
          if (customFee < fallbackFee * 0.5) {
            // If custom fee is too low, use fallback as minimum
            customFee = fallbackFee * 0.8; // 80% of fallback fee
            print('🔍 DEBUG: Custom fee too low, adjusted to market minimum');
          } else if (customFee > fallbackFee * 2.0) {
            // If custom fee is too high, cap it
            customFee = fallbackFee * 1.5; // 150% of fallback fee
            print('🔍 DEBUG: Custom fee too high, capped to market maximum');
          }
          
          _deliveryFee = customFee;
          
          print('🔍 DEBUG: Custom delivery fee calculation:');
          print('  - Fee per km: R${deliveryFeePerKm.toStringAsFixed(2)}');
          print('  - Raw fee: R${(_deliveryDistance * deliveryFeePerKm).toStringAsFixed(2)}');
          print('  - Market fallback: R${fallbackFee.toStringAsFixed(2)}');
          print('  - Final fee: R${(_deliveryFee ?? 0.0).toStringAsFixed(2)}');
        }
        
        print('🔍 DEBUG: Delivery calculation:');
        print('  - Distance: ${_deliveryDistance.toStringAsFixed(2)} km');
        print('  - Seller preference: $_sellerDeliveryPreference');
        print('  - Delivery fee: R${(_deliveryFee ?? 0.0).toStringAsFixed(2)}');
        print('  - Is delivery: $_isDelivery');
    } catch (e) {
        print('🔍 DEBUG: Error getting user location: $e');
        print('🔍 DEBUG: Using default delivery fee due to location error');
        _deliveryFee = 15.0; // Default delivery fee
        _deliveryDistance = 5.0; // Default distance
      }
      
      // Ensure delivery fee is always set for delivery mode
      if (_isDelivery && (_deliveryFee == null || _deliveryFee == 0.0)) {
        print('🔍 DEBUG: Delivery fee is null or zero, setting default');
        _deliveryFee = 15.0;
        _deliveryDistance = 5.0;
      }
      
      // Check if this is a rural area and calculate rural delivery options
      _isRuralArea = RuralDeliveryService.isRuralArea(_deliveryDistance);
      
      if (_isRuralArea) {
        // Calculate rural delivery fee
        final ruralPricing = RuralDeliveryService.calculateRuralDeliveryFee(
          distance: _deliveryDistance,
          storeId: ownerId,
        );
        _ruralDeliveryFee = ruralPricing['finalFee'].toDouble();
        
        // Use rural delivery fee if it's better than standard fee
        if (_ruralDeliveryFee < (_deliveryFee ?? 0.0)) {
          _deliveryFee = _ruralDeliveryFee;
        }
        
        print('🔍 DEBUG: Rural delivery calculation:');
        print('  - Is rural area: $_isRuralArea');
        print('  - Rural delivery fee: R${_ruralDeliveryFee.toStringAsFixed(2)}');
        print('  - Zone: ${ruralPricing['zoneName']}');
      }
      
      // Check if this is an urban area and calculate urban delivery options
      try {
        Position userPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        _isUrbanArea = UrbanDeliveryService.isUrbanDeliveryZone(
          userPos.latitude, 
          userPos.longitude,
        );
        
        if (_isUrbanArea) {
          // Calculate urban delivery fee
          final urbanPricing = UrbanDeliveryService.calculateUrbanDeliveryFee(
            latitude: userPos.latitude,
            longitude: userPos.longitude,
            category: _productCategory,
            distance: _deliveryDistance,
            deliveryTime: DateTime.now(),
          );
          
          if (urbanPricing['isUrbanDelivery'] == true) {
            _urbanDeliveryFee = urbanPricing['fee'].toDouble();
            
            // Use urban delivery fee if it's better than standard fee
            if (_urbanDeliveryFee < (_deliveryFee ?? 0.0)) {
              _deliveryFee = _urbanDeliveryFee;
            }
            
            print('🔍 DEBUG: Urban delivery calculation:');
            print('  - Is urban area: $_isUrbanArea');
            print('  - Urban delivery fee: R${_urbanDeliveryFee.toStringAsFixed(2)}');
            print('  - Zone: ${urbanPricing['zoneName']}');
            print('  - Category: $_productCategory');
          }
        }
      } catch (e) {
        print('🔍 DEBUG: Error checking urban delivery: $e');
      }
      
      // Calculate realistic delivery time
      _deliveryTimeMinutes = _calculateRealisticDeliveryTime(
        distance: _deliveryDistance,
        basePrepTime: seller['preparationTimeMinutes'] ?? 15,
        currentTime: DateTime.now(),
      );
      
      await _fetchPlatformFeeConfigAndExemption(ownerId);
      
      // Ensure UI updates with new delivery fee
      setState(() {});
      print('🔍 DEBUG: Delivery fee calculation completed');
    } finally {
        setState(() {
        _paymentMethodsLoaded = true;
      });
    }
  }

  int _calculateRealisticDeliveryTime({
    required double distance,
    required int basePrepTime,
    required DateTime currentTime,
  }) {
    // Base preparation time
    int totalMinutes = basePrepTime;
    
    // Add travel time (25 km/h average city speed)
    double travelHours = distance / 25.0;
    int travelMinutes = (travelHours * 60).round();
    totalMinutes += travelMinutes;
    
    // Factor in time of day
    int hour = currentTime.hour;
    if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
      totalMinutes = (totalMinutes * 1.5).round(); // Rush hour
    } else if (hour >= 22 || hour <= 6) {
      totalMinutes = (totalMinutes * 0.8).round(); // Off-peak
    }
    
    // Factor in day of week
    int weekday = currentTime.weekday;
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      totalMinutes = (totalMinutes * 1.2).round(); // Weekend
    }
    
    // Add buffer time
    totalMinutes += 5;
    
    // Round to nearest 5 minutes
    totalMinutes = ((totalMinutes / 5).round() * 5);
    
    return totalMinutes.clamp(20, 120);
  }

  void _onRuralDeliveryOptionSelected(String deliveryType, double fee) {
      setState(() {
      _selectedRuralDeliveryType = deliveryType;
      _ruralDeliveryFee = fee;
      _deliveryFee = fee; // Update the main delivery fee
    });
    
    print('🔍 DEBUG: Rural delivery option selected:');
    print('  - Type: $deliveryType');
    print('  - Fee: R${fee.toStringAsFixed(2)}');
  }
  
  void _onUrbanDeliveryOptionSelected(String deliveryType, double fee) {
      setState(() {
      _selectedUrbanDeliveryType = deliveryType;
      _urbanDeliveryFee = fee;
      _deliveryFee = fee; // Update the main delivery fee
    });
    
    print('🔍 DEBUG: Urban delivery option selected:');
    print('  - Type: $deliveryType');
    print('  - Fee: R${fee.toStringAsFixed(2)}');
  }

  Future<void> _fetchPlatformFeeConfigAndExemption(String sellerId) async {
    try {
      final configDoc = await FirebaseFirestore.instance
          .collection('config')
          .doc('platform')
          .get();
      final configData = configDoc.data();
      if (configData != null && configData['platformFee'] != null) {
        _platformFeePercent = (configData['platformFee'] as num).toDouble();
      } else {
        _platformFeePercent = 5.0;
      }
    } catch (_) {
      _platformFeePercent = 5.0;
    }

    try {
      final sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .get();
      final sellerData = sellerDoc.data();
      if (sellerData != null && sellerData['platformFeeExempt'] == true) {
        _isStoreFeeExempt = true;
      } else {
        _isStoreFeeExempt = false;
      }
    } catch (_) {}
  }

  bool _isStoreCurrentlyOpen() {
    if (_storeOpenHour == null || _storeCloseHour == null) {
      return _storeOpen ?? false; // Fallback to manual store open status
    }
    
    try {
      final now = DateTime.now();
      final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);
      
      // Parse store hours
      final openParts = _storeOpenHour!.split(':');
      final closeParts = _storeCloseHour!.split(':');
      
      if (openParts.length != 2 || closeParts.length != 2) {
        return _storeOpen ?? false; // Fallback if time format is invalid
      }
      
      final openHour = int.parse(openParts[0]);
      final openMinute = int.parse(openParts[1]);
      final closeHour = int.parse(closeParts[0]);
      final closeMinute = int.parse(closeParts[1]);
      
      final openTime = TimeOfDay(hour: openHour, minute: openMinute);
      final closeTime = TimeOfDay(hour: closeHour, minute: closeMinute);
      
      // Convert to minutes for easier comparison
      final currentMinutes = currentTime.hour * 60 + currentTime.minute;
      final openMinutes = openTime.hour * 60 + openTime.minute;
      final closeMinutes = closeTime.hour * 60 + closeTime.minute;
      
      // Handle cases where store is open past midnight
      if (closeMinutes < openMinutes) {
        // Store closes after midnight
        return currentMinutes >= openMinutes || currentMinutes <= closeMinutes;
      } else {
        // Store closes on the same day
        return currentMinutes >= openMinutes && currentMinutes <= closeMinutes;
      }
    } catch (e) {
      print('🔍 DEBUG: Error checking store hours: $e');
      return _storeOpen ?? false; // Fallback to manual store open status
    }
  }


  Future<void> _submitOrder() async {
    if (_isLoading || _orderCompleted) return; // Prevent multiple submissions
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method')),
      );
        return;
      }
      
    print('🔍 DEBUG: _submitOrder called with payment method: $_selectedPaymentMethod');

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to place an order')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
        return;
      }
      
    // Log checkout event
    FirebaseAnalytics.instance.logEvent(
      name: 'checkout',
      parameters: {'totalPrice': widget.totalPrice},
    );

    // Validate order before payment
    print('🔍 DEBUG: Validating order before payment...');
    if (!await _validateOrderBeforePayment()) {
      print('🔍 DEBUG: Order validation failed');
      return;
    }
    print('🔍 DEBUG: Order validation passed');

    // Handle different payment methods
    final pm = _selectedPaymentMethod!.toLowerCase();
    if (pm.contains('eft')) {
      await _processBankTransferEFT();
    } else if (pm.contains('payfast') || pm.contains('card')) {
      await _processPayFastPayment();
    } else if (pm.contains('cash')) {
      await _processCashOnDelivery();
    } else {
      await _completeOrder();
    }
  }

  Future<void> _processBankTransferEFT() async {
    // Create order with awaiting_payment status, then show bank details dialog
    final orderNumber = await _completeOrder(paymentStatusOverride: 'awaiting_payment');
    if (!mounted) return;
    _showBankDetailsDialog(orderNumber: orderNumber);
  }

  Future<void> _processCashOnDelivery() async {
    await _completeOrder(paymentStatusOverride: 'pending');
  }

  void _showBankDetailsDialog({String? orderNumber}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: BoxConstraints(maxWidth: 400),
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.angel,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.deepTeal.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.deepTeal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.account_balance, color: AppTheme.deepTeal, size: 20),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bank Transfer Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepTeal,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: AppTheme.breeze),
                      constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
                
                SizedBox(height: 20),
                
                // Bank Details
                _buildSimpleBankRow('Account Name', 'Food Marketplace Pty Ltd'),
                _buildSimpleBankRow('Bank', 'First National Bank'),
                _buildSimpleBankRow('Account Number', '62612345678'),
                _buildSimpleBankRow('Branch Code', '250655'),
                _buildSimpleBankRow('Reference', orderNumber ?? 'Your Order Number'),
                
                SizedBox(height: 20),
                
                // Instructions
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.whisper,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '💡 Use your order number as reference when making the transfer. Payment confirmation takes 1-2 business days.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.deepTeal,
                      height: 1.4,
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final details = 'Food Marketplace Pty Ltd\nFNB: 62612345678\nBranch: 250655\nRef: ${orderNumber ?? 'Order Number'}';
                          Clipboard.setData(ClipboardData(text: details));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Bank details copied!'),
                              backgroundColor: AppTheme.deepTeal,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: Icon(Icons.copy, size: 16),
                        label: Text('Copy'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.deepTeal,
                          side: BorderSide(color: AppTheme.deepTeal),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Done'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.deepTeal,
                          foregroundColor: AppTheme.angel,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuperReadableBankDetail(String label, String value, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.whisper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.deepTeal.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.deepTeal, size: 20),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.breeze,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.deepTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy, color: AppTheme.deepTeal),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Copied to clipboard')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuperReadableInstruction(String instruction) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 2),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.warning,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              instruction,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.deepTeal,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bankRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: TextStyle(color: AppTheme.breeze))),
          Expanded(
            child: Row(
              children: [
                Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => Clipboard.setData(ClipboardData(text: value)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // Enhanced bank row with better styling
  Widget _buildEnhancedBankRow(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.whisper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.deepTeal.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.deepTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.deepTeal.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: AppTheme.deepTeal,
              size: 18,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeUI.safeText(
                  label,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                    color: AppTheme.breeze,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 4),
                SafeUI.safeText(
                  value,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                    color: AppTheme.deepTeal,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          // Copy button
          Container(
            decoration: BoxDecoration(
              color: AppTheme.deepTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.deepTeal.withOpacity(0.3),
              ),
            ),
            child: IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.copy, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$label copied to clipboard!',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppTheme.success,
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              },
              icon: Icon(
                Icons.copy,
                color: AppTheme.deepTeal,
                size: 18,
              ),
              padding: EdgeInsets.all(8),
              constraints: BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Clean bank detail for simplified EFT modal
  Widget _buildCleanBankDetail(String label, String value) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeUI.safeText(
            label,
            style: TextStyle(
              fontSize: ResponsiveUtils.getTitleSize(context) - 2,
              color: AppTheme.breeze,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SafeUI.safeText(
                  value,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context) + 1,
                    color: AppTheme.deepTeal,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.deepTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label copied to clipboard!'),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: Icon(Icons.copy, color: AppTheme.deepTeal, size: 20),
                  padding: EdgeInsets.all(8),
                  constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ),
            ],
          ),
          Divider(
            color: AppTheme.deepTeal.withOpacity(0.2),
            height: 24,
            thickness: 1,
          ),
        ],
      ),
    );
  }

  // Clean instruction for simplified EFT modal
  Widget _buildCleanInstruction(String instruction) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppTheme.warning,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: SafeUI.safeText(
              instruction,
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context) - 1,
                color: AppTheme.deepTeal,
                fontWeight: FontWeight.w600,
                height: 1.4,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Simple bank row for simplified EFT modal
  Widget _buildSimpleBankRow(String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.whisper,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.breeze,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.deepTeal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copied!'),
                  backgroundColor: AppTheme.deepTeal,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy, color: AppTheme.breeze, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  // Simple instruction row for simplified EFT modal
  Widget _buildSimpleInstructionRow(String instruction) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppTheme.warning,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: SafeUI.safeText(
              instruction,
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context) - 3,
                color: AppTheme.deepTeal,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Instruction row for EFT modal
  Widget _buildInstructionRow(String instruction) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppTheme.warning,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: SafeUI.safeText(
              instruction,
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context) - 3,
                color: AppTheme.deepTeal,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _validateOrderBeforePayment() async {
    try {
      // Check delivery zones
    if (_excludedZones.isNotEmpty) {
      final address = _addressController.text.toLowerCase();
      final blocked = _excludedZones.any((zone) => address.contains(zone.toLowerCase()));
      if (blocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Delivery is not available to your address')),
        );
          return false;
      }
    }

      // Check minimum order
    if (_minOrderForDelivery != null && widget.totalPrice < _minOrderForDelivery!) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Minimum order for delivery is R${_minOrderForDelivery!.toStringAsFixed(2)}')),
      );
        return false;
      }

      // Check PAXI delivery speed selection if PAXI is selected
      if (_selectedServiceFilter == 'paxi' && _selectedPaxiDeliverySpeed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a PAXI delivery speed')),
        );
        return false;
      }
      
      // Check cart and stock
      final cartSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('cart')
          .get();
      
      if (cartSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your cart is empty')),
        );
        return false;
      }

      // Stock check
      for (final doc in cartSnapshot.docs) {
        final item = doc.data();
        final productId = item['id'] ?? item['productId'];
        if (productId == null) continue;
        
        final productDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .get();
        
        if (!productDoc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Product not found: ${item['name'] ?? productId}')),
          );
          return false;
        }
        
        final product = productDoc.data()!;
        final stock = product['stock'] ?? 999999;
        final quantity = item['quantity'] ?? 1;
        
        if (quantity > stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Not enough stock for ${item['name'] ?? 'an item'}')),
          );
          return false;
        }
      }

      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error validating order: ${e.toString()}')),
      );
      return false;
    }
  }

  Future<void> _processPayFastPayment() async {
    setState(() => _isLoading = true);

    try {
      // Generate order info
      final now = DateTime.now();
      final orderNumber = 'ORD-${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}-${currentUser!.uid.substring(0, 3).toUpperCase()}';
      final totalAmount = widget.totalPrice + (_isDelivery ? (_deliveryFee ?? 0.0) : 0.0);

      // Generate PayFast URL
      final paymentUrl = _generatePayFastUrl(
        orderId: orderNumber,
        amount: totalAmount,
        buyerEmail: currentUser!.email ?? 'test@example.com',
        buyerName: _nameController.text.trim().isNotEmpty 
            ? _nameController.text.trim() 
            : 'Customer',
      );

      setState(() => _isLoading = false);

      // Show payment confirmation
      final shouldProceed = await _showPaymentConfirmationDialog(totalAmount);
      if (!shouldProceed) return;

      // Launch PayFast
      await _launchPayFastPayment(paymentUrl, orderNumber);

    } catch (e) {
      setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment setup failed: ${e.toString()}')),
      );
    }
  }

  String _generatePayFastUrl({
    required String orderId,
    required double amount,
    required String buyerEmail,
    required String buyerName,
  }) {
    final params = {
      'merchant_id': payfastMerchantId,
      'merchant_key': payfastMerchantKey,
      'return_url': payfastReturnUrl,
      'cancel_url': payfastCancelUrl,
      'notify_url': payfastNotifyUrl,
      'amount': amount.toStringAsFixed(2),
      'item_name': 'Food Order $orderId',
      'name_first': buyerName.split(' ').first,
      'name_last': buyerName.split(' ').length > 1 ? buyerName.split(' ').last : '',
      'email_address': buyerEmail,
      'm_payment_id': orderId,
      'custom_str1': orderId,
      'custom_str2': currentUser!.uid,
    };
    
    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    
    // Use sandbox for development
    if (payfastSandbox) {
      return 'https://sandbox.payfast.co.za/eng/process?$query';
      } else {
      return 'https://www.payfast.co.za/eng/process?$query';
    }
  }

  Future<bool> _showPaymentConfirmationDialog(double totalAmount) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryButtonGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.payment,
                  color: AppTheme.angel,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              SafeUI.safeText(
                'Confirm Payment',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getTitleSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepTeal,
                ),
                maxLines: 1,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeUI.safeText(
                'You will be redirected to PayFast to complete your payment.',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                  color: AppTheme.breeze,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.whisper, AppTheme.angel],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.breeze.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    SafeUI.safeText(
                      'Total Amount:',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getTitleSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.deepTeal,
                      ),
                      maxLines: 1,
                    ),
                    SafeUI.safeText(
                      'R${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getTitleSize(context) + 2,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepTeal,
                      ),
                      maxLines: 1,
                  ),
                ],
              ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: SafeUI.safeText(
                'Cancel',
                style: TextStyle(color: AppTheme.breeze),
                maxLines: 1,
              ),
            ),
              Container(
                decoration: BoxDecoration(
                gradient: AppTheme.primaryButtonGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: SafeUI.safeText(
                  'Continue to Payment',
                  style: TextStyle(
                    color: AppTheme.angel,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<void> _launchPayFastPayment(String paymentUrl, String orderNumber) async {
    try {
      final uri = Uri.parse(paymentUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        // Show return dialog
        if (mounted) {
          _showPaymentReturnDialog(orderNumber);
        }
      } else {
        throw 'Could not launch PayFast payment URL';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open payment gateway: ${e.toString()}')),
      );
    }
  }

  void _showPaymentReturnDialog(String orderNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.payment, color: AppTheme.deepTeal),
              const SizedBox(width: 8),
              SafeUI.safeText(
                'Payment Status',
                style: TextStyle(
                  color: AppTheme.deepTeal,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
              ),
            ],
          ),
          content: SafeUI.safeText(
            'Did you complete the payment successfully?',
            style: TextStyle(
              fontSize: ResponsiveUtils.getTitleSize(context) - 2,
              color: AppTheme.breeze,
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Payment cancelled - stay on checkout screen
              },
              child: SafeUI.safeText(
                'Payment Failed',
                style: TextStyle(color: AppTheme.warmAccentColor),
                maxLines: 1,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryButtonGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Payment successful - complete the order
                  _completeOrder();
                },
                child: SafeUI.safeText(
                  'Payment Success',
                  style: TextStyle(
                    color: AppTheme.angel,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _completeOrder({String? paymentStatusOverride}) async {
    // Prevent duplicate orders
    if (_orderCompleted) {
      print('🔍 DEBUG: Order already completed, preventing duplicate');
      return null;
    }
    
    // Check if store is currently open
    if (!_isStoreCurrentlyOpen()) {
      print('🔍 DEBUG: Store is currently closed');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sorry, ${_storeName ?? 'the store'} is currently closed. Please try again during business hours.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return null;
    }
    
    print('🔍 DEBUG: Starting _completeOrder for payment method: $_selectedPaymentMethod');
    setState(() => _isLoading = true);
    
    String? orderNumber;

    try {
      // Fetch cart items
      final cartSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('cart')
          .get();
      
      print('🔍 DEBUG: Cart items found: ${cartSnapshot.docs.length}');
      final cartItems = cartSnapshot.docs.map((doc) => doc.data()).toList();
      
      var sellerId = cartItems.first['sellerId'] ?? cartItems.first['ownerId'] ?? '';
      if (sellerId.isEmpty && cartItems.first['productId'] != null) {
        final productDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(cartItems.first['productId'])
          .get();
        sellerId = productDoc.data()?['ownerId'] ?? productDoc.data()?['sellerId'] ?? '';
      }
      
      print('🔍 DEBUG: Seller ID: $sellerId');

      // Generate order number
      final now = DateTime.now();
      final orderNumber = 'ORD-${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}-${currentUser!.uid.substring(0, 3).toUpperCase()}';
      
      print('🔍 DEBUG: Order number: $orderNumber');

      final pf = _platformFeePercent ?? 0.0;

      print('🔍 DEBUG: Creating order in Firestore...');
      
      // Log pickup point details if this is a pickup order
      if (!_isDelivery && _selectedPickupPoint != null) {
        print('🚚 DEBUG: Adding pickup point details to order:');
        print('  - Pickup Point: ${_selectedPickupPoint!.name}');
        print('  - Address: ${_selectedPickupPoint!.address}');
        print('  - Type: ${_selectedPickupPoint!.isPargoPoint ? "Pargo" : _selectedPickupPoint!.isPaxiPoint ? "PAXI" : "Local Store"}');
        print('  - Operating Hours: ${_selectedPickupPoint!.operatingHours}');
        print('  - Fee: R${_selectedPickupPoint!.fee}');
        print('  - Distance: ${_selectedPickupPoint!.distance.toStringAsFixed(2)} km');
      }
      
      final orderRef = await FirebaseFirestore.instance.collection('orders').add({
        'orderNumber': orderNumber,
        'buyerId': currentUser!.uid,
        'sellerId': sellerId,
        'items': cartItems,
        'totalPrice': widget.totalPrice,
        'orderType': _isDelivery ? 'delivery' : 'pickup',
        'deliveryFee': _isDelivery ? (_deliveryFee ?? 0.0) : 0.0,
        'deliveryDistance': _deliveryDistance,
        'isRuralArea': _isRuralArea,
        'ruralDeliveryType': _selectedRuralDeliveryType,
        'ruralDeliveryFee': _isRuralArea ? _ruralDeliveryFee : 0.0,
        'isUrbanArea': _isUrbanArea,
        'urbanDeliveryType': _selectedUrbanDeliveryType,
        'urbanDeliveryFee': _isUrbanArea ? _urbanDeliveryFee : 0.0,
        'deliveryModelPreference': _sellerDeliveryPreference ?? 'custom',
        'systemDeliveryModelType': _sellerDeliveryPreference == 'system' ? (_sellerDeliveryPreference == 'system' ? 'standard' : null) : null,
        'productCategory': _productCategory,
        'timestamp': FieldValue.serverTimestamp(),
        'name': _nameController.text.trim(),
        'buyerName': _nameController.text.trim(), // Add buyerName field for consistency
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'deliveryInstructions': _deliveryInstructionsController.text.trim(),
        'status': 'pending',
        'paymentMethod': _selectedPaymentMethod,
        'paymentStatus': paymentStatusOverride ?? (_selectedPaymentMethod?.toLowerCase().contains('cash') == true ? 'pending' : 'paid'),
        'platformFee': (!_isStoreFeeExempt) ? (widget.totalPrice * pf / 100) : 0.0,
        'platformFeePercent': pf,
        'platformFeeExempt': _isStoreFeeExempt,
        'sellerPayout': widget.totalPrice - ((!_isStoreFeeExempt) ? (widget.totalPrice * pf / 100) : 0.0),
        
        // 🚚 PAXI DELIVERY SPEED INFORMATION (for all orders)
        'paxiDeliverySpeed': _selectedPaxiDeliverySpeed,
        'paxiDeliverySpeedName': _selectedPaxiDeliverySpeed != null 
            ? (_selectedPaxiDeliverySpeed == 'express' ? 'Express (3-5 Business Days)' : 'Standard (7-9 Business Days)')
            : null,
        
        // 🚚 PICKUP POINT DETAILS (for pickup orders)
        ...(_isDelivery ? {} : {
          'pickupPointId': _selectedPickupPoint?.id,
          'pickupPointName': _selectedPickupPoint?.name,
          'pickupPointAddress': _selectedPickupPoint?.address,
          'pickupPointType': _selectedPickupPoint?.isPargoPoint == true ? 'pargo' : 
                          _selectedPickupPoint?.isPaxiPoint == true ? 'paxi' : 'local_store',
          'pickupPointOperatingHours': _selectedPickupPoint?.operatingHours,
          'pickupPointCategory': _selectedPickupPoint?.type,
          'pickupPointPargoId': _selectedPickupPoint?.pargoId,
          'pickupPointCoordinates': _selectedPickupPoint != null ? {
            'latitude': _selectedPickupPoint!.latitude,
            'longitude': _selectedPickupPoint!.longitude,
          } : null,
          'pickupInstructions': _selectedPickupPoint?.isPargoPoint == true 
              ? (_productCategory == 'mixed' 
                  ? '📦 Collect NON-FOOD items from Pargo counter with ID verification. Food items must be collected from restaurant.'
                  : '📦 Collect from Pargo counter with ID verification. Bring your order number and ID.')
              : _selectedPickupPoint?.isPaxiPoint == true
              ? (_productCategory == 'mixed'
                  ? '📦 Collect NON-FOOD items from PAXI counter with ID verification. Food items must be collected from restaurant.'
                  : '📦 Collect from PAXI counter with ID verification. Bring your order number and ID.')
              : '🏪 Collect from store counter. Bring your order number.',
          'pickupPointFee': _selectedPickupPoint?.fee ?? 0.0,
          'pickupPointDistance': _selectedPickupPoint?.distance ?? 0.0,
          'pickupPointSummary': _selectedPickupPoint != null 
              ? '${_selectedPickupPoint!.isPargoPoint ? "🚚 Pargo" : _selectedPickupPoint!.isPaxiPoint ? "📦 PAXI" : "🏪 Local Store"}: ${_selectedPickupPoint!.name} - ${_selectedPickupPoint!.address}'
              : null,
          
          // PAXI delivery speed information
          'paxiDeliverySpeed': _selectedPickupPoint?.isPaxiPoint == true ? _selectedPaxiDeliverySpeed : null,
          'paxiDeliverySpeedName': _selectedPickupPoint?.isPaxiPoint == true && _selectedPaxiDeliverySpeed != null 
              ? (_selectedPaxiDeliverySpeed == 'express' ? 'Express (3-5 Business Days)' : 'Standard (7-9 Business Days)')
              : null,
          
          // Mixed cart handling
          'isMixedCart': _productCategory == 'mixed',
          'hasFoodItems': _hasFoodItems,
          'hasNonFoodItems': _hasNonFoodItems,
          'foodItemsCount': _foodItems.length,
          'nonFoodItemsCount': _nonFoodItems.length,
        }),
        
        'trackingUpdates': [
          {
            'description': 'Order placed successfully',
            'timestamp': Timestamp.now(),
            'status': 'pending'
          }
        ],
      });

      print('🔍 DEBUG: Order created successfully with ID: ${orderRef.id}');

                     // **AUTOMATED DRIVER ASSIGNMENT**
               Map<String, dynamic>? assignedDriver;
               if (_isDelivery && (_isRuralArea || _isUrbanArea)) {
                 try {
                   print('🔍 DEBUG: Starting automated driver assignment...');
                   
                   // Get seller location (in real app, get from seller data)
                   final sellerLat = -26.1076; // Demo coordinates
                   final sellerLng = 28.0567;
                   
                   // Get delivery location from order (in real app, get from user's location)
                   final deliveryLat = -26.1076; // Demo coordinates - replace with actual user location
                   final deliveryLng = 28.0567;
                   
                   // Determine delivery type and category
                   String deliveryType = 'pickup';
                   if (_isRuralArea) {
                     deliveryType = 'rural';
                   } else if (_isUrbanArea) {
                     deliveryType = 'urban';
                   }
                   
                   // Assign driver to order
                   assignedDriver = await DeliveryFulfillmentService.assignDriverToOrder(
                     orderId: orderRef.id,
                     sellerId: sellerId,
                     pickupLatitude: sellerLat,
                     pickupLongitude: sellerLng,
                     deliveryLatitude: deliveryLat,
                     deliveryLongitude: deliveryLng,
                     deliveryType: deliveryType,
                     category: _productCategory,
                   );
                   
                   if (assignedDriver != null) {
                     print('🔍 DEBUG: Driver ${assignedDriver['name']} assigned to order');
                     
                     // Update order with driver assignment
                     await orderRef.update({
                       'driverAssigned': true,
                       'assignedDriverId': assignedDriver['driverId'],
                     });
                   } else {
                     print('🔍 DEBUG: No driver available, order will be manually assigned');
                   }
                 } catch (e) {
                   print('🔍 DEBUG: Error in automated driver assignment: $e');
                 }
               }

               // Update notification message if driver was assigned
               String notificationMessage = 'Your order has been placed and is being processed. Track your order to see real-time updates.';
               if (assignedDriver != null) {
                 notificationMessage = '🚚 Driver ${assignedDriver['name']} has been assigned to your order! Track your order to see real-time updates.';
               }

      // Log purchase event
      FirebaseAnalytics.instance.logEvent(
        name: 'purchase',
        parameters: {'totalPrice': widget.totalPrice, 'sellerId': sellerId},
      );

      // Clear cart from Firestore
      for (var doc in cartSnapshot.docs) {
        await doc.reference.delete();
      }

      // Clear local cart provider
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.clearCart();

      _orderCompleted = true; // Mark order as completed
      setState(() => _isLoading = false);

      if (!mounted) return orderNumber;

      // Show popup notification with driver information
      
      NotificationService.showPopupNotification(
        title: 'Order Placed Successfully! 🎉',
        message: notificationMessage,
        onTap: () {
          // Navigate to order tracking
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OrderTrackingScreen(orderId: orderRef.id),
            ),
          );
        },
      );

      // Send notifications
      await _sendOrderNotifications(sellerId, orderRef.id, orderNumber);

      // Navigate to tracking
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: orderRef.id),
        ),
      );
    } catch (e) {
      _orderCompleted = false; // Reset on error
      setState(() => _isLoading = false);
      debugPrint('Checkout error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place order. Please try again.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _submitOrder,
          ),
        ),
      );
    }
    
    return orderNumber;
  }

  Future<void> _sendOrderNotifications(String sellerId, String orderId, String orderNumber) async {
    try {
      // Get buyer name for the notification
      String buyerName = 'Customer';
      try {
        final buyerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();
        final buyerData = buyerDoc.data();
        if (buyerData != null) {
          buyerName = buyerData['name'] ?? buyerData['email'] ?? 'Customer';
        }
      } catch (e) {
        debugPrint('Error getting buyer name: $e');
      }

      // Get seller name for buyer notification
      String sellerName = 'Store';
      try {
        final sellerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(sellerId)
            .get();
        final sellerData = sellerDoc.data();
        if (sellerData != null) {
          sellerName = sellerData['storeName'] ?? sellerData['name'] ?? 'Store';
        }
      } catch (e) {
        debugPrint('Error getting seller name: $e');
      }

      // Send notification to seller (new order received)
      print('🔔 Attempting to send seller notification...');
      await NotificationService().sendNewOrderNotificationToSeller(
        sellerId: sellerId,
        orderId: orderId,
        buyerName: buyerName,
        orderTotal: widget.totalPrice,
        sellerName: sellerName,
      );
      
      // Send notification to buyer (order placed)
      print('🔔 Attempting to send buyer notification...');
      await NotificationService().sendOrderStatusNotificationToBuyer(
        buyerId: currentUser!.uid,
        orderId: orderId,
        status: 'pending',
        sellerName: sellerName,
      );
      
      // Test notification to verify system is working
      print('🔔 Sending test notification...');
      await NotificationService().testNotification();
      
      print('✅ Order notifications sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending order notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_paymentMethodsLoaded) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.deepTeal,
          foregroundColor: AppTheme.angel,
          elevation: 0,
          centerTitle: false,
          title: SafeUI.safeText(
            'Checkout',
            style: TextStyle(
              fontSize: ResponsiveUtils.getTitleSize(context),
              fontWeight: FontWeight.w600,
              color: AppTheme.angel,
            ),
            maxLines: 1,
          ),
          actions: [
            HomeNavigationButton(
              backgroundColor: AppTheme.deepTeal,
              iconColor: AppTheme.angel,
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Container(
                  decoration: BoxDecoration(
            gradient: AppTheme.screenBackgroundGradient,
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    // Compute fee (delivery or pickup) and grand total
    final bool isPickup = !_isDelivery;
    double pickupFee = 0.0;
    if (isPickup && _selectedPickupPoint != null) {
      if (_selectedPickupPoint!.isPaxiPoint && _selectedPaxiDeliverySpeed != null) {
        pickupFee = PaxiConfig.getPrice(_selectedPaxiDeliverySpeed!);
      } else {
        pickupFee = _selectedPickupPoint!.fee;
      }
    }
    final double deliveryFeeFinal = _isDelivery ? (_deliveryFee ?? 15.0) : 0.0;
    final double appliedFee = _isDelivery ? deliveryFeeFinal : pickupFee;
    final grandTotal = widget.totalPrice + appliedFee;

    // Debug logging for total calculation
    print('🔍 DEBUG: Total calculation:');
    print('  - Subtotal: R${widget.totalPrice.toStringAsFixed(2)}');
    print('  - Is delivery: $_isDelivery');
    print('  - Raw _deliveryFee state: R${(_deliveryFee ?? 0.0).toStringAsFixed(2)}');
    print('  - Computed pickup fee: R${pickupFee.toStringAsFixed(2)}');
    print('  - Applied fee: R${appliedFee.toStringAsFixed(2)}');
    print('  - Grand total: R${grandTotal.toStringAsFixed(2)}');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: AppTheme.angel,
        elevation: 0,
        centerTitle: false,
        title: SafeUI.safeText(
          'Checkout',
          style: TextStyle(
            fontSize: ResponsiveUtils.getTitleSize(context),
                              fontWeight: FontWeight.w600,
            color: AppTheme.angel,
          ),
          maxLines: 1,
        ),
        actions: [
          HomeNavigationButton(
            backgroundColor: AppTheme.deepTeal,
            iconColor: AppTheme.angel,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.screenBackgroundGradient,
        ),
        child: Stack(
        children: [

          Form(
            key: _formKey,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildCheckoutHeader(),
                        SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                        
                        _buildStoreInfoSection(),
                        SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                        
                        _buildDeliverySection(),
                        SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                        
                        _buildPaymentSection(),
                        SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                        
                        _buildOrderSummary(grandTotal),
                        SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 2),
                        

                        _buildPlaceOrderButton(),
                        SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
                  Container(
                    decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.deepTeal.withOpacity(0.8), AppTheme.cloud.withOpacity(0.8)],
                  ),
                ),
                child: Center(
                      child: Container(
                    padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 2),
                        decoration: BoxDecoration(
                      gradient: AppTheme.cardBackgroundGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.complementaryElevation,
                    ),
                child: Column(
                      mainAxisSize: MainAxisSize.min,
                  children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
                        ),
                        SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                        SafeUI.safeText(
                          _isLoading ? 'Processing your order...' : 'Finding pickup points...',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getTitleSize(context),
                        fontWeight: FontWeight.w600,
                            color: AppTheme.deepTeal,
                            ),
                            maxLines: 1,
                        ),
                        if (_isLoadingPickupPoints && _pickupPoints.isEmpty) ...[
                          SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
                          SafeUI.safeText(
                            'This can take a few seconds while we search nearby PAXI and Pargo stores.',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                              color: AppTheme.breeze,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                    ),
                  ),
                ],
        ),
      ),
    );
  }

  Widget _buildCheckoutHeader() {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
            decoration: BoxDecoration(
        gradient: AppTheme.cardBackgroundGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.complementaryElevation,
            ),
            child: Row(
              children: [
                Container(
            padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.deepTeal, AppTheme.cloud],
              ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
              Icons.shopping_cart_checkout,
              color: AppTheme.angel,
              size: ResponsiveUtils.getIconSize(context, baseSize: 24),
            ),
          ),
          SizedBox(width: ResponsiveUtils.getHorizontalPadding(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                SafeUI.safeText(
                  'Secure Checkout',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context),
                    fontWeight: FontWeight.w600,
                          color: AppTheme.deepTeal,
                  ),
                  maxLines: 1,
                ),
                SafeUI.safeText(
                  'Complete your order securely',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                    color: AppTheme.breeze,
                  ),
                  maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStoreInfoSection() {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
      decoration: BoxDecoration(
        gradient: AppTheme.cardBackgroundGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.complementaryElevation,
        border: Border.all(
          color: AppTheme.breeze.withOpacity(0.2),
          width: 1,
        ),
      ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
              Icon(
                Icons.storefront,
                color: AppTheme.deepTeal,
                size: ResponsiveUtils.getIconSize(context, baseSize: 20),
              ),
              SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
              SafeUI.safeText(
                'Store Information',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getTitleSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepTeal,
                ),
                maxLines: 1,
                      ),
                    ],
                  ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
          SafeUI.safeText(
            'Store: ${_storeName ?? 'N/A'}',
            style: TextStyle(
              fontSize: ResponsiveUtils.getTitleSize(context) - 2,
              fontWeight: FontWeight.w600,
              color: AppTheme.deepTeal,
            ),
            maxLines: 1,
          ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.3),
          Row(
              children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isStoreCurrentlyOpen() ? AppTheme.deepTeal : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.3),
              SafeUI.safeText(
                _isStoreCurrentlyOpen() ? 'Store is Open' : 'Store is Closed',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                  fontWeight: FontWeight.w600,
                  color: _isStoreCurrentlyOpen() ? AppTheme.deepTeal : Colors.red,
                ),
                maxLines: 1,
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.3),
          SafeUI.safeText(
            'Operating Hours: ${_storeOpenHour ?? 'N/A'} - ${_storeCloseHour ?? 'N/A'}',
            style: TextStyle(
              fontSize: ResponsiveUtils.getTitleSize(context) - 2,
              color: AppTheme.breeze,
            ),
            maxLines: 1,
          ),
          // Debug: Print current values
          Builder(
            builder: (context) {
              print('🔍 DEBUG: Store info display:');
              print('  - _storeOpenHour: $_storeOpenHour');
              print('  - _storeCloseHour: $_storeCloseHour');
              print('  - _storeOpenHour ?? N/A: ${_storeOpenHour ?? 'N/A'}');
              print('  - _storeCloseHour ?? N/A: ${_storeCloseHour ?? 'N/A'}');
              return const SizedBox.shrink();
            },
          ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.3),
          SafeUI.safeText(
            'Delivery Available: ${_isStoreCurrentlyOpen() ? 'Yes' : 'No'}',
            style: TextStyle(
              fontSize: ResponsiveUtils.getTitleSize(context) - 2,
              color: AppTheme.deepTeal,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
  Widget _buildDeliverySection() {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
      decoration: BoxDecoration(
        gradient: AppTheme.cardBackgroundGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.complementaryElevation,
        border: Border.all(
          color: AppTheme.breeze.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Debug: Print current values
          Builder(
            builder: (context) {
              print('🔍 DEBUG: Store info display:');
              print('  - _storeOpenHour: $_storeOpenHour');
              print('  - _storeCloseHour: $_storeCloseHour');
              print('  - _storeOpenHour ?? N/A: ${_storeOpenHour ?? 'N/A'}');
              print('  - _storeCloseHour ?? N/A: ${_storeCloseHour ?? 'N/A'}');
              return const SizedBox.shrink();
            },
          ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.3),
          SafeUI.safeText(
            'Delivery Available: ${_isStoreCurrentlyOpen() ? 'Yes' : 'No'}',
            style: TextStyle(
              fontSize: ResponsiveUtils.getTitleSize(context) - 2,
              color: AppTheme.deepTeal,
            ),
            maxLines: 1,
          ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
          
          // Delivery Model Indicator
          if (_isDelivery) ...[
            Container(
              padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.cloud.withOpacity(0.1),
                    AppTheme.breeze.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.cloud.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.deepTeal.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: AppTheme.deepTeal,
                      size: 16,
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SafeUI.safeText(
                          _getDeliveryModelDisplayText(),
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getTitleSize(context) - 3,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.deepTeal,
                          ),
                          maxLines: 1,
                        ),
                        SafeUI.safeText(
                          _getDeliveryModelDescription(),
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                            color: AppTheme.breeze,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
          
          // Delivery Options
          SafeUI.safeText(
            'Delivery Options',
            style: TextStyle(
              fontSize: ResponsiveUtils.getTitleSize(context),
              fontWeight: FontWeight.w600,
              color: AppTheme.deepTeal,
            ),
            maxLines: 1,
          ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
          
          // Delivery Toggle
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isDelivery = true;
                      _calculateDeliveryFeeAndCheckStore();
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
                    decoration: BoxDecoration(
                                                gradient: _isDelivery 
                              ? LinearGradient(colors: AppTheme.primaryGradient)
                              : LinearGradient(
                                  colors: [AppTheme.angel, AppTheme.angel],
                                ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isDelivery 
                            ? AppTheme.deepTeal.withOpacity(0.5)
                            : AppTheme.breeze.withOpacity(0.3),
                        width: _isDelivery ? 2 : 1,
                      ),
                      boxShadow: _isDelivery 
                          ? [
                              BoxShadow(
                                color: AppTheme.deepTeal.withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.delivery_dining,
                          color: _isDelivery 
                              ? AppTheme.angel
                              : AppTheme.breeze,
                          size: ResponsiveUtils.getIconSize(context, baseSize: 20),
                        ),
                        SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                        Expanded(
                          child: SafeUI.safeText(
                            'Delivery',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                              fontWeight: FontWeight.w600,
                              color: _isDelivery 
                                  ? AppTheme.angel
                                  : AppTheme.breeze,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    print('🔴 DEBUG: PICKUP BUTTON 1 CLICKED!');
                    print('🔴 DEBUG: Before setState - _isDelivery: $_isDelivery');
                    setState(() {
                      _isDelivery = false;
                      print('🔴 DEBUG: Inside setState - _isDelivery: $_isDelivery');
                      _calculateDeliveryFeeAndCheckStore();
                    });
                    print('🔴 DEBUG: After setState - _isDelivery: $_isDelivery');
                    print('🔴 DEBUG: About to load pickup points...');
                    // Load pickup points when switching to pickup mode
                    _loadPickupPointsForCurrentLocation();
                  },
                  child: Container(
                    padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
                    decoration: BoxDecoration(
                                                gradient: !_isDelivery 
                              ? LinearGradient(colors: AppTheme.secondaryGradient)
                              : LinearGradient(
                                  colors: [AppTheme.angel, AppTheme.angel],
                                ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !_isDelivery 
                            ? AppTheme.deepTeal.withOpacity(0.5)
                            : AppTheme.breeze.withOpacity(0.3),
                        width: !_isDelivery ? 2 : 1,
                      ),
                      boxShadow: !_isDelivery 
                          ? [
                              BoxShadow(
                                color: AppTheme.deepTeal.withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.storefront,
                          color: !_isDelivery 
                              ? AppTheme.angel
                              : AppTheme.breeze,
                          size: ResponsiveUtils.getIconSize(context, baseSize: 20),
                        ),
                        SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                        Expanded(
                          child: SafeUI.safeText(
                            'Pickup',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                              fontWeight: FontWeight.w600,
                              color: !_isDelivery 
                                  ? AppTheme.angel
                                  : AppTheme.breeze,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
          
          // Pargo Pickup Points Section
          if (!_isDelivery && (_productCategory.toLowerCase() != 'food' || _hasNonFoodItems) && _pickupPoints.isNotEmpty) ...[
            Container(
              margin: EdgeInsets.symmetric(vertical: ResponsiveUtils.getVerticalPadding(context) * 0.5),
              padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.deepTeal.withOpacity(0.15),
                    AppTheme.deepTeal.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.deepTeal.withOpacity(0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.deepTeal.withOpacity(0.1),
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: AppTheme.deepTeal,
                        size: ResponsiveUtils.getTitleSize(context),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child:                       SafeUI.safeText(
                        '🚚 Pickup Points',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getTitleSize(context),
                          fontWeight: FontWeight.w900,
                          color: AppTheme.deepTeal,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                      ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  SafeUI.safeText(
                    'Choose from our network of secure pickup locations',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                      color: AppTheme.breeze,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 12),
                  
                  // Service selection buttons
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _selectedServiceFilter == 'pargo'
                                  ? [
                                      AppTheme.deepTeal.withOpacity(0.3),
                                      AppTheme.deepTeal.withOpacity(0.2),
                                    ]
                                  : [
                                      AppTheme.deepTeal.withOpacity(0.1),
                                      AppTheme.deepTeal.withOpacity(0.05),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedServiceFilter == 'pargo'
                                  ? AppTheme.deepTeal
                                  : AppTheme.deepTeal.withOpacity(0.3),
                              width: _selectedServiceFilter == 'pargo' ? 2 : 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _filterPickupPointsByService('pargo'),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.local_shipping,
                                      color: _selectedServiceFilter == 'pargo'
                                          ? AppTheme.deepTeal
                                          : AppTheme.deepTeal.withOpacity(0.7),
                                      size: 24,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Pargo',
                                      style: TextStyle(
                                        color: _selectedServiceFilter == 'pargo'
                                            ? AppTheme.deepTeal
                                            : AppTheme.deepTeal.withOpacity(0.7),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Verified Points',
                                      style: TextStyle(
                                        color: _selectedServiceFilter == 'pargo'
                                            ? AppTheme.deepTeal
                                            : AppTheme.breeze,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _selectedServiceFilter == 'paxi'
                                  ? [
                                      AppTheme.deepTeal.withOpacity(0.3),
                                      AppTheme.deepTeal.withOpacity(0.2),
                                    ]
                                  : [
                                      AppTheme.deepTeal.withOpacity(0.1),
                                      AppTheme.deepTeal.withOpacity(0.05),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedServiceFilter == 'paxi'
                                  ? AppTheme.deepTeal
                                  : AppTheme.deepTeal.withOpacity(0.3),
                              width: _selectedServiceFilter == 'paxi' ? 2 : 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _filterPickupPointsByService('paxi'),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.inventory_2,
                                      color: _selectedServiceFilter == 'paxi'
                                          ? AppTheme.deepTeal
                                          : AppTheme.deepTeal.withOpacity(0.7),
                                      size: 24,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'PAXI',
                                      style: TextStyle(
                                        color: _selectedServiceFilter == 'paxi'
                                            ? AppTheme.deepTeal
                                            : AppTheme.deepTeal.withOpacity(0.7),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Secure Points',
                                      style: TextStyle(
                                        color: _selectedServiceFilter == 'paxi'
                                            ? AppTheme.deepTeal
                                            : AppTheme.breeze,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Show All button
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedServiceFilter == null
                            ? AppTheme.deepTeal.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedServiceFilter == null
                              ? AppTheme.deepTeal
                              : AppTheme.deepTeal.withOpacity(0.3),
                          width: _selectedServiceFilter == null ? 2 : 1,
                        ),
                      ),
                      child: TextButton.icon(
                        onPressed: () => _filterPickupPointsByService(null),
                        icon: Icon(
                          Icons.filter_list_off,
                          color: _selectedServiceFilter == null
                              ? AppTheme.deepTeal
                              : AppTheme.deepTeal.withOpacity(0.7),
                          size: 16,
                        ),
                        label: Text(
                          'Show All Services',
                          style: TextStyle(
                            color: _selectedServiceFilter == null
                                ? AppTheme.deepTeal
                                : AppTheme.deepTeal.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                       
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  
                  // PAXI Delivery Speed (only when PAXI is selected)
                    if (_sellerPaxiEnabled && _selectedServiceFilter == 'paxi') ...[
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.deepTeal.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.speed, color: AppTheme.deepTeal, size: 20),
                                SizedBox(width: 8),
                                Text('PAXI Delivery Speed',
                                  style: TextStyle(color: AppTheme.deepTeal, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),

                            ...PaxiConfig.getAllOptions().map((option) {
                              final speed = option['deliverySpeed'] as String;
                              final name = option['name'] as String;
                              final time = option['time'] as String;
                              final price = option['price'] as double;

                              return RadioListTile<String>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                value: speed,
                                groupValue: _selectedPaxiDeliverySpeed,
                                onChanged: (v) {
                                  setState(() {
                                    _selectedPaxiDeliverySpeed = v;
                                    _deliveryFee = PaxiConfig.getPrice(v!);
                                  });
                                },
                                title: Text(
                                  '$name (${time})',
                                  style: TextStyle(color: AppTheme.deepTeal, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  'R${price.toStringAsFixed(2)}',
                                  style: TextStyle(color: AppTheme.deepTeal, fontSize: 12),
                                ),
                                activeColor: AppTheme.deepTeal,
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                 // Debug button to reload pickup points
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        print('🔍 DEBUG: Manually reloading pickup points');
                        _loadPickupPointsForCurrentLocation();
                      },
                      icon: Icon(
                        Icons.refresh,
                        color: AppTheme.breeze,
                        size: 16,
                      ),
                      label: Text(
                        'Reload Points',
                        style: TextStyle(
                          color: AppTheme.breeze,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  
                  // Address search for pickup points
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.search_outlined, color: AppTheme.deepTeal, size: 20),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Search pickup points in different areas',
                                style: TextStyle(
                                  color: AppTheme.deepTeal,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _pickupAddressController,
                          onChanged: (value) {
                            if ((_addressSearchTimer?.isActive ?? false)) {
                              _addressSearchTimer!.cancel();
                            }
                            if (value.length >= 3) {
                              _addressSearchTimer = Timer(const Duration(milliseconds: 400), () async {
                                if (kIsWeb) {
                                  await _herePickupAutocomplete(value);
                                } else {
                                  _searchPickupAddress(value);
                                }
                              });
                            } else {
                              setState(() {
                                _pickupAddressSuggestions = [];
                              });
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter area to find pickup points...',
                            hintStyle: TextStyle(color: AppTheme.breeze),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTheme.deepTeal.withOpacity(0.5)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTheme.deepTeal.withOpacity(0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
                            ),
                            prefixIcon: Icon(Icons.location_city, color: AppTheme.deepTeal),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                        
                        // Pickup address suggestions
                        if (_pickupAddressSuggestions.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Container(
                            constraints: BoxConstraints(maxHeight: 150),
                            decoration: BoxDecoration(
                              color: AppTheme.deepTeal.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.deepTeal.withOpacity(0.2)),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _pickupAddressSuggestions.length,
                              itemBuilder: (context, index) {
                                final placemark = _pickupAddressSuggestions[index];
                                final address = _formatAddress(placemark);
                                return ListTile(
                                  dense: true,
                                  leading: Icon(Icons.location_on, color: AppTheme.deepTeal, size: 16),
                                  title: Text(
                                    address,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.angel,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () async {
                                    _pickupAddressController.text = address;
                                    setState(() {
                                      _pickupAddressSuggestions = [];
                                      // Keep pickup UI visible during geocode + fetch
                                      _isDelivery = false;
                                      _isLoadingPickupPoints = true;
                                    });

                                    try {
                                      if (kIsWeb) {
                                        final uri = Uri.parse(
                                          '${HereConfig.geocodeUrl}?q=${Uri.encodeComponent(address)}&apiKey=${HereConfig.validatedApiKey}',
                                        );
                                        final res = await http.get(uri);
                                        if (res.statusCode == 200) {
                                          final items = (json.decode(res.body)['items'] as List);
                                          if (items.isNotEmpty) {
                                            final pos = items.first['position'];
                                            _selectedLat = (pos['lat'] as num).toDouble();
                                            _selectedLng = (pos['lng'] as num).toDouble();
                                            _loadPickupPointsForCoordinates(_selectedLat!, _selectedLng!);
                                          }
                                        }
                                      } else {
                                        final locations = await locationFromAddress(address);
                                        if (locations.isNotEmpty) {
                                          final loc = locations.first;
                                          _selectedLat = loc.latitude;
                                          _selectedLng = loc.longitude;
                                          _loadPickupPointsForCoordinates(loc.latitude, loc.longitude);
                                        }
                                      }
                                    } catch (e) {
                                      print('❌ Error converting pickup address to coordinates: $e');
                                    } finally {
                                      if (mounted) {
                                        setState(() {
                                          _isLoadingPickupPoints = false;
                                        });
                                      }
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  if (_selectedPickupPoint != null) ...[
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.deepTeal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.deepTeal, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: AppTheme.deepTeal, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Selected Pickup Point',
                                style: TextStyle(
                                  color: AppTheme.deepTeal,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedPickupPoint!.name,
                                  style: TextStyle(
                                    color: AppTheme.angel,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _selectedPickupPoint!.isPargoPoint 
                                      ? AppTheme.deepTeal.withOpacity(0.1)
                                      : AppTheme.deepTeal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.deepTeal.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _selectedPickupPoint!.isPargoPoint 
                                      ? '🚚 Pargo'
                                      : _selectedPickupPoint!.isPaxiPoint 
                                          ? '📦 PAXI'
                                          : '🏪 Local',
                                  style: TextStyle(
                                    color: AppTheme.deepTeal,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            _selectedPickupPoint!.address,
                            style: TextStyle(
                              color: AppTheme.breeze,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: AppTheme.deepTeal,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  'R',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Fee: R${(
                                  _selectedPickupPoint!.isPaxiPoint && _selectedPaxiDeliverySpeed != null
                                    ? PaxiConfig.getPrice(_selectedPaxiDeliverySpeed!).toStringAsFixed(2)
                                    : _selectedPickupPoint!.fee.toStringAsFixed(2)
                                )}',
                                style: TextStyle(
                                  color: AppTheme.deepTeal,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Spacer(),
                              TextButton(
                                onPressed: () => _showPickupPointDetails(_selectedPickupPoint!),
                                child: Text(
                                  'View Details',
                                  style: TextStyle(
                                    color: AppTheme.deepTeal,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                    // Pickup points list header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Available Pickup Points (${_pickupPoints.length})',
                            style: TextStyle(
                              color: AppTheme.deepTeal,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_selectedServiceFilter != null) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.deepTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.deepTeal.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _selectedServiceFilter == 'pargo' ? '🚚 Pargo Only' : '📦 PAXI Only',
                              style: TextStyle(
                                color: AppTheme.deepTeal,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 8),
                    Container(
                      constraints: BoxConstraints(maxHeight: 350),
                      child: _pickupPoints.isEmpty
                          ? Column(
                              children: [
                                SizedBox(height: 20),
                                Icon(
                                  Icons.location_off,
                                  color: AppTheme.breeze,
                                  size: 48,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No pickup points available',
                                  style: TextStyle(
                                    color: AppTheme.breeze,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _selectedServiceFilter == null
                                      ? 'No pickup points found in your area'
                                      : _selectedServiceFilter == 'pargo'
                                          ? 'No Pargo pickup points found'
                                          : 'No PAXI pickup points found',
                                  style: TextStyle(
                                    color: AppTheme.breeze.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 16),
                                if (_allPickupPoints.isNotEmpty) ...[
                                  Text(
                                    'Debug: ${_allPickupPoints.length} total points available',
                                    style: TextStyle(
                                      color: AppTheme.breeze.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Pargo: ${_allPickupPoints.where((p) => p.isPargoPoint).length}, PAXI: ${_allPickupPoints.where((p) => p.isPaxiPoint).length}',
                                    style: TextStyle(
                                      color: AppTheme.breeze.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _pickupPoints.length,
                              itemBuilder: (context, index) {
                                final point = _pickupPoints[index];
                                final isSelected = _selectedPickupPoint?.id == point.id;
                                return Container(
                                  margin: EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? AppTheme.deepTeal.withOpacity(0.1)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected 
                                          ? AppTheme.deepTeal
                                          : AppTheme.deepTeal.withOpacity(0.3),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(
                                      point.isPargoPoint ? Icons.store : Icons.location_on,
                                      color: isSelected ? AppTheme.deepTeal : AppTheme.deepTeal,
                                      size: 20,
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            point.name,
                                            style: TextStyle(
                                              color: AppTheme.angel,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: point.isPargoPoint 
                                                ? AppTheme.deepTeal.withOpacity(0.1)
                                                : AppTheme.deepTeal.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: AppTheme.deepTeal.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            point.isPargoPoint 
                                                ? '🚚'
                                                : point.isPaxiPoint 
                                                    ? '📦'
                                                    : '🏪',
                                            style: TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    point.address,
                                    style: TextStyle(
                                      color: AppTheme.breeze,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'Fee: R${point.fee.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: AppTheme.deepTeal,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        point.isPargoPoint 
                                            ? '🚚 Pargo'
                                            : point.isPaxiPoint 
                                                ? '📦 PAXI'
                                                : '🏪 Local Store',
                                        style: TextStyle(
                                          color: AppTheme.breeze,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Icon(
                                Icons.info_outline,
                                color: AppTheme.deepTeal,
                                size: 18,
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedPickupPoint = point;
                                  _deliveryFee = point.fee;
                                });
                              },
                              onLongPress: () => _showPickupPointDetails(point),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          
          // Address Field (for delivery) or Pickup Location (for pickup)
          if (_isDelivery) ...[
            SafeUI.safeText(
              'Delivery Address',
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                fontWeight: FontWeight.w600,
                color: AppTheme.deepTeal,
              ),
              maxLines: 1,
            ),
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppTheme.inputBackgroundGradient),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.breeze.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: AppTheme.inputElevation,
              ),
              child: TextFormField(
                controller: _addressController,
                onChanged: (value) {
                  if (value.length >= 3) {
                    _searchAddressesInline(value);
                  } else {
                    setState(() {
                      // Reset inline search state
                      _addressSuggestions = [];
                    });
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Enter your delivery address',
                  hintStyle: TextStyle(
                    color: AppTheme.breeze.withOpacity(0.6),
                    fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                  ),
                  prefixIcon: Icon(
                                          Icons.location_on,
                      color: AppTheme.deepTeal,
                      size: ResponsiveUtils.getIconSize(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getHorizontalPadding(context),
                    vertical: ResponsiveUtils.getVerticalPadding(context),
                  ),
                ),
                style: TextStyle(
                  fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                  color: AppTheme.deepTeal,
                ),
                maxLines: 1,
              ),
            ),
            
            // Inline Address Suggestions
            if (_addressSuggestions.isNotEmpty) ...[
              SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
              Container(
                constraints: BoxConstraints(
                  maxHeight: 200,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: AppTheme.inputBackgroundGradient),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.breeze.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: AppTheme.inputElevation,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _addressSuggestions.length,
                  itemBuilder: (context, index) {
                    final placemark = _addressSuggestions[index];
                    return ListTile(
                      leading: Icon(
                        Icons.location_on,
                        color: AppTheme.deepTeal,
                        size: ResponsiveUtils.getIconSize(context),
                      ),
                      title: SafeUI.safeText(
                        placemark.name ?? placemark.street ?? 'Unknown location',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getTitleSize(context) - 3,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.deepTeal,
                        ),
                        maxLines: 1,
                      ),
                      subtitle: SafeUI.safeText(
                        '${placemark.street ?? ''}, ${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                          color: AppTheme.breeze,
                        ),
                        maxLines: 2,
                      ),
                      onTap: () async {
                        setState(() {
                          _addressController.text = '${placemark.street ?? ''}, ${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}';
                          // Reset inline search state
                          _addressSuggestions = [];
                        });
                        
                        // Convert placemark back to coordinates
                        try {
                          final locations = await locationFromAddress(_addressController.text);
                          if (locations.isNotEmpty) {
                            final location = locations.first;
                            _selectedLat = location.latitude;
                            _selectedLng = location.longitude;
                            _loadPickupPointsForCoordinates(
                              location.latitude ?? 0.0,
                              location.longitude ?? 0.0,
                            );
                          }
                        } catch (e) {
                          print('❌ Error converting placemark to coordinates: $e');
                        }
                      },
                    );
                  },
                ),
              ),
            ],
            
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
            
            // Pickup Location Field (for pickup orders)
            if (!_isDelivery) ...[
              SafeUI.safeText(
                'Pickup Location',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepTeal,
                ),
                maxLines: 1,
              ),
              SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: AppTheme.inputBackgroundGradient),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.breeze.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: AppTheme.inputElevation,
                ),
                child: TextFormField(
                  controller: _addressController,
                  onChanged: (value) {
                    if (value.length >= 3) {
                      _searchAddressesInline(value);
                    } else {
                      setState(() {
                        _addressSuggestions = [];
                      });
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter your pickup location',
                    hintStyle: TextStyle(
                      color: AppTheme.breeze.withOpacity(0.6),
                      fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                    ),
                    prefixIcon: Icon(
                      Icons.location_on,
                      color: AppTheme.deepTeal,
                      size: ResponsiveUtils.getIconSize(context),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.getHorizontalPadding(context),
                      vertical: ResponsiveUtils.getVerticalPadding(context),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                    color: AppTheme.deepTeal,
                  ),
                  maxLines: 1,
                ),
              ),
              
              // Inline Address Suggestions for Pickup
              if (_addressSuggestions.isNotEmpty) ...[
                SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: 200,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppTheme.inputBackgroundGradient),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.breeze.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: AppTheme.inputElevation,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _addressSuggestions.length,
                    itemBuilder: (context, index) {
                      final placemark = _addressSuggestions[index];
                      return ListTile(
                        leading: Icon(
                          Icons.location_on,
                          color: AppTheme.deepTeal,
                          size: ResponsiveUtils.getIconSize(context),
                        ),
                        title: SafeUI.safeText(
                          placemark.name ?? placemark.street ?? 'Unknown location',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getTitleSize(context) - 3,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.deepTeal,
                          ),
                          maxLines: 1,
                        ),
                        subtitle: SafeUI.safeText(
                          '${placemark.street ?? ''}, ${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                            color: AppTheme.breeze,
                          ),
                          maxLines: 2,
                        ),
                        onTap: () async {
                          setState(() {
                            _addressController.text = '${placemark.street ?? ''}, ${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}';
                            _addressSuggestions = [];
                          });
                          
                          // Convert placemark back to coordinates and load pickup points
                          try {
                            final locations = await locationFromAddress(_addressController.text);
                            if (locations.isNotEmpty) {
                              final location = locations.first;
                              _selectedLat = location.latitude;
                              _selectedLng = location.longitude;
                              _loadPickupPointsForCoordinates(
                                location.latitude ?? 0.0,
                                location.longitude ?? 0.0,
                              );
                            }
                          } catch (e) {
                            print('❌ Error converting placemark to coordinates: $e');
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
            

            
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
            // Food pickup info message
            if (!_isDelivery && _productCategory.toLowerCase() == 'food') ...[
              SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
              Container(
                padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.warning.withOpacity(0.1),
                      AppTheme.warning.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.warning.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.warning,
                      size: ResponsiveUtils.getIconSize(context),
                    ),
                    SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                    Expanded(
                      child: SafeUI.safeText(
                        '🍕 Food pickup orders are collected directly from the restaurant. Pargo pickup points are not available for food items.',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getTitleSize(context) - 3,
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Mixed cart information
            if (!_isDelivery && _productCategory == 'mixed') ...[
              Container(
                margin: EdgeInsets.symmetric(
                  vertical: ResponsiveUtils.getVerticalPadding(context) * 0.5,
                ),
                padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.deepTeal.withOpacity(0.1), AppTheme.deepTeal.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.deepTeal.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.deepTeal.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: AppTheme.deepTeal,
                        size: ResponsiveUtils.getIconSize(context, baseSize: 18),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SafeUI.safeText(
                            'Mixed Cart Pickup',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getTitleSize(context) - 1,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.deepTeal,
                            ),
                            maxLines: 1,
                          ),
                          SafeUI.safeText(
                            '🍕 Food items: Collect from restaurant\n📦 Other items: Available via Pargo pickup points',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getTitleSize(context) - 3,
                              color: AppTheme.deepTeal,
                              height: 1.4,
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Pargo Pickup Points (for non-food pickup orders only)
            if (!_isDelivery && (_productCategory.toLowerCase() != 'food' || _hasNonFoodItems)) ...[
              SafeUI.safeText(
                'Pargo Pickup Points',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepTeal,
                ),
                maxLines: 1,
              ),
              SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
              
              // Debug info
              if (kDebugMode) ...[
                SafeUI.safeText(
                  'Debug: Product Category: $_productCategory, Pickup Points: ${_pickupPoints.length}',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                    color: AppTheme.breeze,
                  ),
                  maxLines: 1,
                ),
                SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.3),
              ],
              
              // Loading indicator
              if (_isLoadingPickupPoints) ...[
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.deepTeal.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.deepTeal.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: SafeUI.safeText(
                          'Finding pickup points near you...',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                            color: AppTheme.breeze,
                          ),
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_pickupPoints.isNotEmpty) ...[
                ..._pickupPoints.take(5).map((point) => Container(
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: point.isPargoPoint 
                          ? [
                              AppTheme.deepTeal.withOpacity(0.1),
                              AppTheme.deepTeal.withOpacity(0.05),
                              AppTheme.angel,
                            ]
                          : [
                              AppTheme.deepTeal.withOpacity(0.1),
                              AppTheme.deepTeal.withOpacity(0.05),
                              AppTheme.angel,
                            ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: point.isPargoPoint 
                          ? AppTheme.deepTeal.withOpacity(0.4)
                          : AppTheme.deepTeal.withOpacity(0.4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: point.isPargoPoint 
                            ? AppTheme.deepTeal.withOpacity(0.2)
                            : AppTheme.deepTeal.withOpacity(0.2),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _selectedPickupPoint = point;
                          _deliveryFee = point.fee;
                        });
                      },
                      child: Padding(
                        padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
                        child: Row(
                          children: [
                            // Icon Container
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: point.isPargoPoint 
                                      ? [
                                          AppTheme.deepTeal.withOpacity(0.3),
                                          AppTheme.deepTeal.withOpacity(0.1),
                                        ]
                                      : [
                                          AppTheme.deepTeal.withOpacity(0.3),
                                          AppTheme.deepTeal.withOpacity(0.1),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: point.isPargoPoint 
                                      ? AppTheme.deepTeal.withOpacity(0.6)
                                      : AppTheme.deepTeal.withOpacity(0.6),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                point.isPargoPoint 
                                    ? Icons.local_shipping
                                    : Icons.storefront,
                                color: point.isPargoPoint 
                                    ? AppTheme.deepTeal
                                    : AppTheme.deepTeal,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: ResponsiveUtils.getHorizontalPadding(context)),
                            
                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Name and Selection Indicator
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SafeUI.safeText(
                                          point.name,
                                          style: TextStyle(
                                            fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                                            fontWeight: FontWeight.w800,
                                            color: point.isPargoPoint 
                                                ? AppTheme.deepTeal
                                                : AppTheme.deepTeal,
                                            letterSpacing: 0.3,
                                          ),
                                          maxLines: 1,
                                        ),
                                      ),
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _selectedPickupPoint?.id == point.id
                                              ? (point.isPargoPoint 
                                                  ? AppTheme.deepTeal
                                                  : AppTheme.deepTeal)
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: point.isPargoPoint 
                                                ? AppTheme.deepTeal.withOpacity(0.6)
                                                : AppTheme.deepTeal.withOpacity(0.6),
                                            width: 2,
                                          ),
                                        ),
                                        child: _selectedPickupPoint?.id == point.id
                                            ? Icon(
                                                Icons.check,
                                                color: AppTheme.angel,
                                                size: 14,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  
                                  // Address
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: AppTheme.breeze,
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: SafeUI.safeText(
                                          point.address,
                                          style: TextStyle(
                                            fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                                            color: AppTheme.breeze,
                                          ),
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  
                                  // Service Details Row
                                  Row(
                                    children: [
                                      // Service Type
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: point.isPargoPoint 
                                                ? [
                                                    AppTheme.deepTeal.withOpacity(0.2),
                                                    AppTheme.deepTeal.withOpacity(0.1),
                                                  ]
                                                : [
                                                    AppTheme.deepTeal.withOpacity(0.2),
                                                    AppTheme.deepTeal.withOpacity(0.1),
                                                  ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: point.isPargoPoint 
                                                ? AppTheme.deepTeal.withOpacity(0.4)
                                                : AppTheme.deepTeal.withOpacity(0.4),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              point.isPargoPoint 
                                                  ? Icons.local_shipping
                                                  : Icons.store,
                                              color: point.isPargoPoint 
                                                  ? AppTheme.deepTeal
                                                  : AppTheme.deepTeal,
                                              size: 12,
                                            ),
                                            SizedBox(width: 4),
                                            SafeUI.safeText(
                                              point.type,
                                              style: TextStyle(
                                                fontSize: ResponsiveUtils.getTitleSize(context) - 5,
                                                fontWeight: FontWeight.w600,
                                                color: point.isPargoPoint 
                                                    ? AppTheme.deepTeal
                                                    : AppTheme.deepTeal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      
                                      // Distance
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.cloud.withOpacity(0.2),
                                              AppTheme.cloud.withOpacity(0.1),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AppTheme.cloud.withOpacity(0.4),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.straighten,
                                              color: AppTheme.cloud,
                                              size: 12,
                                            ),
                                            SizedBox(width: 4),
                                            SafeUI.safeText(
                                              '${point.distance.toStringAsFixed(1)} km',
                                              style: TextStyle(
                                                fontSize: ResponsiveUtils.getTitleSize(context) - 5,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.cloud,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      
                                      // Fee
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.success.withOpacity(0.2),
                                              AppTheme.success.withOpacity(0.1),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AppTheme.success.withOpacity(0.4),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.payment,
                                              color: AppTheme.success,
                                              size: 12,
                                            ),
                                            SizedBox(width: 4),
                                            SafeUI.safeText(
                                              'R${point.fee.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: ResponsiveUtils.getTitleSize(context) - 5,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.success,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            // Arrow Indicator
                            Icon(
                              Icons.arrow_forward_ios,
                              color: AppTheme.breeze.withOpacity(0.6),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )).toList(),
                
                // View All Button
                if (_pickupPoints.length > 5) ...[
                  SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
                  Center(
                    child: TextButton(
                      onPressed: () => _showAllPickupPointsModal(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.getHorizontalPadding(context),
                          vertical: ResponsiveUtils.getVerticalPadding(context) * 0.5,
                        ),
                      ),
                      child: SafeUI.safeText(
                        'View All ${_pickupPoints.length} Locations',
                        style: TextStyle(
                          color: AppTheme.deepTeal,
                          fontWeight: FontWeight.w600,
                          fontSize: ResponsiveUtils.getTitleSize(context) - 3,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              
              // No pickup points found message
              if (_pickupPoints.isEmpty && !_isLoadingPickupPoints) ...[
                Container(
                  padding: EdgeInsets.all(ResponsiveUtils.getVerticalPadding(context)),
                  decoration: BoxDecoration(
                    color: AppTheme.breeze.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.breeze.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      SafeUI.safeText(
                        'No pickup points found in your area',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getTitleSize(context) - 3,
                          color: AppTheme.breeze,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
                      SafeUI.safeText(
                        'Please try a different address or contact support for assistance.',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                          color: AppTheme.breeze,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () => _loadPickupPointsForCurrentAddress(),
                          icon: Icon(
                            Icons.refresh,
                            color: AppTheme.angel,
                            size: ResponsiveUtils.getIconSize(context),
                          ),
                          label: SafeUI.safeText(
                            'Try Again',
                            style: TextStyle(
                              color: AppTheme.angel,
                              fontWeight: FontWeight.w600,
                              fontSize: ResponsiveUtils.getTitleSize(context) - 3,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.deepTeal,
                            foregroundColor: AppTheme.angel,
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.getHorizontalPadding(context),
                              vertical: ResponsiveUtils.getVerticalPadding(context) * 0.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
            
            // Phone Field
            SafeUI.safeText(
              'Phone Number',
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                fontWeight: FontWeight.w600,
                color: AppTheme.deepTeal,
              ),
              maxLines: 1,
            ),
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppTheme.inputBackgroundGradient), 
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.breeze.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: AppTheme.inputElevation,
              ),
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Enter your phone number',
                  hintStyle: TextStyle(
                    color: AppTheme.breeze.withOpacity(0.6),
                    fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                  ),
                  prefixIcon: Icon(
                    Icons.phone,
                    color: AppTheme.deepTeal,
                    size: ResponsiveUtils.getIconSize(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getHorizontalPadding(context),
                    vertical: ResponsiveUtils.getVerticalPadding(context),
                  ),
                ),
                style: TextStyle(
                  fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                  color: AppTheme.deepTeal,
                ),
                maxLines: 1,
              ),
            ),
            
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
            
            // Delivery Instructions
            SafeUI.safeText(
              'Delivery Instructions',
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                fontWeight: FontWeight.w600,
                color: AppTheme.deepTeal,
              ),
              maxLines: 1,
            ),
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppTheme.inputBackgroundGradient),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.breeze.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: AppTheme.inputElevation,
              ),
              child: TextFormField(
                controller: _deliveryInstructionsController,
                decoration: InputDecoration(
                  hintText: 'Any special delivery instructions?',
                  hintStyle: TextStyle(
                    color: AppTheme.breeze.withOpacity(0.6),
                    fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                  ),
                  prefixIcon: Icon(
                    Icons.edit_note,
                    color: AppTheme.deepTeal,
                    size: ResponsiveUtils.getTitleSize(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getHorizontalPadding(context),
                    vertical: ResponsiveUtils.getVerticalPadding(context),
                  ),
                ),
                style: TextStyle(
                  fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                  color: AppTheme.deepTeal,
                  ),
                maxLines: 3,
              ),
            ),
            
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
            
            // Special Requests
            SafeUI.safeText(
              'Special Requests',
              style: TextStyle(
                fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                fontWeight: FontWeight.w600,
                color: AppTheme.deepTeal,
              ),
              maxLines: 1,
            ),
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppTheme.inputBackgroundGradient),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.breeze.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: AppTheme.inputElevation,
              ),
              child: TextFormField(
                controller: _specialRequestsController,
                decoration: InputDecoration(
                  hintText: 'Any special requests for your order?',
                  hintStyle: TextStyle(
                    color: AppTheme.breeze.withOpacity(0.6),
                    fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                  ),
                  prefixIcon: Icon(
                    Icons.star,
                    color: AppTheme.deepTeal,
                    size: ResponsiveUtils.getIconSize(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getHorizontalPadding(context),
                    vertical: ResponsiveUtils.getVerticalPadding(context),
                  ),
                ),
                style: TextStyle(
                  fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                  color: AppTheme.deepTeal,
                ),
                maxLines: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }
  

  Widget _buildCustomerInfoSection() {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
      decoration: BoxDecoration(
        gradient: AppTheme.cardBackgroundGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.complementaryElevation,
        border: Border.all(
          color: AppTheme.breeze.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Food pickup restriction note
          if (_productCategory.toLowerCase() == 'food') ...[
            Container(
              padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.deepTeal.withOpacity(0.1),
                    AppTheme.deepTeal.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.deepTeal.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.deepTeal.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.restaurant,
                      color: AppTheme.deepTeal,
                      size: 16,
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.4),
                  Expanded(
                    child: SafeUI.safeText(
                      'Food products require delivery for freshness',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getTitleSize(context) - 3,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.deepTeal,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
          ],
          
          // Name Field
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              labelStyle: TextStyle(color: AppTheme.breeze),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
              ),
              prefixIcon: Icon(Icons.person, color: AppTheme.breeze),
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Please enter your name' : null,
          ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
              
          // Delivery/Pickup Toggle
          Container(
            padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.deepTeal.withOpacity(0.1), AppTheme.cloud.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.deepTeal.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Type',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.deepTeal,
                  ),
                ),
                SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isDelivery = true;
                          });
                          if (currentUser != null) {
                            _calculateDeliveryFeeAndCheckStore();
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.8),
                          decoration: BoxDecoration(
                            color: _isDelivery ? AppTheme.deepTeal : AppTheme.whisper,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isDelivery ? AppTheme.deepTeal : AppTheme.breeze.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.delivery_dining,
                                color: _isDelivery ? AppTheme.angel : AppTheme.breeze,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Delivery',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                                  fontWeight: FontWeight.w600,
                                  color: _isDelivery ? AppTheme.angel : AppTheme.breeze,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                    Expanded(
                      child: GestureDetector(
                        onTap: _productCategory.toLowerCase() == 'food' ? null : () {
                          print('🔴 DEBUG: PICKUP BUTTON 2 CLICKED!');
                          print('🔴 DEBUG: Before setState - _isDelivery: $_isDelivery');
                          setState(() {
                            _isDelivery = false;
                            _deliveryFee = 0.0;
                            _deliveryDistance = 0.0;
                            print('🔴 DEBUG: Inside setState - _isDelivery: $_isDelivery');
                          });
                          print('🔴 DEBUG: After setState - _isDelivery: $_isDelivery');
                          print('🔴 DEBUG: About to load pickup points...');
                          _loadPickupPointsForCurrentLocation();
                        },
                        child: Container(
                          padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.8),
                          decoration: BoxDecoration(
                            color: _productCategory.toLowerCase() == 'food' 
                                ? AppTheme.breeze.withOpacity(0.3) 
                                : (!_isDelivery ? AppTheme.deepTeal : AppTheme.whisper),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _productCategory.toLowerCase() == 'food'
                                  ? AppTheme.breeze.withOpacity(0.2)
                                  : (!_isDelivery ? AppTheme.deepTeal : AppTheme.breeze.withOpacity(0.3)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _productCategory.toLowerCase() == 'food' ? Icons.restaurant : Icons.store,
                                color: _productCategory.toLowerCase() == 'food' 
                                    ? AppTheme.breeze.withOpacity(0.5)
                                    : (!_isDelivery ? AppTheme.angel : AppTheme.breeze),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                              'Pickup',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                                  fontWeight: FontWeight.w600,
                                  color: _productCategory.toLowerCase() == 'food' 
                                      ? AppTheme.breeze.withOpacity(0.5)
                                      : (!_isDelivery ? AppTheme.angel : AppTheme.breeze),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
              
          // Address Field with Inline Search
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _addressController,
                focusNode: _addressFocusNode,
                decoration: InputDecoration(
                  labelText: _isDelivery ? 'Delivery Address' : 'Pickup Address',
                  labelStyle: TextStyle(color: AppTheme.breeze),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
                  ),
                  prefixIcon: Icon(Icons.location_on, color: AppTheme.breeze),
                  suffixIcon: _isSearchingAddress
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
                            ),
                          ),
                        )
                      : _addressController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: AppTheme.deepTeal),
                              onPressed: () {
                                _addressController.clear();
                                _validatedAddress = null;
                    setState(() {
                                  _addressSuggestions = [];
                                  _isSearchingAddress = false;
                                });
                              },
                            )
                          : Icon(Icons.search, color: AppTheme.deepTeal),
                ),
                onChanged: (value) {
                  setState(() {});
                  if (value.trim().isNotEmpty) {
                    _searchAddressesInline(value);
                    } else {
                    _addressSuggestions = [];
                  }
                },
                validator: (value) {
                  if (_isDelivery) {
                    if (value == null || value.isEmpty) return 'Please enter your address';
                  }
                  return null;
                },
              ),
            
            // Address Suggestions (if any)
              if (_addressSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.breeze.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                  itemCount: _addressSuggestions.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _addressSuggestions.length) {
                              return ListTile(
                                leading: Icon(Icons.edit, color: AppTheme.deepTeal),
                                title: Text(
                                  'Use entered address',
                                  style: TextStyle(
                                    color: AppTheme.deepTeal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  _addressController.text,
                                  style: TextStyle(color: AppTheme.breeze),
                                ),
                                onTap: () {
                                  _validatedAddress = _addressController.text;
                                  setState(() {
                                    _addressSuggestions = [];
                                  });
                                  _calculateDeliveryFeeAndCheckStore();
                                },
                              );
                            }
                            
                            final placemark = _addressSuggestions[index];
                            final address = _formatAddress(placemark);
                            
                            return ListTile(
                              leading: Icon(Icons.location_on, color: AppTheme.deepTeal),
                              title: Text(
                                address,
                            style: TextStyle(
                                  fontWeight: FontWeight.w600,
                              color: AppTheme.deepTeal,
                                ),
                              ),
                              subtitle: placemark.country != null
                                  ? Text(
                                      placemark.country!,
                            style: TextStyle(
                                        color: AppTheme.breeze,
                              fontSize: 12,
                                      ),
                                    )
                                  : null,
                              onTap: () {
                                _addressController.text = address;
                                _validatedAddress = address;
                                setState(() {
                                  _addressSuggestions = [];
                                });
                                _calculateDeliveryFeeAndCheckStore();
                              },
                            );
                          },
                          ),
                        ),
                      ],
                  ),
              

              
              // Pickup points (Pargo) selector when in Pickup mode  
              // Show Pargo for non-food only carts OR mixed carts (non-food items can use Pargo)
              if (!_isDelivery && (_productCategory.toLowerCase() != 'food' || _hasNonFoodItems)) ...[
                SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 1.5),
                // SUPER PROMINENT PARGO SECTION - ELEVATED ABOVE OTHER CONTENT
                Container(
                  margin: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.withOpacity(0.8),  // Make it super visible
                        Colors.orange.withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.black,
                      width: 4,  // Thick border
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: AppTheme.deepTeal.withOpacity(0.1),
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                      padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                                colors: [
                            AppTheme.deepTeal.withOpacity(0.4),
                            AppTheme.deepTeal.withOpacity(0.2),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                          color: AppTheme.deepTeal.withOpacity(0.6),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.deepTeal.withOpacity(0.2),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                            ),
                            child: Icon(
                              Icons.local_shipping,
                              color: AppTheme.deepTeal,
                        size: 28,
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SafeUI.safeText(
                                  '🚚 Pickup Points',
                                  style: TextStyle(
                              fontSize: ResponsiveUtils.getTitleSize(context) + 2,
                              fontWeight: FontWeight.w900,
                                    color: AppTheme.deepTeal,
                              letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                ),
                                SafeUI.safeText(
                                  _productCategory == 'mixed' 
                                    ? 'For non-food items in your cart'
                                    : 'Choose from our network of secure pickup locations',
                                  style: TextStyle(
                              fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                                    color: AppTheme.breeze,
                                    fontStyle: FontStyle.italic,
                              height: 1.3,
                            ),
                            maxLines: 2,
                          ),
                          SizedBox(height: 4),
                          SafeUI.safeText(
                            'Secure • Convenient • Professional Service',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                              color: AppTheme.deepTeal,
                              fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                ),
                              ],
                      ),
                    ),
                    // View All Button
                    if (_pickupPoints.length > 5)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.deepTeal.withOpacity(0.2),
                              AppTheme.deepTeal.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.deepTeal.withOpacity(0.4),
                          ),
                        ),
                        child: TextButton(
                          onPressed: () {
                            _showAllPickupPointsModal();
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.list_alt,
                                color: AppTheme.deepTeal,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              SafeUI.safeText(
                                'View All',
                                style: TextStyle(
                                  color: AppTheme.deepTeal,
                                  fontWeight: FontWeight.w700,
                                  fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                                ),
                              ),
                            ],
                          ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.angel,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                      color: AppTheme.breeze.withOpacity(0.3),
                          ),
                        ),
                        padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.6),
                        child: _isLoadingPickupPoints
                            ? Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
                                  ),
                                ),
                              )
                      : _pickupPoints.isEmpty
                                ? SafeUI.safeText(
                                    'No pickup points found near this address. Try another area.',
                                    style: TextStyle(color: AppTheme.breeze),
                                    maxLines: 2,
                                  )
                                : Column(
                              children: _pickupPoints.take(5).map((point) => Container(
                                margin: EdgeInsets.only(bottom: 12),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: point.isPargoPoint 
                                        ? [
                                            AppTheme.deepTeal.withOpacity(0.1),
                                            AppTheme.deepTeal.withOpacity(0.05),
                                            AppTheme.angel,
                                          ]
                                        : [
                                            AppTheme.deepTeal.withOpacity(0.1),
                                            AppTheme.deepTeal.withOpacity(0.05),
                                                AppTheme.angel,
                                              ],
                                            ),
                                  borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: point.isPargoPoint 
                                        ? AppTheme.deepTeal.withOpacity(0.4)
                                        : AppTheme.deepTeal.withOpacity(0.4),
                                    width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                      color: point.isPargoPoint 
                                          ? AppTheme.deepTeal.withOpacity(0.15)
                                          : AppTheme.deepTeal.withOpacity(0.15),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                            onTap: () {
                                              _showPargoPickupModal(point);
                                            },
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          // Enhanced Icon Container
                                          Container(
                                            padding: EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: point.isPargoPoint 
                                                    ? [
                                                        AppTheme.deepTeal.withOpacity(0.3),
                                                        AppTheme.deepTeal.withOpacity(0.1),
                                                      ]
                                                    : [
                                                        AppTheme.deepTeal.withOpacity(0.3),
                                                        AppTheme.deepTeal.withOpacity(0.1),
                                                      ],
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: point.isPargoPoint 
                                                    ? AppTheme.deepTeal.withOpacity(0.5)
                                                    : AppTheme.deepTeal.withOpacity(0.5),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Icon(
                                              point.isPargoPoint 
                                                  ? Icons.local_shipping
                                                  : Icons.storefront,
                                              color: point.isPargoPoint 
                                                  ? AppTheme.deepTeal
                                                  : AppTheme.deepTeal,
                                              size: 24,
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          
                                          // Content Section
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Name with enhanced styling
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: SafeUI.safeText(
                                                        point.name,
                                              style: TextStyle(
                                                          fontSize: ResponsiveUtils.getTitleSize(context),
                                                          fontWeight: FontWeight.w800,
                                                color: point.isPargoPoint 
                                                              ? AppTheme.deepTeal
                                                              : AppTheme.deepTeal,
                                                          letterSpacing: 0.3,
                                              ),
                                              maxLines: 1,
                                            ),
                                                    ),
                                                    // Selection indicator
                                                    Container(
                                                      width: 20,
                                                      height: 20,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: _selectedPickupPoint == point
                                                            ? (point.isPargoPoint 
                                                                ? AppTheme.deepTeal
                                                                : AppTheme.deepTeal)
                                                            : Colors.transparent,
                                                        border: Border.all(
                                                          color: _selectedPickupPoint == point
                                                              ? (point.isPargoPoint 
                                                                  ? AppTheme.deepTeal
                                                                  : AppTheme.deepTeal)
                                                              : AppTheme.breeze.withOpacity(0.4),
                                                          width: 2,
                                                        ),
                                                      ),
                                                      child: _selectedPickupPoint == point
                                                          ? Icon(
                                                              Icons.check,
                                                              color: Colors.white,
                                                              size: 14,
                                                            )
                                                          : null,
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 8),
                                                
                                                // Address with location icon
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.location_on,
                                                      color: AppTheme.breeze,
                                                      size: 16,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Expanded(
                                                      child: SafeUI.safeText(
                                                        point.address,
                                              style: TextStyle(
                                                color: AppTheme.breeze, 
                                                fontSize: ResponsiveUtils.getTitleSize(context) - 3,
                                                          height: 1.3,
                                              ),
                                              maxLines: 2,
                                            ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 8),
                                                
                                                // Service details row
                                                Row(
                                                  children: [
                                                    // Service type badge
                                                    Container(
                                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: point.isPargoPoint 
                                                            ? AppTheme.deepTeal.withOpacity(0.2)
                                                            : AppTheme.deepTeal.withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: point.isPargoPoint 
                                                              ? AppTheme.deepTeal.withOpacity(0.4)
                                                              : AppTheme.deepTeal.withOpacity(0.4),
                                                ),
                                              ),
                                                      child: SafeUI.safeText(
                                                point.isPargoPoint 
                                                            ? '🚚 Pargo Service'
                                                            : '🏪 Pickup',
                                                        style: TextStyle(
                                                          fontSize: ResponsiveUtils.getTitleSize(context) - 5,
                                                          fontWeight: FontWeight.w600,
                                                color: point.isPargoPoint 
                                                              ? AppTheme.deepTeal
                                                              : AppTheme.deepTeal,
                                              ),
                                            ),
                                          ),
                                                    SizedBox(width: 12),
                                                    
                                                    // Distance
                                                    Container(
                                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.breeze.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(
                                                          color: AppTheme.breeze.withOpacity(0.3),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.straighten,
                                                            color: AppTheme.breeze,
                                                            size: 14,
                                                          ),
                                                          SizedBox(width: 4),
                                                          SafeUI.safeText(
                                                            '${point.distance.toStringAsFixed(1)} km',
                                                            style: TextStyle(
                                                              fontSize: ResponsiveUtils.getTitleSize(context) - 5,
                                                              fontWeight: FontWeight.w600,
                                                              color: AppTheme.breeze,
                                        ),
                                        ),
                                    ],
                                                      ),
                                                    ),
                                                    SizedBox(width: 12),
                                                    
                                                    // Fee
                                                    Container(
                                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [
                                                            AppTheme.success.withOpacity(0.2),
                                                            AppTheme.success.withOpacity(0.1),
                                                          ],
                                                        ),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(
                                                          color: AppTheme.success.withOpacity(0.4),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.payment,
                                                            color: AppTheme.success,
                                                            size: 14,
                                                          ),
                                                          SizedBox(width: 4),
                                                          SafeUI.safeText(
                                                            'R${point.fee.toStringAsFixed(2)}',
                                                            style: TextStyle(
                                                              fontSize: ResponsiveUtils.getTitleSize(context) - 5,
                                                              fontWeight: FontWeight.w700,
                                                              color: AppTheme.success,
                  ),
                ),
              ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          // Arrow indicator
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            color: point.isPargoPoint 
                                                ? AppTheme.deepTeal.withOpacity(0.6)
                                                : AppTheme.deepTeal.withOpacity(0.6),
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )).toList(),
                            ),
                ),
              ],
            ),
          ),
        ],

                SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
              
                // Phone Field
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: TextStyle(color: AppTheme.breeze),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
                    ),
                    prefixIcon: Icon(Icons.phone, color: AppTheme.breeze),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your phone number';
                    final phoneReg = RegExp(r'^(\+?\d{10,15})');
                    if (!phoneReg.hasMatch(value)) return 'Enter a valid phone number';
                    return null;
                  },
                ),

                SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
              
                // Delivery Instructions
                TextFormField(
                  controller: _deliveryInstructionsController,
                  decoration: InputDecoration(
              labelText: _isDelivery ? 'Delivery Instructions (optional)' : 'Pickup Instructions (optional)',
                    labelStyle: TextStyle(color: AppTheme.breeze),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
                    ),
                    prefixIcon: Icon(Icons.note, color: AppTheme.breeze),
                  ),
                  maxLines: 2,
                ),

                SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
              
                // Special Requests Section
                Container(
                  padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.deepTeal.withOpacity(0.1), AppTheme.cloud.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.deepTeal.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            color: AppTheme.deepTeal,
                            size: ResponsiveUtils.getIconSize(context, baseSize: 18),
                          ),
                  SizedBox(width: ResponsiveUtils.getVerticalPadding(context) * 0.3),
                          SafeUI.safeText(
                            'Special Requests',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.deepTeal,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.3),
                      SafeUI.safeText(
                        'Add any special instructions, dietary preferences, or delivery preferences here',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                          color: AppTheme.breeze,
                          height: 1.3,
                        ),
                        maxLines: 2,
                      ),
                      SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
                      TextFormField(
                        controller: _deliveryInstructionsController,
                        decoration: InputDecoration(
                          hintText: 'e.g., "No onions please", "Call when arriving", "Leave at gate"',
                          hintStyle: TextStyle(
                            color: AppTheme.breeze.withOpacity(0.7),
                            fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                          ),
                          filled: true,
                          fillColor: AppTheme.angel,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.getHorizontalPadding(context) * 0.8,
                            vertical: ResponsiveUtils.getVerticalPadding(context) * 0.8,
                          ),
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
                    ],
                  ),
                ),
              ],
            ),
);
  }

  Widget _buildPaymentSection() {
    // Ensure we always have payment methods
    final availablePaymentMethods = _paymentMethods.isNotEmpty 
        ? _paymentMethods 
        : ['Bank Transfer (EFT)', 'PayFast (Card)', 'Cash on Delivery'];
    
    print('🔍 DEBUG: Building payment section with methods: $availablePaymentMethods');
    
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
      decoration: BoxDecoration(
        gradient: AppTheme.cardBackgroundGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.complementaryElevation,
        border: Border.all(
          color: AppTheme.breeze.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.payment,
                color: AppTheme.deepTeal,
                size: ResponsiveUtils.getIconSize(context, baseSize: 20),
              ),
              SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
              SafeUI.safeText(
                'Payment Method',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getTitleSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepTeal,
                ),
                maxLines: 1,
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
          
          // Always show payment methods dropdown
          DropdownButtonFormField<String>(
            value: _selectedPaymentMethod,
            items: availablePaymentMethods
                .map((m) => DropdownMenuItem(
                    value: m,
                    child: SafeUI.safeText(
                      m,
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                        color: AppTheme.deepTeal,
                      ),
                      maxLines: 1,
                    )))
                .toList(),
            onChanged: _isLoading ? null : (val) => setState(() => _selectedPaymentMethod = val),
            decoration: InputDecoration(
              labelText: 'Select Payment Method',
              labelStyle: TextStyle(color: AppTheme.breeze),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
              ),
              prefixIcon: Icon(Icons.credit_card, color: AppTheme.breeze),
            ),
            validator: (value) => value == null ? 'Please select a payment method' : null,
          ),
          
          // Payment method visual cues and security notes
          if (_selectedPaymentMethod != null) ...[
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
            Container(
              padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.cloud.withOpacity(0.1),
                    AppTheme.breeze.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.cloud.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedPaymentMethod == 'PayFast (Card)' 
                          ? AppTheme.deepTeal.withOpacity(0.2)
                          : _selectedPaymentMethod == 'Bank Transfer (EFT)'
                              ? AppTheme.deepTeal.withOpacity(0.2)
                              : AppTheme.breeze.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _selectedPaymentMethod == 'PayFast (Card)' 
                          ? Icons.credit_card
                          : _selectedPaymentMethod == 'Bank Transfer (EFT)'
                              ? Icons.account_balance
                              : Icons.money_off,
                      color: _selectedPaymentMethod == 'PayFast (Card)' 
                          ? AppTheme.deepTeal
                          : _selectedPaymentMethod == 'Bank Transfer (EFT)'
                              ? AppTheme.deepTeal
                              : AppTheme.breeze,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SafeUI.safeText(
                          _selectedPaymentMethod == 'PayFast (Card)' 
                              ? 'Secure Card Payment'
                              : _selectedPaymentMethod == 'Bank Transfer (EFT)'
                                  ? 'Bank Transfer'
                                  : 'Cash on Delivery',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                            fontWeight: FontWeight.w600,
                            color: _selectedPaymentMethod == 'PayFast (Card)' 
                                ? AppTheme.deepTeal
                                : _selectedPaymentMethod == 'Bank Transfer (EFT)'
                                    ? AppTheme.deepTeal
                                    : AppTheme.breeze,
                          ),
                          maxLines: 1,
                        ),
                        SafeUI.safeText(
                          _selectedPaymentMethod == 'PayFast (Card)' 
                              ? 'Your payment is protected by PayFast\'s secure gateway'
                              : _selectedPaymentMethod == 'Bank Transfer (EFT)'
                                  ? 'Transfer funds directly to our bank account'
                                  : 'Pay when you receive your order',
                                                      style: TextStyle(
                              fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                              color: AppTheme.breeze,
                              fontStyle: FontStyle.italic,
                            ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderSummary(double grandTotal) {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
      decoration: BoxDecoration(
        gradient: AppTheme.cardBackgroundGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.complementaryElevation,
        border: Border.all(
          color: AppTheme.breeze.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long,
                color: AppTheme.deepTeal,
                size: ResponsiveUtils.getIconSize(context, baseSize: 20),
              ),
              SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
              SafeUI.safeText(
                'Order Summary',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getTitleSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepTeal,
                ),
                maxLines: 1,
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SafeUI.safeText(
                'Subtotal',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getTitleSize(context),
                  color: AppTheme.breeze,
                ),
                maxLines: 1,
              ),
              SafeUI.safeText(
                'R${widget.totalPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getTitleSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepTeal,
                ),
                maxLines: 1,
                ),
              ],
            ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
          
          if (_isDelivery) ...[
            // Debug logging for delivery fee display
            Builder(
              builder: (context) {
                final displayFee = _deliveryFee ?? 15.0;
                print('🔍 DEBUG: Rendering delivery fee section');
                print('  - Is delivery: $_isDelivery');
                print('  - Delivery fee: $displayFee');
                print('  - Raw delivery fee: $_deliveryFee');
                return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
                    SafeUI.safeText(
                      'Delivery Fee',
            style: TextStyle(
                        fontSize: ResponsiveUtils.getTitleSize(context),
                        color: AppTheme.breeze,
            ),
                      maxLines: 1,
          ),
                    SafeUI.safeText(
                      'R${displayFee.toStringAsFixed(2)}',
            style: TextStyle(
                        fontSize: ResponsiveUtils.getTitleSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.deepTeal,
                      ),
                      maxLines: 1,
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.3),
            
            // Rural Delivery Widget
            if (_isRuralArea) ...[
              RuralDeliveryWidget(
                distance: _deliveryDistance,
                currentDeliveryFee: _deliveryFee ?? 0.0,
                onDeliveryOptionSelected: _onRuralDeliveryOptionSelected,
                isRuralArea: _isRuralArea,
              ),
              SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.3),
            ],
            
            // Urban Delivery Widget
            if (_isUrbanArea) ...[
              UrbanDeliveryWidget(
                distance: _deliveryDistance,
                currentDeliveryFee: _deliveryFee ?? 0.0,
                onDeliveryOptionSelected: _onUrbanDeliveryOptionSelected,
                isUrbanArea: _isUrbanArea,
                category: _productCategory,
                deliveryTime: DateTime.now(),
              ),
              SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.3),
            ],
          ] else ...[
            Builder(
              builder: (context) {
                double pickupDisplayFee = 0.0;
                if (_selectedPickupPoint != null) {
                  pickupDisplayFee = _selectedPickupPoint!.isPaxiPoint && _selectedPaxiDeliverySpeed != null
                      ? PaxiConfig.getPrice(_selectedPaxiDeliverySpeed!)
                      : _selectedPickupPoint!.fee;
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SafeUI.safeText(
                      'Pickup',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getTitleSize(context),
                        color: AppTheme.breeze,
                      ),
                      maxLines: 1,
                    ),
                    SafeUI.safeText(
                      'R${pickupDisplayFee.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getTitleSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.deepTeal,
                      ),
                      maxLines: 1,
                    ),
                  ],
                );
              },
            ),
          ],
          
          if (_isDelivery && _deliveryTimeMinutes != null) ...[
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.getHorizontalPadding(context) * 0.8,
                vertical: ResponsiveUtils.getVerticalPadding(context) * 0.5,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.cloud.withOpacity(0.2), AppTheme.breeze.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.cloud.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.cloud.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.schedule,
                      color: AppTheme.deepTeal,
                      size: ResponsiveUtils.getIconSize(context, baseSize: 16),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                  Expanded(
                    child: SafeUI.safeText(
                      'Estimated ${_isDelivery ? 'Delivery' : 'Pickup'}: $_deliveryTimeMinutes min',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                        color: AppTheme.deepTeal,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Show delivery/pickup instructions if added
          if (_deliveryInstructionsController.text.isNotEmpty) ...[
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.getHorizontalPadding(context) * 0.8,
                vertical: ResponsiveUtils.getVerticalPadding(context) * 0.5,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.deepTeal.withOpacity(0.1), AppTheme.cloud.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.deepTeal.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.deepTeal.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.note,
                      color: AppTheme.deepTeal,
                      size: ResponsiveUtils.getIconSize(context, baseSize: 16),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                  Expanded(
                    child: SafeUI.safeText(
                      'Special Request: ${_deliveryInstructionsController.text}',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                        color: AppTheme.deepTeal,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          Divider(
            height: ResponsiveUtils.getVerticalPadding(context) * 2,
            color: AppTheme.breeze.withOpacity(0.3),
            thickness: 1,
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SafeUI.safeText(
                'Total',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getTitleSize(context) + 4,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepTeal,
                ),
                maxLines: 1,
              ),
              SafeUI.safeText(
                'R${grandTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getTitleSize(context) + 6,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepTeal,
                ),
                maxLines: 1,
              ),
            ],
            ),
        ],
            ),
          );
        }

  Widget _buildPlaceOrderButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryButtonGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isLoading ? null : _submitOrder,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveUtils.getVerticalPadding(context) * 1.2,
              horizontal: ResponsiveUtils.getHorizontalPadding(context),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  color: AppTheme.angel,
                  size: ResponsiveUtils.getIconSize(context, baseSize: 24),
                ),
                SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                SafeUI.safeText(
                  _selectedPaymentMethod?.toLowerCase().contains('cash') == true 
                      ? 'Place Order' 
                      : 'Continue to Payment',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context) + 2,
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






}

// Enhanced AddressSearchScreen with suggestions
class AddressSearchScreen extends StatefulWidget {
  @override
  _AddressSearchScreenState createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Placemark> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    // Debounce the search to avoid too many API calls
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchAddresses();
    });
  }

  Future<void> _searchAddresses() async {
    final query = _searchController.text.trim();
    if (query.length < 3) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Search for addresses using geocoding
      final locations = await locationFromAddress(query);
      
      if (locations.isNotEmpty) {
        // Get detailed address information for each location
        List<Placemark> placemarks = [];
        for (final location in locations.take(5)) { // Limit to 5 results
          try {
            final placemarkList = await placemarkFromCoordinates(
              location.latitude,
              location.longitude,
            );
            if (placemarkList.isNotEmpty) {
              placemarks.addAll(placemarkList);
            }
  } catch (e) {
            print('Error getting placemark for location: $e');
          }
        }
        
        setState(() {
          _suggestions = placemarks;
          _isLoading = false;
        });
      } else {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
      }
  } catch (e) {
      print('Error searching addresses: $e');
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
    }
  }

  String _formatAddress(Placemark placemark) {
    List<String> parts = [];
    
    if (placemark.street != null && placemark.street!.isNotEmpty) {
      parts.add(placemark.street!);
    }
    if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
      parts.add(placemark.subLocality!);
    }
    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      parts.add(placemark.locality!);
    }
    if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
      parts.add(placemark.administrativeArea!);
    }
    if (placemark.postalCode != null && placemark.postalCode!.isNotEmpty) {
      parts.add(placemark.postalCode!);
    }
    
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Address'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: AppTheme.angel,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search input
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppTheme.deepTeal,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Enter your address',
                labelStyle: TextStyle(color: AppTheme.angel.withOpacity(0.8)),
                hintText: 'e.g., 123 Main Street, Johannesburg',
                hintStyle: TextStyle(color: AppTheme.angel.withOpacity(0.6)),
                filled: true,
                fillColor: AppTheme.angel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.search, color: AppTheme.deepTeal),
                suffixIcon: _isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
                          ),
                        ),
                      )
                    : null,
              ),
              style: TextStyle(color: AppTheme.deepTeal),
            ),
          ),
          
          // Suggestions list
          Expanded(
            child: _suggestions.isEmpty && !_isLoading
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final placemark = _suggestions[index];
                      final address = _formatAddress(placemark);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.location_on,
                            color: AppTheme.deepTeal,
                          ),
                          title: Text(
                            address,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.deepTeal,
                            ),
                          ),
                          subtitle: placemark.country != null
                              ? Text(
                                  placemark.country!,
                                  style: TextStyle(
                                    color: AppTheme.breeze,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                          onTap: () {
                            Navigator.pop(context, address);
                          },
                        ),
                      );
                    },
                  ),
          ),
          
          // Manual address entry option
          if (_suggestions.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Or use your own address:',
                    style: TextStyle(
                      color: AppTheme.breeze,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final address = _searchController.text.trim();
                        if (address.isNotEmpty) {
                          Navigator.pop(context, address);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter an address.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.deepTeal,
                        foregroundColor: AppTheme.angel,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Use Entered Address',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 64,
            color: AppTheme.breeze.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Search for your address',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.deepTeal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start typing to see address suggestions',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.breeze,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

