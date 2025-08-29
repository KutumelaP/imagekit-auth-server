import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReviewsSection extends StatefulWidget {
  const ReviewsSection({Key? key}) : super(key: key);

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  int _negativeThreshold = 2; // rating <= threshold considered negative

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                'Reviews Overview',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 24,
                    fontWeight: FontWeight.bold,
                    ),
              ),
              Row(
                children: [
                  const Text('Negative if rating ≤ '),
                  DropdownButton<int>(
                    value: _negativeThreshold,
                    items: const [1, 2, 3]
                        .map((v) => DropdownMenuItem<int>(value: v, child: Text(v.toString())))
                        .toList(),
                    onChanged: (v) => setState(() => _negativeThreshold = v ?? 2),
                  ),
                ],
          ),
        ],
      ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
          .collection('reviews')
          .orderBy('timestamp', descending: true)
                .limit(200)
                .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
                return const Text('Failed to load reviews.');
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text('No reviews found.');
              }
              // Build productId set for enrichment
              final Set<String> productIds = {
                for (final d in docs)
                  ((d.data() as Map<String, dynamic>? ?? {})['productId']?.toString() ?? '')
              }..removeWhere((e) => e.isEmpty);

              return FutureBuilder<Map<String, Map<String, dynamic>>>(
                future: _fetchProductMeta(productIds),
                builder: (context, metaSnap) {
                  final meta = metaSnap.data ?? const {};

                  // Build per-review rows and store aggregates
                  final List<Widget> reviewCards = [];
                  final Map<String, StoreAgg> storeAgg = {};

                  for (final doc in docs) {
                    final data = doc.data() as Map<String, dynamic>? ?? {};
                    final reviewer = (data['reviewerName'] ?? data['userName'] ?? 'Anonymous').toString();
                    final rating = (data['rating'] ?? 0);
                    final text = (data['text'] ?? data['comment'] ?? '').toString();
                    final ts = data['timestamp'];
                    final date = ts is Timestamp ? DateFormat('yMMMd').format(ts.toDate()) : '';
                    final imageUrls = (data['images'] as List?)?.whereType<String>().toList() ?? [];
                    final productId = (data['productId'] ?? '').toString();
                    final productName = (data['productName'] ?? meta[productId]?['productName'] ?? '').toString();
                    final storeNameRaw = (data['storeName'] ?? data['sellerStoreName'] ?? meta[productId]?['storeName'] ?? '').toString();
                    final storeName = storeNameRaw.isEmpty ? 'Unknown Store' : storeNameRaw;

                    // Aggregate per store
                    final agg = storeAgg.putIfAbsent(storeName, () => StoreAgg());
                    agg.total += 1;
                    final ratingNum = rating is num ? rating.toDouble() : 0.0;
                    agg.sumRatings += ratingNum;
                    if (ratingNum <= _negativeThreshold) agg.bad += 1;

                    // Build review card
                    reviewCards.add(
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                              Row(
                  children: [
                                  const Icon(Icons.person, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                                    child: Text(
                                      reviewer,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  _buildStars(rating),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.store, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _composeStoreProduct(storeName, productName),
                                      style: Theme.of(context).textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (text.isNotEmpty)
                                Text(text, style: const TextStyle(fontSize: 16)),
                              if (imageUrls.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: imageUrls.map((url) => _ImageThumb(url: url)).toList(),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                date,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                              ),
          ],
        ),
      ),
                      ),
                    );
                  }

                  // Build store leaderboard by negative reviews
                  final entries = storeAgg.entries.toList()
                    ..sort((a, b) {
                      final byBad = b.value.bad.compareTo(a.value.bad);
                      if (byBad != 0) return byBad;
                      return b.value.total.compareTo(a.value.total);
                    });

                  Widget leaderboard = Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                              const Icon(Icons.store, size: 20),
                              const SizedBox(width: 8),
                Expanded(
                                child: Text(
                                  'Stores by negative reviews',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
              ],
            ),
            const SizedBox(height: 12),
                          ...entries.map((e) {
                            final avg = e.value.total > 0 ? (e.value.sumRatings / e.value.total) : 0.0;
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(e.key, overflow: TextOverflow.ellipsis),
                              subtitle: Text('Avg rating: ' + avg.toStringAsFixed(2) + ' • Total: ' + e.value.total.toString()),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Negative: ' + e.value.bad.toString(), style: const TextStyle(color: Colors.red)),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leaderboard,
                      const SizedBox(height: 24),
                      Text('Recent Reviews', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...reviewCards,
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStars(dynamic ratingValue) {
    final intRating = ratingValue is num ? ratingValue.round().clamp(0, 5) : 0;
    return Row(
      children: List.generate(5, (i) => Icon(
            i < intRating ? Icons.star : Icons.star_border,
            color: Colors.amber.shade700,
            size: 18,
      )),
    );
  }
  String _composeStoreProduct(String storeName, String productName) {
    if (storeName.isNotEmpty && productName.isNotEmpty) {
      return 'Store: ' + storeName + ' • Product: ' + productName;
    }
    if (storeName.isNotEmpty) return 'Store: ' + storeName;
    if (productName.isNotEmpty) return 'Product: ' + productName;
    return '';
  }

  Future<Map<String, Map<String, dynamic>>> _fetchProductMeta(Set<String> productIds) async {
    final Map<String, Map<String, dynamic>> meta = {};
    if (productIds.isEmpty) return meta;
    final ids = productIds.toList();
    for (int i = 0; i < ids.length; i += 10) {
      final end = (i + 10) < ids.length ? (i + 10) : ids.length;
      final batch = ids.sublist(i, end);
      try {
        final snap = await FirebaseFirestore.instance
            .collection('products')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (final d in snap.docs) {
          final data = d.data();
          meta[d.id] = {
            'productName': data['name'] ?? data['title'] ?? '',
            'storeName': data['storeName'] ?? data['sellerStoreName'] ?? data['store'] ?? data['ownerName'] ?? '',
          };
        }
      } catch (_) {
        // Ignore batch failures silently
      }
    }
    return meta;
  }
}

class StoreAgg {
  int total = 0;
  int bad = 0;
  double sumRatings = 0.0;
}

class _ImageThumb extends StatelessWidget {
  final String url;
  const _ImageThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showZoom(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  void _showZoom(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          backgroundColor: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Image.network(imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
} 