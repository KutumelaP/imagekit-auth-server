import 'package:flutter/material.dart';
import '../config/paxi_config.dart';
import '../theme/app_theme.dart';

class PaxiDeliverySpeedSelector extends StatefulWidget {
  final String? selectedSpeed;
  final Function(String speed, double price) onSpeedSelected;
  final Map<String, double>? customPricing;

  const PaxiDeliverySpeedSelector({
    Key? key,
    this.selectedSpeed,
    required this.onSpeedSelected,
    this.customPricing,
  }) : super(key: key);

  @override
  State<PaxiDeliverySpeedSelector> createState() => _PaxiDeliverySpeedSelectorState();
}

class _PaxiDeliverySpeedSelectorState extends State<PaxiDeliverySpeedSelector> {
  String? _selectedSpeed;
  Map<String, double> _pricing = {};

  @override
  void initState() {
    super.initState();
    _selectedSpeed = widget.selectedSpeed ?? 'standard';
    _loadPricing();
  }

  void _loadPricing() {
    if (widget.customPricing != null) {
      _pricing = widget.customPricing!;
    } else {
      _pricing = {
        'standard': PaxiConfig.getPrice('standard'),
        'express': PaxiConfig.getPrice('express'),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.breeze.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.local_shipping,
                color: AppTheme.deepTeal,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'PAXI Delivery Speed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepTeal,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          Text(
            'Choose your preferred delivery speed. Same bag size, different delivery times.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.mediumGrey,
            ),
          ),
          
          SizedBox(height: 16),
          
          // Speed Options
          Column(
            children: [
              // Standard Speed Option
              _buildSpeedOption(
                speed: 'standard',
                title: 'Standard Delivery',
                subtitle: '7-9 Business Days',
                price: _pricing['standard'] ?? 59.95,
                icon: Icons.schedule,
                color: AppTheme.deepTeal,
              ),
              
              SizedBox(height: 12),
              
              // Express Speed Option
              _buildSpeedOption(
                speed: 'express',
                title: 'Express Delivery',
                subtitle: '3-5 Business Days',
                price: _pricing['express'] ?? 109.95,
                icon: Icons.flash_on,
                color: AppTheme.primaryGreen,
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Info Card
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.primaryGreen.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppTheme.primaryGreen,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PAXI uses the same bag size (10kg) for all delivery speeds. '
                    'The price difference reflects the delivery time priority.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedOption({
    required String speed,
    required String title,
    required String subtitle,
    required double price,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedSpeed == speed;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSpeed = speed;
        });
        widget.onSpeedSelected(speed, price);
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppTheme.breeze.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio Button
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : AppTheme.breeze,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Container(
                      margin: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    )
                  : null,
            ),
            
            SizedBox(width: 16),
            
            // Icon
            Icon(
              icon,
              color: isSelected ? color : AppTheme.breeze,
              size: 24,
            ),
            
            SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : AppTheme.deepTeal,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ],
              ),
            ),
            
            // Price
            Text(
              'R${price.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : AppTheme.deepTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
