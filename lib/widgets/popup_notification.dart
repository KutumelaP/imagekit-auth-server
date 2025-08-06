import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart'; // Added import for NotificationService

class PopupNotification extends StatefulWidget {
  final String title;
  final String message;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const PopupNotification({
    Key? key,
    required this.title,
    required this.message,
    this.imageUrl,
    this.onTap,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<PopupNotification> createState() => _PopupNotificationState();
}

class _PopupNotificationState extends State<PopupNotification>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // Start animations
    _slideController.forward();
    _fadeController.forward();
    
    // Auto dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        dismiss();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void dismiss() {
    _fadeController.reverse().then((_) {
      _slideController.reverse().then((_) {
        widget.onDismiss?.call();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.all(16),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                widget.onTap?.call();
                dismiss();
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.deepTeal,
                      AppTheme.deepTeal.withOpacity(0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Notification Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.angel.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.notifications_active,
                        color: AppTheme.angel,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: AppTheme.angel,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.message,
                            style: TextStyle(
                              color: AppTheme.angel.withOpacity(0.9),
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    
                    // Dismiss Button
                    IconButton(
                      onPressed: dismiss,
                      icon: Icon(
                        Icons.close,
                        color: AppTheme.angel.withOpacity(0.7),
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Global notification overlay
class NotificationOverlay {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static OverlayEntry? _currentNotification;

  static void show({
    required String title,
    required String message,
    String? imageUrl,
    VoidCallback? onTap,
  }) {
    try {
      // Dismiss any existing notification
      dismiss();

      // Get context from the main app's navigator key
      final context = null; // Removed navigatorKey dependency
      
      if (context == null) {
        print('❌ NotificationOverlay: No context available for notification');
        return;
      }

      _showNotificationInContext(context, title, message, imageUrl, onTap);
    } catch (e) {
      print('❌ NotificationOverlay: Error showing notification: $e');
    }
  }

  static void _showNotificationInContext(
    BuildContext context,
    String title,
    String message,
    String? imageUrl,
    VoidCallback? onTap,
  ) {
    try {
      final overlay = Overlay.of(context);
      
      if (overlay == null) {
        print('❌ NotificationOverlay: No overlay available, trying fallback');
        _showFallbackNotification(context, title, message, onTap);
        return;
      }

      _currentNotification = OverlayEntry(
        builder: (context) => PopupNotification(
          title: title,
          message: message,
          imageUrl: imageUrl,
          onTap: onTap,
          onDismiss: dismiss,
        ),
      );

      overlay.insert(_currentNotification!);
      print('✅ NotificationOverlay: Notification shown successfully');
    } catch (e) {
      print('❌ NotificationOverlay: Error creating overlay entry: $e');
      _showFallbackNotification(context, title, message, onTap);
    }
  }

  // Fallback method using SnackBar
  static void _showFallbackNotification(
    BuildContext context,
    String title,
    String message,
    VoidCallback? onTap,
  ) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(message),
            ],
          ),
          backgroundColor: AppTheme.deepTeal,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              onTap?.call();
            },
          ),
        ),
      );
      print('✅ Fallback notification shown successfully');
    } catch (e) {
      print('❌ Error showing fallback notification: $e');
      // Final fallback: just log
      print('🔔 Notification: $title - $message');
    }
  }

  static void dismiss() {
    try {
      _currentNotification?.remove();
      _currentNotification = null;
    } catch (e) {
      print('❌ NotificationOverlay: Error dismissing notification: $e');
    }
  }
} 