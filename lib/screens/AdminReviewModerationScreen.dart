import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminReviewModerationScreen extends StatefulWidget {
  const AdminReviewModerationScreen({super.key});

  @override
  State<AdminReviewModerationScreen> createState() => _AdminReviewModerationScreenState();
}

class _AdminReviewModerationScreenState extends State<AdminReviewModerationScreen> {
  bool _isAdmin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkIfAdmin();
  }

  Future<void> _checkIfAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    setState(() {
      _isAdmin = userDoc.data()?['role'] == 'admin';
      _loading = false;
    });
  }

  Future<void> _deleteReview(String reviewId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Review?'),
        content: const Text('Are you sure you want to delete this review? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('reviews').doc(reviewId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review deleted')));
        setState(() {}); // Refresh UI
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Moderation')),
        body: const Center(child: Text('You do not have permission to view this page.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Review Moderation')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reviews').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading reviews.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final reviews = snapshot.data!.docs;
          if (reviews.isEmpty) {
            return const Center(child: Text('No reviews found.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, __) => const Divider(),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index].data()! as Map<String, dynamic>;
              final reviewId = reviews[index].id;
              final rating = (review['rating'] ?? 0).toDouble();
              final comment = review['comment'] ?? '';
              final storeId = review['storeId'] ?? '';
              final userId = review['userId'] ?? '';
              final timestamp = (review['timestamp'] as Timestamp?)?.toDate();
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                ),
                title: Text(comment.isNotEmpty ? comment : '(No comment)'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Store: $storeId'),
                    Text('User: $userId'),
                    if (timestamp != null)
                      Text('${timestamp.toLocal()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete Review',
                  onPressed: () => _deleteReview(reviewId),
                ),
              );
            },
          );
        },
      ),
    );
  }
} 