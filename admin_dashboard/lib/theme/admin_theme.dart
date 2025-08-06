import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminTheme {
  // Beautiful Tints Color Palette (matching the image)
  static const Color deepTeal = Color(0xFF1F4654);      // Deep Teal #1F4654
  static const Color cloud = Color(0xFF7FB2BF);         // Cloud #7FB2BF
  static const Color breeze = Color(0xFFA6C9D2);        // Breeze #A6C9D2
  static const Color whisper = Color(0xFFCCE0E6);       // Whisper #CCE0E6
  static const Color angel = Color(0xFFF2F7F9);         // Angel #F2F7F9
  
  // Complementary Color Palette (for cards and specific elements)
  static const Color paleLinen = Color(0xFFE0E0D9);
  static const Color indigo = Color(0xFF354269);
  static const Color silverGray = Color(0xFFC0C0C0);
  static const Color fawn = Color(0xFFE5D1B7);
  static const Color antiqueWhite = Color(0xFFFAEBD7);
  
  // Additional colors
  static const Color darkGrey = Color(0xFF424242);
  static const Color mediumGrey = Color(0xFF757575);
  static const Color lightGrey = Color(0xFFBDBDBD);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  static const Color primaryOrange = Color(0xFFFF5722);
  
  // Gradients using beautiful tints palette
  static const List<Color> primaryGradient = [deepTeal, cloud];
  static const List<Color> secondaryGradient = [cloud, breeze];
  static const List<Color> lightGradient = [whisper, angel];
  static const List<Color> surfaceGradient = [angel, whisper];
  static const List<Color> heroGradient = [deepTeal, cloud, breeze];
  static const List<Color> backgroundGradient = [whisper, angel];
  
  // Gradients using complementary palette
  static const List<Color> cardGradient = [paleLinen, antiqueWhite];
  static const List<Color> buttonGradient = [indigo, Color(0xFF2C3550)];
  static const List<Color> accentGradient = [fawn, Color(0xFFD4C4A8)];
  static const List<Color> warmAccent = [fawn, Color(0xFFD4C4A8)];
  static const List<Color> coolAccent = [silverGray, Color(0xFFA8A8A8)];
  static const List<Color> successGradient = [success, Color(0xFF388E3C)];
  static const List<Color> warningGradient = [warning, Color(0xFFF57C00)];
  
  // Text Styles using vibrant theme colors
  static TextStyle get displayLarge => GoogleFonts.poppins(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: deepTeal,
  );
  
  static TextStyle get displayMedium => GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: deepTeal,
  );
  
  static TextStyle get displaySmall => GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: deepTeal,
  );
  
  static TextStyle get headlineLarge => GoogleFonts.poppins(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: deepTeal,
  );
  
  static TextStyle get headlineMedium => GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: deepTeal,
  );
  
  static TextStyle get headlineSmall => GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: deepTeal,
  );
  
  static TextStyle get titleLarge => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: deepTeal,
  );
  
  static TextStyle get titleMedium => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: deepTeal,
  );
  
  static TextStyle get titleSmall => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: deepTeal,
  );
  
  static TextStyle get bodyLarge => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: darkGrey,
  );
  
  static TextStyle get bodyMedium => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: darkGrey,
  );
  
  static TextStyle get bodySmall => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: mediumGrey,
  );
  
  static TextStyle get labelLarge => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: deepTeal,
  );
  
  static TextStyle get labelMedium => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: deepTeal,
  );
  
  static TextStyle get labelSmall => GoogleFonts.poppins(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: mediumGrey,
  );
  
  // Helper methods for decorations
  static BoxDecoration cardDecoration({
    double borderRadius = 16,
    List<BoxShadow>? boxShadow,
    Color? color,
  }) {
    return BoxDecoration(
      color: color ?? angel,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: boxShadow ?? [
        BoxShadow(
          color: indigo.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
  
  static BoxDecoration gradientCardDecoration({
    double borderRadius = 16,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: cardGradient,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: boxShadow ?? [
        BoxShadow(
          color: indigo.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
  
  static BoxDecoration primaryGradientDecoration({
    double borderRadius = 16,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: primaryGradient,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: boxShadow ?? [
        BoxShadow(
          color: deepTeal.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
  
  // Gradient getters
  static LinearGradient get cardBackgroundGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: cardGradient,
  );
  
  static LinearGradient get primaryButtonGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: buttonGradient,
  );
  
  static LinearGradient get screenBackgroundGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: backgroundGradient,
  );
  
  static LinearGradient get heroSectionGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: heroGradient,
    stops: [0.0, 0.6, 1.0],
  );
  
  // Accent color getters
  static Color get warmAccentColor => const Color(0xFFFF8A50); // Coral
  static Color get coolAccentColor => const Color(0xFF4FC3F7); // Light blue
  static Color get successAccentColor => const Color(0xFF00BCD4); // Cyan
  static Color get warningAccentColor => const Color(0xFFFFB74D); // Soft orange
  
  // Shade helpers
  static Color getShade(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
  
  static double complementaryElevation = 4.0;
  static Color complementaryGlow = indigo;
  
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
        return info;
      case 'inactive':
      case 'rejected':
      case 'cancelled':
        return error;
      default:
        return silverGray;
    }
  }
  
  // Category gradients
  static List<Color> getCategoryGradient(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return [deepTeal, cloud];
      case 'beverages':
        return [breeze, whisper];
      case 'desserts':
        return [fawn, antiqueWhite];
      case 'snacks':
        return [indigo, silverGray];
      default:
        return [deepTeal, cloud];
    }
  }
  
  // Create gradient helper
  static LinearGradient createGradient(List<Color> colors, {Alignment? begin, Alignment? end}) {
    return LinearGradient(
      begin: begin ?? Alignment.topLeft,
      end: end ?? Alignment.bottomRight,
      colors: colors,
    );
  }
} 