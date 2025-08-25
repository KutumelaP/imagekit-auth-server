import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
// import 'package:universal_html/html.dart' as html; // Not needed for current functionality
import 'package:flutter/foundation.dart';
import 'user_management_table.dart';
import 'seller_management_table.dart';
import 'order_management_table.dart';
import 'moderation_center.dart';
import 'platform_settings_section.dart';
import '../../main.dart';
import 'package:admin_dashboard/widgets/section_header.dart';

import 'statistics_section.dart';
import 'reviews_section.dart';
import 'categories_section.dart';
import 'audit_logs_section.dart';
import 'developer_tools_section.dart';
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
import 'financial_overview_section.dart';
import 'reports_section.dart';
import 'data_export_section.dart';
import 'roles_permissions_section.dart';
import 'seller_delivery_management.dart';
import 'image_management_section.dart';
import 'paxi_pricing_management.dart';
import 'risk_review_screen.dart';
import 'kyc_review_list.dart';
import 'kyc_overview_widget.dart';
import 'admin_payouts_section.dart';
import 'customer_support_section.dart';
import 'upload_management_section.dart';

class AdminDashboardContent extends StatefulWidget {
  final String adminEmail;
  final String adminUid;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final int selectedSection;
  final ValueChanged<int> onSectionChanged;
  final bool embedded;
  
  const AdminDashboardContent({
    required this.adminEmail, 
    required this.adminUid, 
    required this.auth,
    required this.firestore,
    required this.selectedSection,
    required this.onSectionChanged,
    this.embedded = false,
  });

  @override
  State<AdminDashboardContent> createState() => _AdminDashboardContentState();
}

class _AdminDashboardContentState extends State<AdminDashboardContent> {
  final DashboardCacheService _cacheService = DashboardCacheService();
  final PageStorageBucket _pageStorageBucket = PageStorageBucket();
  final Map<int, Widget> _cachedSectionWidgets = {};

  Widget _getCachedSection(int index) {
    if (_cachedSectionWidgets[index] == null) {
      _cachedSectionWidgets[index] = KeyedSubtree(
        key: ValueKey('section_' + index.toString()),
        child: _sectionWidget(index),
      );
    }
    return _cachedSectionWidgets[index]!;
  }
  
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
    'Storage Stats',
    'Orphaned Images',
    'Cleanup Tools',
    'Platform Settings',
    'Roles/Permissions',
    'Audit Logs',
    'Payment Settings',
    'Financial Overview',
    'Escrow Management',
    'Returns Management',
    'Developer Tools',
    'Data Export',
    'Order Migration',
    'Rural Driver Management',
    'Urban Delivery Management',
    'Driver Management',
    'Seller Delivery Management',
    'PAXI Pricing Management',
    'Risk Review',
    'KYC Review',
    'KYC Overview',
    'Payouts',
    'Customer Support',
    'Upload Management',
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

  // Summary count helpers no longer used in IndexedStack approach

  @override
  Widget build(BuildContext context) {
    final allowedSections = <int>{...List.generate(_sections.length, (i) => i)};

    // Embedded mode: render only the main content area without internal Scaffold/sidebar
    if (widget.embedded) {
      return PageStorage(
        bucket: _pageStorageBucket,
        child: IndexedStack(
          index: widget.selectedSection,
          children: List.generate(_sections.length, (i) {
            return allowedSections.contains(i)
              ? _getCachedSection(i)
              : const SizedBox.shrink();
          }),
        ),
      );
    }

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
              child: PageStorage(
                bucket: _pageStorageBucket,
                child: IndexedStack(
                  index: widget.selectedSection,
                  children: List.generate(_sections.length, (i) {
                    final isActive = i == widget.selectedSection;
                    if (isActive || _cachedSectionWidgets.containsKey(i)) {
                      return _getCachedSection(i);
                    }
                    return const SizedBox.shrink();
                  }),
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
                          const SizedBox(height: 12),
                          // Admin email
                          Text(
                            widget.adminEmail,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
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
                    child: PageStorage(
                      bucket: _pageStorageBucket,
                      child: IndexedStack(
                        index: widget.selectedSection,
                        children: List.generate(_sections.length, (i) {
                          return allowedSections.contains(i)
                            ? _getCachedSection(i)
                            : const SizedBox.shrink();
                        }),
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
      case 13: return ImageManagementSection(); // Storage Stats
      case 14: return ImageManagementSection(); // Orphaned Images
      case 15: return ImageManagementSection(); // Cleanup Tools
      case 16: return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [SectionHeader('Platform Settings'), const SizedBox(height: 8), PlatformSettingsSection(auth: widget.auth, firestore: widget.firestore)])); // Platform Settings
      case 17: return RolesPermissionsSection(); // Roles/Permissions
      case 18: return AuditLogsSection(); // Audit Logs
      case 19: return PaymentSettingsManagement(); // Payment Settings
      case 20: return const FinancialOverviewSection(); // Financial Overview
      case 21: return EscrowManagement(); // Escrow Management
      case 22: return ReturnsManagement(); // Returns Management
      case 23: return DeveloperToolsSection(); // Developer Tools
      case 24: return DataExportSection(); // Data Export
      case 25: return const OrderMigrationScreen(); // Order Migration
      case 26: return RuralDriverManagement(); // Rural Driver Management
      case 27: return UrbanDeliveryManagement(); // Urban Delivery Management
      case 28: return DriverManagementScreen(); // Driver Management
      case 29: return SellerDeliveryManagement(); // Seller Delivery Management
      case 30: return PaxiPricingManagement(); // PAXI Pricing Management
      case 31: return const RiskReviewScreen(); // Risk Review
      case 32: return const KycReviewList(); // KYC Review
      case 33: return const KycOverviewWidget(); // KYC Overview
      case 34: return const AdminPayoutsSection(); // Payouts
      case 35: return const CustomerSupportSection(); // Customer Support
      case 36: return const UploadManagementSection(); // Upload Management
      default: return const SizedBox();
    }
  }

  Widget _buildQuickActions() {
    return SingleChildScrollView(
      child: Padding(
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
    return FutureBuilder<Map<String, int>>(
      future: _cacheService.getQuickCounts(widget.firestore),
      builder: (context, quickSnap) {
        final quick = quickSnap.data ?? _cacheService.cachedQuickCounts;
        if (quick == null && quickSnap.connectionState == ConnectionState.waiting) {
          return LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount;
              double childAspectRatio;
              if (constraints.maxWidth > 1200) {
                crossAxisCount = 5;
                childAspectRatio = 1.6;
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
                children: List.generate(5, (index) => SkeletonLoading(isLoading: true, child: SkeletonStatCard())),
              );
            },
          );
        }
        return FutureBuilder<DashboardStats>(
          future: _cacheService.getDashboardStats(widget.firestore),
          builder: (context, snapshot) {
            final stats = snapshot.data ?? _cacheService.cachedStats;
            return LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount;
                double childAspectRatio;
                if (constraints.maxWidth > 1200) {
                  crossAxisCount = 5;
                  childAspectRatio = 1.6;
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
                      (stats?.totalUsers ?? quick?['totalUsers'] ?? 0).toString(),
                      Icons.people,
                      AdminTheme.info,
                      isLoading: stats == null && _cacheService.isLoadingStats,
                      growth: stats?.userGrowth,
                    ),
                    _buildStatCard(
                      'Today\'s Orders',
                      (stats?.todayOrders ?? quick?['todayOrders'] ?? 0).toString(),
                      Icons.shopping_cart,
                      AdminTheme.success,
                      isLoading: stats == null && _cacheService.isLoadingStats,
                      growth: stats?.orderGrowth,
                    ),
                    _buildStatCard(
                      'Platform Revenue (All Time)',
                      stats != null ? 'R${stats.totalRevenue.toStringAsFixed(2)}' : '—',
                      Icons.receipt,
                      AdminTheme.indigo,
                      isLoading: stats == null && _cacheService.isLoadingStats,
                      growth: stats?.revenueGrowth,
                    ),
                    if (stats != null)
                      _buildStatCard(
                        'GMV (Last 30 Days)',
                        'R${stats.last30Gmv.toStringAsFixed(2)}',
                        Icons.stacked_line_chart,
                        AdminTheme.deepTeal,
                        isLoading: false,
                        growth: null,
                      ),
                    if (stats != null)
                      _buildStatCard(
                        'Platform Fee (Last 30 Days)',
                        'R${stats.last30PlatformFee.toStringAsFixed(2)}',
                        Icons.savings,
                        AdminTheme.indigo,
                        isLoading: false,
                        growth: null,
                      ),
                    _buildStatCard(
                      'Pending Approvals',
                      (stats?.pendingApprovals ?? quick?['pendingApprovals'] ?? 0).toString(),
                      Icons.pending_actions,
                      (stats?.hasHighPendingApprovals ?? ((quick?['pendingApprovals'] ?? 0) > 10)) ? AdminTheme.error : AdminTheme.warning,
                      isLoading: stats == null && _cacheService.isLoadingStats,
                      growth: null,
                    ),
                    _buildStatCard(
                      'Pending KYC',
                      (stats?.pendingKycSubmissions ?? quick?['pendingKyc'] ?? 0).toString(),
                      Icons.verified_user_outlined,
                      (stats?.hasPendingKyc ?? ((quick?['pendingKyc'] ?? 0) > 0)) ? AdminTheme.warning : AdminTheme.success,
                      isLoading: stats == null && _cacheService.isLoadingStats,
                      growth: null,
                    ),
                  ],
                );
              },
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
                _buildQuickActionCard(
                  'KYC Management',
                  Icons.verified_user_outlined,
                  AdminTheme.primaryColor,
                  () => widget.onSectionChanged(32),
                ),
                _buildQuickActionCard(
                  'Customer Support',
                  Icons.support_agent,
                  Colors.purple,
                  () => widget.onSectionChanged(35),
                ),
                _buildQuickActionCard(
                  'Upload Management',
                  Icons.cloud_upload,
                  Colors.indigo,
                  () => widget.onSectionChanged(36),
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

// removed unused _SidebarNavItem

class _NotificationBell extends StatefulWidget {
  const _NotificationBell();
  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  // bool _dialogOpen = false; // removed unused flag
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
                );
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
