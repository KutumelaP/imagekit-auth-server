import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/image_api_config.dart';

class ImageCleanupService {
	static Future<List<Map<String, dynamic>>> _listImagesPage({
		int limit = 100,
		int skip = 0,
		String? path,
		String? searchQuery,
	}) async {
		final user = FirebaseAuth.instance.currentUser;
		final idToken = await user?.getIdToken();
		final url = ImageApiConfig.listUrl(limit: limit, skip: skip, path: path, searchQuery: searchQuery);
		final res = await http.get(Uri.parse(url), headers: {
			'Authorization': 'Bearer ${idToken ?? ''}',
		});
		if (res.statusCode == 200) {
			final body = json.decode(res.body) as Map<String, dynamic>;
			final files = body['files'];
			if (files is List) return files.cast<Map<String, dynamic>>();
		}
		return [];
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
			final user = FirebaseAuth.instance.currentUser;
			final idToken = await user?.getIdToken();
			final res = await http.post(
				Uri.parse(ImageApiConfig.batchDeleteUrl()),
				headers: {
					'Authorization': 'Bearer ${idToken ?? ''}',
					'Content-Type': 'application/json',
				},
				body: json.encode({'fileIds': [fileId]}),
			);
			return res.statusCode == 200;
		} catch (e) {
			print('❌ Error deleting image $fileId: $e');
			return false;
		}
	}
	
	static Future<Map<String, bool>> deleteImages(List<String> fileIds) async {
		try {
			final user = FirebaseAuth.instance.currentUser;
			final idToken = await user?.getIdToken();
			final res = await http.post(
				Uri.parse(ImageApiConfig.batchDeleteUrl()),
				headers: {
					'Authorization': 'Bearer ${idToken ?? ''}',
					'Content-Type': 'application/json',
				},
				body: json.encode({'fileIds': fileIds}),
			);
			if (res.statusCode == 200) {
				final results = <String, bool>{};
				for (final id in fileIds) results[id] = true;
				return results;
			}
		} catch (_) {}
		// Fallback to serial
		final results = <String, bool>{};
		for (final id in fileIds) {
			results[id] = await deleteImage(id);
		}
		return results;
	}
	
	static Future<List<Map<String, dynamic>>> findOrphanedProductImages() async {
		try {
			final orphanedImages = <Map<String, dynamic>>[];
			int skip = 0;
			const pageSize = 100;
			while (true) {
				final page = await getAllImages(limit: pageSize, skip: skip, path: 'products/');
				if (page.isEmpty) break;
				final productsSnapshot = await FirebaseFirestore.instance.collection('products').get();
				final validProductIds = productsSnapshot.docs.map((doc) => doc.id).toSet();
				for (final image in page) {
					final imagePath = (image['filePath'] as String? ?? '').trim();
					final parts = imagePath.split('/');
					if (parts.length >= 2 && parts[0] == 'products') {
						final productId = parts[1];
						if (!validProductIds.contains(productId)) orphanedImages.add(image);
					}
				}
				if (page.length < pageSize) break;
				skip += page.length;
			}
			return orphanedImages;
		} catch (e) {
			print('❌ Error finding orphaned product images: $e');
			return [];
		}
	}
	
	static Future<List<Map<String, dynamic>>> findOrphanedProfileImages() async {
		try {
			final orphanedImages = <Map<String, dynamic>>[];
			int skip = 0;
			const pageSize = 100;
			while (true) {
				final page = await getAllImages(limit: pageSize, skip: skip, path: 'profile_images/');
				if (page.isEmpty) break;
				final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
				final validUserIds = usersSnapshot.docs.map((doc) => doc.id).toSet();
				for (final image in page) {
					final imagePath = (image['filePath'] as String? ?? '').trim();
					final parts = imagePath.split('/');
					if (parts.length >= 2 && parts[0] == 'profile_images') {
						final userId = parts[1];
						if (!validUserIds.contains(userId)) orphanedImages.add(image);
					}
				}
				if (page.length < pageSize) break;
				skip += page.length;
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
			int skip = 0;
			const pageSize = 100;
			while (true) {
				final page = await getAllImages(limit: pageSize, skip: skip, path: 'store_images/');
				if (page.isEmpty) break;
				final usersSnapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'seller').get();
				final validUserIds = usersSnapshot.docs.map((doc) => doc.id).toSet();
				for (final image in page) {
					final imagePath = (image['filePath'] as String? ?? '').trim();
					final parts = imagePath.split('/');
					if (parts.length >= 2 && parts[0] == 'store_images') {
						final userId = parts[1];
						if (!validUserIds.contains(userId)) orphanedImages.add(image);
					}
				}
				if (page.length < pageSize) break;
				skip += page.length;
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
			int skip = 0;
			const pageSize = 100;
			while (true) {
				final page = await getAllImages(limit: pageSize, skip: skip, path: 'chat_images/');
				if (page.isEmpty) break;
				final chatsSnapshot = await FirebaseFirestore.instance.collection('chats').get();
				final validChatIds = chatsSnapshot.docs.map((doc) => doc.id).toSet();
				for (final image in page) {
					final imagePath = (image['filePath'] as String? ?? '').trim();
					final parts = imagePath.split('/');
					if (parts.length >= 2 && parts[0] == 'chat_images') {
						final chatId = parts[1];
						if (!validChatIds.contains(chatId)) orphanedImages.add(image);
					}
				}
				if (page.length < pageSize) break;
				skip += page.length;
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
			final allImages = await getAllImages(limit: 1000);
			int totalImages = 0;
			int totalSize = 0;
			final Map<String, int> imagesByType = {};
			final Map<String, int> sizeByType = {};
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
}
