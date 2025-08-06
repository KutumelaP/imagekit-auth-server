import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UrbanDeliveryService {
  // Urban delivery zones for Gauteng and Cape Town
  static const Map<String, Map<String, dynamic>> _urbanZones = {
    'gauteng': {
      'sandton': {
        'name': 'Sandton',
        'center': {'lat': -26.1076, 'lng': 28.0567},
        'radius': 15.0,
        'type': 'premium',
        'categories': ['electronics', 'food', 'clothes'],
        'peak_hours': {'lunch': '11:00-14:00', 'dinner': '18:00-21:00'},
      },
      'rosebank': {
        'name': 'Rosebank',
        'center': {'lat': -26.1420, 'lng': 28.0444},
        'radius': 12.0,
        'type': 'standard',
        'categories': ['food', 'clothes', 'electronics'],
        'peak_hours': {'lunch': '11:00-14:00', 'dinner': '18:00-21:00'},
      },
      'pretoria_hatfield': {
        'name': 'Pretoria Hatfield',
        'center': {'lat': -25.7479, 'lng': 28.2293},
        'radius': 10.0,
        'type': 'student',
        'categories': ['food', 'clothes', 'electronics'],
        'peak_hours': {'lunch': '11:00-14:00', 'dinner': '18:00-21:00'},
      },
      'fourways': {
        'name': 'Fourways',
        'center': {'lat': -26.0167, 'lng': 28.0167},
        'radius': 12.0,
        'type': 'standard',
        'categories': ['food', 'clothes', 'electronics'],
        'peak_hours': {'lunch': '11:00-14:00', 'dinner': '18:00-21:00'},
      },
    },
    'cape_town': {
      'va_waterfront': {
        'name': 'V&A Waterfront',
        'center': {'lat': -33.9036, 'lng': 18.4207},
        'radius': 8.0,
        'type': 'premium',
        'categories': ['food', 'clothes', 'electronics'],
        'peak_hours': {'lunch': '11:00-14:00', 'dinner': '18:00-21:00'},
      },
      'camps_bay': {
        'name': 'Camps Bay',
        'center': {'lat': -33.9500, 'lng': 18.3833},
        'radius': 6.0,
        'type': 'premium',
        'categories': ['food', 'clothes'],
        'peak_hours': {'lunch': '11:00-14:00', 'dinner': '18:00-21:00'},
      },
      'cbd': {
        'name': 'Cape Town CBD',
        'center': {'lat': -33.9249, 'lng': 18.4241},
        'radius': 10.0,
        'type': 'standard',
        'categories': ['food', 'clothes', 'electronics'],
        'peak_hours': {'lunch': '11:00-14:00', 'dinner': '18:00-21:00'},
      },
      'observatory': {
        'name': 'Observatory',
        'center': {'lat': -33.9333, 'lng': 18.4667},
        'radius': 8.0,
        'type': 'student',
        'categories': ['food', 'clothes'],
        'peak_hours': {'lunch': '11:00-14:00', 'dinner': '18:00-21:00'},
      },
    },
  };

  // Category-specific delivery options
  static const Map<String, Map<String, dynamic>> _categoryDeliveryOptions = {
    'electronics': {
      'name': 'Secure Electronics Delivery',
      'base_fee': 60.0,
      'max_distance': 20.0,
      'features': ['Signature Required', 'Insurance Included', 'Installation Available'],
      'delivery_time': '45-90 minutes',
      'icon': '💻',
      'specialized': true,
    },
    'food': {
      'name': 'Fast Food Delivery',
      'base_fee': 30.0,
      'max_distance': 10.0,
      'features': ['Hot Food Bags', '30-Minute Guarantee', 'Temperature Controlled'],
      'delivery_time': '20-45 minutes',
      'icon': '🍕',
      'specialized': true,
    },
    'clothes': {
      'name': 'Fashion Delivery',
      'base_fee': 40.0,
      'max_distance': 15.0,
      'features': ['Try-On Returns', 'Size Exchange', 'Styling Service'],
      'delivery_time': '30-60 minutes',
      'icon': '👕',
      'specialized': false,
    },
    'other': {
      'name': 'Standard Delivery',
      'base_fee': 35.0,
      'max_distance': 15.0,
      'features': ['Standard Handling', 'Tracking Included'],
      'delivery_time': '45-90 minutes',
      'icon': '📦',
      'specialized': false,
    },
  };

  // Peak hour multipliers
  static const Map<String, double> _peakHourMultipliers = {
    'lunch': 1.2, // +20% during lunch rush
    'dinner': 1.15, // +15% during dinner rush
    'off_peak': 0.85, // -15% during off-peak
    'late_night': 0.8, // -20% during late night
  };

  // Zone type multipliers
  static const Map<String, double> _zoneTypeMultipliers = {
    'premium': 1.3, // +30% for premium areas
    'standard': 1.0, // Standard pricing
    'student': 0.9, // -10% for student areas
  };

  /// Check if a location is in an urban delivery zone
  static bool isUrbanDeliveryZone(double latitude, double longitude) {
    for (String province in _urbanZones.keys) {
      for (String zone in _urbanZones[province]!.keys) {
        final zoneData = _urbanZones[province]![zone]!;
        final center = zoneData['center']!;
        final radius = zoneData['radius']!;
        
        final distance = Geolocator.distanceBetween(
          latitude, longitude,
          center['lat'], center['lng'],
        ) / 1000; // Convert to km
        
        if (distance <= radius) {
          return true;
        }
      }
    }
    return false;
  }

  /// Get the urban zone for a location
  static Map<String, dynamic>? getUrbanZone(double latitude, double longitude) {
    for (String province in _urbanZones.keys) {
      for (String zone in _urbanZones[province]!.keys) {
        final zoneData = _urbanZones[province]![zone]!;
        final center = zoneData['center']!;
        final radius = zoneData['radius']!;
        
        final distance = Geolocator.distanceBetween(
          latitude, longitude,
          center['lat'], center['lng'],
        ) / 1000; // Convert to km
        
        if (distance <= radius) {
          return {
            'province': province,
            'zone': zone,
            'zoneData': zoneData,
            'distance': distance,
          };
        }
      }
    }
    return null;
  }

  /// Calculate urban delivery fee
  static Map<String, dynamic> calculateUrbanDeliveryFee({
    required double latitude,
    required double longitude,
    required String category,
    required double distance,
    DateTime? deliveryTime,
  }) {
    final urbanZone = getUrbanZone(latitude, longitude);
    if (urbanZone == null) {
      return {
        'isUrbanDelivery': false,
        'fee': 0.0,
        'message': 'Not in urban delivery zone',
      };
    }

    final zoneData = urbanZone['zoneData']!;
    final zoneType = zoneData['type']!;
    final categories = List<String>.from(zoneData['categories']!);

    // Check if category is supported in this zone
    if (!categories.contains(category)) {
      return {
        'isUrbanDelivery': false,
        'fee': 0.0,
        'message': 'Category not supported in this zone',
      };
    }

    // Get category delivery options
    final categoryOptions = _categoryDeliveryOptions[category]!;
    double baseFee = categoryOptions['base_fee']!.toDouble();
    final maxDistance = categoryOptions['max_distance']!.toDouble();

    // Apply distance-based pricing
    if (distance > maxDistance) {
      return {
        'isUrbanDelivery': false,
        'fee': 0.0,
        'message': 'Distance exceeds maximum for this category',
      };
    }

    // Apply zone type multiplier
    baseFee *= _zoneTypeMultipliers[zoneType]!;

    // Apply peak hour multiplier
    double peakMultiplier = 1.0;
    if (deliveryTime != null) {
      final hour = deliveryTime.hour;
      if (hour >= 11 && hour <= 14) {
        peakMultiplier = _peakHourMultipliers['lunch']!;
      } else if (hour >= 18 && hour <= 21) {
        peakMultiplier = _peakHourMultipliers['dinner']!;
      } else if (hour >= 14 && hour <= 17) {
        peakMultiplier = _peakHourMultipliers['off_peak']!;
      } else if (hour >= 21 || hour <= 6) {
        peakMultiplier = _peakHourMultipliers['late_night']!;
      }
    }

    final finalFee = baseFee * peakMultiplier;

    return {
      'isUrbanDelivery': true,
      'fee': finalFee,
      'zoneName': zoneData['name'],
      'zoneType': zoneType,
      'category': category,
      'baseFee': baseFee,
      'peakMultiplier': peakMultiplier,
      'deliveryTime': categoryOptions['delivery_time'],
      'features': categoryOptions['features'],
      'icon': categoryOptions['icon'],
      'specialized': categoryOptions['specialized'],
      'message': 'Urban delivery available',
    };
  }

  /// Get available delivery options for a location and category
  static List<Map<String, dynamic>> getUrbanDeliveryOptions({
    required double latitude,
    required double longitude,
    required String category,
    DateTime? deliveryTime,
  }) {
    final urbanZone = getUrbanZone(latitude, longitude);
    if (urbanZone == null) {
      return [];
    }

    final zoneData = urbanZone['zoneData']!;
    final categories = List<String>.from(zoneData['categories']!);

    if (!categories.contains(category)) {
      return [];
    }

    final categoryOptions = _categoryDeliveryOptions[category]!;
    final distance = urbanZone['distance']!;

    // Standard urban delivery
    final standardDelivery = calculateUrbanDeliveryFee(
      latitude: latitude,
      longitude: longitude,
      category: category,
      distance: distance,
      deliveryTime: deliveryTime,
    );

    List<Map<String, dynamic>> options = [
      {
        'type': 'urban_standard',
        'name': categoryOptions['name'],
        'fee': standardDelivery['fee'],
        'time': categoryOptions['delivery_time'],
        'features': categoryOptions['features'],
        'icon': categoryOptions['icon'],
        'recommended': true,
      },
    ];

    // Add premium options for electronics
    if (category == 'electronics') {
      options.add({
        'type': 'urban_premium',
        'name': 'Premium Electronics Delivery',
        'fee': standardDelivery['fee'] * 1.5,
        'time': '30-60 minutes',
        'features': ['Priority Service', 'Installation Included', 'Extended Warranty'],
        'icon': '⭐',
        'recommended': false,
      });
    }

    // Add express options for food
    if (category == 'food') {
      options.add({
        'type': 'urban_express',
        'name': 'Express Food Delivery',
        'fee': standardDelivery['fee'] * 1.3,
        'time': '15-25 minutes',
        'features': ['Ultra-Fast Delivery', 'Priority Queue', 'Hot Food Guarantee'],
        'icon': '⚡',
        'recommended': false,
      });
    }

    return options;
  }

  /// Get urban delivery benefits
  static List<Map<String, dynamic>> getUrbanDeliveryBenefits() {
    return [
      {
        'title': 'Category-Specific Service',
        'description': 'Specialized delivery for electronics, food, clothes, and more',
        'icon': '📦',
      },
      {
        'title': 'Dynamic Pricing',
        'description': 'Lower prices during off-peak hours, premium during rush',
        'icon': '💰',
      },
      {
        'title': 'Zone Optimization',
        'description': 'Optimized delivery zones for Gauteng and Cape Town',
        'icon': '📍',
      },
      {
        'title': 'Peak Hour Management',
        'description': 'Efficient handling of lunch and dinner rush periods',
        'icon': '⏰',
      },
      {
        'title': 'Local Partnerships',
        'description': 'Direct partnerships with local businesses',
        'icon': '🤝',
      },
    ];
  }

  /// Get urban delivery zones info
  static Map<String, List<Map<String, dynamic>>> getUrbanZonesInfo() {
    Map<String, List<Map<String, dynamic>>> zonesByProvince = {};

    for (String province in _urbanZones.keys) {
      List<Map<String, dynamic>> zones = [];
      
      for (String zone in _urbanZones[province]!.keys) {
        final zoneData = _urbanZones[province]![zone]!;
        zones.add({
          'name': zoneData['name'],
          'type': zoneData['type'],
          'categories': zoneData['categories'],
          'radius': zoneData['radius'],
        });
      }
      
      zonesByProvince[province] = zones;
    }

    return zonesByProvince;
  }

  /// Check driver availability for urban delivery
  static Future<bool> checkUrbanDriverAvailability({
    required String zone,
    required String category,
    required DateTime deliveryTime,
  }) async {
    // Simulate driver availability check
    // In real implementation, this would query the drivers collection
    final hour = deliveryTime.hour;
    
    // More drivers available during peak hours
    if (hour >= 11 && hour <= 14 || hour >= 18 && hour <= 21) {
      return true; // High availability during peak
    } else if (hour >= 7 && hour <= 22) {
      return true; // Good availability during business hours
    } else {
      return false; // Limited availability during late night
    }
  }

  /// Get urban delivery statistics
  static Map<String, dynamic> getUrbanDeliveryStats() {
    return {
      'totalZones': 8,
      'provinces': ['gauteng', 'cape_town'],
      'categories': ['electronics', 'food', 'clothes', 'other'],
      'peakHours': {
        'lunch': '11:00-14:00',
        'dinner': '18:00-21:00',
      },
      'averageDeliveryTime': {
        'electronics': '45-90 minutes',
        'food': '20-45 minutes',
        'clothes': '30-60 minutes',
        'other': '45-90 minutes',
      },
    };
  }
} 