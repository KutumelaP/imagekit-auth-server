import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/loading_widget.dart';
import '../services/whatsapp_integration_service.dart';
import '../theme/app_theme.dart';
import 'simple_home_screen.dart';

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
  bool _whatsappSent = false;

  @override
  void initState() {
    super.initState();
    print('🎉 PaymentSuccessScreen initState - orderId: ${widget.orderId}, status: ${widget.status}');
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    print('🔍 _loadOrderData called - widget.orderId: ${widget.orderId}');
    if (widget.orderId == null) {
      print('❌ No order ID provided');
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
        final orderData = orderDoc.data();
        if (orderData == null) {
          setState(() {
            _error = 'Order data is empty';
            _isLoading = false;
          });
          return;
        }
        print('✅ Order found: ${orderData['orderNumber']} - ${orderData['totalPrice']}');
        setState(() {
          _orderData = orderData;
          _isLoading = false;
        });
        
        // Note: WhatsApp notification will be sent when user clicks the button
        // This matches the behavior of COD/EFT which send automatically during order creation
      } else {
        print('❌ Order not found: ${widget.orderId}');
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

  /// Send WhatsApp notification for any order type
  Future<void> _sendWhatsAppNotificationForOrder(Map<String, dynamic> orderData) async {
    if (_whatsappSent) return; // Already sent
    
    try {
      // First try to get phone number from order data
      String? phoneNumber = orderData['buyerPhone'] ?? 
                           orderData['customerPhone'] ?? 
                           orderData['buyerDetails']?['phone'];
      
      // If not in order data, try to get from authenticated user
      if (phoneNumber == null || phoneNumber.isEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Try user.phoneNumber first
          phoneNumber = user.phoneNumber;
          
          // If still null, try to get from user document
          if (phoneNumber == null || phoneNumber.isEmpty) {
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();
              
              if (userDoc.exists) {
                final userData = userDoc.data();
                if (userData != null) {
                  phoneNumber = userData['phoneNumber'] ?? userData['phone'];
                }
              }
            } catch (e) {
              print('⚠️ Could not fetch user data: $e');
            }
          }
        }
      }
      
      // If we still don't have a phone number, try to get from buyer data
      if (phoneNumber == null || phoneNumber.isEmpty) {
        final buyerId = orderData['buyerId'];
        if (buyerId != null) {
          try {
            final buyerDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(buyerId)
                .get();
            
            if (buyerDoc.exists) {
              final buyerData = buyerDoc.data();
              if (buyerData != null) {
                phoneNumber = buyerData['phoneNumber'] ?? buyerData['phone'];
              }
            }
          } catch (e) {
            print('⚠️ Could not fetch buyer data: $e');
          }
        }
      }
      
      print('📱 Phone number search results:');
      print('   - Order buyerPhone: ${orderData['buyerPhone'] ?? 'null'}');
      print('   - Order customerPhone: ${orderData['customerPhone'] ?? 'null'}');
      print('   - Order buyerDetails.phone: ${orderData['buyerDetails']?['phone'] ?? 'null'}');
      print('   - Final phone: ${phoneNumber ?? 'null'}');
      
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        print('✅ Found phone number: $phoneNumber');
        // Get order details
        final orderId = orderData['orderNumber'] ?? orderData['orderId'] ?? widget.orderId ?? 'Unknown';
        
        // Get total price from correct field
        final pricing = orderData['pricing'] as Map<String, dynamic>?;
        final totalPrice = (pricing?['grandTotal'] ?? orderData['totalPrice'] ?? orderData['totalAmount'] ?? 0.0) as double;
        
        // Get store name from multiple possible sources
        String sellerName = 'OmniaSA Store';
        
        // Try to get from fulfillment pickup point
        final fulfillment = orderData['fulfillment'] as Map<String, dynamic>?;
        final pickupPoint = fulfillment?['pickupPoint'] as Map<String, dynamic>?;
        if (pickupPoint != null && pickupPoint['name'] != null && pickupPoint['name'].toString().trim().isNotEmpty) {
          sellerName = pickupPoint['name'].toString().trim();
        } else {
          // Try to get from items
          final items = orderData['items'] as List<dynamic>?;
          if (items != null && items.isNotEmpty) {
            final firstItem = items[0] as Map<String, dynamic>?;
            if (firstItem != null && firstItem['sellerName'] != null && firstItem['sellerName'].toString().trim().isNotEmpty) {
              sellerName = firstItem['sellerName'].toString().trim();
            }
          }
          
          // If still generic, try to fetch from seller document
          if (sellerName == 'OmniaSA Store' || sellerName == 'Unknown Store') {
            final sellerId = orderData['sellerId'];
            if (sellerId != null) {
              try {
                final sellerDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(sellerId)
                    .get();
                if (sellerDoc.exists) {
                  final sellerData = sellerDoc.data();
                  if (sellerData != null) {
                    sellerName = sellerData['businessName'] ?? sellerData['name'] ?? sellerName;
                  }
                }
              } catch (e) {
                print('⚠️ Could not fetch seller name: $e');
              }
            }
          }
        }
        
        // Resolve collection/verification code depending on fulfillment type
        String resolvedCode = 'N/A';
        try {
          final fulfillmentType = (fulfillment?['type'] ?? '').toString().toLowerCase();
          // Prefer explicit fields if already present
          String? pickupCode = fulfillment?['pickupCode'] ?? orderData['pickupCode'];
          String? deliveryOTP = fulfillment?['deliveryOTP'] ?? orderData['deliveryOTP'];

          if (fulfillmentType == 'pickup') {
            // If pickup: try pickupCode first, then look up store_pickups and pickup_bookings
            if (pickupCode == null || pickupCode.toString().isEmpty) {
              try {
                final spDoc = await FirebaseFirestore.instance
                    .collection('store_pickups')
                    .doc(orderId)
                    .get();
                if (spDoc.exists) {
                  pickupCode = spDoc.data()?['pickupCode']?.toString();
                }
              } catch (_) {}

              if (pickupCode == null || pickupCode.toString().isEmpty) {
                try {
                  final bookings = await FirebaseFirestore.instance
                      .collection('pickup_bookings')
                      .where('orderId', isEqualTo: orderId)
                      .limit(1)
                      .get();
                  if (bookings.docs.isNotEmpty) {
                    pickupCode = bookings.docs.first.data()['pickupCode']?.toString();
                  }
                } catch (_) {}
              }
            }
            resolvedCode = (pickupCode != null && pickupCode.isNotEmpty) ? pickupCode : 'Pending';
          } else {
            // If delivery: try deliveryOTP field first, then look up delivery_otps/{orderId}
            if (deliveryOTP == null || deliveryOTP.toString().isEmpty) {
              try {
                final otpDoc = await FirebaseFirestore.instance
                    .collection('delivery_otps')
                    .doc(orderId)
                    .get();
                if (otpDoc.exists) {
                  deliveryOTP = otpDoc.data()?['otp']?.toString();
                }
              } catch (_) {}
            }
            resolvedCode = (deliveryOTP != null && deliveryOTP.isNotEmpty) ? deliveryOTP : 'Pending';
          }
        } catch (_) {}
        
        print('📱 Sending WhatsApp for order: $orderId, store: $sellerName, total: R${totalPrice.toStringAsFixed(2)}');
        
        // Send WhatsApp notification using the service
        final success = await WhatsAppIntegrationService.sendOrderConfirmation(
          orderId: orderId,
          buyerPhone: phoneNumber,
          sellerName: sellerName,
          totalAmount: totalPrice,
          deliveryOTP: resolvedCode,
        );
        
        if (success) {
          setState(() {
            _whatsappSent = true;
          });
          print('✅ WhatsApp confirmation sent for order: $orderId');
        } else {
          print('❌ WhatsApp send failed for order: $orderId');
        }
      } else {
        print('❌ No phone number found! Checked:');
        print('   - Order data (buyerPhone, customerPhone, buyerDetails.phone)');
        print('   - Current user (Firebase Auth + user document)');
        print('   - Buyer document (from order buyerId)');
        print('   Please ensure order has buyer phone number saved');
      }
    } catch (e) {
      print('❌ Error sending WhatsApp notification: $e');
    }
  }

  Future<void> _checkAndSendWhatsAppNotification(Map<String, dynamic> orderData) async {
    // This method is now deprecated - use _sendWhatsAppNotificationForOrder instead
    // Keeping for backward compatibility but redirecting to the universal method
    await _sendWhatsAppNotificationForOrder(orderData);
  }

  Future<void> _checkAndSendWhatsAppNotificationOLD(Map<String, dynamic> orderData) async {
    if (_whatsappSent) return; // Already sent
    
    try {
      // Check if this is a PayFast payment
      final payment = orderData['payment'] as Map<String, dynamic>?;
      final paymentMethod = payment?['method'] ?? payment?['gateway'];
      
      if (paymentMethod == 'payfast' && orderData['paymentStatus'] == 'paid') {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        
        // Get user phone number
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (!userDoc.exists) return;
        
        final userData = userDoc.data();
        if (userData == null) return;
        final phoneNumber = userData['phoneNumber'] ?? userData['phone'];
        
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          // Get correct order ID (order number)
          final orderId = orderData['orderId'] ?? widget.orderId ?? 'Unknown';
          
          // Get total price from correct field
          final pricing = orderData['pricing'] as Map<String, dynamic>?;
          final totalPrice = (pricing?['grandTotal'] ?? orderData['totalPrice'] ?? orderData['totalAmount'] ?? 0.0) as double;
          
          // Get store name from multiple possible sources
          String sellerName = 'OmniaSA Store';
          
          // Try to get from fulfillment pickup point
          final fulfillment = orderData['fulfillment'] as Map<String, dynamic>?;
          final pickupPoint = fulfillment?['pickupPoint'] as Map<String, dynamic>?;
          if (pickupPoint != null && pickupPoint['name'] != null && pickupPoint['name'].toString().trim().isNotEmpty) {
            sellerName = pickupPoint['name'].toString().trim();
          } else {
            // Try to get from items
            final items = orderData['items'] as List<dynamic>?;
            if (items != null && items.isNotEmpty) {
              final firstItem = items[0] as Map<String, dynamic>?;
              if (firstItem != null && firstItem['sellerName'] != null && firstItem['sellerName'].toString().trim().isNotEmpty) {
                sellerName = firstItem['sellerName'].toString().trim();
              }
            }
            
            // If still generic, try to fetch from seller document
            if (sellerName == 'OmniaSA Store' || sellerName == 'Unknown Store') {
              final sellerId = orderData['sellerId'];
              if (sellerId != null) {
                try {
                  final sellerDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(sellerId)
                      .get();
                  if (sellerDoc.exists) {
                    final sellerData = sellerDoc.data();
                    if (sellerData != null) {
                      sellerName = sellerData['businessName'] ?? sellerData['name'] ?? sellerName;
                    }
                  }
                } catch (e) {
                  print('⚠️ Could not fetch seller name: $e');
                }
              }
            }
          }
          
          // Get delivery OTP from correct location
          final deliveryOTP = fulfillment?['deliveryOTP'] ?? orderData['deliveryOTP'] ?? 'N/A';
          
          print('📱 Sending WhatsApp for order: $orderId, store: $sellerName, total: R${totalPrice.toStringAsFixed(2)}');
          
          // Send WhatsApp notification using the service
          final success = await WhatsAppIntegrationService.sendOrderConfirmation(
            orderId: orderId,
            buyerPhone: phoneNumber,
            sellerName: sellerName,
            totalAmount: totalPrice,
            deliveryOTP: deliveryOTP.toString(),
          );
          
          if (success) {
            setState(() {
              _whatsappSent = true;
            });
            print('✅ WhatsApp confirmation sent for PayFast order: $orderId');
          } else {
            print('❌ WhatsApp send failed for order: $orderId');
          }
        } else {
          print('⚠️ No phone number found for user');
        }
      } else {
        print('⚠️ Not a paid PayFast order: method=$paymentMethod, status=${orderData['paymentStatus']}');
      }
    } catch (e) {
      print('❌ Error sending WhatsApp notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.whisper,
      appBar: AppBar(
        title: const Text(
          'Payment Successful',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: AppTheme.angel,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.deepTeal, AppTheme.breeze],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Container(
              color: AppTheme.whisper,
              child: const LoadingWidget(),
            )
          : _error != null
              ? _buildErrorWidget()
              : _buildSuccessWidget(),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: AppTheme.whisper,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.angel,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.deepTeal.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.lightRed.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.primaryRed,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Oops! Something went wrong',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.deepTeal,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _error ?? 'Unknown error occurred',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.mediumGrey,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.deepTeal,
                      foregroundColor: AppTheme.angel,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Go to Home',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessWidget() {
    final orderData = _orderData;
    if (orderData == null) {
      return Center(
        child: Text(
          'Order data not available',
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.mediumGrey,
          ),
        ),
      );
    }
    
    // Get correct order number
    final orderNumber = orderData['orderId'] ?? widget.orderId ?? 'Unknown';
    
    // Get correct pricing
    final pricing = orderData['pricing'] as Map<String, dynamic>?;
    final totalPrice = (pricing?['grandTotal'] ?? orderData['totalPrice'] ?? orderData['totalAmount'] ?? 0.0) as double;
    final deliveryFee = (pricing?['deliveryFee'] ?? orderData['deliveryFee'] ?? 0.0) as double;
    final subtotal = (pricing?['subtotal'] ?? orderData['subtotal'] ?? 0.0) as double;
    
    // Get items
    final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
    
    // Get order type
    final fulfillment = orderData['fulfillment'] as Map<String, dynamic>?;
    final orderType = fulfillment?['type'] ?? 'pickup';
    
    // Get store name
    String sellerStoreName = 'Store';
    final pickupPoint = fulfillment?['pickupPoint'] as Map<String, dynamic>?;
    if (pickupPoint != null && pickupPoint['name'] != null && pickupPoint['name'].toString().trim().isNotEmpty) {
      sellerStoreName = pickupPoint['name'].toString().trim();
    } else if (items.isNotEmpty) {
      final firstItem = items[0] as Map<String, dynamic>?;
      if (firstItem != null && firstItem['sellerName'] != null && firstItem['sellerName'].toString().trim().isNotEmpty) {
        sellerStoreName = firstItem['sellerName'].toString().trim();
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Stunning Success Hero Section with Animation-like effects
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryGreen.withOpacity(0.1),
                  AppTheme.secondaryGreen.withOpacity(0.05),
                  AppTheme.whisper.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.6, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppTheme.angel.withOpacity(0.8),
                  blurRadius: 15,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background pattern
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: RadialGradient(
                        center: Alignment.topRight,
                        radius: 1.2,
                        colors: [
                          AppTheme.primaryGreen.withOpacity(0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(36),
                  child: Column(
                    children: [
                      // Animated-style success icon
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryGreen,
                              AppTheme.secondaryGreen,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          size: 72,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 28),
                      
                      // Success title with enhanced typography
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            AppTheme.deepTeal,
                            AppTheme.primaryGreen,
                          ],
                        ).createShader(bounds),
                        child: Text(
                          '🎉 Payment Successful!',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.8,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Thank you message
                      Text(
                        'Thank you for choosing OmniaSA! 🛒',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryGreen,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      
                      // Order processing info with better styling
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.angel,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.cloud.withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.deepTeal.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.store,
                                color: AppTheme.primaryGreen,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order Confirmed ✅',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.deepTeal,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Being processed by $sellerStoreName',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.mediumGrey,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Order Details Card
          _buildInfoCard(
            icon: Icons.receipt_long,
            title: 'Order Summary',
            iconColor: AppTheme.deepTeal,
            child: Column(
              children: [
                _buildDetailRow('Order Number', orderNumber),
                _buildDetailRow('From Store', sellerStoreName),
                _buildDetailRow('Order Type', orderType == 'delivery' ? 'Delivery' : 'Pickup'),
                _buildDetailRow('Items Total', 'R${subtotal.toStringAsFixed(2)}'),
                if (deliveryFee > 0)
                  _buildDetailRow('Delivery Fee', 'R${deliveryFee.toStringAsFixed(2)}'),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  height: 1,
                  color: AppTheme.cloud.withOpacity(0.5),
                ),
                _buildDetailRow(
                  'Total Paid',
                  'R${totalPrice.toStringAsFixed(2)}',
                  isTotal: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Items Summary Card
          if (items.isNotEmpty) ...[
            _buildInfoCard(
              icon: Icons.shopping_bag_outlined,
              title: 'Items Ordered (${items.length})',
              iconColor: AppTheme.primaryGreen,
              child: Column(
                children: [
                  ...items.take(3).map((item) => _buildItemRow(item)),
                  if (items.length > 3)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.whisper.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '... and ${items.length - 3} more items',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.mediumGrey,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Action Buttons
          _buildActionButtons(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required Widget child,
    required Color iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.angel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.cloud.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepTeal,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 15,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
              color: isTotal ? AppTheme.deepTeal : AppTheme.mediumGrey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 15,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
              color: isTotal ? AppTheme.primaryGreen : AppTheme.deepTeal,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.whisper.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.cloud.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.deepTeal,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'x$quantity',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'R${price.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.deepTeal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // WhatsApp Section with explanation
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF25D366).withOpacity(0.1),
                const Color(0xFF128C7E).withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF25D366).withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF25D366).withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // WhatsApp explanation
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.message,
                      color: Color(0xFF25D366),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      
                        const SizedBox(height: 6),
                        Text(
                          'Instant notifications to your phone with order details, tracking info & delivery updates. Never miss an update!',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.mediumGrey,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // WhatsApp Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _whatsappSent ? null : () async {
                    print('📱 WhatsApp button pressed');
                    if (_orderData != null) {
                      print('📄 Order data available, sending WhatsApp...');
                      try {
                        await _sendWhatsAppNotificationForOrder(_orderData!);
                        print('✅ WhatsApp function completed');
                      } catch (e) {
                        print('❌ WhatsApp error: $e');
                      }
                    } else {
                      print('❌ No order data available for WhatsApp');
                    }
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _whatsappSent ? Icons.check_circle : Icons.message,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  label: Text(
                    _whatsappSent ? '✅ WhatsApp Update Sent!' : ' Send WhatsApp Update',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _whatsappSent ? AppTheme.primaryGreen : const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: _whatsappSent ? 0 : 8,
                    shadowColor: const Color(0xFF25D366).withOpacity(0.4),
                  ),
                ),
              ),
              
              if (_whatsappSent) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppTheme.primaryGreen,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'WhatsApp update sent successfully! 📲',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Action Buttons Row
        Row(
          children: [
            // Track Order Button
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.deepTeal, AppTheme.breeze],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.deepTeal.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (widget.orderId != null) {
                      print('🔍 Navigating to track order: ${widget.orderId}');
                      Navigator.of(context).pushReplacementNamed('/track/${widget.orderId}');
                    } else {
                      print('❌ No order ID available for tracking');
                    }
                  },
                  icon: const Icon(Icons.track_changes, size: 22),
                  label: const Text(
                    'Track Order',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Continue Shopping Button
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.angel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.deepTeal,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.deepTeal.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: OutlinedButton.icon(
                  onPressed: () {
                    print('🛒 Continue Shopping button pressed');
                    try {
                      final cartProvider = Provider.of<CartProvider>(context, listen: false);
                      cartProvider.clearCart();
                      print('🧺 Cart cleared');
                      
                      // Use pushAndRemoveUntil to clear the entire navigation stack
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => SimpleHomeScreen()),
                        (route) => false,
                      );
                      print('🏠 Navigating to home (cleared stack)');
                    } catch (e) {
                      print('❌ Continue Shopping error: $e');
                    }
                  },
                  icon: const Icon(Icons.shopping_bag_outlined, size: 22),
                  label: const Text(
                    'Shop More',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.deepTeal,
                    side: BorderSide.none,
                    backgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Bottom tip
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.whisper.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                Icons.tips_and_updates,
                color: AppTheme.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tip: WhatsApp updates help you stay informed about delivery times and any changes to your order.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.mediumGrey,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
