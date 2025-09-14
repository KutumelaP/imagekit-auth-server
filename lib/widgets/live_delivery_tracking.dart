import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/driver_location_service.dart';
import '../theme/app_theme.dart';

class LiveDeliveryTracking extends StatefulWidget {
  final String orderId;
  final String deliveryAddress;
  final Map<String, dynamic>? deliveryCoordinates;

  const LiveDeliveryTracking({
    Key? key,
    required this.orderId,
    required this.deliveryAddress,
    this.deliveryCoordinates,
  }) : super(key: key);

  @override
  State<LiveDeliveryTracking> createState() => _LiveDeliveryTrackingState();
}

class _LiveDeliveryTrackingState extends State<LiveDeliveryTracking> {
  final DriverLocationService _locationService = DriverLocationService();
  double? _distanceToDelivery;
  Duration? _estimatedArrival;
  String _driverStatus = 'On the way';

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.deepTeal,
              AppTheme.deepTeal.withOpacity(0.8),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_shipping,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Live Delivery Tracking',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Order #${widget.orderId.substring(0, 8)}...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _driverStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Live Location Stream
              StreamBuilder<DocumentSnapshot>(
                stream: _locationService.getOrderLocationStream(widget.orderId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    );
                  }

                  final orderData = snapshot.data!.data() as Map<String, dynamic>?;
                  final driverLocation = orderData?['driverLocation'] as Map<String, dynamic>?;

                  if (driverLocation == null) {
                    return _buildNoLocationWidget();
                  }

                  // Calculate distance and ETA if delivery coordinates available
                  if (widget.deliveryCoordinates != null) {
                    _calculateDistanceAndETA(driverLocation);
                  }

                  return _buildTrackingInfo(driverLocation);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoLocationWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.location_searching,
            color: Colors.white.withOpacity(0.7),
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Waiting for driver location...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Driver will start tracking when they begin delivery',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingInfo(Map<String, dynamic> driverLocation) {
    final latitude = driverLocation['latitude'] as double?;
    final longitude = driverLocation['longitude'] as double?;
    final speed = driverLocation['speed'] as double?;
    final lastUpdate = driverLocation['updatedAt'] as String?;

    return Column(
      children: [
        // Location Info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.my_location,
                    color: Colors.white.withOpacity(0.8),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Driver Location',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lat: ${latitude?.toStringAsFixed(6) ?? 'Unknown'}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Lng: ${longitude?.toStringAsFixed(6) ?? 'Unknown'}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (speed != null && speed > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.speed,
                      color: Colors.white.withOpacity(0.8),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Speed: ${(speed * 3.6).toStringAsFixed(1)} km/h',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Distance and ETA
        if (_distanceToDelivery != null) ...[
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.straighten,
                        color: Colors.white.withOpacity(0.8),
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(_distanceToDelivery! / 1000).toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Distance',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: Colors.white.withOpacity(0.8),
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_estimatedArrival?.inMinutes ?? 0} min',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ETA',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        // Delivery Address
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                color: Colors.white.withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Address',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.deliveryAddress,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        if (lastUpdate != null) ...[
          const SizedBox(height: 12),
          Text(
            'Last updated: ${_formatLastUpdate(lastUpdate)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  void _calculateDistanceAndETA(Map<String, dynamic> driverLocation) {
    final driverLat = driverLocation['latitude'] as double?;
    final driverLng = driverLocation['longitude'] as double?;
    final deliveryLat = widget.deliveryCoordinates?['latitude'] as double?;
    final deliveryLng = widget.deliveryCoordinates?['longitude'] as double?;

    if (driverLat != null && driverLng != null && 
        deliveryLat != null && deliveryLng != null) {
      final distance = DriverLocationService.calculateDistance(
        driverLat, driverLng, deliveryLat, deliveryLng,
      );
      final eta = DriverLocationService.calculateETA(distance);
      
      setState(() {
        _distanceToDelivery = distance;
        _estimatedArrival = eta;
      });
    }
  }

  String _formatLastUpdate(String updatedAt) {
    try {
      final updateTime = DateTime.parse(updatedAt);
      final now = DateTime.now();
      final difference = now.difference(updateTime);
      
      if (difference.inSeconds < 60) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else {
        return '${difference.inHours}h ago';
      }
    } catch (e) {
      return 'recently';
    }
  }
}
