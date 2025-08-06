import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
}

class PaymentStatusWidget extends StatelessWidget {
  final PaymentStatus status;
  final String? message;
  final String? amount;
  final String? paymentId;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  const PaymentStatusWidget({
    Key? key,
    required this.status,
    this.message,
    this.amount,
    this.paymentId,
    this.onRetry,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getStatusIcon(),
                color: _getStatusColor(),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusTitle(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(),
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        message!,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.cloud,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          if (amount != null || paymentId != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(),
          ],
          
          if (status == PaymentStatus.failed || status == PaymentStatus.cancelled) ...[
            const SizedBox(height: 12),
            _buildActionButtons(),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow() {
    return Row(
      children: [
        if (amount != null) ...[
          Icon(
            Icons.attach_money,
            size: 16,
            color: AppTheme.cloud,
          ),
          const SizedBox(width: 4),
          Text(
            'R$amount',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepTeal,
            ),
          ),
        ],
        if (amount != null && paymentId != null) ...[
          const SizedBox(width: 16),
          Container(
            width: 1,
            height: 16,
            color: AppTheme.cloud.withOpacity(0.3),
          ),
          const SizedBox(width: 16),
        ],
        if (paymentId != null) ...[
          Icon(
            Icons.receipt,
            size: 16,
            color: AppTheme.cloud,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'ID: $paymentId',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.cloud,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (onRetry != null) ...[
          Expanded(
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.deepTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Retry Payment'),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (onCancel != null) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.deepTeal,
                side: BorderSide(color: AppTheme.deepTeal),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ],
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.processing:
        return Colors.blue;
      case PaymentStatus.completed:
        return Colors.green;
      case PaymentStatus.failed:
        return Colors.red;
      case PaymentStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case PaymentStatus.pending:
        return Icons.schedule;
      case PaymentStatus.processing:
        return Icons.sync;
      case PaymentStatus.completed:
        return Icons.check_circle;
      case PaymentStatus.failed:
        return Icons.error;
      case PaymentStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _getStatusTitle() {
    switch (status) {
      case PaymentStatus.pending:
        return 'Payment Pending';
      case PaymentStatus.processing:
        return 'Processing Payment';
      case PaymentStatus.completed:
        return 'Payment Successful';
      case PaymentStatus.failed:
        return 'Payment Failed';
      case PaymentStatus.cancelled:
        return 'Payment Cancelled';
    }
  }
}

class PaymentProgressWidget extends StatelessWidget {
  final PaymentStatus status;
  final String? message;

  const PaymentProgressWidget({
    Key? key,
    required this.status,
    this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
          ),
          const SizedBox(height: 16),
          Text(
            _getStatusMessage(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepTeal,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.cloud,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.processing:
        return AppTheme.deepTeal;
      case PaymentStatus.completed:
        return Colors.green;
      case PaymentStatus.failed:
        return Colors.red;
      case PaymentStatus.cancelled:
        return Colors.grey;
    }
  }

  String _getStatusMessage() {
    switch (status) {
      case PaymentStatus.pending:
        return 'Preparing Payment...';
      case PaymentStatus.processing:
        return 'Processing Payment...';
      case PaymentStatus.completed:
        return 'Payment Complete!';
      case PaymentStatus.failed:
        return 'Payment Failed';
      case PaymentStatus.cancelled:
        return 'Payment Cancelled';
    }
  }
} 