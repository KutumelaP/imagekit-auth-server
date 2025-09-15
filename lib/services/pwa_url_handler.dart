import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omniasa/utils/web_js_stub.dart'
    if (dart.library.html) 'package:omniasa/utils/web_js_real.dart' as js;

/// 🚀 Service for handling PWA URLs and deep linking
class PWAUrlHandler {
  static final PWAUrlHandler _instance = PWAUrlHandler._internal();
  factory PWAUrlHandler() => _instance;
  PWAUrlHandler._internal();

  static GlobalKey<NavigatorState>? _navigatorKey;
  
  /// Initialize PWA URL handler with navigator key
  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    if (kIsWeb) {
      _setupUrlHandling();
    }
  }

  /// Set up web URL handling for PWA
  static void _setupUrlHandling() {
    try {
      if (kDebugMode) print('🚀 Setting up PWA URL handling...');
      
      // Listen for browser navigation events
      if (kIsWeb) {
        _setupPopStateListener();
      }
      
      if (kDebugMode) print('✅ PWA URL handling ready');
    } catch (e) {
      if (kDebugMode) print('❌ Error setting up PWA URL handling: $e');
    }
  }

  /// Set up browser back/forward button handling
  static void _setupPopStateListener() {
    try {
      // This would use dart:html's window.onPopState
      // For now, we rely on Flutter's built-in URL handling
      if (kDebugMode) print('🔗 Pop state listener ready');
    } catch (e) {
      if (kDebugMode) print('❌ Error setting up pop state listener: $e');
    }
  }

  /// Generate shareable store URL
  static String generateStoreUrl(String storeId, {String? baseUrl}) {
    final base = baseUrl ?? _getCurrentBaseUrl();
    // 🚀 Store list page filtered to a specific store (hash route for robust web deep link)
    return '$base/#/stores?storeId=$storeId';
  }

  /// Generate shareable store products URL  
  static String generateStoreProductsUrl(String storeId, {String? baseUrl}) {
    final base = baseUrl ?? _getCurrentBaseUrl();
    return '$base/store/$storeId/products';
  }

  /// Get current base URL
  static String _getCurrentBaseUrl() {
    if (kIsWeb) {
      try {
        return js.context.callMethod('eval', ['window.location.origin']) ?? 'https://www.omniasa.co.za';
      } catch (e) {
        return 'https://www.omniasa.co.za';
      }
    }
    return 'https://www.omniasa.co.za';
  }

  /// Handle incoming PWA navigation from service worker
  static void handleServiceWorkerNavigation(String url) {
    try {
      if (kDebugMode) print('🚀 Handling service worker navigation: $url');
      
      if (_navigatorKey?.currentState != null) {
        // Parse the URL and navigate accordingly
        if (url.contains('/store/')) {
          final uri = Uri.parse(url);
          final path = uri.path;
          
          if (kDebugMode) print('🏪 Navigating to store path: $path');
          _navigatorKey!.currentState!.pushNamed(path);
        } else {
          // Navigate to the URL as-is
          _navigatorKey!.currentState!.pushNamed(url);
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error handling service worker navigation: $e');
    }
  }

  /// Share store link
  static Future<void> shareStoreLink(String storeId, String storeName) async {
    try {
      final url = generateStoreUrl(storeId);
      final text = 'Check out $storeName on OmniaSA!';
      
      if (kIsWeb) {
        await _webShare(url, text, storeName);
      } else {
        // Mobile sharing would go here
        if (kDebugMode) print('📤 Would share: $text - $url');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error sharing store link: $e');
    }
  }

  /// Web share API
  static Future<void> _webShare(String url, String text, String title) async {
    try {
      if (kIsWeb) {
        // Check if Web Share API is available
        final hasWebShare = js.context.callMethod('eval', ['typeof navigator.share !== "undefined"']);
        
        if (hasWebShare == true) {
          js.context.callMethod('eval', ['''
            navigator.share({
              title: '$title',
              text: '$text',
              url: '$url'
            }).then(() => {
              console.log('✅ Store link shared successfully');
            }).catch((error) => {
              console.error('❌ Error sharing store link:', error);
              // Fallback to clipboard
              navigator.clipboard.writeText('$url').then(() => {
                console.log('📋 Store link copied to clipboard');
              });
            });
          ''']);
        } else {
          // Fallback to clipboard
          js.context.callMethod('eval', ['''
            navigator.clipboard.writeText('$url').then(() => {
              console.log('📋 Store link copied to clipboard as fallback');
            }).catch((error) => {
              console.error('❌ Error copying to clipboard:', error);
            });
          ''']);
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error with web share: $e');
    }
  }

  /// Copy store link to clipboard
  static Future<void> copyStoreLink(String storeId) async {
    try {
      final url = generateStoreUrl(storeId);
      
      if (kIsWeb) {
        js.context.callMethod('eval', ['''
          navigator.clipboard.writeText('$url').then(() => {
            console.log('📋 Store link copied to clipboard');
          }).catch((error) => {
            console.error('❌ Error copying store link:', error);
          });
        ''']);
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error copying store link: $e');
    }
  }

  /// Check if current page is a store page
  static bool isStorePage() {
    if (!kIsWeb) return false;
    
    try {
      final pathname = js.context.callMethod('eval', ['window.location.pathname']);
      return pathname?.toString().contains('/store/') == true;
    } catch (e) {
      return false;
    }
  }

  /// Get current store ID from URL
  static String? getCurrentStoreId() {
    if (!kIsWeb) return null;
    
    try {
      final pathname = js.context.callMethod('eval', ['window.location.pathname']);
      final path = pathname?.toString() ?? '';
      
      if (path.contains('/store/')) {
        final parts = path.split('/store/');
        if (parts.length > 1) {
          final storeIdPart = parts[1].split('/')[0]; // Get first part after /store/
          return storeIdPart.isNotEmpty ? storeIdPart : null;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update page title for store
  static void updateStorePageTitle(String storeName) {
    if (!kIsWeb) return;
    
    try {
      js.context.callMethod('eval', ['''
        document.title = '$storeName - OmniaSA';
        
        // Update meta description
        var metaDesc = document.querySelector('meta[name="description"]');
        if (metaDesc) {
          metaDesc.setAttribute('content', 'Shop at $storeName on OmniaSA - Your local SA marketplace for food and goods');
        }
        
        // Update og:title
        var ogTitle = document.querySelector('meta[property="og:title"]');
        if (ogTitle) {
          ogTitle.setAttribute('content', '$storeName - OmniaSA');
        }
      ''']);
    } catch (e) {
      if (kDebugMode) print('❌ Error updating page title: $e');
    }
  }
}
