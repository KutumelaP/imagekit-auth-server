import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'product_detail_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/safe_network_image.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final userId = FirebaseAuth.instance.currentUser?.uid;

  // Fetch favorite product IDs for current user
  Future<List<String>> _fetchFavoriteProductIds() async {
    if (userId == null) return [];
    final doc = await FirebaseFirestore.instance.collection('favorites').doc(userId).get();
    if (!doc.exists) return [];
    final data = doc.data()!;
    return List<String>.from(data['productIds'] ?? []);
  }

  // Remove productId from favorites
  Future<void> _removeFavorite(String productId) async {
    if (userId == null) return;
    final docRef = FirebaseFirestore.instance.collection('favorites').doc(userId);

    await docRef.update({
      'productIds': FieldValue.arrayRemove([productId]),
    });

    setState(() {}); // Refresh UI
  }

  // Firestore supports 'whereIn' with max 10 elements
  // So we split productIds into batches of max 10 and fetch separately
  Future<List<QueryDocumentSnapshot>> _fetchProductsInBatches(List<String> productIds) async {
    final List<QueryDocumentSnapshot> allProducts = [];

    for (int i = 0; i < productIds.length; i += 10) {
      final batch = productIds.sublist(
        i,
        i + 10 > productIds.length ? productIds.length : i + 10,
      );

      final querySnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      allProducts.addAll(querySnapshot.docs);
    }

    return allProducts;
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Favorites')),
        body: const Center(child: Text('Please log in to view favorites')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: FutureBuilder<List<String>>(
        future: _fetchFavoriteProductIds(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading favorites: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No favorites added yet'));
          }

          final productIds = snapshot.data!;

          return FutureBuilder<List<QueryDocumentSnapshot>>(
            future: _fetchProductsInBatches(productIds),
            builder: (context, productSnapshot) {
              if (productSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (productSnapshot.hasError) {
                return Center(child: Text('Error loading products: ${productSnapshot.error}'));
              }

              final products = productSnapshot.data ?? [];

              if (products.isEmpty) {
                return const Center(child: Text('No favorite products found'));
              }

              return ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final doc = products[index];
                  final data = doc.data()! as Map<String, dynamic>;
                  final docId = doc.id;

                  return ListTile(
                    leading: data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty
                        ? SafeProductImage(
                            imageUrl: data['imageUrl'],
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: BorderRadius.circular(12),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: AppTheme.cloud,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.image_not_supported,
                              color: AppTheme.deepTeal,
                              size: 40,
                            ),
                          ),
                    title: Text(data['name'] ?? 'Unnamed Product'),
                    subtitle: Text('R${data['price']}'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeFavorite(docId),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(
                            product: {...data, 'id': docId},
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
