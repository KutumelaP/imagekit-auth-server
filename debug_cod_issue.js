const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json');
initializeApp({
  credential: require('firebase-admin/app').cert(serviceAccount)
});

const db = getFirestore();

async function debugCODIssue() {
  try {
    console.log('🔍 Debugging COD availability issue...\n');
    
    // Get current user (you'll need to replace with your actual user ID)
    console.log('Please check your current user ID in the checkout screen console logs and update this script.');
    console.log('Look for logs like: "🔍 DEBUG: Seller ID: <seller_id>"\n');
    
    // For now, let's check all recent sellers
    const usersSnapshot = await db.collection('users')
      .where('role', '==', 'seller')
      .limit(10)
      .get();
    
    console.log(`Found ${usersSnapshot.docs.length} sellers. Checking COD availability:\n`);
    
    for (const doc of usersSnapshot.docs) {
      const seller = doc.data();
      const sellerId = doc.id;
      
      console.log(`\n🏪 Seller: ${seller.storeName || 'Unknown'} (${sellerId})`);
      console.log(`   Email: ${seller.email || 'No email'}`);
      
      // Check 1: allowCOD flag
      const allowCOD = seller.allowCOD !== false;
      console.log(`   ✓ allowCOD flag: ${seller.allowCOD} -> ${allowCOD ? 'ALLOWED' : 'BLOCKED'}`);
      
      // Check 2: KYC status
      const kycStatus = seller.kycStatus || 'none';
      const kycApproved = kycStatus.toLowerCase() === 'approved';
      console.log(`   ✓ KYC status: ${kycStatus} -> ${kycApproved ? 'APPROVED' : 'NOT APPROVED'}`);
      
      // Check 3: Outstanding fees
      try {
        const payoutsSnapshot = await db.collection('users').doc(sellerId).collection('payouts').get();
        let totalDue = 0;
        
        payoutsSnapshot.forEach(payoutDoc => {
          const payout = payoutDoc.data();
          if (payout.status === 'pending') {
            totalDue += (payout.amount || 0);
          }
        });
        
        const feeThreshold = 300.0;
        const feesOk = totalDue <= feeThreshold;
        console.log(`   ✓ Outstanding fees: R${totalDue.toFixed(2)} -> ${feesOk ? 'OK' : 'OVER THRESHOLD'}`);
        
        // Final COD availability
        const codAvailable = allowCOD && kycApproved && feesOk;
        console.log(`   🎯 COD Available: ${codAvailable ? '✅ YES' : '❌ NO'}`);
        
        if (!codAvailable) {
          console.log(`   🚫 Blocked because:`);
          if (!allowCOD) console.log(`      - allowCOD flag is false`);
          if (!kycApproved) console.log(`      - KYC not approved (${kycStatus})`);
          if (!feesOk) console.log(`      - Outstanding fees R${totalDue.toFixed(2)} > R${feeThreshold}`);
        }
        
      } catch (e) {
        console.log(`   ⚠️ Error checking fees: ${e.message}`);
      }
    }
    
    console.log('\n📋 To get specific seller info for your cart:');
    console.log('1. Open checkout screen');
    console.log('2. Look for console log: "🔍 DEBUG: Seller ID: <seller_id>"');
    console.log('3. Run: node debug_specific_seller.js <seller_id>');
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

debugCODIssue();
