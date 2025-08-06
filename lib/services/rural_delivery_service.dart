import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

class RuralDeliveryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Rural delivery zones and pricing
  static const Map<String, Map<String, dynamic>> _ruralZones = {
    'zone1': {
      'name': 'Local Area (0-5km)',
      'minDistance': 0.0,
      'maxDistance': 5.0,
      'baseFee': 20.0,
      'feePerKm': 0.0,
      'maxFee': 20.0,
      'deliveryTime': '20-30 minutes',
      'description': 'Fast local delivery'
    },
    'zone2': {
      'name': 'Nearby Area (5-10km)',
      'minDistance': 5.0,
      'maxDistance': 10.0,
      'baseFee': 35.0,
      'feePerKm': 3.0,
      'maxFee': 50.0,
      'deliveryTime': '30-45 minutes',
      'description': 'Reliable nearby delivery'
    },
    'zone3': {
      'name': 'Extended Area (10-15km)',
      'minDistance': 10.0,
      'maxDistance': 15.0,
      'baseFee': 50.0,
      'feePerKm': 4.0,
      'maxFee': 80.0,
      'deliveryTime': '45-60 minutes',
      'description': 'Extended area delivery'
    },
    'zone4': {
      'name': 'Rural Area (15km+)',
      'minDistance': 15.0,
      'maxDistance': double.infinity,
      'baseFee': 80.0,
      'feePerKm': 5.0,
      'maxFee': 150.0,
      'deliveryTime': '60-90 minutes',
      'description': 'Rural area delivery'
    }
  };

  // Rural delivery options with community network
  static const Map<String, Map<String, dynamic>> _deliveryOptions = {
    'pickup': {
      'name': 'Free Pickup',
      'fee': 0.0,
      'time': '15-20 minutes',
      'description': 'Collect from store - save money!',
      'icon': '🏪',
      'recommended': true
    },
    'local': {
      'name': 'Local Delivery',
      'fee': 20.0,
      'time': '20-30 minutes',
      'description': 'Fast local delivery',
      'icon': '🚚',
      'recommended': false
    },
    'community': {
      'name': 'Community Driver',
      'fee': 18.0,
      'time': '25-35 minutes',
      'description': 'Local community driver - better rates!',
      'icon': '🚴‍♂️',
      'recommended': true
    },
    'batch': {
      'name': 'Batch Delivery',
      'fee': 15.0,
      'time': '30-45 minutes',
      'description': 'Multiple orders, lower cost',
      'icon': '📦',
      'recommended': false
    },
    'scheduled': {
      'name': 'Scheduled Delivery',
      'fee': 25.0,
      'time': 'As scheduled',
      'description': 'Choose your delivery time',
      'icon': '📅',
      'recommended': false
    },
    'student': {
      'name': 'Student Driver',
      'fee': 16.0,
      'time': '20-30 minutes',
      'description': 'Local student driver - flexible hours',
      'icon': '🎓',
      'recommended': false
    },
    'parttime': {
      'name': 'Part-time Driver',
      'fee': 17.0,
      'time': '25-40 minutes',
      'description': 'Reliable part-time community driver',
      'icon': '⏰',
      'recommended': false
    }
  };

  /// Calculate rural delivery fee based on distance
  static Map<String, dynamic> calculateRuralDeliveryFee({
    required double distance,
    required String storeId,
    String? deliveryType,
  }) {
    // Find the appropriate zone
    String zoneKey = 'zone1';
    for (String key in _ruralZones.keys) {
      final zone = _ruralZones[key]!;
      if (distance >= zone['minDistance'] && distance <= zone['maxDistance']) {
        zoneKey = key;
        break;
      }
    }

    final zone = _ruralZones[zoneKey]!;
    double baseFee = zone['baseFee'].toDouble();
    double feePerKm = zone['feePerKm'].toDouble();
    double maxFee = zone['maxFee'].toDouble();

    // Calculate fee
    double calculatedFee = baseFee + (distance * feePerKm);
    double finalFee = min(calculatedFee, maxFee);

    // Apply rural discounts
    if (distance > 10.0) {
      finalFee *= 0.9; // 10% discount for rural areas
    }

    // Apply batch delivery discount
    if (deliveryType == 'batch') {
      finalFee *= 0.8; // 20% discount for batch delivery
    }

    return {
      'zone': zoneKey,
      'zoneName': zone['name'],
      'distance': distance,
      'baseFee': baseFee,
      'feePerKm': feePerKm,
      'calculatedFee': calculatedFee,
      'finalFee': finalFee,
      'deliveryTime': zone['deliveryTime'],
      'description': zone['description'],
      'isRural': distance > 10.0,
      'batchDiscount': deliveryType == 'batch' ? 0.2 : 0.0,
    };
  }

  /// Get available delivery options for rural area
  static List<Map<String, dynamic>> getRuralDeliveryOptions({
    required double distance,
    required bool isRuralArea,
  }) {
    List<Map<String, dynamic>> options = [];

    // Always include pickup
    options.add({
      ..._deliveryOptions['pickup']!,
      'key': 'pickup',
      'available': true,
    });

    // Add delivery options based on distance
    if (distance <= 15.0) {
      options.add({
        ..._deliveryOptions['local']!,
        'key': 'local',
        'available': true,
      });
    }

    if (distance <= 20.0) {
      options.add({
        ..._deliveryOptions['batch']!,
        'key': 'batch',
        'available': true,
      });
    }

    if (distance <= 25.0) {
      options.add({
        ..._deliveryOptions['scheduled']!,
        'key': 'scheduled',
        'available': true,
      });
    }

    // Rural area specific options
    if (isRuralArea) {
      options.add({
        'name': 'Community Delivery',
        'fee': 30.0,
        'time': '60-90 minutes',
        'description': 'Local driver delivery',
        'icon': '🤝',
        'recommended': false,
        'key': 'community',
        'available': true,
      });
    }

    return options;
  }

  /// Check if location is in rural area
  static bool isRuralArea(double distance) {
    return distance > 10.0;
  }

  /// Get available community drivers for area
  static Future<List<Map<String, dynamic>>> getCommunityDrivers({
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    try {
      // Query community drivers within radius
      final driversQuery = await _firestore
          .collection('drivers')
          .where('isActive', isEqualTo: true)
          .where('driverType', whereIn: ['community', 'student', 'parttime'])
          .get();

      List<Map<String, dynamic>> nearbyDrivers = [];

      for (var doc in driversQuery.docs) {
        final driver = doc.data();
        final driverLat = driver['latitude'] ?? 0.0;
        final driverLng = driver['longitude'] ?? 0.0;

        final distance = Geolocator.distanceBetween(
          latitude, longitude, driverLat, driverLng,
        ) / 1000; // Convert to km

        if (distance <= radius) {
          nearbyDrivers.add({
            'id': doc.id,
            'name': driver['name'] ?? 'Driver',
            'phone': driver['phone'] ?? '',
            'rating': driver['rating'] ?? 0.0,
            'distance': distance,
            'isAvailable': driver['isAvailable'] ?? false,
            'vehicleType': driver['vehicleType'] ?? 'Car',
            'maxDistance': driver['maxDistance'] ?? 20.0,
            'driverType': driver['driverType'] ?? 'community',
            'hourlyRate': driver['hourlyRate'] ?? 25.0,
            'specialties': driver['specialties'] ?? [],
            'availability': driver['availability'] ?? {},
          });
        }
      }

      // Sort by distance and availability
      nearbyDrivers.sort((a, b) {
        if (a['isAvailable'] != b['isAvailable']) {
          return a['isAvailable'] ? -1 : 1;
        }
        return a['distance'].compareTo(b['distance']);
      });

      return nearbyDrivers;
    } catch (e) {
      print('Error getting community drivers: $e');
      return [];
    }
  }

  /// Get rural delivery drivers for area
  static Future<List<Map<String, dynamic>>> getRuralDrivers({
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    try {
      // Query drivers within radius
      final driversQuery = await _firestore
          .collection('drivers')
          .where('isActive', isEqualTo: true)
          .where('isRuralDriver', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> nearbyDrivers = [];

      for (var doc in driversQuery.docs) {
        final driver = doc.data();
        final driverLat = driver['latitude'] ?? 0.0;
        final driverLng = driver['longitude'] ?? 0.0;

        final distance = Geolocator.distanceBetween(
          latitude, longitude, driverLat, driverLng,
        ) / 1000; // Convert to km

        if (distance <= radius) {
          nearbyDrivers.add({
            'id': doc.id,
            'name': driver['name'] ?? 'Driver',
            'phone': driver['phone'] ?? '',
            'rating': driver['rating'] ?? 0.0,
            'distance': distance,
            'isAvailable': driver['isAvailable'] ?? false,
            'vehicleType': driver['vehicleType'] ?? 'Car',
            'maxDistance': driver['maxDistance'] ?? 20.0,
          });
        }
      }

      // Sort by distance and availability
      nearbyDrivers.sort((a, b) {
        if (a['isAvailable'] != b['isAvailable']) {
          return a['isAvailable'] ? -1 : 1;
        }
        return a['distance'].compareTo(b['distance']);
      });

      return nearbyDrivers;
    } catch (e) {
      print('Error getting rural drivers: $e');
      return [];
    }
  }

  /// Calculate batch delivery savings
  static Map<String, dynamic> calculateBatchDeliverySavings({
    required int orderCount,
    required double baseDeliveryFee,
  }) {
    double totalWithoutBatch = baseDeliveryFee * orderCount;
    double batchFee = baseDeliveryFee * 0.8; // 20% discount
    double totalWithBatch = batchFee * orderCount;
    double savings = totalWithoutBatch - totalWithBatch;

    return {
      'orderCount': orderCount,
      'baseFee': baseDeliveryFee,
      'batchFee': batchFee,
      'totalWithoutBatch': totalWithoutBatch,
      'totalWithBatch': totalWithBatch,
      'savings': savings,
      'savingsPercentage': (savings / totalWithoutBatch) * 100,
    };
  }

  /// Get rural delivery time slots
  static List<Map<String, dynamic>> getRuralDeliveryTimeSlots({
    required bool isRuralArea,
  }) {
    List<Map<String, dynamic>> slots = [];

    if (isRuralArea) {
      // Rural delivery slots (fewer, longer intervals)
      slots = [
        {'time': '09:00', 'label': 'Morning (9:00 AM)', 'available': true},
        {'time': '12:00', 'label': 'Lunch (12:00 PM)', 'available': true},
        {'time': '15:00', 'label': 'Afternoon (3:00 PM)', 'available': true},
        {'time': '18:00', 'label': 'Evening (6:00 PM)', 'available': true},
      ];
    } else {
      // Urban delivery slots (more frequent)
      slots = [
        {'time': '09:00', 'label': 'Morning (9:00 AM)', 'available': true},
        {'time': '10:30', 'label': 'Late Morning (10:30 AM)', 'available': true},
        {'time': '12:00', 'label': 'Lunch (12:00 PM)', 'available': true},
        {'time': '13:30', 'label': 'Early Afternoon (1:30 PM)', 'available': true},
        {'time': '15:00', 'label': 'Afternoon (3:00 PM)', 'available': true},
        {'time': '16:30', 'label': 'Late Afternoon (4:30 PM)', 'available': true},
        {'time': '18:00', 'label': 'Evening (6:00 PM)', 'available': true},
        {'time': '19:30', 'label': 'Late Evening (7:30 PM)', 'available': true},
      ];
    }

    return slots;
  }

  /// Validate rural delivery address
  static Map<String, dynamic> validateRuralAddress(String address) {
    bool isValid = true;
    List<String> issues = [];

    // Check for rural indicators
    bool isRural = address.toLowerCase().contains('farm') ||
        address.toLowerCase().contains('plot') ||
        address.toLowerCase().contains('rural') ||
        address.toLowerCase().contains('outskirts') ||
        address.toLowerCase().contains('village');

    // Check for landmarks (important for rural delivery)
    bool hasLandmarks = address.toLowerCase().contains('near') ||
        address.toLowerCase().contains('opposite') ||
        address.toLowerCase().contains('next to') ||
        address.toLowerCase().contains('behind');

    if (isRural && !hasLandmarks) {
      issues.add('Rural addresses should include landmarks for easier delivery');
    }

    if (address.length < 10) {
      issues.add('Address seems too short for rural delivery');
      isValid = false;
    }

    return {
      'isValid': isValid,
      'isRural': isRural,
      'hasLandmarks': hasLandmarks,
      'issues': issues,
      'recommendations': [
        'Include nearby landmarks',
        'Add contact phone number',
        'Specify delivery instructions',
        'Include gate/door color if applicable',
      ],
    };
  }

  /// Calculate community driver pricing
  static Map<String, dynamic> calculateCommunityDriverPricing({
    required String driverType,
    required double distance,
    required double baseFee,
  }) {
    double communityDiscount = 0.0;
    String discountReason = '';

    switch (driverType) {
      case 'community':
        communityDiscount = 0.15; // 15% discount for community drivers
        discountReason = 'Community driver discount';
        break;
      case 'student':
        communityDiscount = 0.20; // 20% discount for student drivers
        discountReason = 'Student driver discount';
        break;
      case 'parttime':
        communityDiscount = 0.10; // 10% discount for part-time drivers
        discountReason = 'Part-time driver discount';
        break;
      default:
        communityDiscount = 0.0;
        discountReason = 'Standard pricing';
    }

    double finalFee = baseFee * (1 - communityDiscount);

    return {
      'driverType': driverType,
      'baseFee': baseFee,
      'communityDiscount': communityDiscount,
      'discountReason': discountReason,
      'finalFee': finalFee,
      'savings': baseFee - finalFee,
    };
  }

  /// Get community driver benefits
  static List<Map<String, dynamic>> getCommunityDriverBenefits() {
    return [
      {
        'title': 'Local Knowledge',
        'description': 'Community drivers know the area better',
        'icon': '🗺️',
        'benefit': 'Faster, more efficient routes'
      },
      {
        'title': 'Lower Costs',
        'description': 'Community drivers have lower overhead',
        'icon': '💰',
        'benefit': '15-20% cheaper than corporate delivery'
      },
      {
        'title': 'Flexible Hours',
        'description': 'Students and part-timers available',
        'icon': '⏰',
        'benefit': 'Extended delivery hours'
      },
      {
        'title': 'Personal Touch',
        'description': 'Local drivers provide better service',
        'icon': '🤝',
        'benefit': 'Community connection and trust'
      }
    ];
  }

  /// Check driver availability for time slot
  static Future<bool> checkDriverAvailability({
    required String driverId,
    required DateTime deliveryTime,
  }) async {
    try {
      final driverDoc = await _firestore
          .collection('drivers')
          .doc(driverId)
          .get();

      if (!driverDoc.exists) return false;

      final driverData = driverDoc.data();
      final availability = driverData?['availability'] ?? {};

      // Check if driver is available for the specific time
      final dayOfWeek = deliveryTime.weekday;
      final hour = deliveryTime.hour;

      final dayAvailability = availability[dayOfWeek.toString()] ?? [];
      return dayAvailability.contains(hour);
    } catch (e) {
      print('Error checking driver availability: $e');
      return false;
    }
  }

  /// Get driver partnership opportunities
  static List<Map<String, dynamic>> getPartnershipOpportunities() {
    return [
      {
        'type': 'Student Partnerships',
        'description': 'Partner with local universities and colleges',
        'benefits': [
          'Flexible student schedules',
          'Lower cost structure',
          'Tech-savvy drivers',
          'Campus area coverage'
        ],
        'requirements': [
          'Valid student ID',
          'Clean driving record',
          'Part-time availability',
          'Local area knowledge'
        ]
      },
      {
        'type': 'Local Business Partnerships',
        'description': 'Partner with existing delivery services',
        'benefits': [
          'Established infrastructure',
          'Professional drivers',
          'Insurance coverage',
          'Reliable service'
        ],
        'requirements': [
          'Business license',
          'Insurance coverage',
          'Driver background checks',
          'Vehicle maintenance records'
        ]
      },
      {
        'type': 'Community Driver Program',
        'description': 'Recruit local community members',
        'benefits': [
          'Local area expertise',
          'Community trust',
          'Flexible scheduling',
          'Cost-effective rates'
        ],
        'requirements': [
          'Local residency',
          'Clean background check',
          'Vehicle inspection',
          'Training completion'
        ]
      }
    ];
  }
} 