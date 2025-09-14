import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PayFastService {
  static const String _sandboxUrl = 'https://sandbox.payfast.co.za/eng/process';
  static const String _liveUrl = 'https://www.payfast.co.za/eng/process';
  
  // PayFast merchant credentials - Your real Solo account credentials
  static const String _merchantId = '23918934';
  static const String _merchantKey = 'fxuj8ymlgqwra';
  static const String _passphrase = 'PeterKutumela2025';
  
  static bool _isProduction = true; // production mode as requested

  // Afrihost-hosted PayFast endpoints (PHP) - using apex domain for reliability
  static const String _afrihostBase = 'https://omniasa.co.za';
  
  // Callback URLs (append order ID to return URL dynamically as needed)
  static String get returnUrl => '$_afrihostBase/payfastReturn.php';
  static String cancelUrl = '$_afrihostBase/payfastCancel.php';
  static String notifyUrl = '$_afrihostBase/payfastNotify.php';

  static void setProductionMode(bool isProduction) {
    _isProduction = isProduction;
  }

  static String get formRedirectUrl => '$_afrihostBase/payfastFormRedirect.php';
  static String get returnPath => 'payfastReturn.php';
  static String get cancelPath => 'payfastCancel.php';
  
  // Public getters for merchant credentials
  static String get merchantId => _isProduction ? _merchantId : '10000100';
  static String get merchantKey => _isProduction ? _merchantKey : '46f0cd694581a';
  static bool get isProduction => _isProduction;

  static String _formatAmount(String amount) {
    final parsed = double.tryParse(amount.replaceAll(',', '.')) ?? 0.0;
    return parsed.toStringAsFixed(2);
  }

  static String _sanitizeRef(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9\-_]'), '_');
    return cleaned.length > 50 ? cleaned.substring(0, 50) : cleaned;
  }

  /// Create a PayFast payment
  static Future<Map<String, dynamic>> createPayment({
    required String amount,
    required String itemName,
    required String itemDescription,
    required String customerEmail,
    required String customerFirstName,
    required String customerLastName,
    required String customerPhone,
    String? customerAddress,
    String? customerCity,
    String? customerCountry,
    String? customerZip,
    String? customString1, // Order ID
    String? customString2, // Store ID
    String? customString3, // Customer ID
    String? customString4, // Payment type
    String? customString5, // Delivery address
  }) async {
    try {
      // Create payment data
      final merchantId = _isProduction ? _merchantId : '10000100';
      final merchantKey = _isProduction ? _merchantKey : '46f0cd694581a';
      // Build return URL with order ID for proper tracking
      final returnUrlWithOrderId = customString1 != null 
          ? '$returnUrl?order_id=${Uri.encodeComponent(customString1)}'
          : returnUrl;
      
      Map<String, String> paymentData = {
        'merchant_id': merchantId,
        'merchant_key': merchantKey,
        'return_url': returnUrlWithOrderId,
        'cancel_url': cancelUrl,
        'notify_url': notifyUrl,
        'amount': _formatAmount(amount),
        'item_name': itemName.length > 100 ? itemName.substring(0, 100) : itemName,
        'item_description': itemDescription.isNotEmpty ? itemDescription : itemName,
        'email_address': customerEmail,
        'name_first': customerFirstName.isNotEmpty ? customerFirstName : 'omniaSA',
        'name_last': customerLastName.isNotEmpty ? customerLastName : 'Customer',
        'cell_number': customerPhone.isNotEmpty ? customerPhone : '0606304683',
      };

      // Avoid sending non-standard fields to PayFast to prevent gateway errors
      if (customString1 != null) paymentData['custom_str1'] = _sanitizeRef(customString1);
      if (customString2 != null) paymentData['custom_str2'] = _sanitizeRef(customString2);
      if (customString3 != null) paymentData['custom_str3'] = _sanitizeRef(customString3);
      if (customString4 != null) paymentData['custom_str4'] = _sanitizeRef(customString4);
      if (customString5 != null) paymentData['custom_str5'] = _sanitizeRef(customString5);

      // Note: m_payment_id removed as it can cause signature validation issues
      // PayFast will generate their own payment ID

      // Signature handled server-side by Cloud Function; do not include here

      // Use hosted form redirect (POST) to avoid gateway 500s on long GET URLs
      final redirectParams = Map<String, String>.from(paymentData);
      redirectParams['sandbox'] = _isProduction ? 'false' : 'true';
      return {
        'success': true,
        'paymentUrl': formRedirectUrl,
        'paymentData': redirectParams,
        'signature': 'server_generated',
        'httpMethod': 'POST',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to create payment: $e',
      };
    }
  }

  // Build a GET redirect URL as a fallback when POST form submission isn't available
  static String buildRedirectUrl(String paymentUrl, Map<String, String> paymentData) {
    final params = paymentData.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$paymentUrl?$params';
  }

  /// Generate PayFast signature
  static String _generateSignature(Map<String, String> data) {
    // Sort the data alphabetically
    List<String> keys = data.keys.toList()..sort();
    
    // Create the signature string
    String signatureString = '';
    for (String key in keys) {
      if (key == 'signature') continue;
      final val = data[key]!;
      // PHP-style urlencode: spaces as '+'; do not encode '~', '*' unnecessarily
      final enc = Uri.encodeQueryComponent(val).replaceAll('%20', '+');
      signatureString += '$key=$enc&';
    }
    
    // Remove the last '&'
    if (signatureString.isNotEmpty) {
      signatureString = signatureString.substring(0, signatureString.length - 1);
    }
    
    // Add passphrase if provided (do NOT URL-encode passphrase per PayFast spec)
    if (_passphrase.isNotEmpty) {
      signatureString += '&passphrase=${_passphrase}';
    }
    
    // Generate MD5 hash
    var bytes = utf8.encode(signatureString);
    var digest = md5.convert(bytes);
    
    return digest.toString();
  }

  /// Verify PayFast payment notification
  static bool verifyPaymentNotification(Map<String, dynamic> notificationData) {
    try {
      // Extract signature from notification
      String? receivedSignature = notificationData['signature'];
      if (receivedSignature == null) return false;

      // Remove signature from data for verification
      Map<String, String> dataForVerification = {};
      notificationData.forEach((key, value) {
        if (key != 'signature' && value != null) {
          dataForVerification[key] = value.toString();
        }
      });

      // Generate expected signature
      String expectedSignature = _generateSignature(dataForVerification);

      // Compare signatures
      return receivedSignature.toLowerCase() == expectedSignature.toLowerCase();
    } catch (e) {
      print('Error verifying payment notification: $e');
      return false;
    }
  }

  /// Get payment status - Updated to make real API calls
  static Future<Map<String, dynamic>> getPaymentStatus(String paymentId) async {
    try {
      // Make actual API call to PayFast to check payment status
      final body = {
        'merchant_id': _merchantId,
        'merchant_key': _merchantKey,
        'payment_id': paymentId,
      };
      
      final response = await http.post(
        Uri.parse('https://api.payfast.co.za/eng/query/payment'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'paymentId': paymentId,
          'status': data['status'] ?? 'UNKNOWN',
          'amount': data['amount'] ?? '0.00',
          'timestamp': DateTime.now().toIso8601String(),
          'rawResponse': data,
        };
      } else {
        // Fallback to mock response for development
        print('PayFast API call failed, using fallback response');
        return {
          'success': true,
          'paymentId': paymentId,
          'status': 'PENDING', // Changed from always COMPLETE
          'amount': '0.00',
          'timestamp': DateTime.now().toIso8601String(),
          'note': 'Using fallback response - API call failed',
        };
      }
    } catch (e) {
      print('Error getting payment status: $e');
      return {
        'success': false,
        'error': 'Failed to get payment status: $e',
        'paymentId': paymentId,
        'status': 'ERROR',
      };
    }
  }

  /// Process payment notification (ITN - Instant Transaction Notification)
  static Map<String, dynamic> processPaymentNotification(Map<String, dynamic> notificationData) {
    try {
      // Verify the notification
      if (!verifyPaymentNotification(notificationData)) {
        return {
          'success': false,
          'error': 'Invalid signature',
        };
      }

      // Extract payment information
      String paymentStatus = notificationData['payment_status'] ?? '';
      String amount = notificationData['amount_gross'] ?? '';
      String paymentId = notificationData['pf_payment_id'] ?? '';
      String orderId = notificationData['custom_str1'] ?? '';
      String storeId = notificationData['custom_str2'] ?? '';
      String customerId = notificationData['custom_str3'] ?? '';

      // Process based on payment status
      switch (paymentStatus.toUpperCase()) {
        case 'COMPLETE':
          return {
            'success': true,
            'status': 'COMPLETE',
            'paymentId': paymentId,
            'orderId': orderId,
            'storeId': storeId,
            'customerId': customerId,
            'amount': amount,
            'message': 'Payment completed successfully',
          };
        
        case 'PENDING':
          return {
            'success': true,
            'status': 'PENDING',
            'paymentId': paymentId,
            'orderId': orderId,
            'message': 'Payment is pending',
          };
        
        case 'FAILED':
          return {
            'success': false,
            'status': 'FAILED',
            'paymentId': paymentId,
            'orderId': orderId,
            'message': 'Payment failed',
          };
        
        default:
          return {
            'success': false,
            'status': 'UNKNOWN',
            'paymentId': paymentId,
            'orderId': orderId,
            'message': 'Unknown payment status: $paymentStatus',
          };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to process payment notification: $e',
      };
    }
  }

  /// Get supported payment methods
  static List<Map<String, dynamic>> getSupportedPaymentMethods() {
    return [
      {
        'id': 'eft',
        'name': 'EFT (Electronic Funds Transfer)',
        'description': 'Direct bank transfer',
        'icon': 'bank',
        'processingTime': '2-3 business days',
      },
      {
        'id': 'credit_card',
        'name': 'Credit Card',
        'description': 'Visa, MasterCard, American Express',
        'icon': 'credit_card',
        'processingTime': 'Instant',
      },
      {
        'id': 'debit_card',
        'name': 'Debit Card',
        'description': 'Maestro, Visa Electron',
        'icon': 'account_balance',
        'processingTime': 'Instant',
      },
      {
        'id': 'instant_eft',
        'name': 'Instant EFT',
        'description': 'Real-time bank transfer',
        'icon': 'flash_on',
        'processingTime': 'Instant',
      },
      {
        'id': 'paypal',
        'name': 'PayPal',
        'description': 'PayPal account payment',
        'icon': 'payment',
        'processingTime': 'Instant',
      },
    ];
  }

  /// Calculate payment fees
  static Map<String, dynamic> calculateFees(String amount) {
    try {
      double amountValue = double.parse(amount);
      
      // PayFast fee structure (example)
      double transactionFee = 0.05; // 5% transaction fee
      double fixedFee = 2.00; // R2 fixed fee
      
      double totalFee = (amountValue * transactionFee) + fixedFee;
      double totalAmount = amountValue + totalFee;
      
      return {
        'success': true,
        'originalAmount': amountValue,
        'transactionFee': totalFee,
        'fixedFee': fixedFee,
        'percentageFee': amountValue * transactionFee,
        'totalAmount': totalAmount,
        'feeBreakdown': {
          'transactionFee': '${(transactionFee * 100).toStringAsFixed(1)}%',
          'fixedFee': 'R${fixedFee.toStringAsFixed(2)}',
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to calculate fees: $e',
      };
    }
  }

  /// Calculate marketplace fees and escrow amounts
  static Future<Map<String, dynamic>> calculateMarketplaceFees({
    required double orderTotal,
    required double deliveryFee,
    required String sellerId,
    required String orderId,
    String? customerId,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Get platform fee from admin settings
      DocumentSnapshot settingsDoc = await firestore
          .collection('admin_settings')
          .doc('payment_settings')
          .get();
      
      Map<String, dynamic> settings = settingsDoc.exists 
          ? settingsDoc.data() as Map<String, dynamic>
          : {};
      
      // Default to 5% if not set, otherwise use configured value
      double platformFeePercentage = (settings['platformFeePercentage'] ?? 5.0).toDouble();
      double platformFee = orderTotal * (platformFeePercentage / 100);
      
      // PayFast transaction fee from settings
      double payfastFeePercentage = (settings['payfastFeePercentage'] ?? 3.5).toDouble();
      double payfastFixedFee = (settings['payfastFixedFee'] ?? 2.0).toDouble();
      double payfastFee = (orderTotal * (payfastFeePercentage / 100)) + payfastFixedFee;
      
      // Total fees
      double totalFees = platformFee + payfastFee;
      
      // Seller payment (order total - platform fee - PayFast fee)
      double sellerPayment = orderTotal - platformFee - payfastFee;
      
      // Customer pays (order total + delivery fee)
      double customerPayment = orderTotal + deliveryFee;
      
      // Holdback amount (10% of seller payment for 30 days)
      double holdbackPercentage = (settings['holdbackPercentage'] ?? 10.0).toDouble();
      double holdbackAmount = sellerPayment * (holdbackPercentage / 100);
      double immediatePayment = sellerPayment - holdbackAmount;
      
      return {
        'success': true,
        'orderTotal': orderTotal,
        'deliveryFee': deliveryFee,
        'platformFeePercentage': platformFeePercentage,
        'platformFee': platformFee,
        'payfastFee': payfastFee,
        'totalFees': totalFees,
        'sellerPayment': sellerPayment,
        'customerPayment': customerPayment,
        'holdbackPercentage': holdbackPercentage,
        'holdbackAmount': holdbackAmount,
        'immediatePayment': immediatePayment,
        'sellerId': sellerId,
        'orderId': orderId,
        'customerId': customerId,
        'feeBreakdown': {
          'platformFee': 'R${platformFee.toStringAsFixed(2)} (${platformFeePercentage.toStringAsFixed(1)}%)',
          'payfastFee': 'R${payfastFee.toStringAsFixed(2)} (${payfastFeePercentage.toStringAsFixed(1)}% + R${payfastFixedFee.toStringAsFixed(0)})',
          'sellerPayment': 'R${sellerPayment.toStringAsFixed(2)}',
          'holdback': 'R${holdbackAmount.toStringAsFixed(2)} (${holdbackPercentage.toStringAsFixed(1)}%)',
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to calculate marketplace fees: $e',
      };
    }
  }

  /// Create marketplace payment with escrow
  static Future<Map<String, dynamic>> createMarketplacePayment({
    required String orderId,
    required String sellerId,
    required String customerId,
    required double orderTotal,
    required double deliveryFee,
    required String customerEmail,
    required String customerName,
    required String customerPhone,
    String? deliveryAddress,
  }) async {
    try {
      // Calculate marketplace fees
      Map<String, dynamic> feeCalculation = await calculateMarketplaceFees(
        orderTotal: orderTotal,
        deliveryFee: deliveryFee,
        sellerId: sellerId,
        orderId: orderId,
        customerId: customerId,
      );

      if (!feeCalculation['success']) {
        return feeCalculation;
      }

      // Create PayFast payment for customer
      Map<String, dynamic> paymentResult = await createPayment(
        amount: feeCalculation['customerPayment'].toString(),
        itemName: 'Order #$orderId',
        itemDescription: 'Marketplace order from seller',
        customerEmail: customerEmail,
        customerFirstName: customerName.split(' ').first,
        customerLastName: customerName.split(' ').length > 1 
            ? customerName.split(' ').skip(1).join(' ') 
            : '',
        customerPhone: customerPhone,
        customerAddress: deliveryAddress,
        customString1: orderId,
        customString2: sellerId,
        customString3: customerId,
        customString4: 'marketplace',
        customString5: deliveryAddress ?? '',
      );

      if (!paymentResult['success']) {
        return paymentResult;
      }

      // Store payment details in Firestore for escrow management
      await _storeEscrowDetails(
        orderId: orderId,
        sellerId: sellerId,
        customerId: customerId,
        feeCalculation: feeCalculation,
        paymentData: paymentResult['paymentData'],
      );

      return {
        'success': true,
        'paymentUrl': paymentResult['paymentUrl'],
        'paymentData': paymentResult['paymentData'],
        'escrowDetails': feeCalculation,
        'message': 'Marketplace payment created successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to create marketplace payment: $e',
      };
    }
  }

  /// Store escrow details in Firestore
  static Future<void> _storeEscrowDetails({
    required String orderId,
    required String sellerId,
    required String customerId,
    required Map<String, dynamic> feeCalculation,
    required Map<String, String> paymentData,
  }) async {
    try {
      // Import Firestore
      final firestore = FirebaseFirestore.instance;
      
      await firestore.collection('escrow_payments').doc(orderId).set({
        'orderId': orderId,
        'sellerId': sellerId,
        'customerId': customerId,
        'orderTotal': feeCalculation['orderTotal'],
        'deliveryFee': feeCalculation['deliveryFee'],
        'platformFee': feeCalculation['platformFee'],
        'payfastFee': feeCalculation['payfastFee'],
        'sellerPayment': feeCalculation['sellerPayment'],
        'holdbackAmount': feeCalculation['holdbackAmount'],
        'immediatePayment': feeCalculation['immediatePayment'],
        'paymentStatus': 'pending',
        'escrowStatus': 'created',
        'createdAt': FieldValue.serverTimestamp(),
        'paymentData': paymentData,
        'returnWindow': 7, // 7 days return window
        'holdbackReleaseDate': DateTime.now().add(Duration(days: 30)),
      });
    } catch (e) {
      print('Error storing escrow details: $e');
    }
  }

  /// Process successful payment and release funds
  static Future<Map<String, dynamic>> processSuccessfulPayment({
    required String orderId,
    required String paymentId,
    required String paymentStatus,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Get escrow details
      DocumentSnapshot escrowDoc = await firestore
          .collection('escrow_payments')
          .doc(orderId)
          .get();

      if (!escrowDoc.exists) {
        return {
          'success': false,
          'error': 'Escrow details not found for order $orderId',
        };
      }

      Map<String, dynamic> escrowData = escrowDoc.data() as Map<String, dynamic>;
      
      // Update payment status
      await firestore.collection('escrow_payments').doc(orderId).update({
        'paymentStatus': paymentStatus,
        'paymentId': paymentId,
        'paidAt': FieldValue.serverTimestamp(),
        'escrowStatus': 'funds_received',
      });

      // Release immediate payment to seller
      await _releaseSellerPayment(
        sellerId: escrowData['sellerId'],
        amount: escrowData['immediatePayment'],
        orderId: orderId,
        paymentType: 'immediate',
      );

      // Schedule holdback release
      await _scheduleHoldbackRelease(
        orderId: orderId,
        sellerId: escrowData['sellerId'],
        holdbackAmount: escrowData['holdbackAmount'],
        releaseDate: escrowData['holdbackReleaseDate'].toDate(),
      );

      return {
        'success': true,
        'message': 'Payment processed successfully',
        'immediatePayment': escrowData['immediatePayment'],
        'holdbackAmount': escrowData['holdbackAmount'],
        'sellerId': escrowData['sellerId'],
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to process payment: $e',
      };
    }
  }

  /// Release payment to seller
  static Future<void> _releaseSellerPayment({
    required String sellerId,
    required double amount,
    required String orderId,
    required String paymentType,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Record seller payment
      await firestore.collection('seller_payments').add({
        'sellerId': sellerId,
        'orderId': orderId,
        'amount': amount,
        'paymentType': paymentType, // 'immediate' or 'holdback'
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'scheduledFor': FieldValue.serverTimestamp(),
      });

      // Update seller earnings
      await firestore.collection('sellers').doc(sellerId).update({
        'totalEarnings': FieldValue.increment(amount),
        'pendingPayments': FieldValue.increment(amount),
        'lastPaymentDate': FieldValue.serverTimestamp(),
      });

      print('Payment of R${amount.toStringAsFixed(2)} scheduled for seller $sellerId');
    } catch (e) {
      print('Error releasing seller payment: $e');
    }
  }

  /// Schedule holdback release
  static Future<void> _scheduleHoldbackRelease({
    required String orderId,
    required String sellerId,
    required double holdbackAmount,
    required DateTime releaseDate,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      await firestore.collection('holdback_schedules').add({
        'orderId': orderId,
        'sellerId': sellerId,
        'holdbackAmount': holdbackAmount,
        'releaseDate': releaseDate,
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error scheduling holdback release: $e');
    }
  }

  /// Process return and refund
  static Future<Map<String, dynamic>> processReturn({
    required String orderId,
    required String customerId,
    required String reason,
    required double refundAmount,
    String? returnNotes,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Get escrow details
      DocumentSnapshot escrowDoc = await firestore
          .collection('escrow_payments')
          .doc(orderId)
          .get();

      if (!escrowDoc.exists) {
        return {
          'success': false,
          'error': 'Escrow details not found for order $orderId',
        };
      }

      Map<String, dynamic> escrowData = escrowDoc.data() as Map<String, dynamic>;
      
      // Calculate refund breakdown
      double platformFeeRefund = escrowData['platformFee'] * (refundAmount / escrowData['orderTotal']);
      double sellerRefund = refundAmount - platformFeeRefund;
      
      // Create return record
      await firestore.collection('returns').add({
        'orderId': orderId,
        'customerId': customerId,
        'sellerId': escrowData['sellerId'],
        'refundAmount': refundAmount,
        'platformFeeRefund': platformFeeRefund,
        'sellerRefund': sellerRefund,
        'reason': reason,
        'returnNotes': returnNotes,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update escrow status
      await firestore.collection('escrow_payments').doc(orderId).update({
        'escrowStatus': 'return_processed',
        'returnAmount': refundAmount,
        'returnedAt': FieldValue.serverTimestamp(),
      });

      // Process refund to customer
      await _processCustomerRefund(
        customerId: customerId,
        orderId: orderId,
        refundAmount: refundAmount,
      );

      // Deduct from seller's holdback
      await _deductFromHoldback(
        sellerId: escrowData['sellerId'],
        orderId: orderId,
        amount: sellerRefund,
      );

      return {
        'success': true,
        'message': 'Return processed successfully',
        'refundAmount': refundAmount,
        'platformFeeRefund': platformFeeRefund,
        'sellerRefund': sellerRefund,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to process return: $e',
      };
    }
  }

  /// Process customer refund
  static Future<void> _processCustomerRefund({
    required String customerId,
    required String orderId,
    required double refundAmount,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      await firestore.collection('customer_refunds').add({
        'customerId': customerId,
        'orderId': orderId,
        'refundAmount': refundAmount,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Refund of R${refundAmount.toStringAsFixed(2)} processed for customer $customerId');
    } catch (e) {
      print('Error processing customer refund: $e');
    }
  }

  /// Deduct amount from seller's holdback
  static Future<void> _deductFromHoldback({
    required String sellerId,
    required String orderId,
    required double amount,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Update seller's holdback
      await firestore.collection('sellers').doc(sellerId).update({
        'holdbackAmount': FieldValue.increment(-amount),
        'totalRefunds': FieldValue.increment(amount),
      });

      // Record holdback deduction
      await firestore.collection('holdback_deductions').add({
        'sellerId': sellerId,
        'orderId': orderId,
        'amount': amount,
        'reason': 'return_refund',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error deducting from holdback: $e');
    }
  }

  /// Get seller payment summary
  static Future<Map<String, dynamic>> getSellerPaymentSummary(String sellerId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Get seller data
      DocumentSnapshot sellerDoc = await firestore
          .collection('sellers')
          .doc(sellerId)
          .get();

      if (!sellerDoc.exists) {
        return {
          'success': false,
          'error': 'Seller not found',
        };
      }

      Map<String, dynamic> sellerData = sellerDoc.data() as Map<String, dynamic>;
      
      // Get recent payments
      QuerySnapshot paymentsQuery = await firestore
          .collection('seller_payments')
          .where('sellerId', isEqualTo: sellerId)
          .where('status', isEqualTo: 'completed')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> recentPayments = paymentsQuery.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      // Get pending payments
      QuerySnapshot pendingQuery = await firestore
          .collection('seller_payments')
          .where('sellerId', isEqualTo: sellerId)
          .where('status', isEqualTo: 'pending')
          .get();

      double pendingAmount = pendingQuery.docs.fold(0.0, (sum, doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return sum + (data['amount'] ?? 0.0);
      });

      return {
        'success': true,
        'sellerId': sellerId,
        'totalEarnings': sellerData['totalEarnings'] ?? 0.0,
        'pendingPayments': sellerData['pendingPayments'] ?? 0.0,
        'holdbackAmount': sellerData['holdbackAmount'] ?? 0.0,
        'totalRefunds': sellerData['totalRefunds'] ?? 0.0,
        'recentPayments': recentPayments,
        'pendingAmount': pendingAmount,
        'lastPaymentDate': sellerData['lastPaymentDate'],
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to get seller payment summary: $e',
      };
    }
  }
} 