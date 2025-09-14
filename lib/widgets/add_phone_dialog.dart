import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Add Phone Dialog for updating delivery task phone numbers
class AddPhoneDialog extends StatefulWidget {
  final Map<String, dynamic> task;
  final VoidCallback onPhoneAdded;

  const AddPhoneDialog({
    Key? key,
    required this.task,
    required this.onPhoneAdded,
  }) : super(key: key);

  @override
  State<AddPhoneDialog> createState() => _AddPhoneDialogState();
}

class _AddPhoneDialogState extends State<AddPhoneDialog> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _addPhone() async {
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Update the delivery task with CUSTOMER phone number
      await FirebaseFirestore.instance
          .collection('seller_delivery_tasks')
          .doc(widget.task['orderId'])
          .update({
        'deliveryDetails.buyerPhone': _phoneController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      widget.onPhoneAdded();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer phone number added successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding phone: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Customer Phone'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Add phone number for customer: ${widget.task['deliveryDetails']?['buyerName'] ?? 'Customer'}'),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addPhone,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Phone'),
        ),
      ],
    );
  }
}
