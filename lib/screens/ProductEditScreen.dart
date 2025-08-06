import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class ProductEditScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> initialData;

  const ProductEditScreen({
    super.key,
    required this.productId,
    required this.initialData,
  });

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _categoryController;
  late TextEditingController _imageUrlController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.initialData['name'] ?? '');
    _priceController = TextEditingController(text: widget.initialData['price']?.toString() ?? '');
    _categoryController = TextEditingController(text: widget.initialData['category'] ?? '');
    _imageUrlController = TextEditingController(text: widget.initialData['imageUrl'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final price = double.tryParse(_priceController.text);
      if (price == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid price')),
        );
        setState(() {
          _isSaving = false;
        });
        return;
      }

      await FirebaseFirestore.instance.collection('products').doc(widget.productId).update({
        'name': _nameController.text.trim(),
        'price': price,
        'category': _categoryController.text.trim(),
        'imageUrl': _imageUrlController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Notify admin for moderation
      await NotificationService.createNotification(
        userId: 'admin',
        title: 'Product Edited',
        body: 'A product has been edited and needs review.',
        type: 'product_edit',
        data: {'productId': widget.productId, 'productName': _nameController.text.trim()},
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product updated successfully')),
      );

      Navigator.of(context).pop(true); // Pass true to indicate update success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update product: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isSaving
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Product Name'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Price'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true, signed: false),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? 'Price is required' : null,
                    ),
                    TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(labelText: 'Category'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? 'Category is required' : null,
                    ),
                    TextFormField(
                      controller: _imageUrlController,
                      decoration: const InputDecoration(labelText: 'Image URL'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final uri = Uri.tryParse(value);
                        if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
                          return 'Enter a valid URL or leave empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saveChanges,
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
