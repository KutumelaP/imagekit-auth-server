import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SellerReviewsSection extends StatelessWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  const SellerReviewsSection({Key? key, required this.auth, required this.firestore}) : super(key: key);

  Future<List<Map<String, dynamic>>> _fetchReviews(String sellerId) async {
    final productsSnap = await firestore.collection('products').where('ownerId', isEqualTo: sellerId).get();
    final productIds = productsSnap.docs.map((doc) => doc.id).toList();
    if (productIds.isEmpty) return [];
    final reviewsSnap = await firestore.collection('reviews').where('productId', whereIn: productIds).orderBy('timestamp', descending: true).limit(20).get();
    return reviewsSnap.docs.map((doc) => doc.data()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final sellerId = auth.currentUser?.uid;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: sellerId != null ? _fetchReviews(sellerId) : Future.value([]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load reviews.'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Container(
              width: double.infinity,
              alignment: Alignment.center,
              child: const Text('No reviews found.'),
            );
          }
          final reviews = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recent Reviews', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
              const SizedBox(height: 18),
              ...reviews.map((review) => _ReviewCard(review: review)).toList(),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final reviewer = review['reviewerName'] ?? 'Anonymous';
    final rating = review['rating'] ?? 0;
    final text = review['text'] ?? '';
    final ts = review['timestamp'];
    final date = ts is Timestamp ? DateFormat('yMMMd').format(ts.toDate()) : '';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Theme.of(context).colorScheme.onSurface),
                const SizedBox(width: 8),
                Text(reviewer, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Row(
                  children: List.generate(5, (i) => Icon(
                    i < rating ? Icons.star : Icons.star_border,
                    color: Theme.of(context).colorScheme.primary,
                    size: 18,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(date, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
} 