#!/usr/bin/env node

/**
 * Orphaned Data Cleanup Script
 * 
 * This script finds and cleans up orphaned data in Firebase Firestore.
 * Run with --dry-run to see what would be deleted without actually deleting.
 * 
 * Usage:
 *   node cleanup_orphaned_data.js --dry-run    # Preview what would be deleted
 *   node cleanup_orphaned_data.js --execute    # Actually delete orphaned data
 *   node cleanup_orphaned_data.js --stats      # Show database statistics
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  try {
    admin.initializeApp({
      credential: admin.credential.cert('./serviceAccountKey.json'),
    });
  } catch (error) {
    console.error('❌ Failed to initialize Firebase Admin:', error.message);
    process.exit(1);
  }
}

const db = admin.firestore();

class OrphanedDataCleanup {
  constructor() {
    this.dryRun = true;
    this.results = {};
  }

  /**
   * Get all valid user IDs from the users collection
   */
  async getValidUserIds() {
    const usersSnapshot = await db.collection('users').get();
    return new Set(usersSnapshot.docs.map(doc => doc.id));
  }

  /**
   * Get all valid product IDs from the products collection
   */
  async getValidProductIds() {
    const productsSnapshot = await db.collection('products').get();
    return new Set(productsSnapshot.docs.map(doc => doc.id));
  }

  /**
   * Find orphaned chats (where buyer or seller no longer exists)
   */
  async findOrphanedChats(validUserIds) {
    console.log('🔍 Finding orphaned chats...');
    
    const chatsSnapshot = await db.collection('chats').get();
    const orphanedChats = [];
    
    for (const chatDoc of chatsSnapshot.docs) {
      const chatData = chatDoc.data();
      const buyerId = chatData.buyerId;
      const sellerId = chatData.sellerId;
      
      const missingBuyer = buyerId && !validUserIds.has(buyerId);
      const missingSeller = sellerId && !validUserIds.has(sellerId);
      
      if (missingBuyer || missingSeller) {
        orphanedChats.push({
          chatId: chatDoc.id,
          buyerId,
          sellerId,
          productId: chatData.productId,
          missingBuyer,
          missingSeller,
          lastMessage: chatData.lastMessage,
          timestamp: chatData.timestamp
        });
      }
    }
    
    console.log(`📊 Found ${orphanedChats.length} orphaned chats`);
    return orphanedChats;
  }

  /**
   * Find orphaned chatbot conversations
   */
  async findOrphanedChatbotConversations(validUserIds) {
    console.log('🔍 Finding orphaned chatbot conversations...');
    
    const conversationsSnapshot = await db.collection('chatbot_conversations').get();
    const orphanedConversations = [];
    
    for (const conversationDoc of conversationsSnapshot.docs) {
      const conversationData = conversationDoc.data();
      const userId = conversationData.userId;
      
      if (userId && !validUserIds.has(userId)) {
        orphanedConversations.push({
          conversationId: conversationDoc.id,
          userId,
          userEmail: conversationData.userEmail,
          messageCount: conversationData.messageCount || 0,
          createdAt: conversationData.createdAt
        });
      }
    }
    
    console.log(`📊 Found ${orphanedConversations.length} orphaned chatbot conversations`);
    return orphanedConversations;
  }

  /**
   * Find orphaned orders
   */
  async findOrphanedOrders(validUserIds, validProductIds) {
    console.log('🔍 Finding orphaned orders...');
    
    const ordersSnapshot = await db.collection('orders').get();
    const orphanedOrders = [];
    
    for (const orderDoc of ordersSnapshot.docs) {
      const orderData = orderDoc.data();
      const buyerId = orderData.buyerId;
      const sellerId = orderData.sellerId;
      const productId = orderData.productId;
      
      const issues = [];
      if (buyerId && !validUserIds.has(buyerId)) {
        issues.push(`Missing buyer: ${buyerId}`);
      }
      if (sellerId && !validUserIds.has(sellerId)) {
        issues.push(`Missing seller: ${sellerId}`);
      }
      if (productId && !validProductIds.has(productId)) {
        issues.push(`Missing product: ${productId}`);
      }
      
      if (issues.length > 0) {
        orphanedOrders.push({
          orderId: orderDoc.id,
          buyerId,
          sellerId,
          productId,
          issues,
          totalAmount: orderData.totalAmount,
          status: orderData.status,
          createdAt: orderData.createdAt
        });
      }
    }
    
    console.log(`📊 Found ${orphanedOrders.length} orphaned orders`);
    return orphanedOrders;
  }

  /**
   * Find orphaned reviews
   */
  async findOrphanedReviews(validUserIds, validProductIds) {
    console.log('🔍 Finding orphaned reviews...');
    
    const reviewsSnapshot = await db.collection('reviews').get();
    const orphanedReviews = [];
    
    for (const reviewDoc of reviewsSnapshot.docs) {
      const reviewData = reviewDoc.data();
      const userId = reviewData.userId;
      const storeId = reviewData.storeId;
      const productId = reviewData.productId;
      
      const issues = [];
      if (userId && !validUserIds.has(userId)) {
        issues.push(`Missing reviewer: ${userId}`);
      }
      if (storeId && !validUserIds.has(storeId)) {
        issues.push(`Missing store owner: ${storeId}`);
      }
      if (productId && !validProductIds.has(productId)) {
        issues.push(`Missing product: ${productId}`);
      }
      
      if (issues.length > 0) {
        orphanedReviews.push({
          reviewId: reviewDoc.id,
          userId,
          storeId,
          productId,
          issues,
          rating: reviewData.rating,
          comment: reviewData.comment,
          timestamp: reviewData.timestamp
        });
      }
    }
    
    console.log(`📊 Found ${orphanedReviews.length} orphaned reviews`);
    return orphanedReviews;
  }

  /**
   * Find orphaned notifications
   */
  async findOrphanedNotifications(validUserIds) {
    console.log('🔍 Finding orphaned notifications...');
    
    const notificationsSnapshot = await db.collection('notifications').get();
    const orphanedNotifications = [];
    
    for (const notificationDoc of notificationsSnapshot.docs) {
      const notificationData = notificationDoc.data();
      const userId = notificationData.userId;
      
      if (userId && !validUserIds.has(userId)) {
        orphanedNotifications.push({
          notificationId: notificationDoc.id,
          userId,
          title: notificationData.title,
          body: notificationData.body,
          type: notificationData.type,
          timestamp: notificationData.timestamp
        });
      }
    }
    
    console.log(`📊 Found ${orphanedNotifications.length} orphaned notifications`);
    return orphanedNotifications;
  }

  /**
   * Find orphaned FCM tokens
   */
  async findOrphanedFcmTokens(validUserIds) {
    console.log('🔍 Finding orphaned FCM tokens...');
    
    const tokensSnapshot = await db.collection('fcm_tokens').get();
    const orphanedTokens = [];
    
    for (const tokenDoc of tokensSnapshot.docs) {
      const tokenData = tokenDoc.data();
      const userId = tokenData.userId;
      
      if (userId && !validUserIds.has(userId)) {
        orphanedTokens.push({
          tokenId: tokenDoc.id,
          userId,
          token: tokenData.token,
          platform: tokenData.platform,
          createdAt: tokenData.createdAt
        });
      }
    }
    
    console.log(`📊 Found ${orphanedTokens.length} orphaned FCM tokens`);
    return orphanedTokens;
  }

  /**
   * Find orphaned products
   */
  async findOrphanedProducts(validUserIds) {
    console.log('🔍 Finding orphaned products...');
    
    const productsSnapshot = await db.collection('products').get();
    const orphanedProducts = [];
    
    for (const productDoc of productsSnapshot.docs) {
      const productData = productDoc.data();
      const ownerId = productData.ownerId;
      
      if (ownerId && !validUserIds.has(ownerId)) {
        orphanedProducts.push({
          productId: productDoc.id,
          ownerId,
          name: productData.name,
          category: productData.category,
          price: productData.price,
          createdAt: productData.createdAt
        });
      }
    }
    
    console.log(`📊 Found ${orphanedProducts.length} orphaned products`);
    return orphanedProducts;
  }

  /**
   * Find orphaned platform receivables
   */
  async findOrphanedPlatformReceivables(validUserIds) {
    console.log('🔍 Finding orphaned platform receivables...');
    
    const receivablesSnapshot = await db.collection('platform_receivables').get();
    const orphanedReceivables = [];
    
    for (const receivableDoc of receivablesSnapshot.docs) {
      const receivableData = receivableDoc.data();
      const sellerId = receivableDoc.id; // Document ID is the seller ID
      
      if (sellerId && !validUserIds.has(sellerId)) {
        orphanedReceivables.push({
          receivableId: receivableDoc.id,
          sellerId,
          amount: receivableData.amount,
          type: receivableData.type,
          createdAt: receivableData.createdAt
        });
      }
    }
    
    console.log(`📊 Found ${orphanedReceivables.length} orphaned platform receivables`);
    return orphanedReceivables;
  }

  /**
   * Find orphaned payouts
   */
  async findOrphanedPayouts(validUserIds) {
    console.log('🔍 Finding orphaned payouts...');
    
    const payoutsSnapshot = await db.collection('payouts').get();
    const orphanedPayouts = [];
    
    for (const payoutDoc of payoutsSnapshot.docs) {
      const payoutData = payoutDoc.data();
      const sellerId = payoutData.sellerId;
      
      if (sellerId && !validUserIds.has(sellerId)) {
        orphanedPayouts.push({
          payoutId: payoutDoc.id,
          sellerId,
          amount: payoutData.amount,
          status: payoutData.status,
          failureReason: payoutData.failureReason,
          createdAt: payoutData.createdAt
        });
      }
    }
    
    console.log(`📊 Found ${orphanedPayouts.length} orphaned payouts`);
    return orphanedPayouts;
  }

  /**
   * Find orphaned settlements
   */
  async findOrphanedSettlements(validUserIds) {
    console.log('🔍 Finding orphaned settlements...');
    
    const settlementsSnapshot = await db.collection('settlements').get();
    const orphanedSettlements = [];
    
    for (const settlementDoc of settlementsSnapshot.docs) {
      const settlementData = settlementDoc.data();
      const sellerId = settlementData.sellerId;
      const buyerId = settlementData.buyerId;
      
      const missingSeller = sellerId && !validUserIds.has(sellerId);
      const missingBuyer = buyerId && !validUserIds.has(buyerId);
      
      if (missingSeller || missingBuyer) {
        orphanedSettlements.push({
          settlementId: settlementDoc.id,
          sellerId,
          buyerId,
          amount: settlementData.amount,
          status: settlementData.status,
          missingSeller,
          missingBuyer,
          createdAt: settlementData.createdAt
        });
      }
    }
    
    console.log(`📊 Found ${orphanedSettlements.length} orphaned settlements`);
    return orphanedSettlements;
  }

  /**
   * Find orphaned entries
   */
  async findOrphanedEntries(validUserIds) {
    console.log('🔍 Finding orphaned entries...');
    
    const entriesSnapshot = await db.collection('entries').get();
    const orphanedEntries = [];
    
    for (const entryDoc of entriesSnapshot.docs) {
      const entryData = entryDoc.data();
      const ownerId = entryData.ownerId;
      
      if (ownerId && !validUserIds.has(ownerId)) {
        orphanedEntries.push({
          entryId: entryDoc.id,
          ownerId,
          type: entryData.type,
          amount: entryData.amount,
          description: entryData.description,
          createdAt: entryData.createdAt
        });
      }
    }
    
    console.log(`📊 Found ${orphanedEntries.length} orphaned entries`);
    return orphanedEntries;
  }

  /**
   * Find orphaned returns
   */
  async findOrphanedReturns(validUserIds) {
    console.log('🔍 Finding orphaned returns...');
    
    const returnsSnapshot = await db.collection('returns').get();
    const orphanedReturns = [];
    
    for (const returnDoc of returnsSnapshot.docs) {
      const returnData = returnDoc.data();
      const sellerId = returnData.sellerId;
      
      if (sellerId && !validUserIds.has(sellerId)) {
        orphanedReturns.push({
          returnId: returnDoc.id,
          sellerId,
          orderId: returnData.orderId,
          reason: returnData.reason,
          status: returnData.status,
          createdAt: returnData.createdAt
        });
      }
    }
    
    console.log(`📊 Found ${orphanedReturns.length} orphaned returns`);
    return orphanedReturns;
  }

  /**
   * Find orphaned KYC submissions
   */
  async findOrphanedKycSubmissions(validUserIds) {
    console.log('🔍 Finding orphaned KYC submissions...');
    
    const kycSnapshot = await db.collection('kyc_submissions').get();
    const orphanedKyc = [];
    
    for (const kycDoc of kycSnapshot.docs) {
      const kycData = kycDoc.data();
      const userId = kycData.userId;
      
      if (userId && !validUserIds.has(userId)) {
        orphanedKyc.push({
          kycId: kycDoc.id,
          userId,
          status: kycData.status,
          documentType: kycData.documentType,
          createdAt: kycData.createdAt
        });
      }
    }
    
    console.log(`📊 Found ${orphanedKyc.length} orphaned KYC submissions`);
    return orphanedKyc;
  }

  /**
   * Delete orphaned chats and their messages in batches
   */
  async deleteOrphanedChats(orphanedChats) {
    if (this.dryRun) return orphanedChats.length;
    
    let deletedCount = 0;
    const batchSize = 500; // Firestore batch limit
    
    for (const chat of orphanedChats) {
      try {
        // Get all messages for this chat
        const messagesSnapshot = await db
          .collection('chats')
          .doc(chat.chatId)
          .collection('messages')
          .get();
        
        // Delete messages in batches
        for (let i = 0; i < messagesSnapshot.docs.length; i += batchSize) {
          const batch = db.batch();
          const batchDocs = messagesSnapshot.docs.slice(i, i + batchSize);
          
          batchDocs.forEach(doc => {
            batch.delete(doc.ref);
          });
          
          await batch.commit();
        }
        
        // Delete the chat document
        await db.collection('chats').doc(chat.chatId).delete();
        deletedCount++;
        
        console.log(`🗑️ Deleted orphaned chat: ${chat.chatId} (${messagesSnapshot.docs.length} messages)`);
      } catch (error) {
        console.error(`❌ Error deleting chat ${chat.chatId}:`, error.message);
      }
    }
    
    return deletedCount;
  }

  /**
   * Delete orphaned chatbot conversations and their messages in batches
   */
  async deleteOrphanedChatbotConversations(orphanedConversations) {
    if (this.dryRun) return orphanedConversations.length;
    
    let deletedCount = 0;
    const batchSize = 500;
    
    for (const conversation of orphanedConversations) {
      try {
        // Get all messages for this conversation
        const messagesSnapshot = await db
          .collection('chatbot_conversations')
          .doc(conversation.conversationId)
          .collection('messages')
          .get();
        
        // Delete messages in batches
        for (let i = 0; i < messagesSnapshot.docs.length; i += batchSize) {
          const batch = db.batch();
          const batchDocs = messagesSnapshot.docs.slice(i, i + batchSize);
          
          batchDocs.forEach(doc => {
            batch.delete(doc.ref);
          });
          
          await batch.commit();
        }
        
        // Delete the conversation document
        await db.collection('chatbot_conversations').doc(conversation.conversationId).delete();
        deletedCount++;
        
        console.log(`🗑️ Deleted orphaned chatbot conversation: ${conversation.conversationId} (${messagesSnapshot.docs.length} messages)`);
      } catch (error) {
        console.error(`❌ Error deleting conversation ${conversation.conversationId}:`, error.message);
      }
    }
    
    return deletedCount;
  }

  /**
   * Delete orphaned documents from a collection in batches
   */
  async deleteOrphanedDocuments(collectionName, orphanedItems, idField) {
    if (this.dryRun) return orphanedItems.length;
    
    let deletedCount = 0;
    const batchSize = 500;
    
    for (let i = 0; i < orphanedItems.length; i += batchSize) {
      const batch = db.batch();
      const batchItems = orphanedItems.slice(i, i + batchSize);
      
      batchItems.forEach(item => {
        const docRef = db.collection(collectionName).doc(item[idField]);
        batch.delete(docRef);
      });
      
      try {
        await batch.commit();
        deletedCount += batchItems.length;
        console.log(`🗑️ Deleted ${batchItems.length} orphaned ${collectionName} (batch ${Math.floor(i / batchSize) + 1})`);
      } catch (error) {
        console.error(`❌ Error deleting batch from ${collectionName}:`, error.message);
      }
    }
    
    return deletedCount;
  }

  /**
   * Scan for all types of orphaned data
   */
  async scanOrphanedData() {
    console.log('🧹 Starting comprehensive orphaned data scan...');
    
    try {
      // Get reference data
      const validUserIds = await this.getValidUserIds();
      const validProductIds = await this.getValidProductIds();
      
      console.log(`📊 Found ${validUserIds.size} valid users and ${validProductIds.size} valid products`);
      
      // Find orphaned data
      const orphanedData = {
        chats: await this.findOrphanedChats(validUserIds),
        chatbot_conversations: await this.findOrphanedChatbotConversations(validUserIds),
        orders: await this.findOrphanedOrders(validUserIds, validProductIds),
        reviews: await this.findOrphanedReviews(validUserIds, validProductIds),
        notifications: await this.findOrphanedNotifications(validUserIds),
        fcm_tokens: await this.findOrphanedFcmTokens(validUserIds),
        products: await this.findOrphanedProducts(validUserIds),
        platform_receivables: await this.findOrphanedPlatformReceivables(validUserIds),
        payouts: await this.findOrphanedPayouts(validUserIds),
        settlements: await this.findOrphanedSettlements(validUserIds),
        entries: await this.findOrphanedEntries(validUserIds),
        returns: await this.findOrphanedReturns(validUserIds),
        kyc_submissions: await this.findOrphanedKycSubmissions(validUserIds)
      };
      
      // Calculate totals
      const totalOrphaned = Object.values(orphanedData).reduce((sum, items) => sum + items.length, 0);
      
      console.log('\n📊 ORPHANED DATA SUMMARY:');
      Object.entries(orphanedData).forEach(([collection, items]) => {
        if (items.length > 0) {
          console.log(`  - ${collection}: ${items.length} orphaned records`);
        }
      });
      console.log(`  - TOTAL: ${totalOrphaned} orphaned records\n`);
      
      return orphanedData;
    } catch (error) {
      console.error('❌ Error during scan:', error.message);
      throw error;
    }
  }

  /**
   * Delete all orphaned data
   */
  async cleanupOrphanedData() {
    console.log(`🧹 Starting ${this.dryRun ? 'DRY RUN' : 'LIVE'} comprehensive cleanup...`);
    
    if (this.dryRun) {
      console.log('⚠️ DRY RUN MODE - No data will actually be deleted\n');
    }
    
    try {
      // Find all orphaned data
      const orphanedData = await this.scanOrphanedData();
      
      if (this.dryRun) {
        console.log('✅ Dry run complete. Run with --execute to actually delete the data.');
        return;
      }
      
      // Delete orphaned data
      console.log('🗑️ Starting deletion process...\n');
      
      this.results.chats = await this.deleteOrphanedChats(orphanedData.chats);
      this.results.chatbot_conversations = await this.deleteOrphanedChatbotConversations(orphanedData.chatbot_conversations);
      this.results.orders = await this.deleteOrphanedDocuments('orders', orphanedData.orders, 'orderId');
      this.results.reviews = await this.deleteOrphanedDocuments('reviews', orphanedData.reviews, 'reviewId');
      this.results.notifications = await this.deleteOrphanedDocuments('notifications', orphanedData.notifications, 'notificationId');
      this.results.fcm_tokens = await this.deleteOrphanedDocuments('fcm_tokens', orphanedData.fcm_tokens, 'tokenId');
      this.results.products = await this.deleteOrphanedDocuments('products', orphanedData.products, 'productId');
      this.results.platform_receivables = await this.deleteOrphanedDocuments('platform_receivables', orphanedData.platform_receivables, 'receivableId');
      this.results.payouts = await this.deleteOrphanedDocuments('payouts', orphanedData.payouts, 'payoutId');
      this.results.settlements = await this.deleteOrphanedDocuments('settlements', orphanedData.settlements, 'settlementId');
      this.results.entries = await this.deleteOrphanedDocuments('entries', orphanedData.entries, 'entryId');
      this.results.returns = await this.deleteOrphanedDocuments('returns', orphanedData.returns, 'returnId');
      this.results.kyc_submissions = await this.deleteOrphanedDocuments('kyc_submissions', orphanedData.kyc_submissions, 'kycId');
      
      const totalDeleted = Object.values(this.results).reduce((sum, count) => sum + count, 0);
      
      console.log('\n✅ CLEANUP COMPLETE!');
      console.log('📊 DELETION SUMMARY:');
      Object.entries(this.results).forEach(([collection, count]) => {
        if (count > 0) {
          console.log(`  - ${collection}: ${count} deleted`);
        }
      });
      console.log(`  - TOTAL: ${totalDeleted} records deleted\n`);
      
    } catch (error) {
      console.error('❌ Error during cleanup:', error.message);
      throw error;
    }
  }

  /**
   * Get database statistics
   */
  async getDataStats() {
    console.log('📊 Calculating database statistics...');
    
    try {
      const collections = ['users', 'products', 'chats', 'orders', 'reviews', 'notifications', 'fcm_tokens', 'chatbot_conversations', 'platform_receivables', 'payouts', 'settlements', 'entries', 'returns', 'kyc_submissions'];
      const stats = {};
      
      for (const collection of collections) {
        const snapshot = await db.collection(collection).get();
        stats[collection] = {
          totalDocuments: snapshot.docs.length,
          sizeEstimate: snapshot.docs.length * 200 // Rough estimate in bytes
        };
      }
      
      // Count subcollection documents
      const chatsSnapshot = await db.collection('chats').get();
      let totalChatMessages = 0;
      for (const chatDoc of chatsSnapshot.docs) {
        const messagesSnapshot = await chatDoc.ref.collection('messages').get();
        totalChatMessages += messagesSnapshot.docs.length;
      }
      stats.chat_messages = {
        totalDocuments: totalChatMessages,
        sizeEstimate: totalChatMessages * 200
      };
      
      const conversationsSnapshot = await db.collection('chatbot_conversations').get();
      let totalChatbotMessages = 0;
      for (const conversationDoc of conversationsSnapshot.docs) {
        const messagesSnapshot = await conversationDoc.ref.collection('messages').get();
        totalChatbotMessages += messagesSnapshot.docs.length;
      }
      stats.chatbot_messages = {
        totalDocuments: totalChatbotMessages,
        sizeEstimate: totalChatbotMessages * 200
      };
      
      console.log('\n📊 DATABASE STATISTICS:');
      Object.entries(stats).forEach(([collection, data]) => {
        console.log(`  - ${collection}: ${data.totalDocuments} documents (~${(data.sizeEstimate / 1024).toFixed(1)}KB)`);
      });
      
      const totalDocs = Object.values(stats).reduce((sum, data) => sum + data.totalDocuments, 0);
      const totalSize = Object.values(stats).reduce((sum, data) => sum + data.sizeEstimate, 0);
      console.log(`  - TOTAL: ${totalDocs} documents (~${(totalSize / 1024 / 1024).toFixed(2)}MB)\n`);
      
      return stats;
    } catch (error) {
      console.error('❌ Error calculating stats:', error.message);
      throw error;
    }
  }
}

// Main execution
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log(`
🧹 Orphaned Data Cleanup Script

Usage:
  node cleanup_orphaned_data.js --dry-run    # Preview what would be deleted
  node cleanup_orphaned_data.js --execute    # Actually delete orphaned data
  node cleanup_orphaned_data.js --stats      # Show database statistics

Examples:
  node cleanup_orphaned_data.js --dry-run
  node cleanup_orphaned_data.js --execute
  node cleanup_orphaned_data.js --stats
    `);
    process.exit(0);
  }
  
  const cleanup = new OrphanedDataCleanup();
  
  try {
    if (args.includes('--stats')) {
      await cleanup.getDataStats();
    } else if (args.includes('--execute')) {
      cleanup.dryRun = false;
      await cleanup.cleanupOrphanedData();
    } else if (args.includes('--dry-run')) {
      cleanup.dryRun = true;
      await cleanup.cleanupOrphanedData();
    } else {
      console.log('❌ Invalid argument. Use --dry-run, --execute, or --stats');
      process.exit(1);
    }
  } catch (error) {
    console.error('❌ Script failed:', error.message);
    process.exit(1);
  }
}

// Run the script
if (require.main === module) {
  main();
}

module.exports = OrphanedDataCleanup;
