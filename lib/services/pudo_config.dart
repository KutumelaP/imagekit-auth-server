class PudoConfig {
  static bool isEnabled(Map<String, dynamic>? settings) {
    return (settings?['enabled'] ?? false) == true;
  }

  static double getPrice(String size, {String speed = 'standard', Map<String, dynamic>? pricing}) {
    try {
      final table = pricing ?? const {};
      final bySpeed = (table[speed] as Map?) ?? const {};
      final v = bySpeed[size];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    } catch (_) {
      return 0.0;
    }
  }
}




