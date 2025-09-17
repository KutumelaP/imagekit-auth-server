import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
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

  Widget _buildWebCompatibleImage(File imageFile, {BoxFit? fit, double? width, double? height}) {
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: imageFile.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              fit: fit ?? BoxFit.cover,
              width: width,
              height: height,
            );
          } else if (snapshot.hasError) {
            return Container(
              color: Colors.grey[200],
              child: const Icon(Icons.error, size: 32, color: Colors.red),
            );
          } else {
            return Container(
              color: Colors.grey[100],
              child: const Center(child: CircularProgressIndicator()),
            );
          }
        },
      );
    } else {
      return Image.file(
        imageFile,
        fit: fit ?? BoxFit.cover,
        width: width,
        height: height,
      );
    }
  }

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
  
  // Customization fields
  bool isCustomizable = false;
  List<Map<String, dynamic>> addOns = [];
  List<Map<String, dynamic>> subtractions = [];

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
    
    // Initialize customization fields
    isCustomizable = widget.initialData['customizable'] == true;
    if (isCustomizable && widget.initialData['customizations'] != null) {
      final customizations = widget.initialData['customizations'] as Map<String, dynamic>;
      addOns = List<Map<String, dynamic>>.from(customizations['addOns'] ?? []);
      subtractions = List<Map<String, dynamic>>.from(customizations['subtractions'] ?? []);
    }

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

      final Map<String, dynamic> updateData = {
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
        'customizable': isCustomizable,
      };
      
      // Add customizations if enabled
      if (isCustomizable) {
        updateData['customizations'] = {
          'addOns': addOns.where((addon) => addon['name'].toString().isNotEmpty).toList(),
          'subtractions': subtractions.where((subtract) => subtract['name'].toString().isNotEmpty).toList(),
        };
      }
      
      await FirebaseFirestore.instance.collection('products').doc(widget.productId).update(updateData);

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
                            child: _buildWebCompatibleImage(
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
                  // Customization Section
                  _buildCustomizationSection(),
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
                                  ? _buildWebCompatibleImage(_pickedImage!, width: 80, height: 80, fit: BoxFit.cover)
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

  Widget _buildCustomizationSection() {
    return Container(
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
          const Text(
            'Customization Options',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.deepTeal,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          
          // Enable Customization Toggle
          CheckboxListTile(
            title: const Text('Allow customers to customize this product'),
            subtitle: const Text('Add-ons and subtractions (e.g., extra chicken, no onions)'),
            value: isCustomizable,
            onChanged: (value) {
              setState(() {
                isCustomizable = value ?? false;
                if (!isCustomizable) {
                  addOns.clear();
                  subtractions.clear();
                }
              });
            },
            activeColor: AppTheme.deepTeal,
            contentPadding: EdgeInsets.zero,
          ),
          
            if (isCustomizable) ...[
              const SizedBox(height: 16),
              
              // Add-ons Section
              _buildAddOnsSection(),
              
              const SizedBox(height: 16),
              
              // Subtractions Section
              _buildSubtractionsSection(),
            ],
            
            const SizedBox(height: 16),
            
            // Price Breakdown Section (always visible)
            _buildPriceBreakdownSection(),
        ],
      ),
    );
  }

  Widget _buildAddOnsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Add-ons (Extra items)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.deepTeal,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  addOns.add({
                    'id': 'addon_${DateTime.now().millisecondsSinceEpoch}',
                    'name': '',
                    'price': 0.0,
                  });
                });
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        
        ...addOns.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> addOn = entry.value;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.whisper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cloud),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: addOn['name'],
                    decoration: const InputDecoration(
                      labelText: 'Add-on name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      addOns[index]['name'] = value;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: addOn['price'].toString(),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                      prefixText: 'R',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      addOns[index]['price'] = double.tryParse(value) ?? 0.0;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      addOns.removeAt(index);
                    });
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSubtractionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Subtractions (Remove items)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.deepTeal,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  subtractions.add({
                    'id': 'subtract_${DateTime.now().millisecondsSinceEpoch}',
                    'name': '',
                    'price': 0.0,
                  });
                });
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        
        ...subtractions.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> subtraction = entry.value;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.whisper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cloud),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: subtraction['name'],
                    decoration: const InputDecoration(
                      labelText: 'Subtraction name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      subtractions[index]['name'] = value;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: subtraction['price'].toString(),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                      prefixText: 'R',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final newPrice = double.tryParse(value) ?? 0.0;
                      final basePrice = double.tryParse(_priceController.text) ?? 0.0;
                      final maxSubtraction = basePrice * 0.9; // Max 90% reduction
                      
                      // Convert to negative for subtractions (if positive entered)
                      final subtractionPrice = newPrice > 0 ? -newPrice : newPrice;
                      
                      if (subtractionPrice.abs() > maxSubtraction) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Subtraction price too high. Max reduction: R${maxSubtraction.toStringAsFixed(2)}'),
                            backgroundColor: AppTheme.warning,
                          ),
                        );
                        return;
                      }
                      
                      subtractions[index]['price'] = subtractionPrice;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      subtractions.removeAt(index);
                    });
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildPriceBreakdownSection() {
    final basePrice = double.tryParse(_priceController.text) ?? 0.0;
    final addOnTotal = addOns.fold(0.0, (sum, addon) => sum + (addon['price'] ?? 0.0));
    final subtractionTotal = subtractions.fold(0.0, (sum, subtract) => sum + (subtract['price'] ?? 0.0));
    final maxPrice = basePrice + addOnTotal;
    final minPrice = basePrice + subtractionTotal;
    
    // Calculate tiered commission fees (based on actual system)
    // Tier 1: R0-R25 → 4% + R3.00
    // Tier 2: R25-R100 → 6% + R2.00  
    // Tier 3: R100+ → 8% + R0.00
    const serviceFeeRate = 0.035; // 3.5% service fee
    const payfastFeeRate = 0.029; // 2.9% PayFast fee (no fixed fee)
    
    // Calculate tiered commission for max price
    double maxCommission = 0.0;
    double maxSmallOrderFee = 0.0;
    if (maxPrice <= 25.0) {
      // Tier 1: Small Orders (R0-R25)
      maxCommission = maxPrice * 0.04; // 4%
      maxSmallOrderFee = 3.0; // R3.00
    } else if (maxPrice <= 100.0) {
      // Tier 2: Medium Orders (R25-R100)
      maxCommission = maxPrice * 0.06; // 6%
      maxSmallOrderFee = 2.0; // R2.00
    } else {
      // Tier 3: Large Orders (R100+)
      maxCommission = maxPrice * 0.08; // 8%
      maxSmallOrderFee = 0.0; // No small order fee
    }
    
    // Calculate tiered commission for min price
    double minCommission = 0.0;
    double minSmallOrderFee = 0.0;
    if (minPrice <= 25.0) {
      // Tier 1: Small Orders (R0-R25)
      minCommission = minPrice * 0.04; // 4%
      minSmallOrderFee = 3.0; // R3.00
    } else if (minPrice <= 100.0) {
      // Tier 2: Medium Orders (R25-R100)
      minCommission = minPrice * 0.06; // 6%
      minSmallOrderFee = 2.0; // R2.00
    } else {
      // Tier 3: Large Orders (R100+)
      minCommission = minPrice * 0.08; // 8%
      minSmallOrderFee = 0.0; // No small order fee
    }
    
    // Calculate other fees
    final maxServiceFee = maxPrice * serviceFeeRate;
    final maxPayfastFee = maxPrice * payfastFeeRate;
    final maxTotalFees = maxCommission + maxSmallOrderFee + maxServiceFee + maxPayfastFee;
    final maxEarnings = maxPrice - maxTotalFees;
    
    final minServiceFee = minPrice * serviceFeeRate;
    final minPayfastFee = minPrice * payfastFeeRate;
    final minTotalFees = minCommission + minSmallOrderFee + minServiceFee + minPayfastFee;
    final minEarnings = minPrice - minTotalFees;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.whisper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cloud),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate, color: AppTheme.deepTeal, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Price Breakdown & Earnings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Base Price
          _buildBreakdownRow('Base Product Price', basePrice, isBase: true),
          
          // Add-ons
          if (addOns.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildBreakdownRow('Add-ons Total', addOnTotal, isAddOn: true),
            for (var addon in addOns.where((a) => a['name'].toString().isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: _buildBreakdownRow(
                  '• ${addon['name']}', 
                  addon['price'] ?? 0.0, 
                  isSubItem: true
                ),
              ),
          ],
          
          // Subtractions
          if (subtractions.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildBreakdownRow('Subtractions Total', subtractionTotal, isSubtraction: true),
            for (var subtract in subtractions.where((s) => s['name'].toString().isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: _buildBreakdownRow(
                  '• ${subtract['name']}', 
                  subtract['price'] ?? 0.0, 
                  isSubItem: true
                ),
              ),
          ],
          
          const Divider(height: 24),
          
          // Price Range
          _buildBreakdownRow('Customer Price Range', null, isHeader: true),
          const SizedBox(height: 8),
          _buildBreakdownRow('  Minimum Price', minPrice, isSubItem: true),
          _buildBreakdownRow('  Maximum Price', maxPrice, isSubItem: true),
          
          const Divider(height: 24),
          
          // Fee Breakdown
          _buildBreakdownRow('Fee Breakdown', null, isHeader: true),
          const SizedBox(height: 8),
          _buildBreakdownRow('  Platform Commission', maxCommission, isSubItem: true),
          _buildBreakdownRow('  Small Order Fee', maxSmallOrderFee, isSubItem: true),
          _buildBreakdownRow('  Service Fee (3.5%)', maxServiceFee, isSubItem: true),
          _buildBreakdownRow('  PayFast Fee (2.9%)', maxPayfastFee, isSubItem: true),
          _buildBreakdownRow('  Total Fees', maxTotalFees, isSubtraction: true),
          
          const Divider(height: 24),
          
          // Your Earnings (after all fees)
          _buildBreakdownRow('Your Earnings Range', null, isHeader: true),
          const SizedBox(height: 8),
          _buildBreakdownRow('  Minimum Earnings', minEarnings, isEarnings: true),
          _buildBreakdownRow('  Maximum Earnings', maxEarnings, isEarnings: true),
          
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.success, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Tiered Commission System:',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '• R0-R25: 4% + R3.00\n• R25-R100: 6% + R2.00\n• R100+: 8% + R0.00',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, double? value, {
    bool isBase = false,
    bool isAddOn = false,
    bool isSubtraction = false,
    bool isEarnings = false,
    bool isHeader = false,
    bool isSubItem = false,
  }) {
    Color? textColor;
    FontWeight? fontWeight;
    
    if (isHeader) {
      textColor = AppTheme.deepTeal;
      fontWeight = FontWeight.w600;
    } else if (isEarnings) {
      textColor = AppTheme.success;
      fontWeight = FontWeight.w600;
    } else if (isBase) {
      textColor = AppTheme.deepTeal;
      fontWeight = FontWeight.w500;
    } else if (isAddOn) {
      textColor = AppTheme.success;
    } else if (isSubtraction) {
      textColor = AppTheme.error;
    } else if (isSubItem) {
      textColor = AppTheme.cloud;
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSubItem ? 12 : 14,
            color: textColor,
            fontWeight: fontWeight,
          ),
        ),
        if (value != null)
          Text(
            'R${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isSubItem ? 12 : 14,
              color: textColor,
              fontWeight: fontWeight,
            ),
          ),
      ],
    );
  }
}
