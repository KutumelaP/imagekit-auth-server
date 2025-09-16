const admin = require('firebase-admin');

// Initialize Firebase Admin (make sure you have serviceAccountKey.json in the project root)
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://marketplace-8d6bd-default-rtdb.firebaseio.com"
});

const db = admin.firestore();

async function updateExistingSellersWithPudo() {
  try {
    console.log('🔍 Starting PUDO field update for existing sellers...');
    
    // Get all users with role 'seller'
    const sellersSnapshot = await db.collection('users')
      .where('role', '==', 'seller')
      .get();
    
    console.log(`📊 Found ${sellersSnapshot.docs.length} sellers to check`);
    
    let updatedCount = 0;
    let alreadyHasPudoCount = 0;
    let batch = db.batch();
    let batchCount = 0;
    
    for (const doc of sellersSnapshot.docs) {
      const data = doc.data();
      const sellerId = doc.id;
      const storeName = data.storeName || 'Unknown Store';
      
      // Check if pudoEnabled field exists
      if (data.hasOwnProperty('pudoEnabled')) {
        console.log(`✅ ${storeName} (${sellerId}) already has pudoEnabled: ${data.pudoEnabled}`);
        alreadyHasPudoCount++;
        continue;
      }
      
      // Add missing PUDO fields with default values
      console.log(`🔧 Updating ${storeName} (${sellerId}) - adding PUDO fields`);
      
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
      
      batch.update(doc.ref, updateData);
      updatedCount++;
      batchCount++;
      
      // Firestore batch limit is 500 operations
      if (batchCount >= 500) {
        console.log(`💾 Committing batch of ${batchCount} updates...`);
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
    }
    
    // Commit any remaining updates in the batch
    if (batchCount > 0) {
      console.log(`💾 Committing final batch of ${batchCount} updates...`);
      await batch.commit();
    }
    
    console.log('🎉 PUDO field update completed!');
    console.log(`📈 Summary:`);
    console.log(`   - Total sellers checked: ${sellersSnapshot.docs.length}`);
    console.log(`   - Already had PUDO fields: ${alreadyHasPudoCount}`);
    console.log(`   - Updated with PUDO fields: ${updatedCount}`);
    console.log(`   - Sellers now ready for PUDO: ${sellersSnapshot.docs.length}`);
    
    // Verify the updates
    console.log('\n🔍 Verifying updates...');
    const verifySnapshot = await db.collection('users')
      .where('role', '==', 'seller')
      .where('pudoEnabled', '==', false)
      .get();
    
    console.log(`✅ Verification: ${verifySnapshot.docs.length} sellers now have pudoEnabled: false`);
    
  } catch (error) {
    console.error('❌ Error updating sellers with PUDO fields:', error);
  } finally {
    process.exit();
  }
}

// Run the update
updateExistingSellersWithPudo();
