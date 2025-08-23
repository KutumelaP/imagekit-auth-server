import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/imagekit_service.dart';

class KycUploadScreen extends StatefulWidget {
  const KycUploadScreen({super.key});

  @override
  State<KycUploadScreen> createState() => _KycUploadScreenState();
}

class _KycUploadScreenState extends State<KycUploadScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _idFront;
  XFile? _idBack;
  XFile? _selfie;
  bool _loading = true;
  bool _submitting = false;
  String _kycStatus = 'none';
  String? _idFrontUrl;
  String? _idBackUrl;
  String? _selfieUrl;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final user = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final data = user.data();
        if (data != null) {
          _kycStatus = (data['kycStatus'] as String?) ?? 'none';
        }
        final doc = await FirebaseFirestore.instance
            .collection('users').doc(uid).collection('kyc').doc('L1').get();
        final k = doc.data();
        if (k != null) {
          _idFrontUrl = k['idFrontUrl'] as String?;
          _idBackUrl = k['idBackUrl'] as String?;
          _selfieUrl = k['selfieUrl'] as String?;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickIdFront() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 90);
    if (x != null) setState(() => _idFront = x);
  }

  Future<void> _pickIdBack() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 90);
    if (x != null) setState(() => _idBack = x);
  }

  Future<void> _pickSelfie() async {
    final x = await _picker.pickImage(source: ImageSource.camera, maxWidth: 2000, imageQuality: 90);
    if (x != null) setState(() => _selfie = x);
  }

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_idFront == null && _idFrontUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload ID front')));
      return;
    }
    if (_selfie == null && _selfieUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please take a selfie')));
      return;
    }
    setState(() => _submitting = true);
    try {
      String? frontUrl = _idFrontUrl;
      String? backUrl = _idBackUrl;
      String? selfieUrl = _selfieUrl;
      if (_idFront != null) {
        frontUrl = await ImageKitService.uploadImageWithAuth(file: _idFront!, folder: 'kyc', customFileName: 'kyc/$uid/front_${DateTime.now().millisecondsSinceEpoch}.jpg');
      }
      if (_idBack != null) {
        backUrl = await ImageKitService.uploadImageWithAuth(file: _idBack!, folder: 'kyc', customFileName: 'kyc/$uid/back_${DateTime.now().millisecondsSinceEpoch}.jpg');
      }
      if (_selfie != null) {
        selfieUrl = await ImageKitService.uploadImageWithAuth(file: _selfie!, folder: 'kyc', customFileName: 'kyc/$uid/selfie_${DateTime.now().millisecondsSinceEpoch}.jpg');
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'kycStatus': 'pending'}, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('kyc').doc('L1').set({
        'idFrontUrl': frontUrl,
        'idBackUrl': backUrl,
        'selfieUrl': selfieUrl,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KYC submitted for review')));
      setState(() { _kycStatus = 'pending'; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity Verification'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppTheme.whisper,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatusBanner(),
                const SizedBox(height: 12),
                _buildUploadTile('ID Front', _idFront, _idFrontUrl, _pickIdFront),
                const SizedBox(height: 12),
                _buildUploadTile('ID Back (optional)', _idBack, _idBackUrl, _pickIdBack),
                const SizedBox(height: 12),
                _buildUploadTile('Selfie', _selfie, _selfieUrl, _pickSelfie, camera: true),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.upload),
                    label: Text(_submitting ? 'Submitting...' : 'Submit for Review'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deepTeal, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusBanner() {
    Color c = AppTheme.breeze;
    String text = 'Not submitted';
    if (_kycStatus == 'pending') { c = Colors.orange; text = 'Pending review'; }
    if (_kycStatus == 'approved') { c = Colors.green; text = 'Approved'; }
    if (_kycStatus == 'rejected') { c = Colors.red; text = 'Rejected - please resubmit'; }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withOpacity(0.3))),
      child: Row(
        children: [
          Icon(Icons.verified_user, color: c),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: c, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildUploadTile(String title, XFile? localFile, String? existingUrl, VoidCallback onPick, { bool camera = false }) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0,4)),
      ]),
      child: ListTile(
        leading: Icon(camera ? Icons.camera_alt : Icons.badge, color: AppTheme.deepTeal),
        title: Text(title),
        subtitle: existingUrl != null ? Text('Existing file linked', style: TextStyle(color: AppTheme.breeze)) : null,
        trailing: TextButton.icon(onPressed: onPick, icon: const Icon(Icons.upload_file), label: const Text('Upload')),
      ),
    );
  }
}


