import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/admin_theme.dart';

class RiskReviewScreen extends StatelessWidget {
  const RiskReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Risk Review', style: AdminTheme.headlineMedium),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('order_reviews')
                .where('status', isEqualTo: 'pending')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Center(child: Text('No pending reviews', style: TextStyle(color: AdminTheme.deepTeal)));
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  final id = docs[i].id;
                  final score = d['riskScore'] ?? 0;
                  final reasons = (d['reasons'] as List?)?.join(', ') ?? '';
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: AdminTheme.cardDecoration(),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: AdminTheme.deepTeal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Risk Score: $score', style: TextStyle(color: AdminTheme.deepTeal, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('Reasons: $reasons', style: TextStyle(color: AdminTheme.breeze)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance.collection('order_reviews').doc(id).update({'status': 'approved', 'reviewedAt': FieldValue.serverTimestamp()});
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.deepTeal, foregroundColor: Colors.white),
                          child: const Text('Approve'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance.collection('order_reviews').doc(id).update({'status': 'rejected', 'reviewedAt': FieldValue.serverTimestamp()});
                          },
                          style: OutlinedButton.styleFrom(foregroundColor: AdminTheme.deepTeal),
                          child: const Text('Reject'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}


