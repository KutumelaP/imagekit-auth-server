import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _chatEnabled = true;
  bool _orderEnabled = true;
  bool _generalEnabled = true;
  bool _soundEnabled = true;
  TimeOfDay? _quietStart;
  TimeOfDay? _quietEnd;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _chatEnabled = prefs.getBool('notif_chat') ?? true;
      _orderEnabled = prefs.getBool('notif_order') ?? true;
      _generalEnabled = prefs.getBool('notif_general') ?? true;
      _soundEnabled = prefs.getBool('notif_sound') ?? true;
      final qs = prefs.getString('notif_quiet_start');
      final qe = prefs.getString('notif_quiet_end');
      if (qs != null) {
        final parts = qs.split(':');
        _quietStart = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      if (qe != null) {
        final parts = qe.split(':');
        _quietEnd = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_chat', _chatEnabled);
    await prefs.setBool('notif_order', _orderEnabled);
    await prefs.setBool('notif_general', _generalEnabled);
    await prefs.setBool('notif_sound', _soundEnabled);
    if (_quietStart != null) {
      await prefs.setString('notif_quiet_start', '${_quietStart!.hour}:${_quietStart!.minute}');
    }
    if (_quietEnd != null) {
      await prefs.setString('notif_quiet_end', '${_quietEnd!.hour}:${_quietEnd!.minute}');
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? (_quietStart ?? const TimeOfDay(hour: 22, minute: 0)) : (_quietEnd ?? const TimeOfDay(hour: 7, minute: 0));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isStart) _quietStart = picked; else _quietEnd = picked;
      });
      await _savePrefs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Chat notifications'),
            value: _chatEnabled,
            onChanged: (v) => setState(() { _chatEnabled = v; _savePrefs(); }),
          ),
          SwitchListTile(
            title: const Text('Order notifications'),
            value: _orderEnabled,
            onChanged: (v) => setState(() { _orderEnabled = v; _savePrefs(); }),
          ),
          SwitchListTile(
            title: const Text('General notifications'),
            value: _generalEnabled,
            onChanged: (v) => setState(() { _generalEnabled = v; _savePrefs(); }),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Sound'),
            value: _soundEnabled,
            onChanged: (v) => setState(() { _soundEnabled = v; _savePrefs(); }),
          ),
          const Divider(),
          ListTile(
            title: const Text('Quiet hours start'),
            subtitle: Text(_quietStart != null ? _quietStart!.format(context) : 'Not set'),
            trailing: const Icon(Icons.schedule),
            onTap: () => _pickTime(true),
          ),
          ListTile(
            title: const Text('Quiet hours end'),
            subtitle: Text(_quietEnd != null ? _quietEnd!.format(context) : 'Not set'),
            trailing: const Icon(Icons.schedule),
            onTap: () => _pickTime(false),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

