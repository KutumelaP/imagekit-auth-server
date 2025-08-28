// Performance Optimization Script for Mzansi Marketplace
// This script optimizes loading performance and reduces white screen time

(function() {
  'use strict';
  
  // Performance metrics tracking
  const performanceMetrics = {
    startTime: performance.now(),
    loadStart: 0,
    loadEnd: 0,
    firstPaint: 0,
    firstContentfulPaint: 0
  };
  
  // Track performance metrics
  if ('PerformanceObserver' in window) {
    const observer = new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) {
        if (entry.name === 'first-paint') {
          performanceMetrics.firstPaint = entry.startTime;
        }
        if (entry.name === 'first-contentful-paint') {
          performanceMetrics.firstContentfulPaint = entry.startTime;
        }
      }
    });
    observer.observe({ entryTypes: ['paint'] });
  }
  
  // Preload critical resources
  const preloadResources = () => {
    const criticalResources = [
      '/main.dart.js',
      '/flutter.js',
      '/canvaskit/canvaskit.js'
    ];
    
    criticalResources.forEach(url => {
      const link = document.createElement('link');
      link.rel = 'preload';
      link.as = 'script';
      link.href = url;
      link.crossOrigin = 'anonymous';
      document.head.appendChild(link);
    });
  };
  
  // Optimize Flutter initialization
  const optimizeFlutterInit = () => {
    // Set Flutter configuration for optimal performance
    window.flutterConfiguration = window.flutterConfiguration || {};
    window.flutterConfiguration.renderer = 'canvaskit'; // Use CanvasKit for better performance
    window.flutterConfiguration.canvaskitBaseUrl = '/canvaskit/';
    
    // Enable hardware acceleration hints
    if (window.flutterConfiguration.renderer === 'canvaskit') {
      document.documentElement.style.setProperty('--flutter-renderer', 'canvaskit');
    }
  };
  
  // Initialize optimizations
  const init = () => {
    preloadResources();
    optimizeFlutterInit();
    
    // Track when Flutter is ready
    document.addEventListener('flutter-initialized', () => {
      performanceMetrics.loadEnd = performance.now();
      
      // Log performance metrics
      console.log('🚀 Performance Metrics:', {
        totalLoadTime: performanceMetrics.loadEnd - performanceMetrics.startTime,
        firstPaint: performanceMetrics.firstPaint,
        firstContentfulPaint: performanceMetrics.firstContentfulPaint
      });
      
      // Send performance data to analytics if available
      if (typeof gtag !== 'undefined') {
        gtag('event', 'app_load_performance', {
          'event_category': 'Performance',
          'event_label': 'Flutter Ready',
          'value': Math.round(performanceMetrics.loadEnd - performanceMetrics.startTime)
        });
      }
    });
  };
  
  // Run optimizations when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
  
  // Export for debugging
  window.mzansiPerformance = performanceMetrics;
})();

