import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';

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
      final users = await _db.collection('users').where('kycStatus', isEqualTo: 'pending').get();
      final items = <_KycItem>[];
      for (final u in users.docs) {
        final l1 = await _db.collection('users').doc(u.id).collection('kyc').doc('L1').get();
        final d = l1.data() ?? {};
        items.add(
          _KycItem(
            userId: u.id,
            email: (u.data()['email'] as String?) ?? 'unknown',
            storeName: (u.data()['storeName'] as String?) ?? 'Seller',
            idFrontUrl: d['idFrontUrl'] as String?,
            idBackUrl: d['idBackUrl'] as String?,
            selfieUrl: d['selfieUrl'] as String?,
            submittedAt: (d['submittedAt'] as Timestamp?)?.toDate(),
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

  Future<void> _mark(String userId, String status) async {
    try {
      await _db.collection('users').doc(userId).set({'kycStatus': status, 'kycApprovedAt': status == 'approved' ? FieldValue.serverTimestamp() : null}, SetOptions(merge: true));
      await _db.collection('users').doc(userId).collection('kyc').doc('L1').set({'status': status, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
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
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (item.idFrontUrl != null) _thumb(item.idFrontUrl!, 'ID Front'),
                if (item.idBackUrl != null) _thumb(item.idBackUrl!, 'ID Back'),
                if (item.selfieUrl != null) _thumb(item.selfieUrl!, 'Selfie'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _mark(item.userId, 'approved'),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _mark(item.userId, 'rejected'),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _thumb(String url, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            width: 160,
            height: 100,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: AdminTheme.mediumGrey)),
      ],
    );
  }
}

class _KycItem {
  final String userId;
  final String email;
  final String storeName;
  final String? idFrontUrl;
  final String? idBackUrl;
  final String? selfieUrl;
  final DateTime? submittedAt;
  _KycItem({
    required this.userId,
    required this.email,
    required this.storeName,
    this.idFrontUrl,
    this.idBackUrl,
    this.selfieUrl,
    this.submittedAt,
  });
}


