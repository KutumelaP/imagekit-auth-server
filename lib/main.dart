import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/cart_provider.dart';
import 'providers/user_provider.dart';
import 'providers/optimized_provider.dart';
import 'services/notification_service.dart';
import 'services/error_tracking_service.dart';
import 'services/fcm_config_service.dart';
import 'services/awesome_notification_service.dart';
import 'services/navigation_service.dart';
import 'services/route_persistence_observer.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/security_settings_screen.dart';
import 'screens/KycUploadScreen.dart';
import 'screens/ChatRoute.dart';
import 'services/global_message_listener.dart';
import 'widgets/in_app_notification_widget.dart';
import 'widgets/notification_badge.dart';
import 'widgets/simple_splash_screen.dart';
import 'widgets/chatbot_widget.dart';

import 'screens/simple_home_screen.dart';
import 'screens/product_search_screen.dart';
import 'screens/login_screen.dart';
import 'screens/CartScreen.dart';
import 'screens/OrderHistoryScreen.dart';
import 'screens/ProfileEditScreen.dart';
import 'screens/AdminReviewModerationScreen.dart';
import 'screens/CacheManagementScreen.dart';
import 'screens/seller_product_management.dart';
import 'screens/SellerOrderDetailScreen.dart';
import 'screens/SellerOrdersListScreen.dart';
import 'screens/CheckoutScreen.dart';
import 'screens/AdminRoute.dart';
import 'screens/StoreProfileRouteLoader.dart';
import 'screens/MyStoresScreen.dart';
import 'screens/SellerPayoutsScreen.dart';

import 'dart:async';
import 'utils/safari_optimizer.dart';
import 'utils/web_memory_guard.dart';
import 'utils/performance_config.dart';
import 'services/optimized_location_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'utils/web_env.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // You can add background handling logic here if needed
  if (kDebugMode) print('🔔 Background message: ${message.messageId} data=${message.data}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize performance optimizations
  PerformanceConfig.initialize();
  SafariOptimizer.initialize();
  
  // Web-specific optimizations
  if (kIsWeb) {
    PerformanceConfig.optimizeForWeb();
    // Initialize guard to clear caches when hidden/backgrounded
    WebMemoryGuard().initialize();
  }
  
  // Initialize Firebase with options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Register background message handler before any messaging usage
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize notification service with reduced frequency for Safari
  await NotificationService().initialize();
  
  // Request notification permissions
  await NotificationService().requestPermissions();

  // Initialize FCM config service (token save, handlers)
  await FCMConfigService().initialize();

  // Initialize Awesome Notifications for local banners (mobile)
  await AwesomeNotificationService().initialize();
  
  // Initialize optimized location services (skip on iOS Safari web to avoid reloads)
  try {
    final skipLocationOnIOSWeb = WebEnv.isIOSWeb && !WebEnv.isStandalonePWA;
    if (!skipLocationOnIOSWeb) {
      // Warm up optimized location services for faster subsequent calls
      await OptimizedLocationService.warmUpLocationServices();
    } else {
      if (kDebugMode) print('🔍 DEBUG: Skipping location services on iOS Safari tab');
    }
  } catch (e) {
    if (kDebugMode) print('🔍 DEBUG: Error initializing location services: $e');
  }
  
  // Initialize error tracking
  ErrorTrackingService.initialize();
  
  // Initialize global message listener for notifications
  if (!kIsWeb) {
    await GlobalMessageListener().startListening();
  }
  
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
          navigatorKey: NavigationService.navigatorKey,
        navigatorObservers: [
          if (kDebugMode) _DebugNavigatorObserver(),
          RoutePersistenceObserver(),
        ],
        home: InAppNotificationWidget(
          child: NotificationBadge(
            child: ChatbotWrapper(
              child: SplashWrapper(),
            ),
          ),
        ),
        builder: (context, child) {
          // Global bottom SafeArea to avoid iPhone home indicator overlap
          final wrapped = SafeArea(
            top: false,
            bottom: true,
            minimum: const EdgeInsets.only(bottom: 34),
            child: child!,
          );
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: MediaQuery.of(context).viewInsets,
            ),
            child: wrapped,
          );
        },
        routes: {
          '/home': (context) => SimpleHomeScreen(),
          '/login': (context) => LoginScreen(),
          '/cart': (context) => CartScreen(),
          '/order-history': (context) => OrderHistoryScreen(),
          '/profile': (context) => ProfileEditScreen(),
          '/admin-review-moderation': (context) => AdminReviewModerationScreen(),
          '/cache-management': (context) => CacheManagementScreen(),
          '/my-products': (context) => SellerProductManagement(),
          '/notification-settings': (context) => const NotificationSettingsScreen(),
          '/security-settings': (context) => const SecuritySettingsScreen(),
          '/kyc': (context) => const KycUploadScreen(),
          '/my-stores': (context) => const MyStoresScreen(),
          '/seller-payouts': (context) => const SellerPayoutsScreen(),

        },
        onGenerateRoute: (settings) {
          // Handle routes with parameters
          // Shareable web URL: /store/:storeId
          if (settings.name != null && settings.name!.startsWith('/store/')) {
            final storeId = settings.name!.substring('/store/'.length);
            return MaterialPageRoute(
              builder: (_) => StoreProfileRouteLoader(storeId: storeId),
            );
          }
          if (settings.name == '/search') {
            return MaterialPageRoute(builder: (_) => const ProductSearchScreen());
          }
          if (settings.name == '/chat') {
            final args = settings.arguments as Map<String, dynamic>?;
            final chatId = args?['chatId'] as String?;
            // Remove automatic redirect - let the ChatRoute handle missing chatId
            return MaterialPageRoute(builder: (_) => ChatRoute(chatId: chatId ?? ''));
          }
          if (settings.name == '/seller-order-detail') {
            final args = settings.arguments as Map<String, dynamic>?;
            final orderId = args?['orderId'] as String?;
            if (kDebugMode) print('🔔 Route /seller-order-detail called with orderId: "$orderId" (type: ${orderId.runtimeType})');
            
            // Remove automatic redirect - let the screen handle missing orderId
            return MaterialPageRoute(
              builder: (context) => SellerOrderDetailScreen(orderId: orderId ?? ''),
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
    // Navigate to last route if available, else home
    Future.delayed(const Duration(seconds: 1), () async {
      if (!mounted) return;
      final last = await RoutePersistenceObserver.getLastRoute();
      final target = (last != null && last.isNotEmpty) ? last : '/home';
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SimpleSplashScreen();
  }
}

// Debug navigator observer to track all navigation events
class _DebugNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (kDebugMode) print("➡️ NAVIGATION: PUSH ${route.settings.name}");
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (kDebugMode) print("⬅️ NAVIGATION: POP ${route.settings.name}");
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (kDebugMode) print("🔄 NAVIGATION: REPLACE ${newRoute?.settings.name}");
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (kDebugMode) print("🗑️ NAVIGATION: REMOVE ${route.settings.name}");
  }
}
