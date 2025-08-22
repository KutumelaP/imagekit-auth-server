import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class RiskResult {
  final int riskScore; // 0-100
  final List<String> reasons;
  final Map<String, dynamic> signals;

  const RiskResult({required this.riskScore, required this.reasons, required this.signals});
  bool get isHigh => riskScore >= 80;
  bool get isMedium => riskScore >= 50 && riskScore < 80;
}

class RiskEngine {
  // Simple thresholds; can be tuned or moved to remote config later
  static const int highThreshold = 80;
  static const int mediumThreshold = 50;

  static Future<RiskResult> evaluate({
    required String userId,
    required double orderTotal,
    required bool isDelivery,
    String? ipCountry,
    String? addressCountry,
    double? pickupDistanceKm,
    int accountAgeDays = 0,
    int failedPayments24h = 0,
    int recentOrders24h = 0,
  }) async {
    int score = 0;
    final reasons = <String>[];
    final signals = <String, dynamic>{
      'orderTotal': orderTotal,
      'isDelivery': isDelivery,
      'ipCountry': ipCountry,
      'addressCountry': addressCountry,
      'pickupDistanceKm': pickupDistanceKm,
      'accountAgeDays': accountAgeDays,
      'failedPayments24h': failedPayments24h,
      'recentOrders24h': recentOrders24h,
    };

    // Heuristics
    if (accountAgeDays < 3) { score += 20; reasons.add('new_account'); }
    if (failedPayments24h >= 2) { score += 25; reasons.add('payment_velocity'); }
    if (recentOrders24h >= 5) { score += 20; reasons.add('order_velocity'); }
    if ((ipCountry?.isNotEmpty == true) && (addressCountry?.isNotEmpty == true) && ipCountry != addressCountry) {
      score += 20; reasons.add('country_mismatch');
    }
    if (pickupDistanceKm != null && pickupDistanceKm > 40) {
      score += 15; reasons.add('pickup_far_distance');
    }
    if (orderTotal >= 1500) { score += 25; reasons.add('high_value'); }
    if (!isDelivery && orderTotal >= 800) { score += 10; reasons.add('pickup_high_value'); }

    // Bound score
    score = min(100, score);
    return RiskResult(riskScore: score, reasons: reasons, signals: signals);
  }

  static Future<void> logRiskEvent({
    required String userId,
    required String context,
    required RiskResult result,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('risk_events').add({
        'userId': userId,
        'context': context,
        'riskScore': result.riskScore,
        'reasons': result.reasons,
        'signals': result.signals,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // ignore logging failures
    }
  }
}


