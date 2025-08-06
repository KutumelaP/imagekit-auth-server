import 'package:flutter/material.dart';
import '../services/urban_delivery_service.dart';
import '../theme/app_theme.dart';

class UrbanDeliveryWidget extends StatefulWidget {
  final double distance;
  final double currentDeliveryFee;
  final Function(String, double) onDeliveryOptionSelected;
  final bool isUrbanArea;
  final String category;
  final DateTime? deliveryTime;

  const UrbanDeliveryWidget({
    Key? key,
    required this.distance,
    required this.currentDeliveryFee,
    required this.onDeliveryOptionSelected,
    required this.isUrbanArea,
    required this.category,
    this.deliveryTime,
  }) : super(key: key);

  @override
  State<UrbanDeliveryWidget> createState() => _UrbanDeliveryWidgetState();
}

class _UrbanDeliveryWidgetState extends State<UrbanDeliveryWidget> {
  String? _selectedDeliveryType;
  List<Map<String, dynamic>> _deliveryOptions = [];
  Map<String, dynamic>? _urbanZone;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUrbanDeliveryOptions();
  }

  void _loadUrbanDeliveryOptions() async {
    // Simulate getting user location (in real app, get from location service)
    final userLat = -26.1076; // Sandton coordinates for demo
    final userLng = 28.0567;
    
    final urbanZone = UrbanDeliveryService.getUrbanZone(userLat, userLng);
    final deliveryOptions = UrbanDeliveryService.getUrbanDeliveryOptions(
      latitude: userLat,
      longitude: userLng,
      category: widget.category,
      deliveryTime: widget.deliveryTime ?? DateTime.now(),
    );

    setState(() {
      _urbanZone = urbanZone;
      _deliveryOptions = deliveryOptions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isUrbanArea) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: ResponsiveUtils.getVerticalPadding(context) * 0.2,
      ),
      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.3),
      decoration: BoxDecoration(
        color: AppTheme.deepTeal.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.deepTeal.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          if (_isLoading)
            _buildLoadingIndicator()
          else
            _buildDeliveryOptions(),
          const SizedBox(height: 12),
          _buildUrbanBenefits(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.location_city,
          color: AppTheme.deepTeal,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Urban Delivery Available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepTeal,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.deepTeal,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _urbanZone?['zoneData']?['name'] ?? 'Urban Zone',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildDeliveryOptions() {
    if (_deliveryOptions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Urban delivery not available for this category in your area',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _deliveryOptions.map((option) => _buildDeliveryOption(option)).toList(),
    );
  }

  Widget _buildDeliveryOption(Map<String, dynamic> option) {
    final isSelected = _selectedDeliveryType == option['type'];
    final isRecommended = option['recommended'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.deepTeal.withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? AppTheme.deepTeal
                : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedDeliveryType = option['type'];
            });
            widget.onDeliveryOptionSelected(
              option['type'],
              option['fee'].toDouble(),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.deepTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      option['icon'],
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              option['name'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected 
                                    ? AppTheme.deepTeal
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (isRecommended)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'RECOMMENDED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option['time'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: (option['features'] as List).map((feature) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.deepTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              feature,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.deepTeal,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'R${option['fee'].toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected 
                            ? AppTheme.deepTeal
                            : Colors.black87,
                      ),
                    ),
                    if (option['fee'] < widget.currentDeliveryFee)
                      Text(
                        'Save R${(widget.currentDeliveryFee - option['fee']).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUrbanBenefits() {
    final benefits = UrbanDeliveryService.getUrbanDeliveryBenefits();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.blue, size: 16),
              const SizedBox(width: 6),
              Text(
                'Urban Delivery Benefits',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...benefits.map((benefit) => _buildBenefitItem(benefit)),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(Map<String, dynamic> benefit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            benefit['icon'],
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benefit['title'],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  benefit['description'],
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 