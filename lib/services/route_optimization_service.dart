import 'package:geolocator/geolocator.dart';

class RouteOptimizationService {
  /// Optimize delivery route for multiple orders
  static List<Map<String, dynamic>> optimizeDeliveryRoute({
    required List<Map<String, dynamic>> orders,
    required double startLatitude,
    required double startLongitude,
  }) {
    if (orders.isEmpty) return [];
    if (orders.length == 1) return orders;

    // Simple nearest neighbor algorithm for route optimization
    List<Map<String, dynamic>> optimizedRoute = [];
    List<Map<String, dynamic>> remainingOrders = List.from(orders);
    
    double currentLat = startLatitude;
    double currentLng = startLongitude;

    while (remainingOrders.isNotEmpty) {
      Map<String, dynamic>? nearestOrder;
      double shortestDistance = double.infinity;
      int nearestIndex = -1;

      // Find the nearest unvisited order
      for (int i = 0; i < remainingOrders.length; i++) {
        final order = remainingOrders[i];
        final orderCoords = order['deliveryCoordinates'] as Map<String, dynamic>?;
        
        if (orderCoords != null) {
          final orderLat = orderCoords['latitude'] as double?;
          final orderLng = orderCoords['longitude'] as double?;
          
          if (orderLat != null && orderLng != null) {
            final distance = Geolocator.distanceBetween(
              currentLat, 
              currentLng, 
              orderLat, 
              orderLng,
            );
            
            if (distance < shortestDistance) {
              shortestDistance = distance;
              nearestOrder = order;
              nearestIndex = i;
            }
          }
        }
      }

      if (nearestOrder != null) {
        optimizedRoute.add(nearestOrder);
        remainingOrders.removeAt(nearestIndex);
        
        final coords = nearestOrder['deliveryCoordinates'] as Map<String, dynamic>;
        currentLat = coords['latitude'] as double;
        currentLng = coords['longitude'] as double;
      } else {
        // If no coordinates found, just add remaining orders as-is
        optimizedRoute.addAll(remainingOrders);
        break;
      }
    }

    return optimizedRoute;
  }

  /// Calculate total route distance
  static double calculateTotalRouteDistance({
    required List<Map<String, dynamic>> orders,
    required double startLatitude,
    required double startLongitude,
  }) {
    if (orders.isEmpty) return 0.0;

    double totalDistance = 0.0;
    double currentLat = startLatitude;
    double currentLng = startLongitude;

    for (final order in orders) {
      final coords = order['deliveryCoordinates'] as Map<String, dynamic>?;
      if (coords != null) {
        final orderLat = coords['latitude'] as double?;
        final orderLng = coords['longitude'] as double?;
        
        if (orderLat != null && orderLng != null) {
          totalDistance += Geolocator.distanceBetween(
            currentLat, 
            currentLng, 
            orderLat, 
            orderLng,
          );
          
          currentLat = orderLat;
          currentLng = orderLng;
        }
      }
    }

    return totalDistance;
  }

  /// Calculate estimated total delivery time
  static Duration calculateTotalDeliveryTime({
    required List<Map<String, dynamic>> orders,
    required double startLatitude,
    required double startLongitude,
    double averageSpeedKmh = 30.0,
    int stopTimeMinutes = 5, // Time per delivery stop
  }) {
    final totalDistance = calculateTotalRouteDistance(
      orders: orders,
      startLatitude: startLatitude,
      startLongitude: startLongitude,
    );

    final travelTimeHours = (totalDistance / 1000) / averageSpeedKmh;
    final totalStopTimeHours = (orders.length * stopTimeMinutes) / 60.0;
    
    final totalTimeHours = travelTimeHours + totalStopTimeHours;
    
    return Duration(minutes: (totalTimeHours * 60).round());
  }

  /// Get delivery route summary
  static Map<String, dynamic> getRouteSummary({
    required List<Map<String, dynamic>> orders,
    required double startLatitude,
    required double startLongitude,
  }) {
    final optimizedOrders = optimizeDeliveryRoute(
      orders: orders,
      startLatitude: startLatitude,
      startLongitude: startLongitude,
    );

    final totalDistance = calculateTotalRouteDistance(
      orders: optimizedOrders,
      startLatitude: startLatitude,
      startLongitude: startLongitude,
    );

    final estimatedTime = calculateTotalDeliveryTime(
      orders: optimizedOrders,
      startLatitude: startLatitude,
      startLongitude: startLongitude,
    );

    return {
      'optimizedOrders': optimizedOrders,
      'totalDistanceMeters': totalDistance,
      'totalDistanceKm': totalDistance / 1000,
      'estimatedTimeMinutes': estimatedTime.inMinutes,
      'estimatedTime': estimatedTime,
      'numberOfStops': orders.length,
      'averageDistancePerStop': orders.isNotEmpty ? totalDistance / orders.length : 0.0,
    };
  }

  /// Check if route optimization would be beneficial
  static bool shouldOptimizeRoute(List<Map<String, dynamic>> orders) {
    // Optimize if more than 2 orders
    return orders.length > 2;
  }

  /// Get next delivery recommendation
  static Map<String, dynamic>? getNextDeliveryRecommendation({
    required List<Map<String, dynamic>> pendingOrders,
    required double currentLatitude,
    required double currentLongitude,
  }) {
    if (pendingOrders.isEmpty) return null;

    Map<String, dynamic>? nearestOrder;
    double shortestDistance = double.infinity;

    for (final order in pendingOrders) {
      final coords = order['deliveryCoordinates'] as Map<String, dynamic>?;
      if (coords != null) {
        final orderLat = coords['latitude'] as double?;
        final orderLng = coords['longitude'] as double?;
        
        if (orderLat != null && orderLng != null) {
          final distance = Geolocator.distanceBetween(
            currentLatitude, 
            currentLongitude, 
            orderLat, 
            orderLng,
          );
          
          if (distance < shortestDistance) {
            shortestDistance = distance;
            nearestOrder = order;
          }
        }
      }
    }

    if (nearestOrder != null) {
      return {
        'order': nearestOrder,
        'distance': shortestDistance,
        'distanceKm': shortestDistance / 1000,
        'estimatedTimeMinutes': ((shortestDistance / 1000) / 30 * 60).round(), // 30 km/h average
      };
    }

    return null;
  }
}
