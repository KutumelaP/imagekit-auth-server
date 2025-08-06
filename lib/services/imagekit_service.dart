import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ImageKitService {
  static const String _publicKey = 'public_tAO0SkfLl/37FQN+23c/bkAyfYg=';
  static const String _authServerUrl = 'https://imagekit-auth-server-f4te.onrender.com/auth';
  static const String _uploadUrl = 'https://upload.imagekit.io/api/v1/files/upload';

  /// Upload image to ImageKit with authentication
  static Future<String?> uploadImageWithAuth({
    required dynamic file, // Can be File or XFile
    required String folder,
    String? customFileName,
    List<String>? tags,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ User not authenticated for image upload');
        return null;
      }

      print('🔍 Getting ImageKit auth parameters...');
      
      // Get authentication parameters from backend
      final response = await http.get(
        Uri.parse(_authServerUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30)); // Increased from 10 to 30 seconds

      if (response.statusCode != 200) {
        print('❌ Failed to get ImageKit auth parameters: ${response.statusCode}');
        throw Exception('Failed to get authentication parameters: ${response.statusCode}');
      }

      final authParams = Map<String, dynamic>.from(json.decode(response.body));
      print('✅ Got ImageKit auth params');

      // Validate auth parameters
      if (authParams['token'] == null || authParams['signature'] == null || authParams['expire'] == null) {
        throw Exception('Invalid authentication parameters received');
      }

      // Handle file reading based on platform
      List<int> bytes;
      String fileName;
      
      if (kIsWeb && file is XFile) {
        // Web: Use XFile
        bytes = await file.readAsBytes();
        fileName = customFileName ?? 
            '${folder}/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      } else if (file is File) {
        // Mobile: Use File
        bytes = await file.readAsBytes();
        fileName = customFileName ?? 
            '${folder}/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      } else {
        throw Exception('Unsupported file type');
      }

      // Create request
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      request.fields.addAll({
        'publicKey': _publicKey,
        'token': authParams['token'],
        'signature': authParams['signature'],
        'expire': authParams['expire'].toString(),
        'fileName': fileName,
        'folder': folder,
        'useUniqueFileName': 'true',
      });

      // Add tags if provided
      if (tags != null && tags.isNotEmpty) {
        request.fields['tags'] = tags.join(',');
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: path.basename(file.path),
        ),
      );

      print('🔍 Sending ImageKit upload request...');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final uploadResponse = await http.Response.fromStream(streamedResponse);

      print('🔍 ImageKit upload response status: ${uploadResponse.statusCode}');

      if (uploadResponse.statusCode == 200) {
        final result = json.decode(uploadResponse.body);
        final imageUrl = result['url'];
        print('✅ ImageKit upload successful: $imageUrl');
        return imageUrl;
      } else {
        final errorBody = uploadResponse.body;
        print('❌ ImageKit upload failed: $errorBody');
        
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
      print('❌ ImageKit upload error: $e');
      rethrow;
    }
  }

  /// Upload image to ImageKit using public upload (for chat images)
  static Future<String?> uploadImagePublic({
    required dynamic file, // Can be File or XFile
    required String folder,
    String? customFileName,
    List<String>? tags,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ User not authenticated for image upload');
        return null;
      }

      print('🔍 Starting ImageKit public upload...');

      // Handle file reading based on platform
      List<int> bytes;
      String fileName;
      
      if (kIsWeb && file is XFile) {
        // Web: Use XFile
        bytes = await file.readAsBytes();
        fileName = customFileName ?? 
            '${folder}/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      } else if (file is File) {
        // Mobile: Use File
        bytes = await file.readAsBytes();
        fileName = customFileName ?? 
            '${folder}/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      } else {
        throw Exception('Unsupported file type');
      }

      // Use ImageKit's public upload API
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      request.fields.addAll({
        'publicKey': _publicKey,
        'fileName': fileName,
        'folder': folder,
        'useUniqueFileName': 'true',
      });

      // Add tags if provided
      if (tags != null && tags.isNotEmpty) {
        request.fields['tags'] = tags.join(',');
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: path.basename(file.path),
        ),
      );

      print('🔍 Sending ImageKit upload request...');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final uploadResponse = await http.Response.fromStream(streamedResponse);

      print('🔍 ImageKit upload response status: ${uploadResponse.statusCode}');

      if (uploadResponse.statusCode == 200) {
        final result = json.decode(uploadResponse.body);
        final imageUrl = result['url'];
        print('✅ ImageKit upload successful: $imageUrl');
        return imageUrl;
      } else {
        final errorBody = uploadResponse.body;
        print('❌ ImageKit upload failed: $errorBody');
        throw Exception('Upload failed: ${uploadResponse.statusCode} - $errorBody');
      }
    } catch (e) {
      print('❌ ImageKit upload error: $e');
      rethrow;
    }
  }

  /// Upload chat image specifically
  static Future<String?> uploadChatImage({
    required File file,
    required String chatId,
    required String userId,
  }) async {
    return uploadImageWithAuth(
      file: file,
      folder: 'chat_images',
      customFileName: 'chat_images/$chatId/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}',
      tags: ['chat', chatId, userId],
    );
  }

  /// Upload product image
  static Future<String?> uploadProductImage({
    required File file,
    required String storeId,
    required String userId,
  }) async {
    return uploadImageWithAuth(
      file: file,
      folder: 'products',
      customFileName: 'products/$storeId/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}',
      tags: ['product', storeId, userId],
    );
  }

  /// Upload profile image
  static Future<String?> uploadProfileImage({
    required File file,
    required String userId,
  }) async {
    return uploadImageWithAuth(
      file: file,
      folder: 'profile_images',
      customFileName: 'profile_images/$userId/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}',
      tags: ['profile', userId],
    );
  }

  /// Upload store image
  static Future<String?> uploadStoreImage({
    required dynamic file, // Can be File or XFile
    required String userId,
  }) async {
    return uploadImageWithAuth(
      file: file,
      folder: 'store_images',
      customFileName: 'store_images/$userId/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}',
      tags: ['store', userId],
    );
  }

  /// Upload store video
  static Future<String?> uploadStoreVideo({
    required dynamic file, // Can be File or XFile
    required String userId,
  }) async {
    return uploadImageWithAuth(
      file: file,
      folder: 'store_videos',
      customFileName: 'store_videos/$userId/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}',
      tags: ['store_video', userId],
    );
  }
} 