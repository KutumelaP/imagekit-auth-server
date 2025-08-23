import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class RiskReviewScreen extends StatelessWidget {
  const RiskReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Risk Review'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: AppTheme.angel,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('order_reviews')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No pending reviews',
                style: TextStyle(color: AppTheme.deepTeal),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final id = docs[i].id;
              final score = d['riskScore'] ?? 0;
              final reasons = (d['reasons'] as List?)?.join(', ') ?? '';
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber, color: AppTheme.deepTeal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Risk Score: $score',
                              style: TextStyle(
                                color: AppTheme.deepTeal,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Reasons: $reasons', style: TextStyle(color: AppTheme.breeze)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('order_reviews')
                                  .doc(id)
                                  .update({'status': 'approved', 'reviewedAt': FieldValue.serverTimestamp()});
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deepTeal, foregroundColor: Colors.white),
                            child: const Text('Approve'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('order_reviews')
                                  .doc(id)
                                  .update({'status': 'rejected', 'reviewedAt': FieldValue.serverTimestamp()});
                            },
                            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.deepTeal),
                            child: const Text('Reject'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


