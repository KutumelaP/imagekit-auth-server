import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellerSettingsSection extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  const SellerSettingsSection({Key? key, required this.auth, required this.firestore}) : super(key: key);

  @override
  State<SellerSettingsSection> createState() => _SellerSettingsSectionState();
}

class _SellerSettingsSectionState extends State<SellerSettingsSection> {
  final _storeNameController = TextEditingController();
  final _contactController = TextEditingController();
  bool _loading = false;

  Future<void> _loadSettings(String sellerId) async {
    setState(() => _loading = true);
    final doc = await widget.firestore.collection('users').doc(sellerId).get();
    final data = doc.data();
    if (data != null) {
      _storeNameController.text = data['storeName'] ?? '';
      _contactController.text = data['contact'] ?? '';
    }
    setState(() => _loading = false);
  }

  Future<void> _saveSettings(String sellerId) async {
    setState(() => _loading = true);
    await widget.firestore.collection('users').doc(sellerId).set({
      'storeName': _storeNameController.text.trim(),
      'contact': _contactController.text.trim(),
    }, SetOptions(merge: true));
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved.')));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sellerId = widget.auth.currentUser?.uid;
    if (sellerId != null) {
      _loadSettings(sellerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sellerId = widget.auth.currentUser?.uid;
    return Material(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Store Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _storeNameController,
                    decoration: const InputDecoration(labelText: 'Store Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _contactController,
                    decoration: const InputDecoration(labelText: 'Contact Info'),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: sellerId == null ? null : () => _saveSettings(sellerId),
                    child: const Text('Save Settings'),
                  ),
                ],
              ),
      ),
    );
  }
} 