// import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
// import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:http/http.dart' as http;
// import 'package:path/path.dart' as path;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
// import 'product_upload_screen.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/imagekit_service.dart';
// import '../widgets/home_navigation_button.dart';
// import 'seller_onboarding_screen.dart';
import 'package:flutter/services.dart';

class SellerRegistrationScreen extends StatefulWidget {
  const SellerRegistrationScreen({super.key});

  @override
  State<SellerRegistrationScreen> createState() => _SellerRegistrationScreenState();
}

class _SellerRegistrationScreenState extends State<SellerRegistrationScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _locationController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  String? _formattedAddress;
  String? _selectedStoreCategory;
  final _deliveryFeeController = TextEditingController();
  final _minOrderController = TextEditingController();
  // Payout details controllers
  final TextEditingController _accountHolderController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _branchCodeController = TextEditingController();
  String _accountType = 'cheque';
  final TextEditingController _storyController = TextEditingController();
  final TextEditingController _specialtiesController = TextEditingController();
  final TextEditingController _passionController = TextEditingController();
  final TextEditingController _customRangeController = TextEditingController();
  List<String> _selectedPaymentMethods = [];
  // final List<String> _paymentMethodOptions = ['cash', 'card', 'snapscan', 'eft'];
  
  // Store category options
  final List<String> _storeCategoryOptions = [
    'Food',
    'Electronics', 
    'Clothes',
    'Other'
  ];

  bool _isLoading = false;
  bool _isStoreOpen = true;
  bool _isDeliveryAvailable = false;
  bool _allowCOD = false;
  bool _termsAccepted = false;
  bool _deliverEverywhere = false;
  double _visibilityRadius = 5.0;
  
  // New delivery range variables
  double _deliveryRange = 20.0; // Default 20km range (SA market standard)
  
  // Hybrid delivery mode variables
  String _deliveryMode = 'hybrid'; // 'platform', 'seller', 'hybrid', 'pickup'
  bool _sellerDeliveryEnabled = false;
  bool _platformDeliveryEnabled = true;
  double _sellerDeliveryBaseFee = 25.0; // SA standard base rate
  double _sellerDeliveryFeePerKm = 6.5; // SA standard per km rate
  double _sellerDeliveryMaxFee = 50.0; // Maximum delivery fee
  String _sellerDeliveryTime = '30-45 minutes';
  
  // Delivery hours variables
  TimeOfDay _deliveryStartTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _deliveryEndTime = const TimeOfDay(hour: 18, minute: 0);

  // Operating hours variables
  TimeOfDay _storeOpenTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _storeCloseTime = const TimeOfDay(hour: 18, minute: 0);

  // PAXI Service variables
  bool _paxiEnabled = false;
  
  // Pargo Service variables
  bool _pargoEnabled = false;
  // Global visibility for pickup services
  bool _pargoVisible = true;
  bool _paxiVisible = true;

  dynamic _storeImage; // Can be File or XFile
  // String? _storeImageUrl;
  List<dynamic> _extraPhotos = []; // Can contain File or XFile

  Widget _buildWebCompatibleImage(dynamic imageFile, {BoxFit? fit, double? width, double? height, Widget Function(BuildContext, Object, StackTrace?)? errorBuilder}) {
    if (imageFile == null) {
      return Container(
        color: Colors.grey[200],
        child: const Icon(Icons.error, size: 32, color: Colors.red),
      );
    }

    if (kIsWeb) {
      // On web, use Image.memory with file bytes
      if (imageFile is XFile) {
        return FutureBuilder<Uint8List>(
          future: imageFile.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.memory(
                snapshot.data!,
                fit: fit ?? BoxFit.cover,
                width: width,
                height: height,
                errorBuilder: errorBuilder,
              );
            } else if (snapshot.hasError) {
              return errorBuilder?.call(context, snapshot.error!, StackTrace.current) ??
                  Container(
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
        // Fallback for unknown types on web
        return Container(
          color: Colors.grey[200],
          child: const Icon(Icons.error, size: 32, color: Colors.red),
        );
      }
    } else {
      // On mobile, use Image.file
      File file;
      if (imageFile is XFile) {
        file = File(imageFile.path);
      } else if (imageFile is File) {
        file = imageFile;
      } else {
        return Container(
          color: Colors.grey[200],
          child: const Icon(Icons.error, size: 32, color: Colors.red),
        );
      }

      return Image.file(
        file,
        fit: fit ?? BoxFit.cover,
        width: width,
        height: height,
        errorBuilder: errorBuilder,
      );
    }
  }
  // List<String> _extraPhotoUrls = [];
  dynamic _introVideo; // Can be File or XFile
  // String? _introVideoUrl;

  final picker = ImagePicker();
  final videoPicker = ImagePicker();

  // To store current latitude and longitude
  double? _latitude;
  double? _longitude;

  // double? _platformFeePercent; // used when fetching fee config

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // _fetchPlatformFee();
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();

    // Load global pickup visibility
    _loadPickupVisibility();
  }

  Future<void> _loadPickupVisibility() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('platform').get();
      final cfg = doc.data();
      if (cfg != null) {
        setState(() {
          _pargoVisible = (cfg['pargoVisible'] != false);
          _paxiVisible = (cfg['paxiVisible'] != false);
        });
      }
    } catch (_) {}
  }

  // Show approval notice dialog
  Future<void> _showApprovalNoticeDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: AppTheme.primaryGreen,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Registration Complete!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your seller registration has been submitted successfully!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppTheme.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Important Notice',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your store will be visible to customers after admin approval. This process typically takes 24-48 hours.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'What happens next:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              _buildNextStepItem('1', 'Admin reviews your store information'),
              _buildNextStepItem('2', 'You\'ll receive an email notification'),
              _buildNextStepItem('3', 'Your store becomes visible to customers'),
              _buildNextStepItem('4', 'You can start adding products'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Got it!',
                style: TextStyle(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNextStepItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _storeNameController.dispose();
    _contactController.dispose();
    _locationController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _deliveryFeeController.dispose();
    _minOrderController.dispose();
    _storyController.dispose();
    _specialtiesController.dispose();
    _passionController.dispose();
    _customRangeController.dispose();
    _accountHolderController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _branchCodeController.dispose();

    super.dispose();
  }

// Future<void> _fetchPlatformFee() async {
//   final configDoc = await FirebaseFirestore.instance.collection('config').doc('platform').get();
//   final configData = configDoc.data();
//   if (configData != null && configData['platformFee'] != null) {
//     setState(() {
//       _platformFeePercent = (configData['platformFee'] as num).toDouble();
//     });
//   }
// }

  Future<void> _pickStoreImage() async {
    try {
      print('🔍 DEBUG: Starting store image picker...');
      
      // Show source selection dialog
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Select Image Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                if (!kIsWeb) // Only show camera option on mobile apps
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Camera'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
              ],
            ),
          );
        },
      );
      
      if (source == null) {
        print('🔍 DEBUG: No image source selected');
        return;
      }
      
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        print('🔍 DEBUG: Store image selected: ${pickedFile.path}');
        
        // Handle mobile web vs mobile app
        if (kIsWeb) {
          // For mobile web, we need to handle the file differently
          print('🔍 DEBUG: Mobile web detected, handling file upload');
          // Store the XFile directly for web
          setState(() {
            _storeImage = pickedFile;
          });
        } else {
          // For mobile apps, convert to File
          setState(() {
            _storeImage = File(pickedFile.path);
          });
        }
        print('🔍 DEBUG: Store image set successfully');
      } else {
        print('🔍 DEBUG: No store image selected');
      }
    } catch (e) {
      print('🔍 DEBUG: Error picking store image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _removeStoreImage() {
    setState(() {
      _storeImage = null;
    });
  }

  void _handleStoreImagePick() {
    _pickStoreImage();
  }

// void _handleExtraPhotoPick() { _pickExtraPhoto(); }

  Future<void> _pickExtraPhoto() async {
    if (_extraPhotos.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 2 extra photos allowed')),
      );
      return;
    }
    
    try {
      print('🔍 DEBUG: Starting extra photo picker...');
      
      // Show source selection dialog
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Select Image Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                if (!kIsWeb) // Only show camera option on mobile apps
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Camera'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
              ],
            ),
          );
        },
      );
      
      if (source == null) {
        print('🔍 DEBUG: No image source selected');
        return;
      }
      
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        print('🔍 DEBUG: Extra photo selected: ${pickedFile.path}');
        
        // Handle mobile web vs mobile app
        if (kIsWeb) {
          print('🔍 DEBUG: Mobile web detected, handling extra photo upload');
          // Store the XFile directly for web
          setState(() {
            _extraPhotos.add(pickedFile);
          });
        } else {
          // For mobile apps, convert to File
          setState(() {
            _extraPhotos.add(File(pickedFile.path));
          });
        }
        print('🔍 DEBUG: Extra photo added successfully. Total: ${_extraPhotos.length}');
      } else {
        print('🔍 DEBUG: No extra photo selected');
      }
    } catch (e) {
      print('🔍 DEBUG: Error picking extra photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking photo: $e')),
      );
    }
  }

  void _removeExtraPhoto(int index) {
    setState(() {
      _extraPhotos.removeAt(index);
    });
  }

  Future<void> _pickIntroVideo() async {
    try {
      print('🔍 DEBUG: Starting intro video picker...');
      final pickedFile = await videoPicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5), // Limit to 5 minutes
      );
      
      if (pickedFile != null) {
        print('🔍 DEBUG: Intro video selected: ${pickedFile.path}');
        
        // Handle mobile web vs mobile app
        if (kIsWeb) {
          // Store the XFile directly for web
          setState(() {
            _introVideo = pickedFile;
          });
        } else {
          // For mobile apps, convert to File
          setState(() {
            _introVideo = File(pickedFile.path);
          });
        }
        print('🔍 DEBUG: Intro video set successfully');
      } else {
        print('🔍 DEBUG: No intro video selected');
      }
    } catch (e) {
      print('🔍 DEBUG: Error picking intro video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking video: $e')),
      );
    }
  }

  void _removeIntroVideo() {
    setState(() {
      _introVideo = null;
    });
  }

  Future<void> _selectDeliveryStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _deliveryStartTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.deepTeal,
              onPrimary: AppTheme.angel,
              surface: AppTheme.angel,
              onSurface: AppTheme.deepTeal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _deliveryStartTime) {
      setState(() {
        _deliveryStartTime = picked;
      });
    }
  }

  Future<void> _selectDeliveryEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _deliveryEndTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.deepTeal,
              onPrimary: AppTheme.angel,
              surface: AppTheme.angel,
              onSurface: AppTheme.deepTeal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _deliveryEndTime) {
      setState(() {
        _deliveryEndTime = picked;
      });
    }
  }

  Future<void> _selectStoreOpenTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _storeOpenTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.deepTeal,
              onPrimary: AppTheme.angel,
              surface: AppTheme.angel,
              onSurface: AppTheme.deepTeal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _storeOpenTime) {
      setState(() {
        _storeOpenTime = picked;
      });
    }
  }

  Future<void> _selectStoreCloseTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _storeCloseTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.deepTeal,
              onPrimary: AppTheme.angel,
              surface: AppTheme.angel,
              onSurface: AppTheme.deepTeal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _storeCloseTime) {
      setState(() {
        _storeCloseTime = picked;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Helper function to format TimeOfDay to AM/PM for display
  String _formatTimeOfDayAmPm(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<String?> _uploadImageToImageKit(dynamic file) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      
      print('🔍 DEBUG: Uploading image using ImageKitService...');
      
      // Use the centralized ImageKitService
      final imageUrl = await ImageKitService.uploadStoreImage(
        file: file,
        userId: user.uid,
      );
      
      if (imageUrl != null) {
        print('🔍 DEBUG: Image upload successful: $imageUrl');
        return imageUrl;
      } else {
        print('🔍 DEBUG: Image upload failed');
        return null;
      }
    } catch (e) {
      print('❌ ImageKit upload error: $e');
      return null;
    }
  }

  Future<String?> _uploadVideoToImageKit(dynamic file) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      
      print('🔍 DEBUG: Uploading video using ImageKitService...');
      
      // Use the centralized ImageKitService
      final videoUrl = await ImageKitService.uploadStoreVideo(
        file: file,
        userId: user.uid,
      );
      
      if (videoUrl != null) {
        print('🔍 DEBUG: Video upload successful: $videoUrl');
        return videoUrl;
      } else {
        print('🔍 DEBUG: Video upload failed');
        return null;
      }
    } catch (e) {
      print('❌ ImageKit video upload error: $e');
      return null;
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission = await Geolocator.checkPermission();

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are denied forever')),
      );
      return;
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final placemark = placemarks.first;
      final line1 = [placemark.street, placemark.subLocality].where((e) => e != null && e!.isNotEmpty).join(', ');
      final line2 = [placemark.locality, placemark.administrativeArea].where((e) => e != null && e!.isNotEmpty).join(', ');
      final postal = placemark.postalCode ?? '';
      final country = placemark.country ?? '';
      final formatted = [line1, line2, postal, country].where((e) => e != null && e!.toString().trim().isNotEmpty).join(', ');
      setState(() {
        _addressLine1Controller.text = line1;
        _addressLine2Controller.text = line2;
        _cityController.text = placemark.locality ?? '';
        _postalCodeController.text = postal;
        _formattedAddress = formatted;
        _locationController.text = formatted.isNotEmpty ? formatted : (_locationController.text.isNotEmpty ? _locationController.text : '${placemark.locality}, ${placemark.country}');
      });
    } catch (e) {
      print('Error getting address: $e');
    }
  }

  Future<void> _registerSeller() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Additional validation for store category
    if (_selectedStoreCategory == null || _selectedStoreCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a store category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Service selection validation: at least one service must be enabled
    final bool anyServiceEnabled = _isDeliveryAvailable || _paxiEnabled || _pargoEnabled;
    if (!anyServiceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose at least one service: Delivery or PAXI/Pargo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Food category requires local delivery to be visible (nationwide pickup is non-food only)
    bool _isFoodCat(String? c) {
      final s = (c ?? '').toLowerCase();
      return s.contains('food') || s.contains('meal') || s.contains('bak') || s.contains('pastr') || s.contains('dessert') || s.contains('beverage') || s.contains('drink') || s.contains('coffee') || s.contains('tea') || s.contains('fruit') || s.contains('vegetable') || s.contains('produce') || s.contains('snack');
    }
    if (_isFoodCat(_selectedStoreCategory) && !_isDeliveryAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Food stores must enable local delivery to be visible.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // If delivery is enabled, coordinates are required for distance-based discovery
    if (_isDeliveryAvailable && (_latitude == null || _longitude == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location is required for delivery. Please enable location and set your store location.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Enforce category delivery caps (Food: 20km, Non-food: 50km)
    double _capForCategory(String? c) {
      return _isFoodCat(c) ? 20.0 : 50.0;
    }
    final double cap = _capForCategory(_selectedStoreCategory);
    if (_deliveryRange > cap) {
      setState(() {
        _deliveryRange = cap;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delivery range capped to ${cap.toStringAsFixed(0)} km for your category.'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    // Additional validation for PAXI service
    if (_paxiEnabled && (_latitude == null || _longitude == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PAXI service requires store location coordinates. Please enable location services and try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Additional validation for Pargo service
    if (_pargoEnabled && (_latitude == null || _longitude == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pargo service requires store location coordinates. Please enable location services and try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      String? storeImageUrl;
      if (_storeImage != null) {
        print('🔍 DEBUG: Uploading store image...');
        storeImageUrl = await _uploadImageToImageKit(_storeImage!);
        if (storeImageUrl != null) {
          print('🔍 DEBUG: Store image uploaded successfully: $storeImageUrl');
        } else {
          print('🔍 DEBUG: Store image upload failed');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload store image. Please try again.')),
          );
          return;
        }
      }
      
      List<String> extraPhotoUrls = [];
      for (int i = 0; i < _extraPhotos.length; i++) {
        print('🔍 DEBUG: Uploading extra photo ${i + 1}/${_extraPhotos.length}...');
        String? photoUrl = await _uploadImageToImageKit(_extraPhotos[i]);
        if (photoUrl != null) {
          extraPhotoUrls.add(photoUrl);
          print('🔍 DEBUG: Extra photo ${i + 1} uploaded successfully: $photoUrl');
        } else {
          print('🔍 DEBUG: Extra photo ${i + 1} upload failed');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload extra photo ${i + 1}. Please try again.')),
          );
          return;
        }
      }

      String? introVideoUrl;
      if (_introVideo != null) {
        print('🔍 DEBUG: Uploading intro video...');
        introVideoUrl = await _uploadVideoToImageKit(_introVideo!);
        if (introVideoUrl != null) {
          print('🔍 DEBUG: Intro video uploaded successfully: $introVideoUrl');
        } else {
          print('🔍 DEBUG: Intro video upload failed');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload intro video. Please try again.')),
          );
          return;
        }
      }

      // Save to users collection (as per the existing data structure)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'email': user.email, // Add the logged-in user's email
        'storeName': _storeNameController.text.trim(),
        'storeCategory': _selectedStoreCategory,
        'contact': _contactController.text.trim(),
        'location': _locationController.text.trim(),
        'isStoreOpen': _isStoreOpen,
        'deliveryAvailable': _isDeliveryAvailable,
        'deliveryFeePerKm': _deliveryFeeController.text.isNotEmpty ? double.parse(_deliveryFeeController.text) : 0.0,
        'minOrderForDelivery': _minOrderController.text.isNotEmpty ? double.parse(_minOrderController.text) : 0.0,
        // Hybrid delivery settings
        'deliveryMode': _deliveryMode,
        'sellerDeliveryEnabled': _sellerDeliveryEnabled,
        'platformDeliveryEnabled': _platformDeliveryEnabled,
        'sellerDeliveryBaseFee': _sellerDeliveryBaseFee,
        'sellerDeliveryFeePerKm': _sellerDeliveryFeePerKm,
        'sellerDeliveryMaxFee': _sellerDeliveryMaxFee,
        'sellerDeliveryTime': _sellerDeliveryTime,
        'deliveryStartHour': _formatTimeOfDay(_deliveryStartTime),
        'deliveryEndHour': _formatTimeOfDay(_deliveryEndTime),
        'storeOpenHour': _formatTimeOfDay(_storeOpenTime),
        'storeCloseHour': _formatTimeOfDay(_storeCloseTime),
        'deliverEverywhere': _deliverEverywhere,
        'visibilityRadius': _visibilityRadius,
        'deliveryRange': _deliveryRange,
        'useCustomRange': false, // No longer needed since we use slider
        'paymentMethods': _selectedPaymentMethods,
        'allowCOD': _allowCOD,
        'profileImageUrl': storeImageUrl ?? '',
        'extraPhotoUrls': extraPhotoUrls,
        'introVideoUrl': introVideoUrl ?? '',
        'story': _storyController.text.trim(),
        'specialties': _specialtiesController.text.split(',').map((e) => e.trim()).toList(),
        'passion': _passionController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'paxiEnabled': _paxiEnabled,
        'pargoEnabled': _pargoEnabled,
        'status': 'pending',
        'verified': false,
        'paused': false,
        'platformFeeExempt': false,
        'formattedAddress': _formattedAddress ?? _locationController.text.trim(),
        'addressLine1': _addressLine1Controller.text.trim(),
        'addressLine2': _addressLine2Controller.text.trim(),
        'city': _cityController.text.trim(),
        'postalCode': _postalCodeController.text.trim(),
      });

      // Save payout details to secure sub-document
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('payout')
            .doc('bank')
            .set({
          'accountHolder': _accountHolderController.text.trim(),
          'bankName': _bankNameController.text.trim(),
          'accountNumber': _accountNumberController.text.trim(),
          'branchCode': _branchCodeController.text.trim(),
          'accountType': _accountType,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        print('⚠️ Failed to save payout details: $e');
      }

      // Terms consent timestamp
      if (_termsAccepted) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({ 'termsAcceptedAt': FieldValue.serverTimestamp() }, SetOptions(merge: true));
        } catch (_) {}
      }

      // Call Cloud Function to update role (handles security rules properly)
      try {
        final callable = FirebaseFunctions.instance.httpsCallable('registerAsSeller');
        final result = await callable.call();
        print('✅ Seller role updated via Cloud Function: ${result.data}');
      } catch (e) {
        print('❌ Failed to update seller role via Cloud Function: $e');
        throw Exception('Failed to register as seller. Please try again.');
      }

      // TTS welcome (seller)
      try {
        await NotificationService().speakPreview("Congrats—your seller account is live. Let's get those orders rolling.");
      } catch (_) {}

      // Refresh user data in provider to reflect the role change
      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.loadUserData();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seller registration successful! Your store will be visible after admin approval.'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );
        
        // Show approval notice dialog
        if (mounted) {
          await _showApprovalNoticeDialog();
        }

        // Show store link and QR so seller can advertise immediately
        final storeId = user.uid;
        final base = const String.fromEnvironment('PUBLIC_BASE_URL', defaultValue: 'https://marketplace-8d6bd.web.app');
        final storeUrl = '$base/store/$storeId';
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Your Store Link'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(storeUrl),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: storeUrl));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy link'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to register as seller: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildHeader() {
    return Container(
      margin: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 1.5),
      decoration: BoxDecoration(
        gradient: AppTheme.cardBackgroundGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.complementaryElevation,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.deepTeal, AppTheme.cloud],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.store_outlined,
              size: ResponsiveUtils.getIconSize(context, baseSize: 32),
              color: AppTheme.angel,
            ),
          ),
          SizedBox(width: ResponsiveUtils.getHorizontalPadding(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeUI.safeText(
                  'Become a Seller',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context) + 4,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepTeal,
                  ),
                  maxLines: 1,
                ),
                SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.2),
                SafeUI.safeText(
                  'Join our marketplace and start selling your amazing products',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                    color: AppTheme.breeze,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getHorizontalPadding(context),
        vertical: ResponsiveUtils.getVerticalPadding(context) * 0.5,
      ),
      decoration: BoxDecoration(
        gradient: AppTheme.cardBackgroundGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.complementaryElevation,
        border: Border.all(
          color: AppTheme.breeze.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.whisper, AppTheme.angel],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.deepTeal.withOpacity(0.2), AppTheme.cloud.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.deepTeal,
                    size: ResponsiveUtils.getIconSize(context, baseSize: 20),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                SafeUI.safeText(
                  title,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.deepTeal,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          // Section Content
          Padding(
            padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? helperText,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeUI.safeText(
          label,
          style: TextStyle(
            fontSize: ResponsiveUtils.getTitleSize(context) - 2,
            fontWeight: FontWeight.w600,
            color: AppTheme.deepTeal,
          ),
          maxLines: 1,
        ),
        SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.3),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.cloud.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            maxLines: maxLines,
            enabled: !_isLoading,
            onChanged: onChanged,
            style: TextStyle(
              fontSize: ResponsiveUtils.getTitleSize(context) - 2,
              color: AppTheme.deepTeal,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AppTheme.breeze,
                fontSize: ResponsiveUtils.getTitleSize(context) - 2,
              ),
              prefixIcon: prefixIcon != null ? Icon(
                prefixIcon,
                color: AppTheme.breeze,
                size: ResponsiveUtils.getIconSize(context, baseSize: 20),
              ) : null,
              filled: true,
              fillColor: AppTheme.angel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.getHorizontalPadding(context),
                vertical: ResponsiveUtils.getVerticalPadding(context),
              ),
              helperText: helperText,
              helperStyle: TextStyle(
                color: AppTheme.cloud,
                fontSize: 12,
              ),
            ),
          ),
        ),
        SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
      ],
    );
  }

  Widget _buildImageUploadCard({
    required String title,
    required IconData icon,
    required dynamic imageFile,
    VoidCallback? onTap,
    required String subtitle,
    VoidCallback? onRemove,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.getVerticalPadding(context)),
      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
      decoration: BoxDecoration(
        gradient: AppTheme.cardBackgroundGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.complementaryElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.deepTeal, AppTheme.cloud],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: ResponsiveUtils.getIconSize(context, baseSize: 20),
                  color: AppTheme.angel,
                ),
              ),
              SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeUI.safeText(
                      title,
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getTitleSize(context),
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepTeal,
                      ),
                      maxLines: 1,
                    ),
                    SafeUI.safeText(
                      subtitle,
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                        color: AppTheme.breeze,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
          
          // Image Preview or Upload Button
          if (imageFile != null) ...[
            // Image Preview
            Container(
              width: double.infinity,
              height: ResponsiveUtils.isMobile(context) ? 150 : 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.deepTeal.withOpacity(0.2)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Image
                    Positioned.fill(
                      child: kIsWeb 
                        ? Image.network(
                            imageFile.path,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: AppTheme.cloud,
                                child: Icon(
                                  Icons.image,
                                  color: AppTheme.deepTeal,
                                  size: 48,
                                ),
                              );
                            },
                          )
                        : _buildWebCompatibleImage(
                            imageFile,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: AppTheme.cloud,
                                child: Icon(
                                  Icons.image,
                                  color: AppTheme.deepTeal,
                                  size: 48,
                                ),
                              );
                            },
                          ),
                    ),
                    // Remove button
                    if (onRemove != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: onRemove,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
            // Replace button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onTap,
                icon: Icon(Icons.edit, size: ResponsiveUtils.getIconSize(context, baseSize: 16)),
                label: Text('Replace Image'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.deepTeal,
                  side: BorderSide(color: AppTheme.deepTeal),
                  padding: EdgeInsets.symmetric(
                    vertical: ResponsiveUtils.getVerticalPadding(context) * 0.6,
                  ),
                ),
              ),
            ),
          ] else ...[
            // Upload Button
            GestureDetector(
              onTap: onTap ?? () {},
              child: Container(
                width: double.infinity,
                height: ResponsiveUtils.isMobile(context) ? 120 : 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.deepTeal.withOpacity(0.3),
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.deepTeal.withOpacity(0.05),
                      AppTheme.cloud.withOpacity(0.02),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: ResponsiveUtils.getIconSize(context, baseSize: 32),
                      color: AppTheme.deepTeal,
                    ),
                    SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.3),
                    Text(
                      'Tap to upload',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                        color: AppTheme.deepTeal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.2),
                    Text(
                      'JPG, PNG (Max 5MB)',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getTitleSize(context) - 6,
                        color: AppTheme.breeze,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoUploadCard({
    required String title,
    required IconData icon,
    dynamic videoFile,
    VoidCallback? onTap,
    String? subtitle,
    VoidCallback? onRemove,
  }) {
    return GestureDetector(
      onTap: (_isLoading || onTap == null) ? null : onTap,
      child: Container(
        height: 120,
        margin: EdgeInsets.only(bottom: ResponsiveUtils.getVerticalPadding(context)),
        decoration: BoxDecoration(
          gradient: videoFile != null 
            ? null 
            : LinearGradient(
                colors: [AppTheme.whisper, AppTheme.angel],
              ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.breeze.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.cloud.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: videoFile != null
          ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: AppTheme.deepTeal.withOpacity(0.1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.videocam,
                          size: 48,
                          color: AppTheme.deepTeal,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Video Selected',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.deepTeal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Tap to change',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.breeze,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Remove button
                if (onRemove != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: AppTheme.angel,
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: ResponsiveUtils.getIconSize(context, baseSize: 32),
                  color: AppTheme.breeze,
                ),
                SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.3),
                SafeUI.safeText(
                  title,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.deepTeal,
                  ),
                  maxLines: 1,
                ),
                if (subtitle != null) ...[
                  SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.1),
                  SafeUI.safeText(
                    subtitle,
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getTitleSize(context) - 6,
                      color: AppTheme.breeze,
                    ),
                    maxLines: 1,
                  ),
                ],
              ],
            ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? subtitle,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.getVerticalPadding(context)),
      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.whisper, AppTheme.angel],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.breeze.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeUI.safeText(
                  title,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.deepTeal,
                  ),
                  maxLines: 1,
                ),
                if (subtitle != null) ...[
                  SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.2),
                  SafeUI.safeText(
                    subtitle,
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getTitleSize(context) - 4,
                      color: AppTheme.breeze,
                    ),
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: _isLoading ? null : onChanged,
            activeColor: AppTheme.deepTeal,
            activeTrackColor: AppTheme.cloud,
            inactiveThumbColor: AppTheme.breeze,
            inactiveTrackColor: AppTheme.whisper,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      margin: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: _isLoading 
          ? LinearGradient(colors: [AppTheme.breeze, AppTheme.cloud])
          : AppTheme.primaryButtonGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isLoading ? [] : AppTheme.complementaryElevation,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLoading ? null : _registerSeller,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.getHorizontalPadding(context),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading) ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.angel),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                ] else ...[
                  Icon(
                    Icons.store_outlined,
                    color: AppTheme.angel,
                    size: ResponsiveUtils.getIconSize(context, baseSize: 22),
                  ),
                  SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                ],
                SafeUI.safeText(
                  _isLoading ? 'Registering...' : 'Register as Seller',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.angel,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _getCategoryDeliveryCap() {
    final cat = (_selectedStoreCategory ?? '').toLowerCase();
    if (cat.contains('food')) return 20.0;
    return 50.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.angel,
      appBar: AppBar(
        title: SafeUI.safeText(
          'Seller Registration',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.angel,
            fontSize: ResponsiveUtils.getTitleSize(context),
          ),
          maxLines: 1,
        ),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: AppTheme.angel,
        elevation: 0,
        centerTitle: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.screenBackgroundGradient,
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                  SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                  
                  // Header
                  _buildHeader(),
                  
                  // Store Information Section
                  _buildSectionCard(
                    title: 'Store Information',
                    icon: Icons.store,
                    children: [
                      _buildEnhancedTextField(
                      controller: _storeNameController,
                        label: 'Store Name',
                        hint: 'Enter your store name',
                        prefixIcon: Icons.storefront,
                      validator: (value) => value == null || value.isEmpty ? 'Enter store name' : null,
                    ),
                      // Store Category Dropdown
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: ResponsiveUtils.getVerticalPadding(context)),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.cloud.withOpacity(0.3), AppTheme.whisper],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.breeze.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.cloud.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedStoreCategory,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Store Category *',
                            hintText: 'Select your store category (Required)',
                            prefixIcon: Icon(
                              Icons.category,
                              color: AppTheme.breeze,
                              size: ResponsiveUtils.getIconSize(context, baseSize: 20),
                            ),
                            filled: true,
                            fillColor: AppTheme.angel,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.red, width: 2),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.red, width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.getHorizontalPadding(context) * 0.8,
                              vertical: ResponsiveUtils.getVerticalPadding(context),
                            ),
                            helperText: 'This field is required',
                            helperStyle: TextStyle(
                              color: AppTheme.cloud,
                              fontSize: 12,
                            ),
                          ),
                          items: _storeCategoryOptions.map((String category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Container(
                                width: double.infinity,
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                                    color: AppTheme.deepTeal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: _isLoading ? null : (String? newValue) {
                            setState(() {
                              _selectedStoreCategory = newValue;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Store category is required. Please select a category.';
                            }
                            return null;
                          },
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: AppTheme.deepTeal,
                          ),
                          dropdownColor: AppTheme.angel,
                        ),
                    ),
                      _buildEnhancedTextField(
                      controller: _contactController,
                        label: 'Contact Information',
                        hint: 'Phone number or email',
                        prefixIcon: Icons.contact_phone,
                        keyboardType: TextInputType.phone,
                        validator: (value) => value == null || value.isEmpty ? 'Enter contact info' : null,
                      ),
                      _buildEnhancedTextField(
                      controller: _locationController,
                        label: 'Store Location',
                        hint: 'Enter your address',
                        prefixIcon: Icons.location_on,
                        validator: (value) => value == null || value.isEmpty ? 'Enter store location' : null,
                      ),
                      // Detailed Address
                      _buildEnhancedTextField(
                        controller: _addressLine1Controller,
                        label: 'Address Line 1',
                        hint: 'Street and number',
                        prefixIcon: Icons.home,
                      ),
                      _buildEnhancedTextField(
                        controller: _addressLine2Controller,
                        label: 'Address Line 2 (optional)',
                        hint: 'Complex/Suburb',
                        prefixIcon: Icons.apartment,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildEnhancedTextField(
                              controller: _cityController,
                              label: 'City/Town',
                              hint: 'e.g., Kempton Park',
                              prefixIcon: Icons.location_city,
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                          Expanded(
                            child: _buildEnhancedTextField(
                              controller: _postalCodeController,
                              label: 'Postal Code',
                              hint: 'e.g., 1619',
                              prefixIcon: Icons.local_post_office,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: double.infinity,
                        height: 48,
                        margin: EdgeInsets.only(bottom: ResponsiveUtils.getVerticalPadding(context)),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.cloud.withOpacity(0.3), AppTheme.whisper],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.breeze.withOpacity(0.3)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _isLoading ? null : _getCurrentLocation,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                                Icon(
                                  Icons.my_location,
                                  color: AppTheme.deepTeal,
                                  size: ResponsiveUtils.getIconSize(context, baseSize: 20),
                                ),
                                SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                                SafeUI.safeText(
                                  'Use Current Location',
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.deepTeal,
                                  ),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Store Media Section
                  _buildSectionCard(
                    title: 'Store Media',
                    icon: Icons.photo_camera,
                    children: [
                      _buildImageUploadCard(
                        title: 'Store Image',
                        icon: Icons.store,
                        imageFile: _storeImage,
                        onTap: _handleStoreImagePick,
                        subtitle: 'Main store photo',
                        onRemove: _removeStoreImage,
                      ),
                    ],
                  ),
                  
                  // Store Settings Section
                  _buildSectionCard(
                    title: 'Store Settings',
                    icon: Icons.settings,
                    children: [
                      _buildSwitchTile(
                        title: 'Store Currently Open',
                        subtitle: 'Customers can see and order from your store',
                        value: _isStoreOpen,
                        onChanged: (value) => setState(() => _isStoreOpen = value),
                      ),
                      _buildSwitchTile(
                        title: 'Offer Delivery',
                        subtitle: 'Provide local doorstep delivery to customers',
                        value: _isDeliveryAvailable,
                        onChanged: (value) => setState(() => _isDeliveryAvailable = value),
                      ),
                      _buildSwitchTile(
                        title: 'Allow Cash on Delivery (COD)',
                        subtitle: 'Customers can pay cash on delivery/pickup (fees apply)',
                        value: _allowCOD,
                        onChanged: (value) => setState(() => _allowCOD = value),
                      ),
                      const SizedBox(height: 16),
                      // Pickup Services (decoupled from Offer Delivery)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.angel,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.breeze.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.store_mall_directory, color: AppTheme.deepTeal, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Pickup Services',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.deepTeal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pickup via PAXI/Pargo does not require Offer Delivery. Non‑food pickup stores are discoverable via the Nationwide filter.',
                              style: TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
                            ),
                            const SizedBox(height: 8),
                            if (_paxiVisible)
                              SwitchListTile(
                                title: const Text('Enable PAXI Pickup Service'),
                                subtitle: const Text('Let customers collect at PAXI points'),
                                value: _paxiEnabled,
                                onChanged: (v) => setState(() => _paxiEnabled = v),
                                activeColor: AppTheme.primaryGreen,
                              ),
                            if (_pargoVisible)
                              SwitchListTile(
                                title: const Text('Enable Pargo Pickup Service'),
                                subtitle: const Text('Let customers collect at Pargo points'),
                                value: _pargoEnabled,
                                onChanged: (v) => setState(() => _pargoEnabled = v),
                                activeColor: AppTheme.primaryGreen,
                              ),
                          ],
                        ),
                      ),
                      if (_isDeliveryAvailable) ...[
                        // Delivery Fee Information Note
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.success.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: AppTheme.success,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Delivery Fee Structure',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.success,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '💡 **Default Rates (SA Market Standard):**\n'
                                '• Base Fee: R25 (covers first 3-4km)\n'
                                '• Per KM Rate: R6.50/km (after first 3-4km)\n'
                                '• Maximum Range: 20km\n'
                                '• Minimum Order: R50\n\n'
                                '💡 **You can customize these rates below, or leave blank to use defaults.**\n'
                                '💡 **Reasonable ranges:** Base Fee: R15-R50, Per KM: R3-R15',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGrey,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildEnhancedTextField(
                          controller: _deliveryFeeController,
                          label: 'Delivery Fee (R)',
                          hint: 'Enter delivery fee per kilometer',
                          prefixIcon: Icons.delivery_dining,
                          keyboardType: TextInputType.number,
                          helperText: 'This is the amount you charge per kilometer (leave blank for default R6.50/km)',
                        ),
                        _buildEnhancedTextField(
                          controller: _minOrderController,
                          label: 'Minimum Order (R)',
                          hint: 'Minimum order amount',
                          prefixIcon: Icons.shopping_cart,
                          keyboardType: TextInputType.number,
                        ),
                        
                        // Hybrid Delivery Mode Section
                        Container(
                          margin: EdgeInsets.only(bottom: ResponsiveUtils.getVerticalPadding(context)),
                          padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
                          decoration: BoxDecoration(
                            color: AppTheme.angel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.breeze.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.delivery_dining,
                                    color: AppTheme.deepTeal,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Delivery Mode',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.deepTeal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Choose how you want to handle deliveries. You can use platform drivers, handle delivery yourself, or offer both options.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGrey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Delivery Mode Dropdown
                              DropdownButtonFormField<String>(
                                value: _deliveryMode,
                                decoration: InputDecoration(
                                  labelText: 'Delivery Mode',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: Icon(Icons.settings),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: ResponsiveUtils.getHorizontalPadding(context) * 0.5,
                                    vertical: ResponsiveUtils.getVerticalPadding(context) * 0.3,
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'platform',
                                    child: Tooltip(
                                      message: 'Use platform drivers for deliveries',
                                      child: Text(
                                        'Platform Only',
                                        style: TextStyle(fontSize: ResponsiveUtils.getTitleSize(context) - 4),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'seller',
                                    child: Tooltip(
                                      message: 'Handle delivery yourself',
                                      child: Text(
                                        'Seller Only',
                                        style: TextStyle(fontSize: ResponsiveUtils.getTitleSize(context) - 4),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'hybrid',
                                    child: Tooltip(
                                      message: 'Offer both platform and seller delivery',
                                      child: Text(
                                        'Hybrid',
                                        style: TextStyle(fontSize: ResponsiveUtils.getTitleSize(context) - 4),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'pickup',
                                    child: Tooltip(
                                      message: 'Customers collect from your location',
                                      child: Text(
                                        'Pickup Only',
                                        style: TextStyle(fontSize: ResponsiveUtils.getTitleSize(context) - 4),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                isExpanded: true, // Prevent overflow
                                onChanged: (value) {
                                  setState(() {
                                    _deliveryMode = value!;
                                    // Auto-configure based on mode
                                    switch (value) {
                                      case 'platform':
                                        _sellerDeliveryEnabled = false;
                                        _platformDeliveryEnabled = true;
                                        break;
                                      case 'seller':
                                        _sellerDeliveryEnabled = true;
                                        _platformDeliveryEnabled = false;
                                        break;
                                      case 'hybrid':
                                        _sellerDeliveryEnabled = true;
                                        _platformDeliveryEnabled = true;
                                        break;
                                      case 'pickup':
                                        _sellerDeliveryEnabled = false;
                                        _platformDeliveryEnabled = false;
                                        break;
                                    }
                                  });
                                },
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Delivery Options
                              if (_deliveryMode != 'pickup') ...[
                                Text(
                                  'Delivery Options',
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.getTitleSize(context) - 2,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.deepTeal,
                                  ),
                                ),
                                SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.3),
                                // Responsive delivery options
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxWidth > 500) {
                                      // Desktop/Tablet: Side by side
                                      return Row(
                                        children: [
                                          Expanded(
                                            child: CheckboxListTile(
                                              title: Text(
                                                'Enable Seller Delivery',
                                                style: TextStyle(fontSize: ResponsiveUtils.getTitleSize(context) - 3),
                                              ),
                                              subtitle: Text(
                                                'Handle deliveries yourself',
                                                style: TextStyle(fontSize: ResponsiveUtils.getTitleSize(context) - 4),
                                              ),
                                              value: _sellerDeliveryEnabled,
                                              onChanged: _deliveryMode == 'platform' ? null : (value) {
                                                setState(() => _sellerDeliveryEnabled = value!);
                                              },
                                            ),
                                          ),
                                          Expanded(
                                            child: CheckboxListTile(
                                              title: Text(
                                                'Enable Platform Delivery',
                                                style: TextStyle(fontSize: ResponsiveUtils.getTitleSize(context) - 3),
                                              ),
                                              subtitle: Text(
                                                'Use platform drivers',
                                                style: TextStyle(fontSize: ResponsiveUtils.getTitleSize(context) - 4),
                                              ),
                                              value: _platformDeliveryEnabled,
                                              onChanged: _deliveryMode == 'seller' ? null : (value) {
                                                setState(() => _platformDeliveryEnabled = value!);
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    } else {
                                      // Mobile: Stacked vertically
                                      return Column(
                                        children: [
                                          CheckboxListTile(
                                            title: Text(
                                              'Enable Seller Delivery',
                                              style: TextStyle(fontSize: ResponsiveUtils.getTitleSize(context) - 3),
                                            ),
                                            subtitle: Text(
                                              'Handle deliveries yourself',
                                              style: TextStyle(fontSize: ResponsiveUtils.getTitleSize(context) - 4),
                                            ),
                                            value: _sellerDeliveryEnabled,
                                            onChanged: _deliveryMode == 'platform' ? null : (value) {
                                              setState(() => _sellerDeliveryEnabled = value!);
                                            },
                                          ),
                                          CheckboxListTile(
                                            title: Text(
                                              'Enable Platform Delivery',
                                              style: TextStyle(fontSize: ResponsiveUtils.getTitleSize(context) - 3),
                                            ),
                                            subtitle: Text(
                                              'Use platform drivers',
                                              style: TextStyle(fontSize: ResponsiveUtils.getTitleSize(context) - 4),
                                            ),
                                            value: _platformDeliveryEnabled,
                                            onChanged: _deliveryMode == 'seller' ? null : (value) {
                                              setState(() => _platformDeliveryEnabled = value!);
                                            },
                                          ),
                                        ],
                                      );
                                    }
                                  },
                                ),
                              ],
                              
                              // Seller Delivery Settings
                              if (_sellerDeliveryEnabled) ...[
                                const SizedBox(height: 16),
                                // Seller Delivery Settings Note
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.deepTeal.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.deepTeal.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.settings,
                                        color: AppTheme.deepTeal,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Configure your own delivery rates. These will override the default rates.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.deepTeal,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Seller Delivery Settings',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.deepTeal,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Responsive layout for delivery settings
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxWidth > 600) {
                                      // Desktop/Tablet: Side by side
                                      return Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildEnhancedTextField(
                                                  controller: TextEditingController(
                                                    text: _sellerDeliveryBaseFee.toString(),
                                                  ),
                                                  label: 'Base Fee (R)',
                                                  hint: '25.0',
                                                  prefixIcon: Icons.attach_money,
                                                  keyboardType: TextInputType.number,
                                                  onChanged: (value) {
                                                    if (value.isNotEmpty) {
                                                      _sellerDeliveryBaseFee = double.tryParse(value) ?? 25.0;
                                                    }
                                                  },
                                                ),
                                              ),
                                              SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                                              Expanded(
                                                child: _buildEnhancedTextField(
                                                  controller: TextEditingController(
                                                    text: _sellerDeliveryFeePerKm.toString(),
                                                  ),
                                                  label: 'Fee per km (R)',
                                                  hint: '6.5',
                                                  prefixIcon: Icons.trending_up,
                                                  keyboardType: TextInputType.number,
                                                  onChanged: (value) {
                                                    if (value.isNotEmpty) {
                                                      _sellerDeliveryFeePerKm = double.tryParse(value) ?? 6.5;
                                                    }
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildEnhancedTextField(
                                                  controller: TextEditingController(
                                                    text: _sellerDeliveryMaxFee.toString(),
                                                  ),
                                                  label: 'Max Fee (R)',
                                                  hint: '50.0',
                                                  prefixIcon: Icons.attach_money,
                                                  keyboardType: TextInputType.number,
                                                  onChanged: (value) {
                                                    if (value.isNotEmpty) {
                                                      _sellerDeliveryMaxFee = double.tryParse(value) ?? 50.0;
                                                    }
                                                  },
                                                ),
                                              ),
                                              SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                                              Expanded(
                                                child: _buildEnhancedTextField(
                                                  controller: TextEditingController(
                                                    text: _sellerDeliveryTime,
                                                  ),
                                                  label: 'Delivery Time',
                                                  hint: '30-45 minutes',
                                                  prefixIcon: Icons.access_time,
                                                  onChanged: (value) {
                                                    _sellerDeliveryTime = value;
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    } else {
                                      // Mobile: Stacked vertically
                                      return Column(
                                        children: [
                                          _buildEnhancedTextField(
                                            controller: TextEditingController(
                                              text: _sellerDeliveryBaseFee.toString(),
                                            ),
                                            label: 'Base Fee (R)',
                                            hint: '25.0',
                                            prefixIcon: Icons.attach_money,
                                            keyboardType: TextInputType.number,
                                            onChanged: (value) {
                                              if (value.isNotEmpty) {
                                                _sellerDeliveryBaseFee = double.tryParse(value) ?? 25.0;
                                              }
                                            },
                                          ),
                                          SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
                                          _buildEnhancedTextField(
                                            controller: TextEditingController(
                                              text: _sellerDeliveryFeePerKm.toString(),
                                            ),
                                            label: 'Fee per km (R)',
                                            hint: '6.5',
                                            prefixIcon: Icons.trending_up,
                                            keyboardType: TextInputType.number,
                                            onChanged: (value) {
                                              if (value.isNotEmpty) {
                                                _sellerDeliveryFeePerKm = double.tryParse(value) ?? 6.5;
                                              }
                                            },
                                          ),
                                          SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
                                          _buildEnhancedTextField(
                                            controller: TextEditingController(
                                              text: _sellerDeliveryMaxFee.toString(),
                                            ),
                                            label: 'Max Fee (R)',
                                            hint: '50.0',
                                            prefixIcon: Icons.attach_money,
                                            keyboardType: TextInputType.number,
                                            onChanged: (value) {
                                              if (value.isNotEmpty) {
                                                _sellerDeliveryMaxFee = double.tryParse(value) ?? 50.0;
                                              }
                                            },
                                          ),
                                          SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
                                          _buildEnhancedTextField(
                                            controller: TextEditingController(
                                              text: _sellerDeliveryTime,
                                            ),
                                            label: 'Delivery Time',
                                            hint: '30-45 minutes',
                                            prefixIcon: Icons.access_time,
                                            onChanged: (value) {
                                              _sellerDeliveryTime = value;
                                            },
                                          ),
                                        ],
                                      );
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        // Delivery Range Section
                        Container(
                          margin: EdgeInsets.only(bottom: ResponsiveUtils.getVerticalPadding(context)),
                          padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
                          decoration: BoxDecoration(
                            color: AppTheme.angel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.breeze.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.radar,
                                    color: AppTheme.deepTeal,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Delivery Range',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.deepTeal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Delivery Range Note
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.primaryGreen.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.lightbulb_outline,
                                      color: AppTheme.primaryGreen,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '💡 **Recommended:** 15-25km for urban areas, 30-50km for rural areas. Default: 20km (SA market standard).',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.primaryGreen,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Set the maximum distance you\'re willing to deliver. Your store won\'t be visible to customers outside this range.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGrey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Range Slider
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Range: ${_deliveryRange.toStringAsFixed(0)} km',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.deepTeal,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryGreen.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppTheme.primaryGreen,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '${_deliveryRange.toStringAsFixed(0)} km',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primaryGreen,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: AppTheme.deepTeal,
                                      inactiveTrackColor: AppTheme.cloud,
                                      thumbColor: AppTheme.primaryGreen,
                                      overlayColor: AppTheme.primaryGreen.withOpacity(0.2),
                                      valueIndicatorColor: AppTheme.deepTeal,
                                      valueIndicatorTextStyle: TextStyle(
                                        color: AppTheme.angel,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                    ),
                                    child: Slider(
                                      value: _deliveryRange.clamp(0.0, _getCategoryDeliveryCap()),
                                      min: 0.0,
                                      max: _getCategoryDeliveryCap(),
                                      divisions: _getCategoryDeliveryCap().toInt(),
                                      label: '${_deliveryRange.toStringAsFixed(0)} km',
                                      onChanged: (value) {
                                        setState(() {
                                          _deliveryRange = value;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '0 km',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.mediumGrey,
                                        ),
                                      ),
                                      Text(
                                        '${_getCategoryDeliveryCap().toStringAsFixed(0)} km',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.mediumGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  const SizedBox(height: 8),
                                  Text(
                                    'Notes: Delivery range applies only when Offer Delivery is ON. Food capped at 20 km; non‑food at 50 km. If you offer pickup only (Pargo/PAXI), delivery range is ignored. Non‑food pickup stores can be discovered with the Nationwide filter.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.primaryGreen.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: AppTheme.primaryGreen,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Important: Your store will only be visible to customers within your delivery range. Customers outside this range won\'t see your store in search results.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.primaryGreen,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // PAXI Pickup Service Section (moved above; keep disabled here to avoid duplicate UI)
                        if (false && _paxiVisible) Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.angel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.breeze.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.local_shipping,
                                    color: AppTheme.deepTeal,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'PAXI Pickup Service',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.deepTeal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Allow customers to collect orders from this store via PAXI pickup points.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGrey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // PAXI Service Toggle
                              SwitchListTile(
                                title: Text(
                                  'Enable PAXI Pickup Service',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.deepTeal,
                                  ),
                                ),
                                subtitle: Text(
                                  'Customers can select this store for PAXI pickup',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.mediumGrey,
                                  ),
                                ),
                                value: _paxiEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _paxiEnabled = value;
                                  });
                                },
                                activeColor: AppTheme.primaryGreen,
                              ),
                              
                              // Show PAXI details only if enabled
                              if (_paxiEnabled) ...[
                                const SizedBox(height: 16),
                                
                                // PAXI Information Card
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.primaryGreen.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: AppTheme.primaryGreen,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '✅ Customers can select your store for pickup\n'
                                          '✅ Automatic distance calculations\n'
                                          '✅ Admin-configured pricing\n'
                                          '✅ Uses your existing operating hours\n'
                                          '✅ No additional setup required',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.primaryGreen,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        // Pargo Pickup Service Section (moved above; keep disabled here to avoid duplicate UI)
                        if (false && _pargoVisible) Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.angel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.breeze.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.local_shipping,
                                    color: AppTheme.deepTeal,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pargo Pickup Service',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.deepTeal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Allow customers to collect orders from this store via Pargo pickup points.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGrey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Pargo Service Toggle
                              SwitchListTile(
                                title: Text(
                                  'Enable Pargo Pickup Service',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.deepTeal,
                                  ),
                                ),
                                subtitle: Text(
                                  'Customers can select this store for Pargo pickup',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.mediumGrey,
                                  ),
                                ),
                                value: _pargoEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _pargoEnabled = value;
                                  });
                                },
                                activeColor: AppTheme.primaryGreen,
                              ),
                              
                              // Show Pargo details only if enabled
                              if (_pargoEnabled) ...[
                                const SizedBox(height: 16),
                                
                                // Pargo Information Card
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.primaryGreen.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: AppTheme.primaryGreen,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '✅ Customers can select your store for pickup\n'
                                          '✅ Automatic distance calculations\n'
                                          '✅ Admin-configured pricing\n'
                                          '✅ Uses your existing operating hours\n'
                                          '✅ No additional setup required',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.primaryGreen,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        // Delivery Hours Section
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.angel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.breeze.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    color: AppTheme.deepTeal,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Delivery Hours',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.deepTeal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Set the hours when you\'re available for delivery.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGrey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Delivery Start Time
                              GestureDetector(
                                onTap: _isLoading ? null : _selectDeliveryStartTime,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.whisper,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.breeze.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.wb_sunny,
                                        color: AppTheme.deepTeal,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Start Time',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.mediumGrey,
                                              ),
                                            ),
                                            Text(
                                              _formatTimeOfDayAmPm(_deliveryStartTime),
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.deepTeal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        color: AppTheme.breeze,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Delivery End Time
                              GestureDetector(
                                onTap: _isLoading ? null : _selectDeliveryEndTime,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.whisper,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.breeze.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.nightlight_round,
                                        color: AppTheme.deepTeal,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'End Time',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.mediumGrey,
                                              ),
                                            ),
                                            Text(
                                              _formatTimeOfDayAmPm(_deliveryEndTime),
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.deepTeal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        color: AppTheme.breeze,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Operating Hours Section
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.angel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.breeze.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.store,
                                    color: AppTheme.deepTeal,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Store Operating Hours',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.deepTeal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Set the hours when your store is open for business.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGrey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Store Open Time
                              GestureDetector(
                                onTap: _isLoading ? null : _selectStoreOpenTime,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.whisper,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.breeze.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.wb_sunny,
                                        color: AppTheme.deepTeal,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Store Opens',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.mediumGrey,
                                              ),
                                            ),
                                            Text(
                                              _formatTimeOfDayAmPm(_storeOpenTime),
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.deepTeal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        color: AppTheme.breeze,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Store Close Time
                              GestureDetector(
                                onTap: _isLoading ? null : _selectStoreCloseTime,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.whisper,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.breeze.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.nightlight_round,
                                        color: AppTheme.deepTeal,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Store Closes',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.mediumGrey,
                                              ),
                                            ),
                                            Text(
                                              _formatTimeOfDayAmPm(_storeCloseTime),
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.deepTeal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        color: AppTheme.breeze,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Payout Details Section
                  _buildSectionCard(
                    title: 'Payout Details',
                    icon: Icons.account_balance,
                    children: [
                      _buildEnhancedTextField(
                        controller: _accountHolderController,
                        label: 'Account Holder Name',
                        hint: 'e.g., Jane Dlamini',
                        prefixIcon: Icons.person,
                        validator: (v) => (v == null || v.isEmpty) ? 'Enter account holder name' : null,
                      ),
                      _buildEnhancedTextField(
                        controller: _bankNameController,
                        label: 'Bank Name',
                        hint: 'e.g., FNB, Standard Bank',
                        prefixIcon: Icons.account_balance,
                        validator: (v) => (v == null || v.isEmpty) ? 'Enter bank name' : null,
                      ),
                      _buildEnhancedTextField(
                        controller: _accountNumberController,
                        label: 'Account Number',
                        hint: 'Bank account number',
                        prefixIcon: Icons.numbers,
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.isEmpty) ? 'Enter account number' : null,
                      ),
                      _buildEnhancedTextField(
                        controller: _branchCodeController,
                        label: 'Branch Code',
                        hint: 'e.g., 250 655',
                        prefixIcon: Icons.confirmation_number,
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.isEmpty) ? 'Enter branch code' : null,
                      ),
                      DropdownButtonFormField<String>(
                        value: const ['cheque','savings','business'].contains(_accountType) ? _accountType : 'cheque',
                        decoration: const InputDecoration(
                          labelText: 'Account Type',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.account_box),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'cheque', child: Text('Cheque/Current')),
                          DropdownMenuItem(value: 'savings', child: Text('Savings')),
                          DropdownMenuItem(value: 'business', child: Text('Business')),
                        ],
                        onChanged: (v) => setState(() => _accountType = (const ['cheque','savings','business'].contains(v) ? v : 'cheque') ?? 'cheque'),
                      ),
                    ],
                  ),

                  // Terms & Consent
                  _buildSectionCard(
                    title: 'Terms & Consent',
                    icon: Icons.verified_user,
                    children: [
                      CheckboxListTile(
                        value: _termsAccepted,
                        onChanged: (v) => setState(() => _termsAccepted = v ?? false),
                        title: const Text('I agree to the marketplace terms and payout policy'),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                  ),
                  
                  // Behind the Brand Section
                  _buildSectionCard(
                    title: 'Behind the Brand',
                    icon: Icons.business,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.deepTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.deepTeal.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: AppTheme.deepTeal,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Use this feature to tell your brand story and connect with customers. Share your journey, values, and what makes your products unique.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.deepTeal,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildEnhancedTextField(
                        controller: _storyController,
                        label: 'Behind the Brand',
                        hint: 'Tell customers about your brand journey, values, and what makes your products unique...',
                        prefixIcon: Icons.business,
                        maxLines: 4,
                      ),
                      _buildEnhancedTextField(
                        controller: _specialtiesController,
                        label: 'Specialties',
                        hint: 'Your best products or services (comma separated)',
                        prefixIcon: Icons.star,
                      ),
                      _buildEnhancedTextField(
                        controller: _passionController,
                        label: 'Your Passion Statement',
                        hint: 'What drives your love for your business?',
                        prefixIcon: Icons.favorite,
                        maxLines: 2,
                      ),
                      
                      // Brand Media Section
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Brand Media',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.deepTeal,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Column(
                              children: [
                                // Brand Photos Row
                                Row(
                                  children: [
                                    // First photo slot
                                    Expanded(
                                      child: _buildImageUploadCard(
                                        title: 'Brand Photo 1',
                                        icon: Icons.add_photo_alternate,
                                        imageFile: _extraPhotos.isNotEmpty ? _extraPhotos[0] : null,
                                        onTap: _pickExtraPhoto,
                                        subtitle: _extraPhotos.isEmpty ? 'Add first brand photo' : 'Photo 1 added',
                                        onRemove: _extraPhotos.isNotEmpty ? () => _removeExtraPhoto(0) : null,
                                      ),
                                    ),
                                    SizedBox(width: ResponsiveUtils.getHorizontalPadding(context) * 0.5),
                                    // Second photo slot
                                    Expanded(
                                      child: _buildImageUploadCard(
                                        title: 'Brand Photo 2',
                                        icon: Icons.add_photo_alternate,
                                        imageFile: _extraPhotos.length > 1 ? _extraPhotos[1] : null,
                                        onTap: _pickExtraPhoto,
                                        subtitle: _extraPhotos.length < 2 ? 'Add second brand photo' : 'Photo 2 added',
                                        onRemove: _extraPhotos.length > 1 ? () => _removeExtraPhoto(1) : null,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                                // Brand Video Row
                                _buildVideoUploadCard(
                                  title: 'Brand Video',
                                  icon: Icons.videocam,
                                  videoFile: _introVideo,
                                  onTap: _pickIntroVideo,
                                  subtitle: 'Tell your story (60s max)',
                                  onRemove: _introVideo != null ? () => _removeIntroVideo() : null,
                                ),
                              ],
                            ),
                            
                            // Show all selected extra photos
                            if (_extraPhotos.isNotEmpty) ...[
                              SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                              Text(
                                'Selected Brand Photos',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.deepTeal,
                                ),
                              ),
                              SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 0.5),
                              Wrap(
                                spacing: ResponsiveUtils.getHorizontalPadding(context) * 0.5,
                                runSpacing: ResponsiveUtils.getVerticalPadding(context) * 0.5,
                                children: _extraPhotos.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final photo = entry.value;
                                  return Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppTheme.breeze.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: kIsWeb
                                            ? Image.network(
                                                photo.path,
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover,
                                              )
                                            : _buildWebCompatibleImage(
                                                photo,
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover,
                                              ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () => _removeExtraPhoto(index),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.error.withOpacity(0.9),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.close,
                                                size: 12,
                                                color: AppTheme.angel,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                  
                  // Submit Button
                  _buildSubmitButton(),
                  
                  SizedBox(height: ResponsiveUtils.getVerticalPadding(context) * 2),
                ],
              ),
            ),
                ),
              ),
      ),
    );
  }
}

