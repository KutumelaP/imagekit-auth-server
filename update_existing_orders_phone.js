const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function updateExistingOrdersWithPhone() {
  try {
    console.log('🔍 Finding orders without phone numbers...');
    
    // Get all delivery tasks without phone numbers
    const tasksQuery = await db.collection('seller_delivery_tasks')
      .where('deliveryDetails.buyerPhone', 'in', ['', null])
      .get();
    
    console.log(`📋 Found ${tasksQuery.docs.length} delivery tasks without phone numbers`);
    
    let updatedCount = 0;
    const batch = db.batch();
    
    for (const taskDoc of tasksQuery.docs) {
      const taskData = taskDoc.data();
      const buyerId = taskData.deliveryDetails?.buyerId;
      
      if (!buyerId) {
        console.log(`⚠️ Skipping task ${taskDoc.id} - no buyerId`);
        continue;
      }
      
      // Try to get user's phone from their profile
      const userDoc = await db.collection('users').doc(buyerId).get();
      
      if (userDoc.exists) {
        const userData = userDoc.data();
        const userPhone = userData.phone || userData.contact || '';
        
        if (userPhone && userPhone.trim() !== '') {
          // Update the delivery task with phone number
          const taskRef = db.collection('seller_delivery_tasks').doc(taskDoc.id);
          batch.update(taskRef, {
            'deliveryDetails.buyerPhone': userPhone.trim()
          });
          
          console.log(`✅ Will update task ${taskDoc.id} with phone: ${userPhone}`);
          updatedCount++;
        } else {
          console.log(`⚠️ User ${buyerId} has no phone number in profile`);
        }
      } else {
        console.log(`⚠️ User ${buyerId} not found`);
      }
      
      // Commit in batches of 500
      if (updatedCount > 0 && updatedCount % 500 === 0) {
        await batch.commit();
        console.log(`💾 Committed batch of ${updatedCount} updates`);
      }
    }
    
    // Commit remaining updates
    if (updatedCount > 0) {
      await batch.commit();
      console.log(`💾 Final commit: ${updatedCount} tasks updated`);
    }
    
    console.log(`\n🎉 Successfully updated ${updatedCount} delivery tasks with phone numbers`);
    
    // Show summary
    console.log('\n📊 Summary:');
    console.log(`- Total tasks checked: ${tasksQuery.docs.length}`);
    console.log(`- Tasks updated: ${updatedCount}`);
    console.log(`- Tasks without phone: ${tasksQuery.docs.length - updatedCount}`);
    
  } catch (error) {
    console.error('❌ Error updating orders:', error);
  }
  
  process.exit(0);
}

// Run the update
updateExistingOrdersWithPhone();
