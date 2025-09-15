import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:crypto/crypto.dart';
import 'seller_delivery_management_service.dart';
import 'real_pickup_service.dart';
import 'otp_verification_service.dart';
import 'whatsapp_integration_service.dart';
import 'notification_service.dart';
import 'payfast_service.dart';

class ProductionOrderService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Sanitize nested structures to ensure Firestore-serializable data only
  static Map<String, dynamic>? _sanitizePickupPoint(Map<String, dynamic>? point) {
    if (point == null) return null;
    final allowed = <String, dynamic>{};
    void put(String key, dynamic value) {
      if (value == null) return;
      if (value is num || value is String || value is bool) {
        allowed[key] = value;
      } else if (value is Map) {
        allowed[key] = Map<String, dynamic>.from(value.map((k, v) => MapEntry(k.toString(), v))
            .map((k, v) => MapEntry(k, (v is num || v is String || v is bool) ? v : v.toString())));
      }
    }
    put('id', point['id']);
    put('name', point['name']);
    put('address', point['address']);
    put('latitude', point['latitude']);
    put('longitude', point['longitude']);
    put('distance', point['distance']);
    put('type', point['type']);
    if (point['fees'] is Map<String, dynamic>) {
      final fees = point['fees'] as Map<String, dynamic>;
      allowed['fees'] = {
        'collection': (fees['collection'] is num) ? (fees['collection'] as num).toDouble() : 0.0,
        'return': (fees['return'] is num) ? (fees['return'] as num).toDouble() : 0.0,
      };
    }
    return allowed;
  }
  
  static Map<String, dynamic>? _sanitizePudoDeliveryAddress(Map<String, dynamic>? address) {
    if (address == null) return null;
    final out = <String, dynamic>{};
    void put(String key) {
      final v = address[key];
      if (v == null) return;
      if (v is num || v is String || v is bool) {
        out[key] = v;
      }
    }
    for (final key in ['line1','line2','city','province','postalCode','country']) {
      put(key);
    }
    return out;
  }
  
  /// Complete production-grade order submission with ALL integrations
  static Future<Map<String, dynamic>> submitProductionOrder({
    required List<Map<String, dynamic>> cartItems,
    required bool isDelivery,
    required String paymentMethod,
    String? deliveryAddress,
    Map<String, dynamic>? selectedPickupPoint,
    Map<String, dynamic>? productHandlingInstructions,
    String? specialHandlingInstructions,
    String? selectedPaxiSpeed,
    Map<String, dynamic>? pudoDeliveryAddress,
    String? pudoDeliveryPhone,
    String? customerFirstName,
    String? customerLastName,
    String? customerPhone,
    required BuildContext context,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Authentication required');
      }
      
      // Generate secure order ID with timestamp and hash
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final orderHash = sha256.convert(utf8.encode('${user.uid}_$timestamp')).toString().substring(0, 8);
      final orderId = 'OMN${timestamp.toString().substring(8)}${orderHash.toUpperCase()}';
      
      print('🚀 Processing production order: $orderId');
      
      // Calculate totals with precision
      final subtotal = cartItems.fold<double>(0.0, (sum, item) => 
          sum + ((item['price'] as num).toDouble() * (item['quantity'] as num).toInt()));
      
      double deliveryFee = 0.0;
      double pickupFee = 0.0;
      
      // Get real-time location for delivery
      Position? userLocation;
      if (isDelivery) {
        try {
          userLocation = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          );
          
          // Calculate precise delivery fee based on actual distance
          final sellerLocation = await _getSellerLocation(cartItems.first['sellerId']);
          if (sellerLocation != null) {
            final distance = Geolocator.distanceBetween(
              userLocation.latitude, userLocation.longitude,
              sellerLocation['lat'], sellerLocation['lng'],
            ) / 1000; // Convert to km
            
            // Smart delivery pricing
            deliveryFee = _calculateSmartDeliveryFee(distance, cartItems);
          }
        } catch (e) {
          print('⚠️ Location error, using fallback pricing: $e');
          deliveryFee = 25.0; // Fallback fee
        }
      } else if (selectedPickupPoint != null) {
        pickupFee = selectedPickupPoint['fees']['collection']?.toDouble() ?? 15.0;
      }
      
      final serviceFee = subtotal * 0.035; // 3.5% service fee
      final grandTotal = subtotal + deliveryFee + pickupFee + serviceFee;
      
      // Generate OTP for delivery verification (best-effort)
      String? deliveryOTP;
      if (isDelivery) {
        try {
          deliveryOTP = await OTPVerificationService.generateDeliveryOTP(
            orderId: orderId,
            buyerId: user.uid,
            sellerId: cartItems.first['sellerId'],
          );
        } catch (e) {
          print('⚠️ OTP generation failed, continuing without OTP: $e');
        }
      }
      
      // Create comprehensive order document
      final orderData = {
        'orderId': orderId,
        'buyerId': user.uid,
        'buyerDetails': {
          'firstName': customerFirstName?.trim() ?? '',
          'lastName': customerLastName?.trim() ?? '',
          'fullName': _getFullCustomerName(customerFirstName, customerLastName),
          'displayName': user.displayName, // Keep original for reference
          'email': user.email,
          // Prefer Auth phone, fallback to provided checkout phone (e.g., EFT/PUDO input)
          'phone': user.phoneNumber ?? pudoDeliveryPhone,
        },
        'sellerId': cartItems.first['sellerId'] ?? 'unknown_seller',
        'items': cartItems.map((item) => {
          'productId': item['productId'] ?? 'unknown',
          'name': item['name'] ?? 'Unknown Product',
          'category': item['category'] ?? 'other',
          'price': item['price'] ?? 0.0,
          'quantity': item['quantity'] ?? 1,
          'imageUrl': item['imageUrl'] ?? '',
          'sellerName': item['sellerName'] ?? 'Unknown Seller',
        }).toList(),
        
        // Financial breakdown
        'pricing': {
          'subtotal': subtotal,
          'deliveryFee': deliveryFee,
          'pickupFee': pickupFee,
          'serviceFee': serviceFee,
          'grandTotal': grandTotal,
        },
        
        // Delivery/pickup details
        'fulfillment': {
          'type': isDelivery ? 'delivery' : 'pickup',
          'address': isDelivery ? deliveryAddress : null,
          'coordinates': userLocation != null ? {
            'lat': userLocation.latitude,
            'lng': userLocation.longitude,
            'accuracy': userLocation.accuracy,
          } : null,
          'pickupPoint': _sanitizePickupPoint(selectedPickupPoint),
          'deliveryOTP': deliveryOTP,
          'estimatedTime': isDelivery ? _calculateRealisticETA(userLocation) : null,
          'paxiSpeed': selectedPaxiSpeed,
          'pudoDeliveryDetails': (selectedPickupPoint?['type'] == 'pudo') ? {
            'deliveryAddress': _sanitizePudoDeliveryAddress(pudoDeliveryAddress),
            'deliveryPhone': pudoDeliveryPhone,
            'lockerToDelivery': true,
          } : null,
        },
        
        // Special handling instructions from buyer to seller
        'specialHandlingInstructions': specialHandlingInstructions,
        
        // Payment details
        'payment': {
          'method': paymentMethod,
          'status': 'pending',
          'currency': 'ZAR',
          'gateway': paymentMethod == 'payfast' ? 'payfast' : paymentMethod,
        },
        
        // Product handling
        'handling': productHandlingInstructions ?? {},
        
        // Status tracking
        'status': 'pending_payment',
        'statusHistory': [{
          'status': 'created',
          'timestamp': Timestamp.now(),
          'note': 'Order created successfully',
        }],
        
        // Metadata
        'metadata': {
          'version': '2.0',
          'platform': 'flutter_app',
          'userAgent': 'OmniaSA/2.0',
          'ipAddress': await _getUserIP(),
          'deviceInfo': await _getDeviceInfo(),
        },
        
        // Timestamps
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(hours: 24))),
      };
      
      // Step 1: Create the order document first. If this succeeds, we consider the order placed.
      final orderRef = _firestore.collection('orders').doc(orderId);
      await orderRef.set(orderData);
      print('✅ Order document created: $orderId');

      // Step 2: Best-effort stats updates (do not fail the main flow)
      try {
        final batch = _firestore.batch();

        // Update seller stats (merge to avoid missing-doc failures)
        final sellerId = cartItems.first['sellerId'] ?? 'unknown_seller';
        final sellerRef = _firestore.collection('users').doc(sellerId);
        batch.set(sellerRef, {
          'totalOrders': FieldValue.increment(1),
          'totalRevenue': FieldValue.increment(subtotal),
          'lastOrderAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Update product stats
        for (final item in cartItems) {
          final productId = item['productId'] ?? 'unknown_product';
          final quantity = (item['quantity'] is num) ? (item['quantity'] as num).toInt() : 1;
          final productRef = _firestore.collection('products').doc(productId);
          batch.set(productRef, {
            'totalOrders': FieldValue.increment(quantity),
            'lastOrderAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        await batch.commit();
        print('✅ Stats updated for seller and products');
      } catch (statsErr) {
        print('⚠️ Stats update error (non-fatal): $statsErr');
      }
      
      // Defer external-app flows (WhatsApp) until after PayFast redirect
      final shouldDeferExternal = paymentMethod == 'payfast';
      if (!shouldDeferExternal) {
        // Create delivery task for seller (if delivery)
        if (isDelivery) {
          await SellerDeliveryManagementService.createDeliveryTask(
            orderId: orderId,
            sellerId: cartItems.first['sellerId'] ?? 'unknown_seller',
            deliveryDetails: {
              'buyerId': user.uid,
              'buyerName': _getFullCustomerName(customerFirstName, customerLastName),
              'buyerFirstName': customerFirstName?.trim() ?? '',
              'buyerLastName': customerLastName?.trim() ?? '',
              'buyerPhone': customerPhone?.trim() ?? user.phoneNumber ?? '',
              'address': deliveryAddress ?? '',
              'coordinates': userLocation != null ? {
                'lat': userLocation.latitude,
                'lng': userLocation.longitude,
              } : null,
            },
            productHandlingInstructions: productHandlingInstructions ?? {},
          );
        }
        
        // Create pickup booking with real OmniaSA seller
        else if (selectedPickupPoint != null) {
          await RealPickupService.createPickupBooking(
            pickupPointId: selectedPickupPoint['id'] ?? 'unknown_pickup_point',
            orderId: orderId,
            customerName: _getFullCustomerName(customerFirstName, customerLastName),
            customerPhone: user.phoneNumber ?? '+27987654321',
            items: cartItems.map((item) => {
              'productId': item['productId'] ?? 'unknown_product',
              'name': item['name'] ?? 'Unknown Product',
              'quantity': item['quantity'] ?? 1,
              'price': item['price'] != null ? (item['price'] as num).toDouble() : 0.0,
            }).toList(),
          );
        }
      }
      
      // Process payment
      Map<String, dynamic> paymentResult = {};
      if (paymentMethod == 'payfast') {
        paymentResult = await _processPayFastPayment(orderId, grandTotal, user);
      } else if (paymentMethod == 'eft') {
        paymentResult = await _processEFTPayment(orderId, grandTotal);
      } else if (paymentMethod == 'cod') {
        paymentResult = {'success': true, 'method': 'cod', 'message': 'Cash on delivery'};
      }
      
      // Send comprehensive notifications unless deferring for PayFast redirect
      if (!shouldDeferExternal) {
        await _sendOrderNotifications(orderId, user, cartItems, deliveryOTP, grandTotal, customerFirstName, customerLastName);
      }
      
      // Analytics tracking (safe to run anytime)
      await _trackOrderAnalytics(orderId, cartItems, grandTotal, paymentMethod);
      
      return {
        'success': true,
        'orderId': orderId,
        'total': grandTotal,
        'deliveryOTP': deliveryOTP,
        'payment': paymentResult,
        'estimatedDelivery': isDelivery ? _calculateRealisticETA(userLocation) : null,
        'trackingUrl': 'https://www.omniasa.co.za/track/$orderId',
        'message': 'Order placed successfully! 🎉',
      };
      
    } catch (e, stackTrace) {
      if (e is FirebaseException) {
        print('❌ Production order failed [${e.plugin}/${e.code}]: ${e.message}');
      } else {
        print('❌ Production order failed: $e');
      }
      print('Stack trace: $stackTrace');
      
      // Log error for monitoring
      await _logOrderError(e, stackTrace);
      
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Order processing failed. Please try again.',
      };
    }
  }

  /// Finalize after returning from payment (e.g., after PayFast WebView success)
  static Future<void> finalizePostPayment({
    required String orderId,
    required List<Map<String, dynamic>> cartItems,
    required bool isDelivery,
    String? deliveryAddress,
    Map<String, dynamic>? selectedPickupPoint,
    Map<String, dynamic>? productHandlingInstructions,
    String? customerFirstName,
    String? customerLastName,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Create delivery task or pickup booking now
      if (isDelivery) {
        await SellerDeliveryManagementService.createDeliveryTask(
          orderId: orderId,
          sellerId: cartItems.first['sellerId'] ?? 'unknown_seller',
          deliveryDetails: {
            'buyerId': user.uid,
            'buyerName': _getFullCustomerName(customerFirstName, customerLastName),
            'buyerFirstName': customerFirstName?.trim() ?? '',
            'buyerLastName': customerLastName?.trim() ?? '',
            'buyerPhone': user.phoneNumber ?? '',
            'address': deliveryAddress ?? '',
          },
          productHandlingInstructions: productHandlingInstructions ?? {},
        );
      } else if (selectedPickupPoint != null) {
        await RealPickupService.createPickupBooking(
          pickupPointId: selectedPickupPoint['id'] ?? 'unknown_pickup_point',
          orderId: orderId,
          customerName: _getFullCustomerName(customerFirstName, customerLastName),
          customerPhone: user.phoneNumber ?? '+27987654321',
          items: cartItems.map((item) => {
            'productId': item['productId'] ?? 'unknown_product',
            'name': item['name'] ?? 'Unknown Product',
            'quantity': item['quantity'] ?? 1,
            'price': item['price'] != null ? (item['price'] as num).toDouble() : 0.0,
          }).toList(),
        );
      }

      // Notify buyer and seller
      await _sendOrderNotifications(orderId, user, cartItems, null, 0.0, customerFirstName, customerLastName);
    } catch (e) {
      print('⚠️ finalizePostPayment error: $e');
    }
  }
  
  // PRODUCTION-GRADE HELPER METHODS
  
  static Future<Map<String, dynamic>?> _getSellerLocation(String sellerId) async {
    try {
      final sellerDoc = await _firestore.collection('users').doc(sellerId).get();
      if (sellerDoc.exists && sellerDoc.data() != null) {
        final data = sellerDoc.data()!;
        // Support multiple possible field names
        final lat = (data['latitude'] ?? data['storeLatitude']) ?? -25.7461;
        final lng = (data['longitude'] ?? data['storeLongitude']) ?? 28.1881;
        return {'lat': lat, 'lng': lng};
      }
    } catch (e) {
      print('Error getting seller location: $e');
    }
    return null;
  }
  
  static double _calculateSmartDeliveryFee(double distanceKm, List<Map<String, dynamic>> items) {
    // Base fee
    double fee = 15.0;
    
    // Distance-based pricing
    if (distanceKm <= 5) {
      fee += distanceKm * 4.0; // R4/km for short distance
    } else if (distanceKm <= 15) {
      fee += 20 + ((distanceKm - 5) * 6.0); // R6/km for medium distance
    } else {
      fee += 80 + ((distanceKm - 15) * 8.0); // R8/km for long distance
    }
    
    // Item-based surcharge
    final totalItems = items.fold<int>(0, (sum, item) => sum + (item['quantity'] as int));
    if (totalItems > 5) {
      fee += (totalItems - 5) * 2.0; // R2 per extra item
    }
    
    // Weight/category surcharge
    final hasElectronics = items.any((item) => item['category'].toString().toLowerCase().contains('electronics'));
    if (hasElectronics) {
      fee += 10.0; // Electronics handling fee
    }
    
    // Round to nearest R0.50
    return (fee * 2).round() / 2;
  }
  
  static String _calculateRealisticETA(Position? userLocation) {
    if (userLocation == null) return '45-60 minutes';
    
    final now = DateTime.now();
    final hour = now.hour;
    final isWeekend = now.weekday > 5;
    
    int baseMinutes = 30;
    
    // Rush hour adjustments
    if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
      baseMinutes += 15; // Rush hour delay
    }
    
    // Weekend adjustments
    if (isWeekend) {
      baseMinutes += 10;
    }
    
    // Weather/traffic simulation
    baseMinutes += DateTime.now().millisecond % 10; // Random 0-9 min variation
    
    final maxMinutes = baseMinutes + 15;
    return '$baseMinutes-$maxMinutes minutes';
  }
  
  static Future<Map<String, dynamic>> _processPayFastPayment(String orderId, double amount, User user) async {
    try {
      return await PayFastService.createPayment(
        amount: amount.toStringAsFixed(2),
        itemName: 'OmniaSA Order #${orderId.substring(0, 8)}',
        itemDescription: 'Order payment for ${orderId}',
        customerEmail: user.email ?? 'customer@omniasa.co.za',
        customerFirstName: user.displayName?.split(' ').first ?? 'Customer',
        customerLastName: user.displayName?.split(' ').skip(1).join(' ') ?? '',
        customerPhone: user.phoneNumber ?? '',
        customString1: orderId,
        customString2: 'production_order',
        customString3: user.uid,
      );
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _processEFTPayment(String orderId, double amount) async {
    // Generate unique EFT reference
    final reference = 'OMN${orderId.substring(3, 8)}';

    // Load bank details from platform settings (where EFT details are actually stored)
    Map<String, dynamic> bank = {
      'bank': 'FNB',
      'account': '62841234567',
      'branch': '250655',
      'accountHolder': 'OmniaSA (Pty) Ltd',
      'reference': reference,
    };

    try {
      // Look in the correct location: config/platform (Platform Settings)
      final platformDoc = await _firestore.collection('config').doc('platform').get();
      if (platformDoc.exists) {
        final data = platformDoc.data() ?? {};
        // Use the EFT fields from Platform Settings
        bank = {
          'bank': (data['eftBankName'] ?? bank['bank']).toString(),
          'account': (data['eftAccountNumber'] ?? bank['account']).toString(),
          'branch': (data['eftBranchCode'] ?? bank['branch']).toString(),
          'accountHolder': (data['eftAccountName'] ?? bank['accountHolder']).toString(),
          'reference': reference,
        };
        print('✅ Loaded EFT bank details from Platform Settings: ${bank['bank']} - ${bank['account']}');
      } else {
        print('⚠️ Platform settings document not found, using fallback bank details');
      }
    } catch (e) {
      // Fallback to defaults on error
      print('⚠️ Could not load platform EFT bank details: $e');
    }

    return {
      'success': true,
      'method': 'eft',
      'reference': reference,
      'amount': amount,
      'bankDetails': bank,
      'message': 'Use reference: $reference for payment',
    };
  }
  
  // Removed unused _determineOptimalLockerSize to satisfy linter
  
  static Future<void> _sendOrderNotifications(String orderId, User user, List<Map<String, dynamic>> items, String? otp, double total, String? customerFirstName, String? customerLastName) async {
    try {
      final sellerId = items.isNotEmpty ? (items.first['sellerId']?.toString() ?? '') : '';
      // Customer notification
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        await WhatsAppIntegrationService.sendOrderConfirmation(
          orderId: orderId,
          buyerPhone: user.phoneNumber!,
          sellerName: items.first['sellerName'] ?? 'Store',
          totalAmount: total,
          deliveryOTP: otp ?? 'N/A',
        );
      }
      
      // Seller notification
      await WhatsAppIntegrationService.sendNewOrderNotificationToSeller(
        orderId: orderId,
        sellerPhone: '+27606304683', // Get from seller data
        buyerName: _getFullCustomerName(customerFirstName, customerLastName),
        orderTotal: total,
        items: items,
        deliveryAddress: 'Customer address',
      );

      // System app notifications (in-app/badge)
      try {
        final sellerName = items.first['sellerName']?.toString() ?? 'Store';
        final buyerName = _getFullCustomerName(customerFirstName, customerLastName);
        if (sellerId.isNotEmpty) {
          await NotificationService().sendNewOrderNotificationToSeller(
            sellerId: sellerId,
            orderId: orderId,
            buyerName: buyerName,
            orderTotal: total,
            sellerName: sellerName,
          );
        }
        if (user.uid.isNotEmpty) {
          await NotificationService().sendOrderStatusNotificationToBuyer(
            buyerId: user.uid,
            orderId: orderId,
            status: 'created',
            sellerName: sellerName,
          );
        }
      } catch (e) {
        print('NotificationService error: $e');
      }
    } catch (e) {
      print('Notification error: $e');
    }
  }
  
  static Future<void> _trackOrderAnalytics(String orderId, List<Map<String, dynamic>> items, double total, String paymentMethod) async {
    try {
      await _firestore.collection('analytics_events').add({
        'event': 'order_created',
        'orderId': orderId,
        'value': total,
        'itemCount': items.length,
        'paymentMethod': paymentMethod,
        'timestamp': FieldValue.serverTimestamp(),
        'categories': items.map((item) => item['category']).toSet().toList(),
      });
    } catch (e) {
      print('Analytics error: $e');
    }
  }
  
  static Future<String> _getUserIP() async {
    // In production, integrate with IP detection service
    return '196.xxx.xxx.xxx'; // Mock IP
  }
  
  static Future<Map<String, dynamic>> _getDeviceInfo() async {
    // In production, use device_info_plus package
    return {
      'platform': 'android', // or 'ios'
      'version': '1.0.0',
      'model': 'Unknown',
    };
  }
  
  static Future<void> _logOrderError(dynamic error, StackTrace stackTrace) async {
    try {
      await _firestore.collection('error_logs').add({
        'type': 'order_submission_error',
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
        'timestamp': FieldValue.serverTimestamp(),
        'severity': 'high',
      });
    } catch (e) {
      print('Failed to log error: $e');
    }
  }
  
  /// Helper function to create full customer name
  static String _getFullCustomerName(String? firstName, String? lastName) {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    if (first.isEmpty && last.isEmpty) return 'Customer';
    if (first.isEmpty) return last;
    if (last.isEmpty) return first;
    return '$first $last';
  }
}

