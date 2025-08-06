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

  /// Check if location is in rural area
  static bool isRuralArea(double distance) {
    return distance > 10.0;
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