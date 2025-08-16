import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ImageCleanupService {
  static const String _imagekitUrl = 'https://api.imagekit.io/v1';
  static const String _privateKey = 'private_'; // You'll need to add your private key
  static const String _publicKey = 'public_tAO0SkfLl/37FQN+23c/bkAyfYg=';
  
  /// Get all images from ImageKit with pagination
  static Future<List<Map<String, dynamic>>> getAllImages({
    int limit = 100,
    String? path,
    String? searchQuery,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      
      if (path != null) queryParams['path'] = path;
      if (searchQuery != null) queryParams['searchQuery'] = searchQuery;
      
      final uri = Uri.parse('$_imagekitUrl/files').replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_privateKey:'))}',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['files'] ?? []);
      } else {
        throw Exception('Failed to fetch images: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching images: $e');
      return [];
    }
  }
  
  /// Delete a specific image from ImageKit
  static Future<bool> deleteImage(String fileId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_imagekitUrl/files/$fileId'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_privateKey:'))}',
          'Content-Type': 'application/json',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error deleting image $fileId: $e');
      return false;
    }
  }
  
  /// Delete multiple images in batch
  static Future<Map<String, bool>> deleteImages(List<String> fileIds) async {
    final results = <String, bool>{};
    
    for (final fileId in fileIds) {
      results[fileId] = await deleteImage(fileId);
      // Add small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    return results;
  }
  
  /// Find orphaned product images (not referenced in database)
  static Future<List<Map<String, dynamic>>> findOrphanedProductImages() async {
    try {
      // Get all product images from ImageKit
      final allImages = await getAllImages(path: 'products/');
      
      // Get all product IDs from Firestore
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .get();
      
      final validProductIds = productsSnapshot.docs
          .map((doc) => doc.id)
          .toSet();
      
      // Filter out images that don't have valid product references
      final orphanedImages = <Map<String, dynamic>>[];
      
      for (final image in allImages) {
        final imagePath = image['filePath'] as String? ?? '';
        final pathParts = imagePath.split('/');
        
        if (pathParts.length >= 3) {
          final productId = pathParts[2]; // products/{productId}/{filename}
          
          if (!validProductIds.contains(productId)) {
            orphanedImages.add(image);
          }
        }
      }
      
      return orphanedImages;
    } catch (e) {
      print('❌ Error finding orphaned product images: $e');
      return [];
    }
  }
  
  /// Find orphaned profile images (not referenced in database)
  static Future<List<Map<String, dynamic>>> findOrphanedProfileImages() async {
    try {
      // Get all profile images from ImageKit
      final allImages = await getAllImages(path: 'profile_images/');
      
      // Get all user IDs from Firestore
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      final validUserIds = usersSnapshot.docs
          .map((doc) => doc.id)
          .toSet();
      
      // Filter out images that don't have valid user references
      final orphanedImages = <Map<String, dynamic>>[];
      
      for (final image in allImages) {
        final imagePath = image['filePath'] as String? ?? '';
        final pathParts = imagePath.split('/');
        
        if (pathParts.length >= 3) {
          final userId = pathParts[2]; // profile_images/{userId}/{filename}
          
          if (!validUserIds.contains(userId)) {
            orphanedImages.add(image);
          }
        }
      }
      
      return orphanedImages;
    } catch (e) {
      print('❌ Error finding orphaned profile images: $e');
      return [];
    }
  }
  
  /// Find orphaned store images (not referenced in database)
  static Future<List<Map<String, dynamic>>> findOrphanedStoreImages() async {
    try {
      // Get all store images from ImageKit
      final allImages = await getAllImages(path: 'store_images/');
      
      // Get all user IDs from Firestore (sellers)
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'seller')
          .get();
      
      final validUserIds = usersSnapshot.docs
          .map((doc) => doc.id)
          .toSet();
      
      // Filter out images that don't have valid user references
      final orphanedImages = <Map<String, dynamic>>[];
      
      for (final image in allImages) {
        final imagePath = image['filePath'] as String? ?? '';
        final pathParts = imagePath.split('/');
        
        if (pathParts.length >= 3) {
          final userId = pathParts[2]; // store_images/{userId}/{filename}
          
          if (!validUserIds.contains(userId)) {
            orphanedImages.add(image);
          }
        }
      }
      
      return orphanedImages;
    } catch (e) {
      print('❌ Error finding orphaned store images: $e');
      return [];
    }
  }
  
  /// Find orphaned chat images (not referenced in database)
  static Future<List<Map<String, dynamic>>> findOrphanedChatImages() async {
    try {
      // Get all chat images from ImageKit
      final allImages = await getAllImages(path: 'chat_images/');
      
      // Get all chat IDs from Firestore
      final chatsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .get();
      
      final validChatIds = chatsSnapshot.docs
          .map((doc) => doc.id)
          .toSet();
      
      // Filter out images that don't have valid chat references
      final orphanedImages = <Map<String, dynamic>>[];
      
      for (final image in allImages) {
        final imagePath = image['filePath'] as String? ?? '';
        final pathParts = imagePath.split('/');
        
        if (pathParts.length >= 3) {
          final chatId = pathParts[2]; // chat_images/{chatId}/{filename}
          
          if (!validChatIds.contains(chatId)) {
            orphanedImages.add(image);
          }
        }
      }
      
      return orphanedImages;
    } catch (e) {
      print('❌ Error finding orphaned chat images: $e');
      return [];
    }
  }
  
  /// Get storage statistics
  static Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final allImages = await getAllImages(limit: 1000);
      
      int totalImages = 0;
      int totalSize = 0;
      Map<String, int> imagesByType = {};
      Map<String, int> sizeByType = {};
      
      for (final image in allImages) {
        totalImages++;
        final size = image['size'] as int? ?? 0;
        totalSize += size;
        
        final path = image['filePath'] as String? ?? '';
        final type = path.split('/').first;
        
        imagesByType[type] = (imagesByType[type] ?? 0) + 1;
        sizeByType[type] = (sizeByType[type] ?? 0) + size;
      }
      
      return {
        'totalImages': totalImages,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'imagesByType': imagesByType,
        'sizeByType': sizeByType,
      };
    } catch (e) {
      print('❌ Error getting storage stats: $e');
      return {};
    }
  }
  
  /// Clean up orphaned images automatically
  static Future<Map<String, int>> cleanupOrphanedImages() async {
    try {
      final results = <String, int>{};
      
      // Find and delete orphaned images by type
      final orphanedProducts = await findOrphanedProductImages();
      final orphanedProfiles = await findOrphanedProfileImages();
      final orphanedStores = await findOrphanedStoreImages();
      final orphanedChats = await findOrphanedChatImages();
      
      // Delete orphaned product images
      if (orphanedProducts.isNotEmpty) {
        final fileIds = orphanedProducts.map((img) => img['fileId'] as String).toList();
        final deleteResults = await deleteImages(fileIds);
        results['orphanedProducts'] = deleteResults.values.where((success) => success).length;
      }
      
      // Delete orphaned profile images
      if (orphanedProfiles.isNotEmpty) {
        final fileIds = orphanedProfiles.map((img) => img['fileId'] as String).toList();
        final deleteResults = await deleteImages(fileIds);
        results['orphanedProfiles'] = deleteResults.values.where((success) => success).length;
      }
      
      // Delete orphaned store images
      if (orphanedStores.isNotEmpty) {
        final fileIds = orphanedStores.map((img) => img['fileId'] as String).toList();
        final deleteResults = await deleteImages(fileIds);
        results['orphanedStores'] = deleteResults.values.where((success) => success).length;
      }
      
      // Delete orphaned chat images
      if (orphanedChats.isNotEmpty) {
        final fileIds = orphanedChats.map((img) => img['fileId'] as String).toList();
        final deleteResults = await deleteImages(fileIds);
        results['orphanedChats'] = deleteResults.values.where((success) => success).length;
      }
      
      return results;
    } catch (e) {
      print('❌ Error during cleanup: $e');
      return {};
    }
  }
  
  /// Delete all images for a specific product
  static Future<bool> deleteProductImages(String productId) async {
    try {
      final images = await getAllImages(path: 'products/$productId/');
      
      if (images.isEmpty) return true;
      
      final fileIds = images.map((img) => img['fileId'] as String).toList();
      final deleteResults = await deleteImages(fileIds);
      
      final successCount = deleteResults.values.where((success) => success).length;
      return successCount == fileIds.length;
    } catch (e) {
      print('❌ Error deleting product images: $e');
      return false;
    }
  }
  
  /// Delete all images for a specific user
  static Future<bool> deleteUserImages(String userId) async {
    try {
      bool allSuccess = true;
      
      // Delete profile images
      final profileImages = await getAllImages(path: 'profile_images/$userId/');
      if (profileImages.isNotEmpty) {
        final fileIds = profileImages.map((img) => img['fileId'] as String).toList();
        final deleteResults = await deleteImages(fileIds);
        allSuccess = allSuccess && deleteResults.values.every((success) => success);
      }
      
      // Delete store images
      final storeImages = await getAllImages(path: 'store_images/$userId/');
      if (storeImages.isNotEmpty) {
        final fileIds = storeImages.map((img) => img['fileId'] as String).toList();
        final deleteResults = await deleteImages(fileIds);
        allSuccess = allSuccess && deleteResults.values.every((success) => success);
      }
      
      // Delete product images
      final productImages = await getAllImages(path: 'products/$userId/');
      if (productImages.isNotEmpty) {
        final fileIds = productImages.map((img) => img['fileId'] as String).toList();
        final deleteResults = await deleteImages(fileIds);
        allSuccess = allSuccess && deleteResults.values.every((success) => success);
      }
      
      return allSuccess;
    } catch (e) {
      print('❌ Error deleting user images: $e');
      return false;
    }
  }
  
  /// Delete all images for a specific chat
  static Future<bool> deleteChatImages(String chatId) async {
    try {
      final images = await getAllImages(path: 'chat_images/$chatId/');
      
      if (images.isEmpty) return true;
      
      final fileIds = images.map((img) => img['fileId'] as String).toList();
      final deleteResults = await deleteImages(fileIds);
      
      final successCount = deleteResults.values.where((success) => success).length;
      return successCount == fileIds.length;
    } catch (e) {
      print('❌ Error deleting chat images: $e');
      return false;
    }
  }
}
