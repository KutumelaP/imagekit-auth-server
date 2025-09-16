const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkWhatsAppNotifications() {
  console.log('🔍 Checking WhatsApp notifications collection...');
  
  try {
    // Get recent notifications
    const notificationsSnapshot = await db.collection('whatsapp_notifications')
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();
    
    if (notificationsSnapshot.empty) {
      console.log('📭 No WhatsApp notifications found in the collection.');
      console.log('💡 This means either:');
      console.log('   1. No PayFast payments have been processed yet');
      console.log('   2. The payfastNotify function is not creating notifications');
      console.log('   3. The collection name is different');
      return;
    }
    
    console.log(`📊 Found ${notificationsSnapshot.docs.length} recent notifications:`);
    console.log('');
    
    notificationsSnapshot.docs.forEach((doc, index) => {
      const data = doc.data();
      const createdAt = data.createdAt ? data.createdAt.toDate().toLocaleString() : 'Unknown';
      
      console.log(`${index + 1}. Notification ID: ${doc.id}`);
      console.log(`   📋 Order ID: ${data.orderId || 'Unknown'}`);
      console.log(`   📱 Phone: ${data.buyerPhone || 'Unknown'}`);
      console.log(`   💰 Amount: R${data.totalAmount || 'Unknown'}`);
      console.log(`   🏪 Store: ${data.sellerName || 'Unknown'}`);
      console.log(`   📊 Status: ${data.status || 'Unknown'}`);
      console.log(`   🕒 Created: ${createdAt}`);
      console.log(`   💳 Payment: ${data.paymentMethod || 'Unknown'}`);
      console.log('   ---');
    });
    
  } catch (error) {
    console.error('❌ Error checking notifications:', error);
  }
}

// Run the check
checkWhatsAppNotifications()
  .then(() => {
    console.log('\n✅ Check completed!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Check failed:', error);
    process.exit(1);
  });
