import 'package:flutter/material.dart';
import '../services/real_time_notification_service.dart';

class NotificationPanel extends StatefulWidget {
  final VoidCallback? onClose;

  const NotificationPanel({Key? key, this.onClose}) : super(key: key);

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel> {
  final RealTimeNotificationService _notificationService = RealTimeNotificationService();
  NotificationType? _selectedFilter;
  bool _showUnreadOnly = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildFilterBar(),
          Expanded(child: _buildNotificationList()),
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1F4654), Color(0xFF7FB2BF)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_notificationService.unreadCount} unread',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Connection status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _notificationService.isConnected 
                  ? Colors.green.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _notificationService.isConnected ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _notificationService.isConnected ? 'Live' : 'Offline',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', null),
                const SizedBox(width: 8),
                ...NotificationType.values.map(
                  (type) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(_getTypeDisplayName(type), type),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Toggle switches
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Switch(
                      value: _showUnreadOnly,
                      onChanged: (value) => setState(() => _showUnreadOnly = value),
                      activeColor: Color(0xFF1F4654),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Unread only',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, NotificationType? type) {
    final isSelected = _selectedFilter == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? type : null;
        });
      },
      selectedColor: Color(0xFF1F4654).withOpacity(0.2),
      checkmarkColor: Color(0xFF1F4654),
    );
  }

  Widget _buildNotificationList() {
    return AnimatedBuilder(
      animation: _notificationService,
      builder: (context, child) {
        var notifications = _notificationService.notifications;

        // Apply filters
        if (_selectedFilter != null) {
          notifications = notifications.where((n) => n.type == _selectedFilter).toList();
        }
        
        if (_showUnreadOnly) {
          notifications = notifications.where((n) => !n.isRead).toList();
        }

        if (notifications.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _buildNotificationItem(notification);
          },
        );
      },
    );
  }

  Widget _buildNotificationItem(AdminNotification notification) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        // Remove notification from local list
        _notificationService.clearAll();
      },
      child: Card(
        elevation: notification.isRead ? 1 : 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => _handleNotificationTap(notification),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getPriorityColor(notification.priority).withOpacity(0.3),
                width: notification.isRead ? 1 : 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getTypeColor(notification.type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getTypeIcon(notification.type),
                        color: _getTypeColor(notification.type),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: TextStyle(
                                    fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              _buildPriorityBadge(notification.priority),
                            ],
                          ),
                          const SizedBox(height: 4),
                                                     Text(
                             _formatTimeAgo(notification.timestamp),
                             style: TextStyle(
                               fontSize: 12,
                               color: Colors.grey[600],
                             ),
                           ),
                        ],
                      ),
                    ),
                    if (!notification.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  notification.message,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                if (notification.actionUrl != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _handleNotificationAction(notification),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('View Details'),
                        style: TextButton.styleFrom(
                          foregroundColor: Color(0xFF1F4654),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(NotificationPriority priority) {
    final color = _getPriorityColor(priority);
    final text = priority.toString().split('.').last.toUpperCase();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showUnreadOnly ? Icons.mark_email_read : Icons.notifications_none,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _showUnreadOnly ? 'All caught up!' : 'No notifications yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showUnreadOnly 
                ? 'You have no unread notifications'
                : 'New notifications will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _notificationService.unreadCount > 0 
                  ? () => _notificationService.markAllAsRead()
                  : null,
              icon: const Icon(Icons.done_all, size: 16),
              label: const Text('Mark all read'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _notificationService.notifications.isNotEmpty
                  ? () => _showClearConfirmation()
                  : null,
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear all'),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(AdminNotification notification) {
    if (!notification.isRead) {
      _notificationService.markAsRead(notification.id);
    }
    
    if (notification.actionUrl != null) {
      _handleNotificationAction(notification);
    }
  }

  void _handleNotificationAction(AdminNotification notification) {
    // In a real app, this would navigate to the appropriate screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigate to: ${notification.actionUrl}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications'),
        content: const Text('Are you sure you want to clear all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _notificationService.clearAll();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  String _getTypeDisplayName(NotificationType type) {
    switch (type) {
      case NotificationType.newOrder:
        return 'Orders';
      case NotificationType.sellerRegistration:
        return 'Sellers';
      case NotificationType.paymentFailed:
        return 'Payments';
      case NotificationType.reviewSubmitted:
        return 'Reviews';
      case NotificationType.refundRequested:
        return 'Refunds';
      case NotificationType.systemAlert:
        return 'System';
      case NotificationType.userReported:
        return 'Reports';
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.newOrder:
        return Icons.shopping_cart;
      case NotificationType.sellerRegistration:
        return Icons.store;
      case NotificationType.paymentFailed:
        return Icons.payment;
      case NotificationType.reviewSubmitted:
        return Icons.star;
      case NotificationType.refundRequested:
        return Icons.receipt;
      case NotificationType.systemAlert:
        return Icons.warning;
      case NotificationType.userReported:
        return Icons.report;
    }
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.newOrder:
        return Colors.blue;
      case NotificationType.sellerRegistration:
        return Colors.green;
      case NotificationType.paymentFailed:
        return Colors.red;
      case NotificationType.reviewSubmitted:
        return Colors.orange;
      case NotificationType.refundRequested:
        return Colors.purple;
      case NotificationType.systemAlert:
        return Colors.amber;
      case NotificationType.userReported:
        return Colors.red;
    }
  }

  Color _getPriorityColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Colors.grey;
      case NotificationPriority.medium:
        return Colors.blue;
      case NotificationPriority.high:
        return Colors.orange;
      case NotificationPriority.critical:
        return Colors.red;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
} 