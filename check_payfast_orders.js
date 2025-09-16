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

async function checkPayfastOrders() {
  console.log('🔍 Checking recent PayFast orders and their commission calculations...');
  
  try {
    const ordersSnapshot = await db.collection('orders')
      .where('paymentGateway', '==', 'payfast')
      .orderBy('createdAt', 'desc')
      .limit(5)
      .get();
    
    console.log(`📊 Found ${ordersSnapshot.size} PayFast orders:`);
    
    for (const orderDoc of ordersSnapshot.docs) {
      const orderData = orderDoc.data();
      console.log(`\n📦 Order ${orderDoc.id}:`);
      console.log(`   Order Number: ${orderData.orderNumber}`);
      console.log(`   Total Price: R${orderData.totalPrice}`);
      console.log(`   Created: ${orderData.createdAt?.toDate()}`);
      
      // Check receivable entry
      const receivableRef = db.collection('platform_receivables')
        .doc(orderData.sellerId)
        .collection('entries')
        .doc(orderDoc.id);
      const receivableDoc = await receivableRef.get();
      
      if (receivableDoc.exists) {
        const receivableData = receivableDoc.data();
        console.log(`   💰 ACTUAL Commission: R${receivableData.commission}`);
        console.log(`   💵 ACTUAL Net: R${receivableData.net}`);
        console.log(`   🎯 Tier: ${receivableData.tier}`);
        console.log(`   📋 Commission Type: ${receivableData.commissionType}`);
        
        // Calculate what it SHOULD be using new tiered pricing
        const gross = receivableData.gross || orderData.totalPrice || 0;
        let correctCommission = 0;
        let tier = 0;
        
        if (gross <= 15) {
          // Tier 1: 15% (R0-R15)
          tier = 1;
          correctCommission = Math.round(gross * 0.15 * 100) / 100;
        } else if (gross <= 50) {
          // Tier 2: 10% + R2 fee (R15-R50)
          tier = 2;
          correctCommission = Math.round((gross * 0.10 + 2) * 100) / 100;
        } else {
          // Tier 3: 6% (R50+)
          tier = 3;
          correctCommission = Math.round(gross * 0.06 * 100) / 100;
        }
        
        const correctNet = Math.round((gross - correctCommission) * 100) / 100;
        
        console.log(`   ✅ SHOULD BE Tier: ${tier}`);
        console.log(`   ✅ SHOULD BE Commission: R${correctCommission}`);
        console.log(`   ✅ SHOULD BE Net: R${correctNet}`);
        
        // Check if correction is needed
        if (Math.abs(receivableData.commission - correctCommission) > 0.01) {
          console.log(`   ⚠️  CORRECTION NEEDED! Overcharged by R${Math.round((receivableData.commission - correctCommission) * 100) / 100}`);
        } else {
          console.log(`   ✅ Commission is correct!`);
        }
      } else {
        console.log(`   ❌ No receivable entry found`);
      }
    }
  } catch (error) {
    console.error('❌ Error checking PayFast orders:', error);
  }
}

// Run the check
checkPayfastOrders().then(() => {
  console.log('\n✅ PayFast order check completed');
  process.exit(0);
}).catch((error) => {
  console.error('❌ Error:', error);
  process.exit(1);
});
