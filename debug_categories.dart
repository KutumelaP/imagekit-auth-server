import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  // Initialize Firebase (you'll need to add your config)
  // Firebase.initializeApp();
  
  try {
    print('🔍 DEBUG: Checking categories in database...');
    
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .limit(50)
        .get();
    
    print('🔍 DEBUG: Found ${snapshot.docs.length} products');
    
    final categories = <String>{};
    final subcategories = <String>{};
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final category = data['category']?.toString() ?? 'Unknown';
      final subcategory = data['subcategory']?.toString() ?? 'Unknown';
      
      categories.add(category);
      subcategories.add(subcategory);
      
      print('🔍 DEBUG: Product: ${data['name']} - Category: $category, Subcategory: $subcategory');
    }
    
    print('🔍 DEBUG: All categories found: $categories');
    print('🔍 DEBUG: All subcategories found: $subcategories');
    
  } catch (e) {
    print('❌ Error: $e');
  }
} 