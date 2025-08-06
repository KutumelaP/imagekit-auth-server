import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/home_navigation_button.dart';
import 'OrderTrackingScreen.dart';
import 'ChatScreen.dart';
import 'SellerOrdersListScreen.dart';
import 'OrderHistoryScreen.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshNotifications();
  }

  Future<void> _refreshNotifications() async {
    setState(() => _isLoading = true);
    try {
      await _notificationService.refreshNotifications();
    } catch (e) {
      print('Error refreshing notifications: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _notificationService.deleteNotification(notificationId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification deleted'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting notification: $e'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
    }
  }

  Future<void> _deleteAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Notifications'),
        content: const Text('Are you sure you want to delete all notifications? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _notificationService.deleteAllNotifications();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications deleted'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting notifications: $e'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _notificationService.markNotificationAsRead(notificationId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification marked as read'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking notification as read: $e'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
    }
  }

  // 🔥 NEW: Handle notification tap with enhanced navigation
  void _handleNotificationTap(Map<String, dynamic> notificationData) async {
    final type = notificationData['type'];
    final data = notificationData['data'] ?? {};
    final orderId = data['orderId'] ?? notificationData['orderId'];
    final chatId = data['chatId'] ?? notificationData['chatId'];
    final buyerId = data['buyerId'] ?? notificationData['buyerId'];
    final sellerId = data['sellerId'] ?? notificationData['sellerId'];
    final senderId = data['senderId'] ?? notificationData['senderId'];
    
    print('🔍 DEBUG: Notification tap - Type: $type');
    print('🔍 DEBUG: Notification tap - OrderId: $orderId');
    print('🔍 DEBUG: Notification tap - ChatId: $chatId');
    print('🔍 DEBUG: Notification tap - Data: $data');

    // Mark as read
    await _markAsRead(notificationData['id']);

    // Navigate based on notification type
    print('🔍 DEBUG: Navigation logic - Type: $type, ChatId: $chatId, OrderId: $orderId');
    
    if (type == 'chat_message' && chatId != null) {
      print('🔍 DEBUG: Navigating to ChatScreen');
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && senderId != null) {
        // Get the other user's ID from the chat
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              otherUserId: senderId,
              otherUserName: data['senderName'] ?? 'User',
            ),
          ),
        );
      } else {
        print('🔍 DEBUG: Missing user data for chat navigation');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open chat - user data missing'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    } else if ((type == 'order_status' || type == 'order' || type == 'new_order_buyer') && orderId != null) {
      print('🔍 DEBUG: Navigating to OrderTrackingScreen');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderTrackingScreen(orderId: orderId),
        ),
      );
    } else if (type == 'new_order_seller') {
      print('🔍 DEBUG: Navigating to SellerOrdersListScreen');
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SellerOrdersListScreen(sellerId: currentUser.uid),
          ),
        );
      } else {
        print('🔍 DEBUG: No current user found');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open notification - user not found'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    } else if (type == 'order_status' || type == 'order' || type == 'new_order_buyer') {
      print('🔍 DEBUG: Navigating to OrderHistoryScreen');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OrderHistoryScreen(),
        ),
      );
    } else {
      print('🔍 DEBUG: Unknown notification type or missing data');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open notification'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
    }
  }



  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final timestamp = notification['timestamp'] as Timestamp?;
    final isRead = notification['read'] ?? false;
    final type = notification['type'] ?? '';
    final title = notification['title'] ?? 'Notification';
    final body = notification['body'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        gradient: isRead 
            ? LinearGradient(
                colors: [AppTheme.whisper, AppTheme.angel],
              )
            : LinearGradient(
                colors: [AppTheme.deepTeal.withOpacity(0.1), AppTheme.cloud.withOpacity(0.05)],
              ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRead ? AppTheme.breeze.withOpacity(0.2) : AppTheme.deepTeal.withOpacity(0.3),
          width: isRead ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getNotificationColor(type).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getNotificationIcon(type),
            color: _getNotificationColor(type),
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            color: isRead ? AppTheme.mediumGrey : AppTheme.deepTeal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              body,
              style: TextStyle(
                color: AppTheme.darkGrey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: AppTheme.breeze,
                ),
                const SizedBox(width: 4),
                Text(
                  timestamp != null 
                      ? DateFormat('MMM dd, yyyy HH:mm').format(timestamp.toDate())
                      : 'Unknown time',
                  style: TextStyle(
                    color: AppTheme.breeze,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (!isRead)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: AppTheme.cloud),
          onSelected: (value) {
            if (value == 'delete') {
              _deleteNotification(notification['id']);
            } else if (value == 'mark_read' && !isRead) {
              _markAsRead(notification['id']);
            }
          },
          itemBuilder: (context) => [
            if (!isRead)
              const PopupMenuItem(
                value: 'mark_read',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline),
                    SizedBox(width: 8),
                    Text('Mark as Read'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: AppTheme.primaryRed),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: AppTheme.primaryRed)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _handleNotificationTap(notification),
      ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'new_order_seller':
      case 'new_order_buyer':
        return AppTheme.primaryGreen;
      case 'order_status':
      case 'order':
        return AppTheme.deepTeal;
      case 'chat_message':
        return AppTheme.warmAccentColor;
      default:
        return AppTheme.cloud;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'new_order_seller':
      case 'new_order_buyer':
        return Icons.shopping_bag;
      case 'order_status':
      case 'order':
        return Icons.local_shipping;
      case 'chat_message':
        return Icons.chat;
      default:
        return Icons.notifications;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: AppTheme.cloud,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: AppTheme.headlineMedium.copyWith(
              color: AppTheme.cloud,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see notifications here when you receive them',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.breeze,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _notificationService.getNotificationsWithValidation(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        // Filter out chat messages - they should only appear in the chat tab
        final notifications = snapshot.data!.docs
            .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
            .where((notification) => notification['type'] != 'chat_message')
            .toList();

        if (notifications.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: _refreshNotifications,
          color: AppTheme.deepTeal,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              return _buildNotificationCard(notifications[index]);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return Scaffold(
        backgroundColor: AppTheme.whisper,
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: AppTheme.deepTeal,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Please log in to view notifications'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.whisper,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: Colors.white,
        leading: const HomeNavigationButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshNotifications,
            tooltip: 'Refresh and clean up notifications',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete_all') {
                _deleteAllNotifications();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: AppTheme.primaryRed),
                    SizedBox(width: 8),
                    Text('Delete All', style: TextStyle(color: AppTheme.primaryRed)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.deepTeal),
            )
          : _buildNotificationList(),
    );
  }
} 