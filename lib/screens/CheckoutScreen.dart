import 'dart:async';
import 'package:flutter/material.dart';
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
import '../widgets/address_input_field.dart';

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
  // Platform fee is charged to seller, not buyer - removed platform fee variables
  int? _deliveryTimeMinutes;
  String? _selectedPaymentMethod;
  // Add delivery type selection
  String _selectedDeliveryType = 'platform'; // 'platform', 'seller', 'pickup'
  bool _isDelivery = true; // Keep for backward compatibility
  bool _sellerDeliveryAvailable = false; // Track if seller offers delivery
  List<String> _availableDeliveryTypes = ['pickup']; // Start with pickup only, update based on driver availability

  // Rural delivery variables
  bool _isRuralArea = false;
  String? _selectedRuralDeliveryType;
  double _ruralDeliveryFee = 0.0;
  
  // Urban delivery variables
  bool _isUrbanArea = false;
  String? _selectedUrbanDeliveryType;
  double _urbanDeliveryFee = 0.0;
  String _productCategory = 'other'; // Default category

  User? get currentUser => FirebaseAuth.instance.currentUser;

  // PayFast configuration for development/sandbox
  static const String payfastMerchantId = '10004002';
  static const String payfastMerchantKey = 'q1cd2rdny4a53';
  static const String payfastReturnUrl = 'https://your-app.com/payment/success';
  static const String payfastCancelUrl = 'https://your-app.com/payment/cancel';
  static const String payfastNotifyUrl = 'https://your-app.com/payment/notify';
  static const bool payfastSandbox = true; // Set to false for production

  // Add debounce timer for delivery fee calculation
  Timer? _deliveryFeeTimer;
  bool _isCalculatingDeliveryFee = false;
  bool _hasCalculatedForCurrentAddress = false;
  String _lastCalculatedAddress = '';

  @override
  void initState() {
    super.initState();
    _orderCompleted = false; // Reset order completion flag
    if (currentUser != null) {
      _calculateDeliveryFeeAndCheckStore();
    }
    _checkDriverAvailabilityOnLoad(); // Check driver availability when screen loads
  }

  // Check driver availability when screen loads
  Future<void> _checkDriverAvailabilityOnLoad() async {
    try {
      print('🔍 DEBUG: Checking driver availability on screen load...');
      
      // Query for any available drivers in the system
      final driversSnapshot = await FirebaseFirestore.instance
          .collection('drivers')
          .where('isAvailable', isEqualTo: true)
          .where('isOnline', isEqualTo: true)
          .get();
      
      if (driversSnapshot.docs.isEmpty) {
        print('🔍 DEBUG: No drivers available in system - showing pickup only');
        setState(() {
          _availableDeliveryTypes = ['pickup'];
          if (_selectedDeliveryType != 'pickup') {
            _selectedDeliveryType = 'pickup';
            _deliveryFee = 0.0;
            _deliveryDistance = 0.0;
          }
        });
        
        // Show notification to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ℹ️ No delivery drivers available. Pickup option selected.'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      } else {
        print('🔍 DEBUG: Found ${driversSnapshot.docs.length} drivers available - showing all delivery options');
        setState(() {
          _availableDeliveryTypes = ['pickup', 'platform', 'seller'];
        });
      }
    } catch (e) {
      print('🔍 DEBUG: Error checking driver availability on load: $e');
      // Default to pickup only on error
      setState(() {
        _availableDeliveryTypes = ['pickup'];
        if (_selectedDeliveryType != 'pickup') {
          _selectedDeliveryType = 'pickup';
          _deliveryFee = 0.0;
          _deliveryDistance = 0.0;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _deliveryInstructionsController.dispose();
    _addressFocusNode.dispose();
    _deliveryFeeTimer?.cancel();
    super.dispose();
  }

  // Debounced delivery fee calculation
  void _debouncedCalculateDeliveryFee() {
    final currentAddress = _addressController.text.trim();
    print('🔍 _debouncedCalculateDeliveryFee called with address: "$currentAddress"');
    
    // Don't recalculate if we already calculated for this address
    if (_hasCalculatedForCurrentAddress && _lastCalculatedAddress == currentAddress) {
      print('🔍 Already calculated for this address, skipping...');
      return;
    }
    
    print('🔍 Setting up debounced calculation timer...');
    _deliveryFeeTimer?.cancel();
    _deliveryFeeTimer = Timer(const Duration(milliseconds: 500), () {
      print('🔍 Timer fired, calling _calculateDeliveryFee...');
      if (!_isCalculatingDeliveryFee) {
        _calculateDeliveryFee();
        _hasCalculatedForCurrentAddress = true;
        _lastCalculatedAddress = currentAddress;
      } else {
        print('🔍 Already calculating delivery fee, skipping...');
      }
    });
  }

  // Calculate delivery fee based on selected delivery type
  Future<void> _calculateDeliveryFee() async {
    if (_isCalculatingDeliveryFee) return;
    
    _isCalculatingDeliveryFee = true;
    
    try {
      print('🔍 DEBUG: Starting delivery fee calculation for type: $_selectedDeliveryType');
      
      // Only calculate fees for available delivery types
      if (!_availableDeliveryTypes.contains(_selectedDeliveryType)) {
        print('🔍 DEBUG: Selected delivery type not available: $_selectedDeliveryType');
        setState(() {
          _deliveryFee = 0.0;
          _deliveryDistance = 0.0;
        });
        return;
      }
      
      switch (_selectedDeliveryType) {
        case 'pickup':
          setState(() {
            _deliveryFee = 0.0;
            _deliveryDistance = 0.0;
          });
          break;
        case 'platform':
          await _calculatePlatformDeliveryFee();
          break;
        case 'seller':
          await _calculateSellerDeliveryFee();
          break;
        default:
          setState(() {
            _deliveryFee = 0.0;
            _deliveryDistance = 0.0;
          });
      }
    } catch (e) {
      print('🔍 DEBUG: Error in delivery fee calculation: $e');
      setState(() {
        _deliveryFee = 0.0;
        _deliveryDistance = 0.0;
      });
    } finally {
      _isCalculatingDeliveryFee = false;
    }
  }

  // Check driver availability for the location
  Future<bool> _checkDriverAvailability(double latitude, double longitude) async {
    try {
      print('🔍 DEBUG: Checking driver availability for location: $latitude, $longitude');
      
      // Query for available drivers within 20km radius
      final driversSnapshot = await FirebaseFirestore.instance
          .collection('drivers')
          .where('isAvailable', isEqualTo: true)
          .where('isOnline', isEqualTo: true)
          .get();
      
      if (driversSnapshot.docs.isEmpty) {
        print('🔍 DEBUG: No drivers found in database');
        return false;
      }
      
      // Check if any drivers are within reasonable distance
      for (var doc in driversSnapshot.docs) {
        final driverData = doc.data();
        final driverLat = driverData['latitude'] as double? ?? 0.0;
        final driverLng = driverData['longitude'] as double? ?? 0.0;
        final maxDistance = driverData['maxDistance'] as double? ?? 20.0;
        
        if (driverLat != 0.0 && driverLng != 0.0) {
          final distance = Geolocator.distanceBetween(
            latitude, longitude, driverLat, driverLng,
          ) / 1000; // Convert to km
          
          if (distance <= maxDistance) {
            print('🔍 DEBUG: Found available driver within ${distance.toStringAsFixed(1)}km');
            return true;
          }
        }
      }
      
      print('🔍 DEBUG: No drivers available within reasonable distance');
      return false;
    } catch (e) {
      print('🔍 DEBUG: Error checking driver availability: $e');
      return false;
    }
  }

  // Show available delivery options based on driver availability
  void _updateAvailableDeliveryOptions(bool driversAvailable) {
    setState(() {
      if (!driversAvailable) {
        // Only show pickup when no drivers are available
        _availableDeliveryTypes = ['pickup'];
        if (_selectedDeliveryType != 'pickup') {
          _selectedDeliveryType = 'pickup';
          _deliveryFee = 0.0;
          _deliveryDistance = 0.0;
        }
      } else {
        // Show all delivery options when drivers are available
        _availableDeliveryTypes = ['pickup', 'platform', 'seller'];
      }
    });
  }

  // Calculate platform delivery fee
  Future<void> _calculatePlatformDeliveryFee() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      print('🔍 DEBUG: No address provided for delivery fee calculation');
      setState(() {
        _deliveryFee = 0.0; // No delivery fee if no address
        _deliveryDistance = 0.0;
      });
      return;
    }
    
    print('🔍 DEBUG: Calculating platform delivery fee for address: $address');
    
    try {
      // More lenient address validation
      if (address.length < 3) {
        print('🔍 DEBUG: Address too short: $address');
        setState(() {
          _deliveryFee = 0.0; // No delivery fee for invalid address
          _deliveryDistance = 0.0;
        });
        return;
      }
      
      // Get user's location from address with better error handling
      List<Location> locations;
      try {
        print('🔍 DEBUG: Attempting to geocode address: $address');
        
        // Add timeout to prevent hanging
        locations = await locationFromAddress(address).timeout(
          const Duration(seconds: 15), // Increased timeout
          onTimeout: () {
            print('🔍 DEBUG: Geocoding timeout for address: $address');
            throw TimeoutException('Geocoding timeout', const Duration(seconds: 15));
          },
        );
        
        print('🔍 DEBUG: Geocoding successful, found ${locations.length} locations');
      } catch (e) {
        print('🔍 DEBUG: Geocoding error for address "$address": $e');
        
        // Try with a more specific address format
        try {
          final enhancedAddress = '$address, South Africa';
          print('🔍 DEBUG: Retrying with enhanced address: $enhancedAddress');
          
          locations = await locationFromAddress(enhancedAddress).timeout(
            const Duration(seconds: 10),
          );
          print('🔍 DEBUG: Enhanced geocoding successful, found ${locations.length} locations');
        } catch (retryError) {
          print('🔍 DEBUG: Enhanced geocoding also failed: $retryError');
          setState(() {
            _deliveryFee = 0.0; // No delivery fee if geocoding fails
            _deliveryDistance = 0.0;
          });
          return;
        }
      }
      
      if (locations.isEmpty) {
        print('🔍 DEBUG: Could not geocode address: $address');
        setState(() {
          _deliveryFee = 0.0; // No delivery fee if no location found
          _deliveryDistance = 0.0;
        });
        return;
      }
    
      final userLocation = locations.first;
      if (userLocation.latitude == null || userLocation.longitude == null) {
        print('🔍 DEBUG: Invalid location coordinates from geocoding');
        setState(() {
          _deliveryFee = 0.0; // No delivery fee for invalid coordinates
          _deliveryDistance = 0.0;
        });
        return;
      }
      
      print('🔍 DEBUG: User location: ${userLocation.latitude}, ${userLocation.longitude}');
      
      // Check driver availability for this location
      final driversAvailable = await _checkDriverAvailability(
        userLocation.latitude!, 
        userLocation.longitude!
      );
      
      if (!driversAvailable) {
        print('🔍 DEBUG: No drivers available in this location');
        // Show pickup option only when no drivers are available
        _updateAvailableDeliveryOptions(false);
        
        // Show notification to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ No delivery drivers available in your area. Pickup option selected.'),
            backgroundColor: AppTheme.warning,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
        return;
      }
      
      // Update available delivery options
      _updateAvailableDeliveryOptions(true);
      
      // Calculate distance to a central point (you can adjust this)
      // For now, using a central point in Johannesburg
      const double centralLat = -26.2041; // Johannesburg latitude
      const double centralLng = 28.0473;  // Johannesburg longitude
      
      final distance = Geolocator.distanceBetween(
        userLocation.latitude!,
        userLocation.longitude!,
        centralLat,
        centralLng,
      );
      
      print('🔍 DEBUG: Distance calculated: ${(distance/1000).toStringAsFixed(1)}km');
    
      // Calculate delivery fee based on distance
      double deliveryFee = 0.0;
      if (distance <= 5000) { // Within 5km
        deliveryFee = 20.0;
      } else if (distance <= 10000) { // Within 10km
        deliveryFee = 35.0;
      } else if (distance <= 15000) { // Within 15km
        deliveryFee = 50.0;
      } else {
        deliveryFee = 75.0; // Beyond 15km
      }
      
      setState(() {
        _deliveryDistance = distance;
        _deliveryFee = deliveryFee;
      });
        
      print('🔍 DEBUG: Platform delivery fee calculated: R${deliveryFee.toStringAsFixed(2)} for ${(distance/1000).toStringAsFixed(1)}km');
    } catch (e) {
      print('🔍 DEBUG: Error in platform delivery fee calculation: $e');
      // Set no delivery fee on error instead of default R25
      setState(() {
        _deliveryFee = 0.0; // No delivery fee on error
        _deliveryDistance = 0.0;
      });
    }
  }

  /// Validate address format
  bool _isValidAddress(String address) {
    if (address.isEmpty) return false;
    
    // Check for minimum length
    if (address.length < 5) return false;
    
    // Check for basic address components - more lenient now
    final hasStreet = address.contains(RegExp(r'\d+')) || 
                     address.toLowerCase().contains('street') ||
                     address.toLowerCase().contains('road') ||
                     address.toLowerCase().contains('avenue') ||
                     address.toLowerCase().contains('drive') ||
                     address.toLowerCase().contains('lane') ||
                     address.toLowerCase().contains('close') ||
                     address.toLowerCase().contains('way');
    
    final hasCity = address.toLowerCase().contains('brakpan') ||
                   address.toLowerCase().contains('gauteng') ||
                   address.toLowerCase().contains('johannesburg') ||
                   address.toLowerCase().contains('pretoria') ||
                   address.toLowerCase().contains('cape town') ||
                   address.toLowerCase().contains('durban') ||
                   address.toLowerCase().contains('bloemfontein') ||
                   address.toLowerCase().contains('port elizabeth') ||
                   address.toLowerCase().contains('kempton park');
    
    // More lenient validation - accept if it has either street indicators or city names
    return hasStreet || hasCity || address.length >= 10; // Accept longer addresses even without specific keywords
  }

  // Calculate seller delivery fee
  Future<void> _calculateSellerDeliveryFee() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      print('🔍 DEBUG: No address provided for seller delivery fee calculation');
      return;
    }
    
    print('🔍 DEBUG: Calculating seller delivery fee for address: $address');
    
    try {
      // Validate address format before proceeding
      if (!_isValidAddress(address)) {
        print('🔍 DEBUG: Invalid address format for seller delivery: $address');
        setState(() {
          _deliveryFee = 25.0; // Default delivery fee
          _deliveryDistance = 0.0;
        });
        return;
      }
    
    // Get seller data
    final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('🔍 DEBUG: No current user found');
        return;
      }
    
    final cartSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('cart')
        .get();
    
      if (cartSnapshot.docs.isEmpty) {
        print('🔍 DEBUG: No cart items found');
        return;
      }
    
    final firstCartItem = cartSnapshot.docs.first.data();
    final sellerId = firstCartItem['sellerId'] ?? firstCartItem['ownerId'];
    
      if (sellerId == null) {
        print('🔍 DEBUG: No seller ID found in cart items');
        return;
      }
    
    final sellerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(sellerId)
        .get();
    
      if (!sellerDoc.exists) {
        print('🔍 DEBUG: Seller document not found');
        return;
      }
    
    final sellerData = sellerDoc.data()!;
    
    // Check if seller offers delivery
    final sellerDeliveryEnabled = sellerData['sellerDeliveryEnabled'] ?? false;
    if (!sellerDeliveryEnabled) {
      print('🔍 DEBUG: Seller does not offer delivery');
      setState(() {
        _selectedDeliveryType = 'pickup';
        _deliveryFee = 0.0;
        _deliveryDistance = 0.0;
      });
      return;
    }
    
      // Get user location for driver availability check
      List<Location> locations;
      try {
        locations = await locationFromAddress(address).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Geocoding timeout', const Duration(seconds: 10));
          },
        );
      } catch (e) {
        print('🔍 DEBUG: Geocoding error for seller delivery: $e');
        // If we can't get location, assume no drivers available
        _updateAvailableDeliveryOptions(false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Unable to verify delivery availability. Pickup option selected.'),
            backgroundColor: AppTheme.warning,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      
      if (locations.isNotEmpty) {
        final userLocation = locations.first;
        if (userLocation.latitude != null && userLocation.longitude != null) {
          // Check driver availability for seller delivery
          final driversAvailable = await _checkDriverAvailability(
            userLocation.latitude!,
            userLocation.longitude!
          );
          
          if (!driversAvailable) {
            print('🔍 DEBUG: No drivers available for seller delivery');
            _updateAvailableDeliveryOptions(false);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ No delivery drivers available. Pickup option selected.'),
                backgroundColor: AppTheme.warning,
                duration: const Duration(seconds: 3),
              ),
            );
            return;
          }
        }
      }
      
      // Calculate seller delivery fee with null safety
    final baseFee = (sellerData['sellerDeliveryBaseFee'] ?? 25.0).toDouble();
    final feePerKm = (sellerData['sellerDeliveryFeePerKm'] ?? 2.0).toDouble();
    final maxFee = (sellerData['sellerDeliveryMaxFee'] ?? 50.0).toDouble();
    
    // For now, use a simple calculation (you can enhance this with actual distance)
    double deliveryFee = baseFee;
    deliveryFee = deliveryFee.clamp(0.0, maxFee).toDouble();
    
    setState(() {
      _deliveryFee = deliveryFee;
      _deliveryDistance = 0.0; // Seller delivery doesn't use distance calculation
    });
    
      print('🔍 DEBUG: Seller delivery fee calculated: R${deliveryFee.toStringAsFixed(2)}');
    } catch (e) {
      print('🔍 DEBUG: Error in seller delivery fee calculation: $e');
      // Set default values on error
      setState(() {
        _deliveryFee = 25.0; // Default delivery fee
        _deliveryDistance = 0.0;
      });
    }
  }

  Future<void> _calculateDeliveryFeeAndCheckStore() async {
    if (currentUser == null) {
      print('🔍 DEBUG: No current user, skipping delivery calculation');
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
        return;
      }
      
      // Get the first cart item to determine seller
      final firstCartItem = cartSnapshot.docs.first.data();
      final sellerId = firstCartItem['sellerId'] ?? firstCartItem['ownerId'];
      
      if (sellerId == null) {
        print('🔍 DEBUG: No seller ID found in cart items');
        return;
      }
      
      print('🔍 DEBUG: Found seller ID: $sellerId');
      
      // Fetch seller information
      final sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .get();
      
      if (!sellerDoc.exists) {
        print('🔍 DEBUG: Seller document not found: $sellerId');
        return;
      }
      
      final sellerData = sellerDoc.data()!;
      print('🔍 DEBUG: Seller data: ${sellerData['displayName'] ?? 'Unknown'}');
      
      // Update state with seller information
      setState(() {
        _storeName = sellerData['displayName'] ?? 'Unknown Store';
        _storeOpen = sellerData['isOpen'] ?? true;
        _minOrderForDelivery = (sellerData['minOrderForDelivery'] ?? 0.0).toDouble();
        
        // Handle delivery hours - could be string or int
        final deliveryStartHourRaw = sellerData['deliveryStartHour'];
        if (deliveryStartHourRaw is String) {
          _deliveryStartHour = int.tryParse(deliveryStartHourRaw.split(':')[0]) ?? 8;
        } else {
          _deliveryStartHour = (deliveryStartHourRaw as int?) ?? 8;
        }
        
        final deliveryEndHourRaw = sellerData['deliveryEndHour'];
        if (deliveryEndHourRaw is String) {
          _deliveryEndHour = int.tryParse(deliveryEndHourRaw.split(':')[0]) ?? 20;
        } else {
          _deliveryEndHour = (deliveryEndHourRaw as int?) ?? 20;
        }
        
        _storeOpenHour = sellerData['storeOpenHour'] ?? '08:00';
        _storeCloseHour = sellerData['storeCloseHour'] ?? '20:00';
        _paymentMethods = List<String>.from(sellerData['paymentMethods'] ?? ['Cash on Delivery']);
        _excludedZones = List<String>.from(sellerData['excludedZones'] ?? []);
        _deliveryTimeMinutes = sellerData['deliveryTimeMinutes'] ?? 30;
        _sellerDeliveryAvailable = sellerData['sellerDeliveryEnabled'] ?? false;
      });
      
      print('🔍 DEBUG: Store settings loaded - Name: $_storeName, Open: $_storeOpen, Min Order: $_minOrderForDelivery, Seller Delivery: $_sellerDeliveryAvailable');
      
      // If seller doesn't offer delivery and current selection is seller, switch to platform
      if (!_sellerDeliveryAvailable && _selectedDeliveryType == 'seller') {
        setState(() {
          _selectedDeliveryType = 'platform';
        });
        print('🔍 DEBUG: Seller does not offer delivery, switched to platform delivery');
      }
      
      // Calculate delivery fee based on address
      await _calculateDeliveryFee();
      
    } catch (e) {
      print('❌ Error calculating delivery fee: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    
    return Scaffold(
      backgroundColor: AppTheme.whisper,
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: Colors.white,
        leading: const HomeNavigationButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () => Navigator.pushNamed(context, '/cart'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Information Section
                _buildCustomerInfoSection(),
                SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
              
                // Delivery/Pickup Toggle
                Container(
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
                            _isDelivery ? Icons.delivery_dining : Icons.store,
                            color: AppTheme.deepTeal,
                            size: ResponsiveUtils.getIconSize(context, baseSize: 20),
                          ),
                          SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                          SafeUI.safeText(
                            'Order Type',
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
                      // Dynamic delivery type selection based on availability
                      Row(
                        children: _availableDeliveryTypes.map((deliveryType) {
                          bool isSelected = _selectedDeliveryType == deliveryType;
                          bool isAvailable = deliveryType == 'pickup' || 
                                           (deliveryType == 'platform' && _availableDeliveryTypes.contains('platform')) ||
                                           (deliveryType == 'seller' && _sellerDeliveryAvailable && _availableDeliveryTypes.contains('seller'));
                          
                          return Expanded(
                            child: GestureDetector(
                              onTap: isAvailable ? () {
                                setState(() => _selectedDeliveryType = deliveryType);
                                // Trigger delivery fee calculation when switching delivery types
                                if (_addressController.text.trim().isNotEmpty && deliveryType != 'pickup') {
                                  _debouncedCalculateDeliveryFee();
                                } else if (deliveryType == 'pickup') {
                                  // Clear delivery fee when switching to pickup
                                  setState(() {
                                    _deliveryFee = 0.0;
                                    _deliveryDistance = 0.0;
                                  });
                                }
                              } : null,
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.deepTeal : 
                                         isAvailable ? Colors.grey.shade200 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.deepTeal : 
                                           isAvailable ? Colors.grey.shade300 : Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      deliveryType == 'platform' ? Icons.delivery_dining :
                                      deliveryType == 'seller' ? Icons.local_shipping :
                                      Icons.store,
                                      color: isSelected ? Colors.white : 
                                             isAvailable ? Colors.grey.shade600 : Colors.grey.shade400,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      deliveryType == 'platform' ? 'Platform' :
                                      deliveryType == 'seller' ? 'Seller' : 'Pickup',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : 
                                               isAvailable ? Colors.grey.shade600 : Colors.grey.shade400,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (!isAvailable && deliveryType != 'pickup')
                                      Text(
                                        '(Unavailable)',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontWeight: FontWeight.w400,
                                          fontSize: 10,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
              
                // Address Field with Suggestions
                AddressInputField(
                  controller: _addressController,
                  labelText: 'Delivery Address',
                  hintText: 'Enter your delivery address',
                  onAddressSelected: (String address) {
                    print('📍 Selected address: $address');
                      _debouncedCalculateDeliveryFee();
                  },
                ),
              
                // Delivery Fee Notice (only show for delivery)
                if (_selectedDeliveryType != 'pickup' && _addressController.text.trim().isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.warning, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Enter your delivery address to calculate delivery fee',
                            style: TextStyle(
                              color: AppTheme.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              
                // Delivery Fee Loading (when calculating)
                if (_selectedDeliveryType != 'pickup' && _addressController.text.trim().isNotEmpty && _deliveryFee == null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.deepTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Calculating delivery fee...',
                            style: TextStyle(
                              color: AppTheme.deepTeal,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              
                // Delivery Fee Display (when calculated)
                if (_selectedDeliveryType != 'pickup' && _deliveryFee != null && _deliveryFee! > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.delivery_dining, color: AppTheme.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Delivery Fee: R${_deliveryFee!.toStringAsFixed(2)} (${_deliveryDistance.toStringAsFixed(1)}km)',
                            style: TextStyle(
                              color: AppTheme.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                    // More lenient phone validation - accept various formats
                    final phoneReg = RegExp(r'^[\+]?[\d\s\-\(\)]{10,15}$');
                    if (!phoneReg.hasMatch(value)) return 'Enter a valid phone number';
                    return null;
                  },
                ),
                SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
              
                // Delivery Instructions
                TextFormField(
                  controller: _deliveryInstructionsController,
                  decoration: InputDecoration(
                    labelText: _selectedDeliveryType == 'pickup' ? 'Pickup Instructions (optional)' : 'Delivery Instructions (optional)',
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
              
                // Payment Section
                _buildPaymentSection(),
                SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
              
                // Order Summary
                _buildOrderSummary(widget.totalPrice + (_selectedDeliveryType == 'pickup' ? 0 : (_deliveryFee ?? 0))),
                SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
              
                // Place Order Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _placeOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.deepTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Place Order',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                color: AppTheme.deepTeal,
                size: ResponsiveUtils.getIconSize(context, baseSize: 20),
              ),
              SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
              SafeUI.safeText(
                'Customer Information',
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
              prefixIcon: Icon(Icons.person_outline, color: AppTheme.breeze),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your name';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    final availablePaymentMethods = _paymentMethods.isNotEmpty 
        ? _paymentMethods 
        : ['Cash on Delivery', 'PayFast', 'Card Payment'];
    
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
                Icons.receipt,
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
          
          _buildSummaryRow('Subtotal', 'R${widget.totalPrice.toStringAsFixed(2)}'),
          if (_selectedDeliveryType != 'pickup' && _deliveryFee != null && _deliveryFee! > 0)
            _buildSummaryRow('Delivery Fee', 'R${_deliveryFee!.toStringAsFixed(2)}'),
          Divider(color: AppTheme.breeze.withOpacity(0.3)),
          _buildSummaryRow(
            'Total',
            'R${grandTotal.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? ResponsiveUtils.getTitleSize(context) : ResponsiveUtils.getBodySize(context),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? AppTheme.deepTeal : AppTheme.mediumGrey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? ResponsiveUtils.getTitleSize(context) : ResponsiveUtils.getBodySize(context),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? AppTheme.deepTeal : AppTheme.mediumGrey,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _placeOrder() async {
    if (_orderCompleted) {
      print('🔍 DEBUG: Order already completed, preventing duplicate');
      return;
    }
    
    print('🔍 DEBUG: Starting form validation...');
    print('🔍 DEBUG: Name: "${_nameController.text.trim()}"');
    print('🔍 DEBUG: Phone: "${_phoneController.text.trim()}"');
    print('🔍 DEBUG: Address: "${_addressController.text.trim()}"');
    print('🔍 DEBUG: Payment Method: "$_selectedPaymentMethod"');
    
    if (!_formKey.currentState!.validate()) {
      print('🔍 DEBUG: Form validation failed');
      return;
    }
    
    print('🔍 DEBUG: Form validation passed');
    
    // Check if payment method is selected
    if (_selectedPaymentMethod == null || _selectedPaymentMethod!.isEmpty) {
      print('🔍 DEBUG: No payment method selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please select a payment method'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
      return;
    }
    
    print('🔍 DEBUG: Payment method selected: $_selectedPaymentMethod');
    
    // Ensure delivery fee is calculated
    if (_deliveryFee == null) {
      print('🔍 DEBUG: Delivery fee not calculated, setting default');
      setState(() {
        _deliveryFee = 25.0; // Default delivery fee
        _deliveryDistance = 5.0; // Default distance
      });
    }
    
    print('🔍 DEBUG: Delivery fee: $_deliveryFee, Distance: $_deliveryDistance');
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Get cart items first to check seller
      final cartSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('cart')
          .get();
      
      if (cartSnapshot.docs.isEmpty) {
        throw Exception('Cart is empty');
      }
      
      final cartItems = cartSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'productId': doc.id,
          'name': data['name'],
          'price': data['price'],
          'quantity': data['quantity'],
          'imageUrl': data['imageUrl'],
          'sellerId': data['sellerId'] ?? data['ownerId'],
        };
      }).toList();
      
      // Get seller ID from first item
      final sellerId = cartItems.first['sellerId'];
      
      // 🔒 VALIDATION 1: Prevent seller from buying from their own store
      if (currentUser.uid == sellerId) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ You cannot purchase from your own store'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
        return;
      }
      
      // 🔒 VALIDATION 2: Check if store is open
      final sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .get();
      
      if (!sellerDoc.exists) {
        throw Exception('Seller not found');
      }
      
      final sellerData = sellerDoc.data()!;
      final isStoreOpen = sellerData['isStoreOpen'] ?? false;
      
      if (!isStoreOpen) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Store is currently closed. Please try again later.'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
        return;
      }
      
      // 🔒 VALIDATION 3: Check delivery requirements
      if (_selectedDeliveryType != 'pickup') {
        if (_addressController.text.trim().isEmpty) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Please enter a delivery address'),
              backgroundColor: AppTheme.primaryRed,
            ),
          );
          return;
        }
        
        // Check if seller offers delivery
        final deliveryAvailable = sellerData['deliveryAvailable'] ?? false;
        if (!deliveryAvailable) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ This store does not offer delivery. Please select pickup.'),
              backgroundColor: AppTheme.primaryRed,
            ),
          );
          return;
        }
      }
      
      // Generate order number
      final now = DateTime.now();
      final orderNumber = 'ORD-${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}-${(now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0')}';
      
      print('🔍 DEBUG: Generated order number: $orderNumber');
      
      // Create order document
      final orderData = {
        'orderId': orderNumber,
        'orderNumber': orderNumber, // Add orderNumber field for compatibility
        'buyerId': currentUser.uid,
        'buyerName': _nameController.text.trim(),
        'buyerPhone': _phoneController.text.trim(),
        'buyerAddress': _addressController.text.trim(),
        'deliveryInstructions': _deliveryInstructionsController.text.trim(),
        'deliveryType': _selectedDeliveryType,
        'deliveryDistance': _deliveryDistance,
        'deliveryFee': _selectedDeliveryType == 'pickup' ? 0.0 : (_deliveryFee ?? 0.0),
        'subtotal': widget.totalPrice,
        'totalPrice': widget.totalPrice + (_selectedDeliveryType == 'pickup' ? 0 : (_deliveryFee ?? 0)),
        'total': widget.totalPrice + (_selectedDeliveryType == 'pickup' ? 0 : (_deliveryFee ?? 0)),
        'paymentMethod': _selectedPaymentMethod ?? 'Cash on Delivery',
        'status': 'pending',
        'orderDate': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(), // Add timestamp field for compatibility
        'items': cartItems,
        'sellerId': sellerId,
        'sellerName': _storeName ?? 'Store',
        'estimatedDeliveryTime': _deliveryTimeMinutes ?? 30,
        'deliveryStartHour': _deliveryStartHour ?? 8,
        'deliveryEndHour': _deliveryEndHour ?? 20,
        'minOrderForDelivery': _minOrderForDelivery ?? 0.0,
        'storeOpen': _storeOpen ?? true,
        'excludedZones': _excludedZones,
        'paymentMethods': _paymentMethods,
        // Add additional fields for compatibility with seller order processing
        'name': _nameController.text.trim(), // Legacy field
        'phone': _phoneController.text.trim(), // Legacy field
        'address': _addressController.text.trim(), // Legacy field
        'deliveryAddress': _addressController.text.trim(), // Alternative field name
        'paymentStatus': 'pending', // Add payment status
      };
      
      // Save order to Firestore
      final orderRef = await FirebaseFirestore.instance
          .collection('orders')
          .add(orderData);
      
      print('🔍 DEBUG: Order saved with ID: ${orderRef.id}');
      
      // Clear cart
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in cartSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      // Clear local cart provider state
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.clearCart();
      
      print('🔍 DEBUG: Cart cleared');
      
      // Send notifications
      await _sendOrderNotifications(orderRef.id, sellerId, orderNumber);
      
      setState(() {
        _orderCompleted = true;
        _isLoading = false;
      });
      
      // Navigate to order tracking
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrderTrackingScreen(orderId: orderRef.id),
          ),
        );
      }
      
    } catch (e) {
      print('❌ Error placing order: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error placing order: $e'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    }
  }

  Future<void> _sendOrderNotifications(String orderId, String sellerId, String orderNumber) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ ERROR: No authenticated user found for notifications');
        return;
      }
      
      print('🔍 DEBUG: Starting notification process...');
      print('🔍 DEBUG: Order ID: $orderId');
      print('🔍 DEBUG: Seller ID: $sellerId');
      print('🔍 DEBUG: Buyer ID: ${currentUser.uid}');
      print('🔍 DEBUG: Buyer Name: ${_nameController.text.trim()}');
      print('🔍 DEBUG: Order Total: ${widget.totalPrice + (_selectedDeliveryType == 'pickup' ? 0 : (_deliveryFee ?? 0))}');
      
      // Send notification to seller
      print('🔍 DEBUG: Sending notification to seller...');
      await NotificationService().sendNewOrderNotificationToSeller(
        sellerId: sellerId,
        orderId: orderId,
        buyerName: _nameController.text.trim(),
        orderTotal: widget.totalPrice + (_selectedDeliveryType == 'pickup' ? 0 : (_deliveryFee ?? 0)),
        sellerName: _storeName ?? 'Store',
      );
      print('🔍 DEBUG: Seller notification sent');
      
      // Send notification to buyer
      print('🔍 DEBUG: Sending notification to buyer...');
      await NotificationService().sendOrderStatusNotificationToBuyer(
        buyerId: currentUser.uid,
        orderId: orderId,
        status: 'pending',
        sellerName: _storeName ?? 'Store',
      );
      print('🔍 DEBUG: Buyer notification sent');
      
      print('🔍 DEBUG: Order notifications sent successfully');
      
    } catch (e) {
      print('❌ Error sending order notifications: $e');
      print('❌ Error stack trace: ${StackTrace.current}');
    }
  }
}

// Utility classes for responsive design
class ResponsiveUtils {
  static double getHorizontalPadding(BuildContext context) {
    return MediaQuery.of(context).size.width < 768 ? 16 : 24;
  }
  
  static double getVerticalPadding(BuildContext context) {
    return MediaQuery.of(context).size.width < 768 ? 16 : 20;
  }
  
  static double getTitleSize(BuildContext context) {
    return MediaQuery.of(context).size.width < 768 ? 18 : 20;
  }
  
  static double getBodySize(BuildContext context) {
    return MediaQuery.of(context).size.width < 768 ? 14 : 16;
  }
  
  static double getIconSize(BuildContext context, {double baseSize = 20}) {
    return MediaQuery.of(context).size.width < 768 ? baseSize - 2 : baseSize;
  }
}

class SafeUI {
  static Widget safeText(String text, {
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}


