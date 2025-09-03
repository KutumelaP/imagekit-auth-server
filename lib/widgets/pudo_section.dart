import 'package:flutter/material.dart';

class PudoSection extends StatelessWidget {
  final bool enabled;
  final String? selectedSize; // 's' | 'm' | 'l' | 'xl'
  final String? selectedSpeed; // 'standard' | 'express'
  final void Function(String size)? onSizeChanged;
  final void Function(String speed)? onSpeedChanged;
  final TextEditingController lockerNameController;
  final TextEditingController lockerAddressController;

  const PudoSection({
    super.key,
    required this.enabled,
    required this.selectedSize,
    required this.selectedSpeed,
    required this.onSizeChanged,
    required this.onSpeedChanged,
    required this.lockerNameController,
    required this.lockerAddressController,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.lock, size: 20),
          const SizedBox(width: 8),
          Text('PUDO Locker', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: lockerNameController,
          decoration: const InputDecoration(labelText: 'Locker name (required)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: lockerAddressController,
          decoration: const InputDecoration(labelText: 'Locker address (required)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _Dropdown(
            label: 'Size',
            value: selectedSize,
            items: const ['s','m','l','xl'],
            onChanged: (v){ if (v!=null && onSizeChanged!=null) onSizeChanged!(v); },
          )),
          const SizedBox(width: 8),
          Expanded(child: _Dropdown(
            label: 'Speed',
            value: selectedSpeed,
            items: const ['standard','express'],
            onChanged: (v){ if (v!=null && onSpeedChanged!=null) onSpeedChanged!(v); },
          )),
        ]),
      ],
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final void Function(String?)? onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}




