import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ImageCleanupService {
	static Future<List<Map<String, dynamic>>> _listImagesPage({
		int limit = 100,
		int skip = 0,
		String? path,
		String? searchQuery,
	}) async {
		try {
			Query q = FirebaseFirestore.instance
				.collection('image_assets')
				.limit(limit);
			if (path != null && path.isNotEmpty) {
				q = q.where('filePath', isGreaterThanOrEqualTo: path)
					.where('filePath', isLessThan: path + '\uf8ff');
			}
			if (searchQuery != null && searchQuery.isNotEmpty) {
				q = q.where('name', isGreaterThanOrEqualTo: searchQuery)
					.where('name', isLessThan: searchQuery + '\uf8ff');
			}
			final snap = await q.get();
			return snap.docs.map((d) => d.data()).cast<Map<String, dynamic>>().toList();
		} catch (e) {
			print('❌ Firestore mirror read failed: $e');
			return [];
		}
	}
	
	static Future<List<Map<String, dynamic>>> getAllImages({
		int limit = 100,
		int skip = 0,
		String? path,
		String? searchQuery,
	}) async {
		try {
			return await _listImagesPage(limit: limit, skip: skip, path: path, searchQuery: searchQuery);
		} catch (e) {
			print('❌ Error fetching images: $e');
			return [];
		}
	}
	
	static Future<bool> deleteImage(String fileId) async {
		try {
			// Ensure fresh token with latest admin claims
			await FirebaseAuth.instance.currentUser?.getIdToken(true);
			final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
			final callable = functions.httpsCallable('batchDeleteImages');
			
			final result = await callable.call({'fileIds': [fileId]});
			final response = result.data as Map<String, dynamic>;
			return response['success'] == true;
		} catch (e) {
			print('❌ Error deleting image $fileId: $e');
			return false;
		}
	}
	
	static Future<Map<String, bool>> deleteImages(List<String> fileIds) async {
		final Map<String, bool> overallResults = {};
		try {
			print('🔄 Starting deletion of ${fileIds.length} images...');
			await FirebaseAuth.instance.currentUser?.getIdToken(true);
			final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
			final callable = functions.httpsCallable('batchDeleteImages');
			
			print('📞 Calling batchDeleteImages with fileIds: $fileIds');
			final result = await callable.call({'fileIds': fileIds});
			print('📥 Raw response from Cloud Function: ${result.data}');
			
			final response = result.data as Map<String, dynamic>;
			print('🔍 Parsed response: $response');
			
			if (response['success'] == true && response['results'] is Map) {
				final Map<String, dynamic> serverResults = Map<String, dynamic>.from(response['results']);
				print('✅ Server results: $serverResults');
				
				for (final fileId in fileIds) {
					final itemResult = serverResults[fileId];
					print('📋 Processing result for $fileId: $itemResult');
					
					if (itemResult != null && itemResult['success'] == true) {
						overallResults[fileId] = true;
						print('✅ Successfully deleted $fileId from ImageKit');
					} else {
						overallResults[fileId] = false;
						print('❌ Server deletion failed for $fileId: ${itemResult?['message'] ?? 'Unknown error'}');
					}
				}
			} else {
				print('❌ Server batchDeleteImages call failed: ${response['message'] ?? 'Unknown error'}');
				print('❌ Full response: $response');
				// Don't remove from Firestore mirror if server call fails entirely
				for (final id in fileIds) {
					overallResults[id] = false;
				}
			}
		} catch (e, stackTrace) {
			print('❌ Error calling batchDeleteImages callable: $e');
			print('❌ Stack trace: $stackTrace');
			// Don't remove from Firestore mirror if callable invocation fails
			for (final id in fileIds) {
				overallResults[id] = false;
			}
		}

		print('📊 Final results: $overallResults');
		
		// Only remove from Firestore mirror if ImageKit deletion was successful
		// This prevents orphaned Firestore entries when ImageKit still has the file
		final successfulFileIds = overallResults.entries.where((e) => e.value == true).map((e) => e.key).toList();
		if (successfulFileIds.isNotEmpty) {
			print('🗑️ Removing ${successfulFileIds.length} successfully deleted items from Firestore mirror...');
			final batch = FirebaseFirestore.instance.batch();
			for (final fileId in successfulFileIds) {
				batch.delete(FirebaseFirestore.instance.collection('image_assets').doc(fileId));
			}
			try {
				await batch.commit();
				print('✅ Successfully removed ${successfulFileIds.length} items from Firestore mirror.');
			} catch (e) {
				print('❌ Error removing items from Firestore mirror: $e');
			}
		}
		
		return overallResults;
	}

	static String? _extractFileIdFromUrlOrPath(Map<String, dynamic> image) {
		final id = image['fileId'] as String?;
		if (id != null && id.isNotEmpty) return id;
		// Fallback: not reliable, but try to read 'fileId' stored in mirror docs only
		return null;
	}
	
	static Future<List<Map<String, dynamic>>> findOrphanedProductImages() async {
		try {
			print('🔍 Starting orphaned product images scan...');
			final orphanedImages = <Map<String, dynamic>>[];
			
			// Get all images first, then filter by path
			final allImages = await getAllImages(limit: 1000);
			print('📸 Total images found: ${allImages.length}');
			
			// Get all valid product IDs
			final productsSnapshot = await FirebaseFirestore.instance.collection('products').get();
			final validProductIds = productsSnapshot.docs.map((doc) => doc.id).toSet();
			print('🏪 Valid product IDs: ${validProductIds.length}');
			
			// Scan all images for product references
			for (final image in allImages) {
				final rawPath = (image['filePath'] as String? ?? '').trim();
				if (rawPath.isEmpty) continue;
				final imagePath = rawPath.startsWith('/') ? rawPath.substring(1) : rawPath;
				final parts = imagePath.split('/').where((s) => s.isNotEmpty).toList();
				if (parts.length >= 2 && parts[0] == 'products') {
					final productId = parts[1];
					if (!validProductIds.contains(productId)) {
						orphanedImages.add(image);
					}
				}
			}
			
			print('🎯 Orphaned product images found: ${orphanedImages.length}');
			return orphanedImages;
		} catch (e) {
			print('❌ Error finding orphaned product images: $e');
			return [];
		}
	}
	
	static Future<List<Map<String, dynamic>>> findOrphanedProfileImages() async {
		try {
			final orphanedImages = <Map<String, dynamic>>[];
			final allImages = await getAllImages(limit: 1000);
			final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
			final validUserIds = usersSnapshot.docs.map((doc) => doc.id).toSet();
			for (final image in allImages) {
				final rawPath = (image['filePath'] as String? ?? '').trim();
				if (rawPath.isEmpty) continue;
				final imagePath = rawPath.startsWith('/') ? rawPath.substring(1) : rawPath;
				final parts = imagePath.split('/').where((s) => s.isNotEmpty).toList();
				if (parts.length >= 2 && parts[0] == 'profile_images') {
					final userId = parts[1];
					if (!validUserIds.contains(userId)) orphanedImages.add(image);
				}
			}
			return orphanedImages;
		} catch (e) {
			print('❌ Error finding orphaned profile images: $e');
			return [];
		}
	}
	
	static Future<List<Map<String, dynamic>>> findOrphanedStoreImages() async {
		try {
			final orphanedImages = <Map<String, dynamic>>[];
			final allImages = await getAllImages(limit: 1000);
			final sellersSnapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'seller').get();
			final validSellerIds = sellersSnapshot.docs.map((doc) => doc.id).toSet();
			for (final image in allImages) {
				final rawPath = (image['filePath'] as String? ?? '').trim();
				if (rawPath.isEmpty) continue;
				final imagePath = rawPath.startsWith('/') ? rawPath.substring(1) : rawPath;
				final parts = imagePath.split('/').where((s) => s.isNotEmpty).toList();
				if (parts.length >= 2 && parts[0] == 'store_images') {
					final sellerId = parts[1];
					if (!validSellerIds.contains(sellerId)) orphanedImages.add(image);
				}
			}
			return orphanedImages;
		} catch (e) {
			print('❌ Error finding orphaned store images: $e');
			return [];
		}
	}
	
	static Future<List<Map<String, dynamic>>> findOrphanedChatImages() async {
		try {
			final orphanedImages = <Map<String, dynamic>>[];
			final allImages = await getAllImages(limit: 1000);
			final chatsSnapshot = await FirebaseFirestore.instance.collection('chats').get();
			final validChatIds = chatsSnapshot.docs.map((doc) => doc.id).toSet();
			for (final image in allImages) {
				final rawPath = (image['filePath'] as String? ?? '').trim();
				if (rawPath.isEmpty) continue;
				final imagePath = rawPath.startsWith('/') ? rawPath.substring(1) : rawPath;
				final parts = imagePath.split('/').where((s) => s.isNotEmpty).toList();
				if (parts.length >= 2 && parts[0] == 'chat_images') {
					final chatId = parts[1];
					if (!validChatIds.contains(chatId)) orphanedImages.add(image);
				}
			}
			return orphanedImages;
		} catch (e) {
			print('❌ Error finding orphaned chat images: $e');
			return [];
		}
	}
	
	static Future<Map<String, int>> cleanupOrphanedImages() async {
		try {
			final orphanedProducts = await findOrphanedProductImages();
			final orphanedProfiles = await findOrphanedProfileImages();
			final orphanedStores = await findOrphanedStoreImages();
			final orphanedChats = await findOrphanedChatImages();
			final results = <String, int>{};
			if (orphanedProducts.isNotEmpty) {
				final ids = orphanedProducts.map((e) => e['fileId'] as String).toList();
				final res = await deleteImages(ids);
				results['orphanedProducts'] = res.values.where((ok) => ok).length;
			}
			if (orphanedProfiles.isNotEmpty) {
				final ids = orphanedProfiles.map((e) => e['fileId'] as String).toList();
				final res = await deleteImages(ids);
				results['orphanedProfiles'] = res.values.where((ok) => ok).length;
			}
			if (orphanedStores.isNotEmpty) {
				final ids = orphanedStores.map((e) => e['fileId'] as String).toList();
				final res = await deleteImages(ids);
				results['orphanedStores'] = res.values.where((ok) => ok).length;
			}
			if (orphanedChats.isNotEmpty) {
				final ids = orphanedChats.map((e) => e['fileId'] as String).toList();
				final res = await deleteImages(ids);
				results['orphanedChats'] = res.values.where((ok) => ok).length;
			}
			return results;
		} catch (e) {
			print('❌ Error during cleanup: $e');
			return {};
		}
	}
	
	static Future<Map<String, dynamic>> getStorageStats() async {
		try {
			final snap = await FirebaseFirestore.instance.collection('image_assets').limit(2000).get();
			int totalImages = snap.size;
			int totalSize = 0;
			final Map<String, int> imagesByType = {};
			final Map<String, int> sizeByType = {};
			for (final d in snap.docs) {
				final data = d.data();
				final size = (data['size'] as int?) ?? 0;
				totalSize += size;
				final type = (data['type'] as String?) ?? '';
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
			print('❌ Error getting storage stats from Firestore: $e');
			return {};
		}
	}

	// Debug function to list all images and their paths
	static Future<void> debugListAllImages() async {
		try {
			print('🔍 DEBUG: Listing all images...');
			final allImages = await getAllImages(limit: 1000);
			print('📸 Total images in collection: ${allImages.length}');
			
			for (int i = 0; i < allImages.length; i++) {
				final image = allImages[i];
				final filePath = image['filePath'] as String? ?? 'NO_PATH';
				final name = image['name'] as String? ?? 'NO_NAME';
				print('${i + 1}. $name -> $filePath');
			}
		} catch (e) {
			print('❌ Debug error: $e');
		}
	}

	// Set custom claims for the current user
	static Future<bool> setUserCustomClaims() async {
		try {
			final user = FirebaseAuth.instance.currentUser;
			if (user == null) return false;
			
			final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
			final callable = functions.httpsCallable('setUserCustomClaims');
			
			final result = await callable.call({'userId': user.uid});
			final response = result.data as Map<String, dynamic>;
			// Refresh current user's token so new claims are picked up immediately
			await user.getIdToken(true);
			
			return response['success'] == true;
		} catch (e) {
			print('❌ Error setting custom claims: $e');
			return false;
		}
	}

	// Test method to verify listImages function works
	static Future<bool> testListImages() async {
		try {
			// Ensure fresh token before testing
			await FirebaseAuth.instance.currentUser?.getIdToken(true);
			final images = await getAllImages(limit: 1, skip: 0);
			print('✅ listImages test successful: ${images.length} images returned');
			return true;
		} catch (e) {
			print('❌ listImages test failed: $e');
			return false;
		}
	}
}
