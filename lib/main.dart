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
import 'screens/NotificationSettingsScreen.dart';
import 'screens/ChatRoute.dart';
import 'services/global_message_listener.dart';
import 'widgets/in_app_notification_widget.dart';
import 'widgets/notification_badge.dart';
import 'widgets/simple_splash_screen.dart';
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

import 'dart:async';
import 'utils/safari_optimizer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // You can add background handling logic here if needed
  print('🔔 Background message: ${message.messageId} data=${message.data}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Safari optimizations
  SafariOptimizer.initialize();
  
  // Safari-specific optimizations
  if (kIsWeb) {
    // Reduce memory pressure for Safari
    PaintingBinding.instance.imageCache.maximumSize = 200; // Reduced from default
    PaintingBinding.instance.imageCache.maximumSizeBytes = 25 << 20; // 25MB
    
    // Disable some features that cause issues in Safari
    debugPrintRebuildDirtyWidgets = false;
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
  
  // Initialize global message listener for notifications with reduced frequency
  if (!kIsWeb) { // Only start on mobile to reduce Safari memory pressure
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
        home: InAppNotificationWidget(
          child: NotificationBadge(
            child: SplashWrapper(),
          ),
        ),
        builder: (context, child) {
          // Handle keyboard properly to prevent blank page issues
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: MediaQuery.of(context).viewInsets,
            ),
            child: child!,
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
          '/my-stores': (context) => const MyStoresScreen(),
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
            if (chatId == null || chatId.isEmpty) {
              return MaterialPageRoute(builder: (_) => const SimpleHomeScreen());
            }
            return MaterialPageRoute(builder: (_) => ChatRoute(chatId: chatId));
          }
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
