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

async function fixSpecificOrder() {
  console.log('🔧 Fixing the specific overcharged PayFast order...');
  
  try {
    // Your seller ID
    const sellerId = 'huuuam3H8uOQcFBY0VzGYl5GtJG2';
    
    // Check all entries for this seller
    const entriesSnapshot = await db.collection('platform_receivables')
      .doc(sellerId)
      .collection('entries')
      .get();
    
    console.log(`📊 Found ${entriesSnapshot.size} entries for seller`);
    
    for (const entryDoc of entriesSnapshot.docs) {
      const entryData = entryDoc.data();
      const gross = entryData.gross || 0;
      const currentCommission = entryData.commission || 0;
      const orderId = entryData.orderId;
      
      console.log(`\n📦 Order ${orderId}:`);
      console.log(`   Gross: R${gross}`);
      console.log(`   Current Commission: R${currentCommission}`);
      
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
      
      console.log(`   Correct Commission (Tier ${tier}): R${correctCommission}`);
      console.log(`   Correct Net: R${correctNet}`);
      
      // Fix if there's a significant difference
      if (Math.abs(currentCommission - correctCommission) > 0.01) {
        console.log(`   🔄 FIXING: Overcharged by R${Math.round((currentCommission - correctCommission) * 100) / 100}`);
        
        await entryDoc.ref.update({
          commission: correctCommission,
          net: correctNet,
          tier: tier,
          commissionType: 'tiered_pricing_corrected',
          correctedAt: admin.firestore.FieldValue.serverTimestamp(),
          correctionReason: 'Fixed R5 minimum override - applied correct tiered pricing',
          oldCommission: currentCommission,
          oldNet: entryData.net,
        });
        
        console.log(`   ✅ FIXED! Commission: R${currentCommission} -> R${correctCommission}`);
      } else {
        console.log(`   ✅ Already correct!`);
      }
    }
    
  } catch (error) {
    console.error('❌ Error fixing specific order:', error);
  }
}

// Run the fix
fixSpecificOrder().then(() => {
  console.log('\n✅ Specific order fix completed');
  console.log('📱 Check your earnings - they should now show the correct amounts!');
  process.exit(0);
}).catch((error) => {
  console.error('❌ Error:', error);
  process.exit(1);
});
