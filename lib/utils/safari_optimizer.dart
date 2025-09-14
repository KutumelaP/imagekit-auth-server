import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omniasa/utils/web_html_stub.dart'
    if (dart.library.html) 'dart:html' as html;

class SafariOptimizer {
  static bool _isInitialized = false;
  static bool _isSafari = false;
  static bool _isMobile = false;
  
  static void initialize() {
    if (_isInitialized) return;
    
    if (kIsWeb) {
      _detectBrowser();
      _applyBasicMobileOptimizations();
      _isInitialized = true;
    }
  }
  
  static void _detectBrowser() {
    try {
      final userAgent = html.window.navigator.userAgent;
      _isMobile = userAgent.contains('Android') || 
                   userAgent.contains('iPhone') || 
                   userAgent.contains('iPad') || 
                   userAgent.contains('iPod') || 
                   userAgent.contains('BlackBerry') || 
                   userAgent.contains('IEMobile') || 
                   userAgent.contains('Opera Mini');
      _isSafari = userAgent.contains('Safari') && 
                   !userAgent.contains('Chrome') && 
                   !userAgent.contains('Firefox');
      
      if (_isMobile) {
        print('🔍 DEBUG: Mobile browser detected - applying basic optimizations');
      }
      if (_isSafari) {
        print('🔍 DEBUG: Safari detected - applying minimal optimizations');
      }
    } catch (e) {
      print('🔍 DEBUG: Error detecting browser: $e');
    }
  }
  
  static void _applyBasicMobileOptimizations() {
    if (!_isMobile) return;
    
    try {
      // Basic mobile viewport optimizations only
      html.document.documentElement?.style.setProperty('height', '100vh');
      html.document.body?.style.setProperty('height', '100vh');
      html.document.body?.style.setProperty('position', 'relative');
      html.document.body?.style.setProperty('overflow', 'auto');
      
      // Prevent overscroll behavior
      html.document.body?.style.setProperty('overscroll-behavior', 'none');
      html.document.body?.style.setProperty('-webkit-overflow-scrolling', 'touch');
      
    } catch (e) {
      print('🔍 DEBUG: Error applying basic mobile optimizations: $e');
    }
  }
  
  // Optimize scroll behavior for mobile
  static Widget optimizeScrollView(Widget child) {
    if (!_isMobile) return child;
    
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Prevent overscroll in mobile browsers
        if (notification is OverscrollIndicatorNotification) {
          return true; // Consume the notification
        }
        return false;
      },
      child: child,
    );
  }
  
  // Basic image optimization for mobile
  static Widget optimizeImage(Widget image) {
    if (!_isMobile) return image;
    
    return RepaintBoundary(
      child: image,
    );
  }
  
  // Basic list view optimization for mobile
  static Widget optimizeListView(Widget listView) {
    if (!_isMobile) return listView;
    
    return RepaintBoundary(
      child: listView,
    );
  }
} 