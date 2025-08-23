import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommunityImpactScreen extends StatelessWidget {
  const CommunityImpactScreen({super.key});

  Future<DocumentSnapshot<Object?>> _getCurrentUserDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No user');
    return await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community Impact')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // User's Personal Impact
          FutureBuilder<DocumentSnapshot<Object?>>(
            future: _getCurrentUserDoc(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox();
              }
              if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final role = data?['role'] ?? 'buyer';
              final name = data?['storeName'] ?? data?['email'] ?? 'You';
              // For demo: fallback to 0 or a static value
              final userMeals = data?['mealsDonated'] ?? (role == 'seller' ? 123 : 7);
              return Card(
                color: Colors.blue.shade50,
                margin: const EdgeInsets.only(bottom: 24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role == 'seller'
                            ? 'Your Store’s Impact'
                            : 'Your Personal Impact',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        role == 'seller'
                            ? '$name has helped donate $userMeals meals!'
                            : 'You have helped donate $userMeals meals!',
                        style: const TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Total Meals Donated
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Meals Donated', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('impact').doc('totals').get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      final data = snapshot.data?.data() as Map<String, dynamic>?;
                      final totalMeals = data?['mealsDonated'] ?? 1234; // fallback demo value
                      return Text(
                        '$totalMeals meals donated',
                        style: const TextStyle(fontSize: 24, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Participating Sellers
          const Text('Participating Sellers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'seller').where('status', isEqualTo: 'approved').where('buyOneGiveOne', isEqualTo: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final sellers = snapshot.data!.docs;
                if (sellers.isEmpty) return const Text('No sellers participating yet.');
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: sellers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final data = sellers[i].data() as Map<String, dynamic>;
                    return Chip(
                      label: Text(data['storeName'] ?? 'Seller'),
                      avatar: data['profileImageUrl'] != null
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(data['profileImageUrl']),
                              onBackgroundImageError: (exception, stackTrace) {
                                print('Error loading seller avatar: $exception');
                              },
                            )
                          : const CircleAvatar(child: Icon(Icons.store)),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          // Impact Stories
          const Text('Impact Stories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('“Thanks to your support, we were able to provide fresh bread to 50 families last month!”', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 8),
                  Text('- Local Food Bank', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('“The Buy One, Give One program helped us reduce waste and make a difference in our community.”', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 8),
                  Text('- Doughy Delights', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 