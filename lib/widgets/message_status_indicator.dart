import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MessageStatusIndicator extends StatelessWidget {
  final String status;
  final bool isMe;
  final double size;

  const MessageStatusIndicator({
    super.key,
    required this.status,
    required this.isMe,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    // Only show status indicator for own messages
    if (!isMe) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // First tick (always shown for sent/delivered/read)
        if (status == 'sent' || status == 'delivered' || status == 'read')
          Icon(
            Icons.check,
            size: size,
            color: _getStatusColor(),
          ),
        // Second tick (only for delivered/read)
        if (status == 'delivered' || status == 'read')
          Icon(
            Icons.check,
            size: size,
            color: _getStatusColor(),
          ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case 'sent':
        return Colors.grey[400]!;
      case 'delivered':
        return Colors.grey[600]!;
      case 'read':
        return Colors.blue;
      default:
        return Colors.grey[400]!;
    }
  }
} 