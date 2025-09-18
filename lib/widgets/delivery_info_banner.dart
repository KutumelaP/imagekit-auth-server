import 'package:flutter/material.dart';

class DeliveryInfoBanner extends StatelessWidget {
  final Map<String, dynamic> store;

  const DeliveryInfoBanner({
    Key? key,
    required this.store,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool showDistanceWarning = store['showDistanceWarning'] == true;
    final bool hasNationalDelivery = store['hasNationalDelivery'] == true;
    final bool locationUnavailable = store['locationUnavailable'] == true;
    final double? distance = store['distance']?.toDouble();
    final double? serviceRadius = store['serviceRadius']?.toDouble();
    final bool deliveryAvailable = store['deliveryAvailable'] == true;

    // Don't show banner if store has national delivery options
    if (hasNationalDelivery) {
      return _buildNationalDeliveryInfo();
    }

    // Don't show banner if within delivery range
    if (!showDistanceWarning && distance != null) {
      return _buildInRangeInfo(distance, serviceRadius);
    }

    // Show appropriate warning or info
    if (locationUnavailable) {
      return _buildLocationUnavailableInfo();
    }

    if (showDistanceWarning && distance != null && serviceRadius != null) {
      return _buildDistanceWarning(distance, serviceRadius, deliveryAvailable);
    }

    return const SizedBox.shrink();
  }

  Widget _buildNationalDeliveryInfo() {
    final List<String> methods = [];
    if (store['pudoEnabled'] == true) methods.add('PUDO Lockers');
    if (store['pargoEnabled'] == true) methods.add('Pargo Points');
    if (store['paxiEnabled'] == true) methods.add('PAXI Points');

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.public,
            color: Colors.green.shade600,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🚚 Nationwide Delivery Available',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This store delivers anywhere in South Africa via ${methods.join(", ")}',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInRangeInfo(double distance, double? serviceRadius) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.blue.shade600,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '✅ You\'re ${distance.toStringAsFixed(1)}km away - delivery available!',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationUnavailableInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_off,
            color: Colors.orange.shade600,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📍 Location Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enable location services to check delivery availability to your area',
                  style: TextStyle(
                    color: Colors.orange.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceWarning(double distance, double serviceRadius, bool deliveryAvailable) {
    String deliveryText = '';
    if (deliveryAvailable) {
      deliveryText = 'This store delivers within ${serviceRadius.toStringAsFixed(0)}km radius';
    } else {
      deliveryText = 'This store offers pickup only';
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info,
            color: Colors.amber.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📍 You\'re ${distance.toStringAsFixed(1)}km away',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deliveryText,
                  style: TextStyle(
                    color: Colors.amber.shade700,
                    fontSize: 14,
                  ),
                ),
                if (!deliveryAvailable) ...[
                  const SizedBox(height: 8),
                  Text(
                    '💡 You can still browse and contact the seller for special arrangements',
                    style: TextStyle(
                      color: Colors.amber.shade600,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
