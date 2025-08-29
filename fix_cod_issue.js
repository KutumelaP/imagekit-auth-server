const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json');
initializeApp({
  credential: require('firebase-admin/app').cert(serviceAccount)
});

const db = getFirestore();

async function fixCODIssue(sellerId) {
  try {
    console.log(`🔧 Fixing COD issue for seller: ${sellerId}\n`);
    
    // Get seller document
    const sellerDoc = await db.collection('users').doc(sellerId).get();
    
    if (!sellerDoc.exists) {
      console.log('❌ Seller document not found!');
      return;
    }
    
    const seller = sellerDoc.data();
    console.log(`🏪 Fixing COD for: ${seller.storeName || 'Unknown Store'}`);
    
    const updates = {};
    let needsUpdate = false;
    
    // Fix 1: Ensure allowCOD is true
    if (seller.allowCOD !== true) {
      updates.allowCOD = true;
      needsUpdate = true;
      console.log(`✓ Setting allowCOD: true (was: ${seller.allowCOD})`);
    }
    
    // Fix 2: Ensure KYC is approved if you confirmed it should be
    const kycStatus = seller.kycStatus || 'none';
    if (kycStatus.toLowerCase() !== 'approved') {
      // Only update if you confirm this seller should have approved KYC
      console.log(`⚠️ KYC status is "${kycStatus}" - not auto-fixing`);
      console.log(`   If this seller should have approved KYC, run:`);
      console.log(`   node fix_cod_issue.js ${sellerId} --approve-kyc`);
    } else {
      console.log(`✓ KYC already approved`);
    }
    
    // Fix 3: Check outstanding fees
    try {
      const payoutsSnapshot = await db.collection('users').doc(sellerId).collection('payouts').get();
      
      let totalDue = 0;
      let pendingCount = 0;
      
      payoutsSnapshot.forEach(payoutDoc => {
        const payout = payoutDoc.data();
        if (payout.status === 'pending') {
          totalDue += (payout.amount || 0);
          pendingCount++;
        }
      });
      
      if (totalDue > 300) {
        console.log(`⚠️ Outstanding fees: R${totalDue.toFixed(2)} (${pendingCount} pending payouts)`);
        console.log(`   This will block COD. To fix, either:`);
        console.log(`   a) Process pending payouts to reduce amount below R300`);
        console.log(`   b) Increase threshold in checkout code (line 3366)`);
      } else {
        console.log(`✓ Outstanding fees OK: R${totalDue.toFixed(2)}`);
      }
    } catch (e) {
      console.log(`⚠️ Could not check fees: ${e.message}`);
    }
    
    // Apply updates
    if (needsUpdate) {
      await db.collection('users').doc(sellerId).update(updates);
      console.log(`\n✅ Updated seller document with: ${JSON.stringify(updates)}`);
    } else {
      console.log(`\n✅ No updates needed for seller document`);
    }
    
    // Handle KYC approval if requested
    const approveKyc = process.argv.includes('--approve-kyc');
    if (approveKyc && kycStatus.toLowerCase() !== 'approved') {
      const kycUpdates = {
        kycStatus: 'approved',
        kycApprovedAt: new Date(),
        kycApprovedBy: 'admin-fix-script'
      };
      
      await db.collection('users').doc(sellerId).update(kycUpdates);
      console.log(`✅ KYC approved for seller`);
    }
    
    console.log(`\n🎯 After these fixes, COD should be available!`);
    console.log(`   1. Restart your app or hot reload`);
    console.log(`   2. Navigate to checkout again`);
    console.log(`   3. Check that "Cash on Delivery" appears in payment methods`);
    console.log(`   4. Place Order button should be enabled when COD is selected`);
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

// Get arguments
const sellerId = process.argv[2];

if (!sellerId) {
  console.log('Usage: node fix_cod_issue.js <seller_id> [--approve-kyc]');
  console.log('\nTo find seller ID:');
  console.log('1. Open checkout screen in your app');
  console.log('2. Look for console log: "🔍 DEBUG: Seller ID: <seller_id>"');
  console.log('3. Copy that seller ID and run this script');
  console.log('\nOptions:');
  console.log('  --approve-kyc    Also approve KYC status (use only if seller KYC is actually verified)');
} else {
  fixCODIssue(sellerId);
}
