const admin = require('firebase-admin');

// Initialize Firebase Admin (make sure you have serviceAccountKey.json in the project root)
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://marketplace-8d6bd-default-rtdb.firebaseio.com"
});

const db = admin.firestore();

async function updateAllSellersWithPudo() {
  try {
    console.log('🔍 Starting comprehensive PUDO field update for ALL sellers...');
    
    // Get ALL users with role 'seller' (no additional filters)
    const sellersSnapshot = await db.collection('users')
      .where('role', '==', 'seller')
      .get();
    
    console.log(`📊 Found ${sellersSnapshot.docs.length} sellers total`);
    
    if (sellersSnapshot.empty) {
      console.log('❌ No sellers found in the database');
      return;
    }
    
    let updatedCount = 0;
    let alreadyHasPudoCount = 0;
    
    // Process each seller
    for (const doc of sellersSnapshot.docs) {
      const data = doc.data();
      const sellerId = doc.id;
      const storeName = data.storeName || 'Unknown Store';
      const email = data.email || 'No email';
      const status = data.status || 'No status';
      
      console.log(`\n📋 Processing: ${storeName}`);
      console.log(`   - Seller ID: ${sellerId}`);
      console.log(`   - Email: ${email}`);
      console.log(`   - Status: ${status}`);
      
      // Check if pudoEnabled field exists
      if (data.hasOwnProperty('pudoEnabled')) {
        console.log(`✅ Already has pudoEnabled: ${data.pudoEnabled}`);
        alreadyHasPudoCount++;
        continue;
      }
      
      // Add missing PUDO fields with default values
      console.log(`🔧 Adding PUDO fields...`);
      
      const updateData = {
        pudoEnabled: false,
        pudoDefaultSize: 'm',
        pudoDefaultSpeed: 'standard',
        pudoAccountNumber: '',
        pudoBusinessName: '',
        pudoContactPerson: '',
        pudoContactPhone: '',
        selectedPudoLocker: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      
      try {
        await doc.ref.update(updateData);
        console.log(`✅ Successfully updated ${storeName}`);
        updatedCount++;
      } catch (error) {
        console.error(`❌ Failed to update ${storeName}:`, error.message);
      }
    }
    
    console.log('\n🎉 PUDO field update completed!');
    console.log(`📈 Final Summary:`);
    console.log(`   - Total sellers processed: ${sellersSnapshot.docs.length}`);
    console.log(`   - Already had PUDO fields: ${alreadyHasPudoCount}`);
    console.log(`   - Successfully updated: ${updatedCount}`);
    console.log(`   - Sellers now ready for PUDO: ${alreadyHasPudoCount + updatedCount}`);
    
    // Final verification - count all sellers with pudoEnabled field
    console.log('\n🔍 Final verification...');
    const allSellersSnapshot = await db.collection('users')
      .where('role', '==', 'seller')
      .get();
    
    let hasFieldCount = 0;
    let missingFieldCount = 0;
    
    allSellersSnapshot.docs.forEach(doc => {
      const data = doc.data();
      if (data.hasOwnProperty('pudoEnabled')) {
        hasFieldCount++;
      } else {
        missingFieldCount++;
        console.log(`⚠️  Still missing PUDO field: ${data.storeName || doc.id}`);
      }
    });
    
    console.log(`✅ Final count: ${hasFieldCount} sellers have PUDO fields, ${missingFieldCount} still missing`);
    
  } catch (error) {
    console.error('❌ Error during PUDO update process:', error);
  } finally {
    process.exit();
  }
}

// Run the update
updateAllSellersWithPudo();
