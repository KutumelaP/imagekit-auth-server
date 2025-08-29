import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'user_management_table.dart';
import 'seller_management_table.dart';
import 'order_management_table.dart';
import 'moderation_center.dart';
import 'platform_settings_section.dart';
import '../../main.dart';
import 'package:admin_dashboard/widgets/section_header.dart';

import 'statistics_section.dart';
import 'reports_section.dart';
import 'advanced_analytics_dashboard.dart';
import 'reviews_section.dart';
import 'image_management_section.dart';
import 'roles_permissions_section.dart';
import 'audit_logs_section.dart';
import 'payment_settings_management.dart';
import 'escrow_management.dart';
import 'financial_overview_section.dart';
import 'admin_payouts_section.dart';
import 'returns_management.dart';
import 'categories_section.dart';
import 'developer_tools_section.dart';
import 'data_export_section.dart';
import 'order_migration_screen.dart';
import 'rural_driver_management.dart';
import 'urban_delivery_management.dart';
import 'driver_management_screen.dart';
import 'seller_delivery_management.dart';
import 'paxi_pricing_management.dart';
import 'risk_review_screen.dart';
import 'kyc_review_list.dart';
import 'kyc_overview_widget.dart';
import 'customer_support_section.dart';
import 'upload_management_section.dart';
import 'cleanup_tools_section.dart';
import '../services/dashboard_cache_service.dart';

class AdminDashboardContent extends StatefulWidget {
  final String adminEmail;
  final String adminUid;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final int selectedSection;
  final Function(int) onSectionChanged;
  final bool embedded;

  const AdminDashboardContent({
    Key? key,
    required this.adminEmail,
    required this.adminUid,
    required this.auth,
    required this.firestore,
    required this.selectedSection,
    required this.onSectionChanged,
    this.embedded = false,
  }) : super(key: key);

  @override
  State<AdminDashboardContent> createState() => _AdminDashboardContentState();
}

class _AdminDashboardContentState extends State<AdminDashboardContent> {
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

  void _onSidebarTap(int index) {
    widget.onSectionChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    // Embedded mode: render only the main content area without internal Scaffold/sidebar
    if (widget.embedded) {
      return _sectionWidget(widget.selectedSection);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth < 900 && constraints.maxWidth >= 600;

        if (isMobile) {
          // Mobile layout
          double contentPadding = 16.0;
          return Scaffold(
            appBar: AppBar(
              title: Text(_sections[widget.selectedSection]),
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              elevation: 2,
            ),
            drawer: Drawer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                  ),
                ),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.admin_panel_settings, size: 35, color: Color(0xFF1565C0)),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Admin Dashboard',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            widget.adminEmail,
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    ..._sections.asMap().entries.map((entry) {
                      int index = entry.key;
                      String title = entry.value;
                      return ListTile(
                        leading: Icon(_getIconForSection(index), color: Colors.white),
                        title: Text(title, style: const TextStyle(color: Colors.white)),
                        selected: widget.selectedSection == index,
                        selectedTileColor: Colors.white.withOpacity(0.1),
                        onTap: () {
                          _onSidebarTap(index);
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
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
              child: _sectionWidget(widget.selectedSection),
            ),
          );
        } else {
          // Desktop/Tablet layout
          double contentPadding = isTablet ? 16.0 : 24.0;
          double sidebarWidth = isTablet ? 250 : 280;

          return Scaffold(
            backgroundColor: const Color(0xFFF5F7FA),
            body: Row(
              children: [
                // Sidebar
                Container(
                  width: sidebarWidth,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(2, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.admin_panel_settings, size: 45, color: Color(0xFF1565C0)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Admin Dashboard',
                              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              widget.adminEmail,
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      // Menu items
                      Expanded(
                        child: ListView(
                          children: [
                            ..._sections.asMap().entries.map((entry) {
                              int index = entry.key;
                              String title = entry.value;
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: widget.selectedSection == index ? Colors.white.withOpacity(0.15) : Colors.transparent,
                                ),
                                child: ListTile(
                                  leading: Icon(_getIconForSection(index), color: Colors.white, size: 20),
                                  title: Text(
                                    title,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: widget.selectedSection == index ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                  dense: true,
                                  onTap: () => _onSidebarTap(index),
                                ),
                              );
                            }).toList(),
                            const SizedBox(height: 20),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                              child: const Divider(color: Colors.white24),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              child: ListTile(
                                leading: const Icon(Icons.logout, color: Colors.white, size: 20),
                                title: const Text('Logout', style: TextStyle(color: Colors.white, fontSize: 14)),
                                dense: true,
                                onTap: () async {
                                  await widget.auth.signOut();
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (_) => const PlatformLoginScreen()),
                                    (route) => false,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Main content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(contentPadding),
                    child: _sectionWidget(widget.selectedSection),
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
      case 0: return SingleChildScrollView(child: AdvancedAnalyticsDashboard(firestore: widget.firestore)); // Advanced Analytics
      case 1: return AuditLogsSection(); // Audit Logs
      case 2: return CategoriesSection(firestore: FirebaseFirestore.instance); // Categories
      case 3: return const CleanupToolsSection(); // Cleanup Tools
      case 4: return const CustomerSupportSection(); // Customer Support
      case 5: return DataExportSection(); // Data Export
      case 6: return DeveloperToolsSection(); // Developer Tools
      case 7: return DriverManagementScreen(); // Driver Management
      case 8: return EscrowManagement(); // Escrow Management
      case 9: return const FinancialOverviewSection(); // Financial Overview
      case 10: return const KycOverviewWidget(); // KYC Overview
      case 11: return const KycReviewList(); // KYC Review
      case 12: return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [SectionHeader('Moderation Center'), const SizedBox(height: 8), ModerationCenter(auth: widget.auth, firestore: widget.firestore)])); // Moderation
      case 13: return const OrderMigrationScreen(); // Order Migration
      case 14: // Orders
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
      case 15: return ImageManagementSection(); // Orphaned Images
      case 16: return _buildDashboardOverview(); // Overview
      case 17: return PaxiPricingManagement(); // PAXI Pricing Management
      case 18: return PaymentSettingsManagement(); // Payment Settings
      case 19: return const AdminPayoutsSection(); // Payouts
      case 20: return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [SectionHeader('Platform Settings'), const SizedBox(height: 8), PlatformSettingsSection(auth: widget.auth, firestore: widget.firestore)])); // Platform Settings
      case 21: return _buildQuickActions(); // Quick Actions
      case 22: return _buildRecentActivity(); // Recent Activity
      case 23: return ReportsSection(); // Reports
      case 24: return ReturnsManagement(); // Returns Management
      case 25: return ReturnsManagement(); // Returns/Refunds
      case 26: return SingleChildScrollView(child: ReviewsSection()); // Reviews
      case 27: return const RiskReviewScreen(); // Risk Review
      case 28: return RolesPermissionsSection(); // Roles/Permissions
      case 29: return RuralDriverManagement(); // Rural Driver Management
      case 30: return SellerDeliveryManagement(); // Seller Delivery Management
      case 31: // Sellers
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
      case 32: return SingleChildScrollView(child: StatisticsSection()); // Statistics
      case 33: return ImageManagementSection(); // Storage Stats
      case 34: return UrbanDeliveryManagement(); // Urban Delivery Management
      case 35: // Users
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
      case 36: return const UploadManagementSection(); // Upload Management
      default: return _buildDashboardOverview();
    }
  }

  IconData _getIconForSection(int index) {
    switch (index) {
      case 0: return Icons.trending_up;
      case 1: return Icons.history;
      case 2: return Icons.category;
      case 3: return Icons.cleaning_services;
      case 4: return Icons.support_agent;
      case 5: return Icons.download;
      case 6: return Icons.code;
      case 7: return Icons.person;
      case 8: return Icons.account_balance;
      case 9: return Icons.analytics;
      case 10: return Icons.people_outline;
      case 11: return Icons.verified_user;
      case 12: return Icons.shield;
      case 13: return Icons.swap_horiz;
      case 14: return Icons.shopping_cart;
      case 15: return Icons.image_not_supported;
      case 16: return Icons.dashboard;
      case 17: return Icons.price_check;
      case 18: return Icons.payment;
      case 19: return Icons.account_balance_wallet;
      case 20: return Icons.settings;
      case 21: return Icons.flash_on;
      case 22: return Icons.timeline;
      case 23: return Icons.assessment;
      case 24: return Icons.assignment_returned;
      case 25: return Icons.assignment_return;
      case 26: return Icons.rate_review;
      case 27: return Icons.warning;
      case 28: return Icons.security;
      case 29: return Icons.directions_car;
      case 30: return Icons.delivery_dining;
      case 31: return Icons.store;
      case 32: return Icons.analytics;
      case 33: return Icons.storage;
      case 34: return Icons.local_shipping;
      case 35: return Icons.people;
      case 36: return Icons.upload_file;
      default: return Icons.dashboard;
    }
  }

  Widget _buildDashboardOverview() {
    return FutureBuilder<Map<String, int>>(
      future: DashboardCacheService().getQuickCounts(widget.firestore),
      builder: (context, quickSnap) {
        final quick = quickSnap.data;
        return FutureBuilder<DashboardStats>(
          future: DashboardCacheService().getDashboardStats(widget.firestore),
          builder: (context, statsSnap) {
            final stats = statsSnap.data;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader('Dashboard Overview'),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isLargeScreen = constraints.maxWidth > 800;
                      final crossAxisCount = isLargeScreen ? 4 : 2;
                      final childAspectRatio = isLargeScreen ? 1.5 : 1.2;

                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: childAspectRatio,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        children: [
                          _buildStatCard('Total Users', (stats?.totalUsers ?? quick?['totalUsers'] ?? 0).toString(), Icons.people, Colors.blue),
                          _buildStatCard('Total Sellers', (stats?.totalSellers ?? quick?['totalSellers'] ?? 0).toString(), Icons.store, Colors.green),
                          _buildStatCard('Total Orders', (stats?.totalOrders ?? quick?['todayOrders'] ?? 0).toString(), Icons.shopping_cart, Colors.orange),
                          _buildStatCard('Total Revenue', 'R${(stats?.totalRevenue ?? 0.0).toStringAsFixed(2)}', Icons.attach_money, Colors.purple),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  SectionHeader('Recent Activity'),
                  const SizedBox(height: 16),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: DashboardCacheService().getRecentActivity(widget.firestore),
                    builder: (context, actSnap) {
                      final activities = actSnap.data ?? [];
                      if (actSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (activities.isEmpty) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'No recent activity',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ),
                          ),
                        );
                      }
                      return Card(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, idx) {
                            final a = activities[idx];
                            return ListTile(
                              leading: CircleAvatar(child: Icon(Icons.circle, size: 14)),
                              title: Text(a['title'] ?? ''),
                              subtitle: Text(a['subtitle'] ?? ''),
                            );
                          },
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemCount: activities.length,
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Quick Actions'),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 1.2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildActionCard('Add User', Icons.person_add, () => _onSidebarTap(35)),
              _buildActionCard('View Orders', Icons.shopping_cart, () => _onSidebarTap(14)),
              _buildActionCard('Manage Sellers', Icons.store, () => _onSidebarTap(31)),
              _buildActionCard('View Analytics', Icons.analytics, () => _onSidebarTap(0)),
              _buildActionCard('Platform Settings', Icons.settings, () => _onSidebarTap(20)),
              _buildActionCard('Reports', Icons.assessment, () => _onSidebarTap(23)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: const Color(0xFF1565C0)),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Recent Activity'),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No recent activity',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}