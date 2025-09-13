class PickupPoint {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double fee;
  final bool isPaxi;
  final bool isPargo;

  PickupPoint({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.fee,
    this.isPaxi = false,
    this.isPargo = false,
  });
}

class PickupPointsService {
  static Future<List<PickupPoint>> fetchNearby({required double lat, required double lng, String? filter}) async {
    // TODO: Integrate with PAXI/Pargo SDK/APIs.
    return [];
  }
}

