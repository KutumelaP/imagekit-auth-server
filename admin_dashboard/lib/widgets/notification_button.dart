import 'package:flutter/material.dart';
import '../services/real_time_notification_service.dart';

class NotificationButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? iconColor;
  final double? size;

  const NotificationButton({
    Key? key,
    this.onPressed,
    this.iconColor,
    this.size = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final notificationService = RealTimeNotificationService();
    
    return AnimatedBuilder(
      animation: notificationService,
      builder: (context, child) {
        return IconButton(
          icon: Stack(
            children: [
              Icon(
                Icons.notifications_outlined,
                color: iconColor ?? Colors.white,
                size: size,
              ),
              if (notificationService.unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: notificationService.criticalCount > 0 ? Colors.red : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      notificationService.unreadCount > 99 ? '99+' : '${notificationService.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (notificationService.criticalCount > 0)
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: onPressed,
          tooltip: notificationService.unreadCount > 0
              ? 'Notifications (${notificationService.unreadCount} unread${notificationService.criticalCount > 0 ? ', ${notificationService.criticalCount} critical' : ''})'
              : 'No new notifications',
        );
      },
    );
  }
} 