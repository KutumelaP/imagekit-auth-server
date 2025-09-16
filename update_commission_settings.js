const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();

async function updateCommissionSettings() {
  console.log('🔧 Updating commission settings to new tiered structure...');
  
  try {
    // Update admin settings with new tiered commission structure
    const settings = {
      // Legacy platform fee (now used as fallback) - set to pickup rate
      platformFeePercentage: 6.0, // Was 5%, now 6% (pickup rate)
      
      // Tiered commission rates per delivery mode
      pickupPct: 6.0,           // Pickup: 6%
      merchantDeliveryPct: 9.0,  // Seller delivery: 9%
      platformDeliveryPct: 11.0, // Platform delivery: 11%
      
      // Commission caps
      commissionMin: 5.0,                    // Min R5
      commissionCapPickup: 30.0,             // Pickup cap R30
      commissionCapDeliveryMerchant: 40.0,   // Seller delivery cap R40
      commissionCapDeliveryPlatform: 50.0,   // Platform delivery cap R50
      
      // Buyer service fees
      buyerServiceFeePct: 1.0,    // 1%
      buyerServiceFeeFixed: 3.0,  // + R3
      
      // Small order handling
      smallOrderFee: 5.0,         // R5 small order fee
      smallOrderThreshold: 50.0,  // Orders under R50
      
      // Payment processing
      payfastFeePercentage: 2.9,  // PayFast fee
      payfastFixedFee: 0.0,       // No fixed PayFast fee
      
      // Tiered pricing (order value based) - fairer for small orders
      tier1Max: 15.0,          // R0-R15 (very small orders)
      tier1Commission: 15.0,    // 15% (no fixed fee to keep it simple)
      tier1SmallOrderFee: 0.0,  // No fixed fee for tiny orders
      tier2Max: 50.0,          // R15-R50 (small-medium orders)  
      tier2Commission: 10.0,    // 10% commission
      tier2SmallOrderFee: 2.0,  // Small R2 fee
      tier3Commission: 6.0,     // 6% for larger orders (R50+)
      
      // Business settings
      holdbackPercentage: 0.0,    // No holdback
      holdbackPeriodDays: 0,      // No holdback period
      returnWindowDays: 7,        // 7 day return window
      
      // Update metadata
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: 'system_update',
      notes: 'Updated to tiered commission structure: Pickup 6%, Seller delivery 9%, Platform delivery 11%'
    };

    await db.collection('admin_settings').doc('payment_settings').set(settings, { merge: true });
    
    console.log('✅ Commission settings updated successfully!');
    console.log('📊 New structure:');
    console.log('   - Pickup: 6% (min R5, cap R30)');
    console.log('   - Seller delivery: 9% (cap R40)');
    console.log('   - Platform delivery: 11% (cap R50)');
    console.log('   - Buyer service fee: 1% + R3');
    console.log('');
    console.log('📈 Tiered Commission (by order value):');
    console.log('   - Tier 1 (R0-R15): 15% (no fixed fee)');
    console.log('   - Tier 2 (R15-R50): 10% + R2 fee');
    console.log('   - Tier 3 (R50+): 6% commission');
    
    // Verify the update
    const doc = await db.collection('admin_settings').doc('payment_settings').get();
    if (doc.exists) {
      const data = doc.data();
      console.log('\n🔍 Verification:');
      console.log(`   - Platform fee (legacy): ${data.platformFeePercentage}%`);
      console.log(`   - Pickup commission: ${data.pickupPct}%`);
      console.log(`   - Seller delivery commission: ${data.merchantDeliveryPct}%`);
      console.log(`   - Platform delivery commission: ${data.platformDeliveryPct}%`);
    }
    
  } catch (error) {
    console.error('❌ Error updating commission settings:', error);
    throw error;
  }
}

// Run the update
updateCommissionSettings()
  .then(() => {
    console.log('\n🎉 Commission settings update completed!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Update failed:', error);
    process.exit(1);
  });
