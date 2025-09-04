import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../services/subcategory_suggestions_service.dart';
import '../services/category_normalizer.dart';

class SmartProductUploadScreen extends StatefulWidget {
  final String? storeId;
  
  const SmartProductUploadScreen({
    Key? key,
    this.storeId,
  }) : super(key: key);

  @override
  State<SmartProductUploadScreen> createState() => _SmartProductUploadScreenState();
}

class _SmartProductUploadScreenState extends State<SmartProductUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  
  String? _suggestedCategory;
  String? _suggestedSubcategory;
  List<String> _savedSuggestions = [];
  String? _selectedCategory;
  String? _selectedSubcategory;
  String? _customSubcategory;
  bool _isCustomSubcategory = false;
  File? _imageFile;
  bool _isUploading = false;
  String? storeCategory; // Store's category from database
  
  // Category-subcategory mapping for your app
  static const Map<String, List<String>> categorySubcategoryMap = {
    'Food': [
      'Baked Goods',      // Bread, Cakes, Donuts, Muffins
      'Fresh Produce',     // Fruits, Vegetables
      'Dairy & Eggs',      // Milk, Cheese, Yogurt, Eggs
      'Meat & Poultry',    // Chicken, Beef, Pork, Fish
      'Pantry Items',      // Rice, Pasta, Flour, Sugar
      'Snacks',            // Chips, Nuts, Crackers
      'Beverages',         // Coffee, Tea, Juices, Water
      'Frozen Foods',      // Ice Cream, Frozen Vegetables
      'Organic Foods',     // Organic Products
      'Candy & Sweets',    // Chocolate, Candy
      'Condiments',        // Sauces, Ketchup, Mustard
      'Other Food Items'
    ],
    'Electronics': [
      'Phones',            // iPhone, Samsung, etc.
      'Laptops',           // MacBook, Dell, HP
      'Tablets',           // iPad, Android tablets
      'Computers',         // Desktop PCs, Monitors
      'Cameras',           // DSLR, Point & Shoot
      'Headphones',        // AirPods, Sony, etc.
      'Speakers',          // Bluetooth speakers
      'Gaming',            // Consoles, Games
      'Smart Home',        // Smart bulbs, Alexa
      'Wearables',         // Smartwatches, Fitbit
      'Accessories',       // Chargers, Cases, Cables
      'Other Electronics'
    ],
    'Clothing': [
      'T-Shirts',          // Cotton shirts, Graphic tees
      'Jeans',             // Denim pants
      'Dresses',           // Summer dresses, Formal
      'Shirts',            // Button-down shirts
      'Pants',             // Khakis, Slacks
      'Shorts',            // Summer shorts
      'Skirts',            // Mini skirts, Maxi skirts
      'Jackets',           // Denim jackets, Blazers
      'Sweaters',          // Wool sweaters, Cardigans
      'Hoodies',           // Pullover hoodies
      'Shoes',             // Sneakers, Boots, Sandals
      'Hats',              // Baseball caps, Beanies
      'Accessories',       // Belts, Scarves, Jewelry
      'Underwear',         // Bras, Underwear
      'Socks',             // Athletic socks, Dress socks
      'Other Clothing'
    ],
    'Other': [
      'Handmade',          // Crafts, DIY items
      'Vintage',           // Antique items
      'Collectibles',      // Trading cards, Figurines
      'Books',             // Fiction, Non-fiction
      'Toys',              // Children's toys
      'Home & Garden',     // Plants, Tools
      'Sports',            // Equipment, Jerseys
      'Beauty',            // Makeup, Skincare
      'Health',            // Vitamins, Supplements
      'Automotive',        // Car parts, Accessories
      'Tools',             // Hardware, DIY tools
      'Miscellaneous'      // Everything else
    ]
  };

  static List<String> get allCategories => categorySubcategoryMap.keys.toList();

  static List<String> getSubcategoriesForCategory(String category) {
    return categorySubcategoryMap[category] ?? [];
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onProductNameChanged);
    _descriptionController.addListener(_onProductNameChanged);
    _loadStoreCategory();
  }

  // Load store category from database
  Future<void> _loadStoreCategory() async {
    if (widget.storeId == null) return;
    
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
        });
      }
    } catch (e) {
      print('Error loading store category: $e');
    }
  }

  // Check if a category is allowed for this store
  bool _isCategoryAllowed(String category) {
    if (storeCategory == null) return true; // Allow all if store category not set
    
    final storeCat = storeCategory!.toLowerCase();
    final selectedCat = category.toLowerCase();
    
    // Allow exact matches
    if (storeCat == selectedCat) return true;
    
    // Allow related categories
    if (storeCat.contains('food') && selectedCat.contains('food')) return true;
    if (storeCat.contains('electronics') && selectedCat.contains('electronics')) return true;
    if (storeCat.contains('clothing') && (selectedCat.contains('clothing') || selectedCat.contains('clothes'))) return true;
    if (storeCat.contains('clothes') && (selectedCat.contains('clothing') || selectedCat.contains('clothes'))) return true;
    
    // Allow "Other" category for all stores
    if (selectedCat == 'other') return true;
    
    return false;
  }

  // Get available categories for this store
  List<String> get _availableCategories {
    return categorySubcategoryMap.keys.where((category) => _isCategoryAllowed(category)).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _onProductNameChanged() {
    final name = _nameController.text;
    final description = _descriptionController.text;
    
    if (name.isNotEmpty) {
      setState(() {
        _suggestedCategory = _suggestCategory(name, description);
        _suggestedSubcategory = _suggestSubcategory(name, _suggestedCategory!);
      });
    }
  }

  String _suggestCategory(String productName, String description) {
    final name = productName.toLowerCase();
    final desc = description.toLowerCase();
    
    // Food detection
    if (name.contains('bread') || name.contains('cake') || name.contains('donut') ||
        name.contains('milk') || name.contains('cheese') || name.contains('apple') ||
        name.contains('chicken') || name.contains('rice') || name.contains('juice') ||
        name.contains('coffee') || name.contains('tea') || name.contains('water') ||
        name.contains('meat') || name.contains('fish') || name.contains('egg') ||
        name.contains('fruit') || name.contains('vegetable') || name.contains('snack') ||
        name.contains('chocolate') || name.contains('candy') || name.contains('sweet') ||
        desc.contains('food') || desc.contains('eat') || desc.contains('fresh') ||
        desc.contains('organic') || desc.contains('gluten') || desc.contains('vegan')) {
      return 'Food';
    }
    
    // Electronics detection
    if (name.contains('phone') || name.contains('laptop') || name.contains('computer') ||
        name.contains('camera') || name.contains('headphone') || name.contains('charger') ||
        name.contains('tablet') || name.contains('ipad') || name.contains('iphone') ||
        name.contains('samsung') || name.contains('macbook') || name.contains('dell') ||
        name.contains('speaker') || name.contains('game') || name.contains('console') ||
        name.contains('smart') || name.contains('watch') || name.contains('fitbit') ||
        desc.contains('electronic') || desc.contains('tech') || desc.contains('digital') ||
        desc.contains('wireless') || desc.contains('bluetooth')) {
      return 'Electronics';
    }
    
    // Clothes detection
    if (name.contains('shirt') || name.contains('dress') || name.contains('jeans') ||
        name.contains('shoes') || name.contains('hat') || name.contains('jacket') ||
        name.contains('pants') || name.contains('short') || name.contains('skirt') ||
        name.contains('sweater') || name.contains('hoodie') || name.contains('sneaker') ||
        name.contains('cap') || name.contains('belt') || name.contains('scarf') ||
        name.contains('underwear') || name.contains('sock') || name.contains('bra') ||
        desc.contains('wear') || desc.contains('fashion') || desc.contains('clothing') ||
        desc.contains('cotton') || desc.contains('denim') || desc.contains('wool')) {
      return 'Clothing';
    }
    
    // Default to Other
    return 'Other';
  }

  String? _suggestSubcategory(String productName, String category) {
    final name = productName.toLowerCase();
    
    switch (category) {
      case 'Food':
        if (name.contains('bread') || name.contains('cake') || name.contains('donut') || 
            name.contains('muffin') || name.contains('croissant') || name.contains('pastry')) 
          return 'Baked Goods';
        if (name.contains('apple') || name.contains('banana') || name.contains('fruit') ||
            name.contains('vegetable') || name.contains('tomato') || name.contains('carrot')) 
          return 'Fresh Produce';
        if (name.contains('milk') || name.contains('cheese') || name.contains('egg') ||
            name.contains('yogurt') || name.contains('butter')) 
          return 'Dairy & Eggs';
        if (name.contains('chicken') || name.contains('beef') || name.contains('meat') ||
            name.contains('pork') || name.contains('fish') || name.contains('salmon')) 
          return 'Meat & Poultry';
        if (name.contains('rice') || name.contains('pasta') || name.contains('flour') ||
            name.contains('sugar') || name.contains('oil') || name.contains('honey')) 
          return 'Pantry Items';
        if (name.contains('chip') || name.contains('snack') || name.contains('crack') ||
            name.contains('popcorn') || name.contains('nut')) 
          return 'Snacks';
        if (name.contains('coffee') || name.contains('tea') || name.contains('juice') ||
            name.contains('water') || name.contains('soda') || name.contains('drink')) 
          return 'Beverages';
        if (name.contains('frozen') || name.contains('ice cream')) 
          return 'Frozen Foods';
        if (name.contains('organic')) 
          return 'Organic Foods';
        if (name.contains('chocolate') || name.contains('candy') || name.contains('sweet')) 
          return 'Candy & Sweets';
        if (name.contains('sauce') || name.contains('ketchup') || name.contains('mustard')) 
          return 'Condiments';
        return 'Other Food Items';
        
      case 'Electronics':
        if (name.contains('phone') || name.contains('iphone') || name.contains('samsung')) 
          return 'Phones';
        if (name.contains('laptop') || name.contains('macbook')) 
          return 'Laptops';
        if (name.contains('tablet') || name.contains('ipad')) 
          return 'Tablets';
        if (name.contains('computer') || name.contains('pc') || name.contains('desktop')) 
          return 'Computers';
        if (name.contains('camera')) 
          return 'Cameras';
        if (name.contains('headphone') || name.contains('airpod') || name.contains('earphone')) 
          return 'Headphones';
        if (name.contains('speaker')) 
          return 'Speakers';
        if (name.contains('game') || name.contains('console')) 
          return 'Gaming';
        if (name.contains('smart') || name.contains('home')) 
          return 'Smart Home';
        if (name.contains('watch') || name.contains('fitbit')) 
          return 'Wearables';
        if (name.contains('charger') || name.contains('cable') || name.contains('case')) 
          return 'Accessories';
        return 'Other Electronics';
        
      case 'Clothing':
        if (name.contains('t-shirt') || name.contains('tshirt')) 
          return 'T-Shirts';
        if (name.contains('jean')) 
          return 'Jeans';
        if (name.contains('dress')) 
          return 'Dresses';
        if (name.contains('shirt')) 
          return 'Shirts';
        if (name.contains('pant')) 
          return 'Pants';
        if (name.contains('short')) 
          return 'Shorts';
        if (name.contains('skirt')) 
          return 'Skirts';
        if (name.contains('jacket')) 
          return 'Jackets';
        if (name.contains('sweater')) 
          return 'Sweaters';
        if (name.contains('hoodie')) 
          return 'Hoodies';
        if (name.contains('shoe') || name.contains('sneaker')) 
          return 'Shoes';
        if (name.contains('hat') || name.contains('cap')) 
          return 'Hats';
        if (name.contains('accessory') || name.contains('belt') || name.contains('scarf')) 
          return 'Accessories';
        if (name.contains('underwear') || name.contains('bra')) 
          return 'Underwear';
        if (name.contains('sock')) 
          return 'Socks';
        return 'Other Clothing';
        
      case 'Other':
        if (name.contains('handmade') || name.contains('craft')) 
          return 'Handmade';
        if (name.contains('vintage') || name.contains('antique')) 
          return 'Vintage';
        if (name.contains('collectible') || name.contains('trading')) 
          return 'Collectibles';
        if (name.contains('book')) 
          return 'Books';
        if (name.contains('toy')) 
          return 'Toys';
        if (name.contains('plant') || name.contains('garden') || name.contains('tool')) 
          return 'Home & Garden';
        if (name.contains('sport') || name.contains('jersey')) 
          return 'Sports';
        if (name.contains('makeup') || name.contains('beauty') || name.contains('skincare')) 
          return 'Beauty';
        if (name.contains('vitamin') || name.contains('health') || name.contains('supplement')) 
          return 'Health';
        if (name.contains('car') || name.contains('automotive')) 
          return 'Automotive';
        if (name.contains('tool') || name.contains('hardware')) 
          return 'Tools';
        return 'Miscellaneous';
        
      default:
        return null;
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        if (kIsWeb) {
          // For web, don't create File object
          _imageFile = null;
        } else {
          _imageFile = File(image.path);
        }
      });
    }
  }

  Future<String?> _uploadImageToImageKitPublic(File file) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('🔍 DEBUG: User not authenticated for image upload');
        return null;
      }
      
      print('🔍 DEBUG: Starting ImageKit upload via callable...');
      final bytes = await file.readAsBytes();
      final callable = FirebaseFunctions.instance.httpsCallable('getImageKitUploadAuth');
      final result = await callable.call();
      final data = result.data;
      if (data is! Map) {
        throw Exception('Invalid ImageKit auth response');
      }
      final authParams = Map<String, dynamic>.from(data as Map);
      final fileName = 'products/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final request = http.MultipartRequest('POST', Uri.parse('https://upload.imagekit.io/api/v1/files/upload'));
      request.fields.addAll({
        'publicKey': (authParams['publicKey'] ?? '').toString(),
        'token': authParams['token'],
        'signature': authParams['signature'],
        'expire': authParams['expire'].toString(),
        'fileName': fileName,
        'folder': 'products/${user.uid}',
        'useUniqueFileName': 'true',
        'tags': 'product,${user.uid}',
      });
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: path.basename(file.path)));
      final streamedResponse = await request.send();
      final uploadResponse = await http.Response.fromStream(streamedResponse);
      if (uploadResponse.statusCode == 200) {
        final resultMap = json.decode(uploadResponse.body);
        return resultMap['url'];
      } else {
        throw Exception('ImageKit upload failed: ${uploadResponse.statusCode} - ${uploadResponse.body}');
      }
    } catch (e) {
      print('🔍 DEBUG: Error uploading image to ImageKit: $e');
      return null;
    }
  }

  Future<void> _uploadProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Check user authentication first
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated. Please log in again.');
      }

      print('🔍 DEBUG: User authenticated: ${user.uid}');
      print('🔍 DEBUG: Store ID: ${widget.storeId}');

      // Check if user is a seller (optional - for debugging)
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          final userRole = userData?['role'];
          print('🔍 DEBUG: User role: $userRole');
          
          if (userRole != 'seller' && userRole != 'admin') {
            print('🔍 DEBUG: Warning - User is not a seller, but continuing upload...');
          }
        }
      } catch (e) {
        print('🔍 DEBUG: Could not verify user role: $e');
      }

      String? imageUrl;
      
      // Upload image if selected
      if (_imageFile != null && !kIsWeb) {
        print('🔍 DEBUG: Starting image upload...');
        imageUrl = await _uploadImageToImageKitPublic(_imageFile!);
        if (imageUrl == null) {
          throw Exception('Failed to upload image to ImageKit');
        }
        print('🔍 DEBUG: Image uploaded successfully: $imageUrl');
      }
      // For web, we need to handle image upload differently
      // TODO: Implement web image upload

      // Validate custom subcategory
      if (_isCustomSubcategory && (_customSubcategory == null || _customSubcategory!.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a custom subcategory')),
        );
        return;
      }

      // Validate regular subcategory
      if (!_isCustomSubcategory && (_selectedSubcategory == null || _selectedSubcategory!.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a subcategory')),
        );
        return;
      }

      // Create product data
      final finalSubcategoryRaw = _isCustomSubcategory ? _customSubcategory!.trim() : _selectedSubcategory!.trim();
      final finalSubcategory = CategoryNormalizer.normalizeSubcategory(finalSubcategoryRaw);
      
      print('🔍 DEBUG: Uploading product with subcategory: $finalSubcategory');
      print('🔍 DEBUG: Is custom subcategory: $_isCustomSubcategory');
      print('🔍 DEBUG: Custom subcategory value: $_customSubcategory');
      print('🔍 DEBUG: Selected subcategory value: $_selectedSubcategory');
      
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

      final productData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': price,
        'quantity': quantity,
        'category': _selectedCategory,
        'subcategory': finalSubcategory,
        'imageUrl': imageUrl ?? '',
        'ownerId': user.uid, // Always use user ID for ownership
        'storeId': widget.storeId, // Store ID for store association
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
      };

      // Save to Firestore
      print('🔍 DEBUG: Saving product to Firestore...');
      print('🔍 DEBUG: Product data: $productData');
      
      final docRef = await FirebaseFirestore.instance
          .collection('products')
          .add(productData);
      
      print('🔍 DEBUG: Product saved successfully with ID: ${docRef.id}');

      // Persist custom subcategory to suggestions for future use
      if (_isCustomSubcategory && _selectedCategory != null) {
        await SubcategorySuggestionsService.addSuggestion(_selectedCategory!, finalSubcategory);
      }

      if (mounted) {
        String successMessage = 'Product uploaded successfully!';
        if (_isCustomSubcategory) {
          successMessage += ' Custom subcategory "${_customSubcategory!.trim()}" was saved.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppTheme.deepTeal,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('🔍 DEBUG: Error uploading product: $e');
      if (mounted) {
        String errorMessage = 'Failed to upload product';
        
        if (e.toString().contains('permission')) {
          errorMessage = 'Permission denied. Please check your authentication.';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection.';
        } else if (e.toString().contains('authentication')) {
          errorMessage = 'Authentication error. Please log in again.';
        } else {
          errorMessage = 'Error: $e';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.primaryRed,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Product'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: AppTheme.angel,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Product Name *',
                  hintText: 'e.g., Chocolate Cake, iPhone 13, Cotton T-Shirt',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a product name';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 16),
              
              // Product Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe your product...',
                  border: OutlineInputBorder(),
                ),
              ),
              
              SizedBox(height: 24),
              
              // Smart Category Suggestion
              if (_suggestedCategory != null) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.deepTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.deepTeal),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: AppTheme.deepTeal,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Smart Suggestion',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.deepTeal,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Category: $_suggestedCategory',
                        style: TextStyle(
                          color: AppTheme.deepTeal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_suggestedSubcategory != null) ...[
                        SizedBox(height: 4),
                        Text(
                          'Subcategory: $_suggestedSubcategory',
                          style: TextStyle(
                            color: AppTheme.deepTeal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedCategory = _suggestedCategory;
                            _selectedSubcategory = _suggestedSubcategory;
                          });
                        },
                        icon: Icon(Icons.check, size: 16),
                        label: Text('Use Suggestion'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.deepTeal,
                          foregroundColor: AppTheme.angel,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
              ],
              
              // Manual Category Selection
              Text(
                'Or select manually:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepTeal,
                ),
              ),
              SizedBox(height: 12),
              
              // Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                ),
                items: categorySubcategoryMap.keys.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) async {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                      _selectedSubcategory = null; // Reset subcategory
                    });
                    final list = await SubcategorySuggestionsService.fetchForCategory(value);
                    if (mounted) setState(() => _savedSuggestions = list);
                  }
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 16),
              
              // Subcategory Selection (only show if category selected)
              if (_selectedCategory != null) ...[
                // Subcategory Dropdown
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _isCustomSubcategory ? null : _selectedSubcategory,
                    decoration: InputDecoration(
                      labelText: _isCustomSubcategory ? 'Subcategory (Custom Selected)' : 'Subcategory',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: Icon(
                        _isCustomSubcategory ? Icons.edit : Icons.category,
                        color: _isCustomSubcategory ? AppTheme.warmAccentColor : AppTheme.deepTeal,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: _isCustomSubcategory ? AppTheme.warmAccentColor.withOpacity(0.1) : AppTheme.angel,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Select subcategory...'),
                      ),
                      ...{...getSubcategoriesForCategory(_selectedCategory!), ..._savedSuggestions}.map((subcategory) {
                        return DropdownMenuItem(
                          value: subcategory,
                          child: Text(subcategory),
                        );
                      }),
                      DropdownMenuItem(
                        value: 'custom',
                        child: Row(
                          children: [
                            Icon(Icons.add, color: AppTheme.deepTeal, size: 16),
                            SizedBox(width: 8),
                            Text('Custom Subcategory'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        if (value == 'custom') {
                          _isCustomSubcategory = true;
                          _selectedSubcategory = null;
                        } else {
                          _isCustomSubcategory = false;
                          _selectedSubcategory = value;
                          _customSubcategory = null;
                        }
                      });
                    },
                  ),
                ),
                
                // Custom Subcategory Text Field
                if (_isCustomSubcategory) ...[
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Custom Subcategory *',
                        hintText: 'e.g., Honey, Artisan Bread, Local Produce',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(
                          Icons.edit,
                          color: AppTheme.deepTeal,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: AppTheme.angel,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _customSubcategory = value.trim();
                        });
                      },
                      validator: (value) {
                        if (_isCustomSubcategory && (value == null || value.trim().isEmpty)) {
                          return 'Please enter a custom subcategory';
                        }
                        if (value != null && value.trim().length < 2) {
                          return 'Subcategory must be at least 2 characters';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ],
              
              SizedBox(height: 16),
              
              // Price
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Price *',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 16),
              
              // Quantity
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter quantity';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid quantity';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 24),
              
              // Image Upload
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.cloud),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Product Image',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.deepTeal,
                      ),
                    ),
                    SizedBox(height: 12),
                    if (_imageFile != null) ...[
                      Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                    ],
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.photo_camera),
                      label: Text(_imageFile != null ? 'Change Image' : 'Add Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.deepTeal,
                        foregroundColor: AppTheme.angel,
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 32),
              
              // Upload Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _uploadProduct,
                  child: _isUploading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.angel),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Uploading...'),
                          ],
                        )
                      : Text('Upload Product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deepTeal,
                    foregroundColor: AppTheme.angel,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 