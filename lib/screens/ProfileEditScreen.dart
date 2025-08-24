import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../theme/app_theme.dart';
import '../widgets/safe_network_image.dart';
import '../widgets/home_navigation_button.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _locationController = TextEditingController();
  final _storyController = TextEditingController();
  final _specialtiesController = TextEditingController();
  final _passionController = TextEditingController();
  File? _profileImage;
  String? _profileImageUrl;
  bool _isSeller = false;
  bool _loading = false;
  List<File> _storyPhotos = [];
  List<String> _storyPhotoUrls = [];
  File? _storyVideo;
  String? _storyVideoUrl;
  // Compliance & payments
  String _kycStatus = 'none';
  bool _pargoEnabled = false;
  bool _paxiEnabled = false;
  bool _pargoVisible = true;
  bool _paxiVisible = true;
  bool _allowCOD = true;
  double _minOrderForDelivery = 0.0;
  final TextEditingController _deliveryTimeEstimateController = TextEditingController();
  // Payout controllers
  final TextEditingController _payoutAccountHolderController = TextEditingController();
  final TextEditingController _payoutBankNameController = TextEditingController();
  final TextEditingController _payoutAccountNumberController = TextEditingController();
  final TextEditingController _payoutBranchCodeController = TextEditingController();
  // Canonical account type keys to match stored values
  String _payoutAccountType = 'cheque';
  bool _loadingPayout = false;
  bool _savingPayout = false;
  
  // Store settings for sellers
  bool _isStoreOpen = true;
  bool _isDeliveryAvailable = false;
  TimeOfDay _deliveryStartTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _deliveryEndTime = const TimeOfDay(hour: 18, minute: 0);
  
  // Operating hours variables
  TimeOfDay _storeOpenTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _storeCloseTime = const TimeOfDay(hour: 18, minute: 0);
  
  // Delivery range variables
  double _deliveryRange = 50.0; // Default 50km range (0-1000 range slider)
  final _customRangeController = TextEditingController();
  String? _selectedStoreCategory; // Store category for delivery range caps

  double _getCategoryDeliveryCapFromData(Map<String, dynamic> data) {
    final cat = (data['storeCategory'] ?? '').toString().toLowerCase();
    if (cat.contains('food')) return 20.0;
    return 50.0;
  }

  double _getCategoryDeliveryCap() {
    if (_selectedStoreCategory == null) return 50.0;
    final category = _selectedStoreCategory!.toLowerCase();
    if (category.contains('food') || category.contains('bakery') || category.contains('pastry') || 
        category.contains('dessert') || category.contains('beverage') || category.contains('drink') ||
        category.contains('coffee') || category.contains('tea') || category.contains('fruit') ||
        category.contains('vegetable') || category.contains('produce') || category.contains('snack')) {
      return 20.0; // Food category cap
    }
    return 50.0; // Non-food category cap
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};
    setState(() {
      _isSeller = data['role'] == 'seller';
      _nameController.text = data['storeName'] ?? data['username'] ?? '';
      _contactController.text = data['contact'] ?? '';
      _locationController.text = data['location'] ?? '';
      _storyController.text = data['story'] ?? '';
      _specialtiesController.text = (data['specialties'] is List)
        ? (data['specialties'] as List).join(', ')
        : (data['specialties'] ?? '');
      _passionController.text = data['passion'] ?? '';
      _profileImageUrl = data['profileImageUrl'];
      _storyPhotoUrls = (data['storyPhotoUrls'] as List?)?.cast<String>() ?? [];
      _storyVideoUrl = data['storyVideoUrl'];
      _kycStatus = (data['kycStatus'] as String?) ?? 'none';
      _pargoEnabled = data['pargoEnabled'] == true;
      _paxiEnabled = data['paxiEnabled'] == true;
      // Global visibility
      // Note: loaded below via config
      _allowCOD = data['allowCOD'] != false;
      _minOrderForDelivery = (data['minOrderForDelivery'] ?? 0.0).toDouble();
      _deliveryTimeEstimateController.text = data['deliveryTimeEstimate'] ?? '';
      // Apply capped default
      final cap = _getCategoryDeliveryCapFromData(data);
      _deliveryRange = (data['deliveryRange'] ?? cap).toDouble().clamp(0.0, cap);
      _selectedStoreCategory = data['storeCategory']; // Load store category
      
      // Load store settings for sellers
      if (_isSeller) {
        _isStoreOpen = data['isStoreOpen'] ?? true;
        _isDeliveryAvailable = data['deliveryAvailable'] ?? false;
        
        // Load delivery range
        // _deliveryRange = (data['deliveryRange'] ?? 50.0).toDouble().clamp(0.0, 2000.0); // This line is now handled by the cap
        
        // Load delivery hours
        final startHourStr = data['deliveryStartHour'] ?? '08:00';
        final endHourStr = data['deliveryEndHour'] ?? '18:00';
        
        _deliveryStartTime = _parseTimeString(startHourStr);
        _deliveryEndTime = _parseTimeString(endHourStr);
        
        // Load operating hours
        final storeOpenStr = data['storeOpenHour'] ?? '08:00';
        final storeCloseStr = data['storeCloseHour'] ?? '18:00';
        
        _storeOpenTime = _parseTimeString(storeOpenStr);
        _storeCloseTime = _parseTimeString(storeCloseStr);
      }
      
      _loading = false;
    });
    await _loadPayoutDetails();
    // Load global pickup visibility
    try {
      final cfgDoc = await FirebaseFirestore.instance.collection('config').doc('platform').get();
      final cfg = cfgDoc.data();
      if (cfg != null) {
        setState(() {
          _pargoVisible = (cfg['pargoVisible'] != false);
          _paxiVisible = (cfg['paxiVisible'] != false);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPayoutDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      setState(() { _loadingPayout = true; });
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('payout')
          .doc('bank')
          .get();
      if (doc.exists) {
        final d = doc.data();
        if (d != null) {
          _payoutAccountHolderController.text = (d['accountHolder'] ?? '').toString();
          _payoutBankNameController.text = (d['bankName'] ?? '').toString();
          _payoutAccountNumberController.text = (d['accountNumber'] ?? '').toString();
          _payoutBranchCodeController.text = (d['branchCode'] ?? '').toString();
          final at = (d['accountType'] ?? _payoutAccountType).toString();
          // Normalize possible display values to canonical keys
          switch (at.toLowerCase()) {
            case 'cheque/current':
            case 'cheque':
            case 'current':
              _payoutAccountType = 'cheque';
              break;
            case 'savings':
              _payoutAccountType = 'savings';
              break;
            case 'business cheque':
            case 'business':
              _payoutAccountType = 'business';
              break;
            default:
              _payoutAccountType = 'cheque';
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading payout details: $e');
    } finally {
      if (mounted) setState(() { _loadingPayout = false; });
    }
  }

  Future<String?> _uploadImageToImageKit(File file) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      print('DEBUG: Getting ImageKit auth parameters from server...');

      // Get authentication parameters from backend
      final response = await http.get(Uri.parse('https://imagekit-auth-server-f4te.onrender.com/auth'));

      if (response.statusCode != 200) {
        print('DEBUG: Failed to get ImageKit auth parameters. Response: ${response.body}');
        throw Exception('Failed to get authentication parameters');
      }
      
      final authParams = Map<String, dynamic>.from(jsonDecode(response.body));
      print('DEBUG: Got ImageKit auth params: ${authParams.toString()}');
      
      // Read file bytes safely
      List<int> bytes;
      try {
        if (kIsWeb) {
          // For web, we need to handle XFile differently
          if (file is XFile) {
            bytes = await file.readAsBytes();
          } else {
            throw Exception('Web environment requires XFile for file uploads');
          }
        } else {
          bytes = await file.readAsBytes();
        }
      } catch (e) {
        print('DEBUG: Error reading file bytes: $e');
        if (kIsWeb) {
          throw Exception('File reading not supported in web environment. Please use image picker for web.');
        }
        rethrow;
      }
      
      final fileName = 'profile_images/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://upload.imagekit.io/api/v1/files/upload'),
      );
      
      request.fields.addAll({
        'publicKey': 'public_tAO0SkfLl/37FQN+23c/bkAyfYg=',
        'token': authParams['token'],
        'signature': authParams['signature'],
        'expire': authParams['expire'].toString(),
        'fileName': fileName,
        'folder': 'profile_images/${user.uid}',
      });
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: path.basename(file.path),
        ),
      );
      
      print('DEBUG: Sending image upload request to ImageKit...');
      final streamedResponse = await request.send();
      final uploadResponse = await http.Response.fromStream(streamedResponse);
      print('DEBUG: ImageKit upload response: status=${uploadResponse.statusCode}, body=${uploadResponse.body}');
      
      if (uploadResponse.statusCode == 200) {
        final result = jsonDecode(uploadResponse.body);
        print('DEBUG: ImageKit upload success, url=${result['url']}');
        return result['url'];
      } else {
        throw Exception('Upload failed: ${uploadResponse.body}');
      }
    } catch (e, st) {
      print('DEBUG: ImageKit upload error: ${e.toString()}');
      print(st);
      return null;
    }
  }

  Future<String?> _uploadVideoToImageKit(File file) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      print('DEBUG: Getting ImageKit auth parameters for video upload...');

      // Get authentication parameters from backend
      final response = await http.get(Uri.parse('https://imagekit-auth-server-f4te.onrender.com/auth'));

      if (response.statusCode != 200) {
        print('DEBUG: Failed to get ImageKit auth parameters. Response: ${response.body}');
        throw Exception('Failed to get authentication parameters');
      }
      
      final authParams = Map<String, dynamic>.from(jsonDecode(response.body));
      print('DEBUG: Got ImageKit auth params for video: ${authParams.toString()}');
      
      // Read file bytes safely
      List<int> bytes;
      try {
        if (kIsWeb) {
          // For web, we need to handle XFile differently
          if (file is XFile) {
            bytes = await file.readAsBytes();
          } else {
            throw Exception('Web environment requires XFile for video uploads');
          }
        } else {
          bytes = await file.readAsBytes();
        }
      } catch (e) {
        print('DEBUG: Error reading video file bytes: $e');
        if (kIsWeb) {
          throw Exception('Video file reading not supported in web environment. Please use video picker for web.');
        }
        rethrow;
      }
      
      final fileName = 'profile_videos/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://upload.imagekit.io/api/v1/files/upload'),
      );
      
      request.fields.addAll({
        'publicKey': 'public_tAO0SkfLl/37FQN+23c/bkAyfYg=',
        'token': authParams['token'],
        'signature': authParams['signature'],
        'expire': authParams['expire'].toString(),
        'fileName': fileName,
        'folder': 'profile_videos/${user.uid}',
      });
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: path.basename(file.path),
        ),
      );
      
      print('DEBUG: Sending video upload request to ImageKit...');
      final streamedResponse = await request.send();
      final uploadResponse = await http.Response.fromStream(streamedResponse);
      print('DEBUG: ImageKit video upload response: status=${uploadResponse.statusCode}, body=${uploadResponse.body}');
      
      if (uploadResponse.statusCode == 200) {
        final result = jsonDecode(uploadResponse.body);
        print('DEBUG: ImageKit video upload success, url=${result['url']}');
        return result['url'];
      } else {
        throw Exception('Video upload failed: ${uploadResponse.body}');
      }
    } catch (e, st) {
      print('DEBUG: ImageKit video upload error: ${e.toString()}');
      print(st);
      return null;
    }
  }

  Future<void> _pickProfileImage() async {
    print('DEBUG: _pickProfileImage called');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Picked image! (debug)')),
      );
    }
    final picker = ImagePicker();
    print('Starting image picker for profile image');
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      print('No image selected');
      return;
    } else {
      print('Image selected: ${pickedFile.path}');
    }
    
    // Handle file creation based on platform
    File? imageFile;
    try {
      if (kIsWeb) {
        // For web, we need to handle this differently
        print('DEBUG: Running on web platform');
        // Convert XFile to bytes and create a temporary file
        await pickedFile.readAsBytes();
        // For web, we'll use the bytes directly
        setState(() {
          _profileImage = null; // Don't set File for web
        });
        // Upload directly using bytes
        final url = await _uploadImageToImageKitWeb(pickedFile);
        if (url != null) {
          setState(() => _profileImageUrl = url);
        } else {
          print('DEBUG: ImageKit upload returned null URL');
        }
      } else {
        // For mobile platforms
        imageFile = File(pickedFile.path);
    setState(() {
          _profileImage = imageFile;
    });
    // Upload to ImageKit
    try {
      print('DEBUG: Attempting to upload profile image to ImageKit...');
          final url = await _uploadImageToImageKit(imageFile);
      print('DEBUG: ImageKit upload result: ${url ?? 'null'}');
      if (url != null) {
        setState(() => _profileImageUrl = url);
      } else {
        print('DEBUG: ImageKit upload returned null URL');
      }
    } catch (e, st) {
      print('DEBUG: Error uploading profile image to ImageKit: ${e.toString()}');
      print(st);
        }
      }
    } catch (e) {
      print('DEBUG: Error handling picked image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing image: $e')),
      );
    }
  }

  Future<String?> _uploadImageToImageKitWeb(XFile file) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      
      print('DEBUG: Getting ImageKit auth parameters from server...');
      final response = await http.get(Uri.parse('https://imagekit-auth-server-f4te.onrender.com/auth'));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to get authentication parameters');
      }
      
      final authParams = Map<String, dynamic>.from(jsonDecode(response.body));
      final bytes = await file.readAsBytes();
      final fileName = 'profile_images/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://upload.imagekit.io/api/v1/files/upload'),
      );
      
      request.fields.addAll({
        'publicKey': 'public_tAO0SkfLl/37FQN+23c/bkAyfYg=',
        'token': authParams['token'],
        'signature': authParams['signature'],
        'expire': authParams['expire'].toString(),
        'fileName': fileName,
        'folder': 'profile_images/${user.uid}',
      });
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: path.basename(file.path),
        ),
      );
      
      print('DEBUG: Sending image upload request to ImageKit...');
      final streamedResponse = await request.send();
      final uploadResponse = await http.Response.fromStream(streamedResponse);
      
      if (uploadResponse.statusCode == 200) {
        final result = jsonDecode(uploadResponse.body);
        print('DEBUG: ImageKit upload success, url=${result['url']}');
        return result['url'];
      } else {
        throw Exception('Upload failed: ${uploadResponse.body}');
      }
    } catch (e) {
      print('DEBUG: ImageKit upload error: ${e.toString()}');
      return null;
    }
  }

  Future<void> _pickStoryPhoto() async {
    if (_storyPhotos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 story photos allowed')),
      );
      return;
    }
    
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    
    if (mounted) {
      setState(() {
        if (kIsWeb) {
          // For web, we'll handle XFile differently - don't add to _storyPhotos for web
          // _storyPhotos is for File objects only
        } else {
          // For mobile, convert to File
          _storyPhotos.add(File(pickedFile.path));
        }
      });
    }
    
    // Upload to ImageKit
    try {
      String? url;
      if (kIsWeb) {
        // For web, use XFile directly
        url = await _uploadImageToImageKitWeb(pickedFile);
      } else {
        // For mobile, convert to File
        url = await _uploadImageToImageKit(File(pickedFile.path));
      }
      
      if (url != null && mounted) {
        setState(() {
          _storyPhotoUrls.add(url!); // Use non-null assertion since we already checked
          if (!kIsWeb) {
            _storyPhotos.removeLast(); // Remove the local file after successful upload (mobile only)
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Story photo uploaded successfully!')),
          );
        }
      } else if (mounted) {
        setState(() {
          if (!kIsWeb) {
            _storyPhotos.removeLast(); // Remove the local file if upload failed (mobile only)
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload story photo')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!kIsWeb) {
            _storyPhotos.removeLast(); // Remove the local file if upload failed (mobile only)
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading story photo: $e')),
        );
      }
    }
  }

  Future<void> _pickStoryVideo() async {
    if (_storyVideo != null || _storyVideoUrl != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only one story video allowed')),
      );
      return;
    }
    
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
    if (pickedFile == null) return;
    
    if (mounted) {
      setState(() {
        _storyVideo = File(pickedFile.path);
      });
    }
    
    // Upload to ImageKit
    try {
      final url = await _uploadVideoToImageKit(File(pickedFile.path));
      if (url != null && mounted) {
        setState(() {
          _storyVideoUrl = url;
          _storyVideo = null; // Remove the local file after successful upload
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Story video uploaded successfully!')),
          );
        }
      } else if (mounted) {
        setState(() {
          _storyVideo = null; // Remove the local file if upload failed
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload story video')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _storyVideo = null; // Remove the local file if upload failed
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading story video: $e')),
        );
      }
    }
  }

  void _deleteStoryPhoto(int i) {
    if (mounted) {
      setState(() {
        if (i < _storyPhotoUrls.length) {
          _storyPhotoUrls.removeAt(i);
        }
      });
    }
  }

  void _deleteStoryVideo() {
    if (mounted) {
      setState(() {
        _storyVideoUrl = null;
        _storyVideo = null;
      });
    }
  }

  void _clearStoryText() {
    if (mounted) {
      setState(() {
        _storyController.clear();
      });
    }
  }

  // Helper function to parse time string (HH:MM format)
  TimeOfDay _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: hour, minute: minute);
    }
    return const TimeOfDay(hour: 8, minute: 0);
  }

  // Helper function to format TimeOfDay to string
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Function to select delivery start time
  Future<void> _selectDeliveryStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _deliveryStartTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppTheme.angel,
              hourMinuteTextColor: AppTheme.deepTeal,
              hourMinuteColor: AppTheme.cloud,
              dialHandColor: AppTheme.deepTeal,
              dialBackgroundColor: AppTheme.cloud,
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

  // Function to select delivery end time
  Future<void> _selectDeliveryEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _deliveryEndTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppTheme.angel,
              hourMinuteTextColor: AppTheme.deepTeal,
              hourMinuteColor: AppTheme.cloud,
              dialHandColor: AppTheme.deepTeal,
              dialBackgroundColor: AppTheme.cloud,
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

  // Function to select store open time
  Future<void> _selectStoreOpenTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _storeOpenTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppTheme.angel,
              hourMinuteTextColor: AppTheme.deepTeal,
              hourMinuteColor: AppTheme.cloud,
              dialHandColor: AppTheme.deepTeal,
              dialBackgroundColor: AppTheme.cloud,
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

  // Function to select store close time
  Future<void> _selectStoreCloseTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _storeCloseTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppTheme.angel,
              hourMinuteTextColor: AppTheme.deepTeal,
              hourMinuteColor: AppTheme.cloud,
              dialHandColor: AppTheme.deepTeal,
              dialBackgroundColor: AppTheme.cloud,
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

  Future<void> _saveProfile() async {
    print('DEBUG: _saveProfile called, _profileImage: $_profileImage');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saving profile... (debug)')),
      );
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // If a new image is picked, upload it first
    if (_profileImage != null && !kIsWeb) {
      print('DEBUG: Uploading new profile image before saving profile...');
      final url = await _uploadImageToImageKit(_profileImage!);
      print('DEBUG: ImageKit upload result in saveProfile: ${url ?? 'null'}');
      if (url != null) {
        _profileImageUrl = url;
        _profileImage = null; // Clear after upload
      }
    }
    // For web, the image should already be uploaded in _pickProfileImage

    final data = <String, dynamic>{
      if (_isSeller) 'storeName': _nameController.text.trim(),
      if (!_isSeller) 'username': _nameController.text.trim(),
      'contact': _contactController.text.trim(),
      'location': _locationController.text.trim(),
      'story': _storyController.text.trim(),
      'specialties': _specialtiesController.text.trim().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      'passion': _passionController.text.trim(),
      if (_profileImageUrl != null) 'profileImageUrl': _profileImageUrl,
      'storyPhotoUrls': _storyPhotoUrls,
      'storyVideoUrl': _storyVideoUrl,
      'storeCategory': _selectedStoreCategory, // Save store category
      
      // Store settings for sellers
      if (_isSeller) 'isStoreOpen': _isStoreOpen,
      if (_isSeller) 'deliveryAvailable': _isDeliveryAvailable,
      if (_isSeller) 'deliveryRange': _deliveryRange,
      if (_isSeller) 'deliveryStartHour': _formatTimeOfDay(_deliveryStartTime),
      if (_isSeller) 'deliveryEndHour': _formatTimeOfDay(_deliveryEndTime),
      if (_isSeller) 'storeOpenHour': _formatTimeOfDay(_storeOpenTime),
      if (_isSeller) 'storeCloseHour': _formatTimeOfDay(_storeCloseTime),
    };
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update(data);
    setState(() => _loading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
      Navigator.pop(context);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('Are you sure you want to delete your account? This will delete all your data and cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userId = user.uid;
    // Delete user document
    await FirebaseFirestore.instance.collection('users').doc(userId).delete();
    // Delete all products (if seller)
    final products = await FirebaseFirestore.instance.collection('products').where('ownerId', isEqualTo: userId).get();
    for (final doc in products.docs) {
      await doc.reference.delete();
    }
    // Delete all reviews
    final reviews = await FirebaseFirestore.instance.collection('reviews').where('userId', isEqualTo: userId).get();
    for (final doc in reviews.docs) {
      await doc.reference.delete();
    }
    // Delete all orders (as buyer or seller)
    final orders = await FirebaseFirestore.instance.collection('orders').where('buyerId', isEqualTo: userId).get();
    for (final doc in orders.docs) {
      await doc.reference.delete();
    }
    final sellerOrders = await FirebaseFirestore.instance.collection('orders').where('sellerId', isEqualTo: userId).get();
    for (final doc in sellerOrders.docs) {
      await doc.reference.delete();
    }
    // Delete all chats (as buyer or seller)
    final chats = await FirebaseFirestore.instance.collection('chats').where('buyerId', isEqualTo: userId).get();
    for (final chatDoc in chats.docs) {
      final messages = await chatDoc.reference.collection('messages').get();
      for (final msg in messages.docs) {
        await msg.reference.delete();
      }
      await chatDoc.reference.delete();
    }
    
    // Only delete seller chats if user is actually a seller
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data()?['role'] == 'seller') {
        final sellerChats = await FirebaseFirestore.instance.collection('chats').where('sellerId', isEqualTo: userId).get();
        for (final chatDoc in sellerChats.docs) {
          final messages = await chatDoc.reference.collection('messages').get();
          for (final msg in messages.docs) {
            await msg.reference.delete();
          }
          await chatDoc.reference.delete();
        }
      }
    } catch (e) {
      print('⚠️ Error checking seller chats: $e');
      // Continue with account deletion even if seller chat cleanup fails
    }
    // Delete favorites document
    await FirebaseFirestore.instance.collection('favorites').doc(userId).delete();
    // Delete Firebase Auth user
    await user.delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deleted.')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _locationController.dispose();
    _storyController.dispose();
    _specialtiesController.dispose();
    _passionController.dispose();
    _customRangeController.dispose();
    super.dispose();
  }

  Widget _buildThemedTextField({
    required TextEditingController controller,
    required String labelText,
    bool isRequired = false,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        labelStyle: TextStyle(color: AppTheme.cloud),
        floatingLabelStyle: TextStyle(color: AppTheme.deepTeal),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.cloud.withOpacity(0.5), width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        suffixIcon: suffixIcon,
      ),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
      maxLines: maxLines,
    );
  }

  Widget _buildSectionHeader(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.deepTeal,
      ),
    );
  }

  Widget _buildStoryPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (int i = 0; i < _storyPhotoUrls.length; i++)
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SafeNetworkImage(
                        imageUrl: _storyPhotoUrls[i], 
                        width: 80, 
                        height: 80, 
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade300,
                            child: Icon(Icons.image, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red, size: 20),
                      onPressed: () => _deleteStoryPhoto(i),
                    ),
                  ],
                ),
              ),
            if (_storyPhotoUrls.length < 2)
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: Icon(Icons.add_a_photo, color: AppTheme.deepTeal, size: 30),
                  onPressed: _pickStoryPhoto,
                ),
              ),
          ],
        ),
        if (_storyPhotoUrls.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Add up to 2 photos to tell your story',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStoreSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Store Open/Closed Toggle
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cloud.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.deepTeal.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isStoreOpen ? Icons.store : Icons.store_mall_directory,
                color: _isStoreOpen ? AppTheme.deepTeal : Colors.grey,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Store Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.deepTeal,
                      ),
                    ),
                    Text(
                      _isStoreOpen ? 'Store is Open' : 'Store is Closed',
                      style: TextStyle(
                        fontSize: 14,
                        color: _isStoreOpen ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isStoreOpen,
                onChanged: (value) {
                  setState(() {
                    _isStoreOpen = value;
                  });
                },
                activeColor: AppTheme.deepTeal,
                activeTrackColor: AppTheme.deepTeal.withOpacity(0.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Offer Delivery Toggle
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cloud.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.deepTeal.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isDeliveryAvailable ? Icons.delivery_dining : Icons.delivery_dining_outlined,
                color: _isDeliveryAvailable ? AppTheme.deepTeal : Colors.grey,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offer Delivery',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.deepTeal,
                      ),
                    ),
                    Text(
                      _isDeliveryAvailable ? 'Delivery Available' : 'Delivery Not Available',
                      style: TextStyle(
                        fontSize: 14,
                        color: _isDeliveryAvailable ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isDeliveryAvailable,
                onChanged: (value) {
                  setState(() {
                    _isDeliveryAvailable = value;
                  });
                },
                activeColor: AppTheme.deepTeal,
                activeTrackColor: AppTheme.deepTeal.withOpacity(0.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Delivery Hours Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cloud.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.deepTeal.withOpacity(0.2),
              width: 1,
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
                    size: 24,
                  ),
                  const SizedBox(width: 12),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectDeliveryStartTime,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.angel,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.deepTeal.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.wb_sunny,
                              color: AppTheme.deepTeal,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Start Time',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    _formatTimeOfDay(_deliveryStartTime),
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
                              Icons.edit,
                              color: AppTheme.deepTeal,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectDeliveryEndTime,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.angel,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.deepTeal.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.nightlight_round,
                              color: AppTheme.deepTeal,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'End Time',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    _formatTimeOfDay(_deliveryEndTime),
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
                              Icons.edit,
                              color: AppTheme.deepTeal,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tap on the time cards to edit delivery hours',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Operating Hours Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cloud.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.deepTeal.withOpacity(0.2),
              width: 1,
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
                    size: 24,
                  ),
                  const SizedBox(width: 12),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectStoreOpenTime,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.angel,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.deepTeal.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.wb_sunny,
                              color: AppTheme.deepTeal,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Store Opens',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    _formatTimeOfDay(_storeOpenTime),
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
                              Icons.edit,
                              color: AppTheme.deepTeal,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectStoreCloseTime,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.angel,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.deepTeal.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.nightlight_round,
                              color: AppTheme.deepTeal,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Store Closes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    _formatTimeOfDay(_storeCloseTime),
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
                              Icons.edit,
                              color: AppTheme.deepTeal,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tap on the time cards to edit store operating hours',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Delivery Hours Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cloud.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.deepTeal.withOpacity(0.2),
              width: 1,
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
                    size: 24,
                  ),
                  const SizedBox(width: 12),
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
                'Tap on the time cards to edit store operating hours',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStoryVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_storyVideoUrl != null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.videocam, 
                        size: 40, 
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red, size: 20),
                      onPressed: _deleteStoryVideo,
                    ),
                  ],
                ),
              ),
            if (_storyVideoUrl == null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: Icon(Icons.add_circle_outline, color: AppTheme.deepTeal, size: 30),
                  onPressed: _pickStoryVideo,
                ),
              ),
          ],
        ),
        if (_storyVideoUrl == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Add a video to showcase your story (max 1 minute)',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.whisper, // Use theme background
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: AppTheme.angel,
        elevation: 0,
        actions: [
          HomeNavigationButton(
            backgroundColor: AppTheme.deepTeal,
            iconColor: AppTheme.angel,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.deepTeal,
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickProfileImage,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.deepTeal.withOpacity(0.3),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.deepTeal.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: AppTheme.cloud.withOpacity(0.1),
                            backgroundImage: (_profileImage != null && !kIsWeb)
                                ? FileImage(_profileImage!)
                                : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                                    ? NetworkImage(_profileImageUrl!) as ImageProvider
                                    : null,
                            child: (_profileImage == null || kIsWeb) && (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                                ? Icon(
                                    Icons.person, 
                                    size: 48,
                                    color: AppTheme.deepTeal,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildThemedTextField(
                      controller: _nameController,
                      labelText: _isSeller ? 'Store Name' : 'Name',
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    _buildThemedTextField(
                      controller: _contactController,
                      labelText: 'Contact Info',
                    ),
                    const SizedBox(height: 16),
                    _buildThemedTextField(
                      controller: _locationController,
                      labelText: 'Location',
                    ),
                    if (_isSeller && _kycStatus != 'approved') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user, color: Colors.orange),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('Identity verification pending', style: TextStyle(fontWeight: FontWeight.w700)),
                                  SizedBox(height: 4),
                                  Text('Complete KYC to enable COD and payouts'),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => Navigator.of(context).pushNamed('/kyc'),
                              icon: const Icon(Icons.upload),
                              label: const Text('Complete KYC'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_isSeller) ...[
                      const SizedBox(height: 16),
                      _buildSectionHeader('Pickup Services'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cloud.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.deepTeal.withOpacity(0.2), width: 1),
                        ),
                        child: Column(
                          children: [
                            if (_pargoVisible) SwitchListTile(
                              value: _pargoEnabled,
                              onChanged: (v) async {
                                setState(() { _pargoEnabled = v; });
                                final user = FirebaseAuth.instance.currentUser;
                                if (user != null) await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'pargoEnabled': v});
                              },
                              title: const Text('Enable PARGO pickup points'),
                              subtitle: const Text('Let buyers pick up at PARGO locations'),
                            ),
                            if (_paxiVisible) SwitchListTile(
                              value: _paxiEnabled,
                              onChanged: (v) async {
                                setState(() { _paxiEnabled = v; });
                                final user = FirebaseAuth.instance.currentUser;
                                if (user != null) await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'paxiEnabled': v});
                              },
                              title: const Text('Enable PAXI pickup points'),
                              subtitle: const Text('Let buyers pick up at PAXI locations'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
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
                              Icons.info_outline,
                              size: 16,
                              color: AppTheme.deepTeal,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Nationwide Pickup: When enabled, non-food stores with Pargo/PAXI will be visible to buyers nationwide using the "Nationwide" filter on the store page.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.deepTeal,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildSectionHeader('Delivery Range'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cloud.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.deepTeal.withOpacity(0.2), width: 1),
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
                                'Delivery Range: ${_deliveryRange.toStringAsFixed(0)} km',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.deepTeal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppTheme.deepTeal,
                              inactiveTrackColor: AppTheme.cloud.withOpacity(0.3),
                              thumbColor: AppTheme.deepTeal,
                              overlayColor: AppTheme.deepTeal.withOpacity(0.2),
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
                            'Notes: Food is capped at 20 km, non-food at 50 km. Pickup (Pargo/PAXI) is local by default; buyers can use the Nationwide filter to see non-food pickup stores across SA.',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionHeader('Cash on Delivery & Delivery Info'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cloud.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.deepTeal.withOpacity(0.2), width: 1),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: _allowCOD,
                            onChanged: (v) async {
                              setState(() { _allowCOD = v; });
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'allowCOD': v});
                            },
                            title: const Text('Allow Cash on Delivery'),
                            subtitle: const Text('May be disabled if verification/dues pending'),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: _minOrderForDelivery.toStringAsFixed(0),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Minimum order amount for delivery (R)',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    prefixIcon: const Icon(Icons.payments),
                                  ),
                                  onChanged: (v) {
                                    final x = double.tryParse(v);
                                    if (x != null) _minOrderForDelivery = x;
                                  },
                                  onEditingComplete: () async {
                                    final user = FirebaseAuth.instance.currentUser;
                                    if (user != null) await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'minOrderForDelivery': _minOrderForDelivery});
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _deliveryTimeEstimateController,
                                  decoration: InputDecoration(
                                    labelText: 'Delivery time estimate (e.g., 30–45 min)',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    prefixIcon: const Icon(Icons.timer),
                                  ),
                                  onSubmitted: (v) async {
                                    final user = FirebaseAuth.instance.currentUser;
                                    if (user != null) await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'deliveryTimeEstimate': v});
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionHeader('Payout (Bank) Details'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cloud.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.deepTeal.withOpacity(0.2), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_loadingPayout) ...[
                            Row(children: const [
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('Loading payout details...'),
                            ]),
                            const SizedBox(height: 8),
                          ],
                          TextField(
                            controller: _payoutAccountHolderController,
                            decoration: InputDecoration(
                              labelText: 'Account Holder',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              prefixIcon: const Icon(Icons.person),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _payoutBankNameController,
                            decoration: InputDecoration(
                              labelText: 'Bank Name',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              prefixIcon: const Icon(Icons.account_balance),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _payoutAccountNumberController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Account Number',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    prefixIcon: const Icon(Icons.numbers),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _payoutBranchCodeController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Branch Code',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    prefixIcon: const Icon(Icons.pin),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _payoutAccountType,
                            items: const [
                              DropdownMenuItem(value: 'cheque', child: Text('Cheque/Current')),
                              DropdownMenuItem(value: 'savings', child: Text('Savings')),
                              DropdownMenuItem(value: 'business', child: Text('Business Cheque')),
                            ],
                            onChanged: (v) => setState(() => _payoutAccountType = v ?? 'cheque'),
                            decoration: InputDecoration(
                              labelText: 'Account Type',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              prefixIcon: const Icon(Icons.account_balance_wallet),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(
                              onPressed: _savingPayout ? null : () async {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null) return;
                                setState(() { _savingPayout = true; });
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .collection('payout')
                                      .doc('bank')
                                      .set({
                                        'accountHolder': _payoutAccountHolderController.text.trim(),
                                        'bankName': _payoutBankNameController.text.trim(),
                                        'accountNumber': _payoutAccountNumberController.text.trim(),
                                        'branchCode': _payoutBranchCodeController.text.trim(),
                                        'accountType': _payoutAccountType,
                                        'updatedAt': FieldValue.serverTimestamp(),
                                      }, SetOptions(merge: true));
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout details saved')));
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                                  }
                                } finally {
                                  if (mounted) setState(() { _savingPayout = false; });
                                }
                              },
                              icon: _savingPayout
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.save),
                              label: Text(_savingPayout ? 'Saving...' : 'Save Payout Details'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionHeader('Shortcuts'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/notification-settings'),
                            icon: const Icon(Icons.record_voice_over),
                            label: const Text('Notification & Voice'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/security-settings'),
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Security & Quick Login'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.deepTeal,
                        foregroundColor: AppTheme.angel,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _loading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: AppTheme.angel,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(height: 32),
                    Divider(),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: AppTheme.angel,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(Icons.delete_forever, color: AppTheme.angel),
                      label: const Text('Delete Account'),
                      onPressed: _loading ? null : _deleteAccount,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}