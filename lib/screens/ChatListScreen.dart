import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/home_navigation_button.dart';
import '../screens/ChatScreen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Show search dialog for chats
  void _showSearchDialog() {
    final TextEditingController searchController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Search Chats'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  hintText: 'Enter search term...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  _searchChats(value);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _searchChats(searchController.text);
                Navigator.of(context).pop();
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  // Search chats
  void _searchChats(String searchTerm) {
    if (searchTerm.trim().isEmpty) return;
    
    // Navigate to search results or show results in a dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Search Results for "$searchTerm"'),
          content: FutureBuilder<List<QuerySnapshot>>(
            future: Future.wait([
              FirebaseFirestore.instance
                  .collection('chats')
                  .where('buyerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .where('lastMessage', isGreaterThanOrEqualTo: searchTerm)
                  .where('lastMessage', isLessThan: searchTerm + '\uf8ff')
                  .get(),
              FirebaseFirestore.instance
                  .collection('chats')
                  .where('sellerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .where('lastMessage', isGreaterThanOrEqualTo: searchTerm)
                  .where('lastMessage', isLessThan: searchTerm + '\uf8ff')
                  .get(),
            ]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData) {
                return const Text('No chats found.');
              }
              
              final buyerChats = snapshot.data![0].docs;
              final sellerChats = snapshot.data![1].docs;
              final allChats = [...buyerChats, ...sellerChats];
              
              if (allChats.isEmpty) {
                return const Text('No chats found matching your search.');
              }
              
              return SizedBox(
                height: 300,
                width: double.maxFinite,
                child: ListView.builder(
                  itemCount: allChats.length,
                  itemBuilder: (context, index) {
                    final chat = allChats[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(chat['lastMessage'] ?? 'No message'),
                      subtitle: Text(
                        chat['timestamp'] != null 
                            ? (chat['timestamp'] as Timestamp).toDate().toString()
                            : 'Unknown time',
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        // Navigate to the chat
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              chatId: allChats[index].id,
                              otherUserId: chat['buyerId'] == FirebaseAuth.instance.currentUser?.uid 
                                  ? chat['sellerId'] 
                                  : chat['buyerId'],
                              otherUserName: chat['buyerId'] == FirebaseAuth.instance.currentUser?.uid 
                                  ? 'Seller' 
                                  : 'Buyer',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: AppTheme.whisper,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.deepTeal.withOpacity(0.1),
                AppTheme.whisper,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.cardBackgroundGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.complementaryElevation,
                  ),
                  child: Icon(
                    Icons.login,
                    size: 64,
                    color: AppTheme.deepTeal,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Please log in to see your chats',
                  style: TextStyle(
                    color: AppTheme.darkGrey,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.whisper,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.deepTeal.withOpacity(0.1),
              AppTheme.whisper,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Enhanced Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.deepTeal, AppTheme.cloud],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.deepTeal.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const HomeNavigationButton(
                      backgroundColor: Colors.transparent,
                      iconColor: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Chats',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Connect with buyers and sellers',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        _showSearchDialog();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Chat List
              Expanded(
                child: StreamBuilder<List<QuerySnapshot>>(
                  stream: Stream.fromFuture(Future.wait([
                    FirebaseFirestore.instance
                        .collection('chats')
                        .where('buyerId', isEqualTo: currentUserId)
                        .orderBy('timestamp', descending: true)
                        .get(),
                    FirebaseFirestore.instance
                        .collection('chats')
                        .where('sellerId', isEqualTo: currentUserId)
                        .orderBy('timestamp', descending: true)
                        .get(),
                  ])),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              gradient: AppTheme.cardBackgroundGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: AppTheme.complementaryElevation,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: AppTheme.cloud,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading chats',
                                  style: TextStyle(
                                    color: AppTheme.darkGrey,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please try again later',
                                  style: TextStyle(
                                    color: AppTheme.mediumGrey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    
                    if (!snapshot.hasData) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              gradient: AppTheme.cardBackgroundGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: AppTheme.complementaryElevation,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: AppTheme.deepTeal,
                                  strokeWidth: 3,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Loading chats...',
                                  style: TextStyle(
                                    color: AppTheme.darkGrey,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    // Combine buyer and seller chats
                    final buyerChats = snapshot.data![0].docs;
                    final sellerChats = snapshot.data![1].docs;
                    final chats = [...buyerChats, ...sellerChats];
                    
                    // Sort by last updated
                    chats.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aTime = aData['timestamp'] as Timestamp?;
                      final bTime = bData['timestamp'] as Timestamp?;
                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      return bTime.compareTo(aTime);
                    });
                    
                    if (chats.isEmpty) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              gradient: AppTheme.cardBackgroundGradient,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: AppTheme.complementaryElevation,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppTheme.deepTeal.withOpacity(0.1), AppTheme.cloud.withOpacity(0.1)],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    Icons.chat_bubble_outline,
                                    size: 64,
                                    color: AppTheme.deepTeal,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'No chats yet',
                                  style: TextStyle(
                                    color: AppTheme.darkGrey,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Start a conversation with a seller',
                                  style: TextStyle(
                                    color: AppTheme.mediumGrey,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppTheme.deepTeal, AppTheme.cloud],
                                    ),
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Text(
                                    'Explore Stores',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return SlideTransition(
                      position: _slideAnimation,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: chats.length,
                        itemBuilder: (context, index) {
                          final data = chats[index].data() as Map<String, dynamic>;
                          final chatId = chats[index].id;
                          final lastMessage = data['lastMessage'] ?? '';
                          final timestamp = data['timestamp'] as Timestamp?;
                          final productName = data['productName'] ?? 'Product';
                          final isUnread = data['unreadCount'] != null && data['unreadCount'] > 0;
                          final isBuyer = data['buyerId'] == currentUserId;
                          final buyerName = data['buyerName'] ?? '';
                          final buyerNumber = data['buyerNumber'] ?? '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              gradient: isUnread 
                                ? LinearGradient(
                                    colors: [Colors.white, AppTheme.deepTeal.withOpacity(0.05)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : AppTheme.cardBackgroundGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: isUnread 
                                    ? AppTheme.deepTeal.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                              border: isUnread 
                                ? Border.all(color: AppTheme.deepTeal.withOpacity(0.2), width: 1)
                                : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        chatId: chatId,
                                        otherUserId: isBuyer ? data['sellerId'] : data['buyerId'],
                                        otherUserName: isBuyer ? productName : buyerName,
                                      ),
                                    ),
                                  );
                                },
                                onLongPress: () {
                                  _confirmDeleteChat(context, chatId);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      // Avatar with unread indicator
                                      Stack(
                                        children: [
                                          Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: isBuyer 
                                                  ? [AppTheme.deepTeal, AppTheme.cloud]
                                                  : [AppTheme.primaryGreen, AppTheme.cloud],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (isBuyer ? AppTheme.deepTeal : AppTheme.primaryGreen).withOpacity(0.3),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 5),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                isBuyer 
                                                  ? (productName.isNotEmpty ? productName[0].toUpperCase() : 'P')
                                                  : (buyerName.isNotEmpty ? buyerName[0].toUpperCase() : 'B'),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (isUnread)
                                            Positioned(
                                              right: -2,
                                              top: -2,
                                              child: Container(
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [AppTheme.primaryRed, Colors.red],
                                                  ),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.white, width: 3),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: AppTheme.primaryRed.withOpacity(0.5),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '${data['unreadCount']}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      
                                      const SizedBox(width: 16),
                                      
                                      // Chat details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Header row with name and badge
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    isBuyer ? productName : buyerName,
                                                    style: TextStyle(
                                                      fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                                      color: isUnread ? AppTheme.deepTeal : AppTheme.darkGrey,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: isBuyer 
                                                        ? [AppTheme.deepTeal.withOpacity(0.1), AppTheme.cloud.withOpacity(0.1)]
                                                        : [AppTheme.primaryGreen.withOpacity(0.1), AppTheme.cloud.withOpacity(0.1)],
                                                    ),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: isBuyer ? AppTheme.deepTeal : AppTheme.primaryGreen,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    isBuyer ? 'Product' : 'Buyer',
                                                    style: TextStyle(
                                                      color: isBuyer ? AppTheme.deepTeal : AppTheme.primaryGreen,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            
                                            const SizedBox(height: 8),
                                            
                                            // Additional info
                                            if (isBuyer) ...[
                                              // For buyers: show seller/store name
                                              FutureBuilder<DocumentSnapshot>(
                                                future: FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(data['sellerId'])
                                                    .get(),
                                                builder: (context, sellerSnapshot) {
                                                  final sellerData = sellerSnapshot.data?.data() as Map<String, dynamic>?;
                                                  final sellerName = sellerData?['displayName'] ?? 
                                                                   sellerData?['storeName'] ?? 
                                                                   'Seller';
                                                  return Row(
                                                    children: [
                                                      Icon(
                                                        Icons.store,
                                                        size: 14,
                                                        color: AppTheme.mediumGrey,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        sellerName,
                                                        style: TextStyle(
                                                          color: AppTheme.mediumGrey,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ] else ...[
                                              // For sellers: show product name and contact number
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.shopping_bag,
                                                    size: 14,
                                                    color: AppTheme.mediumGrey,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      productName,
                                                      style: TextStyle(
                                                        color: AppTheme.mediumGrey,
                                                        fontSize: 14,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (buyerNumber.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.phone,
                                                      size: 14,
                                                      color: AppTheme.mediumGrey,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      buyerNumber,
                                                      style: TextStyle(
                                                        color: AppTheme.mediumGrey,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                            
                                            const SizedBox(height: 8),
                                            
                                            // Last message
                                            Text(
                                              lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
                                              style: TextStyle(
                                                color: lastMessage.isNotEmpty 
                                                  ? (isUnread ? AppTheme.deepTeal : AppTheme.mediumGrey)
                                                  : AppTheme.lightGrey,
                                                fontSize: 14,
                                                fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            
                                            if (timestamp != null) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                _formatTimestamp(timestamp),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.lightGrey,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      
                                      // Arrow indicator
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        color: AppTheme.mediumGrey,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteChat(BuildContext context, String chatId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete chat?'),
        content: const Text('This will permanently remove the conversation and its messages.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _deleteChat(chatId);
    }
  }

  Future<void> _deleteChat(String chatId) async {
    try {
      // Delete messages in batches
      final messagesRef = FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages');
      while (true) {
        final snap = await messagesRef.limit(500).get();
        if (snap.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
      // Delete chat document
      await FirebaseFirestore.instance.collection('chats').doc(chatId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted'), backgroundColor: AppTheme.primaryGreen),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete chat: $e'), backgroundColor: AppTheme.primaryRed),
        );
      }
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
