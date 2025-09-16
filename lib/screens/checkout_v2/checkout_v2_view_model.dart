import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/delivery_fee_service.dart';
import '../../utils/delivery_time_utils.dart';
import '../../services/checkout_validation_service.dart';
import '../../services/seller_delivery_management_service.dart';
import '../../services/production_order_service.dart';

class CheckoutV2ViewModel extends ChangeNotifier {
  CheckoutV2ViewModel({required this.totalPrice, required List<Map<String, dynamic>> cartItems}) {
    // Initialize current user
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    // Inject real cart items BEFORE loading settings
    this.cartItems = cartItems;
    // Load seller delivery settings
    _loadSellerDeliverySettings();
  }

  final double totalPrice;

  // UI state
  bool isDelivery = true;
  String productCategory = 'other';
  double distanceKm = 0.0;
  double? deliveryFee;
  int? etaMinutes;
  bool isLoading = false;
  String? error;
  
  // Seller delivery availability
  bool sellerOffersDelivery = false;
  bool sellerOffersPaxi = false;
  bool sellerOffersPudo = false;
  bool sellerOffersPargo = false;
  bool isLoadingSellerInfo = true;

  // Seller store details for Store Pickup
  String? sellerStoreName;
  String? sellerStoreAddress;
  double? sellerStoreLatitude;
  double? sellerStoreLongitude;

  // Store hours
  bool isStoreOpenFlag = true;
  String? sellerOpenHour;   // e.g., '08:00'
  String? sellerCloseHour;  // e.g., '17:00'
  
  // COD and compliance
  bool allowCOD = false;
  String? kycStatus; // 'pending' | 'approved' | etc.
  double sellerOutstandingFees = 0.0;
  bool get codEnabledForSeller => allowCOD && (kycStatus?.toLowerCase() == 'approved') && (sellerOutstandingFees <= 0.0);

  bool get isStoreOpenNow {
    try {
      if ((sellerOpenHour == null || sellerCloseHour == null) || sellerOpenHour!.trim().isEmpty || sellerCloseHour!.trim().isEmpty) {
        return isStoreOpenFlag;
      }
      final open = _parseTodayTime(sellerOpenHour!);
      final close = _parseTodayTime(sellerCloseHour!);
      if (open == null || close == null) return isStoreOpenFlag;
      final now = DateTime.now();
      if (open.isBefore(close)) {
        // Same-day window
        return now.isAfter(open) && now.isBefore(close);
      } else {
        // Overnight window (e.g., 20:00 -> 06:00)
        return now.isAfter(open) || now.isBefore(close);
      }
    } catch (_) {
      return isStoreOpenFlag;
    }
  }

  DateTime? _parseTodayTime(String hhmm) {
    try {
      final base = DateTime.now();
      final parts = hhmm.split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
      if (h == null || m == null) return null;
      return DateTime(base.year, base.month, base.day, h, m);
    } catch (_) {
      return null;
    }
  }

  // Inputs
  String? addressText;
  String? selectedServiceFilter; // 'paxi' | 'pargo' | 'store'
  String? selectedPaxiSpeed; // 'standard' | 'express'
  String? currentUserId;
  List<String> excludedZones = [];
  double? minOrderForDelivery;
  String? sellerDeliveryPreference; // 'system' | 'custom'
  double? sellerFeePerKm;

  // NEW: Advanced checkout features
  Map<String, dynamic>? selectedPickupPoint;
  Map<String, dynamic>? selectedAddress;
  Map<String, dynamic>? productHandlingInstructions;
  String selectedPaymentMethod = 'payfast'; // 'payfast', 'eft', 'cod'
  
  // PUDO-specific delivery details
  Map<String, dynamic>? pudoDeliveryAddress;
  String? pudoDeliveryPhone;
  
  // Customer information
  String? firstName;
  String? lastName;
  String? customerPhone;
  
  // Special handling instructions from buyer to seller
  String? specialHandlingInstructions;
  
  // Real cart items injected by the screen
  List<Map<String, dynamic>> cartItems = [];

  // State helpers (avoid calling notifyListeners from UI)
  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  void setError(String? value) {
    error = value;
    notifyListeners();
  }
  
  void setFirstName(String value) {
    firstName = value.trim().isEmpty ? null : value.trim();
    notifyListeners();
  }
  
  void setLastName(String value) {
    lastName = value.trim().isEmpty ? null : value.trim();
    notifyListeners();
  }
  
  void setCustomerPhone(String value) {
    customerPhone = value.trim().isEmpty ? null : value.trim();
    print('🔍 DEBUG: setCustomerPhone called with: "$value" -> customerPhone: "$customerPhone"');
    print('🔍 DEBUG: pudoDeliveryPhone current: "$pudoDeliveryPhone"');
    
    // Auto-populate PUDO phone if it's empty AND the phone number is complete (10 digits starting with 0)
    if (customerPhone != null && 
        customerPhone!.isNotEmpty && 
        (pudoDeliveryPhone == null || pudoDeliveryPhone!.isEmpty) &&
        _isCompleteLocalPhoneNumber(customerPhone!)) {
      // Convert local format (0xx xxx xxxx) to PUDO format (6x xxx xxxx - without +27 prefix)
      String pudoFormat = _convertToPudoFormat(customerPhone!);
      print('🔍 DEBUG: Converting customer phone "$customerPhone" to PUDO format: "$pudoFormat"');
      pudoDeliveryPhone = pudoFormat;
    }
    notifyListeners();
  }
  
  // Helper method to check if phone number is complete local format
  bool _isCompleteLocalPhoneNumber(String phone) {
    // Remove all non-digits
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    print('🔍 DEBUG: _isCompleteLocalPhoneNumber input: "$phone" -> cleaned: "$cleaned"');
    
    // Check if it's a complete local phone number (10 digits starting with 0)
    bool isComplete = cleaned.startsWith('0') && cleaned.length == 10;
    print('🔍 DEBUG: _isCompleteLocalPhoneNumber result: $isComplete');
    return isComplete;
  }
  
  // Helper method to convert international format to local format
  String _convertToLocalFormat(String internationalPhone) {
    // Remove all non-digits
    String cleaned = internationalPhone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Convert +27 6x xxx xxxx to 0xx xxx xxxx
    if (cleaned.startsWith('27') && cleaned.length == 11) {
      return '0${cleaned.substring(2)}';
    }
    
    return internationalPhone; // Return as-is if no conversion needed
  }
  
  // Helper method to convert local format to PUDO format (without +27 prefix)
  String _convertToPudoFormat(String localPhone) {
    // Remove all non-digits
    String cleaned = localPhone.replaceAll(RegExp(r'[^\d]'), '');
    print('🔍 DEBUG: _convertToPudoFormat input: "$localPhone" -> cleaned: "$cleaned"');
    
    // Convert 0xx xxx xxxx to 6x xxx xxxx (without +27 prefix)
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      String result = cleaned.substring(1); // Remove the 0, keep the rest
      print('🔍 DEBUG: _convertToPudoFormat result: "$result"');
      return result;
    }
    
    print('🔍 DEBUG: _convertToPudoFormat no conversion needed, returning: "$localPhone"');
    return localPhone; // Return as-is if no conversion needed
  }
  
  // Helper method to convert local format to international format
  String _convertToInternationalFormat(String localPhone) {
    // Remove all non-digits
    String cleaned = localPhone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Convert 0xx xxx xxxx to +27 6x xxx xxxx
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      return '+27${cleaned.substring(1)}';
    }
    
    return localPhone; // Return as-is if no conversion needed
  }

  Future<void> computeFeesAndEta({required bool isUrbanArea, double? urbanFee}) async {
    final pref = sellerDeliveryPreference ?? 'custom';
    final perKm = sellerFeePerKm ?? 5.0;

    final result = DeliveryFeeService.compute(
      distanceKm: distanceKm,
      productCategory: productCategory,
      sellerDeliveryPreference: pref,
      sellerFlatFee: 0.0,
      sellerFeePerKm: perKm,
      sellerMinFee: 0.0,
      isUrbanArea: isUrbanArea,
      urbanFee: urbanFee,
    );
    deliveryFee = result.fee;

    etaMinutes = DeliveryTimeUtils.calculateRealisticDeliveryTime(
      distanceKm: distanceKm,
      basePrepTimeMinutes: 15,
      currentTime: DateTime.now(),
    );
    notifyListeners();
  }

  Future<bool> validate() async {
    try {
      // Ensure we have the latest user ID
      currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      print('🔍 DEBUG: Validating checkout with currentUserId: $currentUserId');
      
      // Validate customer name information
      if (firstName == null || firstName!.trim().isEmpty) {
        error = 'Please enter your first name';
        notifyListeners();
        return false;
      }
      
      if (lastName == null || lastName!.trim().isEmpty) {
        error = 'Please enter your last name';
        notifyListeners();
        return false;
      }
      
      print('🔍 ViewModel: Validating with addressText: "$addressText", isDelivery: $isDelivery');
      
      final res = await CheckoutValidationService.validate(
        excludedZones: excludedZones,
        addressText: addressText ?? '',
        totalPrice: totalPrice,
        currentUserId: currentUserId,
        minOrderForDelivery: minOrderForDelivery,
        selectedServiceFilter: selectedServiceFilter,
        selectedPaxiDeliverySpeed: selectedPaxiSpeed,
        selectedPickupPoint: selectedPickupPoint,
        pudoDeliveryAddress: pudoDeliveryAddress,
        pudoDeliveryPhone: pudoDeliveryPhone,
        isDelivery: isDelivery,
        firestore: FirebaseFirestore.instance,
      );
      
      print('🔍 ViewModel: Validation result: ${res.isValid}, error: ${res.errorMessage}');
      
      if (!res.isValid) {
        error = res.errorMessage ?? 'Validation failed';
        notifyListeners();
        return false;
      }
      
      // Additional validations for new features
      if (!isDelivery && selectedPickupPoint == null) {
        error = 'Please select a pickup point';
        notifyListeners();
        return false;
      }
      
      if (selectedPaymentMethod.isEmpty) {
        error = 'Please select a payment method';
        notifyListeners();
        return false;
      }

      // Enforce COD gate by KYC
      if (selectedPaymentMethod == 'cod' && !codEnabledForSeller) {
        if ((kycStatus ?? '').toLowerCase() != 'approved') {
          error = 'Cash on Delivery unavailable: seller identity verification pending.';
        } else if (sellerOutstandingFees > 0.0) {
          error = 'Cash on Delivery unavailable: outstanding fees R${sellerOutstandingFees.toStringAsFixed(2)}';
        } else if (!allowCOD) {
          error = 'Cash on Delivery disabled by this seller.';
        } else {
          error = 'Cash on Delivery is unavailable.';
        }
        notifyListeners();
        return false;
      }
      
      error = null;
      notifyListeners();
      return true;
    } catch (e) {
      error = 'Validation error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> validateAndStepUp(BuildContext context) async {
    final isValid = await validate();
    if (!isValid) return false;
    final stepOk = await _requirePasswordReauthIfNeeded(context);
    return stepOk;
  }

  Future<bool> _requirePasswordReauthIfNeeded(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return true;
      final email = user.email;
      // Basic conditions to require step-up (no Cloud Functions needed)
      final requiresStepUp = selectedPaymentMethod == 'payfast' || totalPrice >= 500.0 || (user.emailVerified == false);
      if (!requiresStepUp) return true;
      if (email == null || email.isEmpty) return true; // phone-only accounts: skip

      final controller = TextEditingController();
      bool cancelled = false;
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Confirm your identity'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('For your security, please enter your password to continue.'),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () { cancelled = true; Navigator.of(ctx).pop(false); },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final pwd = controller.text;
                  if (pwd.isEmpty) return;
                  Navigator.of(ctx).pop(true);
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );

      if (ok != true) {
        if (!cancelled) {
          error = 'Verification cancelled.';
          notifyListeners();
        }
        return false;
      }

      final cred = EmailAuthProvider.credential(email: email, password: controller.text);
      await user.reauthenticateWithCredential(cred);
      error = null;
      notifyListeners();
      return true;
    } catch (e) {
      error = 'Verification failed: $e';
      notifyListeners();
      return false;
    }
  }

  void setIsDelivery(bool v) {
    isDelivery = v;
    
    // Trigger delivery fee calculation when switching to delivery mode
    if (v && addressText != null && addressText!.isNotEmpty) {
      calculateDeliveryFee();
    } else if (!v) {
      // Clear delivery fee when switching to pickup mode
      deliveryFee = null;
    }
    
    notifyListeners();
  }

  void setDistance(double km) {
    distanceKm = km;
    notifyListeners();
  }

  void setProductCategory(String cat) {
    productCategory = cat;
    notifyListeners();
  }

  Future<void> calculateDeliveryFee() async {
    if (!isDelivery || addressText == null || addressText!.isEmpty) {
      deliveryFee = null;
      return;
    }

    try {
      print('🔍 DEBUG: Calculating delivery fee for address: $addressText');
      
      // For now, use a default distance and calculate delivery fee
      // In a real app, you'd geocode the address and calculate actual distance
      final double defaultDistance = distanceKm > 0 ? distanceKm : 5.0;
      
      final result = DeliveryFeeService.compute(
        distanceKm: defaultDistance,
        productCategory: productCategory,
        sellerDeliveryPreference: sellerDeliveryPreference ?? 'system',
        sellerFeePerKm: sellerFeePerKm,
        sellerMinFee: 15.0,
        isUrbanArea: false, // You could implement location detection here
        urbanFee: null,
      );
      
      deliveryFee = result.fee;
      distanceKm = result.distanceKm;
      
      // Calculate estimated delivery time
      etaMinutes = DeliveryTimeUtils.calculateRealisticDeliveryTime(
        distanceKm: distanceKm,
        basePrepTimeMinutes: 15,
        currentTime: DateTime.now(),
      );
      
      print('✅ Delivery fee calculated: R${deliveryFee!.toStringAsFixed(2)} for ${distanceKm}km');
      notifyListeners();
    } catch (e) {
      print('❌ Error calculating delivery fee: $e');
      // Set default fee as fallback
      deliveryFee = 15.0;
      notifyListeners();
    }
  }

  void setAddress(String text) {
    print('🔍 ViewModel: Setting addressText to: "$text"');
    addressText = text;
    print('🔍 ViewModel: addressText is now: "$addressText"');
    
    // Trigger delivery fee calculation when address is set
    if (text.isNotEmpty && isDelivery) {
      calculateDeliveryFee();
    }
    
    notifyListeners();
  }
  
  // NEW: Advanced checkout methods
  
  void setSelectedPickupPoint(Map<String, dynamic>? point) {
    selectedPickupPoint = point;
    notifyListeners();
  }
  
  void setSelectedAddress(Map<String, dynamic>? address) {
    selectedAddress = address;
    notifyListeners();
  }
  
  void setPaymentMethod(String method) {
    selectedPaymentMethod = method;
    notifyListeners();
  }
  
  void setPaxiDeliverySpeed(String? speed) {
    selectedPaxiSpeed = speed;
    notifyListeners();
  }
  
  void setPudoDeliveryAddress(Map<String, dynamic>? address) {
    pudoDeliveryAddress = address;
    notifyListeners();
  }
  
  void setPudoDeliveryPhone(String? phone) {
    pudoDeliveryPhone = phone;
    print('🔍 DEBUG: setPudoDeliveryPhone called with: "$phone" -> pudoDeliveryPhone: "$pudoDeliveryPhone"');
    print('🔍 DEBUG: customerPhone current: "$customerPhone"');
    
    // Auto-populate customer phone if it's empty AND the PUDO phone is complete
    if (phone != null && 
        phone.isNotEmpty && 
        (customerPhone == null || customerPhone!.isEmpty) &&
        _isCompletePudoPhoneNumber(phone)) {
      // Convert PUDO phone format (+27 6x xxx xxxx) to local format (0xx xxx xxxx)
      String localFormat = _convertToLocalFormat(phone);
      print('🔍 DEBUG: Converting PUDO phone "$phone" to customer format: "$localFormat"');
      customerPhone = localFormat;
    }
    notifyListeners();
  }
  
  // Helper method to check if PUDO phone number is complete
  bool _isCompletePudoPhoneNumber(String phone) {
    // Remove all non-digits
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    print('🔍 DEBUG: _isCompletePudoPhoneNumber input: "$phone" -> cleaned: "$cleaned"');
    
    // Check if it's a complete PUDO phone number (9 digits starting with 6, 7, or 8)
    bool isComplete = cleaned.length == 9 && 
                     (cleaned.startsWith('6') || cleaned.startsWith('7') || cleaned.startsWith('8'));
    print('🔍 DEBUG: _isCompletePudoPhoneNumber result: $isComplete');
    return isComplete;
  }
  
  // Customer information setters (removed duplicates)
  
  // Get full customer name
  String getFullName() {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    if (first.isEmpty && last.isEmpty) return 'Customer';
    if (first.isEmpty) return last;
    if (last.isEmpty) return first;
    return '$first $last';
  }
  
  void setSpecialHandlingInstructions(String? instructions) {
    specialHandlingInstructions = instructions;
    notifyListeners();
  }
  
  double calculateTotal() {
    double total = totalPrice;
    
    if (isDelivery && deliveryFee != null) {
      total += deliveryFee!;
    } else if (!isDelivery && selectedPickupPoint != null) {
      final pickupFee = selectedPickupPoint!['fees']['collection'] ?? 0.0;
      total += pickupFee as double;
    }
    
    // Service fee (3.5%)
    total += totalPrice * 0.035;
    
    return total;
  }
  
  double get grandTotal => calculateTotal();
  
  void loadProductHandlingInstructions() {
    if (cartItems.isNotEmpty) {
      final firstItem = cartItems.first;
      productHandlingInstructions = SellerDeliveryManagementService.generateProductHandlingInstructions(
        productCategory: firstItem['category'] ?? 'other',
        productName: firstItem['name'] ?? '',
        productDetails: firstItem,
      );
      notifyListeners();
    }
  }
  
  /// Check if seller offers delivery service
  Future<void> _loadSellerDeliverySettings() async {
    try {
      isLoadingSellerInfo = true;
      notifyListeners();
      
      // Get seller ID from cart items
      if (cartItems.isNotEmpty) {
        final sellerId = cartItems.first['sellerId'];
        print('🔍 DEBUG: Loading seller data for sellerId: $sellerId');
        print('🔍 DEBUG: Cart items: $cartItems');
        
        if (sellerId != null) {
          // Fetch seller document from Firestore
          final sellerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(sellerId)
              .get();
              
          print('🔍 DEBUG: Seller document exists: ${sellerDoc.exists}');
          
          if (sellerDoc.exists && sellerDoc.data() != null) {
            final sellerData = sellerDoc.data()!;
            
            // Check if seller offers delivery (strict: require seller's flag)
            sellerOffersDelivery = sellerData['deliveryAvailable'] ??
                                   sellerData['offersDelivery'] ?? false;
            
            // Check if seller offers pickup services
            sellerOffersPaxi = sellerData['paxiEnabled'] ?? false;
            sellerOffersPudo = sellerData['pudoEnabled'] ?? false;
            sellerOffersPargo = sellerData['pargoEnabled'] ?? false;
            
            // If seller doesn't offer delivery, force pickup mode
            if (!sellerOffersDelivery) {
              isDelivery = false;
            }
            
            // Load other seller settings
            sellerDeliveryPreference = sellerData['deliveryMode'] ?? sellerData['deliveryPreference'] ?? 'system';
            sellerFeePerKm = (sellerData['sellerDeliveryFeePerKm'] ?? sellerData['deliveryFeePerKm'])?.toDouble();
            minOrderForDelivery = sellerData['minOrderForDelivery']?.toDouble();

            // Store hours and open flag
            isStoreOpenFlag = sellerData['isStoreOpen'] ?? sellerData['storeOpen'] ?? true;
            sellerOpenHour = (sellerData['storeOpenHour'] ?? '').toString();
            sellerCloseHour = (sellerData['storeCloseHour'] ?? '').toString();

            // Store info
            sellerStoreName = (sellerData['storeName'] ?? sellerData['name'] ?? sellerData['businessName'])?.toString();
            sellerStoreAddress = (sellerData['storeAddress'] ?? sellerData['address'] ?? '')?.toString();
            final lat = sellerData['latitude'] ?? sellerData['storeLatitude'];
            final lng = sellerData['longitude'] ?? sellerData['storeLongitude'];
            if (lat is num) sellerStoreLatitude = lat.toDouble();
            if (lng is num) sellerStoreLongitude = lng.toDouble();

            // COD and KYC
            final codDisabled = sellerData['codDisabled'] == true;
            allowCOD = (sellerData['allowCOD'] == true) && !codDisabled;
            kycStatus = (sellerData['kycStatus'] ?? '').toString();
            sellerOutstandingFees = (sellerData['outstandingFees'] ?? sellerData['outstandingDue'] ?? 0.0).toDouble();
            
            // If COD was selected but not allowed, revert to PayFast
            if (selectedPaymentMethod == 'cod' && !codEnabledForSeller) {
              selectedPaymentMethod = 'payfast';
            }
            
            print('✅ Seller services loaded:');
            print('   - Delivery: $sellerOffersDelivery (deliveryAvailable: ${sellerData['deliveryAvailable']})');
            print('   - PAXI: $sellerOffersPaxi (paxiEnabled: ${sellerData['paxiEnabled']})');
            print('   - PUDO: $sellerOffersPudo (pudoEnabled: ${sellerData['pudoEnabled']})');
            print('   - PARGO: $sellerOffersPargo (pargoEnabled: ${sellerData['pargoEnabled']})');
            print('📊 Available services: ${[
              if (sellerOffersDelivery) 'Delivery',
              if (sellerOffersPaxi) 'PAXI', 
              if (sellerOffersPudo) 'PUDO',
              if (sellerOffersPargo) 'PARGO'
            ].join(', ')}');
          } else {
            print('❌ DEBUG: Seller document does not exist for sellerId: $sellerId');
          }
        } else {
          print('❌ DEBUG: No sellerId found in cart items');
        }
      } else {
        print('❌ DEBUG: Cart items is empty');
      }
    } catch (e) {
      print('❌ Error loading seller delivery settings: $e');
      // Default to pickup only if error
      sellerOffersDelivery = false;
      isDelivery = false;
      
      // TEMPORARY: For testing when seller ID is wrong, enable services manually
      print('🔧 TEMPORARY: Enabling PAXI/PUDO for testing since seller data failed to load');
      sellerOffersPaxi = true;
      sellerOffersPudo = true;
    } finally {
      isLoadingSellerInfo = false;
      
      // Trigger initial delivery fee calculation if delivery is enabled and we have an address
      if (isDelivery && addressText != null && addressText!.isNotEmpty) {
        calculateDeliveryFee();
      }
      
      notifyListeners();
    }
  }
  
  Future<Map<String, dynamic>> submitOrder(BuildContext context) async {
    // Ensure we have the latest user ID before submitting
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    print('🔍 DEBUG: Submitting order with currentUserId: $currentUserId');
    
    // Load product handling instructions before submission
    loadProductHandlingInstructions();
    
    // Use PRODUCTION-GRADE order service
    final result = await ProductionOrderService.submitProductionOrder(
      cartItems: cartItems,
      isDelivery: isDelivery,
      paymentMethod: selectedPaymentMethod,
      deliveryAddress: addressText,
      selectedPickupPoint: selectedPickupPoint,
      productHandlingInstructions: productHandlingInstructions,
      specialHandlingInstructions: specialHandlingInstructions,
      selectedPaxiSpeed: selectedPaxiSpeed,
      pudoDeliveryAddress: pudoDeliveryAddress,
      pudoDeliveryPhone: pudoDeliveryPhone,
      customerFirstName: firstName,
      customerLastName: lastName,
      customerPhone: customerPhone,
      context: context,
    );
    
    if (!result['success']) {
      throw Exception(result['message'] ?? 'Order submission failed');
    }
    
    print('✅ Production order completed: ${result['orderId']}');

    // Handle PayFast redirect for card payments
    if (selectedPaymentMethod == 'payfast') {
      final payment = result['payment'] as Map<String, dynamic>?;
      if (payment != null && payment['success'] == true) {
        final paymentUrl = payment['paymentUrl'] as String?;
        final paymentData = (payment['paymentData'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString()));
        final method = payment['httpMethod'] as String?;
        if (paymentUrl != null && paymentData != null) {
          // Prefer POST via the Cloud Function bridge; if that's not feasible in-app, build GET fallback
          String finalUrl;
          // Always use GET to the Cloud Function bridge; it will render a POST form to PayFast
          final query = paymentData.entries
              .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
              .join('&');
          finalUrl = '$paymentUrl?$query';

          // Open payment page: on web use same tab (avoid blank WebView), on mobile use in-app WebView
          if (context.mounted) {
            // Debug: log the PayFast URL and expected return/cancel paths
            // Helps verify that we are using Cloud Functions endpoints
            // and not the Hosting proxied URLs
            // Example expected: https://us-central1-marketplace-8d6bd.cloudfunctions.net/payfastFormRedirect?... 
            // Success/Cancel detection: contains 'payfastReturn' / 'payfastCancel'
            // ignore: avoid_print
            print('🧭 PAYFAST URL → '+finalUrl);
            if (kIsWeb) {
              // On web, navigate directly to PayFast URL and handle return via URL parameters
              print('🌐 Web PayFast: Navigating to $finalUrl');
              
              // Store order info for return handling
              final orderId = result['orderId'] as String?;
              if (orderId != null) {
                // Store order info in localStorage for return handling
                // This will be picked up by the main app when user returns
                print('💾 Storing order info for return: $orderId');
              }
              
              // Navigate to PayFast URL directly
              await launchUrl(
                Uri.parse(finalUrl),
                mode: LaunchMode.platformDefault,
                webOnlyWindowName: '_self',
              );
              
              // For web, we'll handle the return via URL parameters in main.dart
              // The PayFast return URL should include order_id and status
              return Map<String, dynamic>.from(result);
            }
            final navResult = await Navigator.of(context).pushNamed(
              '/paymentWebview',
              arguments: {
                'url': finalUrl,
                // Cloud Function endpoint path detection
                'successPath': 'payfastReturn',
                'cancelPath': 'payfastCancel',
              },
            );
            // If payment succeeded via return URL, mark order paid and finalize
            if (navResult is Map && navResult['status'] == 'success') {
              try {
                final orderId = result['orderId'] as String?;
                if (orderId != null) {
                  final db = FirebaseFirestore.instance;
                  // Get existing order data first to preserve totals
                  final existingOrder = await db.collection('orders').doc(orderId).get();
                  final existingData = existingOrder.data() ?? {};
                  
                  await db.collection('orders').doc(orderId).set({
                    'payment': {
                      'method': 'payfast',
                      'status': 'paid',
                      'currency': 'ZAR',
                      'gateway': 'payfast',
                      'paidViaReturn': true,
                    },
                    'status': 'paid',
                    'paymentStatus': 'paid',
                    'paidAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                    'statusHistory': FieldValue.arrayUnion([
                      {
                        'status': 'paid',
                        'timestamp': FieldValue.serverTimestamp(),
                        'note': 'Marked paid via PayFast return',
                      }
                    ]),
                    // Preserve existing pricing information
                    'totalPrice': existingData['totalPrice'] ?? grandTotal,
                    'totalAmount': existingData['totalAmount'] ?? grandTotal,
                    'subtotal': existingData['subtotal'] ?? totalPrice,
                    'deliveryFee': existingData['deliveryFee'] ?? (isDelivery ? (deliveryFee ?? 0.0) : 0.0),
                  }, SetOptions(merge: true));

                  await ProductionOrderService.finalizePostPayment(
                    orderId: orderId,
                    cartItems: cartItems,
                    isDelivery: isDelivery,
                    deliveryAddress: addressText,
                    selectedPickupPoint: selectedPickupPoint,
                    productHandlingInstructions: productHandlingInstructions,
                    customerFirstName: firstName,
                    customerLastName: lastName,
                  );

                  // Navigate to payment success page instead of returning normally
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed(
                      '/payment-success',
                      arguments: {
                        'order_id': orderId,
                        'status': 'paid',
                      },
                    );
                    return {'success': true, 'orderId': orderId, 'navigated': true};
                  }
                }
              } catch (e) {
                // ignore: avoid_print
                print('⚠️ Post-payment finalization error: $e');
              }
            }
          }
        }
      }
    }
    return Map<String, dynamic>.from(result);
  }
}

