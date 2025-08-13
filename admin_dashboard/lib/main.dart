import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_dashboard_screen.dart';
import 'firebase_options.dart';
import 'SellerOrderDetailScreen.dart';
import 'widgets/admin_dashboard_content.dart';
import 'widgets/modern_seller_dashboard_section.dart';
import 'services/notification_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'theme/admin_theme.dart';

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AdminNotificationService().initialize();
  
  // Refresh notifications to clean up stale data
  await AdminNotificationService().validateAndCleanupNotifications();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Admin Dashboard',
          builder: (context, child) {
            return child!;
          },
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: AdminTheme.deepTeal,
            scaffoldBackgroundColor: AdminTheme.whisper, // Use Whisper as scaffold background
            cardColor: AdminTheme.angel, // Use Angel as card background
            colorScheme: ColorScheme(
              brightness: Brightness.light,
              primary: AdminTheme.deepTeal,
              onPrimary: AdminTheme.angel,
              secondary: AdminTheme.cloud,
              onSecondary: AdminTheme.deepTeal,
              tertiary: AdminTheme.breeze,
              onTertiary: AdminTheme.deepTeal,
              surface: AdminTheme.angel, // Use Angel as surface
              onSurface: AdminTheme.deepTeal,
              background: AdminTheme.whisper, // Use Whisper as background
              onBackground: AdminTheme.deepTeal,
              error: AdminTheme.error,
              onError: AdminTheme.angel,
              surfaceVariant: AdminTheme.angel, // Use Angel as surface variant
              onSurfaceVariant: AdminTheme.darkGrey,
              outline: AdminTheme.indigo,
              outlineVariant: AdminTheme.silverGray,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: AdminTheme.deepTeal,
              foregroundColor: AdminTheme.angel,
              elevation: 0,
              titleTextStyle: AdminTheme.headlineMedium.copyWith(color: AdminTheme.angel),
              iconTheme: IconThemeData(color: AdminTheme.angel),
              actionsIconTheme: IconThemeData(color: AdminTheme.angel),
            ),
            textTheme: TextTheme(
              displayLarge: AdminTheme.displayLarge,
              displayMedium: AdminTheme.displayMedium,
              displaySmall: AdminTheme.displaySmall,
              headlineLarge: AdminTheme.headlineLarge,
              headlineMedium: AdminTheme.headlineMedium,
              headlineSmall: AdminTheme.headlineSmall,
              titleLarge: AdminTheme.titleLarge,
              titleMedium: AdminTheme.titleMedium,
              titleSmall: AdminTheme.titleSmall,
              bodyLarge: AdminTheme.bodyLarge,
              bodyMedium: AdminTheme.bodyMedium,
              bodySmall: AdminTheme.bodySmall,
              labelLarge: AdminTheme.labelLarge,
              labelMedium: AdminTheme.labelMedium,
              labelSmall: AdminTheme.labelSmall,
            ),
            cardTheme: CardThemeData(
              color: AdminTheme.angel, // Use Angel for all cards
              elevation: AdminTheme.complementaryElevation,
              shadowColor: AdminTheme.complementaryGlow.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: AdminTheme.angel, // Use Angel for input backgrounds
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AdminTheme.cloud.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AdminTheme.cloud.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AdminTheme.deepTeal, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AdminTheme.error, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AdminTheme.error, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              labelStyle: AdminTheme.bodyMedium.copyWith(color: AdminTheme.cloud),
              hintStyle: AdminTheme.bodyMedium.copyWith(color: AdminTheme.breeze),
              prefixIconColor: AdminTheme.cloud,
              suffixIconColor: AdminTheme.cloud,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.deepTeal,
                foregroundColor: AdminTheme.angel,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: AdminTheme.labelLarge,
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminTheme.deepTeal,
                side: BorderSide(color: AdminTheme.deepTeal),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: AdminTheme.labelLarge,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AdminTheme.deepTeal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                textStyle: AdminTheme.labelLarge,
              ),
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              backgroundColor: AdminTheme.deepTeal,
              foregroundColor: AdminTheme.angel,
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: AdminTheme.angel, // Use Angel for bottom nav
              selectedItemColor: AdminTheme.deepTeal,
              unselectedItemColor: AdminTheme.mediumGrey,
              type: BottomNavigationBarType.fixed,
              elevation: 8,
            ),
            chipTheme: ChipThemeData(
              backgroundColor: AdminTheme.cloud,
              selectedColor: AdminTheme.deepTeal,
              disabledColor: AdminTheme.lightGrey,
              labelStyle: AdminTheme.labelMedium,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            dividerTheme: DividerThemeData(
              color: AdminTheme.silverGray,
              thickness: 1,
              space: 1,
            ),
            iconTheme: IconThemeData(
              color: AdminTheme.deepTeal,
              size: 24,
            ),
            primaryIconTheme: IconThemeData(
              color: AdminTheme.deepTeal,
              size: 24,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: AdminTheme.angel, // Use Angel for dialogs
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titleTextStyle: AdminTheme.headlineMedium,
              contentTextStyle: AdminTheme.bodyMedium,
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: AdminTheme.deepTeal,
              contentTextStyle: AdminTheme.bodyMedium.copyWith(color: AdminTheme.angel),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              behavior: SnackBarBehavior.floating,
            ),
            progressIndicatorTheme: ProgressIndicatorThemeData(
              color: AdminTheme.deepTeal,
              linearTrackColor: AdminTheme.cloud,
              circularTrackColor: AdminTheme.cloud,
            ),
            switchTheme: SwitchThemeData(
              thumbColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return AdminTheme.deepTeal;
                }
                return AdminTheme.silverGray;
              }),
              trackColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return AdminTheme.deepTeal.withOpacity(0.5);
                }
                return AdminTheme.cloud;
              }),
            ),
            checkboxTheme: CheckboxThemeData(
              fillColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return AdminTheme.deepTeal;
                }
                return Colors.transparent;
              }),
              checkColor: MaterialStateProperty.all(AdminTheme.angel),
              side: BorderSide(color: AdminTheme.deepTeal),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            radioTheme: RadioThemeData(
              fillColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return AdminTheme.deepTeal;
                }
                return AdminTheme.silverGray;
              }),
            ),
          ),
          home: AuthGate(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) {
          return const PlatformLoginScreen();
        }
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .get()
              .timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('Timed out fetching user document.')),
          builder: (context, userSnapshot) {
            if (userSnapshot.hasError) {
              return Scaffold(body: Center(child: Text('Error: ${userSnapshot.error}')));
            }
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (!userSnapshot.hasData || userSnapshot.data == null || userSnapshot.data!.data() == null) {
              return const Scaffold(body: Center(child: Text('User document not found. Please contact support.')));
            }
            final data = userSnapshot.data!.data() as Map<String, dynamic>?;
            final role = data?['role'];
            final subRole = data?['subRole'];
            if (role == null) {
              return const Scaffold(body: Center(child: Text('No role found for user. Please contact support.')));
            }
            if (role == 'seller') {
              return ModernSellerDashboardSection();
            } else if (role == 'admin') {
              return AdminDashboardScreen();
            } else {
              return Scaffold(body: Center(child: Text('Unauthorized: You do not have access. Role:  $role')));
            }
          },
        );
      },
    );
  }
}

class PlatformLoginScreen extends StatefulWidget {
  const PlatformLoginScreen({super.key});
  @override
  State<PlatformLoginScreen> createState() => _PlatformLoginScreenState();
}

class _PlatformLoginScreenState extends State<PlatformLoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool showPassword = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final cardGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF1F4654), // Deep Teal
        Color(0xFFA6C9D2), // Breeze
        Color(0xFFF2F7F9), // Angel
      ],
      stops: [0.0, 0.6, 1.0],
    );
    return Scaffold(
      body: Center(
        child: Container(
          width: 350,
          decoration: BoxDecoration(
            gradient: cardGradient,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
                blurRadius: 32,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Soft white overlay for extra softness
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 36, horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Container(
                      height: 96,
                      width: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Mzansi Marketplace',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Welcome back! Please sign in to continue.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    SizedBox(height: 32),
                    TextField(
                      controller: emailController,
                      style: TextStyle(color: Color(0xFF1F4654)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFF2F7F9), // Angel
                        labelText: 'Email',
                        labelStyle: TextStyle(color: Color(0xFF1F4654)),
                        hintText: 'Enter your email',
                        hintStyle: TextStyle(color: Color(0xFF1F4654).withOpacity(0.7)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF1F4654).withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF1F4654), width: 2),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: !showPassword,
                      style: TextStyle(color: Color(0xFF1F4654)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFF2F7F9), // Angel
                        labelText: 'Password',
                        labelStyle: TextStyle(color: Color(0xFF1F4654)),
                        hintText: 'Enter your password',
                        hintStyle: TextStyle(color: Color(0xFF1F4654).withOpacity(0.7)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF1F4654).withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF1F4654), width: 2),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off, color: Color(0xFF1F4654).withOpacity(0.7)),
                          onPressed: () => setState(() => showPassword = !showPassword),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: loading
                            ? null
                            : () async {
                                setState(() {
                                  loading = true;
                                  error = null;
                                });
                                try {
                                  await FirebaseAuth.instance.signInWithEmailAndPassword(
                                    email: emailController.text.trim(),
                                    password: passwordController.text,
                                  );
                                } catch (e) {
                                  setState(() {
                                    error = 'Login failed: Invalid credentials or network error.';
                                  });
                                } finally {
                                  setState(() => loading = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          shape: StadiumBorder(),
                          elevation: 0,
                          backgroundColor: Colors.white,
                          foregroundColor: Color(0xFF1F4654), // Deep Teal
                        ),
                        child: loading
                            ? const CircularProgressIndicator(color: Color(0xFF1F4654))
                            : Text('Log in', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Color(0xFF1F4654))),
                      ),
                    ),
                    if (error != null)
                      AnimatedOpacity(
                        opacity: 1,
                        duration: const Duration(milliseconds: 300),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
