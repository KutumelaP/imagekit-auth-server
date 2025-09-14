import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'otp_verification_service.dart';
import 'whatsapp_integration_service.dart';

class SellerDeliveryManagementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Create delivery task for seller to manage
  static Future<Map<String, dynamic>> createDeliveryTask({
    required String orderId,
    required String sellerId,
    required Map<String, dynamic> deliveryDetails,
    required Map<String, dynamic> productHandlingInstructions,
  }) async {
    try {
      // Generate OTP for this delivery
      final otp = await OTPVerificationService.generateDeliveryOTP(
        orderId: orderId,
        buyerId: deliveryDetails['buyerId'],
        sellerId: sellerId,
      );
      
      // Create delivery task for seller
      await _firestore.collection('seller_delivery_tasks').doc(orderId).set({
        'orderId': orderId,
        'sellerId': sellerId,
        'status': 'pending_seller_action', // pending_seller_action, delivery_in_progress, delivered, cancelled
        'createdAt': FieldValue.serverTimestamp(),
        'deliveryOTP': otp,
        'deliveryDetails': deliveryDetails,
        'productHandlingInstructions': productHandlingInstructions,
        'sellerActions': [],
        'deliveryUpdates': [],
        'estimatedDeliveryTime': null,
        'actualDeliveryMethod': null, // seller_own_driver, taxi, family_friend, third_party
        'driverDetails': null,
      });
      
      // Notify seller about new delivery task
      await _notifySellerOfNewDeliveryTask(
        sellerId: sellerId,
        orderId: orderId,
        otp: otp,
        deliveryDetails: deliveryDetails,
        productInstructions: productHandlingInstructions,
      );
      
      return {
        'success': true,
        'orderId': orderId,
        'otp': otp,
        'message': 'Delivery task created for seller',
      };
      
    } catch (e) {
      print('❌ Error creating delivery task: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Seller confirms they will handle delivery
  static Future<Map<String, dynamic>> sellerConfirmDelivery({
    required String orderId,
    required String sellerId,
    required String deliveryMethod, // own_driver, taxi, family_friend, third_party_service
    required Map<String, dynamic> driverDetails,
    required String estimatedDeliveryTime,
  }) async {
    try {
      print('🚀 CONFIRMING DELIVERY: $orderId');
      print('   - Method: $deliveryMethod');
      print('   - Driver: ${driverDetails['name']} (${driverDetails['driverId']})');
      
      await _firestore.collection('seller_delivery_tasks').doc(orderId).update({
        'status': 'confirmed_by_seller',
        'actualDeliveryMethod': deliveryMethod,
        'driverDetails': driverDetails,
        'estimatedDeliveryTime': estimatedDeliveryTime,
        'confirmedAt': FieldValue.serverTimestamp(),
        'sellerActions': FieldValue.arrayUnion([{
          'action': 'confirmed_delivery',
          'timestamp': Timestamp.now(),
          'method': deliveryMethod,
          'estimatedTime': estimatedDeliveryTime,
        }]),
      });
      
      print('✅ Delivery task updated to confirmed_by_seller status');
      
      // Update main order with driver assignment for driver app access
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'driver_assigned',
        'deliveryMethod': deliveryMethod,
        'estimatedDeliveryTime': estimatedDeliveryTime,
        'assignedDriver': {
          'driverId': driverDetails['driverId'],
          'name': driverDetails['name'],
          'phone': driverDetails['phone'],
          'type': 'seller_assigned',
          'sellerId': sellerId,
          'assignedAt': FieldValue.serverTimestamp(),
        },
        'deliveryType': 'seller_delivery',
      });

      // 🚀 NEW: If using own_driver, make order available in driver app
      if (deliveryMethod == 'own_driver' && driverDetails['driverId'] != null) {
        await _assignOrderToSellerDriver(
          orderId: orderId,
          sellerId: sellerId,
          driverId: driverDetails['driverId'],
          driverDetails: driverDetails,
        );
      }
      
      // Notify buyer that seller confirmed delivery
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (orderDoc.exists) {
        final orderData = orderDoc.data()!;
        await _notifyBuyerDeliveryConfirmed(
          buyerPhone: orderData['buyerPhone'],
          orderId: orderId,
          estimatedTime: estimatedDeliveryTime,
          driverDetails: driverDetails,
        );
      }
      
      return {
        'success': true,
        'message': 'Delivery confirmed by seller',
        'status': 'confirmed_by_seller',
      };
      
    } catch (e) {
      print('❌ Error confirming delivery: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 🚀 NEW: Assign order to seller's driver for driver app access
  static Future<void> _assignOrderToSellerDriver({
    required String orderId,
    required String sellerId,
    required String driverId,
    required Map<String, dynamic> driverDetails,
  }) async {
    try {
      // Update the driver document to show they have a pending order
      await _firestore
          .collection('users')
          .doc(sellerId)
          .collection('drivers')
          .doc(driverId)
          .update({
        'currentOrder': orderId,
        'isAvailable': false,
        'status': 'assigned',
        'lastAssignedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Order $orderId assigned to seller driver $driverId');
    } catch (e) {
      print('❌ Error assigning order to seller driver: $e');
    }
  }
  
  /// Seller starts delivery (when driver picks up from seller)
  static Future<Map<String, dynamic>> sellerStartDelivery({
    required String orderId,
    required String sellerId,
    String? notes,
    String? photoUrl,
  }) async {
    try {
      await _firestore.collection('seller_delivery_tasks').doc(orderId).update({
        'status': 'delivery_in_progress',
        'startedAt': FieldValue.serverTimestamp(),
        'sellerActions': FieldValue.arrayUnion([{
          'action': 'started_delivery',
          'timestamp': Timestamp.now(),
          'notes': notes,
          'photoUrl': photoUrl,
        }]),
      });
      
      // Update main order
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'out_for_delivery',
        'deliveryStartedAt': FieldValue.serverTimestamp(),
      });
      
      // Get delivery task details for notification
      final taskDoc = await _firestore.collection('seller_delivery_tasks').doc(orderId).get();
      if (taskDoc.exists) {
        final taskData = taskDoc.data()!;
        final deliveryDetails = taskData['deliveryDetails'] as Map<String, dynamic>;
        final driverDetails = taskData['driverDetails'] as Map<String, dynamic>?;
        
        // Notify buyer that delivery started
        await WhatsAppIntegrationService.sendDeliveryNotification(
          orderId: orderId,
          buyerPhone: deliveryDetails['buyerPhone'],
          driverName: driverDetails?['name'] ?? 'Driver',
          driverPhone: driverDetails?['phone'] ?? '',
          estimatedArrival: taskData['estimatedDeliveryTime'] ?? 'Soon',
          trackingUrl: 'https://omniasa.co.za/track/$orderId',
          deliveryOTP: taskData['deliveryOTP'],
        );
      }
      
      return {
        'success': true,
        'message': 'Delivery started',
        'status': 'delivery_in_progress',
      };
      
    } catch (e) {
      print('❌ Error starting delivery: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Complete delivery with OTP verification
  static Future<Map<String, dynamic>> completeDeliveryWithOTP({
    required String orderId,
    required String enteredOTP,
    required String? delivererId, // Could be seller's driver ID or name
    Map<String, dynamic>? deliveryLocation,
    String? deliveryNotes,
    String? deliveryPhotoUrl,
  }) async {
    try {
      // Verify OTP
      final otpResult = await OTPVerificationService.verifyDeliveryOTP(
        orderId: orderId,
        enteredOTP: enteredOTP,
        delivererId: delivererId,
        location: deliveryLocation,
      );
      
      if (!otpResult['success']) {
        return otpResult; // Return OTP verification failure
      }
      
      // Update delivery task
      await _firestore.collection('seller_delivery_tasks').doc(orderId).update({
        'status': 'delivered',
        'completedAt': FieldValue.serverTimestamp(),
        'deliveryVerification': {
          'otpVerified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
          'delivererId': delivererId,
          'location': deliveryLocation,
          'notes': deliveryNotes,
          'photoUrl': deliveryPhotoUrl,
        },
        'sellerActions': FieldValue.arrayUnion([{
          'action': 'delivery_completed',
          'timestamp': Timestamp.now(),
          'otpUsed': enteredOTP,
          'delivererId': delivererId,
        }]),
      });
      
      // Update main order status
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'deliveryCompleted': true,
      });

      // 🚀 NEW: Update seller's driver status back to available
      final taskDoc = await _firestore.collection('seller_delivery_tasks').doc(orderId).get();
      if (taskDoc.exists) {
        final taskData = taskDoc.data()!;
        final driverDetails = taskData['driverDetails'] as Map<String, dynamic>?;
        final sellerId = taskData['sellerId'];
        
        if (driverDetails?['driverId'] != null && sellerId != null) {
          try {
            // 🚀 CRITICAL FIX: Calculate driver earnings from delivery fee
            final orderDoc = await _firestore.collection('orders').doc(orderId).get();
            double driverEarnings = 0.0;
            
            if (orderDoc.exists) {
              final orderData = orderDoc.data()!;
              // Extract delivery fee from order data
              final deliveryFee = (orderData['pricing'] as Map<String, dynamic>?)?['deliveryFee']?.toDouble() 
                               ?? orderData['deliveryFee']?.toDouble() 
                               ?? 0.0;
              
              // Driver gets 80% of delivery fee (same as platform drivers)
              driverEarnings = deliveryFee * 0.8;
              print('📊 Calculated driver earnings: R$driverEarnings (80% of R$deliveryFee delivery fee)');
            }

            await _firestore
                .collection('users')
                .doc(sellerId)
                .collection('drivers')
                .doc(driverDetails!['driverId'])
                .update({
              'status': 'available',           // ✅ Change back to available
              'isAvailable': true,             // ✅ Make available for new assignments  
              'currentOrder': null,            // ✅ Clear current order
              'lastCompletedAt': FieldValue.serverTimestamp(),
              'completedOrders': FieldValue.increment(1),
              'earnings': FieldValue.increment(driverEarnings), // 🚀 FIXED: Add driver earnings!
            });
            print('✅ Driver ${driverDetails['driverId']} status updated to available with R$driverEarnings earnings');
          } catch (e) {
            print('⚠️ Could not update driver status: $e');
          }
        }
      }
      
      return {
        'success': true,
        'message': 'Delivery completed successfully!',
        'orderId': orderId,
        'deliveredAt': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      print('❌ Error completing delivery: $e');
      return {
        'success': false,
        'message': 'Failed to complete delivery',
        'error': e.toString(),
      };
    }
  }
  
  /// Get seller's delivery dashboard data
  static Future<Map<String, dynamic>> getSellerDeliveryDashboard(String sellerId) async {
    try {
      // Get delivery tasks and cross-reference with order payment status
      // 🚀 EXPANDED: Include more statuses to track deliveries through the entire flow
      final allTasks = await _firestore
          .collection('seller_delivery_tasks')
          .where('sellerId', isEqualTo: sellerId)
          .where('status', whereIn: [
            'pending_seller_action',    // Waiting for seller to confirm
            'confirmed_by_seller',      // Seller confirmed, ready to start
            'delivery_in_progress',     // Driver is delivering
            'out_for_delivery',         // Alternative in-progress status
            'picked_up',                // Driver picked up order
            'en_route'                  // Driver en route to customer
          ])
          .orderBy('createdAt', descending: true)
          .get();

      // Filter tasks to only show those with paid orders
      List<Map<String, dynamic>> pendingTasks = [];
      List<Map<String, dynamic>> activeDeliveries = [];
      
      for (final taskDoc in allTasks.docs) {
        final taskData = taskDoc.data();
        final orderId = taskData['orderId'];
        final taskStatus = taskData['status'] ?? '';
        
        // Check if the order is paid and ready for delivery
        final orderDoc = await _firestore.collection('orders').doc(orderId).get();
        if (orderDoc.exists) {
          final orderData = orderDoc.data()!;
          final paymentStatus = orderData['payment']?['status'] ?? 'pending';
          final orderStatus = orderData['status'] ?? 'pending';
          final fulfillmentType = orderData['fulfillmentType'] ?? 'pickup';
          
          // Only show delivery orders that are paid and confirmed
          final paymentStatus2 = orderData['paymentStatus'] ?? 'pending';
          final fulfillmentType2 = orderData['fulfillment']?['type'] ?? 'pickup';
          
          final isPaid = paymentStatus == 'paid' || paymentStatus == 'completed' || paymentStatus == 'success' || paymentStatus2 == 'completed';
          final isReadyForDelivery = orderStatus == 'confirmed' || orderStatus == 'ready' || orderStatus == 'preparing' || orderStatus == 'delivery_confirmed' || orderStatus == 'out_for_delivery';
          final isDeliveryOrder = fulfillmentType == 'delivery' || fulfillmentType2 == 'delivery';
          final isInProgress = ['delivery_in_progress', 'out_for_delivery', 'picked_up', 'en_route'].contains(taskStatus);
          
          // 🚀 DEBUG: Log each order's criteria
          print('🔍 Order $orderId criteria:');
          print('   - Task Status: $taskStatus');
          print('   - Payment: $paymentStatus / $paymentStatus2 → isPaid: $isPaid');
          print('   - Order Status: $orderStatus → isReady: $isReadyForDelivery');
          print('   - Fulfillment: $fulfillmentType / $fulfillmentType2 → isDelivery: $isDeliveryOrder');
          print('   - Progress: $isInProgress');
          
          // 🚀 TEMPORARY: Relax criteria for debugging
          final shouldShow = isPaid && isDeliveryOrder && (isReadyForDelivery || isInProgress);
          final debugShow = true; // Temporarily show all tasks for debugging
          
          if (shouldShow || debugShow) {
            if (!shouldShow) {
              print('   - ⚠️ SHOWING FOR DEBUG ONLY (normally would be filtered out)');
            }
            // Use the correct payment status - prefer the root level paymentStatus
            final displayPaymentStatus = paymentStatus2 != 'pending' ? paymentStatus2 : paymentStatus;
            
            final taskItem = {
              'taskId': taskDoc.id,
              'orderId': orderId,
              'orderStatus': orderStatus,
              'paymentStatus': displayPaymentStatus,
              ...taskData,
            };
            
            // 🚀 NEW: Separate pending actions from active deliveries
            if (taskStatus == 'pending_seller_action') {
              pendingTasks.add(taskItem);
            } else {
              // confirmed_by_seller, delivery_in_progress, etc.
              activeDeliveries.add(taskItem);
            }
          }
        }
      }
      
      // Get recent completed deliveries
      final recentDeliveries = await _firestore
          .collection('seller_delivery_tasks')
          .where('sellerId', isEqualTo: sellerId)
          .where('status', isEqualTo: 'delivered')
          .orderBy('completedAt', descending: true)
          .limit(10)
          .get();
      
      // Calculate stats
      final totalDeliveries = recentDeliveries.docs.length;
      final avgDeliveryTime = _calculateAverageDeliveryTime(recentDeliveries.docs);
      
      print('✅ Delivery dashboard loaded:');
      print('   - ${pendingTasks.length} pending tasks');
      print('   - ${activeDeliveries.length} active deliveries');
      print('   - $totalDeliveries completed deliveries');
      print('   - Total tasks fetched: ${allTasks.docs.length}');
      
      // Debug: Show what was filtered out
      if (allTasks.docs.length > (pendingTasks.length + activeDeliveries.length)) {
        print('⚠️ Some tasks were filtered out - checking payment/fulfillment criteria');
      }

      return {
        'success': true,
        'pendingTasks': pendingTasks,
        'activeDeliveries': activeDeliveries, // Already processed list with payment status
        'recentDeliveries': recentDeliveries.docs.map((doc) => {
          'orderId': doc.id,
          ...doc.data(),
        }).toList(),
        'stats': {
          'totalDeliveries': totalDeliveries,
          'pendingCount': pendingTasks.length,
          'averageDeliveryTime': avgDeliveryTime,
        },
      };
      
    } catch (e) {
      print('❌ Error getting seller delivery dashboard: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Generate product-specific handling instructions
  static Map<String, dynamic> generateProductHandlingInstructions({
    required String productCategory,
    required String productName,
    required Map<String, dynamic> productDetails,
  }) {
    Map<String, dynamic> instructions = {
      'category': productCategory,
      'generalInstructions': [],
      'temperatureRequirements': null,
      'packagingRequirements': [],
      'handlingPrecautions': [],
      'specialNotes': '',
    };
    
    // Food-specific instructions (like your kota example)
    if (productCategory.toLowerCase().contains('food')) {
      if (productName.toLowerCase().contains('kota') || 
          productName.toLowerCase().contains('burger') ||
          productName.toLowerCase().contains('sandwich')) {
        instructions['generalInstructions'].addAll([
          'Keep hot and crisp',
          'Sauce on the side (separate container)',
          'Handle upright to prevent spillage',
          'Deliver within 30 minutes of preparation',
        ]);
        instructions['temperatureRequirements'] = {
          'maintain': 'hot',
          'minTemp': 65, // Celsius
          'maxDeliveryTime': 30, // minutes
        };
        instructions['packagingRequirements'].addAll([
          'Insulated bag required',
          'Separate sauce containers',
          'Napkins included',
        ]);
      } else if (productName.toLowerCase().contains('pizza')) {
        instructions['generalInstructions'].addAll([
          'Keep flat and level',
          'Maintain heat',
          'Handle with care to prevent sliding',
        ]);
        instructions['temperatureRequirements'] = {
          'maintain': 'hot',
          'minTemp': 60,
          'maxDeliveryTime': 45,
        };
      } else if (productName.toLowerCase().contains('ice cream') ||
                 productName.toLowerCase().contains('frozen')) {
        instructions['generalInstructions'].addAll([
          'Keep frozen',
          'Insulated container mandatory',
          'Deliver immediately',
        ]);
        instructions['temperatureRequirements'] = {
          'maintain': 'frozen',
          'maxTemp': -10,
          'maxDeliveryTime': 20,
        };
      }
    }
    
    // Electronics instructions
    else if (productCategory.toLowerCase().contains('electronics')) {
      instructions['generalInstructions'].addAll([
        'Handle with extreme care',
        'Keep dry and protected',
        'Avoid shaking or dropping',
        'Fragile item - priority handling',
      ]);
      instructions['packagingRequirements'].addAll([
        'Bubble wrap protection',
        'Waterproof outer covering',
        'Fragile stickers',
      ]);
      instructions['handlingPrecautions'].addAll([
        'Two-hand carry recommended',
        'No stacking on top',
        'Climate controlled transport if possible',
      ]);
    }
    
    // Clothing instructions
    else if (productCategory.toLowerCase().contains('clothing')) {
      instructions['generalInstructions'].addAll([
        'Keep clean and wrinkle-free',
        'Protect from rain/moisture',
        'Fold carefully or hang if possible',
      ]);
      instructions['packagingRequirements'].addAll([
        'Plastic protective covering',
        'Proper folding/hanging',
      ]);
    }
    
    return instructions;
  }
  
  // Private helper methods
  
  static Future<void> _notifySellerOfNewDeliveryTask({
    required String sellerId,
    required String orderId,
    required String otp,
    required Map<String, dynamic> deliveryDetails,
    required Map<String, dynamic> productInstructions,
  }) async {
    try {
      // Get seller details
      final sellerDoc = await _firestore.collection('users').doc(sellerId).get();
      if (!sellerDoc.exists) return;
      
      final sellerData = sellerDoc.data()!;
      final sellerPhone = sellerData['phone'] ?? '';
      
      if (sellerPhone.isNotEmpty) {
        final message = _buildSellerDeliveryTaskMessage(
          orderId: orderId,
          otp: otp,
          buyerName: deliveryDetails['buyerName'] ?? 'Customer',
          deliveryAddress: deliveryDetails['address'] ?? 'Address not provided',
          productInstructions: productInstructions,
        );
        
        await WhatsAppIntegrationService.openWhatsAppChat(
          phoneNumber: sellerPhone,
          message: message,
        );
      }
    } catch (e) {
      print('❌ Error notifying seller: $e');
    }
  }
  
  static Future<void> _notifyBuyerDeliveryConfirmed({
    String? buyerPhone, // Made optional since phone isn't collected at checkout
    required String orderId,
    required String estimatedTime,
    required Map<String, dynamic>? driverDetails,
  }) async {
    try {
      // Skip notification if no phone number available
      if (buyerPhone == null || buyerPhone.isEmpty) {
        print('⚠️ Skipping buyer notification - no phone number available');
        return;
      }
      
      final message = '''✅ *Delivery Confirmed!*

📋 *Order:* #$orderId
🕐 *Estimated Time:* $estimatedTime
👤 *Driver:* ${driverDetails?['name'] ?? 'Assigned driver'}
📞 *Contact:* ${driverDetails?['phone'] ?? 'Via seller'}

Your seller has arranged delivery and will notify you when the driver is on the way!

*OmniaSA Delivery* 🇿🇦''';
      
      await WhatsAppIntegrationService.openWhatsAppChat(
        phoneNumber: buyerPhone,
        message: message,
      );
    } catch (e) {
      print('❌ Error notifying buyer: $e');
    }
  }
  
  static String _buildSellerDeliveryTaskMessage({
    required String orderId,
    required String otp,
    required String buyerName,
    required String deliveryAddress,
    required Map<String, dynamic> productInstructions,
  }) {
    final instructions = (productInstructions['generalInstructions'] as List?)
        ?.cast<String>()
        .join('\n• ') ?? 'Standard handling';
    
    return '''🚚 *New Delivery Task*

📋 *Order:* #$orderId
👤 *Customer:* $buyerName
📍 *Deliver to:* $deliveryAddress

🔐 *Delivery OTP:* $otp
(Give this to your driver for handover)

📦 *Special Instructions:*
• $instructions

Please confirm your delivery method in the seller dashboard!

*OmniaSA Seller Tools* 🏪''';
  }
  
  static double _calculateAverageDeliveryTime(List<QueryDocumentSnapshot> deliveries) {
    if (deliveries.isEmpty) return 0.0;
    
    double totalMinutes = 0.0;
    int validDeliveries = 0;
    
    for (final doc in deliveries) {
      final data = doc.data() as Map<String, dynamic>;
      final startedAt = data['startedAt'] as Timestamp?;
      final completedAt = data['completedAt'] as Timestamp?;
      
      if (startedAt != null && completedAt != null) {
        final duration = completedAt.toDate().difference(startedAt.toDate());
        totalMinutes += duration.inMinutes;
        validDeliveries++;
      }
    }
    
    return validDeliveries > 0 ? totalMinutes / validDeliveries : 0.0;
  }

  /// Start delivery tracking for assigned order
  static Future<Map<String, dynamic>> startDelivery({
    required String orderId,
    required String driverName,
  }) async {
    try {
      // Update the order status to delivery_in_progress
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'delivery_in_progress',
        'trackingStartedAt': FieldValue.serverTimestamp(),
        'trackingStartedBy': driverName,
      });

      // Update seller delivery task if it exists
      final taskDoc = await _firestore.collection('seller_delivery_tasks').doc(orderId).get();
      if (taskDoc.exists) {
        final taskData = taskDoc.data()!;
        
        await _firestore.collection('seller_delivery_tasks').doc(orderId).update({
          'status': 'delivery_in_progress',
          'startedAt': FieldValue.serverTimestamp(),
          'deliveryUpdates': FieldValue.arrayUnion([
            {
              'timestamp': Timestamp.now(),
              'action': 'tracking_started',
              'performer': driverName,
              'details': 'Driver started delivery tracking',
            }
          ]),
        });
        
        // 🚀 NEW: Send WhatsApp notification to buyer when driver starts tracking
        final deliveryDetails = taskData['deliveryDetails'] as Map<String, dynamic>?;
        final driverDetails = taskData['driverDetails'] as Map<String, dynamic>?;
        
        if (deliveryDetails?['buyerPhone'] != null && deliveryDetails!['buyerPhone'].toString().isNotEmpty) {
          await WhatsAppIntegrationService.sendDeliveryNotification(
            orderId: orderId,
            buyerPhone: deliveryDetails['buyerPhone'],
            driverName: driverName,
            driverPhone: driverDetails?['phone'] ?? '',
            estimatedArrival: taskData['estimatedDeliveryTime']?.toString() ?? '30 minutes',
            trackingUrl: 'https://omniasa.co.za/track/$orderId',
            deliveryOTP: taskData['deliveryOTP'],
          );
          
          print('✅ WhatsApp delivery notification sent to buyer');
        } else {
          print('⚠️ No buyer phone number - WhatsApp notification skipped');
        }
      }

      return {
        'success': true,
        'message': 'Delivery tracking started successfully',
      };
    } catch (e) {
      print('❌ Error starting delivery: $e');
      return {
        'success': false,
        'message': 'Failed to start delivery tracking: $e',
      };
    }
  }

  /// 🧪 TESTING ONLY: Reset delivery status to confirmed_by_seller for re-testing
  static Future<Map<String, dynamic>> resetDeliveryForTesting({
    required String orderId,
  }) async {
    try {
      print('🔄 TESTING: Resetting delivery status for order: $orderId');
      
      // Reset order status
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'confirmed',
        'trackingStartedAt': FieldValue.delete(),
        'trackingStartedBy': FieldValue.delete(),
        'driverLocation': FieldValue.delete(),
        'lastLocationUpdate': FieldValue.delete(),
      });

      // Reset seller delivery task status
      final taskDoc = await _firestore.collection('seller_delivery_tasks').doc(orderId).get();
      if (taskDoc.exists) {
        await _firestore.collection('seller_delivery_tasks').doc(orderId).update({
          'status': 'confirmed_by_seller',
          'startedAt': FieldValue.delete(),
          'deliveryUpdates': FieldValue.delete(),
        });
        print('✅ Seller delivery task reset to confirmed_by_seller');
      }

      print('✅ Order reset - you can now test "Start Tracking" again');
      return {
        'success': true,
        'message': 'Delivery reset for testing - you can click Start Tracking again',
      };
    } catch (e) {
      print('❌ Error resetting delivery: $e');
      return {
        'success': false,
        'message': 'Failed to reset delivery: $e',
      };
    }
  }
}
