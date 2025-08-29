import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for cleaning up orphaned data in Firestore
/// This service finds and removes data that references non-existent entities
class DataCleanupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Find orphaned chats (where buyer or seller no longer exists)
  static Future<List<Map<String, dynamic>>> findOrphanedChats() async {
    try {
      print('🔍 Finding orphaned chats...');
      
      // Get all valid user IDs
      final usersSnapshot = await _firestore.collection('users').get();
      final validUserIds = usersSnapshot.docs.map((doc) => doc.id).toSet();
      
      // Get all chats
      final chatsSnapshot = await _firestore.collection('chats').get();
      final orphanedChats = <Map<String, dynamic>>[];
      
      for (final chatDoc in chatsSnapshot.docs) {
        final chatData = chatDoc.data();
        final buyerId = chatData['buyerId'] as String?;
        final sellerId = chatData['sellerId'] as String?;
        
        if (buyerId != null && !validUserIds.contains(buyerId) ||
            sellerId != null && !validUserIds.contains(sellerId)) {
          orphanedChats.add({
            'chatId': chatDoc.id,
            'buyerId': buyerId,
            'sellerId': sellerId,
            'productId': chatData['productId'],
            'missingBuyer': buyerId != null && !validUserIds.contains(buyerId),
            'missingSeller': sellerId != null && !validUserIds.contains(sellerId),
          });
        }
      }
      
      print('📊 Found ${orphanedChats.length} orphaned chats');
      return orphanedChats;
    } catch (e) {
      print('❌ Error finding orphaned chats: $e');
      return [];
    }
  }

  /// Find orphaned chatbot conversations (where user no longer exists)
  static Future<List<Map<String, dynamic>>> findOrphanedChatbotConversations() async {
    try {
      print('🔍 Finding orphaned chatbot conversations...');
      
      // Get all valid user IDs
      final usersSnapshot = await _firestore.collection('users').get();
      final validUserIds = usersSnapshot.docs.map((doc) => doc.id).toSet();
      
      // Get all chatbot conversations
      final conversationsSnapshot = await _firestore.collection('chatbot_conversations').get();
      final orphanedConversations = <Map<String, dynamic>>[];
      
      for (final conversationDoc in conversationsSnapshot.docs) {
        final conversationData = conversationDoc.data();
        final userId = conversationData['userId'] as String?;
        
        if (userId != null && !validUserIds.contains(userId)) {
          orphanedConversations.add({
            'conversationId': conversationDoc.id,
            'userId': userId,
            'userEmail': conversationData['userEmail'],
            'createdAt': conversationData['createdAt'],
            'messageCount': conversationData['messageCount'] ?? 0,
          });
        }
      }
      
      print('📊 Found ${orphanedConversations.length} orphaned chatbot conversations');
      return orphanedConversations;
    } catch (e) {
      print('❌ Error finding orphaned chatbot conversations: $e');
      return [];
    }
  }

  /// Find orphaned orders (where buyer, seller, or product no longer exists)
  static Future<List<Map<String, dynamic>>> findOrphanedOrders() async {
    try {
      print('🔍 Finding orphaned orders...');
      
      // Get all valid user IDs and product IDs
      final usersSnapshot = await _firestore.collection('users').get();
      final validUserIds = usersSnapshot.docs.map((doc) => doc.id).toSet();
      
      final productsSnapshot = await _firestore.collection('products').get();
      final validProductIds = productsSnapshot.docs.map((doc) => doc.id).toSet();
      
      // Get all orders
      final ordersSnapshot = await _firestore.collection('orders').get();
      final orphanedOrders = <Map<String, dynamic>>[];
      
      for (final orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();
        final buyerId = orderData['buyerId'] as String?;
        final sellerId = orderData['sellerId'] as String?;
        final productId = orderData['productId'] as String?;
        
        bool isOrphaned = false;
        final issues = <String>[];
        
        if (buyerId != null && !validUserIds.contains(buyerId)) {
          isOrphaned = true;
          issues.add('Missing buyer: $buyerId');
        }
        
        if (sellerId != null && !validUserIds.contains(sellerId)) {
          isOrphaned = true;
          issues.add('Missing seller: $sellerId');
        }
        
        if (productId != null && !validProductIds.contains(productId)) {
          isOrphaned = true;
          issues.add('Missing product: $productId');
        }
        
        if (isOrphaned) {
          orphanedOrders.add({
            'orderId': orderDoc.id,
            'buyerId': buyerId,
            'sellerId': sellerId,
            'productId': productId,
            'issues': issues,
            'totalAmount': orderData['totalAmount'],
            'status': orderData['status'],
            'createdAt': orderData['createdAt'],
          });
        }
      }
      
      print('📊 Found ${orphanedOrders.length} orphaned orders');
      return orphanedOrders;
    } catch (e) {
      print('❌ Error finding orphaned orders: $e');
      return [];
    }
  }

  /// Find orphaned reviews (where reviewer, store owner, or product no longer exists)
  static Future<List<Map<String, dynamic>>> findOrphanedReviews() async {
    try {
      print('🔍 Finding orphaned reviews...');
      
      // Get all valid user IDs and product IDs
      final usersSnapshot = await _firestore.collection('users').get();
      final validUserIds = usersSnapshot.docs.map((doc) => doc.id).toSet();
      
      final productsSnapshot = await _firestore.collection('products').get();
      final validProductIds = productsSnapshot.docs.map((doc) => doc.id).toSet();
      
      // Get all reviews
      final reviewsSnapshot = await _firestore.collection('reviews').get();
      final orphanedReviews = <Map<String, dynamic>>[];
      
      for (final reviewDoc in reviewsSnapshot.docs) {
        final reviewData = reviewDoc.data();
        final userId = reviewData['userId'] as String?;
        final storeId = reviewData['storeId'] as String?;
        final productId = reviewData['productId'] as String?;
        
        bool isOrphaned = false;
        final issues = <String>[];
        
        if (userId != null && !validUserIds.contains(userId)) {
          isOrphaned = true;
          issues.add('Missing reviewer: $userId');
        }
        
        if (storeId != null && !validUserIds.contains(storeId)) {
          isOrphaned = true;
          issues.add('Missing store owner: $storeId');
        }
        
        if (productId != null && !validProductIds.contains(productId)) {
          isOrphaned = true;
          issues.add('Missing product: $productId');
        }
        
        if (isOrphaned) {
          orphanedReviews.add({
            'reviewId': reviewDoc.id,
            'userId': userId,
            'storeId': storeId,
            'productId': productId,
            'issues': issues,
            'rating': reviewData['rating'],
            'comment': reviewData['comment'],
            'timestamp': reviewData['timestamp'],
          });
        }
      }
      
      print('📊 Found ${orphanedReviews.length} orphaned reviews');
      return orphanedReviews;
    } catch (e) {
      print('❌ Error finding orphaned reviews: $e');
      return [];
    }
  }

  /// Find orphaned notifications (where user no longer exists)
  static Future<List<Map<String, dynamic>>> findOrphanedNotifications() async {
    try {
      print('🔍 Finding orphaned notifications...');
      
      // Get all valid user IDs
      final usersSnapshot = await _firestore.collection('users').get();
      final validUserIds = usersSnapshot.docs.map((doc) => doc.id).toSet();
      
      // Get all notifications
      final notificationsSnapshot = await _firestore.collection('notifications').get();
      final orphanedNotifications = <Map<String, dynamic>>[];
      
      for (final notificationDoc in notificationsSnapshot.docs) {
        final notificationData = notificationDoc.data();
        final userId = notificationData['userId'] as String?;
        
        if (userId != null && !validUserIds.contains(userId)) {
          orphanedNotifications.add({
            'notificationId': notificationDoc.id,
            'userId': userId,
            'title': notificationData['title'],
            'body': notificationData['body'],
            'type': notificationData['type'],
            'timestamp': notificationData['timestamp'],
          });
        }
      }
      
      print('📊 Found ${orphanedNotifications.length} orphaned notifications');
      return orphanedNotifications;
    } catch (e) {
      print('❌ Error finding orphaned notifications: $e');
      return [];
    }
  }

  /// Find orphaned FCM tokens (where user no longer exists)
  static Future<List<Map<String, dynamic>>> findOrphanedFcmTokens() async {
    try {
      print('🔍 Finding orphaned FCM tokens...');
      
      // Get all valid user IDs
      final usersSnapshot = await _firestore.collection('users').get();
      final validUserIds = usersSnapshot.docs.map((doc) => doc.id).toSet();
      
      // Get all FCM tokens
      final tokensSnapshot = await _firestore.collection('fcm_tokens').get();
      final orphanedTokens = <Map<String, dynamic>>[];
      
      for (final tokenDoc in tokensSnapshot.docs) {
        final tokenData = tokenDoc.data();
        final userId = tokenData['userId'] as String?;
        
        if (userId != null && !validUserIds.contains(userId)) {
          orphanedTokens.add({
            'tokenId': tokenDoc.id,
            'userId': userId,
            'token': tokenData['token'],
            'platform': tokenData['platform'],
            'createdAt': tokenData['createdAt'],
          });
        }
      }
      
      print('📊 Found ${orphanedTokens.length} orphaned FCM tokens');
      return orphanedTokens;
    } catch (e) {
      print('❌ Error finding orphaned FCM tokens: $e');
      return [];
    }
  }

  /// Find orphaned products (where owner no longer exists)
  static Future<List<Map<String, dynamic>>> findOrphanedProducts() async {
    try {
      print('🔍 Finding orphaned products...');
      
      // Get all valid user IDs
      final usersSnapshot = await _firestore.collection('users').get();
      final validUserIds = usersSnapshot.docs.map((doc) => doc.id).toSet();
      
      // Get all products
      final productsSnapshot = await _firestore.collection('products').get();
      final orphanedProducts = <Map<String, dynamic>>[];
      
      for (final productDoc in productsSnapshot.docs) {
        final productData = productDoc.data();
        final ownerId = productData['ownerId'] as String?;
        
        if (ownerId != null && !validUserIds.contains(ownerId)) {
          orphanedProducts.add({
            'productId': productDoc.id,
            'ownerId': ownerId,
            'name': productData['name'],
            'category': productData['category'],
            'price': productData['price'],
            'createdAt': productData['createdAt'],
          });
        }
      }
      
      print('📊 Found ${orphanedProducts.length} orphaned products');
      return orphanedProducts;
    } catch (e) {
      print('❌ Error finding orphaned products: $e');
      return [];
    }
  }

  /// Perform a comprehensive scan for all types of orphaned data
  static Future<Map<String, List<Map<String, dynamic>>>> findAllOrphanedData() async {
    print('🧹 Starting comprehensive orphaned data scan...');
    
    final results = <String, List<Map<String, dynamic>>>{};
    
    try {
      results['chats'] = await findOrphanedChats();
      results['chatbot_conversations'] = await findOrphanedChatbotConversations();
      results['orders'] = await findOrphanedOrders();
      results['reviews'] = await findOrphanedReviews();
      results['notifications'] = await findOrphanedNotifications();
      results['fcm_tokens'] = await findOrphanedFcmTokens();
      results['products'] = await findOrphanedProducts();
      
      final totalOrphaned = results.values.map((list) => list.length).reduce((a, b) => a + b);
      print('✅ Scan complete! Found $totalOrphaned total orphaned records');
      
      // Print summary
      print('\n📊 ORPHANED DATA SUMMARY:');
      results.forEach((collection, orphanedItems) {
        if (orphanedItems.isNotEmpty) {
          print('  - $collection: ${orphanedItems.length} orphaned records');
        }
      });
      
    } catch (e) {
      print('❌ Error during comprehensive scan: $e');
    }
    
    return results;
  }

  /// Delete orphaned chats and their messages
  static Future<int> deleteOrphanedChats(List<Map<String, dynamic>> orphanedChats) async {
    int deletedCount = 0;
    
    try {
      for (final chat in orphanedChats) {
        final chatId = chat['chatId'] as String;
        
        // Delete all messages in the chat
        final messagesSnapshot = await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .get();
        
        // Delete messages in batches
        final batch = _firestore.batch();
        for (final messageDoc in messagesSnapshot.docs) {
          batch.delete(messageDoc.reference);
        }
        
        // Delete the chat document itself
        batch.delete(_firestore.collection('chats').doc(chatId));
        
        await batch.commit();
        deletedCount++;
        
        print('🗑️ Deleted orphaned chat: $chatId (${messagesSnapshot.docs.length} messages)');
      }
    } catch (e) {
      print('❌ Error deleting orphaned chats: $e');
    }
    
    return deletedCount;
  }

  /// Delete orphaned chatbot conversations and their messages
  static Future<int> deleteOrphanedChatbotConversations(List<Map<String, dynamic>> orphanedConversations) async {
    int deletedCount = 0;
    
    try {
      for (final conversation in orphanedConversations) {
        final conversationId = conversation['conversationId'] as String;
        
        // Delete all messages in the conversation
        final messagesSnapshot = await _firestore
            .collection('chatbot_conversations')
            .doc(conversationId)
            .collection('messages')
            .get();
        
        // Delete messages in batches
        final batch = _firestore.batch();
        for (final messageDoc in messagesSnapshot.docs) {
          batch.delete(messageDoc.reference);
        }
        
        // Delete the conversation document itself
        batch.delete(_firestore.collection('chatbot_conversations').doc(conversationId));
        
        await batch.commit();
        deletedCount++;
        
        print('🗑️ Deleted orphaned chatbot conversation: $conversationId (${messagesSnapshot.docs.length} messages)');
      }
    } catch (e) {
      print('❌ Error deleting orphaned chatbot conversations: $e');
    }
    
    return deletedCount;
  }

  /// Delete orphaned data by collection type
  static Future<int> deleteOrphanedData(String collectionType, List<Map<String, dynamic>> orphanedItems) async {
    int deletedCount = 0;
    
    try {
      final batch = _firestore.batch();
      
      for (final item in orphanedItems) {
        String docId;
        
        switch (collectionType) {
          case 'orders':
            docId = item['orderId'] as String;
            break;
          case 'reviews':
            docId = item['reviewId'] as String;
            break;
          case 'notifications':
            docId = item['notificationId'] as String;
            break;
          case 'fcm_tokens':
            docId = item['tokenId'] as String;
            break;
          case 'products':
            docId = item['productId'] as String;
            break;
          default:
            continue;
        }
        
        batch.delete(_firestore.collection(collectionType).doc(docId));
        deletedCount++;
      }
      
      if (deletedCount > 0) {
        await batch.commit();
        print('🗑️ Deleted $deletedCount orphaned records from $collectionType');
      }
    } catch (e) {
      print('❌ Error deleting orphaned $collectionType: $e');
      deletedCount = 0;
    }
    
    return deletedCount;
  }

  /// Perform comprehensive cleanup of all orphaned data
  static Future<Map<String, int>> cleanupAllOrphanedData({bool dryRun = true}) async {
    print('🧹 Starting ${dryRun ? 'DRY RUN' : 'LIVE'} comprehensive cleanup...');
    
    final results = <String, int>{};
    
    if (dryRun) {
      print('⚠️ DRY RUN MODE - No data will actually be deleted');
      final orphanedData = await findAllOrphanedData();
      orphanedData.forEach((collection, items) {
        results[collection] = items.length;
      });
      return results;
    }
    
    try {
      // Find all orphaned data first
      final orphanedData = await findAllOrphanedData();
      
      // Delete orphaned data by type
      results['chats'] = await deleteOrphanedChats(orphanedData['chats'] ?? []);
      results['chatbot_conversations'] = await deleteOrphanedChatbotConversations(orphanedData['chatbot_conversations'] ?? []);
      results['orders'] = await deleteOrphanedData('orders', orphanedData['orders'] ?? []);
      results['reviews'] = await deleteOrphanedData('reviews', orphanedData['reviews'] ?? []);
      results['notifications'] = await deleteOrphanedData('notifications', orphanedData['notifications'] ?? []);
      results['fcm_tokens'] = await deleteOrphanedData('fcm_tokens', orphanedData['fcm_tokens'] ?? []);
      results['products'] = await deleteOrphanedData('products', orphanedData['products'] ?? []);
      
      final totalDeleted = results.values.reduce((a, b) => a + b);
      print('✅ Cleanup complete! Deleted $totalDeleted total orphaned records');
      
    } catch (e) {
      print('❌ Error during comprehensive cleanup: $e');
    }
    
    return results;
  }

  /// Get storage statistics for all collections
  static Future<Map<String, dynamic>> getDataStats() async {
    try {
      print('📊 Calculating database statistics...');
      
      final stats = <String, dynamic>{};
      final collections = ['users', 'products', 'chats', 'orders', 'reviews', 'notifications', 'fcm_tokens', 'chatbot_conversations'];
      
      for (final collection in collections) {
        final snapshot = await _firestore.collection(collection).get();
        stats[collection] = {
          'totalDocuments': snapshot.docs.length,
          'sizeBytes': snapshot.docs.fold<int>(0, (sum, doc) {
            // Rough estimate of document size
            final data = doc.data();
            return sum + data.toString().length;
          }),
        };
      }
      
      // Calculate chat messages separately
      final chatsSnapshot = await _firestore.collection('chats').get();
      int totalChatMessages = 0;
      for (final chatDoc in chatsSnapshot.docs) {
        final messagesSnapshot = await chatDoc.reference.collection('messages').get();
        totalChatMessages += messagesSnapshot.docs.length;
      }
      stats['chat_messages'] = {
        'totalDocuments': totalChatMessages,
        'sizeBytes': totalChatMessages * 200, // Rough estimate
      };
      
      // Calculate chatbot messages separately
      final conversationsSnapshot = await _firestore.collection('chatbot_conversations').get();
      int totalChatbotMessages = 0;
      for (final conversationDoc in conversationsSnapshot.docs) {
        final messagesSnapshot = await conversationDoc.reference.collection('messages').get();
        totalChatbotMessages += messagesSnapshot.docs.length;
      }
      stats['chatbot_messages'] = {
        'totalDocuments': totalChatbotMessages,
        'sizeBytes': totalChatbotMessages * 200, // Rough estimate
      };
      
      return stats;
    } catch (e) {
      print('❌ Error calculating data stats: $e');
      return {};
    }
  }
}
