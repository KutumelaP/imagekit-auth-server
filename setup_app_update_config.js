// Script to set up app update configuration in Firestore
// Run this to configure app update notifications

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
try {
    const serviceAccount = require('./serviceAccountKey.json');
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
} catch (error) {
    console.error("Error initializing Firebase Admin SDK. Make sure 'serviceAccountKey.json' is in the project root.");
    console.error(error);
    process.exit(1);
}

const db = admin.firestore();

async function setupAppUpdateConfig() {
    console.log('🔧 Setting up app update configuration...');
    
    const updateConfig = {
        // App version information
        latest_version: '1.0.0',
        latest_build_number: '3',
        
        // Update settings
        update_enabled: true,
        force_update: false, // Set to true to force all users to update
        
        // Update messaging
        update_title: '🚀 New Version Available!',
        update_message: 'OmniaSA v1.0.0+3 is now available with exciting new features:\n\n• Store hours fix - stores now show correct open/closed status\n• Enhanced product customization system\n• Improved AI chatbot with smarter escalation\n• Better order management and tracking\n• Performance improvements and bug fixes\n\nUpdate now to enjoy the latest features!',
        
        // Download URL (GitHub releases)
        download_url: 'https://github.com/KutumelaP/imagekit-auth-server/releases/download/v1.0.0+3/app-release.apk',
        
        // Update check settings
        check_cooldown_hours: 24, // How often to check for updates (in hours)
        
        // Metadata
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        created_by: 'admin',
    };
    
    try {
        await db.collection('app_config').doc('app_updates').set(updateConfig);
        console.log('✅ App update configuration created successfully!');
        console.log('📱 Latest version:', updateConfig.latest_version + '+' + updateConfig.latest_build_number);
        console.log('🔗 Download URL:', updateConfig.download_url);
        console.log('⏰ Check cooldown:', updateConfig.check_cooldown_hours, 'hours');
        console.log('🔒 Force update:', updateConfig.force_update ? 'Enabled' : 'Disabled');
    } catch (error) {
        console.error('❌ Error setting up app update config:', error);
    }
}

// Run the setup
setupAppUpdateConfig()
    .then(() => {
        console.log('🎉 Setup complete!');
        process.exit(0);
    })
    .catch(error => {
        console.error('💥 Setup failed:', error);
        process.exit(1);
    });
