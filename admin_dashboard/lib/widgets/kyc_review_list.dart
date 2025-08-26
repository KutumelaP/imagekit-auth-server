import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';
import 'kyc_image_preview.dart';

class KycReviewList extends StatefulWidget {
  const KycReviewList({super.key});

  @override
  State<KycReviewList> createState() => _KycReviewListState();
}

class _KycReviewListState extends State<KycReviewList> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _loading = true;
  List<_KycItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Read from kyc_submissions collection instead of users
      final submissions = await _db.collection('kyc_submissions')
          .where('status', isEqualTo: 'pending')
          .orderBy('submittedAt', descending: true)
          .get();
      
      final items = <_KycItem>[];
      for (final sub in submissions.docs) {
        final subData = sub.data();
        final userId = subData['userId'] as String?;
        if (userId == null) continue;
        
        // Get user info
        final userDoc = await _db.collection('users').doc(userId).get();
        final userData = userDoc.data() ?? {};
        
        // Get all kyc images for this user
        final kycDocs = await _db.collection('users').doc(userId).collection('kyc').get();
        String? idFrontUrl, idBackUrl, selfieUrl;
        
        for (final kycDoc in kycDocs.docs) {
          final kycData = kycDoc.data();
          final url = kycData['url'] as String?;
          final filePath = kycData['filePath'] as String? ?? '';
          
          if (url != null) {
            if (filePath.contains('id_front') || filePath.contains('front')) {
              idFrontUrl = url;
            } else if (filePath.contains('id_back') || filePath.contains('back')) {
              idBackUrl = url;
            } else if (filePath.contains('selfie')) {
              selfieUrl = url;
            }
          }
        }
        
        items.add(
          _KycItem(
            userId: userId,
            submissionId: sub.id,
            email: (userData['email'] as String?) ?? 'unknown',
            storeName: (userData['storeName'] as String?) ?? 'Seller',
            idFrontUrl: idFrontUrl,
            idBackUrl: idBackUrl,
            selfieUrl: selfieUrl,
            submittedAt: (subData['submittedAt'] is Timestamp) 
                ? (subData['submittedAt'] as Timestamp).toDate()
                : DateTime.tryParse(subData['submittedAt']?.toString() ?? ''),
          ),
        );
      }
      setState(() { _items = items; });
    } catch (e) {
      debugPrint('KYC load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _mark(String userId, String submissionId, String status) async {
    try {
      // Update user's KYC status
      await _db.collection('users').doc(userId).set({
        'kycStatus': status, 
        'kycApprovedAt': status == 'approved' ? FieldValue.serverTimestamp() : null
      }, SetOptions(merge: true));
      
      // Update the submission status 
      await _db.collection('kyc_submissions').doc(submissionId).update({
        'status': status,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KYC $status')));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return const Center(child: Text('No pending KYC submissions'));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('KYC Review', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AdminTheme.textColor)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _buildRow(_items[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(_KycItem item) {
    final List<KycImageData> images = [];
    if (item.idFrontUrl != null) {
      images.add(KycImageData(url: item.idFrontUrl!, label: 'ID Front'));
    }
    if (item.idBackUrl != null) {
      images.add(KycImageData(url: item.idBackUrl!, label: 'ID Back'));
    }
    if (item.selfieUrl != null) {
      images.add(KycImageData(url: item.selfieUrl!, label: 'Selfie'));
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0,4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user, color: AdminTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(child: Text('${item.storeName}  •  ${item.email}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                Text(item.submittedAt != null ? item.submittedAt!.toLocal().toString().split('.').first : '—', style: TextStyle(color: AdminTheme.mediumGrey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            if (images.isNotEmpty) ...[
              KycImageGrid(images: images),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _mark(item.userId, item.submissionId, 'approved'),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _mark(item.userId, item.submissionId, 'rejected'),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _KycItem {
  final String userId;
  final String submissionId;
  final String email;
  final String storeName;
  final String? idFrontUrl;
  final String? idBackUrl;
  final String? selfieUrl;
  final DateTime? submittedAt;
  _KycItem({
    required this.userId,
    required this.submissionId,
    required this.email,
    required this.storeName,
    this.idFrontUrl,
    this.idBackUrl,
    this.selfieUrl,
    this.submittedAt,
  });
}


