const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to add your service account key)
// admin.initializeApp({
//   credential: admin.credential.applicationDefault(),
//   // or use a service account key file
//   // credential: admin.credential.cert(require('./path-to-service-account.json')),
// });

async function createTestUser() {
  try {
    // Create a test user
    const userRecord = await admin.auth().createUser({
      email: 'test@example.com',
      password: 'test123456',
      displayName: 'Test User',
      emailVerified: true,
    });

    console.log('Successfully created test user:', userRecord.uid);

    // Create user document in Firestore
    await admin.firestore().collection('users').doc(userRecord.uid).set({
      email: 'test@example.com',
      displayName: 'Test User',
      role: 'customer',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      favoriteStores: [],
      cart: [],
    });

    console.log('Successfully created user document in Firestore');

    return userRecord;
  } catch (error) {
    console.error('Error creating test user:', error);
    throw error;
  }
}

// Usage instructions:
console.log(`
To create a test user for review functionality testing:

1. Install Firebase Admin SDK:
   npm install firebase-admin

2. Set up Firebase Admin credentials:
   - Download your service account key from Firebase Console
   - Place it in your project directory
   - Update the admin.initializeApp() call above

3. Run this script:
   node create_test_user.js

4. Use the created account to test reviews:
   Email: test@example.com
   Password: test123456

Note: This is for testing purposes only. In production, users should create their own accounts.
`);

// Uncomment the line below to actually create the test user
// createTestUser(); 