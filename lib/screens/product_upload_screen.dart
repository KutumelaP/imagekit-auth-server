import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class ProductUploadScreen extends StatefulWidget {
  final String storeId;
  final String storeName;

  const ProductUploadScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<ProductUploadScreen> createState() => _ProductUploadScreenState();
}

class _ProductUploadScreenState extends State<ProductUploadScreen> {

  Widget _buildWebCompatibleImage(File imageFile, {BoxFit? fit, double? width, double? height}) {
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: imageFile.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(snapshot.data!, fit: fit ?? BoxFit.cover, width: width, height: height);
          } else if (snapshot.hasError) {
            return Container(color: Colors.grey[200], child: const Icon(Icons.error, size: 32, color: Colors.red));
          } else {
            return Container(color: Colors.grey[100], child: const Center(child: CircularProgressIndicator()));
          }
        },
      );
    } else {
      return Image.file(imageFile, fit: fit ?? BoxFit.cover, width: width, height: height);
    }
  }
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  
  String selectedCategory = 'Food';
  String selectedSubcategory = 'Baked Goods';
  String? storeCategory; // Store's category from database
  File? selectedImage;
  bool isUploading = false;
  String uploadStatus = '';
  
  // Customization fields
  bool isCustomizable = false;
  List<Map<String, dynamic>> addOns = [];
  List<Map<String, dynamic>> subtractions = [];

  final List<String> categories = [
    'Food',
    'Clothing',
    'Electronics',
    'Home & Garden',
    'Beauty & Health',
    'Sports & Outdoors',
    'Books & Media',
    'Other'
  ];

  final Map<String, List<String>> subcategories = {
    'Food': ['Baked Goods', 'Fresh Produce', 'Dairy', 'Meat', 'Beverages', 'Snacks', 'Other'],
    'Clothing': ['Men', 'Women', 'Children', 'Accessories', 'Shoes', 'Other'],
    'Electronics': ['Phones', 'Computers', 'Audio', 'Cameras', 'Gaming', 'Other'],
    'Home & Garden': ['Furniture', 'Decor', 'Kitchen', 'Garden', 'Tools', 'Other'],
    'Beauty & Health': ['Skincare', 'Makeup', 'Hair Care', 'Fragrances', 'Supplements', 'Other'],
    'Sports & Outdoors': ['Fitness', 'Camping', 'Cycling', 'Water Sports', 'Team Sports', 'Other'],
    'Books & Media': ['Fiction', 'Non-Fiction', 'Educational', 'Magazines', 'Music', 'Other'],
    'Other': ['Miscellaneous']
  };

  @override
  void initState() {
    super.initState();
    _loadStoreCategory();
  }

  // Load store category from database
  Future<void> _loadStoreCategory() async {
    try {
      final storeDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.storeId)
          .get();
      
      if (storeDoc.exists) {
        final storeData = storeDoc.data() as Map<String, dynamic>;
        final category = storeData['storeCategory'] as String?;
        
        setState(() {
          storeCategory = category;
          // Set default category based on store category
          if (category != null && category.isNotEmpty) {
            selectedCategory = category;
            selectedSubcategory = subcategories[category]?.first ?? 'Other';
          }
        });
      }
    } catch (e) {
      print('Error loading store category: $e');
    }
  }



  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
      setState(() {
          selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _uploadProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedImage == null) {
      _showErrorSnackBar('Please select an image for your product');
      return;
    }

    setState(() {
      isUploading = true;
      uploadStatus = 'Uploading product...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Upload image first
      uploadStatus = 'Uploading image...';
      final imageUrl = await _uploadImageToImageKit(
        selectedImage!,
        widget.storeId,
        user.uid,
      );

      // Parse price safely, removing currency symbols and commas
      final priceText = _priceController.text.replaceAll(RegExp(r'[R,\s]'), '');
      final price = double.tryParse(priceText);
      if (price == null || price <= 0) {
        throw Exception('Invalid price format. Please enter a valid price.');
      }

      // Parse quantity safely
      final quantityText = _quantityController.text.trim();
      final quantity = int.tryParse(quantityText);
      if (quantity == null || quantity < 0) {
        throw Exception('Invalid quantity. Please enter a valid number.');
      }

      // Create product data
      uploadStatus = 'Creating product...';
      final Map<String, dynamic> productData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': price,
        'quantity': quantity,
        'category': selectedCategory,
        'subcategory': selectedSubcategory,
        'imageUrl': imageUrl,
        'storeId': widget.storeId,
        'ownerId': user.uid,
        'status': 'active',
        'timestamp': FieldValue.serverTimestamp(),
        'customizable': isCustomizable,
      };
      
      // Add customizations if enabled
      if (isCustomizable) {
        productData['customizations'] = {
          'addOns': addOns.where((addon) => addon['name'].toString().isNotEmpty).toList(),
          'subtractions': subtractions.where((subtract) => subtract['name'].toString().isNotEmpty).toList(),
        };
      }

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('products')
          .add(productData);

      setState(() {
        isUploading = false;
        uploadStatus = 'Product uploaded successfully!';
      });

      _showSuccessSnackBar('Product uploaded successfully!');
      
      // Reset form
      _resetForm();
      
      // Navigate back after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });

    } catch (e) {
      print('❌ Error uploading product: $e');
      setState(() {
        isUploading = false;
        uploadStatus = 'Upload failed: $e';
      });
      _showErrorSnackBar('Failed to upload product: $e');
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _quantityController.clear();
    setState(() {
      selectedImage = null;
      selectedCategory = 'Food';
      selectedSubcategory = 'Baked Goods';
      isCustomizable = false;
      addOns.clear();
      subtractions.clear();
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String> _uploadImageToImageKit(File file, String storeId, String userId) async {
    try {
      final bytes = await file.readAsBytes();
      
      final request = http.MultipartRequest('POST', Uri.parse('https://upload.imagekit.io/api/v1/files/upload'));
      request.headers.addAll({
        'Authorization': 'Basic dXBsb2FkXzU3Vld6YjdEcUtISEZ1NzM6',
      });
      request.fields.addAll({
        'fileName': path.basename(file.path),
        'folder': 'products/$storeId',
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
        throw Exception('Upload failed: ${uploadResponse.body}');
      }
    } catch (e) {
      print('❌ ImageKit upload error: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.whisper,
      appBar: AppBar(
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Add New Product',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (isUploading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              // Store Info
          Container(
                padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                  color: AppTheme.deepTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                    const Icon(
                      Icons.store,
                    color: AppTheme.deepTeal,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.storeName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.deepTeal,
                            ),
                          ),
                          Text(
                            'Adding product to this store',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.mediumGrey,
                            ),
                          ),
                        ],
            ),
          ),
        ],
      ),
              ),

              const SizedBox(height: 24),

              // Image Upload Section
              _buildImageUploadSection(),

              const SizedBox(height: 24),

              // Product Details Section
              _buildProductDetailsSection(),

              const SizedBox(height: 24),

              // Category Section
              _buildCategorySection(),

              const SizedBox(height: 24),

              // Customization Section
              _buildCustomizationSection(),

              const SizedBox(height: 32),

              // Upload Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isUploading ? null : _uploadProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deepTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isUploading ? 'Uploading...' : 'Upload Product',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              if (uploadStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    uploadStatus,
                  style: TextStyle(
                      color: uploadStatus.contains('successfully') 
                          ? Colors.green 
                          : uploadStatus.contains('failed') 
                              ? Colors.red 
                              : AppTheme.deepTeal,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Image',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.deepTeal,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 200,
            width: double.infinity,
          decoration: BoxDecoration(
              color: AppTheme.cloud,
            borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.deepTeal.withOpacity(0.3),
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildWebCompatibleImage(
                      selectedImage!,
                      fit: BoxFit.cover,
      width: double.infinity,
                      height: double.infinity,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(
                        Icons.add_photo_alternate,
                        size: 48,
                        color: AppTheme.deepTeal.withOpacity(0.6),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add product image',
                  style: TextStyle(
                          color: AppTheme.deepTeal.withOpacity(0.6),
                          fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.deepTeal,
          ),
        ),
        const SizedBox(height: 12),
        
        // Product Name
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Product Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.shopping_bag),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a product name';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // Description
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description (Optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.description),
          ),
          maxLines: 3,
        ),
        
        const SizedBox(height: 16),
        
        // Price and Quantity Row
        Row(
                    children: [
            Expanded(
              child: TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (R)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.receipt),
                ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid price';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Price must be greater than 0';
                  }
                          return null;
                        },
                      ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                        controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter quantity';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid quantity';
                  }
                  if (int.parse(value) < 0) {
                    return 'Quantity cannot be negative';
                  }
                          return null;
                        },
                      ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.deepTeal,
          ),
        ),
        const SizedBox(height: 12),
        
        // Category Dropdown
        DropdownButtonFormField<String>(
          value: selectedCategory,
          decoration: const InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category),
          ),
          items: categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                selectedCategory = value;
                selectedSubcategory = subcategories[value]!.first;
              });
            }
          },
        ),
        
        const SizedBox(height: 16),
        
        // Subcategory Dropdown
        DropdownButtonFormField<String>(
          value: selectedSubcategory,
          decoration: const InputDecoration(
            labelText: 'Subcategory',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.subdirectory_arrow_right),
          ),
          items: subcategories[selectedCategory]!.map((subcategory) {
            return DropdownMenuItem(
              value: subcategory,
              child: Text(subcategory),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedSubcategory = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCustomizationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customization Options',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.deepTeal,
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
        ),
        
        if (isCustomizable) ...[
          const SizedBox(height: 16),
          
          // Add-ons Section
          _buildAddOnsSection(),
          
          const SizedBox(height: 16),
          
          // Subtractions Section
          _buildSubtractionsSection(),
        ],
      ],
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
                      subtractions[index]['price'] = double.tryParse(value) ?? 0.0;
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
}

