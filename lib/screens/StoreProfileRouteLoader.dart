import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'simple_store_profile_screen.dart';

class StoreProfileRouteLoader extends StatelessWidget {
  final String storeId;
  const StoreProfileRouteLoader({required this.storeId});

  @override
  Widget build(BuildContext context) {
    // 🔍 DEBUG: Log when the loader is built
    print('🔗 STORE LOADER DEBUG: Building StoreProfileRouteLoader for storeId: $storeId');
    
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(storeId).get(),
      builder: (context, snapshot) {
        // 🔍 DEBUG: Log the snapshot state
        print('🔗 STORE LOADER DEBUG: Snapshot state: ${snapshot.connectionState}');
        print('🔗 STORE LOADER DEBUG: Has data: ${snapshot.hasData}');
        print('🔗 STORE LOADER DEBUG: Data exists: ${snapshot.data?.exists}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('🔗 STORE LOADER DEBUG: Showing loading indicator');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          print('🔗 STORE LOADER DEBUG: Store not found - showing error');
          return const Scaffold(
            body: Center(child: Text('Store not found')),
          );
        }
        
        final data = snapshot.data!.data()!..putIfAbsent('storeId', () => storeId);
        print('🔗 STORE LOADER DEBUG: Store data loaded successfully, navigating to SimpleStoreProfileScreen');
        
        return SimpleStoreProfileScreen(store: data);
      },
    );
  }
}


