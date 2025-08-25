import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
// import 'product_browsing_screen.dart';
import 'stunning_product_browser.dart';
import 'ChatScreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
// Unused heavy imports removed to reduce bundle size
import 'stunning_store_cards.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';
// import '../widgets/robust_image.dart';
import '../widgets/home_navigation_button.dart';
import 'simple_store_profile_screen.dart';
import '../widgets/safe_network_image.dart';

class StoreSelectionScreen extends StatefulWidget {
  final String category;

  const StoreSelectionScreen({super.key, required this.category});

  @override
  State<StoreSelectionScreen> createState() => _StoreSelectionScreenState();
}

class _StoreSelectionScreenState extends State<StoreSelectionScreen> {
  // Minimal state to avoid unused warnings and reduce memory
  bool _isAdmin = false; // reserved for future admin tools
  Set<String> _favoriteStoreIds = {};
  Map<String, int> _favoriteStoreCounts = {};

  // Search and filter variables
  String _searchQuery = '';
  String _activeFilter = 'all'; // all, nearby, delivery, verified

  @override
  void initState() {
    super.initState();
    // Simplified initialization to prevent crashes
    _checkIfAdmin();
    // Delay favorite fetching to prevent heavy operations on startup
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _fetchFavoriteStores();
      }
    });
  }

  Future<void> _checkIfAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _isAdmin = userDoc.data()?['role'] == 'admin';
        });
      }
    } catch (e) {
      print('Error checking admin status: $e');
      // Continue without admin privileges
    }
  }

  // Admin-only utilities (kept for future; currently unused)
  // ignore: unused_element
  Future<void> _deleteStore(String storeId, String storeName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Store?'),
        content: Text('Are you sure you want to delete "$storeName"? This will also delete all products, reviews, and orders for this store. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      // Delete user document
      await FirebaseFirestore.instance.collection('users').doc(storeId).delete();
      // Delete all products by this store
      final products = await FirebaseFirestore.instance.collection('products').where('ownerId', isEqualTo: storeId).get();
      final productIds = <String>[];
      for (final doc in products.docs) {
        productIds.add(doc.id);
        await doc.reference.delete();
      }
      // Delete all reviews for this store
      final reviews = await FirebaseFirestore.instance.collection('reviews').where('storeId', isEqualTo: storeId).get();
      for (final doc in reviews.docs) {
        await doc.reference.delete();
      }
      // Delete all orders for this store (as seller)
      final orders = await FirebaseFirestore.instance.collection('orders').where('sellerId', isEqualTo: storeId).get();
      for (final doc in orders.docs) {
        await doc.reference.delete();
      }
      // Delete all chats where sellerId matches
      final chats = await FirebaseFirestore.instance.collection('chats').where('sellerId', isEqualTo: storeId).get();
      for (final chatDoc in chats.docs) {
        // Delete all messages in the chat
        final messages = await chatDoc.reference.collection('messages').get();
        for (final msg in messages.docs) {
          await msg.reference.delete();
        }
        await chatDoc.reference.delete();
      }
      // Remove store's products from all favorites
      if (productIds.isNotEmpty) {
        final favorites = await FirebaseFirestore.instance.collection('favorites').get();
        for (final favDoc in favorites.docs) {
          final data = favDoc.data();
          if (data['productIds'] != null) {
            final List<dynamic> ids = List.from(data['productIds']);
            final updated = ids.where((id) => !productIds.contains(id)).toList();
            if (updated.length != ids.length) {
              await favDoc.reference.update({'productIds': updated});
            }
          }
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Store "$storeName" and all related data deleted')),
      );
      setState(() {}); // Refresh UI
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
  
  Future<void> _fetchFavoriteStores() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not authenticated, skipping favorite stores fetch');
        return;
      }
      final favDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favoriteStores')
          .get()
          .timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _favoriteStoreIds = favDocs.docs.map((doc) => doc.id).toSet();
        });
      }
    } catch (e) {
      print('Error fetching favorite stores: $e');
      // Continue without favorites
    }
  }

  // int _fetchStoreFavoriteCount is unused, remove heavy calls for now

  Future<List<Map<String, dynamic>>> _getApprovedStores() async {
    try {
      // Get all sellers from users collection (all store data is stored here)
    // For now, show all sellers regardless of status for testing
    print('🔍 DEBUG: Starting store query...');
    
    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'seller')
        .where('status', isEqualTo: 'approved')
        .get();

    print('🔍 DEBUG: Found ${userQuery.docs.length} sellers in database');
    
    if (userQuery.docs.isEmpty) {
      print('🔍 DEBUG: No sellers found in database');
      return [];
    }
    
    // Debug: Print all sellers and their status
    for (var doc in userQuery.docs) {
      final data = doc.data();
      print('🔍 DEBUG: Seller ${data['storeName'] ?? 'Unnamed'} - Status: ${data['status'] ?? 'no status'}, Verified: ${data['verified'] ?? false}');
    }

    // Get user location with proper permission handling
    Position? userPos;
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('🔍 DEBUG: Location services are disabled');
        userPos = null;
      } else {
        // Check location permission
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          print('🔍 DEBUG: Requesting location permission...');
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            print('🔍 DEBUG: Location permission denied');
            userPos = null;
          } else if (permission == LocationPermission.deniedForever) {
            print('🔍 DEBUG: Location permission denied forever');
            userPos = null;
          } else {
            print('🔍 DEBUG: Location permission granted, getting position...');
            userPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
            print('🔍 DEBUG: Got user position: ${userPos.latitude}, ${userPos.longitude}');
          }
        } else if (permission == LocationPermission.deniedForever) {
          print('🔍 DEBUG: Location permission denied forever');
          userPos = null;
        } else {
          print('🔍 DEBUG: Location permission already granted, getting position...');
          userPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          print('🔍 DEBUG: Got user position: ${userPos.latitude}, ${userPos.longitude}');
        }
      }
    } catch (e) {
      print('🔍 DEBUG: Error getting location: $e');
      userPos = null;
    }
      
    List<Map<String, dynamic>> storesWithProducts = [];

    for (final userDoc in userQuery.docs) {
      final storeId = userDoc.id;
      final userData = userDoc.data();
      
      print('🔍 DEBUG: Processing store: ${userData['storeName'] ?? 'Unnamed'}');
      print('🔍 DEBUG: - Status: ${userData['status'] ?? 'no status'}');
      print('🔍 DEBUG: - Verified: ${userData['verified'] ?? false}');
      print('🔍 DEBUG: - Paused: ${userData['paused'] ?? false}');
      
      if (userData['paused'] == true) {
        print('🔍 DEBUG: Skipping paused store: ${userData['storeName'] ?? 'Unnamed'}');
        continue; // Hide paused stores
      }
      

      
      // Get products for this store in the current category
      final productsQuery = await FirebaseFirestore.instance
          .collection('products')
          .where('ownerId', isEqualTo: storeId)
          .where('category', isEqualTo: widget.category)
          .limit(5)
          .get();

      // Also get products from all categories for this store (for image display)
      final allProductsQuery = await FirebaseFirestore.instance
          .collection('products')
          .where('ownerId', isEqualTo: storeId)
          .limit(5)
          .get();

      // Filter by store category if specified
      final storeCategory = userData['storeCategory'] as String?;
      
      // Apply category filtering for specific categories (not "All" or "Other")
      if (widget.category != 'All' && widget.category != 'Other') {
        bool shouldShowStore = false;
        
        // If store has a category field, check if it matches
        if (storeCategory != null) {
          final storeCategoryLower = storeCategory.toLowerCase();
          final widgetCategoryLower = widget.category.toLowerCase();
          
          // Check for exact match or common variations
          shouldShowStore = storeCategoryLower == widgetCategoryLower ||
                           storeCategoryLower.contains(widgetCategoryLower) ||
                           widgetCategoryLower.contains(storeCategoryLower) ||
                           // Common variations
                           (storeCategoryLower.contains('cloth') && widgetCategoryLower.contains('cloth')) ||
                           (storeCategoryLower.contains('wear') && widgetCategoryLower.contains('wear')) ||
                           (storeCategoryLower.contains('fashion') && widgetCategoryLower.contains('fashion')) ||
                           (storeCategoryLower.contains('food') && widgetCategoryLower.contains('food')) ||
                           (storeCategoryLower.contains('electronics') && widgetCategoryLower.contains('electronics'));
        } else {
          // If store doesn't have a category field, check if it has products in this category
          final productsInCategory = productsQuery.docs.length;
          shouldShowStore = productsInCategory > 0;
        }
        
        if (!shouldShowStore) {
          print('🔍 DEBUG: Store ${userData['storeName']} filtered out:');
          print('  - Store category: $storeCategory');
          print('  - Widget category: ${widget.category}');
          print('  - Products in category: ${productsQuery.docs.length}');
          continue; // Skip this store
        }
      }
      
      // For "All" category, show all stores (no filtering)
      if (widget.category == 'All') {
        print('🔍 DEBUG: Store ${userData['storeName']} shown in All category');
      }
      
      // For "Other" category, show stores that don't fit into specific categories
      if (widget.category == 'Other') {
        if (storeCategory != null && 
            (storeCategory.toLowerCase().contains('food') ||
             storeCategory.toLowerCase().contains('cloth') ||
             storeCategory.toLowerCase().contains('electronics'))) {
          print('🔍 DEBUG: Store ${userData['storeName']} filtered out from Other category:');
          print('  - Store category: $storeCategory');
          continue; // Skip this store from "Other" category
        }
      }
      
      // Get product images from ALL categories (not just current category) - limit to 3
      final productImages = allProductsQuery.docs
          .map((doc) {
            // Try multiple possible image field names
            final imageUrl = doc['imageUrl'] ?? doc['image'] ?? doc['photoUrl'] ?? doc['photo'] ?? doc['images']?[0];
            
            // Additional validation for image URL
            if (imageUrl != null && imageUrl is String && imageUrl.isNotEmpty) {
              // Check if URL is valid
              try {
                final uri = Uri.parse(imageUrl);
                if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
                  print('🔍 DEBUG: Valid image URL found: $imageUrl');
                  return imageUrl;
                } else {
                  print('🔍 DEBUG: Invalid URL scheme for product ${doc.id}: $imageUrl');
                }
              } catch (e) {
                print('🔍 DEBUG: Invalid image URL for product ${doc.id}: $imageUrl (Error: $e)');
              }
            } else {
              print('🔍 DEBUG: No valid image URL found for product ${doc.id}');
            }
            return null;
          })
          .where((url) => url != null && url.isNotEmpty)
          .cast<String>()
          .take(3) // Limit to 3 images to reduce load
          .toList();
      
      // Debug product images
      print('🔍 DEBUG: Store ${userData['storeName']} product images:');
      print('  - Products in current category: ${productsQuery.docs.length}');
      print('  - Total products for store: ${allProductsQuery.docs.length}');
      if (allProductsQuery.docs.isNotEmpty) {
        print('  - First product data: ${allProductsQuery.docs.first.data()}');
        print('  - First product imageUrl: ${allProductsQuery.docs.first.data()['imageUrl']}');
        print('  - First product image field: ${allProductsQuery.docs.first.data()['image']}');
        print('  - First product photoUrl field: ${allProductsQuery.docs.first.data()['photoUrl']}');
      }
      print('  - Product images: $productImages');
      print('  - Profile image: ${userData['profileImageUrl']}');
          
      // Show store even if no products in this category
      // This ensures all approved sellers are visible
          
      final review = await _getStoreReviewSummary(storeId);
      final storeLat = _parseCoordinate(userData['latitude']);
      final storeLng = _parseCoordinate(userData['longitude']);
      final deliveryRangeRaw = (userData['deliveryRange'] ?? 0.0).toDouble();
      final bool deliveryAvailable = userData['deliveryAvailable'] == true;
      final bool pargoEnabled = userData['pargoEnabled'] == true;
      final bool paxiEnabled = userData['paxiEnabled'] == true;
      final String category = (userData['storeCategory'] ?? '').toString();
      // Category caps (can be tuned or moved to config)
      const double foodCapKm = 20.0;
      const double nonFoodDeliveryCapKm = 50.0;
      const double pickupFoodDefaultKm = 12.0;
      const double pickupNonFoodDefaultKm = 30.0;
      const double noDeliveryNoPickupDefaultKm = 5.0;
      // Compute service radius
      double serviceRadiusKm;
      final bool hasPickup = pargoEnabled || paxiEnabled;
      final bool isFood = _isFoodCategory(category);
      if (deliveryAvailable && deliveryRangeRaw > 0) {
        serviceRadiusKm = isFood
            ? deliveryRangeRaw.clamp(1.0, foodCapKm)
            : deliveryRangeRaw.clamp(1.0, nonFoodDeliveryCapKm);
      } else if (hasPickup) {
        serviceRadiusKm = isFood ? pickupFoodDefaultKm : pickupNonFoodDefaultKm;
      } else {
        serviceRadiusKm = noDeliveryNoPickupDefaultKm;
      }
      double? distance;
      bool inRange = true;
      
      // Remove profile image from product images to avoid duplication
      final cleanProductImages = productImages.where((url) => 
        url != userData['profileImageUrl']
      ).toList();
      
      // Debug the cleaning process
      print('🔍 DEBUG: Image cleaning for ${userData['storeName']}:');
      print('  - Original product images: $productImages');
      print('  - Profile image: ${userData['profileImageUrl']}');
      print('  - Cleaned product images: $cleanProductImages');
      print('  - Images removed: ${productImages.length - cleanProductImages.length}');
      print('  - Final image count: ${cleanProductImages.length}');
      
      // Check if any images were removed due to profile image duplication
      if (productImages.length != cleanProductImages.length) {
        print('🔍 DEBUG: Some images were removed because they match the profile image');
      }
      
      // Calculate distance if we have both user and store locations
      if (userPos != null && storeLat != null && storeLng != null) {
        // Debug: Print store coordinates
        print('🔍 DEBUG: Store ${userData['storeName']} coordinates: $storeLat, $storeLng');
        print('🔍 DEBUG: User coordinates: ${userPos.latitude}, ${userPos.longitude}');
        
        // Check if user coordinates look like mock/test coordinates (San Francisco area)
        final isMockLocation = (userPos.latitude > 37.0 && userPos.latitude < 38.0 && 
                              userPos.longitude > -123.0 && userPos.longitude < -122.0);
        
        if (isMockLocation) {
          print('🔍 DEBUG: Detected mock location (San Francisco area), showing all stores');
          inRange = true; // Show all stores if using mock location
        } else {
          distance = Geolocator.distanceBetween(
            userPos.latitude,
            userPos.longitude,
            storeLat,
            storeLng,
          ) / 1000;
          
          // Check if store is within service radius
          inRange = distance <= serviceRadiusKm;
          // Nationwide pickup override: show non-food pickup stores regardless of distance
          if (_activeFilter == 'nationwide' && hasPickup && !isFood) {
            inRange = true;
          }
          
          print('🔍 DEBUG: Store ${userData['storeName']} - Distance: ${distance.toStringAsFixed(1)}km, ServiceRadius: ${serviceRadiusKm.toStringAsFixed(1)}km, In Range: $inRange, Delivery: $deliveryAvailable/$deliveryRangeRaw km, Pickup: $hasPickup, Category: $category');
        }
      } else {
        // If we can't calculate distance, do not show (requires location for local-first discovery)
        inRange = false;
        // Nationwide pickup override: include non-food pickup stores even without user coords
        if (_activeFilter == 'nationwide' && hasPickup && !isFood) {
          inRange = true;
        }
        print('🔍 DEBUG: Store ${userData['storeName']} - Could not calculate distance, ' + (inRange ? 'showing due to nationwide pickup' : 'hiding store (no user/store coords)'));
      }
      
      // Fetch favoriteCount for this store
      int favoriteCount = userData['favoriteCount'] ?? 0;
      _favoriteStoreCounts[storeId] = favoriteCount;
      
      if (inRange) {
        // Debug: Print the store data being prepared
        print('🔍 DEBUG: Preparing store data for ${userData['storeName']}:');
        print('  - storyPhotoUrls: ${userData['storyPhotoUrls']}');
        print('  - storyVideoUrl: ${userData['storyVideoUrl']}');
        print('  - passion: ${userData['passion']}');
        print('  - specialties: ${userData['specialties']}');
        print('  - story: ${userData['story']}');
        print('  - Raw userData keys: ${userData.keys.toList()}');
        
        storesWithProducts.add({
          'storeId': storeId,
          'storeName': userData['storeName'] ?? 'Unnamed Store',
          'location': userData['location'] ?? 'Unknown location',
          'profileImageUrl': userData['profileImageUrl'] as String?,
          'productImages': cleanProductImages, // Use cleaned product images
          'avgRating': review['avgRating'],
          'reviewCount': review['reviewCount'],
          'isStoreOpen': userData['isStoreOpen'] ?? false,
          'productSnippetImages': cleanProductImages.length > 3 ? cleanProductImages.sublist(0, 3) : cleanProductImages,
          'distance': distance,
          'story': userData['story'],
          'status': userData['status'] ?? '',
          'contact': userData['contact'] ?? '',
          'favoriteCount': favoriteCount,
          'introVideoUrl': userData['introVideoUrl'] as String?,
          // Add delivery fields
          'deliveryAvailable': userData['deliveryAvailable'] ?? false,
          'deliveryRange': deliveryRangeRaw,
          // Add story media fields
          'storyPhotoUrls': userData['storyPhotoUrls'] as List<dynamic>?,
          'storyVideoUrl': userData['storyVideoUrl'] as String?,
          'passion': userData['passion'] as String?,
          'specialties': userData['specialties'] as List<dynamic>?,
          'category': userData['storeCategory'] as String?,
          'isVerified': userData['isVerified'] ?? false, // Add isVerified field
          'storeOpenHour': userData['storeOpenHour'] as String?,
          'storeCloseHour': userData['storeCloseHour'] as String?,
          'pargoEnabled': pargoEnabled,
          'paxiEnabled': paxiEnabled,
        });
      }
    }

    return storesWithProducts;
      
    } catch (e) {
      print('ERROR in _getApprovedStores: $e');
      return [];
    }
  }

  // Helper method to parse coordinates from various types
  double? _parseCoordinate(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      // Trim whitespace and normalize comma decimals
      final normalized = value.trim().replaceAll(',', '.');
      if (normalized.isEmpty) return null;
      return double.tryParse(normalized);
    }
    return null;
  }

  bool _isFoodCategory(String category) {
    final c = category.toLowerCase();
    return c.contains('food') || c.contains('meal') || c.contains('bak') || c.contains('pastr') || c.contains('dessert') || c.contains('beverage') || c.contains('drink') || c.contains('coffee') || c.contains('tea') || c.contains('fruit') || c.contains('vegetable') || c.contains('produce') || c.contains('snack');
  }

  bool userLatLngValid(Position? userPos, dynamic storeLat, dynamic storeLng, double deliveryRange) {
    return userPos != null && storeLat != null && storeLng != null && deliveryRange > 0;
  }

  bool _isStoreCurrentlyOpen(Map<String, dynamic> store) {
    // First check: Manual store toggle (seller can manually close store)
    if (store['isStoreOpen'] == false) {
      return false; // Seller manually closed the store - always respect this
    }
    
    // Second check: Automatic hours (if store is manually "open", check if within hours)
    final storeOpenHour = store['storeOpenHour'] as String?;
    final storeCloseHour = store['storeCloseHour'] as String?;
    
    if (storeOpenHour == null || storeCloseHour == null) {
      return store['isStoreOpen'] ?? false; // Fallback to manual store open status if no hours set
    }
    
    try {
      final now = DateTime.now();
      final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);
      
      // Parse store hours
      final openParts = storeOpenHour.split(':');
      final closeParts = storeCloseHour.split(':');
      
      if (openParts.length != 2 || closeParts.length != 2) {
        return store['isStoreOpen'] ?? false; // Fallback if time format is invalid
      }
      
      final openHour = int.parse(openParts[0]);
      final openMinute = int.parse(openParts[1]);
      final closeHour = int.parse(closeParts[0]);
      final closeMinute = int.parse(closeParts[1]);
      
      final openTime = TimeOfDay(hour: openHour, minute: openMinute);
      final closeTime = TimeOfDay(hour: closeHour, minute: closeMinute);
      
      // Convert to minutes for easier comparison
      final currentMinutes = currentTime.hour * 60 + currentTime.minute;
      final openMinutes = openTime.hour * 60 + openTime.minute;
      final closeMinutes = closeTime.hour * 60 + closeTime.minute;
      
      bool withinOperatingHours;
      // Handle cases where store is open past midnight
      if (closeMinutes < openMinutes) {
        // Store closes after midnight
        withinOperatingHours = currentMinutes >= openMinutes || currentMinutes <= closeMinutes;
      } else {
        // Store closes on the same day
        withinOperatingHours = currentMinutes >= openMinutes && currentMinutes <= closeMinutes;
      }
      
      // Combined logic: Store is open if manual toggle is true AND within operating hours
      return (store['isStoreOpen'] ?? true) && withinOperatingHours;
      
    } catch (e) {
      return store['isStoreOpen'] ?? false; // Fallback to manual store open status
    }
  }

  String _getStoreStatusText(Map<String, dynamic> store) {
    // Check manual toggle first
    if (store['isStoreOpen'] == false) {
      return 'Temp Closed';
    }
    
    // Check if we have operating hours
    final storeOpenHour = store['storeOpenHour'] as String?;
    final storeCloseHour = store['storeCloseHour'] as String?;
    
    if (storeOpenHour == null || storeCloseHour == null) {
      return store['isStoreOpen'] == true ? 'Open' : 'Closed';
    }
    
    // Check if within operating hours
    try {
      final now = DateTime.now();
      final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);
      
      final openParts = storeOpenHour.split(':');
      final closeParts = storeCloseHour.split(':');
      
      if (openParts.length != 2 || closeParts.length != 2) {
        return store['isStoreOpen'] == true ? 'Open' : 'Closed';
      }
      
      final openHour = int.parse(openParts[0]);
      final openMinute = int.parse(openParts[1]);
      final closeHour = int.parse(closeParts[0]);
      final closeMinute = int.parse(closeParts[1]);
      
      final openTime = TimeOfDay(hour: openHour, minute: openMinute);
      final closeTime = TimeOfDay(hour: closeHour, minute: closeMinute);
      
      final currentMinutes = currentTime.hour * 60 + currentTime.minute;
      final openMinutes = openTime.hour * 60 + openTime.minute;
      final closeMinutes = closeTime.hour * 60 + closeTime.minute;
      
      bool withinOperatingHours;
      if (closeMinutes < openMinutes) {
        withinOperatingHours = currentMinutes >= openMinutes || currentMinutes <= closeMinutes;
      } else {
        withinOperatingHours = currentMinutes >= openMinutes && currentMinutes <= closeMinutes;
      }
      
      if (store['isStoreOpen'] == true && withinOperatingHours) {
        return 'Open';
      } else if (store['isStoreOpen'] == true && !withinOperatingHours) {
        return 'Closed (Hours)';
      } else {
        return 'Closed';
      }
    } catch (e) {
      return store['isStoreOpen'] == true ? 'Open' : 'Closed';
    }
  }

  // ignore: unused_element
  Future<void> _toggleFavoriteStore(String storeId, String storeName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final favRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('favoriteStores').doc(storeId);
    final storeRef = FirebaseFirestore.instance.collection('users').doc(storeId);
    final isFav = _favoriteStoreIds.contains(storeId);
    setState(() {
      if (isFav) {
        _favoriteStoreIds.remove(storeId);
        _favoriteStoreCounts[storeId] = (_favoriteStoreCounts[storeId] ?? 1) - 1;
      } else {
        _favoriteStoreIds.add(storeId);
        _favoriteStoreCounts[storeId] = (_favoriteStoreCounts[storeId] ?? 0) + 1;
      }
    });
    if (isFav) {
      await favRef.delete();
      await storeRef.update({'favoriteCount': FieldValue.increment(-1)});
    } else {
      await favRef.set({'storeName': storeName, 'timestamp': FieldValue.serverTimestamp()});
      await storeRef.update({'favoriteCount': FieldValue.increment(1)});
    }
  }

  Widget buildReviewStars(double avg, int count) {
  final full = avg.floor();
  final half = avg - full >= 0.5;
  return Row(
    children: [
      for (int i = 0; i < full; i++)
        const Icon(Icons.star, size: 14, color: Colors.orange),
      if (half) const Icon(Icons.star_half, size: 14, color: Colors.orange),
      for (int i = 0; i < 5 - full - (half ? 1 : 0); i++)
        const Icon(Icons.star_border, size: 14, color: Colors.orange),
      const SizedBox(width: 4),
      Text('($count)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ],
  );
}


  Widget buildMainStoreImage(String? profileImageUrl, List<String> productImages) {
    final responsiveHeight = ResponsiveUtils.isMobile(context) ? 160.0 : 180.0;
    
    if (productImages.isNotEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: SizedBox(
          height: responsiveHeight,
          child: PageView.builder(
            itemCount: productImages.length,
            itemBuilder: (context, index) {
              return SafeNetworkImage(
                imageUrl: productImages[index],
                fit: BoxFit.cover,
                width: double.infinity,
                errorWidget: Container(
                  width: double.infinity,
                  height: responsiveHeight,
                  color: AppTheme.cloud,
                  child: Icon(
                    Icons.image,
                    color: AppTheme.deepTeal,
                    size: ResponsiveUtils.getIconSize(context, baseSize: 48),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      return SafeNetworkImage(
        imageUrl: profileImageUrl,
        height: responsiveHeight,
        width: double.infinity,
        fit: BoxFit.cover,
        errorWidget: Container(
          width: double.infinity,
          height: responsiveHeight,
          color: AppTheme.cloud,
          child: Icon(
            Icons.store,
            color: AppTheme.deepTeal,
            size: ResponsiveUtils.getIconSize(context, baseSize: 48),
          ),
        ),
      );
    } else {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Container(
          height: responsiveHeight,
          color: AppTheme.cloud,
          child: Icon(
            Icons.store, 
            size: ResponsiveUtils.getIconSize(context, baseSize: 60), 
            color: AppTheme.deepTeal
          ),
        ),
      );
    }
  }

  Widget buildProductSnippet(List<String> snippetImages) {
    if (snippetImages.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: SizedBox(
        height: 70,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: snippetImages.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          addSemanticIndexes: false,
          cacheExtent: 300,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final imgUrl = snippetImages[index];
            return SafeNetworkImage(
              imageUrl: imgUrl,
              width: 70,
              height: 70,
              borderRadius: BorderRadius.circular(8),

            );
          },
        ),
      ),
    );
  }
Future<Map<String, dynamic>> _getStoreReviewSummary(String storeId) async {
  final snapshot = await FirebaseFirestore.instance
    .collection('reviews')
    .where('storeId', isEqualTo: storeId)
    .get();

  if (snapshot.docs.isEmpty) return {'avgRating': 0.0, 'reviewCount': 0};

  final ratings = snapshot.docs
      .map((d) => (d.data()['rating'] ?? 0).toDouble())
      .toList();
  final avg = ratings.reduce((a, b) => a + b) / ratings.length;
  return {'avgRating': avg, 'reviewCount': ratings.length};
}

Future<void> _contactStore(String storeId, String storeName) async {
  print('Contact Store called with storeId: $storeId, storeName: $storeName');
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please login to contact the store')),
    );
    return;
  }

  // Check if chat already exists
  final query = await FirebaseFirestore.instance
      .collection('chats')
      .where('buyerId', isEqualTo: currentUser.uid)
      .where('sellerId', isEqualTo: storeId)
      .where('productId', isEqualTo: '') // Empty for store-level chat
      .limit(1)
      .get();

  String chatId;
  if (query.docs.isNotEmpty) {
    chatId = query.docs.first.id;
  } else {
    // Create new store-level chat
    final newChat = await FirebaseFirestore.instance.collection('chats').add({
      'buyerId': currentUser.uid,
      'sellerId': storeId,
      'productId': '', // Empty for store-level chat
      'lastMessage': '',
      'timestamp': FieldValue.serverTimestamp(),
      'participants': [currentUser.uid, storeId],
      'productName': 'Store: $storeName',
    });
    chatId = newChat.id;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        chatId: chatId,
        otherUserId: storeId,
        otherUserName: storeName,
      ),
    ),
  );
}

void _showLeaveReviewDialog(String storeId) {
  double rating = 5.0;
  String comment = '';

  // Debug logging
  print('DEBUG: Opening review dialog for storeId: $storeId');

  showDialog(
    context: context,
    barrierDismissible: false, // Prevent accidental dismissal
    builder: (ctx) {
      double dialogRating = rating; // local state for slider
      String dialogComment = comment;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Leave a Review'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Rating: ${dialogRating.toStringAsFixed(1)}'),
                Slider(
                  min: 1, max: 5, divisions: 8, value: dialogRating,
                  label: dialogRating.toStringAsFixed(1),
                  onChanged: (v) => setState(() => dialogRating = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Comment (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (v) => dialogComment = v,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  print('DEBUG: Review dialog cancelled');
                  Navigator.pop(ctx);
                }, 
                child: const Text('Cancel')
              ),
              ElevatedButton(
                onPressed: () async {
                  print('DEBUG: Submitting review...');
                  print('DEBUG: StoreId: $storeId');
                  print('DEBUG: Rating: $dialogRating');
                  print('DEBUG: Comment: $dialogComment');
                  
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      print('DEBUG: User authenticated: ${user.uid}');
                      
                      // Add the review to Firestore
                      await FirebaseFirestore.instance.collection('reviews').add({
                        'storeId': storeId,
                        'userId': user.uid,
                        'rating': dialogRating,
                        'comment': dialogComment,
                        'timestamp': FieldValue.serverTimestamp(),
                        'userEmail': user.email,
                        'userName': user.displayName ?? 'Anonymous',
                      });
                      
                      print('DEBUG: Review submitted successfully');
                      Navigator.pop(ctx);
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Review submitted successfully!'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 3),
                          )
                        );
                      }
                      
                      // Refresh the UI to show the new review
                      setState(() {});
                    } else {
                      print('DEBUG: User not authenticated');
                      Navigator.pop(ctx);
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (loginCtx) => AlertDialog(
                            title: const Text('Login Required'),
                            content: const Text('You need to be logged in to leave a review. Would you like to log in now?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(loginCtx),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(loginCtx);
                                  Navigator.pushNamed(context, '/login');
                                },
                                child: const Text('Login'),
                              ),
                            ],
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    print('ERROR: Failed to submit review: $e');
                    Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error submitting review: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        )
                      );
                    }
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          );
        }
      );
    },
  );
}

void _navigateToStoreProfile(Map<String, dynamic> store) {
  print('DEBUG: Navigating to store profile with data: $store');
  print('DEBUG: Distance value: ${store['distance']}');
  print('DEBUG: Store story data:');
  print('  - story: ${store['story']}');
  print('  - storyPhotoUrls: ${store['storyPhotoUrls']}');
  print('  - storyVideoUrl: ${store['storyVideoUrl']}');
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SimpleStoreProfileScreen(store: store),
    ),
  );
}

  Widget _buildStoreCard(Map<String, dynamic> store, int index) {
              return GestureDetector(
                onTap: () {
        // Navigate to product browsing for this specific store
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
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getHorizontalPadding(context),
          vertical: ResponsiveUtils.getVerticalPadding(context) / 2,
        ),
        constraints: BoxConstraints(
          maxWidth: ResponsiveUtils.getCardWidth(context),
        ),
  decoration: BoxDecoration(
            gradient: AppTheme.cardBackgroundGradient,
          borderRadius: BorderRadius.circular(16),
          // Special styling for stores with stories
          boxShadow: store['story'] != null && store['story'].toString().isNotEmpty
              ? [
      BoxShadow(
                    color: AppTheme.deepTeal.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: AppTheme.deepTeal.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppTheme.deepTeal.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
      ),
    ],
          border: store['story'] != null && store['story'].toString().isNotEmpty
              ? Border.all(
                  color: AppTheme.deepTeal.withOpacity(0.1),
                  width: 1,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Slideshow Header
            // Debug what's being passed to slideshow
            Builder(
              builder: (context) {
                // Debug what's being passed to slideshow
                print('🔍 DEBUG: Calling slideshow for ${store['storeName']}:');
                print('  - Store ID: ${store['storeId']}');
                print('  - Product images: ${store['productImages']}');
                print('  - Profile image: ${store['profileImageUrl']}');
                return _buildProductSlideshow(
              store['storeId'],
              store['productImages'] as List<String>? ?? [],
              store['profileImageUrl'] as String?,
              store: store,
                );
              },
            ),
            
            // Store Info Section
            Padding(
              padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Name and Location
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Store Avatar - Responsive size
                      Container(
                        width: ResponsiveUtils.isMobile(context) ? 45 : 50,
                        height: ResponsiveUtils.isMobile(context) ? 45 : 50,
              decoration: BoxDecoration(
                          shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppTheme.deepTeal, AppTheme.cloud],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.deepTeal.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                backgroundColor: Colors.transparent,
                backgroundImage: store['profileImageUrl'] != null && store['profileImageUrl'].toString().isNotEmpty
                    ? NetworkImage(store['profileImageUrl'])
                    : null,
                onBackgroundImageError: store['profileImageUrl'] != null && store['profileImageUrl'].toString().isNotEmpty
                    ? (exception, stackTrace) {
                        print('Error loading store profile image: $exception');
                      }
                    : null,
                child: store['profileImageUrl'] == null || store['profileImageUrl'].toString().isEmpty
                    ? Text(
                        store['storeName']?.substring(0, 1).toUpperCase() ?? 'S',
                        style: TextStyle(
                          color: AppTheme.angel,
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveUtils.isMobile(context) ? 16 : 18,
                        ),
                      )
                    : null,
              ),
                      ),
                      
                      SizedBox(width: ResponsiveUtils.isMobile(context) ? 8 : 12),
                      
                      // Store Info - Flexible to prevent overflow
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                      children: [
                        Expanded(
                          child: Text(
                            store['storeName'] ?? 'Store Name',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.isMobile(context) ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.deepTeal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (store['isVerified'] == true)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryGreen.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Verified',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                            SizedBox(height: ResponsiveUtils.isMobile(context) ? 2 : 4),
                            Row(
                children: [
                                Icon(
                                  Icons.location_on,
                                  size: ResponsiveUtils.getIconSize(context, baseSize: 14),
                                  color: AppTheme.cloud,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: SafeUI.safeText(
                  store['location'] ?? 'Location not set',
                                    style: ResponsiveUtils.safeTextStyle(
                                      context,
                                      AppTheme.bodyMedium.copyWith(
                    color: AppTheme.cloud,
                                      ),
                  ),
                  maxLines: 1,
                                  ),
                                ),
                              ],
                ),
                if (store['distance'] != null && store['distance'] != 'N/A') ...[
                  const SizedBox(height: 2),
                  SafeUI.safeText(
                                '${store['distance']}km away',
                                style: ResponsiveUtils.safeTextStyle(
                                  context,
                                  AppTheme.bodySmall.copyWith(
                      color: AppTheme.breeze,
                      fontWeight: FontWeight.w500,
                                  ),
                    ),
                    maxLines: 1,
                  ),
                ],
                
                // Store Status and Delivery Range
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Store Status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isStoreCurrentlyOpen(store) 
                          ? AppTheme.primaryGreen.withOpacity(0.1)
                          : AppTheme.primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isStoreCurrentlyOpen(store) 
                            ? AppTheme.primaryGreen
                            : AppTheme.primaryRed,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isStoreCurrentlyOpen(store) 
                              ? Icons.store
                              : Icons.store_mall_directory,
                            size: 12,
                            color: _isStoreCurrentlyOpen(store) 
                              ? AppTheme.primaryGreen
                              : AppTheme.primaryRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getStoreStatusText(store),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _isStoreCurrentlyOpen(store) 
                                ? AppTheme.primaryGreen
                                : AppTheme.primaryRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Operating Hours
                    if (store['storeOpenHour'] != null && store['storeCloseHour'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.deepTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.deepTeal,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: AppTheme.deepTeal,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              TimeUtils.formatTimeRangeToAmPm(
                                store['storeOpenHour'] ?? '08:00',
                                store['storeCloseHour'] ?? '18:00',
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.deepTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(width: 8),
                    
                    // Delivery Range
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (store['deliveryAvailable'] == true) 
                          ? AppTheme.deepTeal.withOpacity(0.1)
                          : AppTheme.mediumGrey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (store['deliveryAvailable'] == true) 
                            ? AppTheme.deepTeal
                            : AppTheme.mediumGrey,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (store['deliveryAvailable'] == true) 
                              ? Icons.delivery_dining
                              : Icons.store,
                            size: 12,
                            color: (store['deliveryAvailable'] == true) 
                              ? AppTheme.deepTeal
                              : AppTheme.mediumGrey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (store['deliveryAvailable'] == true) 
                              ? '${(store['distance'] != null ? store['distance'].toStringAsFixed(1) : (store['deliveryRange'] ?? 1000).toStringAsFixed(0))}km away'
                              : 'Pick up',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: (store['deliveryAvailable'] == true) 
                                ? AppTheme.deepTeal
                                : AppTheme.mediumGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                          ],
                        ),
                      ),
                      
                      // Meet the Baker/Chef Button (instead of store icon)
                      Container(
                        constraints: BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SimpleStoreProfileScreen(store: store),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.deepTeal,
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.isMobile(context) ? 6 : 8,
                              vertical: ResponsiveUtils.isMobile(context) ? 2 : 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                                Icons.auto_stories,
                                color: AppTheme.deepTeal,
                        size: ResponsiveUtils.getIconSize(context, baseSize: 16),
                      ),
                              if (!ResponsiveUtils.isMobile(context)) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Story',
                          style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.deepTeal,
                            fontWeight: FontWeight.w500,
                        ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: ResponsiveUtils.isMobile(context) ? 8 : 12),
                  
                  // Reviews Section
                  if (store['avgRating'] > 0) 
                    _buildRatingRow(store)
                  else
                    Text(
                      'No reviews yet',
                      style: ResponsiveUtils.safeTextStyle(
                        context,
                        AppTheme.bodyMedium.copyWith(
                          color: AppTheme.cloud,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  
                  // Story Teaser Section - Makes story feature discoverable
                  if (store['story'] != null && store['story'].toString().isNotEmpty) ...[
                    SizedBox(height: ResponsiveUtils.isMobile(context) ? 8 : 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SimpleStoreProfileScreen(store: store),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.isMobile(context) ? 10 : 12,
                          vertical: ResponsiveUtils.isMobile(context) ? 8 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.deepTeal.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.deepTeal.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_stories,
                              color: AppTheme.deepTeal,
                size: ResponsiveUtils.getIconSize(context, baseSize: 16),
                        ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ResponsiveUtils.isMobile(context) ? 'Brand' : 'Behind the Brand',
                                    style: ResponsiveUtils.safeTextStyle(
                                      context,
                                      AppTheme.bodyMedium.copyWith(
                                        color: AppTheme.deepTeal,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  SafeUI.safeText(
                                    store['story'].toString().length > 80 
                                        ? '${store['story'].toString().substring(0, 80)}...'
                                        : store['story'].toString(),
                                    style: ResponsiveUtils.safeTextStyle(
                                      context,
                                      AppTheme.bodySmall.copyWith(
                                        color: AppTheme.cloud,
                                        height: 1.3,
                                      ),
                                    ),
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: AppTheme.deepTeal,
                              size: ResponsiveUtils.getIconSize(context, baseSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  SizedBox(height: ResponsiveUtils.isMobile(context) ? 12 : 16),
                  
                  // Action Buttons - Three-button layout showcasing all features
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final hasStory = store['story'] != null && store['story'].toString().isNotEmpty;
                      
                      // On very small screens, stack buttons vertically
                      if (constraints.maxWidth < 300) {
                        return Column(
                          children: [
                            _buildActionButton(
                              onPressed: () {
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
                              icon: Icons.shopping_bag,
                              label: 'View Products',
                              isOutlined: false,
                            ),
                            if (hasStory) ...[
                              const SizedBox(height: 6),
                              _buildActionButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SimpleStoreProfileScreen(store: store),
                                    ),
                                  );
                                },
                                icon: Icons.business,
                                label: ResponsiveUtils.isMobile(context) ? 'Brand' : 'Behind the Brand',
                                isOutlined: true,
                              ),
                            ],
                            const SizedBox(height: 6),
                            _buildActionButton(
                              onPressed: () => _showLeaveReviewDialog(store['storeId']),
                              icon: Icons.star_outline,
                              label: 'Leave Review',
                              isOutlined: true,
                            ),
                          ],
                        );
                      } else {
                        // Horizontal layout with 2 or 3 buttons
                        return Row(
                          children: [
                            Expanded(
                              flex: hasStory ? 3 : 2,
                              child: _buildActionButton(
                                onPressed: () {
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
                                icon: Icons.shopping_bag,
                                label: ResponsiveUtils.isMobile(context) ? 'Products' : 'View Products',
                                isOutlined: false,
                              ),
                            ),
                            if (hasStory) ...[
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: _buildActionButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SimpleStoreProfileScreen(store: store),
                                      ),
                                    );
                                  },
                                  icon: Icons.auto_stories,
                                  label: ResponsiveUtils.isMobile(context) ? 'Brand' : 'Behind the Brand',
                                  isOutlined: true,
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildActionButton(
                                onPressed: () {
                                  print('DEBUG: Review button pressed in store page');
                                  print('DEBUG: Store ID: ${store['storeId']}');
                                  print('DEBUG: Context mounted: ${context.mounted}');
                                  _showLeaveReviewDialog(store['storeId']);
                                },
                                icon: Icons.star_outline,
                                label: ResponsiveUtils.isMobile(context) ? 'Review' : 'Review',
                                isOutlined: true,
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getBakerTitle(String category) {
    switch (category.toLowerCase()) {
      case 'bakery':
      case 'baked goods':
      case 'pastries':
      case 'desserts':
        return 'Baker';
      case 'food':
      case 'meals':
      case 'cuisine':
      case 'cooking':
        return 'Chef';
      case 'beverages':
      case 'drinks':
      case 'coffee':
      case 'tea':
        return 'Barista';
      case 'fruits':
      case 'vegetables':
      case 'produce':
        return 'Farmer';
      case 'snacks':
      case 'treats':
        return 'Maker';
      default:
        return 'Seller';
    }
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required bool isOutlined,
  }) {
    final buttonStyle = isOutlined
        ? OutlinedButton.styleFrom(
            foregroundColor: AppTheme.warmAccentColor,
            side: BorderSide(color: AppTheme.warmAccentColor),
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveUtils.isMobile(context) ? 6 : 8,
              horizontal: ResponsiveUtils.isMobile(context) ? 8 : 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: AppTheme.warmAccentColor,
            foregroundColor: AppTheme.angel,
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveUtils.isMobile(context) ? 6 : 8,
              horizontal: ResponsiveUtils.isMobile(context) ? 8 : 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          );

    return isOutlined
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: ResponsiveUtils.getIconSize(context, baseSize: 16)),
            label: Text(
              label,
              style: ResponsiveUtils.safeTextStyle(context, null),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            style: buttonStyle,
          )
        : ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: ResponsiveUtils.getIconSize(context, baseSize: 16)),
            label: Text(
              label,
              style: ResponsiveUtils.safeTextStyle(context, null),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            style: buttonStyle,
          );
  }

  Widget _buildProductSlideshow(String storeId, List<String> productImages, String? profileImageUrl, {Map<String, dynamic>? store}) {
    final hasProductImages = productImages.isNotEmpty;
    
    // Debug slideshow data
    print('🔍 DEBUG: Slideshow for store $storeId:');
    print('  - Product images: $productImages');
    print('  - Has product images: $hasProductImages');
    print('  - Profile image: $profileImageUrl');
    print('  - All images to display: ${hasProductImages ? productImages : 'NONE - will show placeholder'}');
    
    // Responsive height based on screen size
    final headerHeight = ResponsiveUtils.isMobile(context) ? 160.0 : 180.0;
    
    // Only use product images for slideshow (not profile image)
    List<String> allImages = [];
    if (hasProductImages) {
      allImages.addAll(productImages);
      print('🔍 DEBUG: Using ${allImages.length} product images for slideshow');
      print('🔍 DEBUG: Product images list: ${allImages.join(', ')}');
    } else {
      print('🔍 DEBUG: No product images available, showing placeholder');
    }
    
    if (allImages.isEmpty) {
      print('🔍 DEBUG: Showing placeholder for store $storeId');
    return Container(
        height: headerHeight,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
              AppTheme.deepTeal.withOpacity(0.1),
              AppTheme.cloud.withOpacity(0.05),
          ],
                            ),
      ),
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.deepTeal.withOpacity(0.1),
                    AppTheme.cloud.withOpacity(0.05),
                  ],
                ),
              ),
            ),
            // Store icon and text
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
            Icons.store,
            size: ResponsiveUtils.getIconSize(context, baseSize: 50),
            color: AppTheme.cloud,
          ),
                  const SizedBox(height: 8),
                  Text(
                    'Store Preview',
                    style: TextStyle(
                      color: AppTheme.cloud,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    print('🔍 DEBUG: Building slideshow with ${allImages.length} images: ${allImages.join(', ')}');
    
    // Test if the first product image is accessible
    if (allImages.isNotEmpty) {
      final testUrl = allImages.first;
      print('🔍 DEBUG: Testing product image URL: $testUrl');
      
      // Try to make a simple HTTP request to test if the image is accessible
      try {
        final uri = Uri.parse(testUrl);
        print('🔍 DEBUG: Parsed URI: $uri');
        print('🔍 DEBUG: URI scheme: ${uri.scheme}');
        print('🔍 DEBUG: URI host: ${uri.host}');
        print('🔍 DEBUG: URI path: ${uri.path}');
        
        // Test if the URL is accessible
        print('🔍 DEBUG: Testing if ImageKit URL is accessible...');
        // Note: We can't make actual HTTP requests in Flutter web due to CORS
        // This is likely the issue - ImageKit URLs require authentication or have CORS restrictions
        print('🔍 DEBUG: ImageKit URLs often require authentication or have CORS restrictions');
        print('🔍 DEBUG: This is likely why you see the profile image instead of product images');
        
        // Check if this is an ImageKit URL
        if (uri.host.contains('imagekit.io')) {
          print('🔍 DEBUG: This is an ImageKit URL - may have CORS restrictions');
          print('🔍 DEBUG: Consider using a different image hosting service or adding CORS headers');
        }
      } catch (e) {
        print('🔍 DEBUG: Error parsing image URL: $e');
      }
    }

    return Container(
      height: headerHeight,
      child: Stack(
        children: [
          // Carousel slider for multiple images or single image
          ClipRRect(
                borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: allImages.length > 1
                ? SizedBox(
                    height: headerHeight,
                    child: PageView.builder(
                      itemCount: allImages.length,
                      itemBuilder: (context, index) {
                        final imageUrl = allImages[index];
                        print('🔍 DEBUG: Loading page view image: $imageUrl');
                        return Container(
                          width: double.infinity,
                          child: SafeNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('🔍 DEBUG: Failed to load image: $imageUrl, Error: $error');
                              return Container(
                                width: double.infinity,
                                height: headerHeight,
                                color: Colors.grey.shade300,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_not_supported,
                                      size: 40,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Image not available',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  )
                : SafeNetworkImage(
                    imageUrl: allImages.first,
                    height: headerHeight,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('🔍 DEBUG: Failed to load single image: ${allImages.first}, Error: $error');
                      return Container(
                        width: double.infinity,
                        height: headerHeight,
                        color: Colors.grey.shade300,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported,
                              size: 40,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Image not available',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
              ),
                  ),
          
          // Story Badge (top-left) - Make feature discoverable
          if (store != null && store['story'] != null && store['story'].toString().isNotEmpty)
            Positioned(
              top: 12,
              left: 12,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SimpleStoreProfileScreen(store: store),
                    ),
                  );
                },
            child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                      colors: [AppTheme.deepTeal, AppTheme.deepTeal.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_stories,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Story Inside',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                      ),
                    ),
            ),
          ),
          
          // Image count indicator for multiple images
          if (allImages.length > 1)
          Positioned(
              top: 12,
              right: 12,
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.photo_library,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${allImages.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // "Products" label overlay
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.deepTeal.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_bag,
                    size: 14,
                    color: AppTheme.angel,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to view products',
                    style: TextStyle(
                      color: AppTheme.angel,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
                        ),
                      ),
                    ],
                  ),
    );
  }

  Widget _buildRatingRow(Map<String, dynamic> store) {
    final avgRating = store['avgRating'] ?? 0.0;
    final reviewCount = store['reviewCount'] ?? 0;
    
    return Row(
      children: [
        // Star Rating - Responsive sizing
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            return Icon(
              index < avgRating.floor() ? Icons.star : Icons.star_outline,
              color: AppTheme.warmAccentColor,
              size: ResponsiveUtils.getIconSize(context, baseSize: 16),
            );
          }),
      ),
        const SizedBox(width: 8),
        
        // Rating text - Overflow-safe
        Expanded(
          child: SafeUI.safeText(
          avgRating > 0 
              ? '${avgRating.toStringAsFixed(1)} (${reviewCount} reviews)'
              : 'No reviews yet',
            style: ResponsiveUtils.safeTextStyle(
              context,
              AppTheme.bodyMedium.copyWith(
                color: AppTheme.cloud,
            fontWeight: FontWeight.w500,
              ),
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  // _buildActionButtons() is currently unused in this screen

  List<Map<String, dynamic>> _filterStores(List<Map<String, dynamic>> stores) {
    List<Map<String, dynamic>> filtered = stores;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((store) {
        final name = (store['storeName'] ?? '').toString().toLowerCase();
        final location = (store['location'] ?? '').toString().toLowerCase();
        return name.contains(query) || location.contains(query);
      }).toList();
    }

    // Apply category filter
    switch (_activeFilter) {
      case 'nearby':
        // Show stores with distance information (sorted by distance)
        filtered = filtered.where((store) => store['distance'] != null).toList();
        filtered.sort((a, b) => (a['distance'] ?? double.infinity).compareTo(b['distance'] ?? double.infinity));
        break;
      case 'delivery':
        // Show stores that offer delivery
        filtered = filtered.where((store) => store['deliveryAvailable'] == true).toList();
        break;
      case 'nationwide':
        // Show non-food stores that support pickup (Pargo/PAXI), distance ignored
        filtered = filtered.where((store) {
          final category = (store['category'] ?? '').toString();
          final hasPickup = (store['pargoEnabled'] == true) || (store['paxiEnabled'] == true);
          return hasPickup && !_isFoodCategory(category);
        }).toList();
        break;
      case 'all':
      default:
        // Show all stores
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category} Stores'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: false,
        leading: const HomeNavigationButton(),
      ),
      backgroundColor: AppTheme.angel,
      body: Column(
        children: [
          // Search and Filter Section
          _buildSearchAndFilterSection(),
          Expanded(child: _buildStoresList()),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search stores...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.cloud),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppTheme.cloud.withOpacity(0.1),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          // Filter Buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', Icons.store),
                const SizedBox(width: 6),
                _buildFilterChip('Nearby', 'nearby', Icons.location_on),
                const SizedBox(width: 6),
                _buildFilterChip('Delivery', 'delivery', Icons.delivery_dining),
                const SizedBox(width: 6),
                _buildFilterChip('Nationwide', 'nationwide', Icons.public),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _activeFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.deepTeal : AppTheme.cloud.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.deepTeal : AppTheme.cloud.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppTheme.deepTeal,
            ),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.deepTeal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoresList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
              future: _getApprovedStores(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No stores found in this category.',
              style: TextStyle(fontSize: 16),
            ),
          );
        }
        final stores = snapshot.data!;
        
        // Apply search and filter
        final filteredStores = _filterStores(stores);
        
        if (filteredStores.isEmpty) {
          return const Center(
            child: Text(
              'No stores match your search criteria.',
              style: TextStyle(fontSize: 16),
            ),
          );
        }
        
        return ListView.builder(
          itemCount: filteredStores.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          addSemanticIndexes: false,
          cacheExtent: 800,
          itemBuilder: (context, index) {
            final store = filteredStores[index];
            return StunningStoreCard(
              store: store,
              category: widget.category,
            );
          },
        );
            },
  );
}
}

class StoreReviewsScreen extends StatelessWidget {
  final String storeId;

  const StoreReviewsScreen({super.key, required this.storeId});

  Future<List<Map<String, dynamic>>> _fetchReviews() async {
    final snapshot = await FirebaseFirestore.instance
      .collection('reviews')
      .where('storeId', isEqualTo: storeId)
      .orderBy('timestamp', descending: true)
      .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchReviews(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No reviews yet.'));
          }

          final reviews = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, __) => const Divider(),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              final rating = (review['rating'] ?? 0).toDouble();
              final comment = review['comment'] ?? '';
              final timestamp = (review['timestamp'] as Timestamp?)?.toDate();

              return ListTile(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < rating.floor()
                              ? Icons.star
                              : (i < rating ? Icons.star_half : Icons.star_border),
                          size: 16,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        () {
                          final reviewerName = review['reviewerName'] ?? '';
                          final reviewerEmail = review['reviewerEmail'] ?? '';
                          if (reviewerName.isNotEmpty && reviewerEmail.isNotEmpty) {
                            return '$reviewerName ($reviewerEmail)';
                          } else if (reviewerName.isNotEmpty) {
                            return reviewerName;
                          } else if (reviewerEmail.isNotEmpty) {
                            return reviewerEmail;
                          } else {
                            return 'Anonymous';
                          }
                        }(),
                        style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (comment.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          comment,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    if (timestamp != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          '${timestamp.toLocal()}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}


