import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderMigrationUtils {
  /// Migrates existing orders to include buyerName field
  /// This should be run once to update existing orders
  static Future<void> migrateExistingOrders() async {
    try {
      print('🔄 Starting order migration...');
      
      // Get all orders
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .get();
      
      print('📊 Found ${ordersSnapshot.docs.length} orders to migrate');
      
      int migratedCount = 0;
      int skippedCount = 0;
      
      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        
        // Check if order already has buyerName
        if (data['buyerName'] != null && data['buyerName'].toString().isNotEmpty) {
          skippedCount++;
          continue;
        }
        
        // Try to get buyerName from name field
        String buyerName = '';
        if (data['name'] != null && data['name'].toString().isNotEmpty) {
          buyerName = data['name'].toString();
        }
        
        // If no name field, try to get from users collection
        if (buyerName.isEmpty && data['buyerId'] != null) {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(data['buyerId'])
                .get();
            
            if (userDoc.exists) {
              final userData = userDoc.data();
              buyerName = userData?['name'] ?? 
                          userData?['displayName'] ?? 
                          userData?['email'] ?? 
                          '';
            }
          } catch (e) {
            print('❌ Error fetching user data for order ${doc.id}: $e');
          }
        }
        
        // Update the order with buyerName
        if (buyerName.isNotEmpty) {
          await doc.reference.update({
            'buyerName': buyerName,
          });
          migratedCount++;
          print('✅ Migrated order ${doc.id} with buyerName: $buyerName');
        } else {
          skippedCount++;
          print('⚠️ Could not determine buyerName for order ${doc.id}');
        }
      }
      
      print('🎉 Migration completed!');
      print('✅ Migrated: $migratedCount orders');
      print('⏭️ Skipped: $skippedCount orders');
      
    } catch (e) {
      print('❌ Error during migration: $e');
      rethrow;
    }
  }
  
  /// Gets customer name from order data with fallback logic
  static String getCustomerName(Map<String, dynamic> order) {
    // First try buyerName from order data
    if (order['buyerName'] != null && order['buyerName'].toString().isNotEmpty) {
      return order['buyerName'].toString();
    }
    // Then try name field (legacy)
    else if (order['name'] != null && order['name'].toString().isNotEmpty) {
      return order['name'].toString();
    }
    // Then try buyerEmail
    else if (order['buyerEmail'] != null && order['buyerEmail'].toString().isNotEmpty) {
      return order['buyerEmail'].toString();
    }
    // Finally return Unknown
    return 'Unknown Customer';
  }
} 