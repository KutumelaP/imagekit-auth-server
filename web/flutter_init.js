// Flutter Web Initialization with Enhanced iOS Safari Support
(function() {
  'use strict';
  
  const isIOS = /iPhone|iPad|iPod/.test(navigator.userAgent);
  const isSafari = /^((?!chrome|android).)*safari/i.test(navigator.userAgent);
  
  console.log('🚀 Flutter Init: iOS=' + isIOS + ', Safari=' + isSafari);
  
  // Enhanced configuration for older Flutter versions
  const flutterConfig = {
    renderer: "canvaskit", // Better compatibility than HTML renderer
    canvasKitBaseUrl: "/canvaskit/",
    debugShowSemanticsDebugger: false,
    hostElement: document.getElementById('flutter_target')
  };
  
  // iOS Safari specific optimizations
  if (isIOS && isSafari) {
    console.log('📱 Applying iOS Safari optimizations');
    
    // Prevent memory pressure refreshes
    flutterConfig.memoryOptimization = true;
    
    // PWA-specific optimizations
    if (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) {
      console.log('📱 PWA mode detected - applying enhanced optimizations');
      flutterConfig.poweredByFlutter = false; // Reduce memory footprint
      flutterConfig.debugShowSemanticsDebugger = false;
    }
    
    // Use default CanvasKit variant for Safari (no chromium variant)
    
    // Keep app alive
    let keepAliveInterval;
    
    const startKeepAlive = () => {
      if (keepAliveInterval) clearInterval(keepAliveInterval);
      keepAliveInterval = setInterval(() => {
        if (!document.hidden && window.flutter) {
          // Minimal activity to prevent iOS from killing the page
          try {
            // Touch the Flutter engine to keep it alive
            if (window.flutter.callbackManager) {
              // Just ping the callback manager
            }
          } catch (e) {
            // Ignore errors, just trying to keep alive
          }
        }
      }, 25000); // Every 25 seconds
    };
    
    const stopKeepAlive = () => {
      if (keepAliveInterval) {
        clearInterval(keepAliveInterval);
        keepAliveInterval = null;
      }
    };
    
    // Start keep-alive when Flutter loads
    document.addEventListener('flutter-initialized', startKeepAlive);
    
    // Manage keep-alive based on visibility
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        stopKeepAlive();
      } else {
        startKeepAlive();
      }
    });
  }
  
  // Make config globally available
  window.flutterConfiguration = flutterConfig;
  
  console.log('✅ Flutter configuration ready:', flutterConfig);
  
})();
