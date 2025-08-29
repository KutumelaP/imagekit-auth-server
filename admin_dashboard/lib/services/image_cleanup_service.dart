import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
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
			// Get auth token for the HTTP request
			final idToken = await FirebaseAuth.instance.currentUser?.getIdToken(true);
			if (idToken == null) {
				throw Exception('Failed to get authentication token');
			}
			
			// Use HTTP request instead of callable to handle CORS
			final httpResponse = await http.post(
				Uri.parse('https://us-central1-marketplace-8d6bd.cloudfunctions.net/batchDeleteImagesHttp'),
				headers: {
					'Content-Type': 'application/json',
					'Authorization': 'Bearer $idToken',
				},
				body: json.encode({'fileIds': [fileId]}),
			);
			
			if (httpResponse.statusCode != 200) {
				throw Exception('HTTP ${httpResponse.statusCode}: ${httpResponse.body}');
			}
			
			final response = json.decode(httpResponse.body) as Map<String, dynamic>;
			return response['success'] == true;
		} catch (e) {
			print('❌ Error deleting image $fileId: $e');
			return false;
		}
	}
	
	static Future<Map<String, bool>> deleteImages(List<String> fileIds) async {
		final Map<String, bool> overallResults = {};
		
		if (fileIds.isEmpty) {
			return overallResults;
		}
		
		try {
			print('🔄 Starting deletion of ${fileIds.length} images...');
			await FirebaseAuth.instance.currentUser?.getIdToken(true);
			final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
			final callable = functions.httpsCallable('batchDeleteImages');
			
			// Split into batches if needed (server limit is 50)
			const int maxBatchSize = 50;
			final List<List<String>> batches = [];
			for (int i = 0; i < fileIds.length; i += maxBatchSize) {
				batches.add(fileIds.sublist(i, i + maxBatchSize > fileIds.length ? fileIds.length : i + maxBatchSize));
			}
			
			print('📦 Processing ${fileIds.length} images in ${batches.length} batches (max $maxBatchSize per batch)');
			
			for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
				final currentBatch = batches[batchIndex];
				print('📦 Processing batch ${batchIndex + 1}/${batches.length} with ${currentBatch.length} images');
				
				try {
					print('📞 Calling batchDeleteImages with batch: $currentBatch');
					
					// Get auth token for the HTTP request
					final idToken = await FirebaseAuth.instance.currentUser?.getIdToken(true);
					if (idToken == null) {
						throw Exception('Failed to get authentication token');
					}
					
					// Use HTTP request instead of callable to handle CORS
					final httpResponse = await http.post(
						Uri.parse('https://us-central1-marketplace-8d6bd.cloudfunctions.net/batchDeleteImagesHttp'),
						headers: {
							'Content-Type': 'application/json',
							'Authorization': 'Bearer $idToken',
						},
						body: json.encode({'fileIds': currentBatch}),
					);
					
					print('📥 HTTP Response status: ${httpResponse.statusCode}');
					print('📥 HTTP Response body: ${httpResponse.body}');
					
					if (httpResponse.statusCode != 200) {
						throw Exception('HTTP ${httpResponse.statusCode}: ${httpResponse.body}');
					}
					
					final response = json.decode(httpResponse.body) as Map<String, dynamic>;
					print('🔍 Parsed response: $response');
					
					if (response['success'] == true && response['results'] is Map) {
						final Map<String, dynamic> serverResults = Map<String, dynamic>.from(response['results']);
						print('✅ Server results for batch ${batchIndex + 1}: $serverResults');
						
						for (final fileId in currentBatch) {
							final itemResult = serverResults[fileId];
							print('📋 Processing result for $fileId: $itemResult');
							
							if (itemResult == true) {
								overallResults[fileId] = true;
								print('✅ Successfully deleted $fileId from ImageKit');
							} else {
								overallResults[fileId] = false;
								print('❌ Server deletion failed for $fileId');
							}
						}
						
						// Show progress summary
						if (response['summary'] is Map) {
							final summary = response['summary'] as Map<String, dynamic>;
							print('📊 Batch ${batchIndex + 1} summary: ${summary['successful']}/${summary['total']} successful');
						}
					} else if (response['maxBatchSize'] != null) {
						// Handle batch size error specifically
						print('❌ Batch size too large: ${response['error']}');
						for (final id in currentBatch) {
							overallResults[id] = false;
						}
						break; // Stop processing remaining batches
					} else {
						print('❌ Server batchDeleteImages call failed for batch ${batchIndex + 1}: ${response['error'] ?? 'Unknown error'}');
						print('❌ Full response: $response');
						for (final id in currentBatch) {
							overallResults[id] = false;
						}
					}
					
					// Small delay between batches to be gentle on the server
					if (batchIndex < batches.length - 1) {
						print('⏳ Waiting 2 seconds before next batch...');
						await Future.delayed(const Duration(seconds: 2));
					}
					
				} catch (batchError) {
					print('❌ Error processing batch ${batchIndex + 1}: $batchError');
					for (final id in currentBatch) {
						overallResults[id] = false;
					}
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
			
			// Process Firestore updates in batches of 500 (Firestore limit)
			for (int i = 0; i < successfulFileIds.length; i += 500) {
				final batch = FirebaseFirestore.instance.batch();
				final batchIds = successfulFileIds.sublist(i, i + 500 > successfulFileIds.length ? successfulFileIds.length : i + 500);
				for (final fileId in batchIds) {
					batch.delete(FirebaseFirestore.instance.collection('image_assets').doc(fileId));
				}
				try {
					await batch.commit();
					print('✅ Successfully removed batch of ${batchIds.length} items from Firestore mirror.');
				} catch (e) {
					print('❌ Error removing batch from Firestore mirror: $e');
				}
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
	
	// Videos: profile_videos/<userId>/...
	static Future<List<Map<String, dynamic>>> findOrphanedProfileVideos() async {
		try {
			final orphaned = <Map<String, dynamic>>[];
			final allImages = await getAllImages(limit: 1000);
			final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
			final validUserIds = usersSnapshot.docs.map((doc) => doc.id).toSet();
			for (final image in allImages) {
				final rawPath = (image['filePath'] as String? ?? '').trim();
				if (rawPath.isEmpty) continue;
				final imagePath = rawPath.startsWith('/') ? rawPath.substring(1) : rawPath;
				final parts = imagePath.split('/').where((s) => s.isNotEmpty).toList();
				if (parts.length >= 2 && parts[0] == 'profile_videos') {
					final userId = parts[1];
					if (!validUserIds.contains(userId)) orphaned.add(image);
				}
			}
			return orphaned;
		} catch (e) {
			print('❌ Error finding orphaned profile videos: $e');
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
	
	// Videos: store_videos/<sellerId>/...
	static Future<List<Map<String, dynamic>>> findOrphanedStoreVideos() async {
		try {
			final orphaned = <Map<String, dynamic>>[];
			final allImages = await getAllImages(limit: 1000);
			final sellersSnapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'seller').get();
			final validSellerIds = sellersSnapshot.docs.map((doc) => doc.id).toSet();
			for (final image in allImages) {
				final rawPath = (image['filePath'] as String? ?? '').trim();
				if (rawPath.isEmpty) continue;
				final imagePath = rawPath.startsWith('/') ? rawPath.substring(1) : rawPath;
				final parts = imagePath.split('/').where((s) => s.isNotEmpty).toList();
				if (parts.length >= 2 && parts[0] == 'store_videos') {
					final sellerId = parts[1];
					if (!validSellerIds.contains(sellerId)) orphaned.add(image);
				}
			}
			return orphaned;
		} catch (e) {
			print('❌ Error finding orphaned store videos: $e');
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
			final orphanedProfileVids = await findOrphanedProfileVideos();
			final orphanedStoreVids = await findOrphanedStoreVideos();
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
			if (orphanedProfileVids.isNotEmpty) {
				final ids = orphanedProfileVids.map((e) => e['fileId'] as String).toList();
				final res = await deleteImages(ids);
				results['orphanedProfileVideos'] = res.values.where((ok) => ok).length;
			}
			if (orphanedStoreVids.isNotEmpty) {
				final ids = orphanedStoreVids.map((e) => e['fileId'] as String).toList();
				final res = await deleteImages(ids);
				results['orphanedStoreVideos'] = res.values.where((ok) => ok).length;
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

	// Uncategorized media: files not under known prefixes and not in kyc/
	static Future<List<Map<String, dynamic>>> findUncategorizedMedia() async {
		try {
			final orphaned = <Map<String, dynamic>>[];
			final knownPrefixes = <String>{
				'products/', 'profile_images/', 'store_images/', 'chat_images/',
				'profile_videos/', 'store_videos/', 'kyc/'
			};
			final allImages = await getAllImages(limit: 1000);
			for (final image in allImages) {
				final rawPath = (image['filePath'] as String? ?? '').trim();
				if (rawPath.isEmpty) continue;
				final imagePath = rawPath.startsWith('/') ? rawPath.substring(1) : rawPath;
				final hasKnownPrefix = knownPrefixes.any((p) => imagePath.startsWith(p));
				if (!hasKnownPrefix) {
					orphaned.add(image);
				}
			}
			return orphaned;
		} catch (e) {
			print('❌ Error finding uncategorized media: $e');
			return [];
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
