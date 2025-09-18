import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

import 'simple_store_profile_screen.dart';

// Helper to enrich store data with fallback address and reviews aggregates
Future<Map<String, dynamic>> _enrichStoreData(
  String storeId,
  Map<String, dynamic> baseData,
) async {
  final Map<String, dynamic> data = Map<String, dynamic>.from(baseData);

  // Ensure storeId present
  data.putIfAbsent('storeId', () => storeId);

  // Prefer a real address if available over generic/online placeholders
  try {
    String? locationText = (data['location'] is String) ? (data['location'] as String?) : null;
    String? candidateAddress;

    // Common address field candidates
    final dynamic locField = data['location'];
    final List<dynamic> candidates = <dynamic>[
      data['address'],
      data['storeAddress'],
      data['locationAddress'],
      data['streetAddress'],
      data['pickupAddress'],
      (locField is Map<String, dynamic>) ? locField['address'] : null,
    ];
    for (final dynamic v in candidates) {
      if (v is String && v.trim().isNotEmpty) {
        candidateAddress = v.trim();
        break;
      }
    }

    // If existing location is empty or says online, and we have a candidate address, use it
    final bool looksOnlineOnly = (locationText != null &&
        locationText.toLowerCase().contains('online'));
    if ((locationText == null || locationText.trim().isEmpty || looksOnlineOnly) &&
        candidateAddress != null && candidateAddress.isNotEmpty) {
      data['location'] = candidateAddress;
    }
  } catch (_) {
    // Non-fatal
  }

  // Calculate delivery availability and distance information for direct store access
  try {
    // Get user location to calculate distance and delivery availability
    Position? userPosition;
    try {
      userPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('📍 Could not get user location for store access: $e');
      userPosition = null;
    }
    
    // Calculate distance and delivery info if location available
    if (userPosition != null) {
      final storeLat = _parseCoordinate(data['latitude']);
      final storeLng = _parseCoordinate(data['longitude']);
      
      if (storeLat != null && storeLng != null) {
        // Calculate distance using Geolocator
        final distance = Geolocator.distanceBetween(
          userPosition.latitude, 
          userPosition.longitude, 
          storeLat, 
          storeLng
        ) / 1000; // Convert to km
        
        // Get delivery settings
        final deliveryRangeRaw = (data['deliveryRange'] ?? 0.0).toDouble();
        final bool deliveryAvailable = data['deliveryAvailable'] == true;
        final bool pargoEnabled = data['pargoEnabled'] == true;
        final bool paxiEnabled = data['paxiEnabled'] == true;
        final bool pudoEnabled = data['pudoEnabled'] == true;
        final String category = (data['storeCategory'] ?? '').toString();
        
        // Calculate service radius using same logic as store_page.dart
        const double foodCapKm = 20.0;
        const double nonFoodDeliveryCapKm = 50.0;
        final bool hasPickup = pudoEnabled || pargoEnabled || paxiEnabled;
        final bool isFood = _isFoodCategory(category);
        
        double serviceRadiusKm;
        if (deliveryAvailable && deliveryRangeRaw > 0) {
          serviceRadiusKm = isFood
              ? deliveryRangeRaw.clamp(1.0, foodCapKm)
              : deliveryRangeRaw.clamp(1.0, nonFoodDeliveryCapKm);
        } else if (hasPickup) {
          serviceRadiusKm = isFood ? 12.0 : 30.0;
        } else {
          serviceRadiusKm = 5.0;
        }
        
        // Check if store has national delivery options
        final hasNationalDelivery = hasPickup && !isFood; // Nationwide pickup for non-food stores
        
        // Add distance and delivery info to store data
        data['distance'] = distance;
        data['serviceRadius'] = serviceRadiusKm;
        data['withinDeliveryRange'] = distance <= serviceRadiusKm || hasNationalDelivery;
        data['deliveryAvailable'] = deliveryAvailable;
        data['hasPickupOptions'] = hasPickup;
        data['hasNationalDelivery'] = hasNationalDelivery;
        data['pargoEnabled'] = pargoEnabled;
        data['paxiEnabled'] = paxiEnabled;
        data['pudoEnabled'] = pudoEnabled;
        data['showDistanceWarning'] = !hasNationalDelivery && distance > serviceRadiusKm;
        
        print('📍 Distance calculated for direct store access:');
        print('   Distance: ${distance.toStringAsFixed(1)}km');
        print('   Service Radius: ${serviceRadiusKm.toStringAsFixed(1)}km');
        print('   Within Range: ${distance <= serviceRadiusKm}');
        print('   Delivery Available: $deliveryAvailable');
        print('   Pickup Options: $hasPickup');
        print('   National Delivery: $hasNationalDelivery');
        print('   Show Distance Warning: ${!hasNationalDelivery && distance > serviceRadiusKm}');
      }
    } else {
      // No location available - set defaults but still show store
      final bool pargoEnabled = data['pargoEnabled'] == true;
      final bool paxiEnabled = data['paxiEnabled'] == true;
      final bool pudoEnabled = data['pudoEnabled'] == true;
      final String category = (data['storeCategory'] ?? '').toString();
      final bool hasPickup = pudoEnabled || pargoEnabled || paxiEnabled;
      final bool isFood = _isFoodCategory(category);
      final hasNationalDelivery = hasPickup && !isFood;
      
      data['distance'] = null;
      data['serviceRadius'] = data['deliveryRange'] ?? 10.0;
      data['withinDeliveryRange'] = hasNationalDelivery; // Allow if national delivery available
      data['hasNationalDelivery'] = hasNationalDelivery;
      data['locationUnavailable'] = true;
      data['showDistanceWarning'] = !hasNationalDelivery; // Show warning only if no national options
    }
  } catch (e) {
    print('❌ Error calculating delivery info: $e');
    // Still show store even if delivery calculation fails
    data['distance'] = null;
    data['withinDeliveryRange'] = false;
  }

  // Fetch products to get product images for consistency with store listing
  try {
    final QuerySnapshot allProductsQuery = await FirebaseFirestore.instance
        .collection('products')
        .where('ownerId', isEqualTo: storeId)
        .limit(5)
        .get();

    // Get product images from ALL categories - limit to 3 (same logic as store_page.dart)
    final productImages = allProductsQuery.docs
        .map((doc) {
          // Try multiple possible image field names
          final imageUrl = doc['imageUrl'] ?? doc['image'] ?? doc['photoUrl'] ?? doc['photo'] ?? doc['images']?[0];
          
          // Additional validation for image URL
          if (imageUrl != null && imageUrl is String && imageUrl.isNotEmpty) {
            // Check if URL is valid
            try {
              final uri = Uri.parse(imageUrl);
              if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
                return imageUrl;
              }
            } catch (e) {
              // Invalid image URL, skip it
            }
          }
          return null;
        })
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .take(3) // Limit to 3 images to reduce load
        .toList();

    // Remove profile image from product images to avoid duplication (same as store_page.dart)
    final cleanProductImages = productImages.where((url) => 
      url != data['profileImageUrl']
    ).toList();

    // Add product image fields for consistency with store listing
    data['productImages'] = cleanProductImages;
    data['productSnippetImages'] = cleanProductImages.length > 3 ? cleanProductImages.sublist(0, 3) : cleanProductImages;
  } catch (_) {
    // On error, provide empty product images
    data.putIfAbsent('productImages', () => <String>[]);
    data.putIfAbsent('productSnippetImages', () => <String>[]);
  }

  // Aggregate reviews (average + count). If permission denied, skip silently.
  try {
    final QuerySnapshot reviewsSnap = await FirebaseFirestore.instance
        .collection('reviews')
        .where('storeId', isEqualTo: storeId)
        .get();
    final int count = reviewsSnap.docs.length;
    if (count > 0) {
      double sum = 0.0;
      for (final doc in reviewsSnap.docs) {
        final Map<String, dynamic> r = doc.data() as Map<String, dynamic>;
        final num ratingNum = (r['rating'] ?? 0) as num;
        sum += ratingNum.toDouble();
      }
      data['reviewCount'] = count;
      data['rating'] = sum / count;
      data['avgRating'] = sum / count; // For consistency with store listing display
    } else {
      data.putIfAbsent('reviewCount', () => 0);
      data.putIfAbsent('rating', () => 0.0);
      data.putIfAbsent('avgRating', () => 0.0); // For consistency with store listing display
    }
  } catch (_) {
    // On permission or network error, keep existing fallback fields if present
    data.putIfAbsent('reviewCount', () => 0);
    data.putIfAbsent('rating', () => 0.0);
    data.putIfAbsent('avgRating', () => 0.0); // For consistency with store listing display
  }

  return data;
}

class StoreProfileRouteLoader extends StatelessWidget {
  final String storeId;
  const StoreProfileRouteLoader({required this.storeId});

  @override
  Widget build(BuildContext context) {
    // 🔍 DEBUG: Log when the loader is built
    print('🔗 STORE LOADER DEBUG: Building StoreProfileRouteLoader for storeId: $storeId');
    
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(storeId).get(),
      builder: (context, snapshot) {
        // 🔍 DEBUG: Log the snapshot state
        print('🔗 STORE LOADER DEBUG: Snapshot state: ${snapshot.connectionState}');
        print('🔗 STORE LOADER DEBUG: Has data: ${snapshot.hasData}');
        print('🔗 STORE LOADER DEBUG: Data exists: ${snapshot.data?.exists}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('🔗 STORE LOADER DEBUG: Showing loading indicator');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          print('🔗 STORE LOADER DEBUG: Store not found - showing error');
          return const Scaffold(
            body: Center(child: Text('Store not found')),
          );
        }
        
        final raw = snapshot.data!.data()!..putIfAbsent('storeId', () => storeId);
        print('🔗 STORE LOADER DEBUG: Store data loaded successfully, enriching and navigating...');

        return FutureBuilder<Map<String, dynamic>>(
          future: _enrichStoreData(storeId, raw),
          builder: (context, enrichSnap) {
            if (enrichSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final enriched = enrichSnap.data ?? raw;
            return SimpleStoreProfileScreen(store: enriched);
          },
        );
      },
    );
  }
}

/// Helper function to parse coordinates
double? _parseCoordinate(dynamic coord) {
  if (coord == null) return null;
  if (coord is double) return coord;
  if (coord is int) return coord.toDouble();
  if (coord is String) {
    try {
      return double.parse(coord);
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Helper function to check if a category is food-related
bool _isFoodCategory(String category) {
  final foodCategories = ['food', 'restaurants', 'groceries', 'fresh produce', 'bakery'];
  return foodCategories.any((food) => category.toLowerCase().contains(food.toLowerCase()));
}