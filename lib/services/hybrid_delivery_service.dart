import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'rural_delivery_service.dart';
import 'urban_delivery_service.dart';
import 'delivery_fulfillment_service.dart';

class HybridDeliveryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// **HYBRID DELIVERY MODES**
  /// 1. Platform-Managed: Uses platform drivers (existing system)
  /// 2. Seller-Managed: Seller handles their own delivery
  /// 3. Hybrid: Platform drivers + seller drivers
  /// 4. Pickup-Only: Customer picks up from store

  /// **GET DELIVERY OPTIONS FOR SELLER**
  static Future<Map<String, dynamic>> getDeliveryOptions({
    required String sellerId,
    required double sellerLat,
    required double sellerLng,
    required String category,
  }) async {
    try {
      // Get seller's delivery preferences
      final sellerDoc = await _firestore.collection('users').doc(sellerId).get();
      final sellerData = sellerDoc.data() ?? {};
      
      final deliveryMode = sellerData['deliveryMode'] ?? 'hybrid'; // platform, seller, hybrid, pickup
      final sellerDeliveryEnabled = sellerData['sellerDeliveryEnabled'] ?? false;
      final platformDeliveryEnabled = sellerData['platformDeliveryEnabled'] ?? true;
      
      Map<String, dynamic> options = {
        'pickup': {
          'name': 'Free Pickup',
          'fee': 0.0,
          'time': '15-20 minutes',
          'description': 'Collect from store - save money!',
          'icon': '🏪',
          'available': true,
          'recommended': true
        }
      };

      // Add seller-managed delivery if enabled
      if (sellerDeliveryEnabled) {
        options['seller_delivery'] = {
          'name': 'Store Delivery',
          'fee': _calculateSellerDeliveryFee(sellerData),
          'time': sellerData['sellerDeliveryTime'] ?? '30-45 minutes',
          'description': 'Direct delivery from store',
          'icon': '🚚',
          'available': true,
          'recommended': false
        };
      }

      // Add platform delivery if enabled
      if (platformDeliveryEnabled) {
        final isRural = _isRuralLocation(sellerLat, sellerLng);
        
        if (isRural) {
          // Add rural delivery options - using existing rural delivery logic
          options['rural_community'] = {
            'name': 'Community Driver',
            'fee': 18.0,
            'time': '25-35 minutes',
            'description': 'Local community driver - better rates!',
            'icon': '🚴‍♂️',
            'available': true,
            'recommended': true
          };
          options['rural_batch'] = {
            'name': 'Batch Delivery',
            'fee': 15.0,
            'time': '30-45 minutes',
            'description': 'Multiple orders, lower cost',
            'icon': '📦',
            'available': true,
            'recommended': false
          };
        } else {
          // Add urban delivery options - using existing urban delivery logic
          switch (category.toLowerCase()) {
            case 'food':
              options['urban_food'] = {
                'name': 'Fast Food Delivery',
                'fee': 30.0,
                'time': '20-45 minutes',
                'description': 'Hot food bags, temperature controlled',
                'icon': '🍕',
                'available': true,
                'recommended': true
              };
              break;
            case 'electronics':
              options['urban_electronics'] = {
                'name': 'Secure Electronics Delivery',
                'fee': 60.0,
                'time': '45-90 minutes',
                'description': 'Signature required, insurance included',
                'icon': '💻',
                'available': true,
                'recommended': true
              };
              break;
            case 'clothes':
              options['urban_clothes'] = {
                'name': 'Fashion Delivery',
                'fee': 40.0,
                'time': '30-60 minutes',
                'description': 'Professional fashion delivery',
                'icon': '👕',
                'available': true,
                'recommended': true
              };
              break;
            default:
              options['urban_standard'] = {
                'name': 'Standard Delivery',
                'fee': 35.0,
                'time': '30-60 minutes',
                'description': 'Reliable standard delivery',
                'icon': '🚚',
                'available': true,
                'recommended': false
              };
          }
        }
      }

      return {
        'deliveryMode': deliveryMode,
        'options': options,
        'sellerDeliveryEnabled': sellerDeliveryEnabled,
        'platformDeliveryEnabled': platformDeliveryEnabled,
      };
      
    } catch (e) {
      print('🔍 DEBUG: Error getting delivery options: $e');
      return {
        'deliveryMode': 'pickup',
        'options': {
          'pickup': {
            'name': 'Free Pickup',
            'fee': 0.0,
            'time': '15-20 minutes',
            'description': 'Collect from store',
            'icon': '🏪',
            'available': true,
            'recommended': true
          }
        },
        'sellerDeliveryEnabled': false,
        'platformDeliveryEnabled': false,
      };
    }
  }

  /// **PROCESS DELIVERY SELECTION**
  static Future<Map<String, dynamic>> processDeliverySelection({
    required String orderId,
    required String sellerId,
    required String deliveryType, // 'pickup', 'seller_delivery', 'platform_rural', 'platform_urban'
    required double deliveryLat,
    required double deliveryLng,
    required String category,
  }) async {
    try {
      final sellerDoc = await _firestore.collection('users').doc(sellerId).get();
      final sellerData = sellerDoc.data() ?? {};
      
      Map<String, dynamic> result = {
        'success': true,
        'deliveryType': deliveryType,
        'assignedDriver': null,
        'deliveryFee': 0.0,
        'estimatedTime': '',
      };

      switch (deliveryType) {
        case 'pickup':
          result['deliveryFee'] = 0.0;
          result['estimatedTime'] = '15-20 minutes';
          break;

        case 'seller_delivery':
          // Seller handles delivery themselves
          result['deliveryFee'] = _calculateSellerDeliveryFee(sellerData);
          result['estimatedTime'] = sellerData['sellerDeliveryTime'] ?? '30-45 minutes';
          result['assignedDriver'] = {
            'name': sellerData['storeName'] ?? 'Store',
            'phone': sellerData['contact'] ?? '',
            'type': 'seller_delivery',
          };
          break;

        case 'platform_rural':
        case 'platform_urban':
          // Use platform drivers
          final driver = await DeliveryFulfillmentService.assignDriverToOrder(
            orderId: orderId,
            sellerId: sellerId,
            pickupLatitude: sellerData['latitude'] ?? 0.0,
            pickupLongitude: sellerData['longitude'] ?? 0.0,
            deliveryLatitude: deliveryLat,
            deliveryLongitude: deliveryLng,
            deliveryType: deliveryType == 'platform_rural' ? 'rural' : 'urban',
            category: category,
          );
          
          if (driver != null) {
            result['assignedDriver'] = driver;
            result['deliveryFee'] = _calculatePlatformDeliveryFee(deliveryType, category);
            result['estimatedTime'] = deliveryType == 'platform_rural' ? '45-90 minutes' : '30-60 minutes';
          } else {
            result['success'] = false;
            result['error'] = 'No drivers available. Please try pickup or seller delivery.';
          }
          break;
      }

      // Update order with delivery details
      await _firestore.collection('orders').doc(orderId).update({
        'deliveryType': deliveryType,
        'deliveryFee': result['deliveryFee'],
        'estimatedDeliveryTime': result['estimatedTime'],
        'assignedDriver': result['assignedDriver'],
      });

      return result;
      
    } catch (e) {
      print('🔍 DEBUG: Error processing delivery selection: $e');
      return {
        'success': false,
        'error': 'Failed to process delivery selection',
      };
    }
  }

  /// **CALCULATE SELLER DELIVERY FEE**
  static double _calculateSellerDeliveryFee(Map<String, dynamic> sellerData) {
    final baseFee = (sellerData['sellerDeliveryBaseFee'] ?? 25.0).toDouble();
    final feePerKm = (sellerData['sellerDeliveryFeePerKm'] ?? 2.0).toDouble();
    final maxFee = (sellerData['sellerDeliveryMaxFee'] ?? 50.0).toDouble();
    
    // This would be calculated based on actual delivery distance
    return baseFee.clamp(0.0, maxFee);
  }

  /// **CALCULATE PLATFORM DELIVERY FEE**
  static double _calculatePlatformDeliveryFee(String deliveryType, String category) {
    if (deliveryType == 'platform_rural') {
      return 35.0; // Rural delivery base fee
    } else {
      // Urban delivery - category-based
      switch (category.toLowerCase()) {
        case 'food':
          return 30.0;
        case 'electronics':
          return 60.0;
        case 'clothes':
          return 40.0;
        default:
          return 35.0;
      }
    }
  }

  /// **CHECK IF LOCATION IS RURAL**
  static bool _isRuralLocation(double lat, double lng) {
    // Simple logic - you can enhance this based on your needs
    // For now, using distance from major cities
    final johannesburg = {'lat': -26.2041, 'lng': 28.0473};
    final capeTown = {'lat': -33.9249, 'lng': 18.4241};
    
    final distanceFromJHB = _calculateDistance(lat, lng, johannesburg['lat']!, johannesburg['lng']!);
    final distanceFromCT = _calculateDistance(lat, lng, capeTown['lat']!, capeTown['lng']!);
    
    // If more than 50km from major cities, consider rural
    return distanceFromJHB > 50.0 && distanceFromCT > 50.0;
  }

  /// **CALCULATE DISTANCE BETWEEN TWO POINTS**
  static double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371.0; // Earth's radius in kilometers
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        (sin(lat1) * sin(lat2) * sin(dLng / 2) * sin(dLng / 2));
    final c = 2 * atan(sqrt(a) / sqrt(1 - a));
    
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (3.14159 / 180);
  }
} 