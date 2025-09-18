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

async function fixCommissionMinimum() {
  console.log('🔧 Fixing commission minimum that overrides tiered pricing...');
  
  try {
    // Update payment settings to remove the problematic R5 minimum
    await db.collection('admin_settings').doc('payment_settings').update({
      commissionMin: 0.50, // Set to 50 cents - much more reasonable for small orders
      notes: 'Updated commission minimum to R0.50 to allow tiered pricing to work correctly for small orders',
      updatedBy: 'commission_fix',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log('✅ Updated commission minimum from R5 to R0.50');
    
    // Now fix existing receivable entries that were overcharged
    console.log('🔄 Fixing overcharged receivable entries...');
    
    // Get all recent receivable entries with high commission rates
    const receivablesSnapshot = await db.collectionGroup('entries')
      .where('paymentGateway', '==', 'payfast')
      .where('commission', '>=', 3)
      .get();
    
    console.log(`📊 Found ${receivablesSnapshot.size} potentially overcharged entries`);
    
    let fixedCount = 0;
    
    for (const receivableDoc of receivablesSnapshot.docs) {
      const receivableData = receivableDoc.data();
      const gross = receivableData.gross || 0;
      const currentCommission = receivableData.commission || 0;
      
      // Calculate correct commission using tiered pricing
      let correctCommission = 0;
      let tier = 0;
      
      if (gross <= 15) {
        // Tier 1: 15% (R0-R15)
        tier = 1;
        correctCommission = Math.max(0.50, Math.round(gross * 0.15 * 100) / 100);
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
      
      // Only fix if there's a significant difference (more than 1 cent)
      if (Math.abs(currentCommission - correctCommission) > 0.01) {
        console.log(`🔄 Fixing order ${receivableData.orderId}:`);
        console.log(`   Gross: R${gross}`);
        console.log(`   Old Commission: R${currentCommission} -> New: R${correctCommission}`);
        console.log(`   Old Net: R${receivableData.net} -> New: R${correctNet}`);
        
        await receivableDoc.ref.update({
          commission: correctCommission,
          net: correctNet,
          tier: tier,
          commissionType: 'tiered_pricing_corrected',
          correctedAt: admin.firestore.FieldValue.serverTimestamp(),
          correctionReason: 'Fixed R5 minimum override on small orders',
        });
        
        fixedCount++;
      }
    }
    
    console.log(`🎉 Fixed ${fixedCount} overcharged commission entries`);
    console.log('📱 Sellers should now see correct earnings amounts!');
    
  } catch (error) {
    console.error('❌ Error fixing commission minimum:', error);
  }
}

// Run the fix
fixCommissionMinimum().then(() => {
  console.log('✅ Commission minimum fix completed');
  process.exit(0);
}).catch((error) => {
  console.error('❌ Error:', error);
  process.exit(1);
});

