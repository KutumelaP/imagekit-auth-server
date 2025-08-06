import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductEditDialog extends StatefulWidget {
  final DocumentSnapshot? productDoc;
  final void Function(Map<String, dynamic> data) onSave;
  const ProductEditDialog({Key? key, this.productDoc, required this.onSave}) : super(key: key);

  @override
  State<ProductEditDialog> createState() => _ProductEditDialogState();
}

class _ProductEditDialogState extends State<ProductEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _sellerController;
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    final data = widget.productDoc?.data() as Map<String, dynamic>?;
    _nameController = TextEditingController(text: data?['name'] ?? '');
    _categoryController = TextEditingController(text: data?['category'] ?? '');
    _priceController = TextEditingController(text: data?['price']?.toString() ?? '');
    _stockController = TextEditingController(text: data?['stock']?.toString() ?? '');
    _sellerController = TextEditingController(text: data?['sellerName'] ?? data?['sellerId'] ?? '');
    _status = data?['status'] ?? 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _sellerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.productDoc == null ? 'Add Product' : 'Edit Product'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.isEmpty ? 'Enter product name' : null,
              ),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (v) => v == null || v.isEmpty ? 'Enter category' : null,
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Enter price' : null,
              ),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(labelText: 'Stock'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Enter stock' : null,
              ),
              TextFormField(
                controller: _sellerController,
                decoration: const InputDecoration(labelText: 'Seller (name or ID)'),
                validator: (v) => v == null || v.isEmpty ? 'Enter seller' : null,
              ),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'active'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              widget.onSave({
                'name': _nameController.text.trim(),
                'category': _categoryController.text.trim(),
                'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
                'stock': int.tryParse(_stockController.text.trim()) ?? 0,
                'sellerName': _sellerController.text.trim(),
                'status': _status,
              });
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
} 