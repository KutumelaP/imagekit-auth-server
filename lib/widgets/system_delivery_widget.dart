import 'package:flutter/material.dart';
import '../services/system_delivery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/safe_ui.dart';

/// System Delivery Widget
/// Displays system delivery options with R5-R10/km pricing tiers
class SystemDeliveryWidget extends StatefulWidget {
  final double deliveryDistance;
  final double? currentDeliveryFee;
  final Function(String modelType, double fee) onDeliveryOptionSelected;
  final bool isSelected;

  const SystemDeliveryWidget({
    Key? key,
    required this.deliveryDistance,
    this.currentDeliveryFee,
    required this.onDeliveryOptionSelected,
    this.isSelected = false,
  }) : super(key: key);

  @override
  State<SystemDeliveryWidget> createState() => _SystemDeliveryWidgetState();
}

class _SystemDeliveryWidgetState extends State<SystemDeliveryWidget> {
  String? _selectedModelType;
  List<Map<String, dynamic>> _deliveryOptions = [];

  @override
  void initState() {
    super.initState();
    _loadDeliveryOptions();
  }

  void _loadDeliveryOptions() {
    _deliveryOptions = SystemDeliveryService.getSystemDeliveryOptions(
      widget.deliveryDistance,
    );
    
    // Auto-select recommended model if none selected
    if (_selectedModelType == null && _deliveryOptions.isNotEmpty) {
      final recommended = _deliveryOptions.firstWhere(
        (option) => option['isRecommended'] == true,
        orElse: () => _deliveryOptions.first,
      );
      _selectedModelType = recommended['modelType'];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SystemDeliveryService.isSystemDeliveryAvailable(widget.deliveryDistance)) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.warning, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'System delivery not available for distances over 100km',
                style: TextStyle(
                  color: AppTheme.warning,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.deepTeal.withOpacity(0.1),
            AppTheme.deepTeal.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isSelected 
              ? AppTheme.deepTeal.withOpacity(0.6)
              : AppTheme.deepTeal.withOpacity(0.3),
          width: widget.isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.deepTeal.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.deepTeal.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_shipping,
                    color: AppTheme.deepTeal,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                                              Text(
                          '🚚 System Delivery Options',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.deepTeal,
                          ),
                        ),
                        Text(
                          'Standardized pricing from R5-R10/km',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppTheme.breeze,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.isSelected)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.deepTeal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'SELECTED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Delivery Options
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                for (final option in _deliveryOptions)
                  _buildDeliveryOptionCard(option),
                
                SizedBox(height: 16),
                
                // Benefits Section
                _buildBenefitsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryOptionCard(Map<String, dynamic> option) {
    final isSelected = _selectedModelType == option['modelType'];
    final color = Color(option['color'] as int);
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.1) : AppTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? color.withOpacity(0.6) : AppTheme.breeze.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected ? color.withOpacity(0.2) : AppTheme.breeze.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: RadioListTile<String>(
        value: option['modelType'] as String,
        groupValue: _selectedModelType,
        onChanged: (value) {
          setState(() {
            _selectedModelType = value;
          });
          widget.onDeliveryOptionSelected(
            value!,
            option['fee'] as double,
          );
        },
        dense: true,
        title: Row(
          children: [
            Text(
              option['icon'] as String,
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                option['name'] as String,
                style: TextStyle(
                                  fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isSelected ? color : AppTheme.deepTeal,
                ),
              ),
            ),
            if (option['isRecommended'] == true)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'RECOMMENDED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              option['description'] as String,
              style: TextStyle(
                color: AppTheme.breeze,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppTheme.breeze,
                ),
                SizedBox(width: 4),
                Text(
                  '${option['deliveryTime']}',
                  style: TextStyle(
                    color: AppTheme.breeze,
                    fontSize: 14,
                  ),
                ),
                Spacer(),
                Text(
                  'R${(option['fee'] as double).toStringAsFixed(2)}',
                  style: TextStyle(
                    color: color,
                                      fontSize: 17,
                  fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final feature in option['features'] as List<String>)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: color.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      feature,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        secondary: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Icon(
            Icons.local_shipping,
            color: color,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsSection() {
    final benefits = SystemDeliveryService.getSystemDeliveryBenefits();
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.breeze.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎯 System Delivery Benefits',
            style: TextStyle(
                              fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.deepTeal,
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final benefit in benefits)
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.deepTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.deepTeal.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        benefit['icon'] as String,
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(width: 6),
                      Text(
                        benefit['title'] as String,
                        style: TextStyle(
                          color: AppTheme.deepTeal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
