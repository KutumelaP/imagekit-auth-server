class DeliveryFeeResult {
  final double fee;
  final double distanceKm;
  final bool isUrbanArea;
  final bool usedUrbanPricing;
  final String modelUsed; // e.g., 'system', 'seller_custom', 'urban'

  DeliveryFeeResult({
    required this.fee,
    required this.distanceKm,
    required this.isUrbanArea,
    required this.usedUrbanPricing,
    required this.modelUsed,
  });
}

class DeliveryFeeService {
  // System delivery model (simple defaults; mirror values from Checkout where possible)
  static const double _defaultFeePerKm = 4.5;
  static const double _defaultMinFee = 15.0;
  static const double _defaultMaxFee = 60.0;

  static DeliveryFeeResult compute({
    required double distanceKm,
    required String productCategory, // 'food','electronics','clothes','other'
    required String sellerDeliveryPreference, // 'system' | 'custom'
    double? sellerFlatFee, // for custom
    double? sellerFeePerKm, // for custom
    double? sellerMinFee, // for custom
    bool isUrbanArea = false,
    double? urbanFee, // precomputed urban fee if available
  }) {
    double baselineFee;
    String modelUsed;

    if (sellerDeliveryPreference == 'system') {
      // System model: fee per km with min/max caps
      final double perKm = _defaultFeePerKm;
      final double minFee = _defaultMinFee;
      final double maxFee = _defaultMaxFee;
      baselineFee = (distanceKm * perKm).clamp(minFee, maxFee);
      modelUsed = 'system';
    } else {
      // Seller custom
      final double flat = (sellerFlatFee ?? 0).toDouble();
      final double perKm = (sellerFeePerKm ?? 0).toDouble();
      final double minFee = (sellerMinFee ?? 0).toDouble();
      final double computed = flat + (distanceKm * perKm);
      baselineFee = computed < minFee ? minFee : computed;
      modelUsed = 'seller_custom';
    }

    bool usedUrban = false;
    double finalFee = baselineFee;

    if (isUrbanArea && urbanFee != null) {
      if (urbanFee < baselineFee) {
        finalFee = urbanFee;
        usedUrban = true;
        modelUsed = 'urban';
      }
    }

    return DeliveryFeeResult(
      fee: double.parse(finalFee.toStringAsFixed(2)),
      distanceKm: distanceKm,
      isUrbanArea: isUrbanArea,
      usedUrbanPricing: usedUrban,
      modelUsed: modelUsed,
    );
  }
}

