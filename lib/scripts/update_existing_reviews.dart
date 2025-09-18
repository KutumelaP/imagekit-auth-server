import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Script to update existing reviews that have "Anonymous" usernames
/// but have valid email addresses. Extracts username from email.
class UpdateExistingReviews {
  static Future<void> updateReviews() async {
    try {
      print('🔍 Fetching reviews with Anonymous usernames...');
      
      // Get all reviews where userName is 'Anonymous' but userEmail exists
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('userName', isEqualTo: 'Anonymous')
          .get();
      
      print('📊 Found ${reviewsSnapshot.docs.length} reviews with Anonymous usernames');
      
      if (reviewsSnapshot.docs.isEmpty) {
        print('✅ No reviews need updating');
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
          print('📝 Updated review ${doc.id}: $userEmail → $username');
        } else {
          print('⚠️  Skipping review ${doc.id}: No valid email found');
        }
      }
      
      print('✅ Successfully updated $updateCount reviews');
      
    } catch (error) {
      print('❌ Error updating reviews: $error');
    }
  }
  
  /// Helper function to extract username from email
  static String extractUsernameFromEmail(String? email) {
    if (email == null || email.isEmpty) return 'Anonymous';
    final parts = email.split('@');
    if (parts.isEmpty) return 'Anonymous';
    return parts[0];
  }
}
