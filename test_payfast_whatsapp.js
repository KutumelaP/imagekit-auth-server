const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function testPayfastWhatsApp() {
  console.log('🧪 Testing PayFast WhatsApp notification without payment...');
  
  try {
    // Use the order ID from the logs that we know had PayFast payment
    const testOrderId = 'OMN60612A96FC6AD'; 
    console.log(`📝 Using test order ID: ${testOrderId}`);
    
    // Create test WhatsApp notification entry
    await testWhatsAppNotification(testOrderId);
    
  } catch (error) {
    console.error('❌ Error testing WhatsApp notification:', error);
  }
}

async function testWhatsAppNotification(orderId, orderData = null) {
  try {
    console.log(`📲 Creating test WhatsApp notification for order: ${orderId}`);
    
    // If no order data provided, try to fetch it
    if (!orderData) {
      const orderDoc = await db.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        console.log('❌ Order not found. Please provide a valid order ID.');
        return;
      }
      orderData = orderDoc.data();
    }
    
    // Create a test notification in the whatsapp_notifications collection
    // This simulates what the PayFast webhook would do
    const notificationData = {
      orderId: orderId,
      buyerPhone: orderData.buyerPhone || '+27123456789', // fallback for testing
      totalAmount: orderData.totalPrice || orderData.total || 100,
      sellerName: orderData.sellerName || 'Test Store',
      deliveryOTP: orderData.deliveryOTP || '1234',
      type: 'payment_confirmation',
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentStatus: 'paid',
      paymentMethod: 'payfast'
    };
    
    // Add to whatsapp_notifications collection
    const notificationRef = await db.collection('whatsapp_notifications').add(notificationData);
    
    console.log('✅ Test WhatsApp notification created successfully!');
    console.log(`📧 Notification ID: ${notificationRef.id}`);
    console.log(`📱 Target phone: ${notificationData.buyerPhone}`);
    console.log(`💰 Amount: R${notificationData.totalAmount}`);
    console.log(`🏪 Store: ${notificationData.sellerName}`);
    
    console.log('\n🔍 Check your Cloud Functions logs to see if the notification was processed:');
    console.log('   firebase functions:log --only processWhatsAppNotification');
    
    console.log('\n📱 The WhatsApp message should be sent to: ' + notificationData.buyerPhone);
    console.log('   (Make sure this phone number can receive WhatsApp messages)');
    
  } catch (error) {
    console.error('❌ Error creating test notification:', error);
  }
}

// Run the test
console.log('🚀 Starting PayFast WhatsApp notification test...');
testPayfastWhatsApp()
  .then(() => {
    console.log('\n✅ Test completed! Check the results above.');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Test failed:', error);
    process.exit(1);
  });
