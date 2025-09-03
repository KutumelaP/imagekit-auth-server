#!/usr/bin/env node

/**
 * Delete Test Payout Data Script
 * 
 * This script removes the test payout data we identified earlier.
 * 
 * Usage:
 *   node delete_test_payouts.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  try {
    admin.initializeApp({
      credential: admin.credential.cert('./serviceAccountKey.json'),
    });
  } catch (error) {
    console.error('❌ Failed to initialize Firebase Admin:', error.message);
    process.exit(1);
  }
}

const db = admin.firestore();

async function deleteTestPayouts() {
  console.log('🗑️ Deleting test payout data...\n');
  
  try {
    // Get all payouts
    const payoutsSnapshot = await db.collection('payouts').get();
    console.log(`📊 Found ${payoutsSnapshot.docs.length} total payouts`);
    
    if (payoutsSnapshot.docs.length === 0) {
      console.log('✅ No payouts found to delete');
      return;
    }
    
    // Delete each payout from both collections
    for (const payoutDoc of payoutsSnapshot.docs) {
      const payoutData = payoutDoc.data();
      const sellerId = payoutData.sellerId;
      const payoutId = payoutDoc.id;
      
      console.log(`🗑️ Deleting payout ${payoutId} (R ${payoutData.amount}, ${payoutData.status})`);
      
      // Delete from top-level payouts collection
      await db.collection('payouts').doc(payoutId).delete();
      
      // Delete from user's personal payouts subcollection
      if (sellerId) {
        await db.collection('users').doc(sellerId).collection('payouts').doc(payoutId).delete();
        console.log(`  ✅ Deleted from users/${sellerId}/payouts/${payoutId}`);
      }
      
      console.log(`  ✅ Deleted from payouts/${payoutId}`);
    }
    
    console.log('\n✅ All test payout data has been deleted!');
    console.log('📊 Summary:');
    console.log(`  - Deleted ${payoutsSnapshot.docs.length} payout records`);
    console.log('  - Removed from both top-level and user subcollections');
    
  } catch (error) {
    console.error('❌ Error deleting test payouts:', error.message);
    throw error;
  }
}

// Main execution
async function main() {
  try {
    await deleteTestPayouts();
  } catch (error) {
    console.error('❌ Script failed:', error.message);
    process.exit(1);
  }
}

// Run the script
if (require.main === module) {
  main();
}

module.exports = { deleteTestPayouts };
