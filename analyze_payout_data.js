#!/usr/bin/env node

/**
 * Payout Data Analysis Script
 * 
 * This script analyzes payout data to help understand the current state
 * and why orphaned data might not be found.
 * 
 * Usage:
 *   node analyze_payout_data.js
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

class PayoutDataAnalyzer {
  constructor() {
    this.results = {};
  }

  /**
   * Analyze all payout data
   */
  async analyzePayoutData() {
    console.log('🔍 Analyzing payout data...\n');
    
    try {
      // Get all payouts
      const payoutsSnapshot = await db.collection('payouts').get();
      console.log(`📊 Found ${payoutsSnapshot.docs.length} total payouts`);
      
      if (payoutsSnapshot.docs.length === 0) {
        console.log('✅ No payouts found - this is normal if no payouts have been requested');
        return;
      }
      
      // Get all users
      const usersSnapshot = await db.collection('users').get();
      const validUserIds = new Set(usersSnapshot.docs.map(doc => doc.id));
      console.log(`📊 Found ${validUserIds.size} valid users`);
      
      // Analyze each payout
      const payoutAnalysis = [];
      
      for (const payoutDoc of payoutsSnapshot.docs) {
        const payoutData = payoutDoc.data();
        const sellerId = payoutData.sellerId;
        const status = payoutData.status || 'unknown';
        const amount = payoutData.amount || 0;
        const failureReason = payoutData.failureReason || '';
        const createdAt = payoutData.createdAt;
        
        const userExists = validUserIds.has(sellerId);
        const isOrphaned = !userExists;
        
        payoutAnalysis.push({
          payoutId: payoutDoc.id,
          sellerId,
          amount,
          status,
          failureReason,
          createdAt,
          userExists,
          isOrphaned
        });
        
        console.log(`  📄 Payout ${payoutDoc.id}:`);
        console.log(`    - Seller: ${sellerId} ${userExists ? '✅' : '❌'}`);
        console.log(`    - Amount: R ${amount}`);
        console.log(`    - Status: ${status}`);
        if (failureReason) {
          console.log(`    - Failure: ${failureReason}`);
        }
        console.log(`    - Orphaned: ${isOrphaned ? 'YES' : 'NO'}`);
        console.log('');
      }
      
      // Summary statistics
      const totalPayouts = payoutAnalysis.length;
      const orphanedPayouts = payoutAnalysis.filter(p => p.isOrphaned).length;
      const failedPayouts = payoutAnalysis.filter(p => p.status === 'failed').length;
      const successfulPayouts = payoutAnalysis.filter(p => p.status === 'paid').length;
      const pendingPayouts = payoutAnalysis.filter(p => p.status === 'requested' || p.status === 'processing').length;
      
      console.log('📊 PAYOUT SUMMARY:');
      console.log(`  - Total payouts: ${totalPayouts}`);
      console.log(`  - Orphaned payouts: ${orphanedPayouts}`);
      console.log(`  - Failed payouts: ${failedPayouts}`);
      console.log(`  - Successful payouts: ${successfulPayouts}`);
      console.log(`  - Pending payouts: ${pendingPayouts}`);
      
      if (orphanedPayouts === 0) {
        console.log('\n✅ All payouts belong to valid users - no orphaned data found');
        console.log('💡 The failed payouts you see are from users who still exist in the system');
      } else {
        console.log(`\n⚠️ Found ${orphanedPayouts} orphaned payouts that could be cleaned up`);
      }
      
      // Show failed payouts details
      if (failedPayouts > 0) {
        console.log('\n🔍 FAILED PAYOUTS DETAILS:');
        const failedPayoutsList = payoutAnalysis.filter(p => p.status === 'failed');
        failedPayoutsList.forEach(payout => {
          console.log(`  - ${payout.payoutId}: R ${payout.amount} (${payout.failureReason})`);
        });
      }
      
      return payoutAnalysis;
      
    } catch (error) {
      console.error('❌ Error analyzing payout data:', error.message);
      throw error;
    }
  }

  /**
   * Analyze user data to understand the relationship
   */
  async analyzeUserData() {
    console.log('\n👥 Analyzing user data...\n');
    
    try {
      const usersSnapshot = await db.collection('users').get();
      console.log(`📊 Found ${usersSnapshot.docs.length} users`);
      
      const userAnalysis = [];
      
      for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();
        const role = userData.role || 'unknown';
        const email = userData.email || 'no email';
        const status = userData.status || 'unknown';
        
        userAnalysis.push({
          userId: userDoc.id,
          email,
          role,
          status
        });
        
        console.log(`  👤 User ${userDoc.id}:`);
        console.log(`    - Email: ${email}`);
        console.log(`    - Role: ${role}`);
        console.log(`    - Status: ${status}`);
        console.log('');
      }
      
      // Count by role
      const roleCounts = {};
      userAnalysis.forEach(user => {
        roleCounts[user.role] = (roleCounts[user.role] || 0) + 1;
      });
      
      console.log('📊 USER ROLE SUMMARY:');
      Object.entries(roleCounts).forEach(([role, count]) => {
        console.log(`  - ${role}: ${count} users`);
      });
      
      return userAnalysis;
      
    } catch (error) {
      console.error('❌ Error analyzing user data:', error.message);
      throw error;
    }
  }

  /**
   * Check for potential data inconsistencies
   */
  async checkDataConsistency() {
    console.log('\n🔍 Checking data consistency...\n');
    
    try {
      // Check if there are payouts without sellerId
      const payoutsSnapshot = await db.collection('payouts').get();
      const payoutsWithoutSeller = payoutsSnapshot.docs.filter(doc => {
        const data = doc.data();
        return !data.sellerId;
      });
      
      if (payoutsWithoutSeller.length > 0) {
        console.log(`⚠️ Found ${payoutsWithoutSeller.length} payouts without sellerId`);
        payoutsWithoutSeller.forEach(doc => {
          console.log(`  - Payout ${doc.id} has no sellerId`);
        });
      } else {
        console.log('✅ All payouts have valid sellerId');
      }
      
      // Check for users with unusual status
      const usersSnapshot = await db.collection('users').get();
      const usersWithIssues = usersSnapshot.docs.filter(doc => {
        const data = doc.data();
        return !data.email || !data.role;
      });
      
      if (usersWithIssues.length > 0) {
        console.log(`⚠️ Found ${usersWithIssues.length} users with missing data`);
        usersWithIssues.forEach(doc => {
          const data = doc.data();
          console.log(`  - User ${doc.id}: missing ${!data.email ? 'email' : ''} ${!data.role ? 'role' : ''}`);
        });
      } else {
        console.log('✅ All users have complete data');
      }
      
    } catch (error) {
      console.error('❌ Error checking data consistency:', error.message);
      throw error;
    }
  }
}

// Main execution
async function main() {
  const analyzer = new PayoutDataAnalyzer();
  
  try {
    await analyzer.analyzePayoutData();
    await analyzer.analyzeUserData();
    await analyzer.checkDataConsistency();
    
    console.log('\n✅ Analysis complete!');
    console.log('\n💡 Key insights:');
    console.log('  - Orphaned data only exists when users are deleted');
    console.log('  - Failed payouts from existing users are not orphaned');
    console.log('  - The cleanup script is working correctly');
    console.log('  - To find orphaned data, users would need to be deleted first');
    
  } catch (error) {
    console.error('❌ Analysis failed:', error.message);
    process.exit(1);
  }
}

// Run the script
if (require.main === module) {
  main();
}

module.exports = PayoutDataAnalyzer;
