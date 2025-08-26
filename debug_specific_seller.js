const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json');
initializeApp({
  credential: require('firebase-admin/app').cert(serviceAccount)
});

const db = getFirestore();

async function debugSpecificSeller(sellerId) {
  try {
    console.log(`🔍 Debugging COD for seller: ${sellerId}\n`);
    
    // Get seller document
    const sellerDoc = await db.collection('users').doc(sellerId).get();
    
    if (!sellerDoc.exists) {
      console.log('❌ Seller document not found!');
      return;
    }
    
    const seller = sellerDoc.data();
    
    console.log(`🏪 Seller Details:`);
    console.log(`   Store Name: ${seller.storeName || 'Unknown'}`);
    console.log(`   Email: ${seller.email || 'No email'}`);
    console.log(`   Role: ${seller.role || 'unknown'}`);
    console.log('');
    
    // Check 1: allowCOD flag
    const allowCODRaw = seller.allowCOD;
    const allowCOD = seller.allowCOD !== false;
    console.log(`✓ COD Permission Check:`);
    console.log(`   allowCOD field: ${allowCODRaw} (type: ${typeof allowCODRaw})`);
    console.log(`   Evaluated as: ${allowCOD ? 'ALLOWED' : 'BLOCKED'}`);
    console.log('');
    
    // Check 2: KYC status
    const kycStatus = seller.kycStatus || 'none';
    const kycApproved = kycStatus.toLowerCase() === 'approved';
    console.log(`✓ KYC Status Check:`);
    console.log(`   kycStatus field: "${kycStatus}"`);
    console.log(`   Approved: ${kycApproved ? 'YES' : 'NO'}`);
    if (seller.kycApprovedAt) {
      console.log(`   Approved at: ${new Date(seller.kycApprovedAt.toDate()).toLocaleString()}`);
    }
    console.log('');
    
    // Check 3: Outstanding fees
    console.log(`✓ Outstanding Fees Check:`);
    try {
      const payoutsSnapshot = await db.collection('users').doc(sellerId).collection('payouts').get();
      
      let totalDue = 0;
      let pendingPayouts = [];
      
      payoutsSnapshot.forEach(payoutDoc => {
        const payout = payoutDoc.data();
        if (payout.status === 'pending') {
          totalDue += (payout.amount || 0);
          pendingPayouts.push({
            id: payoutDoc.id,
            amount: payout.amount || 0,
            createdAt: payout.createdAt ? new Date(payout.createdAt.toDate()).toLocaleDateString() : 'Unknown'
          });
        }
      });
      
      const feeThreshold = 300.0;
      const feesOk = totalDue <= feeThreshold;
      
      console.log(`   Total pending payouts: ${pendingPayouts.length}`);
      console.log(`   Total amount due: R${totalDue.toFixed(2)}`);
      console.log(`   Threshold: R${feeThreshold.toFixed(2)}`);
      console.log(`   Status: ${feesOk ? 'OK' : 'OVER THRESHOLD'}`);
      
      if (pendingPayouts.length > 0) {
        console.log(`   Pending payouts:`);
        pendingPayouts.forEach(p => {
          console.log(`     - R${p.amount.toFixed(2)} (${p.createdAt})`);
        });
      }
      
      console.log('');
      
      // Final result
      const codAvailable = allowCOD && kycApproved && feesOk;
      console.log(`🎯 FINAL RESULT:`);
      console.log(`   COD Available: ${codAvailable ? '✅ YES' : '❌ NO'}`);
      
      if (!codAvailable) {
        console.log(`\n🚫 COD is BLOCKED because:`);
        if (!allowCOD) console.log(`   ❌ allowCOD flag is false or missing`);
        if (!kycApproved) console.log(`   ❌ KYC not approved (status: "${kycStatus}")`);
        if (!feesOk) console.log(`   ❌ Outstanding fees R${totalDue.toFixed(2)} > R${feeThreshold.toFixed(2)}`);
        
        console.log(`\n🔧 TO FIX:`);
        if (!allowCOD) console.log(`   • Set allowCOD: true in seller document`);
        if (!kycApproved) console.log(`   • Update kycStatus to "approved" in seller document`);
        if (!feesOk) console.log(`   • Clear pending payouts or increase threshold`);
      } else {
        console.log(`\n✅ COD should be available! If button is still disabled, check:`);
        console.log(`   • Form validation (name, address, phone filled)`);
        console.log(`   • Payment method selection`);
        console.log(`   • Console logs in checkout for other issues`);
      }
      
    } catch (e) {
      console.log(`   ⚠️ Error checking fees: ${e.message}`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

// Get seller ID from command line argument
const sellerId = process.argv[2];

if (!sellerId) {
  console.log('Usage: node debug_specific_seller.js <seller_id>');
  console.log('\nTo find seller ID:');
  console.log('1. Open checkout screen in your app');
  console.log('2. Look for console log: "🔍 DEBUG: Seller ID: <seller_id>"');
  console.log('3. Copy that seller ID and run this script with it');
} else {
  debugSpecificSeller(sellerId);
}
