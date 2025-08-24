import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ImageKitService {
  // Remove hardcoded public key - will get it from server
  // static const String _publicKey = 'public_tAO0SkfLl/37FQN+23c/bkAyfYg=';
  
  // Use Firebase callable to fetch auth; legacy URLs retained as last-resort fallback if needed
  static const List<String> _legacyAuthServerUrls = [];
  
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
      
      // Preferred: Firebase callable function
      Map<String, dynamic>? authParams;
      try {
        final callable = FirebaseFunctions.instance.httpsCallable('getImageKitUploadAuth');
        final result = await callable.call();
        final data = result.data;
        if (data is Map) {
          authParams = Map<String, dynamic>.from(data as Map);
          print('✅ Got ImageKit auth params via Firebase callable');
        }
      } catch (e) {
        print('⚠️ Firebase callable getImageKitUploadAuth failed: $e');
      }

      // Legacy fallback (disabled by default)
      if (authParams == null) {
        for (String serverUrl in _legacyAuthServerUrls) {
          try {
            final response = await http.get(Uri.parse(serverUrl), headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 15));
            if (response.statusCode == 200) {
              authParams = Map<String, dynamic>.from(json.decode(response.body));
              print('✅ Got ImageKit auth params from legacy: $serverUrl');
              break;
            }
          } catch (_) {}
        }
      }

      if (authParams == null) {
        throw Exception('Authentication failed. Please check ImageKit callable configuration.');
      }

      // Validate auth parameters
      if (authParams['token'] == null || authParams['signature'] == null || authParams['expire'] == null) {
        throw Exception('Invalid authentication parameters received from ImageKit auth');
      }

      // Get public key from server config to ensure signature matches
      String publicKey;
      if (authParams['publicKey'] != null) {
        // Use public key from server response (recommended)
        publicKey = authParams['publicKey'];
        print('🔑 Using public key from server: ${publicKey.substring(0, 20)}...');
      } else {
        // Fallback to hardcoded key (for backward compatibility)
        publicKey = 'public_tAO0SkfLl/37FQN+23c/bkAyfYg=';
        print('⚠️ Using fallback public key: ${publicKey.substring(0, 20)}...');
      }

      // Determine filename and prepare multipart file
      String fileName;
      http.MultipartFile multipartFile;

      if (kIsWeb && file is XFile) {
        // Web: must use bytes
        final bytes = await file.readAsBytes();
        fileName = customFileName ?? '${folder}/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
        multipartFile = http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: path.basename(file.path),
        );
      } else {
        // Mobile/Desktop: support both File and XFile by streaming from disk to save memory
        File fileOnDisk;
        if (file is File) {
          fileOnDisk = file;
        } else if (file is XFile) {
          fileOnDisk = File(file.path);
        } else {
          throw Exception('Unsupported file type');
        }
        fileName = customFileName ?? '${folder}/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(fileOnDisk.path)}';
        final length = await fileOnDisk.length();
        multipartFile = http.MultipartFile(
          'file',
          fileOnDisk.openRead(),
          length,
          filename: path.basename(fileOnDisk.path),
        );
      }

      // Create request
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      request.fields.addAll({
        'publicKey': publicKey,
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

      request.files.add(multipartFile);

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

      String fileName;
      http.MultipartFile multipartFile;

      if (kIsWeb && file is XFile) {
        // Web: must use bytes
        final bytes = await file.readAsBytes();
        fileName = customFileName ?? '${folder}/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
        multipartFile = http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: path.basename(file.path),
        );
      } else {
        // Mobile/Desktop: support both File and XFile by streaming from disk to save memory
        File fileOnDisk;
        if (file is File) {
          fileOnDisk = file;
        } else if (file is XFile) {
          fileOnDisk = File(file.path);
        } else {
          throw Exception('Unsupported file type');
        }
        fileName = customFileName ?? '${folder}/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(fileOnDisk.path)}';
        final length = await fileOnDisk.length();
        multipartFile = http.MultipartFile(
          'file',
          fileOnDisk.openRead(),
          length,
          filename: path.basename(fileOnDisk.path),
        );
      }

      // Use ImageKit's public upload API
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      request.fields.addAll({
        'publicKey': 'public_tAO0SkfLl/37FQN+23c/bkAyfYg=', // Hardcoded for public upload
        'fileName': fileName,
        'folder': folder,
        'useUniqueFileName': 'true',
      });

      // Add tags if provided
      if (tags != null && tags.isNotEmpty) {
        request.fields['tags'] = tags.join(',');
      }

      request.files.add(multipartFile);

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