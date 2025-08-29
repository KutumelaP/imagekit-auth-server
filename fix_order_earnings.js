// Simple script to manually create receivable entry for existing order
// Run this with: node fix_order_earnings.js

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK  
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'marketplace-8d6bd'
});

const db = admin.firestore();

async function createReceivableEntryForOrder() {
  try {
    const orderId = '8qPP7LypByKTzkTONhCv';
    console.log('🔄 Creating receivable entry for order:', orderId);
    
    // Get the order data
    const orderRef = db.collection('orders').doc(orderId);
    const orderSnap = await orderRef.get();
    
    if (!orderSnap.exists) {
      console.error('❌ Order not found:', orderId);
      return;
    }
    
    const orderData = orderSnap.data();
    const sellerId = orderData.sellerId;
    const totalPrice = Number(orderData.totalPrice || 0);
    const platformFee = Number(orderData.platformFee || 0);
    const sellerPayout = Number(orderData.sellerPayout || 0);
    const paymentMethod = orderData.paymentMethod || 'unknown';
    
    console.log('📊 Order details:');
    console.log('  - Seller ID:', sellerId);
    console.log('  - Total Price: R' + totalPrice.toFixed(2));
    console.log('  - Platform Fee: R' + platformFee.toFixed(2));
    console.log('  - Seller Payout: R' + sellerPayout.toFixed(2));
    console.log('  - Payment Method:', paymentMethod);
    
    if (!sellerId || totalPrice <= 0) {
      console.error('❌ Invalid order data');
      return;
    }
    
    // Check if receivable entry already exists
    const receivableRef = db.collection('platform_receivables')
      .doc(sellerId)
      .collection('entries')
      .doc(orderId);
    
    const existingEntry = await receivableRef.get();
    if (existingEntry.exists) {
      console.log('ℹ️  Receivable entry already exists for this order');
      console.log('📋 Existing entry:', existingEntry.data());
      return;
    }
    
    // Create the receivable entry
    const receivableData = {
      orderId: orderId,
      orderNumber: orderData.orderNumber || orderId,
      sellerId: sellerId,
      buyerId: orderData.buyerId,
      method: paymentMethod.toLowerCase().includes('cash') ? 'COD' : 'online',
      gross: totalPrice,
      commission: platformFee,
      net: sellerPayout,
      status: 'available', // Available for payout
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      orderData: {
        totalPrice: totalPrice,
        platformFee: platformFee,
        sellerPayout: sellerPayout,
        paymentMethod: paymentMethod,
        orderType: orderData.orderType || 'unknown',
        productCategory: orderData.productCategory || 'other'
      }
    };
    
    await receivableRef.set(receivableData);
    
    console.log('✅ Successfully created receivable entry!');
    console.log('💰 Earnings should now show:');
    console.log('  - Gross: R' + totalPrice.toFixed(2));
    console.log('  - Commission: R' + platformFee.toFixed(2));
    console.log('  - Net Available: R' + sellerPayout.toFixed(2));
    
  } catch (error) {
    console.error('❌ Error creating receivable entry:', error);
  }
}

createReceivableEntryForOrder()
  .then(() => {
    console.log('🎉 Script completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('💥 Script failed:', error);
    process.exit(1);
  });
