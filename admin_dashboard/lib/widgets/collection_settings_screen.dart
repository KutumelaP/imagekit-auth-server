import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/admin_theme.dart';

class CollectionSettingsScreen extends StatefulWidget {
  const CollectionSettingsScreen({Key? key}) : super(key: key);

  @override
  State<CollectionSettingsScreen> createState() => _CollectionSettingsScreenState();
}

class _CollectionSettingsScreenState extends State<CollectionSettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  bool _saving = false;

  // Controllers
  final TextEditingController _codDisableThresholdController = TextEditingController();
  final TextEditingController _graceDaysController = TextEditingController();
  final TextEditingController _lateFeePctController = TextEditingController();
  final TextEditingController _reminder1DaysController = TextEditingController();
  final TextEditingController _reminder2DaysController = TextEditingController();
  final TextEditingController _reminder3DaysController = TextEditingController();

  bool _emailEnabled = true;
  bool _smsEnabled = false;
  bool _autoLockOnOverdue = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await _firestore.collection('admin_settings').doc('collection_settings').get();
      final data = doc.data() ?? {};
      _codDisableThresholdController.text = (data['codDisableThreshold'] ?? 300.0).toString();
      _graceDaysController.text = (data['graceDays'] ?? 7).toString();
      _lateFeePctController.text = (data['lateFeePct'] ?? 0).toString();
      _reminder1DaysController.text = (data['reminderDay1'] ?? 1).toString();
      _reminder2DaysController.text = (data['reminderDay2'] ?? 3).toString();
      _reminder3DaysController.text = (data['reminderDay3'] ?? 7).toString();
      _emailEnabled = data['emailEnabled'] != false;
      _smsEnabled = data['smsEnabled'] == true;
      _autoLockOnOverdue = data['autoLockOnOverdue'] != false;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _firestore.collection('admin_settings').doc('collection_settings').set({
        'codDisableThreshold': double.tryParse(_codDisableThresholdController.text) ?? 0.0,
        'graceDays': int.tryParse(_graceDaysController.text) ?? 0,
        'lateFeePct': double.tryParse(_lateFeePctController.text) ?? 0.0,
        'reminderDay1': int.tryParse(_reminder1DaysController.text) ?? 0,
        'reminderDay2': int.tryParse(_reminder2DaysController.text) ?? 0,
        'reminderDay3': int.tryParse(_reminder3DaysController.text) ?? 0,
        'emailEnabled': _emailEnabled,
        'smsEnabled': _smsEnabled,
        'autoLockOnOverdue': _autoLockOnOverdue,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Collection settings saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.rule, color: AdminTheme.deepTeal), const SizedBox(width: 8), Text('Collections Settings', style: AdminTheme.headlineMedium.copyWith(color: AdminTheme.deepTeal, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 16),
          _row([
            _field(_codDisableThresholdController, 'COD Disable Threshold (R)', Icons.lock),
            _field(_graceDaysController, 'Grace Period (days)', Icons.schedule),
            _field(_lateFeePctController, 'Late Fee (%)', Icons.percent),
          ]),
          const SizedBox(height: 16),
          _row([
            _field(_reminder1DaysController, 'Reminder 1 (days)', Icons.email_outlined),
            _field(_reminder2DaysController, 'Reminder 2 (days)', Icons.email_outlined),
            _field(_reminder3DaysController, 'Reminder 3 (days)', Icons.email_outlined),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 16, runSpacing: 8, children: [
            SwitchListTile(title: const Text('Email Reminders'), value: _emailEnabled, onChanged: (v) => setState(() => _emailEnabled = v)),
            SwitchListTile(title: const Text('SMS Reminders'), value: _smsEnabled, onChanged: (v) => setState(() => _smsEnabled = v)),
            SwitchListTile(title: const Text('Auto-lock COD when Overdue'), value: _autoLockOnOverdue, onChanged: (v) => setState(() => _autoLockOnOverdue = v)),
          ]),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: _saving ? const Text('Saving...') : const Text('Save Settings'),
              style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.deepTeal, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon) {
    return TextField(
      controller: c,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  Widget _row(List<Widget> children) {
    return Row(children: children.map((w) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: w))).toList());
  }
}
