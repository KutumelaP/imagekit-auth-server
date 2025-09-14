import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Phone Number'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add phone number for ${widget.task['deliveryDetails']?['buyerName'] ?? 'customer'}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: 'e.g., 0123456789',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addPhone,
          child: _isLoading 
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text('Add Phone'),
        ),
      ],
    );
  }

  Future<void> _addPhone() async {
    final phone = _phoneController.text.trim();
    
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Update the delivery task with phone number
      await FirebaseFirestore.instance
          .collection('seller_delivery_tasks')
          .doc(widget.task['orderId'])
          .update({
        'deliveryDetails.buyerPhone': phone,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Phone number added successfully'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onPhoneAdded();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add phone number: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
