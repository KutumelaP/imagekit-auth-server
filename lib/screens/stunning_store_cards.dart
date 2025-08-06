import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/app_theme.dart';
import '../widgets/robust_image.dart';
import 'product_browsing_screen.dart';
import 'simple_store_profile_screen.dart';
import '../widgets/safe_network_image.dart';
import 'stunning_product_browser.dart';

class StunningStoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final String category;

  const StunningStoreCard({
    super.key,
    required this.store,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    // Debug: Print store data to see what we're working with
    print('DEBUG: Store data for ${store['storeName']}:');
    print('  - avgRating: ${store['avgRating']}');
    print('  - reviewCount: ${store['reviewCount']}');
    print('  - distance: ${store['distance']}');
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppTheme.angel,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          // Stunning Header with Image
          _buildStunningHeader(context),
          
          // Clean Content Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store Info
                _buildStoreInfo(),
                const SizedBox(height: 16),
                
                // Rating and Distance
                _buildRatingAndDistance(),
                const SizedBox(height: 20),
                
                // Action Buttons
                _buildActionButtons(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStunningHeader(BuildContext context) {
    // Get product images for slideshow
    final List<String> productImages = List<String>.from(store['productImages'] ?? []);
    final String? profileImageUrl = store['profileImageUrl'];
    
    // Debug the images
    print('🔍 DEBUG: StunningStoreCard header for ${store['storeName']}:');
    print('  - Product images: $productImages');
    print('  - Profile image: $profileImageUrl');
    
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          // Product Images Slideshow or Profile Image
          if (productImages.isNotEmpty)
            SafeNetworkImage(
              imageUrl: productImages.first,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            )
          else if (profileImageUrl != null && profileImageUrl.isNotEmpty)
            SafeNetworkImage(
              imageUrl: profileImageUrl,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            )
          else
            _buildPlaceholderImage(),
          
          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
              ),
            ),
          ),
          
          // Store Name Overlay
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Text(
              store['storeName'] ?? 'Store Name',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(1, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ),
          
          // Behind the Brand Badge
          if (store['story'] != null && store['story'].toString().isNotEmpty)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.deepTeal, AppTheme.cloud],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.business,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Brand',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Image count indicator for multiple images
          if (productImages.length > 1)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_library,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${productImages.length}',
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
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String url, dynamic error) {
    return Container(
      color: AppTheme.whisper,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image,
              size: 40,
              color: AppTheme.cloud,
            ),
            const SizedBox(height: 4),
            Text(
              'Product Image\nFailed to Load\n\nURL: ${url.length > 30 ? url.substring(0, 30) + '...' : url}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.cloud,
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.deepTeal.withOpacity(0.1),
            AppTheme.cloud.withOpacity(0.05),
          ],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.deepTeal.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.store,
            size: 40,
            color: AppTheme.deepTeal,
          ),
        ),
      ),
    );
  }

  Widget _buildStoreInfo() {
    return Row(
      children: [
        // Store Avatar
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppTheme.deepTeal, AppTheme.cloud],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.deepTeal.withOpacity(0.3),
                blurRadius: 8,
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
                    print('Error loading store avatar: $exception');
                  }
                : null,
            child: store['profileImageUrl'] == null || store['profileImageUrl'].toString().isEmpty
                ? Text(
                    store['storeName']?.substring(0, 1).toUpperCase() ?? 'S',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Store Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      store['storeName'] ?? 'Store Name',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepTeal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (store['isVerified'] == true)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '✓',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: AppTheme.cloud,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      store['location'] ?? 'Location not set',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.cloud,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingAndDistance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rating and Reviews - Always show, even if 0
        Row(
          children: [
            ...List.generate(5, (index) {
              final rating = (store['avgRating'] ?? 0.0) as double;
              if (index < rating.floor()) {
                return const Icon(Icons.star, size: 16, color: Colors.orange);
              } else if (index == rating.floor() && rating % 1 >= 0.5) {
                return const Icon(Icons.star_half, size: 16, color: Colors.orange);
              } else {
                return const Icon(Icons.star_border, size: 16, color: Colors.orange);
              }
            }),
            const SizedBox(width: 8),
            Text(
              '${(store['avgRating'] ?? 0.0).toStringAsFixed(1)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.deepTeal,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(${store['reviewCount'] ?? 0} reviews)',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.mediumGrey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Distance
        if (store['distance'] != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.deepTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.directions_walk,
                  size: 14,
                  color: AppTheme.deepTeal,
                ),
                const SizedBox(width: 4),
                Text(
                  '${store['distance'].toStringAsFixed(1)}km away',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.deepTeal,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 8),
        
        // Store Status and Delivery Information
        Row(
          children: [
            // Store Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: (store['isStoreOpen'] == true) 
                  ? AppTheme.primaryGreen.withOpacity(0.1)
                  : AppTheme.primaryRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (store['isStoreOpen'] == true) 
                    ? AppTheme.primaryGreen
                    : AppTheme.primaryRed,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    (store['isStoreOpen'] == true) 
                      ? Icons.store
                      : Icons.store_mall_directory,
                    size: 10,
                    color: (store['isStoreOpen'] == true) 
                      ? AppTheme.primaryGreen
                      : AppTheme.primaryRed,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    (store['isStoreOpen'] == true) ? 'Open' : 'Closed',
                    style: TextStyle(
                      color: (store['isStoreOpen'] == true) 
                        ? AppTheme.primaryGreen
                        : AppTheme.primaryRed,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 6),
            
            // Delivery Range Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: (store['deliveryAvailable'] == true) 
                  ? AppTheme.deepTeal.withOpacity(0.1)
                  : AppTheme.mediumGrey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
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
                    size: 10,
                    color: (store['deliveryAvailable'] == true) 
                      ? AppTheme.deepTeal
                      : AppTheme.mediumGrey,
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      (store['deliveryAvailable'] == true) 
                        ? '${(store['distance'] != null ? store['distance'].toStringAsFixed(1) : (store['deliveryRange'] ?? 1000).toStringAsFixed(0))}km'
                        : 'Pick up',
                      style: TextStyle(
                        color: (store['deliveryAvailable'] == true) 
                          ? AppTheme.deepTeal
                          : AppTheme.mediumGrey,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 6),
            
            // Operating Hours Badge
            if (store['storeOpenHour'] != null && store['storeCloseHour'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.deepTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
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
                      size: 10,
                      color: AppTheme.deepTeal,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${store['storeOpenHour']} - ${store['storeCloseHour']}',
                      style: TextStyle(
                        color: AppTheme.deepTeal,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // Main Action Buttons Row
        Row(
          children: [
            // View Products Button
            Expanded(
              child: ElevatedButton.icon(
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
                icon: const Icon(Icons.shopping_bag, size: 16),
                label: const Text('Products', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.deepTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Behind the Brand Button (if story exists)
            if (store['story'] != null && store['story'].toString().isNotEmpty)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SimpleStoreProfileScreen(store: store),
                      ),
                    );
                  },
                  icon: const Icon(Icons.business, size: 16),
                  label: const Text('Brand', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.deepTeal,
                    side: BorderSide(color: AppTheme.deepTeal),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Add Review Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              print('DEBUG: Review button pressed for store: ${store['storeName']}');
              print('DEBUG: Store ID: ${store['storeId']}');
              print('DEBUG: Context mounted: ${context.mounted}');
              
              // Check authentication state
              final user = FirebaseAuth.instance.currentUser;
              print('DEBUG: Current user: ${user?.uid ?? 'null'}');
              print('DEBUG: User email: ${user?.email ?? 'null'}');
              print('DEBUG: User display name: ${user?.displayName ?? 'null'}');
              
              _showLeaveReviewDialog(context, store['storeId']);
            },
            icon: const Icon(Icons.star_outline, size: 16),
            label: const Text('Leave a Review'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.deepTeal,
              side: BorderSide(color: AppTheme.deepTeal.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showLeaveReviewDialog(BuildContext context, String storeId) {
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
} 