import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/imagekit_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  late TextEditingController _subcategoryController;
  late TextEditingController _imageUrlController;
  late TextEditingController _stockController;
  late TextEditingController _descriptionController;
  String _status = 'active';
  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();

  static const Map<String, List<String>> _categoryMap = {
    'Food': ['Baked Goods','Fresh Produce','Dairy & Eggs','Meat & Poultry','Pantry Items','Snacks','Beverages','Frozen Foods','Organic Foods','Candy & Sweets','Condiments'],
    'Electronics': ['Phones','Laptops','Tablets','Computers','Cameras','Headphones','Speakers','Gaming','Smart Home','Wearables','Accessories'],
    'Clothing': ['T-Shirts','Jeans','Dresses','Shirts','Pants','Shorts','Skirts','Jackets','Sweaters','Hoodies','Shoes','Hats','Accessories','Underwear','Socks'],
    'Other': ['Handmade','Vintage','Collectibles','Books','Toys','Home & Garden','Sports','Beauty','Health','Automotive','Tools','Miscellaneous'],
  };

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.initialData['name'] ?? '');
    _priceController = TextEditingController(text: widget.initialData['price']?.toString() ?? '');
    
    // Validate category exists in map, otherwise reset to empty
    final initialCategory = widget.initialData['category'] as String? ?? '';
    final validCategory = _categoryMap.containsKey(initialCategory) ? initialCategory : '';
    _categoryController = TextEditingController(text: validCategory);
    
    // Reset subcategory if parent category is invalid
    final initialSubcategory = widget.initialData['subcategory'] as String? ?? '';
    final validSubcategory = (validCategory.isNotEmpty && 
        (_categoryMap[validCategory]?.contains(initialSubcategory) ?? false)) 
        ? initialSubcategory : '';
    _subcategoryController = TextEditingController(text: validSubcategory);
    
    _imageUrlController = TextEditingController(text: widget.initialData['imageUrl'] ?? '');
    _stockController = TextEditingController(text: (widget.initialData['quantity'] ?? widget.initialData['stock'] ?? '').toString());
    _descriptionController = TextEditingController(text: widget.initialData['description'] ?? '');
    _status = (widget.initialData['status'] as String?)?.toLowerCase() == 'draft' ? 'draft' : 'active';

    // Rebuild on changes to show floating save bar
    for (final c in [
      _nameController,
      _priceController,
      _categoryController,
      _subcategoryController,
      _imageUrlController,
      _stockController,
      _descriptionController,
    ]) {
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _subcategoryController.dispose();
    _imageUrlController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
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
        'subcategory': _subcategoryController.text.trim(),
        'imageUrl': _imageUrlController.text.trim(),
        'quantity': int.tryParse(_stockController.text.trim()) ?? widget.initialData['quantity'] ?? widget.initialData['stock'] ?? 0,
        'stock': int.tryParse(_stockController.text.trim()) ?? widget.initialData['stock'] ?? widget.initialData['quantity'] ?? 0,
        'description': _descriptionController.text.trim(),
        'status': _status,
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
    return WillPopScope(
      onWillPop: () async {
        if (_isDirty()) {
          final discard = await _confirmDiscardChanges();
          return discard;
        }
        return true;
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product'),
      ),
      body: _isSaving
            ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Form(
                key: _formKey,
                child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                  // Basic Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.complementaryElevation,
                      border: Border.all(color: AppTheme.breeze.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                        const Text('Basic Info', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.deepTeal)),
                        const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Product Name'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: 'Description (optional)'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _status,
                          items: const [
                            DropdownMenuItem(value: 'active', child: Text('Active')),
                            DropdownMenuItem(value: 'draft', child: Text('Draft')),
                          ],
                          onChanged: (v) => setState(() => _status = v ?? 'active'),
                          decoration: const InputDecoration(labelText: 'Status'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Pricing & Inventory Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.complementaryElevation,
                      border: Border.all(color: AppTheme.breeze.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pricing & Inventory', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.deepTeal)),
                        const SizedBox(height: 12),
                    TextFormField(
                      controller: _priceController,
                          decoration: const InputDecoration(prefixText: 'R ', labelText: 'Price'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Price is required' : null,
                        ),
                        const SizedBox(height: 12),
                    TextFormField(
                          controller: _stockController,
                          decoration: const InputDecoration(labelText: 'Quantity in stock'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final qty = int.tryParse(_stockController.text.trim());
                            if (qty != null && qty > 0 && qty <= 5) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.warning.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.warning),
                                    SizedBox(width: 6),
                                    Text('Low stock', style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Categories Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.complementaryElevation,
                      border: Border.all(color: AppTheme.breeze.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Categories', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.deepTeal)),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _categoryController.text.isNotEmpty ? _categoryController.text : null,
                          items: _categoryMap.keys
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _categoryController.text = val ?? '';
                              _subcategoryController.clear();
                            });
                          },
                      decoration: const InputDecoration(labelText: 'Category'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Category is required' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _subcategoryController.text.isNotEmpty ? _subcategoryController.text : null,
                          items: (_categoryMap[_categoryController.text] ?? const <String>[]) 
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (val) => setState(() => _subcategoryController.text = val ?? ''),
                          decoration: const InputDecoration(labelText: 'Subcategory (optional)'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Media Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.complementaryElevation,
                      border: Border.all(color: AppTheme.breeze.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Media', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.deepTeal)),
                        const SizedBox(height: 12),
                        LayoutBuilder(builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 360;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              SizedBox(
                                width: isNarrow ? constraints.maxWidth : null,
                                child: ElevatedButton.icon(
                              onPressed: () async {
                                final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                                if (picked != null) {
                                  setState(() {
                                    _pickedImage = File(picked.path);
                                  });
                                }
                              },
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Pick from gallery'),
                                ),
                              ),
                              SizedBox(
                                width: isNarrow ? constraints.maxWidth : null,
                                child: ElevatedButton.icon(
                              onPressed: () async {
                                final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                                if (picked != null) {
                                  setState(() {
                                    _pickedImage = File(picked.path);
                                  });
                                }
                              },
                              icon: const Icon(Icons.photo_camera),
                              label: const Text('Use camera'),
                                ),
                              ),
                            ],
                          );
                        }),
                        const SizedBox(height: 12),
                        if (_pickedImage != null)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                if (_pickedImage == null) return;
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null) return;
                                try {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Uploading image...')),
                                  );
                                  final url = await ImageKitService.uploadProductImage(
                                    file: _pickedImage!,
                                    storeId: widget.initialData['ownerId'] ?? widget.initialData['sellerId'] ?? user.uid,
                                    userId: user.uid,
                                  );
                                  if (url != null && mounted) {
                                    // Save to Firestore immediately so list updates without extra step
                                    await FirebaseFirestore.instance.collection('products').doc(widget.productId).update({
                                      'imageUrl': url,
                                      'timestamp': FieldValue.serverTimestamp(),
                                    });
                                    setState(() {
                                      _imageUrlController.text = url;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Image uploaded and saved')),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to upload image')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Upload error: $e')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.cloud_upload),
                              label: const Text('Upload to ImageKit'),
                            ),
                          ),
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 8),
                        if (_pickedImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _pickedImage!,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        else if (_imageUrlController.text.trim().isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _imageUrlController.text.trim(),
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 160,
                                color: AppTheme.cloud,
                                alignment: Alignment.center,
                                child: const Icon(Icons.image, color: AppTheme.deepTeal),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tip: Paste an image URL or pick an image. Upload to your preferred storage (e.g., ImageKit) and paste the URL here.',
                          style: TextStyle(fontSize: 12, color: AppTheme.cloud),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Live Preview Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.complementaryElevation,
                      border: Border.all(color: AppTheme.breeze.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Preview', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.deepTeal)),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _pickedImage != null
                                  ? Image.file(_pickedImage!, width: 80, height: 80, fit: BoxFit.cover)
                                  : (_imageUrlController.text.trim().isNotEmpty
                                      ? Image.network(
                                          _imageUrlController.text.trim(),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 80,
                                            height: 80,
                                            color: AppTheme.cloud,
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.image, color: AppTheme.deepTeal),
                                          ),
                                        )
                                      : Container(
                                          width: 80,
                                          height: 80,
                                          color: AppTheme.cloud,
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.image, color: AppTheme.deepTeal),
                                        )),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _nameController.text.trim().isEmpty ? 'Product name' : _nameController.text.trim(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.deepTeal),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _descriptionController.text.trim().isEmpty ? 'Description preview' : _descriptionController.text.trim(),
                                    style: const TextStyle(fontSize: 12, color: AppTheme.cloud),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'R ${(_priceController.text.trim().isEmpty ? '0.00' : _priceController.text.trim())}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryGreen),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 60),
                ],
                  ),
                ),
                if (_isDirty() && !_isSaving)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.deepTeal,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.save, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'You have unsaved changes',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                            TextButton(
                      onPressed: _saveChanges,
                              style: TextButton.styleFrom(foregroundColor: Colors.white),
                              child: const Text('Save'),
                    ),
                  ],
                ),
              ),
                    ),
                  ),
              ],
            ),
    ));
  }

  bool _isDirty() {
    final name = _nameController.text.trim();
    final price = _priceController.text.trim();
    final cat = _categoryController.text.trim();
    final sub = _subcategoryController.text.trim();
    final image = _imageUrlController.text.trim();
    final qty = _stockController.text.trim();
    final desc = _descriptionController.text.trim();
    if (name != (widget.initialData['name'] ?? '')) return true;
    if (price != (widget.initialData['price']?.toString() ?? '')) return true;
    if (cat != (widget.initialData['category'] ?? '')) return true;
    if (sub != (widget.initialData['subcategory'] ?? '')) return true;
    if (image != (widget.initialData['imageUrl'] ?? '')) return true;
    final initialQty = (widget.initialData['quantity'] ?? widget.initialData['stock'] ?? '').toString();
    if (qty != initialQty) return true;
    if (desc != (widget.initialData['description'] ?? '')) return true;
    if (_status != ((widget.initialData['status'] as String?)?.toLowerCase() == 'draft' ? 'draft' : 'active')) return true;
    if (_pickedImage != null) return true;
    return false;
  }

  Future<bool> _confirmDiscardChanges() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    return result ?? false;
  }
}
