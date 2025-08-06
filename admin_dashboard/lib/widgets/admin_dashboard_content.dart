import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
// import 'package:universal_html/html.dart' as html; // Not needed for current functionality
import '../SellerOrderDetailScreen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'user_management_table.dart';
import 'seller_management_table.dart';
import 'order_management_table.dart';
import 'moderation_center.dart';
import 'platform_settings_section.dart';
import '../../main.dart';
import 'package:admin_dashboard/widgets/quick_actions_bar.dart';
import 'package:admin_dashboard/widgets/section_header.dart';
import 'package:admin_dashboard/widgets/dashboard_stats_grid.dart';

import 'package:admin_dashboard/widgets/analytics_trends_card.dart';
import 'package:admin_dashboard/widgets/recent_activity_feed.dart';
import 'statistics_section.dart';
import 'reviews_section.dart';
import 'products_section.dart';
import 'categories_section.dart';
import 'audit_logs_section.dart';
import 'developer_tools_section.dart';
import 'advanced_analytics_section.dart';
import 'summary_card.dart';
import '../services/dashboard_cache_service.dart';
import 'skeleton_loading.dart';
import 'advanced_analytics_dashboard.dart';
import '../theme/admin_theme.dart';
import 'order_migration_screen.dart';
import 'rural_driver_management.dart';
import 'urban_delivery_management.dart';
import 'payment_settings_management.dart';
import 'escrow_management.dart';
import 'returns_management.dart';
import 'driver_management_screen.dart';
import 'reports_section.dart';
import 'data_export_section.dart';
import 'roles_permissions_section.dart';
import 'seller_delivery_management.dart';

class AdminDashboardContent extends StatefulWidget {
  final String adminEmail;
  final String adminUid;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final int selectedSection;
  final ValueChanged<int> onSectionChanged;
  
  const AdminDashboardContent({
    required this.adminEmail, 
    required this.adminUid, 
    required this.auth,
    required this.firestore,
    required this.selectedSection,
    required this.onSectionChanged,
  });

  @override
  State<AdminDashboardContent> createState() => _AdminDashboardContentState();
}

class _AdminDashboardContentState extends State<AdminDashboardContent> {
  final DashboardCacheService _cacheService = DashboardCacheService();
  
  final List<String> _sections = [
    'Overview',
    'Quick Actions', 
    'Recent Activity',
    'Users',
    'Sellers', 
    'Orders',
    'Categories',
    'Statistics',
    'Reports',
    'Advanced Analytics',
    'Moderation',
    'Reviews',
    'Returns/Refunds',
    'Platform Settings',
    'Roles/Permissions',
    'Audit Logs',
    'Payment Settings',
    'Escrow Management',
    'Returns Management',
    'Developer Tools',
    'Data Export',
    'Order Migration',
    'Rural Driver Management',
    'Urban Delivery Management',
    'Driver Management',
    'Seller Delivery Management',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-load dashboard data
    _preloadDashboardData();
  }

  Future<void> _preloadDashboardData() async {
    try {
      await Future.wait([
        _cacheService.getDashboardStats(widget.firestore),
        _cacheService.getRecentActivity(widget.firestore),
      ]);
    } catch (error) {
      debugPrint('Error preloading dashboard data: $error');
    }
  }

  void _onSidebarTap(int index) {
    widget.onSectionChanged(index);
  }

  Future<int> _getUserCount() async {
    final users = await widget.firestore.collection('users').get();
    return users.docs.length;
  }
  Future<int> _getSellerCount() async {
    final sellers = await widget.firestore.collection('users').where('role', isEqualTo: 'seller').get();
    return sellers.docs.length;
  }
  Future<double> _getTotalPlatformFees() async {
    final orders = await widget.firestore.collection('orders').get();
    double total = 0;
    for (var doc in orders.docs) {
      total += (doc.data()['platformFee'] ?? 0.0) as double;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final allowedSections = <int>{...List.generate(_sections.length, (i) => i)};

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth < 900 && constraints.maxWidth >= 600;
        final sidebarWidth = 0.0;
        final contentPadding = isMobile ? 4.0 : isTablet ? 8.0 : 24.0;
        if (isMobile) {
          // Mobile: Use Drawer for navigation, AppBar for top actions
    return Scaffold(
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              title: Text('Dashboard', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _NotificationBell(),
                ),
              ],
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
            drawer: Drawer(
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
            child: Column(
                        children: [
                          CircleAvatar(radius: 32, backgroundColor: Theme.of(context).colorScheme.surface, child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary, size: 36)),
                          const SizedBox(height: 12),
                          Text(widget.adminEmail, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                    ),
                    ...List.generate(_sections.length, (i) =>
                      allowedSections.contains(i)
                        ? ListTile(
                            leading: _sidebarIconForIndex(i),
                            title: Text(_sections[i], style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: widget.selectedSection == i ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface)),
                            selected: widget.selectedSection == i,
                            selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.18),
                            hoverColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.12),
                            onTap: () {
                              Navigator.pop(context);
                              _onSidebarTap(i);
                            },
                          )
                        : const SizedBox.shrink(),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Logout'),
                      onTap: () async {
                        await widget.auth.signOut();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const PlatformLoginScreen()),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            body: Padding(
              padding: EdgeInsets.all(contentPadding),
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 350),
                transitionBuilder: (child, animation) {
                  final fade = FadeTransition(opacity: animation, child: child);
                  final slide = SlideTransition(
                    position: Tween<Offset>(begin: Offset(0.05, 0), end: Offset.zero).animate(animation),
                    child: fade,
                  );
                  return slide;
                },
                child: Container(
                  key: ValueKey(widget.selectedSection),
                                  child: _sectionWidget(widget.selectedSection),
                ),
              ),
            ),
          );
        } else {
          // Desktop/Tablet: Always use a Scaffold to apply background color
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sidebar
                Container(
                  width: sidebarWidth,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.background,
                      ],
                    ),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 32),
                          // Avatar/logo
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            backgroundImage: AssetImage('assets/logo.png'),
                          ),
                          const SizedBox(height: 18),
                          // Admin email
                          Text(
                            widget.adminEmail,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 17),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          _NotificationBell(),
                          const SizedBox(height: 24),
                          // Navigation
                          ...List.generate(_sections.length, (i) =>
                            allowedSections.contains(i)
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () => _onSidebarTap(i),
                                      child: AnimatedContainer(
                                        duration: Duration(milliseconds: 200),
                                        curve: Curves.easeInOut,
                                        decoration: BoxDecoration(
                                          color: widget.selectedSection == i ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.12) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  child: Row(
                    children: [
                                            _sidebarIconForIndex(i),
                                            const SizedBox(width: 14),
                                            Flexible(
                                              child: Text(
                                                _sections[i],
                                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontSize: 15, fontWeight: widget.selectedSection == i ? FontWeight.bold : FontWeight.normal),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 24),
                          IconButton(
                            icon: Icon(Icons.logout, color: AdminTheme.angel),
                            tooltip: 'Logout',
                            onPressed: () async {
                              await widget.auth.signOut();
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const PlatformLoginScreen()),
                                (route) => false,
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                // Main content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(contentPadding),
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) {
                        final fade = FadeTransition(opacity: animation, child: child);
                        final slide = SlideTransition(
                          position: Tween<Offset>(begin: Offset(0.05, 0), end: Offset.zero).animate(animation),
                          child: fade,
                        );
                        return slide;
                      },
                      child: Container(
                        key: ValueKey(widget.selectedSection),
                        child: allowedSections.contains(widget.selectedSection)
                          ? SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        FutureBuilder<int>(
                                          future: _getUserCount(),
                                          builder: (context, snapshot) => SummaryCard(
                                            label: 'Total Users',
                                            value: snapshot.hasData ? snapshot.data.toString() : '...',
                                            icon: Icons.people,
                                          ),
                                        ),
                                        SizedBox(width: 24),
                                        FutureBuilder<int>(
                                          future: _getSellerCount(),
                                          builder: (context, snapshot) => SummaryCard(
                                            label: 'Total Sellers',
                                            value: snapshot.hasData ? snapshot.data.toString() : '...',
                                            icon: Icons.verified_user,
                                          ),
                                        ),
                                        SizedBox(width: 24),
                                        FutureBuilder<double>(
                                          future: _getTotalPlatformFees(),
                                          builder: (context, snapshot) => SummaryCard(
                                            label: 'Platform Fee Revenue',
                                            value: snapshot.hasData ? 'R${snapshot.data!.toStringAsFixed(2)}' : '...',
                                            icon: Icons.receipt,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 24),
                                                                  _sectionWidget(widget.selectedSection),
                                ],
                              ),
                            )
                          : const Center(child: Text('Access Denied')),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _sectionWidget(int i) {
    switch (i) {
      case 0: return _buildDashboardOverview(); // Dashboard
      case 1: return _buildQuickActions(); // Quick Actions
      case 2: return _buildRecentActivity(); // Recent Activity
      case 3: // Users
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SectionHeader('User Management'),
              const SizedBox(height: 8),
              SizedBox(height: 500, child: UserManagementTable(auth: widget.auth, firestore: widget.firestore)),
            ],
          ),
        );
      case 4: // Sellers
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SectionHeader('Seller Management'),
              const SizedBox(height: 8),
              SizedBox(height: 500, child: SellerManagementTable(auth: widget.auth, firestore: widget.firestore)),
            ],
          ),
        );
      case 5: // Orders
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SectionHeader('Order Management'),
              const SizedBox(height: 8),
              SizedBox(height: 500, child: OrderManagementTable()),
            ],
          ),
        );
      case 6: return CategoriesSection(firestore: FirebaseFirestore.instance); // Categories
      case 7: return SingleChildScrollView(child: StatisticsSection()); // Statistics
      case 8: return ReportsSection(); // Reports
      case 9: return SingleChildScrollView(child: AdvancedAnalyticsDashboard(firestore: widget.firestore)); // Advanced Analytics
      case 10: return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [SectionHeader('Moderation Center'), const SizedBox(height: 8), ModerationCenter(auth: widget.auth, firestore: widget.firestore)])); // Moderation
      case 11: return SingleChildScrollView(child: ReviewsSection()); // Reviews
              case 12: return ReturnsManagement(); // Returns/Refunds
      case 13: return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [SectionHeader('Platform Settings'), const SizedBox(height: 8), PlatformSettingsSection(auth: widget.auth, firestore: widget.firestore)])); // Platform Settings
      case 14: return RolesPermissionsSection(); // Roles/Permissions
      case 15: return AuditLogsSection(); // Audit Logs
      case 16: return PaymentSettingsManagement(); // Payment Settings
      case 17: return EscrowManagement(); // Escrow Management
      case 18: return ReturnsManagement(); // Returns Management
      case 19: return DeveloperToolsSection(); // Developer Tools
      case 20: return DataExportSection(); // Data Export
      case 21: return const OrderMigrationScreen(); // Order Migration
      case 22: return RuralDriverManagement(); // Rural Driver Management
      case 23: return UrbanDeliveryManagement(); // Urban Delivery Management
      case 24: return DriverManagementScreen(); // Driver Management
      case 25: return SellerDeliveryManagement(); // Seller Delivery Management
      default: return const SizedBox();
    }
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Perform common administrative tasks with one click',
            style: TextStyle(
              color: AdminTheme.mediumGrey,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          _buildQuickActionsGrid(),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Platform Activity',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Real-time updates from your marketplace',
            style: TextStyle(
              color: AdminTheme.mediumGrey,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildActivityFeed(),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _buildStatsGrid()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1F4654), Color(0xFF7FB2BF)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to Admin Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.angel,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Monitor and manage your marketplace platform',
                        style: TextStyle(
                          color: AdminTheme.angel.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.dashboard,
                  size: 48,
                                          color: AdminTheme.angel.withOpacity(0.8),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Stats Grid
          _buildStatsGrid(),
          const SizedBox(height: 24),
          
          // Charts and Activity Row
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1000) {
                // Desktop: Side by side
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildRevenueChart(),
                    ),
                    const SizedBox(width: 16),
                Expanded(
                      child: _buildActivityFeed(),
                    ),
                  ],
                );
              } else {
                // Mobile/Tablet: Stacked
                return Column(
                  children: [
                    _buildRevenueChart(),
                    const SizedBox(height: 16),
                    _buildActivityFeed(),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),
          
          // Quick Actions
          _buildQuickActionsGrid(),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return FutureBuilder<DashboardStats>(
      future: _cacheService.getDashboardStats(widget.firestore),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _cacheService.cachedStats == null) {
          return LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount;
              double childAspectRatio;
              
              if (constraints.maxWidth > 1200) {
                crossAxisCount = 4;
                childAspectRatio = 2.0;
              } else if (constraints.maxWidth > 800) {
                crossAxisCount = 3;
                childAspectRatio = 1.8;
              } else if (constraints.maxWidth > 600) {
                crossAxisCount = 2;
                childAspectRatio = 1.6;
              } else {
                crossAxisCount = 1;
                childAspectRatio = 1.4;
              }

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: List.generate(4, (index) => 
                  SkeletonLoading(
                    isLoading: true,
                    child: SkeletonStatCard(),
                  ),
                ),
              );
            },
          );
        }

        final stats = snapshot.data ?? _cacheService.cachedStats;
        if (stats == null) {
          return _buildErrorCard('Failed to load stats');
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount;
            double childAspectRatio;
            
            if (constraints.maxWidth > 1200) {
              crossAxisCount = 4;
              childAspectRatio = 2.0;
            } else if (constraints.maxWidth > 800) {
              crossAxisCount = 3;
              childAspectRatio = 1.8;
            } else if (constraints.maxWidth > 600) {
              crossAxisCount = 2;
              childAspectRatio = 1.6;
            } else {
              crossAxisCount = 1;
              childAspectRatio = 1.4;
            }

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
          children: [
            _buildStatCard(
              'Total Users',
              stats.totalUsers.toString(),
              Icons.people,
              AdminTheme.info,
              isLoading: _cacheService.isLoadingStats,
              growth: stats.userGrowth,
            ),
            _buildStatCard(
              'Today\'s Orders',
              stats.todayOrders.toString(),
              Icons.shopping_cart,
              AdminTheme.success,
              isLoading: _cacheService.isLoadingStats,
              growth: stats.orderGrowth,
            ),
            _buildStatCard(
              'Platform Revenue',
              'R${stats.totalRevenue.toStringAsFixed(2)}',
              Icons.receipt,
              AdminTheme.indigo,
              isLoading: _cacheService.isLoadingStats,
              growth: stats.revenueGrowth,
            ),
            _buildStatCard(
              'Pending Approvals',
              stats.pendingApprovals.toString(),
              Icons.pending_actions,
              stats.hasHighPendingApprovals ? AdminTheme.error : AdminTheme.warning,
              isLoading: _cacheService.isLoadingStats,
              growth: null, // No growth for pending items
            ),
          ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool isLoading = false, double? growth}) {
    return SkeletonLoading(
      isLoading: isLoading,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AdminTheme.cardDecoration(
          color: AdminTheme.angel,
          boxShadow: [
            BoxShadow(
              color: AdminTheme.indigo.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (growth != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                      color: AdminTheme.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up, color: AdminTheme.success, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          '${growth.toStringAsFixed(1)}%',
                          style: AdminTheme.labelSmall.copyWith(
                            color: AdminTheme.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: AdminTheme.displaySmall.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: AdminTheme.bodyMedium.copyWith(
                color: AdminTheme.darkGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.cardDecoration(
        color: AdminTheme.angel,
        boxShadow: [
          BoxShadow(
            color: AdminTheme.indigo.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Revenue Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AdminTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+12.5%',
                  style: TextStyle(
                    color: AdminTheme.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: widget.firestore.collection('orders').get(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF1F4654).withOpacity(0.1),
                          Color(0xFF1F4654).withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 48,
                            color: Color(0xFF1F4654),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Revenue Trending Up',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F4654),
                            ),
                          ),
                          Text(
                            '${snapshot.data!.docs.length} total orders',
                            style: TextStyle(color: AdminTheme.mediumGrey),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Center(child: CircularProgressIndicator());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeed() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () async {
                  await _cacheService.getRecentActivity(widget.firestore, forceRefresh: true);
                  setState(() {});
                },
                tooltip: 'Refresh activity',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _cacheService.getRecentActivity(widget.firestore),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _cacheService.cachedRecentActivity == null) {
                  return ListView.builder(
                    itemCount: 5,
                    itemBuilder: (context, index) => SkeletonActivityItem(),
                  );
                }

                final activities = snapshot.data ?? _cacheService.cachedRecentActivity ?? [];
                
                if (activities.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: AdminTheme.lightGrey),
                        const SizedBox(height: 8),
                        Text(
                          'No recent activity',
                          style: TextStyle(color: AdminTheme.mediumGrey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    final timestamp = activity['timestamp'] as Timestamp?;
                    final timeAgo = timestamp != null 
                        ? _getTimeAgo(timestamp.toDate())
                        : 'Unknown time';
                    
                    return _buildActivityItem(
                      activity['title'] ?? 'Unknown Activity',
                      timeAgo,
                      _getIconForActivityType(activity['icon'] ?? 'help'),
                      _getColorForActivityType(activity['color'] ?? 'grey'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: AdminTheme.mediumGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AdminTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount;
            double childAspectRatio;
            
            if (constraints.maxWidth > 800) {
              crossAxisCount = 3;
              childAspectRatio = 1.2;
            } else if (constraints.maxWidth > 600) {
              crossAxisCount = 2;
              childAspectRatio = 1.0;
            } else {
              crossAxisCount = 1;
              childAspectRatio = 0.8;
            }

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildQuickActionCard(
                  'Approve Sellers',
                  Icons.verified_user,
                  AdminTheme.success,
                  () => widget.onSectionChanged(4),
                ),
                _buildQuickActionCard(
                  'Manage Orders',
                  Icons.shopping_cart,
                  AdminTheme.info,
                  () => widget.onSectionChanged(5),
                ),
                _buildQuickActionCard(
                  'Moderate Content',
                  Icons.shield,
                  AdminTheme.warning,
                  () => widget.onSectionChanged(10),
                ),
                _buildQuickActionCard(
                  'View Analytics',
                  Icons.analytics,
                  AdminTheme.indigo,
                  () => widget.onSectionChanged(9),
                ),
                _buildQuickActionCard(
                  'Platform Settings',
                  Icons.settings,
                  AdminTheme.deepTeal,
                  () => widget.onSectionChanged(13),
                ),
                _buildQuickActionCard(
                  'System Logs',
                  Icons.history,
                  AdminTheme.cloud,
                  () => widget.onSectionChanged(15),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
            child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AdminTheme.cardDecoration(
          color: AdminTheme.angel,
          boxShadow: [
            BoxShadow(
              color: AdminTheme.indigo.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AdminTheme.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AdminTheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForActivityType(String iconType) {
    switch (iconType) {
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'store':
        return Icons.store;
      case 'person':
        return Icons.person;
      case 'review':
        return Icons.star;
      case 'settings':
        return Icons.settings;
      default:
        return Icons.info;
    }
  }

  Color _getColorForActivityType(String colorType) {
    switch (colorType) {
      case 'blue':
        return AdminTheme.info;
      case 'green':
        return AdminTheme.success;
      case 'orange':
        return AdminTheme.warning;
      case 'purple':
        return AdminTheme.indigo;
      case 'red':
        return AdminTheme.error;
      case 'teal':
        return AdminTheme.deepTeal;
      default:
        return AdminTheme.mediumGrey;
    }
  }

  Icon _sidebarIconForIndex(int i) {
    switch (i) {
      case 0: return const Icon(Icons.category);
      case 1: return const Icon(Icons.people);
      case 2: return const Icon(Icons.verified_user);
      case 3: return const Icon(Icons.shopping_cart);
      case 4: return const Icon(Icons.reviews);
      case 5: return const Icon(Icons.bar_chart);
      case 6: return const Icon(Icons.shield);
      case 7: return const Icon(Icons.settings);
      case 8: return const Icon(Icons.security);
      case 9: return const Icon(Icons.code);
      case 10: return const Icon(Icons.analytics);
      default: return const Icon(Icons.dashboard);
    }
  }
}

class _SidebarNavItem extends StatelessWidget {
  final Icon icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarNavItem({required this.icon, required this.label, this.selected = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.13) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 14),
            Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class _NotificationBell extends StatefulWidget {
  const _NotificationBell();
  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  bool _dialogOpen = false;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('admin_notifications')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        final unread = snapshot.data?.docs.where((d) => d['read'] == false).length ?? 0;
        return Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications, color: Theme.of(context).colorScheme.onPrimary, size: 28),
              tooltip: 'Notifications',
              onPressed: () {
                setState(() => _dialogOpen = true);
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Notifications'),
                    content: SizedBox(
                      width: 400,
                      child: snapshot.hasData && snapshot.data!.docs.isNotEmpty
                          ? ListView.separated(
                              shrinkWrap: true,
                              itemCount: snapshot.data!.docs.length,
                              separatorBuilder: (_, __) => Divider(),
                              itemBuilder: (context, i) {
                                final n = snapshot.data!.docs[i];
                                return ListTile(
                                  leading: Icon(Icons.info, color: n['read'] == false ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                                  title: Text(n['message'] ?? ''),
                                  subtitle: Text(n['timestamp'] != null ? (n['timestamp'] as Timestamp).toDate().toString() : ''),
                                  trailing: n['read'] == false
                                      ? TextButton(
                                          child: Text('Mark Read'),
                                          onPressed: () async {
                                            await n.reference.update({'read': true});
                                            Navigator.pop(ctx);
                                          },
                                        )
                                      : null,
                                );
                              },
                            )
                          : const Text('No notifications.'),
                    ),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close'))],
                  ),
                ).then((_) => setState(() => _dialogOpen = false));
              },
            ),
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.error, shape: BoxShape.circle),
                  child: Text('$unread', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onError, fontSize: 12)),
                ),
              ),
          ],
        );
      },
    );
  }
} 
