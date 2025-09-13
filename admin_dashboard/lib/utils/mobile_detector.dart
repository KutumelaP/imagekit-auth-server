import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class MobileDetector {
  static bool get isMobile {
    if (kIsWeb) {
      return _isWebMobile();
    } else {
      return Platform.isAndroid || Platform.isIOS;
    }
  }

  static bool get isTablet {
    if (kIsWeb) {
      return _isWebTablet();
    } else {
      return false; // For native apps, we only care about mobile vs desktop
    }
  }

  static bool get isDesktop {
    return !isMobile && !isTablet;
  }

  static bool _isWebMobile() {
    try {
      // Use MediaQuery to detect mobile screen size
      // This is a fallback method when we don't have access to window.navigator
      return false; // Will be overridden by MediaQuery-based detection
    } catch (e) {
      return false;
    }
  }

  static bool _isWebTablet() {
    try {
      // Use MediaQuery to detect tablet screen size
      return false; // Will be overridden by MediaQuery-based detection
    } catch (e) {
      return false;
    }
  }

  /// Check if current screen size indicates mobile device
  static bool isMobileScreenSize(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    
    // Consider mobile if width is less than 768px or height is less than 600px
    // This covers most mobile devices and small tablets
    return width < 768 || height < 600;
  }

  /// Check if current screen size indicates tablet device
  static bool isTabletScreenSize(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    
    // Consider tablet if width is between 768px and 1024px
    return width >= 768 && width < 1024;
  }

  /// Check if current screen size indicates desktop device
  static bool isDesktopScreenSize(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    
    // Consider desktop if width is 1024px or more
    return width >= 1024;
  }

  /// Get device type based on screen size
  static DeviceType getDeviceType(BuildContext context) {
    if (isMobileScreenSize(context)) {
      return DeviceType.mobile;
    } else if (isTabletScreenSize(context)) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  /// Check if admin dashboard should be blocked for current device
  static bool shouldBlockAdminDashboard(BuildContext context) {
    // Allow web access - only block native mobile apps
    if (kIsWeb) {
      return false; // Always allow web access
    }
    // Block mobile devices and small tablets for native apps only
    return isMobileScreenSize(context) || isTabletScreenSize(context);
  }
}

enum DeviceType {
  mobile,
  tablet,
  desktop,
}
