import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'widgets/admin_dashboard_content.dart';
import 'widgets/notification_panel.dart';
import 'widgets/breeze_background.dart';
import 'services/real_time_notification_service.dart';
import 'utils/advanced_memory_optimizer.dart';
import 'theme/admin_theme.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize advanced memory optimization
  AdvancedMemoryOptimizer.initialize();
  
  // Set up advanced memory monitoring
  Timer.periodic(const Duration(minutes: 1), (timer) {
    try {
      final stats = AdvancedMemoryOptimizer.getComprehensiveStats();
      if (stats['imageCache']['usagePercent'] > 80) {
        AdvancedMemoryOptimizer.emergencyCleanup();
      }
    } catch (e) {
      print('❌ Advanced memory monitoring failed: $e');
    }
  });

  runApp(AdminDashboardApp());
}

class AdminDashboardApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AdminDashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final RealTimeNotificationService _notificationService = RealTimeNotificationService();
  bool _showNotificationPanel = false;

  @override
  void initState() {
    super.initState();
    _initializeNotificationService();
  }

  Future<void> _initializeNotificationService() async {
    try {
      await _notificationService.initialize(
        FirebaseFirestore.instance,
        FirebaseAuth.instance,
      );
    } catch (e) {
      debugPrint('Failed to initialize notification service: $e');
    }
  }

  @override
  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserData(),
      builder: (context, snapshot) {
        // Always show the layout structure, never mask with full-screen spinner
        if (snapshot.hasError) {
          return _buildErrorScreen(snapshot.error.toString());
        }

        final userData = snapshot.data ?? {};
        
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 768;
            final isTablet = constraints.maxWidth >= 768 && constraints.maxWidth < 1024;
            final isDesktop = constraints.maxWidth >= 1024;

            if (isMobile) {
              return _buildMobileLayout(userData, snapshot.connectionState);
            } else if (isTablet) {
              return _buildTabletLayout(userData, snapshot.connectionState);
            } else {
              return _buildDesktopLayout(userData, snapshot.connectionState);
            }
          },
        );
      },
    );
  }

  Widget _buildMobileLayout(Map<String, dynamic> userData, ConnectionState connectionState) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getCurrentSectionTitle()),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: AdminTheme.angel,
      ),
      drawer: _buildMobileDrawer(),
      body: _buildMainContent(userData, connectionState),
    );
  }

  Widget _buildTabletLayout(Map<String, dynamic> userData, ConnectionState connectionState) {
          return Scaffold(
      body: Row(
                children: [
          // Compact Sidebar
          Container(
            width: 60,
            color: Theme.of(context).colorScheme.primary,
            child: _buildCompactSidebar(),
          ),
          // Main Content
          Expanded(
            child: BreezeBackground(
              padding: const EdgeInsets.all(0),
              child: _buildMainContent(userData, connectionState),
                    ),
                  ),
                ],
            ),
          );
        }

  Widget _buildDesktopLayout(Map<String, dynamic> userData, ConnectionState connectionState) {
        return Scaffold(
      body: Row(
            children: [
          // Enhanced Sidebar
                    Container(
                      width: 220,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primary.withOpacity(0.8),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                  color: AdminTheme.deepTeal.withOpacity(0.1),
                  blurRadius: 10,
                            offset: const Offset(2, 0),
                          ),
                        ],
                      ),
            child: _buildEnhancedSidebar(userData),
          ),
          // Main Content
          Expanded(
            child: Container(
              color: Colors.transparent,
              child: BreezeBackground(
                padding: const EdgeInsets.all(0),
                child: _buildMainContent(userData, connectionState),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSidebar() {
    return Column(
                        children: [
        // Logo/Icon
                          Container(
                            padding: const EdgeInsets.all(16),
          child: Icon(
            Icons.admin_panel_settings,
            color: AdminTheme.angel,
            size: 28,
          ),
        ),
        Divider(color: AdminTheme.angel.withOpacity(0.2)),
        // Navigation Icons
        Expanded(
          child: ListView.builder(
            itemCount: _sections.length,
            itemBuilder: (context, index) {
              return Column(
                              children: [
                  // Navigation Icon
                                Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: IconButton(
                      icon: Icon(
                        _getIconForSection(index),
                        color: _selectedIndex == index 
                            ? AdminTheme.angel 
                            : AdminTheme.angel.withOpacity(0.8),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _selectedIndex = index);
                      },
                      tooltip: _sections[index],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // Helper method to get appropriate icons for each section
  IconData _getIconForSection(int index) {
    switch (index) {
      case 0: return Icons.trending_up; // Advanced Analytics
      case 1: return Icons.history; // Audit Logs
      case 2: return Icons.category; // Categories
      case 3: return Icons.cleaning_services; // Cleanup Tools
      case 4: return Icons.support_agent; // Customer Support
      case 5: return Icons.download; // Data Export
      case 6: return Icons.code; // Developer Tools
      case 7: return Icons.person; // Driver Management
      case 8: return Icons.account_balance; // Escrow Management
      case 9: return Icons.analytics; // Financial Overview
      case 10: return Icons.people_outline; // KYC Overview
      case 11: return Icons.verified_user; // KYC Review
      case 12: return Icons.shield; // Moderation
      case 13: return Icons.swap_horiz; // Order Migration
      case 14: return Icons.shopping_cart; // Orders
      case 15: return Icons.image_not_supported; // Orphaned Images
      case 16: return Icons.dashboard; // Overview
      case 17: return Icons.price_check; // PAXI Pricing Management
      case 18: return Icons.payment; // Payment Settings
      case 19: return Icons.account_balance_wallet; // Payouts
      case 20: return Icons.settings; // Platform Settings
      case 21: return Icons.flash_on; // Quick Actions
      case 22: return Icons.timeline; // Recent Activity
      case 23: return Icons.assessment; // Reports
      case 24: return Icons.assignment_returned; // Returns Management
      case 25: return Icons.assignment_return; // Returns/Refunds
      case 26: return Icons.rate_review; // Reviews
      case 27: return Icons.warning; // Risk Review
      case 28: return Icons.security; // Roles/Permissions
      case 29: return Icons.directions_car; // Rural Driver Management
      case 30: return Icons.delivery_dining; // Seller Delivery Management
      case 31: return Icons.store; // Sellers
      case 32: return Icons.analytics; // Statistics
      case 33: return Icons.storage; // Storage Stats
      case 34: return Icons.local_shipping; // Urban Delivery Management
      case 35: return Icons.people; // Users
      case 36: return Icons.upload_file; // Upload Management
      default: return Icons.dashboard;
    }
  }

  Widget _buildEnhancedSidebar(Map<String, dynamic> userData) {
    return Column(
      children: [
        // Admin Profile Header
        Container(
          padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: AdminTheme.angel.withOpacity(0.2),
                child: Icon(Icons.admin_panel_settings, size: 35, color: AdminTheme.angel),
              ),
              const SizedBox(height: 8),
                                      Text(
                                        'Admin Dashboard',
                style: TextStyle(
                  color: AdminTheme.angel,
                  fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                textAlign: TextAlign.center,
                                      ),
              const SizedBox(height: 2),
                                      Text(
                                        'Management Panel',
                style: TextStyle(
                  color: AdminTheme.angel.withOpacity(0.8),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminTheme.success,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Active',
                  style: TextStyle(
                    color: AdminTheme.angel,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                                  ),
                                ),
                              ],
                            ),
                          ),
        Divider(color: AdminTheme.angel.withOpacity(0.24)),
        // Navigation Items
                          Expanded(
                            child: _buildNavigationList(),
                          ),
        // Admin Profile Footer
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
            color: AdminTheme.angel.withOpacity(0.05),
                              border: Border(
                                top: BorderSide(
                color: AdminTheme.angel.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                backgroundColor: AdminTheme.angel.withOpacity(0.2),
                                  child: Text(
                                    (userData['email'] ?? 'A')[0].toUpperCase(),
                                    style: TextStyle(
                    color: AdminTheme.angel,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        userData['name'] ?? userData['email']?.split('@')[0] ?? 'Admin',
                      style: TextStyle(
                        color: AdminTheme.angel,
                                          fontWeight: FontWeight.w600,
                        fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Administrator',
                      style: TextStyle(
                        color: AdminTheme.angel.withOpacity(0.7),
                        fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert,
                  color: AdminTheme.angel.withOpacity(0.8),
                                  ),
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'profile',
                                      child: ListTile(
                                        leading: Icon(Icons.person_outline),
                                        title: Text('Profile Settings'),
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'logout',
                                      child: ListTile(
                                        leading: Icon(Icons.logout),
                                        title: Text('Logout'),
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) async {
                                    if (value == 'logout') {
                                      await FirebaseAuth.instance.signOut();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
    );
  }

  String _getCurrentSectionTitle() {
    // Get the current section title based on selected index
    if (_selectedIndex < _sections.length) {
      return _sections[_selectedIndex];
    }
    return 'Admin Dashboard';
  }

  Widget _buildMainContent(Map<String, dynamic> userData, ConnectionState connectionState) {
    print('🎯 _buildMainContent called with _selectedIndex: $_selectedIndex');
    
    // Show loading state only within the content area, not masking the whole screen
    if (connectionState == ConnectionState.waiting) {
      return _buildContentLoadingState();
    }

    // Content is loaded, show the actual dashboard
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _buildErrorScreen('User not authenticated');
    
    return Padding(
      padding: const EdgeInsets.all(24),
                    child: AdminDashboardContent(
                      adminEmail: user.email ?? '',
                      adminUid: user.uid,
                      auth: FirebaseAuth.instance,
                      firestore: FirebaseFirestore.instance,
        selectedSection: _selectedIndex,
        onSectionChanged: (index) => setState(() => _selectedIndex = index),
        embedded: true,
      ),
    );
  }

  Widget _buildContentLoadingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 300,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ],
              ),
          const SizedBox(height: 32),
          
          // Stats grid skeleton
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 5,
            crossAxisSpacing: 16,
            childAspectRatio: 2.5,
            children: List.generate(5, (index) => Container(
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
            )),
          ),
          const SizedBox(height: 32),
          
          // Content skeleton
          Container(
            width: double.infinity,
            height: 400,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
                  ),
                ),
            ],
          ),
    );
  }

  PreferredSizeWidget _buildAppBar(Map<String, dynamic> userData) {
    return AppBar(
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Admin Dashboard',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Marketplace Management',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Real-time notifications
        AnimatedBuilder(
          animation: _notificationService,
          builder: (context, child) {
            return IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_outlined),
                  if (_notificationService.unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          _notificationService.unreadCount > 99 ? '99+' : '${_notificationService.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () => setState(() => _showNotificationPanel = !_showNotificationPanel),
              tooltip: 'Notifications (${_notificationService.unreadCount} unread)',
            );
          },
        ),
        
        // Admin profile
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: PopupMenuButton<String>(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    (userData['email'] ?? 'A')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  userData['email']?.split('@')[0] ?? 'Admin',
                  style: const TextStyle(color: Colors.white),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white),
              ],
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Profile Settings'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                  dense: true,
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'logout') {
                await FirebaseAuth.instance.signOut();
              }
            },
          ),
        ),
      ],
    );
  }


  Widget _buildMobileDrawer() {
    return Drawer(
      child: Container(
        color: Theme.of(context).colorScheme.primary,
        child: SafeArea(
      child: Column(
        children: [
              // Admin Profile Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AdminTheme.angel.withOpacity(0.2),
                      child: Icon(Icons.admin_panel_settings, size: 40, color: AdminTheme.angel),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Admin Dashboard',
                      style: TextStyle(
                        color: AdminTheme.angel,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Management Panel',
                      style: TextStyle(
                        color: AdminTheme.angel.withOpacity(0.8),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Divider(color: AdminTheme.angel.withOpacity(0.24)),
              // Navigation Items
              Expanded(
                child: _buildNavigationList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar(Map<String, dynamic> userData) {
    return Container(
      width: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
                colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.9),
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Sidebar Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Dashboard',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                          color: Colors.white,
                      ),
                    ),
                    Text(
                      'Management Panel',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                  ),
                ),
              ],
            ),
          ),
          
          // Navigation Categories
          Expanded(
            child: _buildNavigationList(),
          ),
          
          // Sidebar Footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
              child: Row(
                children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    (userData?['email'] ?? 'A')[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Text(
                        userData?['name'] ?? userData?['email']?.split('@')[0] ?? 'Admin',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Administrator',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'profile',
                      child: ListTile(
                        leading: Icon(Icons.person_outline),
                        title: Text('Profile Settings'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: ListTile(
                        leading: Icon(Icons.logout),
                        title: Text('Logout'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  onSelected: (value) async {
                    if (value == 'logout') {
                      await FirebaseAuth.instance.signOut();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPanel() {
    return Positioned(
      top: 0,
      right: 16,
      child: NotificationPanel(
        onClose: () => setState(() => _showNotificationPanel = false),
      ),
    );
  }

  Widget _buildNavigationList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: _sections.length,
      itemBuilder: (context, index) {
        return _buildNavigationItem(
          title: _sections[index],
          index: index,
          isSelected: _selectedIndex == index,
        );
      },
    );
  }

  Widget _buildNavigationItem({
    required String title,
    required int index,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected 
                ? Colors.white
                : Colors.white.withOpacity(0.8),
          ),
        ),
        selected: isSelected,
        selectedTileColor: Colors.white.withOpacity(0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        dense: true,
        onTap: () {
          print('🎯 Navigation item tapped: $title (index: $index)');
          print('🎯 Previous selected index: $_selectedIndex');
          setState(() => _selectedIndex = index);
          print('🎯 New selected index: $_selectedIndex');
          if (MediaQuery.of(context).size.width < 1200) {
            Navigator.of(context).pop(); // Close drawer on mobile
          }
        },
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AdminTheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load dashboard',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: AdminTheme.mediumGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // Add the missing _getUserData method
  Future<Map<String, dynamic>> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!userDoc.exists || userDoc.data() == null) {
      throw Exception('User data not found');
    }

    final userData = userDoc.data() as Map<String, dynamic>;
    final role = userData['role'];

    if (role != 'admin') {
      throw Exception('Admin access required');
    }

    return userData;
  }

  // Add the sections list to match AdminDashboardContent
  final List<String> _sections = [
    'Advanced Analytics',
    'Audit Logs',
    'Categories',
    'Cleanup Tools',
    'Customer Support',
    'Data Export',
    'Developer Tools',
    'Driver Management',
    'Escrow Management',
    'Financial Overview',
    'KYC Overview',
    'KYC Review',
    'Moderation',
    'Order Migration',
    'Orders',
    'Orphaned Images',
    'Overview',
    'PAXI Pricing Management',
    'Payment Settings',
    'Payouts',
    'Platform Settings',
    'Quick Actions',
    'Recent Activity',
    'Reports',
    'Returns Management',
    'Returns/Refunds',
    'Reviews',
    'Risk Review',
    'Roles/Permissions',
    'Rural Driver Management',
    'Seller Delivery Management',
    'Sellers',
    'Statistics',
    'Storage Stats',
    'Urban Delivery Management',
    'Users',
    'Upload Management',
  ];
} 
