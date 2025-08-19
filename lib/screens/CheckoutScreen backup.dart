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
import '../services/courier_quote_service.dart';

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
  double? _platformFeePercent;
  double _platformFee = 0.0;
  bool _isStoreFeeExempt = false;
  int? _deliveryTimeMinutes;
  String? _selectedPaymentMethod;
  // Add delivery type selection
  String _selectedDeliveryType = 'platform'; // 'platform', 'seller', 'pickup'
  bool _isDelivery = true; // Keep for backward compatibility
  bool _sellerDeliveryAvailable = false; // Track if seller offers delivery

  // Rural delivery variables
  bool _isRuralArea = false;
  String? _selectedRuralDeliveryType;
  double _ruralDeliveryFee = 0.0;
  
  // Urban delivery variables
  bool _isUrbanArea = false;
  String? _selectedUrbanDeliveryType;
  double _urbanDeliveryFee = 0.0;
  String _productCategory = 'other'; // Default category

  // Pargo pickup points variables
  List<Map<String, dynamic>> _pargoPickupPoints = [];
  String? _selectedPargoPickupPoint;
  bool _isPargoAvailable = false;
  double _pargoDeliveryFee = 0.0;

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

  // Pickup points loading variables
  bool _isLoadingPickupPoints = false;
  List<Map<String, dynamic>> _pickupPoints = [];
  Map<String, dynamic>? _selectedPickupPoint;
  double _selectedLat = 0.0;
  double _selectedLng = 0.0;
  List<dynamic> _addressSuggestions = [];
  bool _isSearchingAddress = false;
  Timer? _addressSearchTimer;

  @override
  void initState() {
    super.initState();
    _orderCompleted = false; // Reset order completion flag
    if (currentUser != null) {
      _calculateDeliveryFeeAndCheckStore();
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
    
    // Don't recalculate if we already calculated for this address
    if (_hasCalculatedForCurrentAddress && _lastCalculatedAddress == currentAddress) {
      print('🔍 Already calculated for this address, skipping...');
      return;
    }
    
    _deliveryFeeTimer?.cancel();
    _deliveryFeeTimer = Timer(const Duration(milliseconds: 500), () {
      if (!_isCalculatingDeliveryFee) {
        _calculateDeliveryFee();
        _hasCalculatedForCurrentAddress = true;
        _lastCalculatedAddress = currentAddress;
      }
    });
  }

  // Calculate delivery fee based on selected type
  Future<void> _calculateDeliveryFee() async {
    if (_isCalculatingDeliveryFee) {
      print('🔍 DEBUG: Already calculating delivery fee, skipping...');
      return;
    }
    
    try {
      _isCalculatingDeliveryFee = true;
      print('🔍 DEBUG: Starting delivery fee calculation for type: $_selectedDeliveryType');
      
      // Update _isDelivery based on selected type
      _isDelivery = _selectedDeliveryType != 'pickup';
      
      switch (_selectedDeliveryType) {
        case 'pickup':
          setState(() {
            _deliveryFee = 0.0;
            _deliveryDistance = 0.0;
            _platformFee = 0.0;
          });
          break;
          
        case 'seller':
          // Check if seller offers delivery
          if (!_sellerDeliveryAvailable) {
            print('🔍 DEBUG: Seller does not offer delivery, switching to pickup');
            setState(() {
              _selectedDeliveryType = 'pickup';
              _deliveryFee = 0.0;
              _deliveryDistance = 0.0;
              _platformFee = 0.0;
            });
            return;
          }
          // Calculate seller delivery fee
          await _calculateSellerDeliveryFee();
          break;
          
        case 'platform':
        default:
          // Calculate platform delivery fee
          await _calculatePlatformDeliveryFee();
          break;
      }
      
    } catch (e) {
      print('❌ Error calculating delivery fee: $e');
    } finally {
      _isCalculatingDeliveryFee = false;
    }
  }

  // Calculate platform delivery fee (existing logic)
  Future<void> _calculatePlatformDeliveryFee() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      print('🔍 DEBUG: No address provided for delivery fee calculation');
      return;
    }
    
    print('🔍 DEBUG: Calculating platform delivery fee for address: $address');
    
    // Get user's location from address
    final locations = await locationFromAddress(address);
    if (locations.isEmpty) {
      print('🔍 DEBUG: Could not geocode address: $address');
      return;
    }
    
    final userLocation = locations.first;
    print('🔍 DEBUG: User location: ${userLocation.latitude}, ${userLocation.longitude}');
    
    // Get seller's location
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final cartSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('cart')
        .get();
    
    if (cartSnapshot.docs.isEmpty) return;
    
    final firstCartItem = cartSnapshot.docs.first.data();
    final sellerId = firstCartItem['sellerId'] ?? firstCartItem['ownerId'];
    
    if (sellerId == null) return;
    
    final sellerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(sellerId)
        .get();
    
    if (!sellerDoc.exists) return;
    
    final sellerData = sellerDoc.data()!;
    final sellerLat = sellerData['latitude'];
    final sellerLng = sellerData['longitude'];
    
    if (sellerLat == null || sellerLng == null) {
      print('🔍 DEBUG: Seller location not available');
      return;
    }
    
    // Calculate distance
    final distance = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      sellerLat,
      sellerLng,
    );
    
    print('🔍 DEBUG: Distance calculated: ${distance.toStringAsFixed(2)} meters');
    
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
    
    // Calculate platform fee
    double platformFee = 0.0;
    if (!_isStoreFeeExempt && _platformFeePercent != null) {
      platformFee = (widget.totalPrice * _platformFeePercent! / 100);
    }
    
    setState(() {
      _deliveryDistance = distance;
      _deliveryFee = deliveryFee;
      _platformFee = platformFee;
    });
    
    print('🔍 DEBUG: Platform delivery fee calculated: R${deliveryFee.toStringAsFixed(2)}, Platform fee: R${platformFee.toStringAsFixed(2)}');
  }

  // Calculate seller delivery fee
  Future<void> _calculateSellerDeliveryFee() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      print('🔍 DEBUG: No address provided for seller delivery fee calculation');
      return;
    }
    
    print('🔍 DEBUG: Calculating seller delivery fee for address: $address');
    
    // Get seller data
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final cartSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('cart')
        .get();
    
    if (cartSnapshot.docs.isEmpty) return;
    
    final firstCartItem = cartSnapshot.docs.first.data();
    final sellerId = firstCartItem['sellerId'] ?? firstCartItem['ownerId'];
    
    if (sellerId == null) return;
    
    final sellerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(sellerId)
        .get();
    
    if (!sellerDoc.exists) return;
    
    final sellerData = sellerDoc.data()!;
    
    // Check if seller offers delivery
    final sellerDeliveryEnabled = sellerData['sellerDeliveryEnabled'] ?? false;
    if (!sellerDeliveryEnabled) {
      print('🔍 DEBUG: Seller does not offer delivery');
      setState(() {
        _selectedDeliveryType = 'pickup';
        _deliveryFee = 0.0;
        _deliveryDistance = 0.0;
        _platformFee = 0.0;
      });
      return;
    }
    
    // Calculate seller delivery fee
    final baseFee = (sellerData['sellerDeliveryBaseFee'] ?? 25.0).toDouble();
    final feePerKm = (sellerData['sellerDeliveryFeePerKm'] ?? 2.0).toDouble();
    final maxFee = (sellerData['sellerDeliveryMaxFee'] ?? 50.0).toDouble();
    
    // For now, use a simple calculation (you can enhance this with actual distance)
    double deliveryFee = baseFee;
    deliveryFee = deliveryFee.clamp(0.0, maxFee).toDouble();
    
    // Calculate platform fee
    double platformFee = 0.0;
    if (!_isStoreFeeExempt && _platformFeePercent != null) {
      platformFee = (widget.totalPrice * _platformFeePercent! / 100);
    }
    
    setState(() {
      _deliveryFee = deliveryFee;
      _platformFee = platformFee;
      _deliveryDistance = 0.0; // Seller delivery doesn't use distance calculation
    });
    
    print('🔍 DEBUG: Seller delivery fee calculated: R${deliveryFee.toStringAsFixed(2)}, Platform fee: R${platformFee.toStringAsFixed(2)}');
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
        _platformFeePercent = (sellerData['platformFeePercent'] ?? 5.0).toDouble();
        _isStoreFeeExempt = sellerData['isFeeExempt'] ?? false;
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

  // Load pickup points for current user location
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

  // Load pickup points for specific coordinates
  Future<void> _loadPickupPointsForCoordinates(double lat, double lng) async {
    try {
      print('🚚 DEBUG: Loading pickup points for coordinates: $lat, $lng');
      
      final pickupPoints = await CourierQuoteService.getPickupPoints(
        latitude: lat,
        longitude: lng,
      );
      
      setState(() {
        _pickupPoints = pickupPoints.map((point) => {
          'id': point.id,
          'name': point.name,
          'address': point.address,
          'latitude': point.latitude,
          'longitude': point.longitude,
          'type': point.type,
          'distance': point.distance,
          'fee': point.fee,
          'operatingHours': point.operatingHours,
          'isPargoPoint': point.isPargoPoint,
        }).toList();
        
        print('🚚 DEBUG: Found ${_pickupPoints.length} pickup points');
        
        // Auto-select first pickup point
        if (_pickupPoints.isNotEmpty) {
          _selectedPickupPoint = _pickupPoints.first;
          print('🚚 DEBUG: Selected pickup point: ${_selectedPickupPoint!['name']}');
        }
      });
      
    } catch (e) {
      print('❌ DEBUG: Error loading pickup points: $e');
      setState(() {
        _pickupPoints = [];
        _selectedPickupPoint = null;
      });
    }
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
      
      try {
        final locations = await locationFromAddress(query);
        if (locations.isNotEmpty) {
          final loc = locations.first;
          setState(() {
            _addressSuggestions = locations;
            _isSearchingAddress = false;
          });
          
          if (!_isDelivery && locations.isNotEmpty) {
            final loc = locations.first;
            _selectedLat = loc.latitude;
            _selectedLng = loc.longitude;
            print('🚚 DEBUG: Loading pickup points for pickup order at ${loc.latitude}, ${loc.longitude}');
            _loadPickupPointsForCoordinates(loc.latitude!, loc.longitude!);
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
        setState(() {
          _addressSuggestions = [];
          _isSearchingAddress = false;
        });
      }
    });
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
      body: Form(
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
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDeliveryType = 'platform';
                                _isDelivery = true;
                                // Clear pickup data when switching to delivery
                                _pickupPoints.clear();
                                _selectedPickupPoint = null;
                              });
                              // Trigger delivery fee calculation when switching to platform
                              if (_addressController.text.trim().isNotEmpty) {
                                _debouncedCalculateDeliveryFee();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _selectedDeliveryType == 'platform' ? AppTheme.deepTeal : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedDeliveryType == 'platform' ? AppTheme.deepTeal : Colors.grey.shade300,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.delivery_dining,
                                    color: _selectedDeliveryType == 'platform' ? Colors.white : Colors.grey.shade600,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Platform',
                                    style: TextStyle(
                                      color: _selectedDeliveryType == 'platform' ? Colors.white : Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: _sellerDeliveryAvailable ? () {
                              setState(() {
                                _selectedDeliveryType = 'seller';
                                _isDelivery = true;
                                // Clear pickup data when switching to delivery
                                _pickupPoints.clear();
                                _selectedPickupPoint = null;
                              });
                              // Trigger delivery fee calculation when switching to seller
                              if (_addressController.text.trim().isNotEmpty) {
                                _debouncedCalculateDeliveryFee();
                              }
                            } : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _selectedDeliveryType == 'seller' ? AppTheme.deepTeal : 
                                       _sellerDeliveryAvailable ? Colors.grey.shade200 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedDeliveryType == 'seller' ? AppTheme.deepTeal : 
                                         _sellerDeliveryAvailable ? Colors.grey.shade300 : Colors.grey.shade200,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.local_shipping,
                                    color: _selectedDeliveryType == 'seller' ? Colors.white : 
                                           _sellerDeliveryAvailable ? Colors.grey.shade600 : Colors.grey.shade400,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Seller',
                                    style: TextStyle(
                                      color: _selectedDeliveryType == 'seller' ? Colors.white : 
                                             _sellerDeliveryAvailable ? Colors.grey.shade600 : Colors.grey.shade400,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (!_sellerDeliveryAvailable)
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
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDeliveryType = 'pickup';
                                _isDelivery = false;
                                // Clear delivery fee when switching to pickup
                                _deliveryFee = 0.0;
                                _deliveryDistance = 0.0;
                                // Clear previous pickup points and show address search for pickup
                                _pickupPoints.clear();
                                _selectedPickupPoint = null;
                              });
                              
                              // Load pickup points for current location
                              _loadPickupPointsForCurrentLocation();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _selectedDeliveryType == 'pickup' ? AppTheme.deepTeal : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedDeliveryType == 'pickup' ? AppTheme.deepTeal : Colors.grey.shade300,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.store,
                                    color: _selectedDeliveryType == 'pickup' ? Colors.white : Colors.grey.shade600,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pickup',
                                    style: TextStyle(
                                      color: _selectedDeliveryType == 'pickup' ? Colors.white : Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
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
              
              // Address Field
              AddressInputField(
                controller: _addressController,
                labelText: _selectedDeliveryType == 'pickup' ? 'Pickup Address' : 'Delivery Address',
                hintText: _selectedDeliveryType == 'pickup' ? 'Enter your pickup address' : 'Enter your delivery address',
                onAddressSelected: (address) {
                  setState(() {});
                  // For pickup orders, search for pickup points at this address
                  if (_selectedDeliveryType == 'pickup' && address.isNotEmpty) {
                    _searchAddressesInline(address);
                  }
                },
              ),
              
              // Pickup Points Display Section
              if (_selectedDeliveryType == 'pickup') ...[
                SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
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
                            Icons.location_on,
                            color: AppTheme.deepTeal,
                            size: ResponsiveUtils.getIconSize(context, baseSize: 20),
                          ),
                          SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                          SafeUI.safeText(
                            'Pickup Points',
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
                      
                      // Pickup location header
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.deepTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: AppTheme.deepTeal, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Enter your pickup location to find nearest Pargo points',
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
                      SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                      
                      // Loading state
                      if (_isLoadingPickupPoints)
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Loading pickup points...',
                                style: TextStyle(
                                  color: AppTheme.deepTeal,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Success message when points found
                      if (_pickupPoints.isNotEmpty && !_isLoadingPickupPoints)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Found ${_pickupPoints.length} pickup points near your location!',
                                  style: TextStyle(
                                    color: AppTheme.success,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Pickup points list
                      if (_pickupPoints.isNotEmpty && !_isLoadingPickupPoints)
                        Column(
                          children: _pickupPoints.map((point) {
                            final isSelected = _selectedPickupPoint?['id'] == point['id'];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.deepTeal.withOpacity(0.1) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? AppTheme.deepTeal : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedPickupPoint = point;
                                  });
                                  print('🚚 DEBUG: Selected pickup point: ${point['name']}');
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                        color: isSelected ? AppTheme.deepTeal : Colors.grey.shade600,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              point['name'] ?? 'Pickup Point',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: isSelected ? AppTheme.deepTeal : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              point['address'] ?? 'Address not available',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                                                const SizedBox(width: 4),
                                                Text(
                                                  point['operatingHours'] ?? 'Hours not available',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  'R${(point['fee'] ?? 0.0).toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                    color: AppTheme.deepTeal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      
                      // No pickup points message
                      if (_pickupPoints.isEmpty && !_isLoadingPickupPoints)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No pickup points found. Please try a different location or contact support.',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              
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
              _buildOrderSummary(widget.totalPrice + (_selectedDeliveryType == 'pickup' ? 0 : (_deliveryFee ?? 0)) + _platformFee),
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
          if (_platformFee > 0)
            _buildSummaryRow('Platform Fee', 'R${_platformFee.toStringAsFixed(2)}'),
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
    
    if (!_formKey.currentState!.validate()) {
      print('🔍 DEBUG: Form validation failed');
      return;
    }
    
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
        'orderNumber': orderNumber,
        'buyerId': currentUser.uid,
        'buyerName': _nameController.text.trim(),
        'buyerPhone': _phoneController.text.trim(),
        'buyerAddress': _addressController.text.trim(),
        'deliveryInstructions': _deliveryInstructionsController.text.trim(),
        'sellerId': sellerId,
        'items': cartItems,
        'subtotal': widget.totalPrice,
        'deliveryFee': _selectedDeliveryType == 'pickup' ? 0.0 : (_deliveryFee ?? 0.0),
        'platformFee': _platformFee,
        'total': widget.totalPrice + (_selectedDeliveryType == 'pickup' ? 0 : (_deliveryFee ?? 0)) + _platformFee,
        'paymentMethod': _selectedPaymentMethod ?? 'Cash on Delivery',
        'status': 'pending',
        'isDelivery': _selectedDeliveryType != 'pickup',
        'timestamp': FieldValue.serverTimestamp(),
        'deliveryDistance': _selectedDeliveryType == 'pickup' ? 0.0 : _deliveryDistance,
        'deliveryTimeEstimate': _deliveryTimeEstimate,
        'deliveryType': _selectedDeliveryType,
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
      if (currentUser == null) return;
      
      // Send notification to seller
      await NotificationService().sendNewOrderNotificationToSeller(
        sellerId: sellerId,
        orderId: orderId,
        buyerName: _nameController.text.trim(),
        orderTotal: widget.totalPrice + (_selectedDeliveryType == 'pickup' ? 0 : (_deliveryFee ?? 0)) + _platformFee,
        sellerName: _storeName ?? 'Store',
      );
      
      // Send notification to buyer
      await NotificationService().sendOrderStatusNotificationToBuyer(
        buyerId: currentUser.uid,
        orderId: orderId,
        status: 'pending',
        sellerName: _storeName ?? 'Store',
      );
      
      print('🔍 DEBUG: Order notifications sent');
      
    } catch (e) {
      print('❌ Error sending order notifications: $e');
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
