import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/checkout_v2/checkout_v2_view_model.dart';

// PAXI Delivery Speed Selector
class PaxiSpeedSelector extends StatelessWidget {
  final CheckoutV2ViewModel vm;
  const PaxiSpeedSelector({Key? key, required this.vm}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.cardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardElevation,
        border: Border.all(
          color: AppTheme.breeze.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppTheme.lightGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.cloud.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.speed,
                  color: AppTheme.deepTeal,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAXI Delivery Speed',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppTheme.deepTeal,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Choose your preferred delivery speed',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.mediumGrey,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          
          // Speed Options
          Column(
            children: [
              _buildSpeedOption(
                speed: 'standard',
                name: 'Standard Delivery',
                time: '7-9 business days',
                price: 59.95,
                isSelected: vm.selectedPaxiSpeed == 'standard',
                onTap: () => vm.setPaxiDeliverySpeed('standard'),
              ),
              SizedBox(height: 12),
              _buildSpeedOption(
                speed: 'express',
                name: 'Express Delivery',
                time: '3-5 business days',
                price: 109.95,
                isSelected: vm.selectedPaxiSpeed == 'express',
                onTap: () => vm.setPaxiDeliverySpeed('express'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedOption({
    required String speed,
    required String name,
    required String time,
    required double price,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.deepTeal.withOpacity(0.1) : AppTheme.whisper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.deepTeal : AppTheme.cloud.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.deepTeal : AppTheme.mediumGrey,
                  width: 2,
                ),
                color: isSelected ? AppTheme.deepTeal : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 12,
                      color: AppTheme.angel,
                    )
                  : null,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isSelected ? AppTheme.deepTeal : AppTheme.darkGrey,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.deepTeal : AppTheme.cloud.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'R${price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isSelected ? AppTheme.angel : AppTheme.deepTeal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
