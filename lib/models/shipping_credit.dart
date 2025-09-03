class ShippingCredit {
  final String method; // e.g., 'paxi' | 'pudo'
  final double amount; // credited to seller if buyer paid shipping
  final String settlementMode; // e.g., 'prepaid_wallet'
  final String carrier; // e.g., 'paxi' | 'pudo'

  const ShippingCredit({
    required this.method,
    required this.amount,
    required this.settlementMode,
    required this.carrier,
  });
}




