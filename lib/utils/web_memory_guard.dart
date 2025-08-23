import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marketplace_app/utils/web_html_stub.dart'
    if (dart.library.html) 'dart:html' as html;

/// WebMemoryGuard reduces memory pressure on iOS Safari by:
/// - Clearing Flutter's image cache when the page is hidden or backgrounded
/// - Clearing live images to free GPU memory
/// - Optionally throttling work via visibilitychange
class WebMemoryGuard with WidgetsBindingObserver {
  static final WebMemoryGuard _instance = WebMemoryGuard._internal();
  factory WebMemoryGuard() => _instance;
  WebMemoryGuard._internal();

  bool _initialized = false;

  void initialize() {
    if (_initialized || !kIsWeb) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    // Listen for tab visibility changes to free memory when hidden
    try {
      html.document.addEventListener('visibilitychange', (event) {
        final hidden = html.document.visibilityState == 'hidden';
        if (hidden) {
          _clearFlutterImageCaches();
        }
      });
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On inactive/paused (backgrounded), clear image caches
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _clearFlutterImageCaches();
    }
  }

  void _clearFlutterImageCaches() {
    try {
      final cache = PaintingBinding.instance.imageCache;
      cache.clear();
      cache.clearLiveImages();
    } catch (_) {}
  }
}


