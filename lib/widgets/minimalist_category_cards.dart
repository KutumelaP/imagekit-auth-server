import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'safe_network_image.dart';

// Minimalist Category Card with Clean Design
class MinimalistCategoryCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? accentColor;

  const MinimalistCategoryCard({
    super.key,
    required this.title,
    this.imageUrl,
    required this.icon,
    this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    // Use the new gradient system for better visual hierarchy
    final gradientColors = CategoryStyling.getGradientForCategory(title);
    final accentColorForCategory = CategoryStyling.getAccentColorForCategory(title);
    final themeAccentColor = accentColor ?? accentColorForCategory;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive height based on screen width
        final cardHeight = constraints.maxWidth > 600 ? 100.0 : 90.0;
        final isSmallScreen = constraints.maxWidth < 400;
        
    return GestureDetector(
      onTap: onTap,
      child: Container(
            height: cardHeight,
        decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                  color: themeAccentColor.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
            ),
            BoxShadow(
                  color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
                  offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Enhanced Image/Icon Section with beautiful gradients
            Expanded(
                  flex: isSmallScreen ? 2 : 2,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                          gradientColors[0].withOpacity(0.2),
                          gradientColors[1].withOpacity(0.1),
                    ],
                  ),
                ),
                    child: Stack(
                        children: [
                        // Background Image (if available)
                        if ((imageUrl ?? CategoryStyling.getImageForCategory(title)).isNotEmpty)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                bottomLeft: Radius.circular(20),
                              ),
                              child: SafeNetworkImage(
                                imageUrl: imageUrl ?? CategoryStyling.getImageForCategory(title),
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                borderRadius: BorderRadius.circular(12),

                              ),
                            ),
                          )
                        else
                          _buildIconSection(themeAccentColor, gradientColors),
                        
                        // Gradient Overlay
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                bottomLeft: Radius.circular(20),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                  themeAccentColor.withOpacity(0.1),
                                  ],
                              ),
                            ),
                          ),
                                  ),
                                ],
                              ),
                  ),
                ),
                
                // Enhanced Content Section
                Expanded(
                  flex: isSmallScreen ? 3 : 3,
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Category Title
                        Flexible(
                          child: SafeUI.safeText(
                            title,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                              height: 1.1,
                              fontSize: isSmallScreen ? 14 : 16,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        
                        SizedBox(height: isSmallScreen ? 2 : 4),
                        
                        // Category Description/Subtitle
                        Flexible(
                          child: SafeUI.safeText(
                            _getCategoryDescription(title),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: themeAccentColor,
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                              fontSize: isSmallScreen ? 10 : 12,
                            ),
                            maxLines: 1,
              ),
            ),
                        
                        if (!isSmallScreen) SizedBox(height: 4),
                        
                        // Action indicator
                        if (!isSmallScreen)
                          Flexible(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: themeAccentColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: themeAccentColor.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                  children: [
                                                                              SafeUI.safeText(
                                        'Explore',
                                        style: TextStyle(
                                          color: themeAccentColor,
                                          fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                    ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          color: themeAccentColor,
                                          size: 8,
                                        ),
                                      ],
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
          ],
        ),
      ),
        );
      },
    );
  }

  Widget _buildIconSection(Color themeAccentColor, List<Color> gradientColors) {
    return Container(
            decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
            gradientColors[0].withOpacity(0.15),
            gradientColors[1].withOpacity(0.08),
                ],
              ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: themeAccentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
            color: themeAccentColor,
              size: 28,
          ),
        ),
      ),
    );
  }

  String _getCategoryDescription(String categoryTitle) {
    final descriptions = {
      'Food': 'Delicious local meals',
      'Drinks': 'Refreshing beverages',
      'Bakery': 'Fresh baked goods',
      'Fruits': 'Fresh & organic',
      'Vegetables': 'Farm fresh produce',
      'Snacks': 'Quick & tasty treats',
      'Dairy': 'Fresh dairy products',
      'Meat': 'Quality meat products',
      'Seafood': 'Fresh from the ocean',
      'Spices': 'Aromatic seasonings',
    };
    return descriptions[categoryTitle] ?? 'Discover local products';
  }
}

// Premium Minimalist Card with Enhanced Shadows
class PremiumMinimalistCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? accentColor;

  const PremiumMinimalistCard({
    super.key,
    required this.title,
    this.imageUrl,
    required this.icon,
    this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final themeAccentColor = accentColor ?? Theme.of(context).colorScheme.primary;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            // Image Section
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      themeAccentColor.withOpacity(0.1),
                      themeAccentColor.withOpacity(0.05),
                    ],
                  ),
                ),
                child: (imageUrl ?? CategoryStyling.getImageForCategory(title)).isNotEmpty
                    ? Stack(
                        children: [
                          // Background Image
                          Positioned.fill(
                            child: SafeNetworkImage(
                              imageUrl: imageUrl ?? CategoryStyling.getImageForCategory(title),
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(12),

                            ),
                          ),
                          // Gradient Overlay
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Icon overlay
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                icon,
                                size: 20,
                                color: themeAccentColor,
                              ),
                            ),
                          ),
                        ],
                      )
                    : _buildIconSection(context, themeAccentColor),
              ),
            ),
            // Text Section
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeUI.safeText(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.1,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    SafeUI.safeText(
                      'Explore',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconSection(BuildContext context, Color themeAccentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeAccentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: themeAccentColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 32,
              color: themeAccentColor,
            ),
          ),
        ],
      ),
    );
  }
}

// Category Styling Helper Class
class CategoryStyling {
  static IconData getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'drinks':
        return Icons.local_drink;
      case 'bakery':
        return Icons.cake;
      case 'fruits':
        return Icons.apple;
      case 'vegetables':
        return Icons.eco;
      case 'meat':
        return Icons.set_meal;
      case 'dairy':
        return Icons.local_dining;
      case 'snacks':
        return Icons.fastfood;
      case 'beverages':
        return Icons.coffee;
      case 'desserts':
        return Icons.icecream;
      case 'organic':
        return Icons.spa;
      case 'local':
        return Icons.location_on;
      case 'fresh':
        return Icons.restaurant_menu;
      case 'healthy':
        return Icons.favorite;
      case 'electronics':
        return Icons.devices;
      case 'clothes':
        return Icons.shopping_bag;
      case 'other':
        return Icons.category;
      default:
        return Icons.category;
    }
  }

  static String getImageForCategory(String category) {
    // Return appropriate image URL based on category
    // This is a placeholder - implement actual image mapping
    return '';
  }

  static Color getColorForCategory(String category, [int? index]) {
    // Enhanced color scheme using tints palette + strategic accent colors
    final categoryColorMap = {
      'food': AppTheme.deepTeal,           // Primary brand color for main category
      'drinks': AppTheme.cloud,            // Cool and refreshing
      'bakery': AppTheme.primaryOrange,    // Warm and inviting
      'fruits': AppTheme.primaryGreen,     // Fresh and natural
      'vegetables': AppTheme.secondaryGreen, // Healthy and organic
      'snacks': AppTheme.primaryPurple,    // Fun and vibrant
      'electronics': AppTheme.primaryBlue, // Tech and modern
      'clothes': AppTheme.breeze,         // Soft and elegant
      'other': AppTheme.cloud,             // Neutral and versatile
    };
    
    // Try to get category-specific color first
    if (categoryColorMap.containsKey(category.toLowerCase())) {
      return categoryColorMap[category.toLowerCase()]!;
    }
    
    // Enhanced fallback colors using tints palette + accents
    final fallbackColors = [
      AppTheme.deepTeal,        // Primary brand
      AppTheme.cloud,           // Secondary brand
      AppTheme.primaryOrange,   // Warm accent
      AppTheme.primaryGreen,    // Fresh accent
      AppTheme.breeze,          // Light accent
      AppTheme.primaryBlue,     // Cool accent
      AppTheme.primaryPurple,   // Rich accent
      AppTheme.secondaryOrange, // Deep warm
      AppTheme.secondaryGreen,  // Deep fresh
      AppTheme.secondaryBlue,   // Deep cool
    ];
    
    // Use provided index if available, otherwise use hash-based assignment
    if (index != null) {
      return fallbackColors[index % fallbackColors.length];
    }
    
    // Simple hash-based color assignment
    final hash = category.hashCode;
    final colorIndex = hash.abs() % fallbackColors.length;
    return fallbackColors[colorIndex];
  }

  // New: Get gradient colors for categories using tints palette
  static List<Color> getGradientForCategory(String category, [int? index]) {
    final categoryGradients = {
      'food': [AppTheme.deepTeal, AppTheme.cloud],              // Primary brand gradient
      'drinks': [AppTheme.cloud, AppTheme.breeze],              // Cool and flowing
      'bakery': [AppTheme.primaryOrange, AppTheme.secondaryOrange], // Warm and cozy
      'fruits': [AppTheme.primaryGreen, AppTheme.secondaryGreen],   // Fresh and vibrant
      'vegetables': [AppTheme.secondaryGreen, AppTheme.lightGreen], // Natural and healthy
      'snacks': [AppTheme.primaryPurple, AppTheme.secondaryPurple], // Fun and energetic
      'electronics': [AppTheme.primaryBlue, AppTheme.secondaryBlue], // Tech and modern
      'clothes': [AppTheme.breeze, AppTheme.whisper],          // Soft and elegant
      'other': [AppTheme.cloud, AppTheme.breeze],               // Neutral and versatile
    };

    // Try to get category-specific gradient first
    if (categoryGradients.containsKey(category.toLowerCase())) {
      return categoryGradients[category.toLowerCase()]!;
    }

    // Enhanced fallback gradients
    final fallbackGradients = [
      [AppTheme.deepTeal, AppTheme.cloud],           // Primary tints
      [AppTheme.cloud, AppTheme.breeze],             // Light tints
      [AppTheme.breeze, AppTheme.whisper],           // Subtle tints
      [AppTheme.primaryOrange, AppTheme.secondaryOrange], // Warm
      [AppTheme.primaryGreen, AppTheme.secondaryGreen],   // Fresh
      [AppTheme.primaryBlue, AppTheme.secondaryBlue],     // Cool
      [AppTheme.primaryPurple, AppTheme.secondaryPurple], // Rich
      [AppTheme.whisper, AppTheme.angel],            // Ultra light
      [AppTheme.deepTeal.withOpacity(0.8), AppTheme.cloud], // Soft primary
      [AppTheme.cloud.withOpacity(0.8), AppTheme.breeze],   // Soft secondary
    ];

    // Use provided index if available, otherwise use hash-based assignment
    if (index != null) {
      return fallbackGradients[index % fallbackGradients.length];
    }

    // Simple hash-based gradient assignment
    final hash = category.hashCode;
    final gradientIndex = hash.abs() % fallbackGradients.length;
    return fallbackGradients[gradientIndex];
  }

  // New: Get accent color for category (for icons, highlights, etc.)
  static Color getAccentColorForCategory(String category, [int? index]) {
    final categoryAccents = {
      'food': AppTheme.primaryOrange,      // Appetizing warm accent
      'drinks': AppTheme.primaryBlue,      // Cool and refreshing
      'bakery': AppTheme.warning,          // Golden brown like baked goods
      'fruits': AppTheme.primaryGreen,     // Natural and fresh
      'vegetables': AppTheme.secondaryGreen, // Organic and healthy
      'snacks': AppTheme.primaryPurple,    // Fun and playful
      'electronics': AppTheme.cloud,       // Tech blue from our palette
      'clothes': AppTheme.deepTeal,       // Elegant and sophisticated
      'other': AppTheme.breeze,            // Neutral from our palette
    };

    // Try to get category-specific accent first
    if (categoryAccents.containsKey(category.toLowerCase())) {
      return categoryAccents[category.toLowerCase()]!;
    }

    // Fallback to main color function
    return getColorForCategory(category, index);
  }
} 