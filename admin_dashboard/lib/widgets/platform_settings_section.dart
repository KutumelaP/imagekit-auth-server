import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlatformSettingsSection extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  const PlatformSettingsSection({Key? key, required this.auth, required this.firestore}) : super(key: key);

  @override
  State<PlatformSettingsSection> createState() => _PlatformSettingsSectionState();
}

class _PlatformSettingsSectionState extends State<PlatformSettingsSection> {
  final _feeController = TextEditingController();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  // EFT bank details
  final _eftAccountNameController = TextEditingController();
  final _eftBankNameController = TextEditingController();
  final _eftAccountNumberController = TextEditingController();
  final _eftBranchCodeController = TextEditingController();
  bool _registrationEnabled = true;
  bool _moderationEnabled = true;
  bool _saving = false;
  Map<String, dynamic>? _settings;
  // Pickup visibility
  bool _pargoVisible = true;
  bool _paxiVisible = true;
  // Notification fields (already present)
  final _messageController = TextEditingController();
  String _target = 'all';
  bool _sending = false;
  // Add a maintenanceMode field to state
  bool _maintenanceMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final doc = await widget.firestore.collection('config').doc('platform').get();
    final data = doc.data();
    if (data != null) {
      setState(() {
        _settings = data;
        _feeController.text = (data['platformFee'] ?? '').toString();
        _nameController.text = data['platformName'] ?? '';
        _contactController.text = data['contactInfo'] ?? '';
        _registrationEnabled = data['registrationEnabled'] != false;
        _moderationEnabled = data['moderationEnabled'] != false;
        _maintenanceMode = data['maintenanceMode'] == true;
        _pargoVisible = data['pargoVisible'] != false;
        _paxiVisible = data['paxiVisible'] != false;
        _eftAccountNameController.text = data['eftAccountName'] ?? '';
        _eftBankNameController.text = data['eftBankName'] ?? '';
        _eftAccountNumberController.text = data['eftAccountNumber'] ?? '';
        _eftBranchCodeController.text = data['eftBranchCode'] ?? '';
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      await widget.firestore.collection('config').doc('platform').set({
        'platformFee': double.tryParse(_feeController.text) ?? 0.0,
        'platformName': _nameController.text.trim(),
        'contactInfo': _contactController.text.trim(),
        'registrationEnabled': _registrationEnabled,
        'moderationEnabled': _moderationEnabled,
        'maintenanceMode': _maintenanceMode,
        'pargoVisible': _pargoVisible,
        'paxiVisible': _paxiVisible,
        'eftAccountName': _eftAccountNameController.text.trim(),
        'eftBankName': _eftBankNameController.text.trim(),
        'eftAccountNumber': _eftAccountNumberController.text.trim(),
        'eftBranchCode': _eftBranchCodeController.text.trim(),
      }, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _sendNotification() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.firestore.collection('notifications').add({
        'message': msg,
        'target': _target,
        'timestamp': FieldValue.serverTimestamp(),
        'sender': widget.auth.currentUser?.email ?? 'admin',
      });
      _messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification sent')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _feeController.dispose();
    _nameController.dispose();
    _contactController.dispose();
    _eftAccountNameController.dispose();
    _eftBankNameController.dispose();
    _eftAccountNumberController.dispose();
    _eftBranchCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.background,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        color: Theme.of(context).cardColor,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Platform Settings', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 12),
                  if (_maintenanceMode)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.error),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
                             SizedBox(width: 8),
                            Expanded(child: Text('Maintenance Mode is ENABLED. The platform is in read-only or offline mode for users.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error))),
                          ],
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _feeController,
                          decoration: InputDecoration(
                            labelText: 'Platform Fee (%)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Platform Name',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _contactController,
                          decoration: InputDecoration(
                            labelText: 'Contact Info',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    child: Theme(
                      data: Theme.of(context),
                      child: Row(
                        children: [
                          Expanded(
                            child: SwitchListTile(
                              title: const Text('Enable Registration'),
                              value: _registrationEnabled,
                              onChanged: (v) => setState(() => _registrationEnabled = v),
                            ),
                          ),
                          Expanded(
                            child: SwitchListTile(
                              title: const Text('Enable Moderation'),
                              value: _moderationEnabled,
                              onChanged: (v) => setState(() => _moderationEnabled = v),
                            ),
                          ),
                          Expanded(
                            child: SwitchListTile(
                              title: const Text('Enable Maintenance Mode'),
                              value: _maintenanceMode,
                              onChanged: (v) => setState(() => _maintenanceMode = v),
                            ),
                          ),
                          Expanded(
                            child: SwitchListTile(
                              title: const Text('Show PARGO'),
                              value: _pargoVisible,
                              onChanged: (v) => setState(() => _pargoVisible = v),
                            ),
                          ),
                          Expanded(
                            child: SwitchListTile(
                              title: const Text('Show PAXI'),
                              value: _paxiVisible,
                              onChanged: (v) => setState(() => _paxiVisible = v),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _saving ? null : _saveSettings,
                            child: _saving ? const Text('Saving...') : const Text('Save Settings'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 32),
                  Text('EFT Bank Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _eftAccountNameController,
                          decoration: InputDecoration(
                            labelText: 'Account Name',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _eftBankNameController,
                          decoration: InputDecoration(
                            labelText: 'Bank',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _eftAccountNumberController,
                          decoration: InputDecoration(
                            labelText: 'Account Number',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _eftBranchCodeController,
                          decoration: InputDecoration(
                            labelText: 'Branch Code',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  // Notifications UI (already present)
                  Text('Send Platform Notification', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            labelText: 'Message',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          minLines: 1,
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<String>(
                        value: _target,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Users')),
                          DropdownMenuItem(value: 'sellers', child: Text('Sellers Only')),
                          DropdownMenuItem(value: 'buyers', child: Text('Buyers Only')),
                        ],
                        onChanged: (v) => setState(() => _target = v ?? 'all'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _sending ? null : _sendNotification,
                        child: _sending ? CircularProgressIndicator() : Text('Send'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text('Notification History', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Tip: You can scroll horizontally to see more columns.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontStyle: FontStyle.italic, fontSize: 13),
                    ),
                  ),
                  SizedBox(
                    height: 500,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: widget.firestore.collection('notifications').orderBy('timestamp', descending: true).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final notifs = snapshot.data!.docs;
                        if (notifs.isEmpty) return const Text('No notifications sent.');
                        return ListView.separated(
                          itemCount: notifs.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor),
                          itemBuilder: (context, i) {
                            final data = notifs[i].data() as Map<String, dynamic>;
                            return ListTile(
                              title: Text(data['message'] ?? ''),
                              subtitle: Text('Target: ${data['target'] ?? 'all'} | Sent: ${data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate().toString() : ''}'),
                              trailing: Text(data['sender'] ?? ''),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 