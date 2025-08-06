import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../constants/app_constants.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../theme/admin_theme.dart';

class SellerProductsSection extends StatelessWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  const SellerProductsSection({Key? key, required this.auth, required this.firestore}) : super(key: key);

  Future<List<Map<String, dynamic>>> _fetchProducts(String sellerId) async {
    final snap = await firestore.collection('products').where('ownerId', isEqualTo: sellerId).get();
    return snap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  void _showProductDialog(BuildContext context, {Map<String, dynamic>? product, required Function(Map<String, dynamic>) onSave}) {
    final nameController = TextEditingController(text: product?['name'] ?? '');
    final priceController = TextEditingController(text: product?['price']?.toString() ?? '');
    final imageUrlController = TextEditingController(text: product?['imageUrl'] ?? '');
    final quantityController = TextEditingController(text: product?['quantity']?.toString() ?? '');
    String status = product?['status'] ?? 'active';
    File? _imageFile;
    bool _uploading = false;
    String? _error;
    void _pickImage(StateSetter setState) async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
        });
      }
    }
    Future<String?> _uploadImageToImageKit(File file, String sellerId) async {
      try {
        final response = await http.get(Uri.parse(AppConstants.backendUrl));
        if (response.statusCode != 200) {
          throw Exception('Failed to get authentication parameters');
        }
        final authParams = json.decode(response.body);
        final bytes = await file.readAsBytes();
        final fileName = 'products/$sellerId/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
        final publicKey = 'public_tAO0SkfLl/37FQN+23c/bkAyfYg=';
        final token = authParams['token'];
        final signature = authParams['signature'];
        final expire = authParams['expire'];
        if (publicKey == null || token == null || signature == null || expire == null) {
          return null;
        }
        final request = http.MultipartRequest(
          'POST',
          Uri.parse(AppConstants.imageKitUploadUrl),
        );
        request.fields.addAll({
          'publicKey': publicKey,
          'token': token,
          'signature': signature,
          'expire': expire.toString(),
          'fileName': fileName,
          'folder': 'products/$sellerId',
        });
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: path.basename(file.path),
          ),
        );
        final streamedResponse = await request.send();
        final uploadResponse = await http.Response.fromStream(streamedResponse);
        if (uploadResponse.statusCode == 200) {
          final result = json.decode(uploadResponse.body);
          return result['url'];
        } else {
          return null;
        }
      } catch (e) {
        return null;
      }
    }
    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 420),
          child: StatefulBuilder(
            builder: (ctx, setState) => AlertDialog(
              title: Text(product == null ? 'Add Product' : 'Edit Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: 'Product Name', errorText: _error == 'name' ? 'Name required' : null),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: priceController,
                      decoration: InputDecoration(labelText: 'Price', errorText: _error == 'price' ? 'Price required' : null),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: quantityController,
                      decoration: InputDecoration(labelText: 'Quantity', errorText: _error == 'quantity' ? 'Quantity required' : null),
                      keyboardType: TextInputType.numberWithOptions(decimal: false),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _imageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb
                                  ? Container(
                                      height: 56,
                                      width: 56,
                                      color: AdminTheme.lightGrey,
                                      child: Icon(Icons.image, color: AdminTheme.mediumGrey, size: 24),
                                    )
                                  : Image.file(_imageFile!, height: 56, width: 56, fit: BoxFit.cover),
                            )
                          : (imageUrlController.text.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(imageUrlController.text, height: 56, width: 56, fit: BoxFit.cover),
                                )
                              : Container(
                                  height: 56, width: 56,
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AdminTheme.lightGrey),
                                  child: Icon(Icons.image, color: AdminTheme.mediumGrey),
                                )),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: Icon(Icons.upload),
                          label: Text('Pick Image'),
                          onPressed: _uploading ? null : () => _pickImage(setState),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('Active')),
                        DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                      ],
                      onChanged: (v) => status = v ?? 'active',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: AdminTheme.angel,
                    textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _uploading
                      ? null
                      : () async {
                          setState(() => _error = null);
                          final name = nameController.text.trim();
                          final price = double.tryParse(priceController.text.trim()) ?? 0.0;
                          final quantity = int.tryParse(quantityController.text.trim());
                          if (name.isEmpty) {
                            setState(() => _error = 'name');
                            return;
                          }
                          if (price <= 0) {
                            setState(() => _error = 'price');
                            return;
                          }
                          if (quantity == null || quantity < 0) {
                            setState(() => _error = 'quantity');
                            return;
                          }
                          if (_imageFile == null && imageUrlController.text.isEmpty) {
                            setState(() => _error = 'Image required');
                            return;
                          }
                          String imageUrl = imageUrlController.text;
                          if (_imageFile != null) {
                            setState(() => _uploading = true);
                            final sellerId = FirebaseAuth.instance.currentUser?.uid ?? '';
                            final url = await _uploadImageToImageKit(_imageFile!, sellerId);
                            setState(() => _uploading = false);
                            if (url == null) {
                              setState(() => _error = 'Image upload failed');
                              return;
                            }
                            imageUrl = url;
                          }
                          onSave({
                            'name': name,
                            'price': price,
                            'quantity': quantity,
                            'imageUrl': imageUrl,
                            'status': status,
                          });
                          Navigator.pop(ctx);
                        },
                  child: _uploading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sellerId = auth.currentUser?.uid;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: sellerId != null ? _fetchProducts(sellerId) : Future.value([]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('My Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                  ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('Add Product'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: AdminTheme.angel,
                      textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      _showProductDialog(context, onSave: (newProduct) async {
                        await firestore.collection('products').add({
                          ...newProduct,
                          'ownerId': sellerId,
                        });
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (products.isEmpty)
                const Center(child: Text('No products found.'))
              else
                ...products.map((product) => _ProductCard(
                  product: product,
                  onEdit: (updated) async {
                    await firestore.collection('products').doc(product['id']).update(updated);
                  },
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Delete Product'),
                        content: Text('Are you sure you want to delete this product?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await firestore.collection('products').doc(product['id']).delete();
                    }
                  },
                  onShowEdit: () {
                    _showProductDialog(context, product: product, onSave: (updated) async {
                      await firestore.collection('products').doc(product['id']).update(updated);
                    });
                  },
                )),
            ],
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  final Future<void> Function() onDelete;
  final VoidCallback onShowEdit;
  const _ProductCard({required this.product, required this.onEdit, required this.onDelete, required this.onShowEdit});

  @override
  Widget build(BuildContext context) {
    final name = product['name'] ?? 'Unnamed';
    final price = product['price'] ?? 0.0;
    final status = product['status'] ?? 'active';
    final imageUrl = product['imageUrl'] ?? '';
    final quantity = product['quantity'] ?? 0;
    final isLowStock = quantity <= 5 && quantity > 0;
    final isOutOfStock = quantity == 0;
    final textColor = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final imageWidget = imageUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl, 
                  height: 56, 
                  width: 56, 
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading product image: $error');
                    return Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.image, color: Colors.grey[400]),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              )
            : Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.store, color: Theme.of(context).colorScheme.primary, size: 28),
              );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
            Text('R${price.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
            Row(
              children: [
                Text('Stock: $quantity', style: TextStyle(fontWeight: FontWeight.bold, color: isOutOfStock ? Theme.of(context).colorScheme.error : isLowStock ? AdminTheme.warning : textColor)),
                if (isOutOfStock)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Chip(
                      label: Text('Out of Stock', style: TextStyle(color: AdminTheme.angel, fontWeight: FontWeight.bold, fontSize: 14)),
                      backgroundColor: Theme.of(context).colorScheme.errorContainer,
                    ),
                  ),
                if (isLowStock && !isOutOfStock)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: _LowStockPulse(),
                  ),
              ],
            ),
          ],
        );
        final actions = Wrap(
          spacing: 8,
          children: [
            Chip(
              label: Text(status.toUpperCase()),
              backgroundColor: status == 'active' ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.errorContainer,
              labelStyle: TextStyle(color: AdminTheme.angel, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            IconButton(
              icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
              tooltip: 'Edit',
              onPressed: onShowEdit,
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
          ],
        );
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [imageWidget, const SizedBox(width: 12), Expanded(child: details)],
                      ),
                      const SizedBox(height: 12),
                      actions,
                    ],
                  )
                : Row(
                    children: [
                      imageWidget,
                      const SizedBox(width: 12),
                      Expanded(child: details),
                      actions,
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _LowStockPulse extends StatefulWidget {
  @override
  State<_LowStockPulse> createState() => _LowStockPulseState();
}

class _LowStockPulseState extends State<_LowStockPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + 0.15 * _controller.value;
        final color = Color.lerp(AdminTheme.warning, AdminTheme.error, _controller.value)!;
        return Row(
          children: [
            Transform.scale(
              scale: scale,
              child: Icon(Icons.warning, color: color, size: 20),
            ),
            const SizedBox(width: 2),
            Text('Low Stock', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        );
      },
    );
  }
} 