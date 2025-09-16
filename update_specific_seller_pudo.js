const admin = require('firebase-admin');

// Initialize Firebase Admin (make sure you have serviceAccountKey.json in the project root)
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://marketplace-8d6bd-default-rtdb.firebaseio.com"
});

const db = admin.firestore();

async function updateSpecificSellerWithPudo() {
  try {
    console.log('🔍 Looking for the test seller with email: thandokhomotso@gmail.com');
    
    // Find seller by email
    const sellerSnapshot = await db.collection('users')
      .where('email', '==', 'thandokhomotso@gmail.com')
      .where('role', '==', 'seller')
      .get();
    
    if (sellerSnapshot.empty) {
      console.log('❌ No seller found with that email');
      return;
    }
    
    const sellerDoc = sellerSnapshot.docs[0];
    const sellerId = sellerDoc.id;
    const data = sellerDoc.data();
    const storeName = data.storeName || 'Unknown Store';
    
    console.log(`📋 Found seller: ${storeName} (${sellerId})`);
    console.log(`📧 Email: ${data.email}`);
    
    // Check current PUDO status
    if (data.hasOwnProperty('pudoEnabled')) {
      console.log(`✅ Seller already has pudoEnabled: ${data.pudoEnabled}`);
    } else {
      console.log(`🔧 Adding PUDO fields to ${storeName}`);
      
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
      
      await sellerDoc.ref.update(updateData);
      console.log(`✅ Successfully updated ${storeName} with PUDO fields`);
    }
    
    // Show the updated data
    const updatedDoc = await sellerDoc.ref.get();
    const updatedData = updatedDoc.data();
    console.log('\n📊 Current PUDO fields:');
    console.log(`   - pudoEnabled: ${updatedData.pudoEnabled}`);
    console.log(`   - pudoDefaultSize: ${updatedData.pudoDefaultSize}`);
    console.log(`   - pudoDefaultSpeed: ${updatedData.pudoDefaultSpeed}`);
    console.log(`   - pargoEnabled: ${updatedData.pargoEnabled}`);
    console.log(`   - paxiEnabled: ${updatedData.paxiEnabled}`);
    
  } catch (error) {
    console.error('❌ Error updating seller with PUDO fields:', error);
  } finally {
    process.exit();
  }
}

// Run the update
updateSpecificSellerWithPudo();
