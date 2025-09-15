import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WhatsAppIntegrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // WhatsApp Business API Configuration
  static const String _baseUrl = 'https://wa.me';
  static const String _businessNumber = '27606304683'; // Your business WhatsApp number
  
  /// Send order confirmation via WhatsApp
  static Future<bool> sendOrderConfirmation({
    required String orderId,
    required String buyerPhone,
    required String sellerName,
    required double totalAmount,
    required String deliveryOTP,
  }) async {
    try {
      final message = _buildOrderConfirmationMessage(
        orderId: orderId,
        sellerName: sellerName,
        totalAmount: totalAmount,
        deliveryOTP: deliveryOTP,
      );
      
      return await _sendWhatsAppMessage(
        phoneNumber: _cleanPhoneNumber(buyerPhone),
        message: message,
      );
    } catch (e) {
      print('❌ Error sending order confirmation: $e');
      return false;
    }
  }
  
  /// Send delivery notification to buyer
  static Future<bool> sendDeliveryNotification({
    required String orderId,
    required String buyerPhone,
    required String driverName,
    required String driverPhone,
    required String estimatedArrival,
    required String trackingUrl,
    String? deliveryOTP,
  }) async {
    try {
      final message = _buildDeliveryNotificationMessage(
        orderId: orderId,
        driverName: driverName,
        driverPhone: driverPhone,
        estimatedArrival: estimatedArrival,
        trackingUrl: trackingUrl,
        deliveryOTP: deliveryOTP,
      );
      
      return await _sendWhatsAppMessage(
        phoneNumber: _cleanPhoneNumber(buyerPhone),
        message: message,
      );
    } catch (e) {
      print('❌ Error sending delivery notification: $e');
      return false;
    }
  }
  
  /// Send new order notification to seller
  static Future<bool> sendNewOrderNotificationToSeller({
    required String orderId,
    required String sellerPhone,
    required String buyerName,
    required double orderTotal,
    required List<Map<String, dynamic>> items,
    required String deliveryAddress,
  }) async {
    try {
      final message = _buildSellerOrderNotificationMessage(
        orderId: orderId,
        buyerName: buyerName,
        orderTotal: orderTotal,
        items: items,
        deliveryAddress: deliveryAddress,
      );
      
      return await _sendWhatsAppMessage(
        phoneNumber: _cleanPhoneNumber(sellerPhone),
        message: message,
      );
    } catch (e) {
      print('❌ Error sending seller notification: $e');
      return false;
    }
  }
  
  /// Send delivery ready notification to seller
  static Future<bool> sendDeliveryReadyNotification({
    required String orderId,
    required String sellerPhone,
    required String pickupInstructions,
  }) async {
    try {
      final message = _buildDeliveryReadyMessage(
        orderId: orderId,
        pickupInstructions: pickupInstructions,
      );
      
      return await _sendWhatsAppMessage(
        phoneNumber: _cleanPhoneNumber(sellerPhone),
        message: message,
      );
    } catch (e) {
      print('❌ Error sending delivery ready notification: $e');
      return false;
    }
  }
  
  /// Open WhatsApp chat with pre-filled message
  static Future<bool> openWhatsAppChat({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      return await _sendWhatsAppMessage(
        phoneNumber: _cleanPhoneNumber(phoneNumber),
        message: message,
      );
    } catch (e) {
      print('❌ Error opening WhatsApp chat: $e');
      return false;
    }
  }
  
  /// Send customer support escalation
  static Future<bool> sendSupportEscalation({
    required String orderId,
    required String issue,
    required String customerPhone,
    required String urgency, // low, medium, high, critical
  }) async {
    try {
      final message = _buildSupportEscalationMessage(
        orderId: orderId,
        issue: issue,
        customerPhone: customerPhone,
        urgency: urgency,
      );
      
      // Send to business support number
      return await _sendWhatsAppMessage(
        phoneNumber: _businessNumber,
        message: message,
      );
    } catch (e) {
      print('❌ Error sending support escalation: $e');
      return false;
    }
  }
  
  // Private helper methods
  
  static Future<bool> _sendWhatsAppMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final encodedMessage = Uri.encodeComponent(message);
      final whatsappUrl = '$_baseUrl/$phoneNumber?text=$encodedMessage';
      
      final uri = Uri.parse(whatsappUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        // Log the message for analytics
        await _logWhatsAppMessage(phoneNumber, message);
        
        return true;
      } else {
        print('❌ Cannot launch WhatsApp URL: $whatsappUrl');
        return false;
      }
    } catch (e) {
      print('❌ Error launching WhatsApp: $e');
      return false;
    }
  }
  
  static String _cleanPhoneNumber(String phone) {
    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Add country code if not present
    if (cleaned.startsWith('0')) {
      cleaned = '27${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('27')) {
      cleaned = '27$cleaned';
    }
    
    return cleaned;
  }
  
  static String _buildOrderConfirmationMessage({
    required String orderId,
    required String sellerName,
    required double totalAmount,
    required String deliveryOTP,
  }) {
    return '''🎉 *Order Confirmed!*

Hi! Your OmniaSA order is confirmed:

📋 *Order:* #$orderId
🏪 *Store:* $sellerName  
💰 *Total:* R${totalAmount.toStringAsFixed(2)}

🔐 *Delivery OTP:* $deliveryOTP
(Share this with the driver during delivery)

📱 Track your order: https://omniasa.co.za/track/$orderId

Need help? Reply to this message!

*OmniaSA - Your Local Marketplace* 🇿🇦''';
  }
  
  static String _buildDeliveryNotificationMessage({
    required String orderId,
    required String driverName,
    required String driverPhone,
    required String estimatedArrival,
    required String trackingUrl,
    String? deliveryOTP,
  }) {
    return '''🚚 *Your order is on the way!*

📋 *Order:* #$orderId
👤 *Driver:* $driverName
📞 *Driver Phone:* $driverPhone
⏰ *ETA:* $estimatedArrival

📍 *How to track:*
1) Open the OmniaSA app
2) Go to Order History
3) Tap "Track" on order #$orderId

${deliveryOTP != null ? '🔐 *Delivery OTP:* $deliveryOTP\n(Share this with the driver during delivery)\n' : '🔐 Have your OTP ready for delivery verification!'}

*OmniaSA Delivery* 🇿🇦''';
  }
  
  static String _buildSellerOrderNotificationMessage({
    required String orderId,
    required String buyerName,
    required double orderTotal,
    required List<Map<String, dynamic>> items,
    required String deliveryAddress,
  }) {
    final itemsList = items.map((item) => 
      '• ${item['name']} x${item['quantity']}'
    ).join('\n');
    
    return '''🛒 *New Order Received!*

📋 *Order:* #$orderId
👤 *Customer:* $buyerName
💰 *Total:* R${orderTotal.toStringAsFixed(2)}

📦 *Items:*
$itemsList

📍 *Delivery to:* $deliveryAddress

⚡ Please prepare order for pickup/delivery

*OmniaSA Seller Dashboard* 🏪''';
  }
  
  static String _buildDeliveryReadyMessage({
    required String orderId,
    required String pickupInstructions,
  }) {
    return '''📦 *Order Ready for Pickup*

📋 *Order:* #$orderId

🚚 *Pickup Instructions:*
$pickupInstructions

⏰ Driver will arrive within 30 minutes

*OmniaSA Logistics* 🇿🇦''';
  }
  
  static String _buildSupportEscalationMessage({
    required String orderId,
    required String issue,
    required String customerPhone,
    required String urgency,
  }) {
    final urgencyEmoji = {
      'low': '🟢',
      'medium': '🟡', 
      'high': '🟠',
      'critical': '🔴'
    }[urgency] ?? '🟡';
    
    return '''$urgencyEmoji *SUPPORT ESCALATION*

📋 *Order:* #$orderId
📞 *Customer:* $customerPhone
⚠️ *Urgency:* ${urgency.toUpperCase()}

🔍 *Issue:*
$issue

⏰ *Time:* ${DateTime.now().toLocal()}

*Immediate attention required*''';
  }
  
  static Future<void> _logWhatsAppMessage(String phoneNumber, String message) async {
    try {
      await _firestore.collection('whatsapp_logs').add({
        'phoneNumber': phoneNumber,
        'message': message,
        'sentAt': FieldValue.serverTimestamp(),
        'platform': 'flutter_app',
      });
    } catch (e) {
      print('❌ Error logging WhatsApp message: $e');
    }
  }
  
  /// Get pre-defined message templates
  static Map<String, String> getMessageTemplates() {
    return {
      'order_delay': 'Hi! Your order #{{orderId}} is delayed by {{delay}} minutes. We apologize for the inconvenience. New ETA: {{newETA}}',
      'order_ready': '🎉 Great news! Your order #{{orderId}} is ready for collection at {{storeName}}. Please bring your ID.',
      'payment_reminder': '💰 Reminder: Payment for order #{{orderId}} (R{{amount}}) is still pending. Please complete payment to proceed.',
      'delivery_failed': '❌ Delivery attempt failed for order #{{orderId}}. Please contact us to reschedule: {{supportNumber}}',
      'refund_processed': '✅ Refund of R{{amount}} for order #{{orderId}} has been processed. It will reflect in 3-5 business days.',
    };
  }
}
