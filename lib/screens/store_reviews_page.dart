import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class StoreReviewsPage extends StatefulWidget {
  final String storeId;
  final String storeName;

  const StoreReviewsPage({
    Key? key,
    required this.storeId,
    required this.storeName,
  }) : super(key: key);

  @override
  State<StoreReviewsPage> createState() => _StoreReviewsPageState();
}

class _StoreReviewsPageState extends State<StoreReviewsPage> {
  final ScrollController _scrollController = ScrollController();
  final List<DocumentSnapshot> _reviews = [];
  bool _isLoading = false;
  bool _hasMoreData = true;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMoreData) {
        _loadMoreReviews();
      }
    }
  }

  Future<void> _loadReviews() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('reviews')
          .where('storeId', isEqualTo: widget.storeId)
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);

      final QuerySnapshot snapshot = await query.get();
      
      setState(() {
        _reviews.clear();
        _reviews.addAll(snapshot.docs);
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMoreData = snapshot.docs.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading reviews: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreReviews() async {
    if (_isLoading || !_hasMoreData || _lastDocument == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('reviews')
          .where('storeId', isEqualTo: widget.storeId)
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize);

      final QuerySnapshot snapshot = await query.get();
      
      setState(() {
        _reviews.addAll(snapshot.docs);
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMoreData = snapshot.docs.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading more reviews: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final reviewDate = timestamp.toDate();
    final difference = now.difference(reviewDate);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reviews - ${widget.storeName}'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _reviews.isEmpty && !_isLoading
          ? _buildEmptyState()
          : _buildReviewsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.star_border,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No reviews yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to leave a review!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    return RefreshIndicator(
      onRefresh: _loadReviews,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _reviews.length + (_hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _reviews.length) {
            return _buildLoadingIndicator();
          }

          final review = _reviews[index].data() as Map<String, dynamic>;
          final rating = review['rating'] as int? ?? 0;
          final comment = review['comment'] as String? ?? '';
          final userName = review['userName'] as String? ?? 'Anonymous';
          final timestamp = review['timestamp'] as Timestamp?;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Star rating
                    Row(
                      children: List.generate(5, (starIndex) {
                        return Icon(
                          starIndex < rating ? Icons.star : Icons.star_border,
                          color: starIndex < rating ? Colors.amber : Colors.grey,
                          size: 20,
                        );
                      }),
                    ),
                    const Spacer(),
                    // User name and date
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (timestamp != null)
                          Text(
                            _formatTimestamp(timestamp),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    comment,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
} 