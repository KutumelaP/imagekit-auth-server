class PaxiConfig {
  // Delivery speed-based pricing structure
  static const Map<String, Map<String, double>> pricing = {
    'standard': {
      'price': 59.95,    // 7-9 business days
    },
    'express': {
      'price': 109.95,   // 3-5 business days
    },
  };

  // Bag specifications (same bag, different delivery speeds)
  static const Map<String, Map<String, dynamic>> bagSpecs = {
    'standard': {
      'name': 'PAXI Bag',
      'weight': '10kg',
      'dimensions': '64 cm x 51 cm',
      'description': 'Standard PAXI bag with standard delivery',
    },
    'express': {
      'name': 'PAXI Bag',
      'weight': '10kg', 
      'dimensions': '64 cm x 51 cm',
      'description': 'Same PAXI bag with express delivery',
    },
  };

  // Delivery time descriptions
  static const Map<String, String> deliveryTimes = {
    'standard': '7-9 business days',
    'express': '3-5 business days',
  };

  // Helper methods
  static double getPrice(String deliverySpeed) {
    return pricing[deliverySpeed]?['price'] ?? 0.0;
  }

  static Map<String, dynamic> getBagSpecs(String deliverySpeed) {
    return bagSpecs[deliverySpeed] ?? {};
  }

  static String getDeliveryTimeDescription(String deliverySpeed) {
    return deliveryTimes[deliverySpeed] ?? '';
  }

  // Get all available delivery speed options
  static List<Map<String, dynamic>> getAllOptions() {
    return [
      {
        'deliverySpeed': 'standard',
        'name': 'Standard Delivery',
        'price': 59.95,
        'time': '7-9 business days',
        'description': 'Standard PAXI delivery - 7-9 business days',
      },
      {
        'deliverySpeed': 'express',
        'name': 'Express Delivery',
        'price': 109.95,
        'time': '3-5 business days',
        'description': 'Fast PAXI delivery - 3-5 business days',
      },
    ];
  }
}
