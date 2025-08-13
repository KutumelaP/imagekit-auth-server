import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'widgets/admin_dashboard_content.dart';
import 'widgets/notification_panel.dart';
import 'services/real_time_notification_service.dart';
import 'utils/advanced_memory_optimizer.dart';
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
  
  // Navigation categories for better organization
  final List<NavigationCategory> _categories = [
    NavigationCategory(
      title: 'Overview',
      icon: Icons.dashboard,
      items: ['Overview', 'Quick Actions', 'Recent Activity'],
    ),
    NavigationCategory(
      title: 'Management',
      icon: Icons.manage_accounts,
      items: ['Users', 'Sellers', 'Orders', 'Categories'],
    ),
    NavigationCategory(
      title: 'Analytics',
      icon: Icons.analytics,
      items: ['Statistics', 'Reports', 'Advanced Analytics'],
    ),
    NavigationCategory(
      title: 'Operations',
      icon: Icons.shield,
      items: ['Moderation', 'Reviews', 'Returns/Refunds'],
    ),
    NavigationCategory(
      title: 'Settings',
      icon: Icons.settings,
      items: ['Platform Settings', 'Roles/Permissions', 'Audit Logs'],
    ),
    NavigationCategory(
      title: 'Financial',
      icon: Icons.account_balance,
      items: ['Payment Settings', 'Escrow Management', 'Returns Management'],
    ),
    NavigationCategory(
      title: 'Developer',
      icon: Icons.code,
      items: ['Developer Tools', 'Data Export', 'Order Migration'],
    ),
    NavigationCategory(
      title: 'Delivery',
      icon: Icons.delivery_dining,
      items: ['Rural Driver Management', 'Urban Delivery Management'],
    ),
    NavigationCategory(
      title: 'Driver Management',
      icon: Icons.person,
      items: ['Driver Management'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in to access the admin dashboard'),
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data?.data() == null) {
    return const Scaffold(
            body: Center(
              child: Text('User data not found. Please contact support.'),
            ),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final role = userData['role'];

        if (role != 'admin') {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Admin Access Required',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You do not have permission to access this dashboard.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          appBar: _buildAppBar(userData),
          drawer: MediaQuery.of(context).size.width < 1200 ? _buildMobileDrawer() : null,
          body: Stack(
            children: [
              Row(
                children: [
                  // Desktop Sidebar for larger screens
                  if (MediaQuery.of(context).size.width >= 1200)
                    Container(
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
                                    (userData['email'] ?? 'A')[0].toUpperCase(),
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
                                        userData['name'] ?? userData['email']?.split('@')[0] ?? 'Admin',
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
                    ),
                  
                  // Main Content
                  Expanded(
                    child: AdminDashboardContent(
                      adminEmail: user.email ?? '',
                      adminUid: user.uid,
                      auth: FirebaseAuth.instance,
                      firestore: FirebaseFirestore.instance,
                      selectedSection: _mapNavigationIndexToSectionIndex(_selectedIndex),
                      onSectionChanged: (index) => setState(() => _selectedIndex = _mapSectionIndexToNavigationIndex(index)),
                    ),
                  ),
                ],
              ),
              
              // Notification Panel Overlay
              if (_showNotificationPanel)
                Positioned(
                  top: 0,
                  right: 16,
                  child: NotificationPanel(
                    onClose: () => setState(() => _showNotificationPanel = false),
                  ),
                ),
            ],
          ),
        );
      },
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
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Admin Dashboard',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Management Panel',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _buildNavigationList()),
        ],
      ),
    );
  }

  Widget _buildNavigationList() {
    int itemIndex = 0;
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: _categories.length,
      itemBuilder: (context, categoryIndex) {
        final category = _categories[categoryIndex];
        final categoryStartIndex = itemIndex;
        
        final categoryWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (categoryIndex > 0) const SizedBox(height: 16),
            
            // Category Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    category.icon,
                    size: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            
            // Category Items
            ...category.items.map((item) {
              final currentItemIndex = itemIndex++;
              return _buildNavigationItem(
                title: item,
                index: currentItemIndex,
                isSelected: _selectedIndex == currentItemIndex,
              );
            }).toList(),
          ],
        );
        
        return categoryWidget;
      },
    );
  }

  int _mapNavigationIndexToSectionIndex(int navigationIndex) {
    // Map navigation indices to section indices
    // This maps the sequential navigation indices to the correct section indices
    switch (navigationIndex) {
      case 0: return 0;   // Overview
      case 1: return 1;   // Quick Actions
      case 2: return 2;   // Recent Activity
      case 3: return 3;   // Users
      case 4: return 4;   // Sellers
      case 5: return 5;   // Orders
      case 6: return 6;   // Categories
      case 7: return 7;   // Statistics
      case 8: return 8;   // Reports
      case 9: return 9;   // Advanced Analytics
      case 10: return 10; // Moderation
      case 11: return 11; // Reviews
      case 12: return 12; // Returns/Refunds
      case 13: return 13; // Platform Settings
      case 14: return 14; // Roles/Permissions
      case 15: return 15; // Audit Logs
      case 16: return 16; // Payment Settings
      case 17: return 17; // Escrow Management
      case 18: return 18; // Returns Management
      case 19: return 19; // Developer Tools
      case 20: return 20; // Data Export
      case 21: return 21; // Order Migration
      case 22: return 22; // Rural Driver Management
      case 23: return 23; // Urban Delivery Management
      case 24: return 24; // Driver Management
      default: return 0;
    }
  }

  int _mapSectionIndexToNavigationIndex(int sectionIndex) {
    // Map section indices back to navigation indices
    switch (sectionIndex) {
      case 0: return 0;   // Overview
      case 1: return 1;   // Quick Actions
      case 2: return 2;   // Recent Activity
      case 3: return 3;   // Users
      case 4: return 4;   // Sellers
      case 5: return 5;   // Orders
      case 6: return 6;   // Categories
      case 7: return 7;   // Statistics
      case 8: return 8;   // Reports
      case 9: return 9;   // Advanced Analytics
      case 10: return 10; // Moderation
      case 11: return 11; // Reviews
      case 12: return 12; // Returns/Refunds
      case 13: return 13; // Platform Settings
      case 14: return 14; // Roles/Permissions
      case 15: return 15; // Audit Logs
      case 16: return 16; // Payment Settings
      case 17: return 17; // Escrow Management
      case 18: return 18; // Returns Management
      case 19: return 19; // Developer Tools
      case 20: return 20; // Data Export
      case 21: return 21; // Order Migration
      case 22: return 22; // Rural Driver Management
      case 23: return 23; // Urban Delivery Management
      case 24: return 24; // Driver Management
      default: return 0;
    }
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
          setState(() => _selectedIndex = index);
          if (MediaQuery.of(context).size.width < 1200) {
            Navigator.of(context).pop(); // Close drawer on mobile
          }
        },
      ),
    );
  }
}

class NavigationCategory {
  final String title;
  final IconData icon;
  final List<String> items;

  NavigationCategory({
    required this.title,
    required this.icon,
    required this.items,
  });
} 
