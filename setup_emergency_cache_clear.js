// Setup emergency cache clear configuration in Firestore
// Run this script to enable remote cache clearing capability

const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need your service account key)
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function setupCacheClearConfig() {
  try {
    console.log('🔧 Setting up emergency cache clear configuration...');
    
    // Create the cache management configuration
    const cacheConfig = {
      force_clear_cache: false, // Set to true to trigger cache clear for all users
      clear_version: 'initial-setup', // Change this to trigger new cache clears
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      description: 'Emergency cache clear configuration for all app users',
      instructions: 'Set force_clear_cache to true and update clear_version to trigger cache clear'
    };
    
    await db.collection('app_config').doc('cache_management').set(cacheConfig);
    
    console.log('✅ Cache clear configuration created successfully!');
    console.log('');
    console.log('📋 How to use:');
    console.log('1. Go to Firebase Console → Firestore');
    console.log('2. Navigate to app_config → cache_management');
    console.log('3. Set force_clear_cache to true');
    console.log('4. Update clear_version to a new value (e.g., "emergency-fix-001")');
    console.log('5. All users will clear cache on next app open');
    console.log('');
    console.log('🚨 Emergency Example:');
    console.log('   force_clear_cache: true');
    console.log('   clear_version: "hotfix-2024-09-18-001"');
    
    process.exit(0);
    
  } catch (error) {
    console.error('❌ Error setting up cache clear config:', error);
    process.exit(1);
  }
}

// Run the setup
setupCacheClearConfig();
