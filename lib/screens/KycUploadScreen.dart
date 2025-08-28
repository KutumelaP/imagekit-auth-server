import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:typed_data';
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
        if (kDebugMode) print('🔍 Loading KYC data for user: $uid');
        
        final user = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final data = user.data();
        if (data != null) {
          _kycStatus = (data['kycStatus'] as String?) ?? 'none';
          if (kDebugMode) print('📋 User KYC status: $_kycStatus');
        }
        
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users').doc(uid).collection('kyc').doc('L1').get();
          final k = doc.data();
          if (k != null) {
            _idFrontUrl = k['idFrontUrl'] as String?;
            _idBackUrl = k['idBackUrl'] as String?;
            _selfieUrl = k['selfieUrl'] as String?;
            if (kDebugMode) print('📄 Found existing KYC documents');
          } else {
            if (kDebugMode) print('📄 No existing KYC documents found');
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Error loading KYC documents: $e');
          // This is expected for new users - don't treat as error
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error loading user data: $e');
    }
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

  Widget _buildWebCompatibleImage(XFile file, BoxFit fit, {double? width, double? height}) {
    if (kIsWeb) {
      // On web, use Image.network with the file path as a blob URL
      return FutureBuilder<Uint8List>(
        future: file.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              fit: fit,
              width: width,
              height: height,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.error, size: 32, color: Colors.red),
              ),
            );
          } else if (snapshot.hasError) {
            return Container(
              color: Colors.grey[200],
              child: const Icon(Icons.error, size: 32, color: Colors.red),
            );
          } else {
            return Container(
              color: Colors.grey[100],
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
        },
      );
    } else {
      // On mobile, use Image.file
      return Image.file(
        File(file.path),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[200],
          child: const Icon(Icons.error, size: 32, color: Colors.red),
        ),
      );
    }
  }

  void _showImagePreview(String title, XFile? localFile, String? existingUrl) {
    if (localFile == null && existingUrl == null) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 400, maxWidth: 300),
                child: localFile != null
                    ? _buildWebCompatibleImage(localFile, BoxFit.contain)
                    : Image.network(
                        existingUrl!,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.error, size: 48, color: Colors.red),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
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
        frontUrl = await ImageKitService.uploadImageWithAuth(file: _idFront!, folder: 'kyc_uploads', customFileName: 'kyc_uploads/$uid/front_${DateTime.now().millisecondsSinceEpoch}.jpg');
      }
      if (_idBack != null) {
        backUrl = await ImageKitService.uploadImageWithAuth(file: _idBack!, folder: 'kyc_uploads', customFileName: 'kyc_uploads/$uid/back_${DateTime.now().millisecondsSinceEpoch}.jpg');
      }
      if (_selfie != null) {
        selfieUrl = await ImageKitService.uploadImageWithAuth(file: _selfie!, folder: 'kyc_uploads', customFileName: 'kyc_uploads/$uid/selfie_${DateTime.now().millisecondsSinceEpoch}.jpg');
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
      if (kDebugMode) print('❌ KYC submission failed: $e');
      
      String errorMessage = 'KYC submission failed';
      if (e.toString().contains('permission-denied')) {
        errorMessage = 'Permission denied. Please check your account status.';
      } else if (e.toString().contains('unavailable')) {
        errorMessage = 'Service temporarily unavailable. Please try again.';
      } else if (e.toString().contains('unauthenticated')) {
        errorMessage = 'Please log in again to submit KYC.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
      ));
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
    final hasImage = localFile != null || existingUrl != null;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(12), 
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0,4)),
        ]
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(camera ? Icons.camera_alt : Icons.badge, color: AppTheme.deepTeal),
            title: Text(title),
            subtitle: existingUrl != null ? Text('Existing file linked', style: TextStyle(color: AppTheme.breeze)) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasImage)
                  IconButton(
                    onPressed: () => _showImagePreview(title, localFile, existingUrl),
                    icon: const Icon(Icons.preview, color: AppTheme.deepTeal),
                    tooltip: 'Preview',
                  ),
                TextButton.icon(
                  onPressed: onPick, 
                  icon: const Icon(Icons.upload_file), 
                  label: const Text('Upload')
                ),
              ],
            ),
          ),
          if (hasImage) ...[
            Container(
              height: 120,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: localFile != null
                    ? _buildWebCompatibleImage(localFile, BoxFit.cover, width: double.infinity)
                    : Image.network(
                        existingUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.error, size: 32, color: Colors.red),
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


