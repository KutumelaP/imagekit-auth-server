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

async function fixOrderTotals() {
  console.log('🔧 Fixing R0.00 display issue for existing orders...');
  
  try {
    const sellerId = 'huuuam3H8uOQcFBY0VzGYl5GtJG2';
    
    // Get the seller's orders that show R0.00
    const ordersSnapshot = await db.collection('orders')
      .where('sellerId', '==', sellerId)
      .get();
    
    console.log(`📊 Found ${ordersSnapshot.size} orders to check`);
    
    for (const orderDoc of ordersSnapshot.docs) {
      const orderData = orderDoc.data();
      const orderId = orderDoc.id;
      const currentTotalPrice = orderData.totalPrice;
      const pricingGrandTotal = orderData.pricing?.grandTotal;
      
      console.log(`\n📦 Order ${orderId}:`);
      console.log(`   Current totalPrice: ${currentTotalPrice}`);
      console.log(`   Pricing grandTotal: ${pricingGrandTotal}`);
      
      // If totalPrice is missing or 0, but we have pricing.grandTotal
      if ((!currentTotalPrice || currentTotalPrice === 0) && pricingGrandTotal > 0) {
        console.log(`   🔄 FIXING: Setting totalPrice to ${pricingGrandTotal}`);
        
        await orderDoc.ref.update({
          totalPrice: pricingGrandTotal,
          totalAmount: pricingGrandTotal,
          subtotal: orderData.pricing?.subtotal || pricingGrandTotal,
          deliveryFee: orderData.pricing?.deliveryFee || 0,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          fixApplied: 'total_price_correction',
        });
        
        console.log(`   ✅ FIXED! totalPrice: 0 -> ${pricingGrandTotal}`);
      } else if (currentTotalPrice > 0) {
        console.log(`   ✅ Already has correct totalPrice: ${currentTotalPrice}`);
      } else {
        console.log(`   ⚠️  No pricing data available to fix`);
      }
    }
    
    console.log('\n🎉 Order totals fix completed!');
    console.log('📱 Your app should now show correct totals after reloading!');
    
  } catch (error) {
    console.error('❌ Error fixing order totals:', error);
  }
}

// Run the fix
fixOrderTotals().then(() => {
  console.log('✅ Order totals fix completed');
  process.exit(0);
}).catch((error) => {
  console.error('❌ Error:', error);
  process.exit(1);
});
