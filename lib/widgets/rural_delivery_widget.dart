import 'package:flutter/material.dart';
import '../services/rural_delivery_service.dart';
import '../theme/app_theme.dart';

class RuralDeliveryWidget extends StatefulWidget {
  final double distance;
  final double currentDeliveryFee;
  final Function(String, double) onDeliveryOptionSelected;
  final bool isRuralArea;

  const RuralDeliveryWidget({
    Key? key,
    required this.distance,
    required this.currentDeliveryFee,
    required this.onDeliveryOptionSelected,
    required this.isRuralArea,
  }) : super(key: key);

  @override
  State<RuralDeliveryWidget> createState() => _RuralDeliveryWidgetState();
}

class _RuralDeliveryWidgetState extends State<RuralDeliveryWidget> {
  String? _selectedOption;
  List<Map<String, dynamic>> _deliveryOptions = [];
  bool _hasCommunityDrivers = false;

  @override
  void initState() {
    super.initState();
    _loadDeliveryOptions();
    _checkDrivers();
  }

  Future<void> _checkDrivers() async {
    try {
      // Use a modest radius based on distance (cap to 20km)
      final double radius = widget.distance.clamp(5.0, 20.0);
      final List<Map<String, dynamic>> community = await RuralDeliveryService.getCommunityDrivers(
        latitude: 0.0, // TODO: pass real coords from parent if available
        longitude: 0.0,
        radius: radius,
      );
      final List<Map<String, dynamic>> rural = await RuralDeliveryService.getRuralDrivers(
        latitude: 0.0,
        longitude: 0.0,
        radius: radius,
      );
      if (mounted) setState(() {
        _hasCommunityDrivers = (community.isNotEmpty || rural.isNotEmpty);
        if (!_hasCommunityDrivers) {
          // Remove community option if present
          _deliveryOptions.removeWhere((o) => o['key'] == 'community');
        } else if (_deliveryOptions.indexWhere((o) => o['key'] == 'community') == -1 && widget.isRuralArea) {
          // Ensure community option exists if rural and drivers exist
          _deliveryOptions.add({
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
      });
    } catch (_) {}
  }

  void _loadDeliveryOptions() {
    _deliveryOptions = RuralDeliveryService.getRuralDeliveryOptions(
      distance: widget.distance,
      isRuralArea: widget.isRuralArea,
    );

    // Gate community option until drivers exist
    if (!_hasCommunityDrivers) {
      _deliveryOptions.removeWhere((o) => o['key'] == 'community');
    }

    // Set pickup as default
    _selectedOption = 'pickup';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.deepTeal.withOpacity(0.1),
            AppTheme.cloud.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.deepTeal.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  widget.isRuralArea ? Icons.location_on : Icons.delivery_dining,
                  color: AppTheme.deepTeal,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isRuralArea ? 'Rural Delivery Options' : 'Delivery Options',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepTeal,
                        ),
                      ),
                      Text(
                        '${widget.distance.toStringAsFixed(1)}km from store',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.cloud,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isRuralArea)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.deepTeal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'RURAL',
                      style: TextStyle(
                        color: AppTheme.angel,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Delivery Options
          ..._deliveryOptions.map((option) => _buildDeliveryOption(option)),

          // Rural Area Benefits
          if (widget.isRuralArea && _hasCommunityDrivers) _buildRuralBenefits(),

          // Distance-based Pricing
          _buildDistancePricing(),
        ],
      ),
    );
  }

  Widget _buildDeliveryOption(Map<String, dynamic> option) {
    final isSelected = _selectedOption == option['key'];
    final isRecommended = option['recommended'] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.deepTeal.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? AppTheme.deepTeal : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedOption = option['key'];
          });
          widget.onDeliveryOptionSelected(
            option['key'],
            option['fee'].toDouble(),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.deepTeal : AppTheme.cloud,
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

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            option['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppTheme.deepTeal : AppTheme.darkGrey,
                            ),
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            fit: FlexFit.loose,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'RECOMMENDED',
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.cloud,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${option['time']} • R${option['fee'].toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.deepTeal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Radio Button
              Radio<String>(
                value: option['key'],
                groupValue: _selectedOption,
                onChanged: (value) {
                  setState(() {
                    _selectedOption = value;
                  });
                  widget.onDeliveryOptionSelected(
                    option['key'],
                    option['fee'].toDouble(),
                  );
                },
                activeColor: AppTheme.deepTeal,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuralBenefits() {
    final communityBenefits = RuralDeliveryService.getCommunityDriverBenefits();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                'Community Driver Benefits',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildBenefitItem('🌾 10% discount on delivery fees'),
          _buildBenefitItem('🤝 Community driver network'),
          _buildBenefitItem('📦 Batch delivery options'),
          _buildBenefitItem('📅 Flexible scheduling'),
          const SizedBox(height: 8),
          ...communityBenefits.map((benefit) => _buildCommunityBenefitItem(benefit)),
        ],
      ),
    );
  }

  Widget _buildCommunityBenefitItem(Map<String, dynamic> benefit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
                Text(
                  benefit['description'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade600,
                  ),
                ),
                Text(
                  benefit['benefit'],
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: Colors.green.shade700,
        ),
      ),
    );
  }

  Widget _buildDistancePricing() {
    final ruralPricing = RuralDeliveryService.calculateRuralDeliveryFee(
      distance: widget.distance,
      storeId: 'store_id', // This would come from actual store
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.angel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.cloud.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distance-Based Pricing',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepTeal,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Distance:', style: TextStyle(color: AppTheme.cloud)),
              Text(
                '${widget.distance.toStringAsFixed(1)} km',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepTeal,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Zone:', style: TextStyle(color: AppTheme.cloud)),
              Text(
                ruralPricing['zoneName'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepTeal,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Delivery Time:', style: TextStyle(color: AppTheme.cloud)),
              Text(
                ruralPricing['deliveryTime'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepTeal,
                ),
              ),
            ],
          ),
          if (widget.isRuralArea) ...[
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Rural Discount:', style: TextStyle(color: Colors.green)),
                Text(
                  '10% OFF',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
} 