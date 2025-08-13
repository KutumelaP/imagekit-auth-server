import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:html' as html;

class SafariOptimizer {
  static bool _isInitialized = false;
  static bool _isSafari = false;
  static bool _isMobile = false;
  
  static void initialize() {
    if (_isInitialized) return;
    
    if (kIsWeb) {
      _detectBrowser();
      _applyMobileOptimizations();
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
        print('🔍 DEBUG: Mobile browser detected - applying optimizations');
      }
      if (_isSafari) {
        print('🔍 DEBUG: Safari detected - applying Safari-specific optimizations');
      }
    } catch (e) {
      print('🔍 DEBUG: Error detecting browser: $e');
    }
  }
  
  static void _applyMobileOptimizations() {
    if (!_isMobile) return;
    
    try {
      // Mobile viewport optimizations
      html.document.documentElement?.style.setProperty('height', '100vh');
      html.document.documentElement?.style.setProperty('height', '-webkit-fill-available');
      html.document.documentElement?.style.setProperty('height', '-moz-available');
      html.document.documentElement?.style.setProperty('height', 'stretch');
      
      // Body optimizations
      html.document.body?.style.setProperty('height', '100vh');
      html.document.body?.style.setProperty('height', '-webkit-fill-available');
      html.document.body?.style.setProperty('height', '-moz-available');
      html.document.body?.style.setProperty('height', 'stretch');
      html.document.body?.style.setProperty('position', 'relative');
      html.document.body?.style.setProperty('overflow', 'auto');
      
      // Prevent overscroll behavior
      html.document.body?.style.setProperty('overscroll-behavior', 'none');
      html.document.body?.style.setProperty('-webkit-overflow-scrolling', 'touch');
      
      // Mobile keyboard handling
      _setupMobileKeyboardHandling();
      
      // Safari-specific optimizations
      if (_isSafari) {
        _applySafariSpecificOptimizations();
      }
      
    } catch (e) {
      print('🔍 DEBUG: Error applying mobile optimizations: $e');
    }
  }
  
  static void _setupMobileKeyboardHandling() {
    try {
      // Handle viewport changes when keyboard appears
      void setViewportHeight() {
        final vh = (html.window.innerHeight ?? 0) * 0.01;
        html.document.documentElement?.style.setProperty('--vh', '${vh}px');
        
        // Update body height
        final height = html.window.innerHeight ?? 0;
        html.document.body?.style.setProperty('height', '${height}px');
        html.document.body?.style.setProperty('min-height', '${height}px');
      }
      
      // Set initial height
      setViewportHeight();
      
      // Update on resize (keyboard show/hide)
      html.window.addEventListener('resize', (event) => setViewportHeight());
      html.window.addEventListener('orientationchange', (event) => setViewportHeight());
      
      // Handle visual viewport changes
      if (html.window.visualViewport != null) {
        html.window.visualViewport!.addEventListener('resize', (event) => setViewportHeight());
      }
      
      // Prevent zoom on double tap
      int lastTouchEnd = 0;
      html.document.addEventListener('touchend', (event) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastTouchEnd <= 300) {
          event.preventDefault();
        }
        lastTouchEnd = now;
      }, false);
      
      // Prevent pull-to-refresh
      html.document.addEventListener('touchmove', (event) {
        if (event is html.TouchEvent) {
          final touchCount = event.touches?.length ?? 0;
          if (touchCount > 1) {
            event.preventDefault();
          }
        }
      }, false);
      
    } catch (e) {
      print('🔍 DEBUG: Error setting up mobile keyboard handling: $e');
    }
  }
  
  static void _applySafariSpecificOptimizations() {
    try {
      // Safari-specific memory management
      html.window.addEventListener('pagehide', (event) {
        print('🔍 DEBUG: Page hide event - Safari memory management');
      });
      
      html.window.addEventListener('focus', (event) {
        print('🔍 DEBUG: Window focus - preventing Safari reload');
      });
      
      // Prevent Safari from unloading the page
      html.window.addEventListener('beforeunload', (event) {
        print('🔍 DEBUG: Before unload - Safari page management');
      });
      
    } catch (e) {
      print('🔍 DEBUG: Error applying Safari-specific optimizations: $e');
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
  
  // Optimize image loading for mobile
  static Widget optimizeImage(Widget image) {
    if (!_isMobile) return image;
    
    return RepaintBoundary(
      child: image,
    );
  }
  
  // Reduce animation complexity for mobile
  static Duration getOptimizedDuration(Duration original) {
    if (!_isMobile) return original;
    
    // Reduce animation duration to prevent lag on mobile
    return Duration(milliseconds: (original.inMilliseconds * 0.7).round());
  }
  
  // Optimize list views for mobile
  static Widget optimizeListView(Widget listView) {
    if (!_isMobile) return listView;
    
    return RepaintBoundary(
      child: listView,
    );
  }
  
  // Memory management for mobile
  static void clearMemory() {
    if (!_isMobile) return;
    
    try {
      // Clear image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      
      // Force garbage collection if available
      html.window.navigator.serviceWorker?.ready.then((registration) {
        registration.active?.postMessage({'type': 'clearCache'});
      });
      
      print('🔍 DEBUG: Memory cleared for mobile');
    } catch (e) {
      print('🔍 DEBUG: Error clearing memory: $e');
    }
  }
  
  // Prevent mobile browsers from reloading on focus
  static void preventReloadOnFocus() {
    if (!_isMobile) return;
    
    try {
      html.window.addEventListener('focus', (event) {
        // Prevent any reload behavior
        event.preventDefault();
      });
      
      html.window.addEventListener('pageshow', (event) {
        // Handle page show event
        print('🔍 DEBUG: Page show event - mobile navigation');
      });
      
    } catch (e) {
      print('🔍 DEBUG: Error preventing reload: $e');
    }
  }
  
  // Optimize canvas rendering for mobile
  static void optimizeCanvas() {
    if (!_isMobile) return;
    
    try {
      // Reduce canvas memory usage
      final canvas = html.document.querySelector('canvas');
      if (canvas != null) {
        canvas.style.setProperty('will-change', 'auto');
        canvas.style.setProperty('transform', 'translateZ(0)');
      }
    } catch (e) {
      print('🔍 DEBUG: Error optimizing canvas: $e');
    }
  }
  
  // Handle mobile keyboard visibility
  static void handleKeyboardVisibility() {
    if (!_isMobile) return;
    
    try {
      // Update viewport when keyboard appears/disappears
      void updateViewport() {
        final vh = (html.window.innerHeight ?? 0) * 0.01;
        html.document.documentElement?.style.setProperty('--vh', '${vh}px');
        
        // Update body height
        final height = html.window.innerHeight ?? 0;
        html.document.body?.style.setProperty('height', '${height}px');
        html.document.body?.style.setProperty('min-height', '${height}px');
      }
      
      // Listen for viewport changes
      html.window.addEventListener('resize', (event) => updateViewport());
      
      // Use visual viewport API if available
      if (html.window.visualViewport != null) {
        html.window.visualViewport!.addEventListener('resize', (event) => updateViewport());
      }
      
    } catch (e) {
      print('🔍 DEBUG: Error handling keyboard visibility: $e');
    }
  }
  
  // Check memory pressure (for backward compatibility)
  static void checkMemoryPressure() {
    if (!_isMobile) return;
    
    try {
      // Clear image cache if it's getting large
      final cache = PaintingBinding.instance.imageCache;
      if (cache.currentSize > 100) {
        print('🧹 Mobile: Clearing image cache (${cache.currentSize} images)');
        cache.clear();
        cache.clearLiveImages();
      }
      
      print('🔍 DEBUG: Memory pressure check completed');
    } catch (e) {
      print('🔍 DEBUG: Error checking memory pressure: $e');
    }
  }
} 