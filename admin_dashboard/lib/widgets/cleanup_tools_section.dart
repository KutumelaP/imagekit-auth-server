import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/image_cleanup_service.dart';
import 'section_header.dart';

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

  /// Find orphaned platform receivables (where seller no longer exists)
  static Future<List<Map<String, dynamic>>> findOrphanedPlatformReceivables() async {
    try {
      print('🔍 Finding orphaned platform receivables...');
      
      // Get all valid user IDs
      final usersSnapshot = await _firestore.collection('users').get();
      final validUserIds = usersSnapshot.docs.map((doc) => doc.id).toSet();
      
      // Get all platform receivables
      final receivablesSnapshot = await _firestore.collection('platform_receivables').get();
      final orphanedReceivables = <Map<String, dynamic>>[];
      
      for (final receivableDoc in receivablesSnapshot.docs) {
        final sellerId = receivableDoc.id;
        
        if (!validUserIds.contains(sellerId)) {
          // Get total amount owed by this deleted seller
          final entriesSnapshot = await receivableDoc.reference.collection('entries').get();
          double totalOwed = 0.0;
          int entryCount = 0;
          
          for (final entryDoc in entriesSnapshot.docs) {
            final entryData = entryDoc.data();
            final amount = (entryData['amount'] is num) 
                ? (entryData['amount'] as num).toDouble() 
                : double.tryParse('${entryData['amount']}') ?? 0.0;
            final commission = (entryData['commission'] is num) 
                ? (entryData['commission'] as num).toDouble() 
                : double.tryParse('${entryData['commission']}') ?? 0.0;
            
            totalOwed += amount > 0 ? amount : commission;
            entryCount++;
          }
          
          orphanedReceivables.add({
            'sellerId': sellerId,
            'totalOwed': totalOwed,
            'entryCount': entryCount,
            'hasEntries': entryCount > 0,
          });
        }
      }
      
      print('📊 Found ${orphanedReceivables.length} orphaned platform receivables');
      return orphanedReceivables;
    } catch (e) {
      print('❌ Error finding orphaned platform receivables: $e');
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
      results['notifications'] = await findOrphanedNotifications();
      results['fcm_tokens'] = await findOrphanedFcmTokens();
      results['platform_receivables'] = await findOrphanedPlatformReceivables();
      
      final totalOrphaned = results.values.map((list) => list.length).reduce((a, b) => a + b);
      print('✅ Scan complete! Found $totalOrphaned total orphaned records');
      
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

  /// Delete orphaned platform receivables (from deleted sellers)
  static Future<int> deleteOrphanedPlatformReceivables(List<Map<String, dynamic>> orphanedReceivables) async {
    int deletedCount = 0;
    
    try {
      for (final item in orphanedReceivables) {
        final sellerId = item['sellerId'] as String;
        final totalOwed = item['totalOwed'] as double;
        
        print('🗑️ Deleting orphaned receivables for deleted seller $sellerId (Total: R${totalOwed.toStringAsFixed(2)})');
        
        // Delete all entries in the subcollection first
        final entriesSnapshot = await _firestore
            .collection('platform_receivables')
            .doc(sellerId)
            .collection('entries')
            .get();
            
        final batch = _firestore.batch();
        for (final entryDoc in entriesSnapshot.docs) {
          batch.delete(entryDoc.reference);
        }
        
        // Delete the main receivables document
        batch.delete(_firestore.collection('platform_receivables').doc(sellerId));
        
        await batch.commit();
        deletedCount++;
        
        print('✅ Deleted orphaned receivables for seller $sellerId');
      }
      
      if (deletedCount > 0) {
        print('🗑️ Deleted $deletedCount orphaned platform receivables');
      }
    } catch (e) {
      print('❌ Error deleting orphaned platform receivables: $e');
      deletedCount = 0;
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
          case 'chatbot_conversations':
            docId = item['conversationId'] as String;
            // Also delete messages subcollection
            final messagesSnapshot = await _firestore
                .collection('chatbot_conversations')
                .doc(docId)
                .collection('messages')
                .get();
            for (final messageDoc in messagesSnapshot.docs) {
              batch.delete(messageDoc.reference);
            }
            break;
          case 'notifications':
            docId = item['notificationId'] as String;
            break;
          case 'fcm_tokens':
            docId = item['tokenId'] as String;
            break;
          case 'platform_receivables':
            // Handle platform receivables separately due to subcollections
            return await deleteOrphanedPlatformReceivables(orphanedItems);
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
}

class CleanupToolsSection extends StatefulWidget {
  const CleanupToolsSection({Key? key}) : super(key: key);

  @override
  State<CleanupToolsSection> createState() => _CleanupToolsSectionState();
}

class _CleanupToolsSectionState extends State<CleanupToolsSection> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isScanning = false;
  bool _isCleaningUp = false;
  Map<String, List<Map<String, dynamic>>> _orphanedData = {};
  Map<String, dynamic> _imageStats = {};
  Map<String, int> _cleanupResults = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Cleanup Tools'),
          const SizedBox(height: 24),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // Tab Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF1565C0),
                    unselectedLabelColor: Colors.grey[600],
                    indicator: const UnderlineTabIndicator(
                      borderSide: BorderSide(width: 3, color: Color(0xFF1565C0)),
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.search),
                        text: 'Data Cleanup',
                      ),
                      Tab(
                        icon: Icon(Icons.image_not_supported),
                        text: 'Image Cleanup',
                      ),
                    ],
                  ),
                ),
                
                // Tab Content
                SizedBox(
                  height: 800,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDataCleanupTab(),
                      _buildImageCleanupTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCleanupTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with scan button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Database Cleanup',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Find and remove orphaned data in your Firestore database',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isScanning ? null : _scanForOrphanedData,
                    icon: _isScanning 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isScanning ? 'Scanning...' : 'Scan Database'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_orphanedData.isNotEmpty && !_isScanning)
                    ElevatedButton.icon(
                      onPressed: _isCleaningUp ? null : _cleanupOrphanedData,
                      icon: _isCleaningUp
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cleaning_services),
                      label: Text(_isCleaningUp ? 'Cleaning...' : 'Clean Up'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Results section
          if (_orphanedData.isNotEmpty) ...[
            _buildOrphanedDataResults(),
          ] else if (_cleanupResults.isNotEmpty) ...[
            _buildCleanupResults(),
          ] else ...[
            _buildEmptyState(),
          ],
        ],
      ),
    );
  }

  Widget _buildImageCleanupTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Image & Media Cleanup',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage orphaned images and media files in ImageKit storage',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _getImageStats,
                    icon: const Icon(Icons.analytics),
                    label: const Text('Get Stats'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _cleanupOrphanedImages,
                    icon: const Icon(Icons.cleaning_services),
                    label: const Text('Cleanup Images'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Image stats
          if (_imageStats.isNotEmpty) ...[
            _buildImageStats(),
          ] else ...[
            _buildEmptyImageState(),
          ],
        ],
      ),
    );
  }

  Widget _buildOrphanedDataResults() {
    final totalOrphaned = _orphanedData.values
        .map((list) => list.length)
        .reduce((a, b) => a + b);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Found $totalOrphaned orphaned records',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'These records reference users, products, or other entities that no longer exist.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Detailed results
          Expanded(
            child: ListView(
              children: _orphanedData.entries
                  .where((entry) => entry.value.isNotEmpty)
                  .map((entry) => _buildOrphanedDataCard(entry.key, entry.value))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrphanedDataCard(String type, List<Map<String, dynamic>> items) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Icon(_getIconForDataType(type), color: Colors.red),
        title: Text(
          '${_getDisplayName(type)} (${items.length} orphaned)',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.take(5).map((item) => 
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatItemDisplay(type, item),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              ).toList(),
            ),
          ),
          if (items.length > 5)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '... and ${items.length - 5} more',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCleanupResults() {
    final totalDeleted = _cleanupResults.values.reduce((a, b) => a + b);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 16),
          Text(
            'Cleanup Complete!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Successfully deleted $totalDeleted orphaned records',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ..._cleanupResults.entries.map((entry) =>
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_getDisplayName(entry.key)),
                  Text(
                    '${entry.value} deleted',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Click "Scan Database" to find orphaned data',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will check for data that references missing users, products, etc.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildImageStatCard(
                'Total Images',
                _imageStats['totalImages']?.toString() ?? '0',
                Icons.image,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildImageStatCard(
                'Total Size',
                _imageStats['totalSizeMB']?.toString() ?? '0',
                Icons.storage,
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyImageState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Click "Get Stats" to view image storage information',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForDataType(String type) {
    switch (type) {
      case 'chats':
        return Icons.chat;
      case 'chatbot_conversations':
        return Icons.smart_toy;
      case 'notifications':
        return Icons.notifications;
      case 'fcm_tokens':
        return Icons.token;
      default:
        return Icons.data_object;
    }
  }

  String _getDisplayName(String type) {
    switch (type) {
      case 'chats':
        return 'Chat Conversations';
      case 'chatbot_conversations':
        return 'Chatbot Conversations';
      case 'notifications':
        return 'Notifications';
      case 'fcm_tokens':
        return 'FCM Tokens';
      case 'orphanedProducts':
        return 'Product Images';
      case 'orphanedProfiles':
        return 'Profile Images';
      case 'orphanedStores':
        return 'Store Images';
      case 'orphanedChats':
        return 'Chat Images';
      default:
        return type;
    }
  }

  String _formatItemDisplay(String type, Map<String, dynamic> item) {
    switch (type) {
      case 'chats':
        return 'Chat ${item['chatId']} - Missing: ${item['missingBuyer'] ? 'Buyer ' : ''}${item['missingSeller'] ? 'Seller' : ''}';
      case 'chatbot_conversations':
        return 'Conversation ${item['conversationId']} - User: ${item['userId']}';
      case 'notifications':
        return 'Notification ${item['notificationId']} - User: ${item['userId']}';
      case 'fcm_tokens':
        return 'Token ${item['tokenId']} - User: ${item['userId']}';
      default:
        return item.toString();
    }
  }

  Future<void> _scanForOrphanedData() async {
    setState(() {
      _isScanning = true;
      _orphanedData.clear();
      _cleanupResults.clear();
    });

    try {
      final results = await DataCleanupService.findAllOrphanedData();
      setState(() {
        _orphanedData = results;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan complete! Found ${results.values.map((list) => list.length).reduce((a, b) => a + b)} orphaned records'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during scan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _cleanupOrphanedData() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Cleanup'),
        content: const Text(
          'This will permanently delete all orphaned data. This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isCleaningUp = true;
    });

    try {
      final results = <String, int>{};
      
      // Delete orphaned chats
      if (_orphanedData['chats']?.isNotEmpty == true) {
        results['chats'] = await DataCleanupService.deleteOrphanedChats(_orphanedData['chats']!);
      }
      
      // Delete other orphaned data
      for (final entry in _orphanedData.entries) {
        if (entry.key != 'chats' && entry.value.isNotEmpty) {
          results[entry.key] = await DataCleanupService.deleteOrphanedData(entry.key, entry.value);
        }
      }
      
      setState(() {
        _cleanupResults = results;
        _orphanedData.clear();
      });
      
      final totalDeleted = results.values.reduce((a, b) => a + b);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cleanup complete! Deleted $totalDeleted orphaned records'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during cleanup: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isCleaningUp = false;
      });
    }
  }

  Future<void> _getImageStats() async {
    try {
      final stats = await ImageCleanupService.getStorageStats();
      setState(() {
        _imageStats = stats;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image stats loaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading image stats: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cleanupOrphanedImages() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Image Cleanup'),
        content: const Text(
          'This will permanently delete all orphaned images from ImageKit storage. This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final results = await ImageCleanupService.cleanupOrphanedImages();
      
      final totalDeleted = results.values.reduce((a, b) => a + b);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image cleanup complete! Deleted $totalDeleted orphaned images'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh stats
      await _getImageStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during image cleanup: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
