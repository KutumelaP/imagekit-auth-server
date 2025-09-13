class PaymentProcessingService {
  // Placeholder methods. Implement with actual gateways.
  static Future<bool> startCardPayment({required String orderNumber, required double amount}) async {
    return false;
  }

  static Future<bool> startEftPayment({required String orderNumber, required double amount}) async {
    return true; // Show bank details dialog in UI layer
  }

  static Future<bool> markCashOnDelivery({required String orderId}) async {
    return true;
  }
}

