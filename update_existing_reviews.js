const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to set up your service account key)
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function updateExistingReviews() {
  try {
    console.log('🔍 Fetching reviews with Anonymous usernames...');
    
    // Get all reviews where userName is 'Anonymous' but userEmail exists
    const reviewsSnapshot = await db.collection('reviews')
      .where('userName', '==', 'Anonymous')
      .get();
    
    console.log(`📊 Found ${reviewsSnapshot.size} reviews with Anonymous usernames`);
    
    if (reviewsSnapshot.empty) {
      console.log('✅ No reviews need updating');
      return;
    }
    
    const batch = db.batch();
    let updateCount = 0;
    
    reviewsSnapshot.forEach((doc) => {
      const reviewData = doc.data();
      const userEmail = reviewData.userEmail;
      
      if (userEmail && userEmail.includes('@')) {
        // Extract username from email (part before @)
        const username = userEmail.split('@')[0];
        
        // Update the review with the extracted username
        batch.update(doc.ref, {
          userName: username
        });
        
        updateCount++;
        console.log(`📝 Will update review ${doc.id}: ${userEmail} → ${username}`);
      } else {
        console.log(`⚠️  Skipping review ${doc.id}: No valid email found`);
      }
    });
    
    if (updateCount > 0) {
      console.log(`💾 Committing ${updateCount} updates...`);
      await batch.commit();
      console.log(`✅ Successfully updated ${updateCount} reviews`);
    } else {
      console.log('ℹ️  No reviews were updated');
    }
    
  } catch (error) {
    console.error('❌ Error updating reviews:', error);
  } finally {
    process.exit(0);
  }
}

// Run the update
updateExistingReviews();
