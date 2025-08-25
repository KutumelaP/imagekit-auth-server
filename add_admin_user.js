const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
// You'll need to download your service account key from Firebase Console
// Go to Project Settings > Service Accounts > Generate New Private Key
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function addAdminUser() {
  try {
    // Replace with the actual user UID and email
    const userId = '1wfyRBWAxnhIGGOUNtdbH4qO6yX2'; // The missing user UID
    const userEmail = 'peter@gmail.com'; // The admin email
    
    const adminUserData = {
      email: userEmail,
      role: 'admin',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      notificationsEnabled: true,
      paused: false,
      verified: true,
      // Additional admin-specific fields
      adminLevel: 'super', // or 'moderator' for different admin levels
      permissions: [
        'canViewOrders',
        'canEditOrders', 
        'canViewUsers',
        'canEditUsers',
        'canViewSettings',
        'canEditSettings',
        'canViewAuditLogs',
        'canModerate'
      ]
    };

    await db.collection('users').doc(userId).set(adminUserData);
    
    console.log('✅ Admin user added successfully!');
    console.log(`User ID: ${userId}`);
    console.log(`Email: ${userEmail}`);
    console.log('Role: admin');
    
  } catch (error) {
    console.error('❌ Error adding admin user:', error);
  } finally {
    process.exit(0);
  }
}

addAdminUser(); 