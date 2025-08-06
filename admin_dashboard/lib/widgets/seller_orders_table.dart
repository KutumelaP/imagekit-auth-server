import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/order_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import '../SellerOrderDetailScreen.dart';
import 'dart:async';

class SellerOrdersTable extends StatefulWidget {
  final FirebaseFirestore firestore;
  final String? sellerId;
  final ValueNotifier<List<String>?> filteredOrderIds;
  const SellerOrdersTable({Key? key, required this.firestore, required this.sellerId, required this.filteredOrderIds}) : super(key: key);

  @override
  State<SellerOrdersTable> createState() => _SellerOrdersTableState();
}

class _SellerOrdersTableState extends State<SellerOrdersTable> with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  Set<String> _newOrderIds = {};
  Timer? _newOrderTimer;

  @override
  void initState() {
    super.initState();
    _setupBlinkAnimation();
    _setupNewOrderListener();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _newOrderTimer?.cancel();
    super.dispose();
  }

  void _setupBlinkAnimation() {
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _blinkController,
      curve: Curves.easeInOut,
    ));
    _blinkController.repeat(reverse: true);
  }

  void _setupNewOrderListener() {
    // Listen for new orders (orders created in the last 5 minutes)
    final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
    
    widget.firestore
        .collection('orders')
        .where('sellerId', isEqualTo: widget.sellerId)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(fiveMinutesAgo))
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _newOrderIds = snapshot.docs.map((doc) => doc.id).toSet();
      });
      
      if (_newOrderIds.isNotEmpty) {
        // Start blinking animation
        _blinkController.repeat(reverse: true);
        
        // Stop blinking after 30 seconds
        _newOrderTimer?.cancel();
        _newOrderTimer = Timer(const Duration(seconds: 30), () {
          _blinkController.stop();
        });
      }
    });
  }

  bool _isNewOrder(String orderId) {
    return _newOrderIds.contains(orderId);
  }

  Future<void> _contactBuyer(BuildContext context, Map<String, dynamic> orderData) async {
    // Use phone from order first
    String? phoneNumber = orderData['phone'];
    if (phoneNumber == null || phoneNumber.isEmpty) {
      final buyerId = orderData['buyerId'];
      if (buyerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Buyer information not available')),
        );
        return;
      }
      // Fallback to user profile
      try {
        final buyerDoc = await widget.firestore.collection('users').doc(buyerId).get();
        final buyerData = buyerDoc.data();
        phoneNumber = buyerData?['phoneNumber'] ?? buyerData?['phone'];
      } catch (e) {
        phoneNumber = null;
      }
    }
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buyer phone number not available')),
      );
      return;
    }
    // Show contact options (unchanged)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Buyer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.chat, color: Theme.of(context).colorScheme.primary),
              title: const Text('Send Message'),
              subtitle: const Text('Open chat with buyer'),
              onTap: () {
                Navigator.pop(context);
                _openChatWithBuyer(orderData['buyerId'], orderData);
              },
            ),
            ListTile(
              leading: Icon(Icons.message, color: Theme.of(context).colorScheme.secondary),
              title: const Text('WhatsApp'),
              subtitle: const Text('Open WhatsApp chat'),
              onTap: () {
                Navigator.pop(context);
                if (phoneNumber != null && phoneNumber.isNotEmpty) {
                  _openWhatsApp(phoneNumber, orderData);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _openChatWithBuyer(String buyerId, Map<String, dynamic> orderData) {
    // Check if chat already exists
    widget.firestore
        .collection('chats')
        .where('sellerId', isEqualTo: widget.sellerId)
        .where('buyerId', isEqualTo: buyerId)
        .limit(1)
        .get()
        .then((querySnapshot) {
      if (querySnapshot.docs.isNotEmpty) {
        final chatId = querySnapshot.docs.first.id;
        _showChatDialog(chatId, buyerId);
      } else {
        // Create new chat
        widget.firestore.collection('chats').add({
          'sellerId': widget.sellerId,
          'buyerId': buyerId,
          'productId': orderData['items']?[0]?['productId'],
          'productName': orderData['items']?[0]?['name'] ?? 'Product',
          'lastMessage': '',
          'timestamp': FieldValue.serverTimestamp(),
          'participants': [buyerId, widget.sellerId!],
        }).then((newChat) {
          _showChatDialog(newChat.id, buyerId);
        });
      }
    });
  }

  void _showChatDialog(String chatId, String buyerId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(32),
        child: SizedBox(
          width: 500,
          height: 400,
          child: _ChatDialog(
            chatId: chatId,
            buyerId: buyerId,
            sellerId: widget.sellerId!,
            firestore: widget.firestore,
          ),
        ),
      ),
    );
  }

  void _openWhatsApp(String phoneNumber, Map<String, dynamic> orderData) {
    final orderNumber = orderData['orderNumber'] ?? 'Order';
    final productName = orderData['items']?[0]?['name'] ?? 'Product';
    
    // Format phone number (remove spaces, add country code if needed)
    String formattedPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (!formattedPhone.startsWith('+')) {
      formattedPhone = '+27$formattedPhone'; // Default to South Africa
    }
    
    // Create WhatsApp message
          final message = 'Hi! I\'m contacting you about your order ${OrderUtils.formatShortOrderNumber(orderNumber)} for $productName. How can I help you?';
    final encodedMessage = Uri.encodeComponent(message);
    
    // Create WhatsApp URL
    final whatsappUrl = 'https://wa.me/$formattedPhone?text=$encodedMessage';
    
    // Launch WhatsApp
    launchUrl(Uri.parse(whatsappUrl)).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open WhatsApp: $error')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>?>(
      valueListenable: widget.filteredOrderIds,
      builder: (context, filtered, _) {
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 2,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.03), blurRadius: 8)],
            ),
            child: Column(
              children: [
                // Header with new order indicator
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Orders',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                          ),
                          if (_newOrderIds.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            AnimatedBuilder(
                              animation: _blinkAnimation,
                              builder: (context, child) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_newOrderIds.length} NEW',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onErrorContainer,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
                        onPressed: () {
                          setState(() {
                            _newOrderIds.clear();
                            _blinkController.stop();
                          });
                        },
                        tooltip: 'Clear notifications',
                      ),
                    ],
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: widget.firestore
                      .collection('orders')
                      .where('sellerId', isEqualTo: widget.sellerId)
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var orders = snapshot.data!.docs;
                    if (filtered != null) {
                      orders = orders.where((doc) => filtered.contains(doc.id)).toList();
                    }
                    if (orders.isEmpty) return const Padding(padding: EdgeInsets.all(32), child: Text('No orders found.'));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            'Tip: You can scroll vertically to see more orders.',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontStyle: FontStyle.italic, fontSize: 13),
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Product')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Price')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Contact')),
                              DataColumn(label: Text('')), // Manage button
                            ],
                            rows: orders.take(5).map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final orderId = doc.id;
                              final orderNumber = data['orderNumber'] ?? orderId;
                              final product = (data['items'] is List && data['items'].isNotEmpty) ? data['items'][0]['name'] : 'Product';
                              final date = (data['timestamp'] is Timestamp) ? (data['timestamp'] as Timestamp).toDate() : DateTime.now();
                              final price = data['totalPrice'] ?? 0.0;
                              final status = (data['status'] ?? 'pending').toString();
                              final isNew = _isNewOrder(orderId);
                              
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        if (isNew)
                                          AnimatedBuilder(
                                            animation: _blinkAnimation,
                                            builder: (context, child) {
                                              return Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.errorContainer,
                                                  shape: BoxShape.circle,
                                                ),
                                              );
                                            },
                                          ),
                                        if (data['items'] is List && data['items'].isNotEmpty && data['items'][0]['image'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: CircleAvatar(
                                              backgroundImage: NetworkImage(data['items'][0]['image']),
                                              radius: 16,
                                            ),
                                          ),
                                        Text(product),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}')),
                                  DataCell(Text('R${price.toStringAsFixed(2)}')),
                                  DataCell(
                                    DropdownButton<String>(
                                      value: status,
                                      items: [
                                        DropdownMenuItem(value: 'pending', child: Text('Pending', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold))),
                                        const DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                                        const DropdownMenuItem(value: 'preparing', child: Text('Preparing')),
                                        const DropdownMenuItem(value: 'ready', child: Text('Ready')),
                                        const DropdownMenuItem(value: 'shipped', child: Text('Shipped')),
                                        const DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                                        const DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                                      ],
                                      onChanged: (newStatus) async {
                                        if (newStatus != null && newStatus != status) {
                                          await widget.firestore.collection('orders').doc(orderId).update({'status': newStatus});
                                        }
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.contact_phone, color: Theme.of(context).colorScheme.primary),
                                          tooltip: 'Contact Buyer',
                                          onPressed: () => _contactBuyer(context, data),
                                        ),
                                        SizedBox(width: 4),
                                        Text(data['phone'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                                      ],
                                    ),
                                  ),
                                  DataCell(Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.picture_as_pdf, color: Theme.of(context).colorScheme.primary),
                                        tooltip: 'Download Invoice',
                                        onPressed: () {
                                          // TODO: Implement invoice download
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Invoice download coming soon!')),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
                                        tooltip: 'Manage Order',
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => Dialog(
                                              insetPadding: const EdgeInsets.all(24),
                                              child: LayoutBuilder(
                                                builder: (context, constraints) {
                                                  final maxWidth = 900.0;
                                                  final maxHeight = MediaQuery.of(context).size.height * 0.9;
                                                  return SizedBox(
                                                    width: maxWidth,
                                                    height: maxHeight,
                                                    child: SingleChildScrollView(
                                                      child: ConstrainedBox(
                                                        constraints: BoxConstraints(
                                                          minWidth: 0,
                                                          maxWidth: maxWidth,
                                                          minHeight: 0,
                                                          maxHeight: maxHeight,
                                                        ),
                                                        child: SellerOrderDetailScreen(orderId: orderId),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  )),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Chat Dialog Widget
class _ChatDialog extends StatefulWidget {
  final String chatId;
  final String buyerId;
  final String sellerId;
  final FirebaseFirestore firestore;
  
  const _ChatDialog({
    required this.chatId,
    required this.buyerId,
    required this.sellerId,
    required this.firestore,
  });
  
  @override
  State<_ChatDialog> createState() => _ChatDialogState();
}

class _ChatDialogState extends State<_ChatDialog> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    
    widget.firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
          'text': message,
          'senderId': widget.sellerId,
          'timestamp': Timestamp.now(),
        });
    
    // Update chat metadata
    widget.firestore.collection('chats').doc(widget.chatId).update({
      'lastMessage': message,
      'timestamp': Timestamp.now(),
    });
    
    _messageController.clear();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Buyer'),
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.firestore
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final messages = snapshot.data!.docs;
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)),
                        SizedBox(height: 8),
                        Text('No messages yet', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38))),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isFromSeller = message['senderId'] == widget.sellerId;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: isFromSeller ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.6,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isFromSeller ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              message['text'] ?? '',
                              style: TextStyle(
                                color: isFromSeller ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 