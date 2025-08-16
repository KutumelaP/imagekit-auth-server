import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/ChatScreen.dart';

class ChatRoute extends StatelessWidget {
  final String chatId;
  const ChatRoute({Key? key, required this.chatId}) : super(key: key);

  Future<Map<String, String>?> _loadOtherUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    final chatDoc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .get();
    if (!chatDoc.exists) return null;

    final data = chatDoc.data() as Map<String, dynamic>;
    final buyerId = data['buyerId'] as String?;
    final sellerId = data['sellerId'] as String?;
    final otherUserId = currentUser.uid == buyerId ? sellerId : buyerId;
    if (otherUserId == null) return null;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(otherUserId)
        .get();
    final name = (userDoc.data()?['displayName'] as String?) ??
        (userDoc.data()?['email'] as String?)?.split('@').first ??
        'User';

    return {
      'otherUserId': otherUserId,
      'otherUserName': name,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>?>(
      future: _loadOtherUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final info = snapshot.data;
        if (info == null) {
          return const Scaffold(body: Center(child: Text('Chat not found')));
        }
        return ChatScreen(
          chatId: chatId,
          otherUserId: info['otherUserId']!,
          otherUserName: info['otherUserName']!,
        );
      },
    );
  }
}

