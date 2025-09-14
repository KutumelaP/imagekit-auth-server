import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';

class MobileBlockScreen extends StatelessWidget {
  const MobileBlockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.whisper,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AdminTheme.deepTeal.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.desktop_windows,
                    size: 60,
                    color: AdminTheme.deepTeal,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Title
                Text(
                  'Desktop Access Required',
                  style: AdminTheme.headlineMedium.copyWith(
                    color: AdminTheme.deepTeal,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Subtitle
                Text(
                  'Admin Dashboard',
                  style: AdminTheme.titleLarge.copyWith(
                    color: AdminTheme.mediumGrey,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 24),
                
                // Description
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AdminTheme.angel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AdminTheme.cloud.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'The Admin Dashboard is designed for desktop and laptop computers only.',
                        style: AdminTheme.bodyLarge.copyWith(
                          color: AdminTheme.deepTeal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      Text(
                        'For the best experience and full functionality, please access the admin dashboard from a desktop or laptop computer with a screen width of at least 1024px.',
                        style: AdminTheme.bodyMedium.copyWith(
                          color: AdminTheme.mediumGrey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Requirements
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AdminTheme.breeze.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AdminTheme.breeze.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AdminTheme.deepTeal,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'System Requirements',
                            style: AdminTheme.titleMedium.copyWith(
                              color: AdminTheme.deepTeal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      _buildRequirementItem(
                        'Screen Width:',
                        'Minimum 1024px',
                        Icons.desktop_windows,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      _buildRequirementItem(
                        'Browser:',
                        'Chrome, Firefox, Safari, or Edge',
                        Icons.web,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      _buildRequirementItem(
                        'Device:',
                        'Desktop or Laptop Computer',
                        Icons.computer,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Contact info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdminTheme.cloud.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.support_agent,
                        color: AdminTheme.deepTeal,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Need help? Contact your system administrator for assistance.',
                          style: AdminTheme.bodySmall.copyWith(
                            color: AdminTheme.mediumGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: AdminTheme.deepTeal.withOpacity(0.7),
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AdminTheme.bodyMedium.copyWith(
            color: AdminTheme.deepTeal,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: AdminTheme.bodyMedium.copyWith(
              color: AdminTheme.mediumGrey,
            ),
          ),
        ),
      ],
    );
  }
}





