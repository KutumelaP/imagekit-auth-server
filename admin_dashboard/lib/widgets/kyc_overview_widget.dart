import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';
import 'kyc_image_preview.dart';

class KycOverviewWidget extends StatefulWidget {
  const KycOverviewWidget({super.key});

  @override
  State<KycOverviewWidget> createState() => _KycOverviewWidgetState();
}

class _KycOverviewWidgetState extends State<KycOverviewWidget> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _loading = true;
  List<_KycOverviewItem> _items = [];
  String _selectedStatus = 'all';
  final List<String> _statusOptions = ['all', 'pending', 'approved', 'rejected'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await _db.collection('users').get();
      final items = <_KycOverviewItem>[];
      
      for (final u in users.docs) {
        final userData = u.data();
        final kycStatus = userData['kycStatus'] as String? ?? 'none';
        
        // Skip if filtering by specific status and it doesn't match
        if (_selectedStatus != 'all' && kycStatus != _selectedStatus) continue;
        
        // Only include users who have submitted KYC
        if (kycStatus == 'none') continue;
        
        final l1 = await _db.collection('users').doc(u.id).collection('kyc').doc('L1').get();
        final kycData = l1.data() ?? {};
        
        items.add(
          _KycOverviewItem(
            userId: u.id,
            email: (userData['email'] as String?) ?? 'unknown',
            storeName: (userData['storeName'] as String?) ?? 'Seller',
            kycStatus: kycStatus,
            idFrontUrl: kycData['idFrontUrl'] as String?,
            idBackUrl: kycData['idBackUrl'] as String?,
            selfieUrl: kycData['selfieUrl'] as String?,
            submittedAt: (kycData['submittedAt'] as Timestamp?)?.toDate(),
            updatedAt: (kycData['updatedAt'] as Timestamp?)?.toDate(),
          ),
        );
      }
      
      // Sort by submission date (newest first)
      items.sort((a, b) => (b.submittedAt ?? DateTime(1900)).compareTo(a.submittedAt ?? DateTime(1900)));
      
      setState(() { _items = items; });
    } catch (e) {
      debugPrint('KYC overview load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onStatusChanged(String? newStatus) {
    if (newStatus != null && newStatus != _selectedStatus) {
      setState(() => _selectedStatus = newStatus);
      _load();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return AdminTheme.mediumGrey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'KYC Overview',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.textColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminTheme.primaryColor.withOpacity(0.3)),
                ),
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  underline: const SizedBox(),
                  items: _statusOptions.map((status) => DropdownMenuItem(
                    value: status,
                    child: Text(
                      status == 'all' ? 'All Statuses' : _getStatusText(status),
                      style: TextStyle(
                        color: status == 'all' ? AdminTheme.textColor : _getStatusColor(status),
                      ),
                    ),
                  )).toList(),
                  onChanged: _onStatusChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_items.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 64,
                    color: AdminTheme.mediumGrey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No KYC submissions found',
                    style: TextStyle(
                      fontSize: 18,
                      color: AdminTheme.mediumGrey,
                    ),
                  ),
                  if (_selectedStatus != 'all')
                    Text(
                      'for ${_getStatusText(_selectedStatus)} status',
                      style: TextStyle(
                        fontSize: 14,
                        color: AdminTheme.mediumGrey,
                      ),
                    ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _buildOverviewCard(_items[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(_KycOverviewItem item) {
    final statusColor = _getStatusColor(item.kycStatus);
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
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    _getStatusText(item.kycStatus),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  item.submittedAt != null 
                      ? 'Submitted: ${item.submittedAt!.toLocal().toString().split('.').first}'
                      : '—',
                  style: TextStyle(
                    color: AdminTheme.mediumGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person, color: AdminTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${item.storeName}  •  ${item.email}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Documents (${images.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AdminTheme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              KycImageGrid(
                images: images,
                thumbnailWidth: 120,
                thumbnailHeight: 80,
              ),
            ],
            if (item.updatedAt != null && item.updatedAt != item.submittedAt) ...[
              const SizedBox(height: 12),
              Text(
                'Last updated: ${item.updatedAt!.toLocal().toString().split('.').first}',
                style: TextStyle(
                  color: AdminTheme.mediumGrey,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KycOverviewItem {
  final String userId;
  final String email;
  final String storeName;
  final String kycStatus;
  final String? idFrontUrl;
  final String? idBackUrl;
  final String? selfieUrl;
  final DateTime? submittedAt;
  final DateTime? updatedAt;

  _KycOverviewItem({
    required this.userId,
    required this.email,
    required this.storeName,
    required this.kycStatus,
    this.idFrontUrl,
    this.idBackUrl,
    this.selfieUrl,
    this.submittedAt,
    this.updatedAt,
  });
}
