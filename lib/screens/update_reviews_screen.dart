import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class UpdateReviewsScreen extends StatefulWidget {
  const UpdateReviewsScreen({Key? key}) : super(key: key);

  @override
  State<UpdateReviewsScreen> createState() => _UpdateReviewsScreenState();
}

class _UpdateReviewsScreenState extends State<UpdateReviewsScreen> {
  bool _isUpdating = false;
  String _status = 'Ready to update reviews';
  int _totalReviews = 0;
  int _updatedReviews = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Existing Reviews'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review Username Update',
                      style: AppTheme.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This will update existing reviews that show "Anonymous" as the username but have a valid email address. The username will be extracted from the email (part before @).',
                      style: AppTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Status: $_status',
                      style: AppTheme.bodyMedium.copyWith(
                        color: _isUpdating ? AppTheme.warning : AppTheme.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_totalReviews > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Total reviews found: $_totalReviews',
                        style: AppTheme.bodyMedium,
                      ),
                    ],
                    if (_updatedReviews > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Reviews updated: $_updatedReviews',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUpdating ? null : _updateReviews,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.deepTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isUpdating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Updating...'),
                        ],
                      )
                    : const Text('Update Reviews'),
              ),
            ),
            const SizedBox(height: 16),
            if (_isUpdating)
              const LinearProgressIndicator(
                backgroundColor: AppTheme.cloud,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateReviews() async {
    setState(() {
      _isUpdating = true;
      _status = 'Fetching reviews...';
      _totalReviews = 0;
      _updatedReviews = 0;
    });

    try {
      // Get all reviews where userName is 'Anonymous' but userEmail exists
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('userName', isEqualTo: 'Anonymous')
          .get();

      setState(() {
        _totalReviews = reviewsSnapshot.docs.length;
        _status = 'Found $_totalReviews reviews to update';
      });

      if (reviewsSnapshot.docs.isEmpty) {
        setState(() {
          _status = 'No reviews need updating';
          _isUpdating = false;
        });
        return;
      }

      int updateCount = 0;

      for (final doc in reviewsSnapshot.docs) {
        final reviewData = doc.data();
        final userEmail = reviewData['userEmail'] as String?;

        if (userEmail != null && userEmail.contains('@')) {
          // Extract username from email (part before @)
          final username = userEmail.split('@')[0];

          // Update the review with the extracted username
          await doc.reference.update({
            'userName': username
          });

          updateCount++;
          
          setState(() {
            _updatedReviews = updateCount;
            _status = 'Updated $updateCount of $_totalReviews reviews...';
          });
        }
      }

      setState(() {
        _status = 'Successfully updated $updateCount reviews';
        _isUpdating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated $updateCount reviews successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      }

    } catch (error) {
      setState(() {
        _status = 'Error: $error';
        _isUpdating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating reviews: $error'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}
