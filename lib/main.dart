import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/cart_provider.dart';
import 'providers/user_provider.dart';
import 'providers/optimized_provider.dart';
import 'screens/simple_home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/CartScreen.dart';
import 'screens/CheckoutScreen.dart';
import 'screens/OrderHistoryScreen.dart';
import 'screens/ProfileEditScreen.dart';
import 'screens/SellerOrdersListScreen.dart';
import 'screens/SellerOrderDetailScreen.dart';
import 'screens/AdminReviewModerationScreen.dart';
import 'screens/AdminRoute.dart';
import 'screens/CacheManagementScreen.dart';
import 'screens/seller_product_management.dart';

import 'services/error_handler.dart';
import 'services/error_tracking_service.dart';
import 'services/notification_service.dart';
import 'utils/cache_utils.dart';
import 'utils/performance_utils.dart';
import 'utils/memory_optimizer.dart';
import 'utils/advanced_memory_optimizer.dart';
import 'services/bulletproof_service.dart';
import 'services/advanced_security_service.dart';
import 'services/enterprise_performance_service.dart';
import 'widgets/popup_notification.dart';
import 'widgets/simple_splash_screen.dart';
import 'firebase_options.dart';
import 'dart:async';
import 'theme/app_theme.dart';
import 'package:geolocator/geolocator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize notification service
  await NotificationService().initialize();
  
  // Request notification permissions
  await NotificationService().requestPermissions();
  
  // Initialize location permissions
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (serviceEnabled) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print('🔍 DEBUG: Requesting location permission on app start...');
        await Geolocator.requestPermission();
      }
    }
  } catch (e) {
    print('🔍 DEBUG: Error initializing location permissions: $e');
  }
  
  // Initialize error tracking
  ErrorTrackingService.initialize();
  
  // Initialize cache management
  await CacheUtils.autoClearCorruptedCache();
  
  // Initialize performance optimizations
  PerformanceUtils.initializeLargeImageCache();
  
  // Initialize memory optimization instead of large cache
  MemoryOptimizer.initialize();
  
  // Initialize advanced memory optimization
  AdvancedMemoryOptimizer.initialize();

  // 🛡️ Initialize bulletproof protection system
  await BulletproofService.initialize();
  
  // 🛡️ Initialize advanced security system
  AdvancedSecurityService.sanitizeInput('init'); // Initialize security service
  
  // 🚀 Initialize enterprise performance system
  await EnterprisePerformanceService.initialize();

  // Set up periodic memory cleanup with bulletproof protection
  Timer.periodic(const Duration(minutes: 2), (timer) {
    try {
      MemoryOptimizer.smartCleanup();
      MemoryOptimizer.monitorMemory();
      
      // Record performance metric
      EnterprisePerformanceService.recordPerformanceMetric('memory_cleanup', 100.0);
    } catch (e) {
      print('❌ Memory cleanup failed: $e');
      BulletproofService.recordSecurityViolation('memory_cleanup', e.toString());
    }
  });

  // Set up advanced memory monitoring with enterprise protection
  Timer.periodic(const Duration(minutes: 1), (timer) {
    try {
      final stats = AdvancedMemoryOptimizer.getComprehensiveStats();
      if (stats['imageCache']['usagePercent'] > 80) {
        AdvancedMemoryOptimizer.emergencyCleanup();
        EnterprisePerformanceService.recordPerformanceMetric('emergency_cleanup', 500.0);
      }
    } catch (e) {
      print('❌ Advanced memory monitoring failed: $e');
      BulletproofService.recordSecurityViolation('memory_monitoring', e.toString());
    }
  });

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CartProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => OptimizedDataProvider()),
      ],
      child: MaterialApp(
        title: 'Food Marketplace',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: SplashWrapper(),
        routes: {
          '/home': (context) => SimpleHomeScreen(),
          '/login': (context) => LoginScreen(),
          '/cart': (context) => CartScreen(),
          '/order-history': (context) => OrderHistoryScreen(),
          '/profile': (context) => ProfileEditScreen(),
          '/admin-review-moderation': (context) => AdminReviewModerationScreen(),
          '/cache-management': (context) => CacheManagementScreen(),
          '/my-products': (context) => SellerProductManagement(),

        },
        onGenerateRoute: (settings) {
          // Handle routes with parameters
          if (settings.name == '/seller-order-detail') {
            final args = settings.arguments as Map<String, dynamic>?;
            final orderId = args?['orderId'] as String? ?? '';
            return MaterialPageRoute(
              builder: (context) => SellerOrderDetailScreen(orderId: orderId),
            );
          }
          if (settings.name == '/seller-orders') {
            final args = settings.arguments as Map<String, dynamic>?;
            final sellerId = args?['sellerId'] as String?;
            return MaterialPageRoute(
              builder: (context) => SellerOrdersListScreen(sellerId: sellerId),
            );
          }
          if (settings.name == '/checkout') {
            final args = settings.arguments as Map<String, dynamic>?;
            final totalPrice = args?['totalPrice'] as double? ?? 0.0;
            return MaterialPageRoute(
              builder: (context) => CheckoutScreen(totalPrice: totalPrice),
            );
          }
          if (settings.name == '/admin-route') {
            final args = settings.arguments as Map<String, dynamic>?;
            final child = args?['child'] as Widget?;
            return MaterialPageRoute(
              builder: (context) => AdminRoute(child: child ?? Container()),
            );
          }
          return null;
        },
      ),
    );
  }
}

class SplashWrapper extends StatefulWidget {
  @override
  _SplashWrapperState createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  @override
  void initState() {
    super.initState();
    // Navigate to home screen after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
            return SimpleSplashScreen();
  }
}
