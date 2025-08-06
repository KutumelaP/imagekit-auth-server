import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategorySeederScreen extends StatelessWidget {
  const CategorySeederScreen({super.key});

  final List<Map<String, dynamic>> categories = const [
    {
      'name': 'Food',
      'icon': 'fastfood',
      'color': '#FF6F61',
    },
    {
      'name': 'Drinks',
      'icon': 'local_drink',
      'color': '#4A90E2',
    },
    {
      'name': 'Bakery',
      'icon': 'cake',
      'color': '#F5A623',
    },
    {
      'name': 'Fruits',
      'icon': 'apple',
      'color': '#7ED321',
    },
    {
      'name': 'Vegetables',
      'icon': 'eco',
      'color': '#50E3C2',
    },
    {
      'name': 'Snacks',
      'icon': 'fastfood',
      'color': '#FF6F61',
    },
    {
      'name': 'Electronics',
      'icon': 'devices',
      'color': '#4A90E2',
    },
    {
      'name': 'Clothes',
      'icon': 'shopping_bag',
      'color': '#F5A623',
    },
    {
      'name': 'Other',
      'icon': 'category',
      'color': '#9B59B6',
    },
  ];

  Future<void> seedCategories(BuildContext context) async {
    try {
      final collection = FirebaseFirestore.instance.collection('categories');

      final batch = FirebaseFirestore.instance.batch();

      for (var cat in categories) {
        // Use non-null assertion ! because we know name is set in each map
        final docId = cat['name']!.toLowerCase();
        final docRef = collection.doc(docId);
        batch.set(docRef, cat);
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categories seeded successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to seed categories: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seed Categories')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => seedCategories(context),
          child: const Text('Seed Default Categories'),
        ),
      ),
    );
  }
}
