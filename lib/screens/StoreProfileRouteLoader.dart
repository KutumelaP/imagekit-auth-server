import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'simple_store_profile_screen.dart';

class StoreProfileRouteLoader extends StatelessWidget {
  final String storeId;
  const StoreProfileRouteLoader({required this.storeId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(storeId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Store not found')),
          );
        }
        final data = snapshot.data!.data()!..putIfAbsent('storeId', () => storeId);
        return SimpleStoreProfileScreen(store: data);
      },
    );
  }
}


