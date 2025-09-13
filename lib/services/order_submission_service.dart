import 'package:cloud_firestore/cloud_firestore.dart';

class OrderSubmissionService {
  static Future<String> createOrder({
    required String buyerId,
    required String sellerId,
    required double totalPrice,
    required bool isDelivery,
    double deliveryFee = 0.0,
    String? address,
  }) async {
    final now = DateTime.now();
    final orderNumber = 'V2-${now.millisecondsSinceEpoch}';
    final ref = await FirebaseFirestore.instance.collection('orders').add({
      'orderNumber': orderNumber,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'totalPrice': totalPrice,
      'orderType': isDelivery ? 'delivery' : 'pickup',
      'deliveryFee': isDelivery ? deliveryFee : 0.0,
      'address': address,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }
}

