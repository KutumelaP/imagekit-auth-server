import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:path/path.dart' as path;
import '../theme/app_theme.dart';
import '../services/category_normalizer.dart';
import '../constants/app_constants.dart';
import '../services/subcategory_suggestions_service.dart';
import '../services/subcategory_suggestions_service.dart';

class StunningProductUpload extends StatefulWidget {
  final String storeId;
  final String storeName;

  const StunningProductUpload({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<StunningProductUpload> createState() => _StunningProductUploadState();
}

class _StunningProductUploadState extends State<StunningProductUpload>
    with TickerProviderStateMixin {

  Widget _buildWebCompatibleImage(File imageFile, {BoxFit? fit, double? width, double? height}) {
    if (kIsWeb) {
      // On web, read file bytes and use Image.memory
      return FutureBuilder<Uint8List>(
        future: imageFile.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              fit: fit ?? BoxFit.cover,
              width: width,
              height: height,
              errorBuilder: (context, error, stackTrace) {
                print('🔍 DEBUG: Error loading image memory: $error');
                return Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.error, size: 32, color: Colors.red),
                );
              },
            );
          } else if (snapshot.hasError) {
            print('🔍 DEBUG: Error reading image bytes: ${snapshot.error}');
            return Container(
              color: Colors.grey[200],
              child: const Icon(Icons.error, size: 32, color: Colors.red),
            );
          } else {
            return Container(
              color: Colors.grey[100],
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
        },
      );
    } else {
      // On mobile, use Image.file
      return Image.file(
        imageFile,
        fit: fit ?? BoxFit.cover,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          print('🔍 DEBUG: Error loading image file: $error');
          return Container(
            color: Colors.grey[200],
            child: const Icon(Icons.error, size: 32, color: Colors.red),
          );
        },
      );
    }
  }

  // Form Controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _subcategoryController = TextEditingController();
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  // State Variables
  String selectedCategory = 'Food';
  String selectedSubcategory = 'Baked Goods';
  List<String> _savedSuggestions = [];
  String selectedCondition = 'New'; // New, Second Hand, Refurbished
  bool _categoryLocked = false; // lock category if loaded from store
  File? selectedImage;
  Uint8List? selectedImageBytes; // For web support
  bool isUploading = false;
  String uploadStatus = '';
  int currentStep = 0;
  
  // Product condition options
  final List<String> _conditionOptions = [
    'New',
    'Second Hand', 
    'Refurbished'
  ];
  
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    print('🔍 DEBUG: StunningProductUpload initState called');
    print('🔍 DEBUG: storeId = ${widget.storeId}');
    print('🔍 DEBUG: storeName = ${widget.storeName}');
    _initializeAnimations();
    // Load store category immediately and ensure it's set
    _loadStoreCategory().then((_) {
      print('🔍 DEBUG: _loadStoreCategory completed, selectedCategory: $selectedCategory');
      // Force a rebuild to ensure the UI reflects the correct category
      if (mounted) {
        setState(() {});
      }
      _loadSavedSubcategories();
    });
  }

  Future<void> _loadSavedSubcategories() async {
    final list = await SubcategorySuggestionsService.fetchForCategory(selectedCategory);
    if (mounted) setState(() => _savedSuggestions = list);
  }

  // Load store category from store registration
  Future<void> _loadStoreCategory() async {
    try {
      print('🔍 DEBUG: _loadStoreCategory called for storeId: ${widget.storeId}');
      // Use provided storeId if valid; otherwise default to current user's uid
      String? docId = widget.storeId;
      if (docId.isEmpty || docId == 'all') {
        final user = FirebaseAuth.instance.currentUser;
        docId = user?.uid ?? '';
        print('🔍 DEBUG: Falling back to current user uid for store category: $docId');
      }

      if (docId.isEmpty) {
        print('🔍 DEBUG: No valid docId for store category fetch');
        return;
      }

      final storeDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .get();
      
      print('🔍 DEBUG: Store document exists: ${storeDoc.exists}');
      
      if (storeDoc.exists) {
        final storeData = storeDoc.data() as Map<String, dynamic>;
        final storeCategory = storeData['storeCategory'] as String?;
        
        print('🔍 DEBUG: Raw storeCategory from database: "$storeCategory"');
        print('🔍 DEBUG: storeCategory is null: ${storeCategory == null}');
        print('🔍 DEBUG: storeCategory is empty: ${storeCategory?.isEmpty}');
        
        if (storeCategory != null && storeCategory.isNotEmpty) {
          print('🔍 DEBUG: Setting selectedCategory to: $storeCategory');
          setState(() {
            selectedCategory = storeCategory;
            // Set appropriate subcategory based on category
            selectedSubcategory = _getDefaultSubcategory(storeCategory);
            _subcategoryController.text = selectedSubcategory;
            _categoryLocked = true;
          });
          print('🔍 DEBUG: Loaded store category: $storeCategory');
          print('🔍 DEBUG: Set selectedSubcategory to: $selectedSubcategory');
        } else {
          print('🔍 DEBUG: storeCategory is null or empty, keeping default: $selectedCategory');
        }
      } else {
        print('🔍 DEBUG: Store document does not exist');
      }
    } catch (e) {
      print('❌ Error loading store category: $e');
    }
  }

  String _getDefaultSubcategory(String category) {
    switch (category) {
      case 'Food':
        return 'Baked Goods';
      case 'Electronics':
        return 'Phones';
      case 'Clothes':
        return 'T-Shirts';
      case 'Clothing':
        return 'T-Shirts';
      default:
        return 'Other';
    }
  }

  void _initializeAnimations() {
    print('🔍 DEBUG: _initializeAnimations called');
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _subcategoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      print('🔍 DEBUG: Starting image picker...');
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        print('🔍 DEBUG: Image selected: ${image.path}');
        
        if (kIsWeb) {
          // For web, read bytes directly
          final bytes = await image.readAsBytes();
          setState(() {
            selectedImageBytes = bytes;
            selectedImage = null;
          });
          print('🔍 DEBUG: Web - selectedImageBytes set, length: ${bytes.length}');
        } else {
          // For mobile, use File
          setState(() {
            selectedImage = File(image.path);
            selectedImageBytes = null;
          });
          print('🔍 DEBUG: Mobile - selectedImage set to: ${selectedImage?.path}');
        }
        
        _animateImageSelection();
      } else {
        print('🔍 DEBUG: No image selected');
      }
    } catch (e) {
      print('🔍 DEBUG: Error picking image: $e');
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  void _animateImageSelection() {
    _scaleController.reset();
    _scaleController.forward();
  }

  Future<String> _uploadImageToImageKit(File file) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not logged in');
        
        print('🔍 DEBUG: Getting ImageKit auth parameters from server... (attempt ${retryCount + 1})');
        
        // Get authentication parameters from Firebase callable
        final callable = FirebaseFunctions.instance.httpsCallable('getImageKitUploadAuth');
        final result = await callable.call();
        final data = result.data;
        if (data is! Map) {
          throw Exception('Invalid ImageKit auth response');
        }
        final authParams = Map<String, dynamic>.from(data as Map);
        print('🔍 DEBUG: Got ImageKit auth params: ${authParams.toString()}');
        
        // Validate auth parameters
        if (authParams['token'] == null || authParams['signature'] == null || authParams['expire'] == null) {
          throw Exception('Invalid authentication parameters received');
        }
        
        final bytes = await file.readAsBytes();
        final fileName = 'products/${widget.storeId}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
        
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://upload.imagekit.io/api/v1/files/upload'),
        );
        
        request.fields.addAll({
          'publicKey': (authParams['publicKey'] ?? '').toString(),
          'token': authParams['token'],
          'signature': authParams['signature'],
          'expire': authParams['expire'].toString(),
          'fileName': fileName,
          'folder': 'products/${widget.storeId}',
          'useUniqueFileName': 'true',
          'tags': 'product,${widget.storeId}',
        });
        
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: path.basename(file.path),
          ),
        );

        print('🔍 DEBUG: Sending ImageKit upload request...');
        final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
        final uploadResponse = await http.Response.fromStream(streamedResponse);
        
        print('🔍 DEBUG: ImageKit upload response status: ${uploadResponse.statusCode}');
        print('🔍 DEBUG: ImageKit upload response body: ${uploadResponse.body}');
        
        if (uploadResponse.statusCode == 200) {
          final result = json.decode(uploadResponse.body);
          final imageUrl = result['url'];
          print('🔍 DEBUG: ImageKit upload successful: $imageUrl');
          return imageUrl;
        } else {
          final errorBody = uploadResponse.body;
          print('🔍 DEBUG: ImageKit upload failed: $errorBody');
          
          // Check for specific error types
          if (errorBody.contains('authentication') || errorBody.contains('token')) {
            throw Exception('Authentication failed - please try again');
          } else if (errorBody.contains('quota') || errorBody.contains('limit')) {
            throw Exception('Upload quota exceeded');
          } else {
            throw Exception('Upload failed: ${uploadResponse.statusCode} - $errorBody');
          }
        }
      } catch (e) {
        retryCount++;
        print('🔍 DEBUG: Error uploading image to ImageKit (attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          print('🔍 DEBUG: Max retries reached, throwing error');
          throw Exception('Failed to upload image after $maxRetries attempts: $e');
        }
        
        // Wait before retrying (exponential backoff)
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }
    
    throw Exception('Upload failed after all retry attempts');
  }

  Future<String> _uploadImageBytesToImageKit(Uint8List bytes) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not logged in');
        
        print('🔍 DEBUG: Getting ImageKit auth parameters from server... (attempt ${retryCount + 1})');
        
        // Get authentication parameters from Firebase callable
        final callable = FirebaseFunctions.instance.httpsCallable('getImageKitUploadAuth');
        final result = await callable.call();
        final data = result.data;
        if (data is! Map) {
          throw Exception('Invalid ImageKit auth response');
        }
        final authParams = Map<String, dynamic>.from(data as Map);
        print('🔍 DEBUG: Got ImageKit auth params: ${authParams.toString()}');
        
        // Validate auth parameters
        if (authParams['token'] == null || authParams['signature'] == null || authParams['expire'] == null) {
          throw Exception('Invalid authentication parameters received');
        }
        
        final fileName = 'products/${widget.storeId}/${DateTime.now().millisecondsSinceEpoch}_web_image.jpg';
        
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://upload.imagekit.io/api/v1/files/upload'),
        );
        
        request.fields.addAll({
          'publicKey': (authParams['publicKey'] ?? '').toString(),
          'token': authParams['token'],
          'signature': authParams['signature'],
          'expire': authParams['expire'].toString(),
          'fileName': fileName,
          'folder': 'products/${widget.storeId}',
          'useUniqueFileName': 'true',
          'tags': 'product,${widget.storeId}',
        });
        
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'web_image.jpg',
          ),
        );

        print('🔍 DEBUG: Sending ImageKit upload request for web bytes...');
        final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
        final uploadResponse = await http.Response.fromStream(streamedResponse);
        
        print('🔍 DEBUG: ImageKit upload response status: ${uploadResponse.statusCode}');
        print('🔍 DEBUG: ImageKit upload response body: ${uploadResponse.body}');
        
        if (uploadResponse.statusCode == 200) {
          final result = json.decode(uploadResponse.body);
          final imageUrl = result['url'];
          print('🔍 DEBUG: ImageKit upload successful: $imageUrl');
          return imageUrl;
        } else {
          final errorBody = uploadResponse.body;
          print('🔍 DEBUG: ImageKit upload failed: $errorBody');
          
          // Check for specific error types
          if (errorBody.contains('authentication') || errorBody.contains('token')) {
            throw Exception('Authentication failed - please try again');
          } else if (errorBody.contains('quota') || errorBody.contains('limit')) {
            throw Exception('Upload quota exceeded');
          } else {
            throw Exception('Upload failed: ${uploadResponse.statusCode} - $errorBody');
          }
        }
      } catch (e) {
        retryCount++;
        print('🔍 DEBUG: Error uploading image bytes to ImageKit (attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          print('🔍 DEBUG: Max retries reached, throwing error');
          throw Exception('Failed to upload image after $maxRetries attempts: $e');
        }
        
        // Wait before retrying (exponential backoff)
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }
    
    throw Exception('Upload failed after all retry attempts');
  }

  Future<void> _uploadProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedImage == null && selectedImageBytes == null) {
      _showErrorSnackBar('Please select an image for your product');
      return;
    }

    setState(() {
      isUploading = true;
      uploadStatus = 'Preparing upload...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Upload image
      setState(() => uploadStatus = 'Uploading image...');
      final imageUrl = selectedImage != null 
          ? await _uploadImageToImageKit(selectedImage!)
          : await _uploadImageBytesToImageKit(selectedImageBytes!);

      // Create product data
      setState(() => uploadStatus = 'Creating product...');
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
        'category': selectedCategory,
        'subcategory': CategoryNormalizer.normalizeSubcategory(selectedSubcategory),
        'condition': selectedCondition,
        'imageUrl': imageUrl,
        'storeId': widget.storeId,
        'ownerId': user.uid,
        'status': 'active',
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      setState(() => uploadStatus = 'Saving to database...');
      await FirebaseFirestore.instance
          .collection(AppConstants.productsCollection)
          .add(productData);

      // Save custom subcategory into suggestions list for this category
      if (_subcategoryController.text.trim().isNotEmpty) {
        await SubcategorySuggestionsService.addSuggestion(selectedCategory, _subcategoryController.text.trim());
      }

      setState(() {
        isUploading = false;
        uploadStatus = 'Product uploaded successfully!';
      });

      _showSuccessSnackBar('Product uploaded successfully!');
      _resetForm();
      
      // Navigate back after delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });

    } catch (e) {
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
    _subcategoryController.clear();
    setState(() {
      selectedImage = null;
      selectedCategory = 'Food';
      selectedSubcategory = 'Baked Goods';
      selectedCondition = 'New';
      currentStep = 0;
    });
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _nextStep() {
    // Validate current step before proceeding
    if (!_validateCurrentStep()) {
      return;
    }
    
    if (currentStep < 3) {
      setState(() {
        currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    switch (currentStep) {
      case 0: // Image step
        if (selectedImage == null && selectedImageBytes == null) {
          _showErrorSnackBar('Please select a product image');
          return false;
        }
        break;
      case 1: // Details step
        if (!_validateDetailsStep()) {
          return false;
        }
        break;
      case 2: // Category step
        if (!_validateCategoryStep()) {
          return false;
        }
        break;
    }
    return true;
  }

  bool _validateDetailsStep() {
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a product name');
      return false;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a product description');
      return false;
    }
    if (_descriptionController.text.trim().length < 10) {
      _showErrorSnackBar('Description must be at least 10 characters');
      return false;
    }
    if (_priceController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a price');
      return false;
    }
    if (double.tryParse(_priceController.text) == null) {
      _showErrorSnackBar('Please enter a valid price');
      return false;
    }
    if (double.parse(_priceController.text) <= 0) {
      _showErrorSnackBar('Price must be greater than 0');
      return false;
    }
    if (_quantityController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter quantity');
      return false;
    }
    if (int.tryParse(_quantityController.text) == null) {
      _showErrorSnackBar('Please enter a valid quantity');
      return false;
    }
    if (int.parse(_quantityController.text) < 0) {
      _showErrorSnackBar('Quantity cannot be negative');
      return false;
    }
    if (selectedCondition.isEmpty) {
      _showErrorSnackBar('Please select product condition');
      return false;
    }
    return true;
  }

  bool _validateCategoryStep() {
    if (selectedCategory.isEmpty) {
      _showErrorSnackBar('Please select a category');
      return false;
    }
    if (_subcategoryController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a subcategory');
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    print('🔍 DEBUG: StunningProductUpload build called');
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    print('🔍 DEBUG: screenWidth = $screenWidth, isMobile = $isMobile');
    
    print('🔍 DEBUG: Building Scaffold');
    return Scaffold(
      backgroundColor: AppTheme.angel,
      appBar: AppBar(
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: Colors.white,
        title: Text(
          'Add New Product',
          style: TextStyle(
            fontSize: isMobile ? 18 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppTheme.primaryGradient,
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: _buildUploadForm(isMobile),
        ),
      ),
    );
  }



    Widget _buildUploadForm(bool isMobile) {
    print('🔍 DEBUG: _buildUploadForm called with isMobile = $isMobile');
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Progress Indicator
            _buildProgressIndicator(isMobile),
            
            SizedBox(height: isMobile ? 16 : 24),
            
            // Form Steps
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildImageStep(isMobile),
                  _buildDetailsStep(isMobile),
                  _buildCategoryStep(isMobile),
                  _buildReviewStep(isMobile),
                ],
              ),
            ),
            
            SizedBox(height: isMobile ? 16 : 24),
            
            // Navigation Buttons
            _buildNavigationButtons(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(bool isMobile) {
    final steps = ['Image', 'Details', 'Category', 'Review'];
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isActive = index <= currentStep;
          final isCurrent = index == currentStep;
          
          return Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.deepTeal : AppTheme.cloud,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCurrent
                        ? Icon(Icons.edit, color: Colors.white, size: 14)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    step,
                    style: TextStyle(
                      color: isActive ? AppTheme.deepTeal : AppTheme.cloud,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      fontSize: isMobile ? 11 : 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (index < steps.length - 1) ...[
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isActive ? AppTheme.deepTeal : AppTheme.cloud,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildImageStep(bool isMobile) {
    print('🔍 DEBUG: _buildImageStep called, selectedImage: ${selectedImage?.path}, selectedImageBytes: ${selectedImageBytes?.length} bytes');
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepTeal.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_camera_outlined,
              size: isMobile ? 40 : 56,
              color: AppTheme.deepTeal,
            ),
            
            SizedBox(height: isMobile ? 16 : 20),
            
            Text(
              'Product Photo',
              style: AppTheme.headlineMedium.copyWith(
                color: AppTheme.deepTeal,
                fontSize: isMobile ? 20 : 24,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: isMobile ? 6 : 8),
            
            Text(
              'Choose a beautiful photo that showcases your product',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.cloud,
                fontSize: isMobile ? 14 : 16,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            SizedBox(height: isMobile ? 24 : 32),
            
            Flexible(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: isMobile ? 180 : 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.whisper,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (selectedImage == null && selectedImageBytes == null) 
                          ? AppTheme.error 
                          : AppTheme.cloud,
                      width: 2,
                    ),
                  ),
                  child: (selectedImage != null || selectedImageBytes != null)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: selectedImage != null
                              ? _buildWebCompatibleImage(
                                  selectedImage!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                )
                              : Image.memory(
                                  selectedImageBytes!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    print('🔍 DEBUG: Error loading image bytes: $error');
                                    return Container(
                                      color: AppTheme.cloud,
                                      child: Icon(
                                        Icons.error,
                                        color: AppTheme.deepTeal,
                                        size: 48,
                                      ),
                                    );
                                  },
                                ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: isMobile ? 40 : 48,
                              color: AppTheme.cloud,
                            ),
                            SizedBox(height: isMobile ? 8 : 12),
                            Text(
                              'Tap to select image',
                              style: AppTheme.titleMedium.copyWith(
                                color: AppTheme.cloud,
                                fontSize: isMobile ? 14 : 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (currentStep > 0) ...[
                              SizedBox(height: isMobile ? 4 : 6),
                              Text(
                                'Image is required',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.error,
                                  fontSize: isMobile ? 11 : 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsStep(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product Details',
              style: AppTheme.headlineMedium.copyWith(
                color: AppTheme.deepTeal,
              ),
            ),
            
            const SizedBox(height: 20),
            
            _buildStyledTextField(
              controller: _nameController,
              label: 'Product Name',
              hint: 'Enter a catchy product name',
              icon: Icons.inventory,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a product name';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            _buildStyledTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Describe your amazing product',
              icon: Icons.description,
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a product description';
                }
                if (value.trim().length < 10) {
                  return 'Description must be at least 10 characters';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            _buildStyledDropdown(
              value: selectedCondition,
              label: 'Product Condition',
              icon: Icons.verified,
              items: _conditionOptions,
              onChanged: (value) {
                setState(() => selectedCondition = value!);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select product condition';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildStyledTextField(
                    controller: _priceController,
                    label: 'Price (R)',
                    hint: '0.00',
                    icon: Icons.receipt,
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
                  child: _buildStyledTextField(
                    controller: _quantityController,
                    label: 'Quantity',
                    hint: '1',
                    icon: Icons.inventory_2,
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
        ),
      ),
    );
  }

  Widget _buildCategoryStep(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category & Type',
              style: AppTheme.headlineMedium.copyWith(
                color: AppTheme.deepTeal,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Category Dropdown
            if (_categoryLocked) ...[
              Text('Category', style: AppTheme.bodyMedium.copyWith(color: AppTheme.cloud, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.whisper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cloud),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.category, color: AppTheme.deepTeal, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedCategory,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.deepTeal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.lock, color: AppTheme.cloud, size: 16),
                  ],
                ),
              ),
            ] else ...[
              _buildStyledDropdown(
                value: selectedCategory,
                label: 'Category',
                icon: Icons.category,
                items: AppConstants.categories,
                onChanged: (value) async {
                  if (value != null) {
                    setState(() {
                      selectedCategory = value;
                      selectedSubcategory = AppConstants.categoryMap[value]?.first ?? 'Other';
                      _subcategoryController.text = selectedSubcategory;
                    });
                    await _loadSavedSubcategories();
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Subcategory with manual entry option
            _buildStyledTextField(
              controller: _subcategoryController,
              label: 'Subcategory',
              hint: 'Enter subcategory or select from list',
              icon: Icons.subdirectory_arrow_right,
              onChanged: (value) {
                setState(() => selectedSubcategory = value);
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a subcategory';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Suggested subcategories based on category + saved suggestions
            if (AppConstants.categoryMap[selectedCategory] != null || _savedSuggestions.isNotEmpty) ...[
              Text(
                'Suggested subcategories:',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.cloud,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ([
                  ...?AppConstants.categoryMap[selectedCategory],
                  ..._savedSuggestions
                ]).toSet().toList()
                    .map((subcategory) => GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedSubcategory = subcategory;
                              _subcategoryController.text = subcategory;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selectedSubcategory == subcategory
                                  ? AppTheme.deepTeal
                                  : AppTheme.whisper,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selectedSubcategory == subcategory
                                    ? AppTheme.deepTeal
                                    : AppTheme.cloud,
                              ),
                            ),
                            child: Text(
                              subcategory,
                              style: TextStyle(
                                color: selectedSubcategory == subcategory
                                    ? Colors.white
                                    : AppTheme.deepTeal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],

            const SizedBox(height: 16),

            // Condition Selector
            Text(
              'Condition',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.cloud,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _conditionOptions.map((opt) {
                final selected = selectedCondition == opt;
                return ChoiceChip(
                  label: Text(opt),
                  selected: selected,
                  onSelected: (_) => setState(() => selectedCondition = opt),
                  selectedColor: AppTheme.deepTeal,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppTheme.deepTeal,
                  ),
                  backgroundColor: AppTheme.whisper,
                  side: BorderSide(color: AppTheme.cloud),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Subtle helper
            Text(
              'Tip: Choose the closest match so buyers can find your item easily.',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.cloud),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStep(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text(
              'Review & Upload',
              style: AppTheme.headlineMedium.copyWith(
                color: AppTheme.deepTeal,
              ),
            ),
            
            const SizedBox(height: 20),
            
                       if (selectedImage != null || selectedImageBytes != null) ...[
               ClipRRect(
                 borderRadius: BorderRadius.circular(12),
                 child: selectedImage != null
                     ? _buildWebCompatibleImage(
                         selectedImage!,
                         height: 120,
                         width: 120,
                         fit: BoxFit.cover,
                       )
                     : Image.memory(
                         selectedImageBytes!,
                         height: 120,
                         width: 120,
                         fit: BoxFit.cover,
                       ),
               ),
               
               const SizedBox(height: 16),
             ],
            
            _buildReviewItem('Name', _nameController.text),
            _buildReviewItem('Description', _descriptionController.text),
            _buildReviewItem('Price', 'R${_priceController.text}'),
            _buildReviewItem('Quantity', _quantityController.text),
            _buildReviewItem('Condition', selectedCondition),
            _buildReviewItem('Category', selectedCategory),
            _buildReviewItem('Subcategory', selectedSubcategory ?? ''),
            
            if (isUploading) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(
                backgroundColor: AppTheme.whisper,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
              ),
              const SizedBox(height: 8),
              Text(
                uploadStatus,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.cloud),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
              color: AppTheme.darkGrey,
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Not set',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.deepTeal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.darkGrey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.breeze),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.breeze),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
        ),
        filled: true,
        fillColor: AppTheme.whisper.withOpacity(0.3),
      ),
    );
  }

  Widget _buildStyledDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.darkGrey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.breeze),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.breeze),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
        ),
        filled: true,
        fillColor: AppTheme.whisper.withOpacity(0.3),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildNavigationButtons(bool isMobile) {
    return Container(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: isUploading ? null : _previousStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.deepTeal,
                  side: BorderSide(color: AppTheme.deepTeal),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Previous'),
              ),
            ),
          
          if (currentStep > 0) const SizedBox(width: 16),
          
          Expanded(
            flex: currentStep > 0 ? 1 : 2,
            child: ElevatedButton(
              onPressed: isUploading 
                  ? null 
                  : currentStep < 3 
                      ? _nextStep 
                      : _uploadProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.deepTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                currentStep < 3 ? 'Next' : 'Upload Product',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 