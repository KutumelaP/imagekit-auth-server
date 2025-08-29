import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/loading_widget.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String? orderId;
  final String? status;

  const PaymentSuccessScreen({
    Key? key,
    this.orderId,
    this.status,
  }) : super(key: key);

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _orderData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    if (widget.orderId == null) {
      setState(() {
        _isLoading = false;
        _error = 'No order ID provided';
      });
      return;
    }

    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();

      if (orderDoc.exists) {
        setState(() {
          _orderData = orderDoc.data();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Order not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading order: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Successful'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Prevent back button
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _error != null
              ? _buildErrorWidget()
              : _buildSuccessWidget(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
            child: const Text('Go to Home'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessWidget() {
    final orderData = _orderData!;
    final orderNumber = orderData['orderNumber'] ?? 'Unknown';
    final totalPrice = orderData['totalPrice'] ?? 0.0;
    final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
    final orderType = orderData['orderType'] ?? 'pickup';
    final deliveryFee = orderData['deliveryFee'] ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Success Icon and Message
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                Text(
                  'Payment Successful!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Thank you for your order!',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your order has been confirmed and is being processed.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Order Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Order Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Order Number', orderNumber),
                _buildDetailRow('Order Type', orderType == 'delivery' ? 'Delivery' : 'Pickup'),
                _buildDetailRow('Subtotal', 'R${totalPrice.toStringAsFixed(2)}'),
                if (deliveryFee > 0)
                  _buildDetailRow('Delivery Fee', 'R${deliveryFee.toStringAsFixed(2)}'),
                const Divider(),
                _buildDetailRow(
                  'Total',
                  'R${(totalPrice + deliveryFee).toStringAsFixed(2)}',
                  isTotal: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Items Summary
          if (items.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_bag, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Items Ordered',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...items.take(3).map((item) => _buildItemRow(item)),
                  if (items.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '... and ${items.length - 3} more items',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Action Buttons
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to order tracking
                    if (widget.orderId != null) {
                      Navigator.of(context).pushReplacementNamed(
                        '/order/${widget.orderId}',
                      );
                    }
                  },
                  icon: const Icon(Icons.track_changes),
                  label: const Text('Track My Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Clear cart and go to home
                    final cartProvider = Provider.of<CartProvider>(context, listen: false);
                    cartProvider.clearCart();
                    Navigator.of(context).pushReplacementNamed('/');
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Continue Shopping'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.blue.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final name = item['name'] ?? 'Unknown Item';
    final quantity = item['quantity'] ?? 1;
    final price = item['price'] ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              'x$quantity',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'R${price.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
