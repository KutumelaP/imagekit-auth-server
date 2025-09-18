const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
try {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
} catch (error) {
  console.log('Using default credentials');
  admin.initializeApp();
}

const db = admin.firestore();

async function fixPayfastEarnings() {
  console.log('🔧 Fixing PayFast earnings that are stuck in "held" status...');
  
  try {
    // Find all orders that are PayFast paid but have held receivables
    const ordersSnapshot = await db.collection('orders')
      .where('paymentStatus', '==', 'paid')
      .where('paymentGateway', '==', 'payfast')
      .get();
    
    console.log(`📊 Found ${ordersSnapshot.size} PayFast paid orders`);
    
    let fixedCount = 0;
    
    for (const orderDoc of ordersSnapshot.docs) {
      const orderId = orderDoc.id;
      const orderData = orderDoc.data();
      const sellerId = orderData.sellerId;
      
      if (!sellerId) {
        console.log(`⚠️ Order ${orderId} missing sellerId`);
        continue;
      }
      
      // Check if receivable entry exists and is held
      const receivableRef = db.collection('platform_receivables')
        .doc(sellerId)
        .collection('entries')
        .doc(orderId);
      
      const receivableDoc = await receivableRef.get();
      
      if (receivableDoc.exists) {
        const receivableData = receivableDoc.data();
        
        if (receivableData.status === 'held') {
          console.log(`🔄 Fixing order ${orderId} - moving from held to available`);
          
          // Update receivable to available
          await receivableRef.update({
            status: 'available',
            availableAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          // Ensure order status is confirmed
          await orderDoc.ref.update({
            status: 'confirmed',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          fixedCount++;
          console.log(`✅ Fixed earnings for order ${orderId}`);
        } else {
          console.log(`ℹ️ Order ${orderId} receivable already ${receivableData.status}`);
        }
      } else {
        console.log(`⚠️ Order ${orderId} missing receivable entry`);
        
        // Create missing receivable entry
        const totalPrice = Number((orderData.pricing && orderData.pricing.grandTotal) || orderData.totalPrice || orderData.total || 0);
        
        if (totalPrice > 0) {
          // Calculate commission (simplified - using 6% default)
          const commission = Math.round(totalPrice * 0.06 * 100) / 100;
          const net = Math.round((totalPrice - commission) * 100) / 100;
          
          await receivableRef.set({
            orderId,
            orderRef: db.collection('orders').doc(orderId),
            paymentGateway: 'payfast',
            source: 'online',
            status: 'available', // Make it available immediately
            gross: totalPrice,
            commission: commission,
            net: net,
            tier: 'pickup',
            commissionType: 'fixed_6_percent',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            availableAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          fixedCount++;
          console.log(`✅ Created missing receivable for order ${orderId}`);
        }
      }
    }
    
    console.log(`🎉 Fixed ${fixedCount} PayFast earnings entries`);
    console.log('📱 Sellers should now see their PayFast earnings in the app!');
    
  } catch (error) {
    console.error('❌ Error fixing PayFast earnings:', error);
  }
}

// Run the fix
fixPayfastEarnings().then(() => {
  console.log('✅ PayFast earnings fix completed');
  process.exit(0);
}).catch((error) => {
  console.error('❌ Error:', error);
  process.exit(1);
});

