import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../screens/stunning_product_browser.dart';

class CompactRecommendedStores extends StatefulWidget {
  final String category;
  final int maxStores;
  final bool showDistance;

  const CompactRecommendedStores({
    Key? key,
    required this.category,
    this.maxStores = 3,
    this.showDistance = true,
  }) : super(key: key);

  @override
  State<CompactRecommendedStores> createState() => _CompactRecommendedStoresState();
}

class _CompactRecommendedStoresState extends State<CompactRecommendedStores> {
  List<Map<String, dynamic>> _recommendedStores = [];
  bool _isLoading = true;
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _loadRecommendedStores();
  }

  Future<void> _loadRecommendedStores() async {
    try {
      // Get user location
      _userPosition = await _getUserLocation();
      
      // Get stores from Firestore
      final storesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'seller')
          .where('status', isEqualTo: 'active')
          .where('storeCategory', isEqualTo: widget.category)
          .get();

      List<Map<String, dynamic>> stores = [];
      
      for (var doc in storesSnapshot.docs) {
        Map<String, dynamic> storeData = doc.data();
        storeData['storeId'] = doc.id;
        
        // Calculate distance if user location is available
        if (_userPosition != null) {
          double? storeLat = storeData['latitude'];
          double? storeLng = storeData['longitude'];
          
          if (storeLat != null && storeLng != null) {
            double distance = Geolocator.distanceBetween(
              _userPosition!.latitude,
              _userPosition!.longitude,
              storeLat,
              storeLng,
            ) / 1000; // Convert to km
            
            storeData['distance'] = distance;
          }
        }
        
        stores.add(storeData);
      }

      // Sort by rating and distance
      stores.sort((a, b) {
        double ratingA = (a['avgRating'] ?? 0.0).toDouble();
        double ratingB = (b['avgRating'] ?? 0.0).toDouble();
        
        if (ratingA != ratingB) {
          return ratingB.compareTo(ratingA); // Higher rating first
        }
        
        // If ratings are equal, sort by distance
        double distanceA = (a['distance'] ?? double.infinity).toDouble();
        double distanceB = (b['distance'] ?? double.infinity).toDouble();
        return distanceA.compareTo(distanceB);
      });

      setState(() {
        _recommendedStores = stores.take(widget.maxStores).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading recommended stores: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Position?> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting user location: $e');
      return null;
    }
  }

  String _formatDistance(double distance) {
    if (distance < 1) {
      return '${(distance * 1000).round()}m';
    } else {
      return '${distance.toStringAsFixed(1)}km';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_recommendedStores.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Text(
          'No recommended stores found',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recommended Stores',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepTeal,
                ),
              ),
              Text(
                '${_recommendedStores.length} stores',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.cloud,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _recommendedStores.length,
            itemBuilder: (context, index) {
              final store = _recommendedStores[index];
              return Container(
                width: 280,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildStoreCard(store),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> store) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StunningProductBrowser(
                storeId: store['storeId'],
                storeName: store['storeName'] ?? 'Store',
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store Image
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                image: DecorationImage(
                  image: NetworkImage(
                    store['profileImageUrl'] ?? 
                    'https://via.placeholder.com/280x120?text=Store',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            
            // Store Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Name
                  Text(
                    store['storeName'] ?? 'Store',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Rating
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        double rating = (store['avgRating'] ?? 0.0).toDouble();
                        if (index < rating.floor()) {
                          return const Icon(Icons.star, size: 14, color: Colors.orange);
                        } else if (index == rating.floor() && rating % 1 >= 0.5) {
                          return const Icon(Icons.star_half, size: 14, color: Colors.orange);
                        } else {
                          return const Icon(Icons.star_border, size: 14, color: Colors.orange);
                        }
                      }),
                      const SizedBox(width: 4),
                      Text(
                        '${(store['avgRating'] ?? 0.0).toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Distance and Delivery
                  Row(
                    children: [
                      if (widget.showDistance && store['distance'] != null) ...[
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: AppTheme.cloud,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _formatDistance(store['distance']),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.cloud,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (store['deliveryAvailable'] == true) ...[
                        Icon(
                          Icons.delivery_dining,
                          size: 12,
                          color: AppTheme.deepTeal,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Delivery',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.deepTeal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 