class DeliveryTimeUtils {
  /// Calculates a realistic delivery time in minutes based on distance, prep time, and current time.
  ///
  /// Logic mirrors existing implementation in CheckoutScreen:
  /// - Base preparation time (minutes)
  /// - Travel time assuming ~25 km/h average speed
  /// - Time-of-day adjustment: rush hour +50%, off-peak -20%
  /// - Weekend adjustment: +20%
  /// - Adds a small fixed buffer (5 min)
  /// - Rounds to nearest 5 minutes
  /// - Clamps between 20 and 120 minutes
  static int calculateRealisticDeliveryTime({
    required double distanceKm,
    required int basePrepTimeMinutes,
    required DateTime currentTime,
  }) {
    int totalMinutes = basePrepTimeMinutes;

    // Travel time (25 km/h average city speed)
    final double travelHours = distanceKm / 25.0;
    final int travelMinutes = (travelHours * 60).round();
    totalMinutes += travelMinutes;

    // Time of day adjustments
    final int hour = currentTime.hour;
    if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
      totalMinutes = (totalMinutes * 1.5).round(); // Rush hour
    } else if (hour >= 22 || hour <= 6) {
      totalMinutes = (totalMinutes * 0.8).round(); // Off-peak
    }

    // Weekend adjustment
    final int weekday = currentTime.weekday;
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      totalMinutes = (totalMinutes * 1.2).round();
    }

    // Fixed buffer
    totalMinutes += 5;

    // Round to nearest 5 minutes
    totalMinutes = ((totalMinutes / 5).round() * 5);

    // Clamp
    if (totalMinutes < 20) return 20;
    if (totalMinutes > 120) return 120;
    return totalMinutes;
  }
}
