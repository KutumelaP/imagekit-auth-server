import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Beautiful Tints Color Palette (matching the image)
  static const Color deepTeal = Color(0xFF1F4654);      // Deep Teal #1F4654
  static const Color cloud = Color(0xFF7FB2BF);         // Cloud #7FB2BF
  static const Color breeze = Color(0xFF5A7A8A);        // Breeze #5A7A8A (darker, more visible)
  static const Color whisper = Color(0xFFCCE0E6);       // Whisper #CCE0E6
  static const Color angel = Color(0xFFF2F7F9);         // Angel #F2F7F9

  // Neutral sand palette (provided swatches)
  static const Color sand0 = Color(0xFFEDEDE9); // EDEDE9
  static const Color sand1 = Color(0xFFD6CCC2); // D6CCC2
  static const Color sand2 = Color(0xFFF5EBE0); // F5EBE0
  static const Color sand3 = Color(0xFFE3D5CA); // E3D5CA
  static const Color sand4 = Color(0xFFD5BDAF); // D5BDAF

  // Complementary Color Palette (for cards and specific elements)
  static const Color paleLinen = Color(0xFFE0E0D9);     // Very light, almost off-white
  static const Color indigo = Color(0xFF354269);         // Deep, muted blue
  static const Color silverGray = Color(0xFFC0C0C0);    // Neutral, medium grey
  static const Color fawn = Color(0xFFE5D1B7);          // Light, warm beige
  static const Color antiqueWhite = Color(0xFFFAEBD7);  // Very light, creamy off-white

  // Accent colors for variety (keeping original for diversity)
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color secondaryGreen = Color(0xFF4CAF50);
  static const Color lightGreen = Color(0xFF8BC34A);
  static const Color accentGreen = Color(0xFF66BB6A);
  
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color secondaryBlue = Color(0xFF42A5F5);
  static const Color lightBlue = Color(0xFF90CAF9);
  
  static const Color primaryPurple = Color(0xFF7B1FA2);
  static const Color secondaryPurple = Color(0xFFAB47BC);
  static const Color lightPurple = Color(0xFFCE93D8);
  
  static const Color primaryOrange = Color(0xFFFF8F00);
  static const Color secondaryOrange = Color(0xFFFFB74D);
  static const Color lightOrange = Color(0xFFFFCC80);
  
  static const Color primaryRed = Color(0xFFD32F2F);
  static const Color secondaryRed = Color(0xFFEF5350);
  static const Color lightRed = Color(0xFFEF9A9A);
  
  static const Color darkGrey = Color(0xFF424242);
  static const Color mediumGrey = Color(0xFF666666);
  static const Color lightGrey = Color(0xFF9E9E9E);
  static const Color veryLightGrey = Color(0xFFF5F5F5);
  static const Color white = Color(0xFFFFFFFF);
  
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF2196F3);

  // Main App Gradients (using beautiful tints palette)
  static const List<Color> primaryGradient = [deepTeal, cloud];
  static const List<Color> secondaryGradient = [cloud, breeze];
  static const List<Color> lightGradient = [breeze, whisper];
  static const List<Color> surfaceGradient = [whisper, angel];
  
  // Hero and main app gradients (beautiful tints theme)
  static const List<Color> heroGradient = [deepTeal, cloud, breeze];
  static const List<Color> backgroundGradient = [whisper, angel];
  
  // Card Gradients (using beautiful tints palette)
  static const List<Color> cardGradient = [angel, whisper];
  static const List<Color> buttonGradient = [deepTeal, cloud];
  static const List<Color> accentGradient = [breeze, cloud];

  // Pickup UI tokens (use sand palette)
  static const LinearGradient pickupCardGradient = LinearGradient(
    colors: [sand2, sand0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Color pickupBorder = sand1;
  static const Color pickupAccent = sand4;
  static const Color pickupText = Colors.black87;
  static const Color pickupMuted = sand3;
  
  // Input field gradients and shadows
  static const List<Color> inputBackgroundGradient = [angel, whisper];
  static const List<BoxShadow> inputElevation = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];
  
  // Complementary accent gradients (for cards and specific elements)
  static const List<Color> warmAccent = [Color(0xFFFF8A50), Color(0xFFFFB388)];
  static const List<Color> coolAccent = [Color(0xFF4FC3F7), Color(0xFF81D4FA)];
  static const List<Color> successGradient = [Color(0xFF00BCD4), Color(0xFF4DD0E1)];
  static const List<Color> warningGradient = [Color(0xFFFFB74D), Color(0xFFFFCC80)];

  // Text Styles - Using vibrant theme colors
  static TextStyle get displayLarge => GoogleFonts.poppins(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: deepTeal,
  );

  static TextStyle get displayMedium => GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: deepTeal,
  );

  static TextStyle get displaySmall => GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: deepTeal,
  );

  static TextStyle get headlineLarge => GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: deepTeal,
  );

  static TextStyle get headlineMedium => GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: darkGrey,
  );

  static TextStyle get headlineSmall => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: darkGrey,
  );

  static TextStyle get titleLarge => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: darkGrey,
  );

  static TextStyle get titleMedium => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: darkGrey,
  );

  static TextStyle get titleSmall => GoogleFonts.poppins(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: darkGrey,
  );

  static TextStyle get bodyLarge => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: darkGrey,
  );

  static TextStyle get bodyMedium => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: mediumGrey,
  );

  static TextStyle get bodySmall => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: lightGrey,
  );

  static TextStyle get labelLarge => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: deepTeal,
  );

  static TextStyle get labelMedium => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: darkGrey,
  );

  static TextStyle get labelSmall => GoogleFonts.poppins(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: darkGrey,
  );

  // Theme Data
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: deepTeal,
      onPrimary: white,
      secondary: cloud,
      onSecondary: deepTeal,
      tertiary: breeze,
      onTertiary: deepTeal,
      surface: angel,
      onSurface: darkGrey,
      background: whisper,
      onBackground: darkGrey,
      error: error,
      onError: white,
      surfaceVariant: whisper,
      onSurfaceVariant: darkGrey,
      outline: breeze,
      outlineVariant: cloud,
    ),
    
    // App Bar Theme
    appBarTheme: AppBarTheme(
      backgroundColor: deepTeal,
      foregroundColor: white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: white,
      ),
    ),

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: angel,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: breeze),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: breeze),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: deepTeal, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: darkGrey,
      ),
      hintStyle: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: mediumGrey,
      ),
    ),

    // Card Theme (set to angel as requested)
    cardTheme: CardThemeData(
      color: angel,
      elevation: 4,
      shadowColor: indigo.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: deepTeal,
        foregroundColor: white,
        elevation: 4,
        shadowColor: deepTeal.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Outlined Button Theme
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: deepTeal,
        side: BorderSide(color: deepTeal, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Text Button Theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: deepTeal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    // Floating Action Button Theme
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: deepTeal,
      foregroundColor: white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: angel,
      selectedItemColor: deepTeal,
      unselectedItemColor: lightGrey,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    // Chip Theme
    chipTheme: ChipThemeData(
      backgroundColor: cloud,
      selectedColor: deepTeal,
      disabledColor: veryLightGrey,
      labelStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),

    // Divider Theme
    dividerTheme: DividerThemeData(
      color: breeze,
      thickness: 1,
      space: 1,
    ),

    // Icon Theme
    iconTheme: IconThemeData(
      color: deepTeal,
      size: 24,
    ),

    // Primary Icon Theme
    primaryIconTheme: IconThemeData(
      color: white,
      size: 24,
    ),

    // Scaffold Background Color
    scaffoldBackgroundColor: whisper,

    // Dialog Theme
    dialogTheme: DialogThemeData(
      backgroundColor: angel,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    // Snack Bar Theme
    snackBarTheme: SnackBarThemeData(
      backgroundColor: deepTeal,
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      contentTextStyle: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),

    // Progress Indicator Theme
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: deepTeal,
      linearTrackColor: cloud,
    ),

    // Switch Theme
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return deepTeal;
        }
        return lightGrey;
      }),
      trackColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return deepTeal.withOpacity(0.5);
        }
        return veryLightGrey;
      }),
    ),

    // Checkbox Theme
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return deepTeal;
        }
        return Colors.transparent;
      }),
      checkColor: MaterialStateProperty.all(white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),

    // Radio Theme
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return deepTeal;
        }
        return lightGrey;
      }),
    ),
  );

  // Helper methods for card decorations (using complementary colors)
  static BoxDecoration cardDecoration({
    Color? color,
    double borderRadius = 16,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      color: color ?? paleLinen,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: boxShadow ?? [
        BoxShadow(
          color: indigo.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration gradientCardDecoration({
    List<Color>? colors,
    double borderRadius = 16,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: colors ?? cardGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: boxShadow ?? [
        BoxShadow(
          color: indigo.withOpacity(0.15),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static BoxDecoration primaryGradientDecoration({
    List<Color>? colors,
    double borderRadius = 16,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: colors ?? primaryGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: boxShadow ?? [
        BoxShadow(
          color: deepTeal.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // Category-specific gradients (using vibrant theme)
  static List<Color> getCategoryGradient(String category) {
    switch (category.toLowerCase()) {
      case 'bakery':
      case 'bread':
        return [primaryOrange, secondaryOrange];
      case 'clothes':
      case 'fashion':
        return [primaryPurple, secondaryPurple];
      case 'electronics':
      case 'tech':
        return [primaryBlue, secondaryBlue];
      case 'home':
      case 'decor':
        return [primaryGreen, secondaryGreen];
      case 'food':
      case 'restaurant':
        return [primaryOrange, lightOrange];
      case 'beauty':
      case 'cosmetics':
        return [primaryPurple, lightPurple];
      case 'sports':
      case 'fitness':
        return [primaryGreen, lightGreen];
      case 'books':
      case 'education':
        return [primaryBlue, lightBlue];
      default:
        return [deepTeal, cloud];
    }
  }

  // Create gradient helper
  static LinearGradient createGradient(List<Color> colors) {
    return LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // Get shade helper
  static Color getShade(Color color, double opacity) {
    return color.withOpacity(opacity);
  }

  // Elevation helpers
  static List<BoxShadow> complementaryElevation = [
    BoxShadow(
      color: indigo.withOpacity(0.1),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> complementaryGlow = [
    BoxShadow(
      color: indigo.withOpacity(0.2),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ];

  // Status colors
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
      case 'completed':
      case 'delivered':
        return success;
      case 'pending':
      case 'processing':
        return warning;
      case 'confirmed':
        return breeze;
      case 'preparing':
        return warning;
      case 'ready':
        return deepTeal;
      case 'shipped':
        return primaryGreen;
      case 'rejected':
      case 'cancelled':
      case 'failed':
        return error;
      case 'draft':
      case 'inactive':
        return silverGray;
      default:
        return breeze;
    }
  }

  // Missing gradient methods that other files are using
  static LinearGradient get cardBackgroundGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: cardGradient,
  );

  static LinearGradient get primaryButtonGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: buttonGradient,
  );

  static LinearGradient get screenBackgroundGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: backgroundGradient,
  );

  static LinearGradient get heroSectionGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: heroGradient,
    stops: const [0.0, 0.6, 1.0],
  );

  // Missing accent color methods
  static Color get warmAccentColor => const Color(0xFFFF8A50); // Coral
  static Color get coolAccentColor => const Color(0xFF4FC3F7); // Light blue
  static Color get successAccentColor => const Color(0xFF00BCD4); // Cyan
  static Color get warningAccentColor => const Color(0xFFFFB74D); // Soft orange
}

class ResponsiveUtils {
    // Screen size breakpoints
    static const double mobileBreakpoint = 600;
    static const double tabletBreakpoint = 900;
    static const double desktopBreakpoint = 1200;
    
    // Check screen type
    static bool isMobile(BuildContext context) => 
        MediaQuery.of(context).size.width < mobileBreakpoint;
    
    static bool isTablet(BuildContext context) => 
        MediaQuery.of(context).size.width >= mobileBreakpoint && 
        MediaQuery.of(context).size.width < desktopBreakpoint;
    
    static bool isDesktop(BuildContext context) => 
        MediaQuery.of(context).size.width >= desktopBreakpoint;
    
    // Responsive spacing
    static double getHorizontalPadding(BuildContext context) {
      if (isMobile(context)) return 16.0;
      if (isTablet(context)) return 24.0;
      return 32.0;
    }
    
    static double getVerticalPadding(BuildContext context) {
      if (isMobile(context)) return 12.0;
      if (isTablet(context)) return 16.0;
      return 20.0;
    }
    
    // Responsive font sizes
    static double getHeadlineSize(BuildContext context) {
      if (isMobile(context)) return 24.0;
      if (isTablet(context)) return 28.0;
      return 32.0;
    }
    
    static double getTitleSize(BuildContext context) {
      if (isMobile(context)) return 18.0;
      if (isTablet(context)) return 20.0;
      return 22.0;
    }
    
    // Responsive grid columns
    static int getGridColumns(BuildContext context) {
      if (isMobile(context)) return 2;
      if (isTablet(context)) return 3;
      return 4;
    }
    
    // Responsive card width
    static double getCardWidth(BuildContext context) {
      final screenWidth = MediaQuery.of(context).size.width;
      if (isMobile(context)) return screenWidth * 0.85;
      if (isTablet(context)) return 300.0;
      return 350.0;
    }
    
    // Safe text scaling
    static TextStyle safeTextStyle(BuildContext context, TextStyle? baseStyle) {
      if (baseStyle == null) return const TextStyle();
      
      final mediaQuery = MediaQuery.of(context);
      final scaleFactor = mediaQuery.textScaleFactor.clamp(0.8, 1.2);
      
      return baseStyle.copyWith(
        fontSize: (baseStyle.fontSize ?? 14.0) * scaleFactor,
      );
    }
    
    // Responsive icon size
    static double getIconSize(BuildContext context, {double baseSize = 24.0}) {
      if (isMobile(context)) return baseSize * 0.9;
      if (isTablet(context)) return baseSize;
      return baseSize * 1.1;
    }
  }

// Overflow-safe UI helpers
class SafeUI {
  // Overflow-safe text widget
  static Widget safeText(
    String text, {
    TextStyle? style,
    int? maxLines,
    TextAlign? textAlign,
    TextOverflow overflow = TextOverflow.ellipsis,
  }) {
    return Text(
      text,
      style: style,
      maxLines: maxLines ?? 1,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
  
  // Safe flexible widget for rows
  static Widget safeFlexible({
    required Widget child,
    int flex = 1,
  }) {
    return Flexible(
      flex: flex,
      child: child,
    );
  }
  
  // Safe expanded widget with overflow protection
  static Widget safeExpanded({
    required Widget child,
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: child,
    );
  }
} 