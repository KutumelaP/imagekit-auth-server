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
  // Prep time defaults
  final _defaultPrepTimeController = TextEditingController();
  bool _defaultMadeToOrder = false;
  bool _registrationEnabled = true;
  bool _moderationEnabled = true;
  bool _saving = false;
  // removed unused _settings
  // Pickup visibility
  bool _pargoVisible = true;
  bool _paxiVisible = true;
  bool _forcePudoDoorVisible = false;
  // Notification fields (already present)
  final _messageController = TextEditingController();
  String _target = 'all';
  bool _sending = false;
  // Add a maintenanceMode field to state
  bool _maintenanceMode = false;
  // Delivery/assignment controls
  bool _autoDriverAssignmentEnabled = false;
  bool _autoPudoRoutingEnabled = false;

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
        // _settings removed; apply fields directly
        // platformFee here is legacy and not used; fee managed in Payment Settings
        _feeController.text = '';
        _nameController.text = data['platformName'] ?? '';
        _contactController.text = data['contactInfo'] ?? '';
        _registrationEnabled = data['registrationEnabled'] != false;
        _moderationEnabled = data['moderationEnabled'] != false;
        _maintenanceMode = data['maintenanceMode'] == true;
        _pargoVisible = data['pargoVisible'] != false;
        _paxiVisible = data['paxiVisible'] != false;
        final f = data['forcePudoDoorVisible'];
        _forcePudoDoorVisible = (f == true) || (f is String && f.toLowerCase() == 'true');
        _eftAccountNameController.text = data['eftAccountName'] ?? '';
        _eftBankNameController.text = data['eftBankName'] ?? '';
        _eftAccountNumberController.text = data['eftAccountNumber'] ?? '';
        _eftBranchCodeController.text = data['eftBranchCode'] ?? '';
        _autoDriverAssignmentEnabled = data['autoDriverAssignmentEnabled'] == true;
        _autoPudoRoutingEnabled = data['autoPudoRoutingEnabled'] == true;
        _defaultPrepTimeController.text = (data['defaultPrepTimeMinutes']?.toString() ?? '');
        _defaultMadeToOrder = data['defaultMadeToOrder'] == true;
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
        'forcePudoDoorVisible': _forcePudoDoorVisible,
        'autoDriverAssignmentEnabled': _autoDriverAssignmentEnabled,
        'autoPudoRoutingEnabled': _autoPudoRoutingEnabled,
        'eftAccountName': _eftAccountNameController.text.trim(),
        'eftBankName': _eftBankNameController.text.trim(),
        'eftAccountNumber': _eftAccountNumberController.text.trim(),
        'eftBranchCode': _eftBranchCodeController.text.trim(),
        'defaultPrepTimeMinutes': int.tryParse(_defaultPrepTimeController.text.trim()) ?? null,
        'defaultMadeToOrder': _defaultMadeToOrder,
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
                      // Removed duplicate Platform Fee field; controlled in Payment Settings
                      const SizedBox(width: 0),
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
                  _buildLogoUrlRow(context),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    child: Theme(
                      data: Theme.of(context),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: 260,
                            child: SwitchListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Enable Registration', softWrap: false, overflow: TextOverflow.ellipsis),
                              value: _registrationEnabled,
                              onChanged: (v) => setState(() => _registrationEnabled = v),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: SwitchListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Enable Moderation', softWrap: false, overflow: TextOverflow.ellipsis),
                              value: _moderationEnabled,
                              onChanged: (v) => setState(() => _moderationEnabled = v),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: SwitchListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Enable Maintenance Mode', softWrap: false, overflow: TextOverflow.ellipsis),
                              value: _maintenanceMode,
                              onChanged: (v) => setState(() => _maintenanceMode = v),
                            ),
                          ),
                          SizedBox(
                            width: 200,
                            child: SwitchListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Show PARGO', softWrap: false, overflow: TextOverflow.ellipsis),
                              value: _pargoVisible,
                              onChanged: (v) => setState(() => _pargoVisible = v),
                            ),
                          ),
                          SizedBox(
                            width: 200,
                            child: SwitchListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Show PAXI', softWrap: false, overflow: TextOverflow.ellipsis),
                              value: _paxiVisible,
                              onChanged: (v) => setState(() => _paxiVisible = v),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: SwitchListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Enable Auto Driver Assignment', softWrap: false, overflow: TextOverflow.ellipsis),
                              value: _autoDriverAssignmentEnabled,
                              onChanged: (v) => setState(() => _autoDriverAssignmentEnabled = v),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: SwitchListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Enable Auto PUDO Routing', softWrap: false, overflow: TextOverflow.ellipsis),
                              value: _autoPudoRoutingEnabled,
                              onChanged: (v) => setState(() => _autoPudoRoutingEnabled = v),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: SwitchListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Force PUDO Door visible (debug)', softWrap: false, overflow: TextOverflow.ellipsis),
                              value: _forcePudoDoorVisible,
                              onChanged: (v) => setState(() => _forcePudoDoorVisible = v),
                            ),
                          ),
                          // Default Prep Time + Made to order (used by main app if product lacks values)
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _defaultPrepTimeController,
                              decoration: InputDecoration(
                                labelText: 'Default Prep Time (minutes)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(
                            width: 240,
                            child: SwitchListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Default: Made to order', softWrap: false, overflow: TextOverflow.ellipsis),
                              value: _defaultMadeToOrder,
                              onChanged: (v) => setState(() => _defaultMadeToOrder = v),
                            ),
                          ),
                          SizedBox(
                            width: 200,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _saveSettings,
                              child: _saving ? const Text('Saving...') : const Text('Save Settings'),
                            ),
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

Widget _buildLogoUrlRow(BuildContext context) => _LogoUrlRow();

class _LogoUrlRow extends StatefulWidget {
  @override
  State<_LogoUrlRow> createState() => _LogoUrlRowState();
}

class _LogoUrlRowState extends State<_LogoUrlRow> {
  final TextEditingController _logoCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('admin_settings').doc('branding').get();
      _logoCtrl.text = (snap.data()?['logoUrl'] as String? ?? '').trim();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _logoCtrl,
            decoration: InputDecoration(
              labelText: 'Brand Logo URL (used in PDFs/emails)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () async {
            await FirebaseFirestore.instance.collection('admin_settings').doc('branding').set({
              'logoUrl': _logoCtrl.text.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logo URL saved.')));
          },
          icon: const Icon(Icons.save),
          label: const Text('Save Logo'),
        ),
        const SizedBox(width: 12),
        if ((_logoCtrl.text).trim().isNotEmpty)
          SizedBox(height: 40, width: 120, child: Image.network(_logoCtrl.text.trim(), fit: BoxFit.contain)),
      ],
    );
  }
}