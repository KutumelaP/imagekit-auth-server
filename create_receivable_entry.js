const { initializeApp } = require('firebase/app');
const { getFunctions, httpsCallable } = require('firebase/functions');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');

// Firebase config
const firebaseConfig = {
  apiKey: "AIzaSyDCtpHKT2qLhVKN6hJ3WIEtj_PTjV5UvBo",
  authDomain: "marketplace-8d6bd.firebaseapp.com",
  projectId: "marketplace-8d6bd",
  storageBucket: "marketplace-8d6bd.appspot.com",
  messagingSenderId: "648477936440",
  appId: "1:648477936440:web:6c4b3e9f4d5c9d7e2f5c8a"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const functions = getFunctions(app);
const auth = getAuth(app);

async function createReceivableEntry() {
  try {
    console.log('🔄 Creating receivable entry for order...');
    
    // You'll need to sign in as the seller or admin
    // For now, let's try calling the function directly
    const createReceivable = httpsCallable(functions, 'createReceivableEntry');
    
    const result = await createReceivable({
      orderId: '8qPP7LypByKTzkTONhCv'
    });
    
    console.log('✅ Success:', result.data);
    
  } catch (error) {
    console.error('❌ Error:', error);
    
    if (error.code === 'functions/unauthenticated') {
      console.log('ℹ️  Authentication required. Please sign in as the seller or admin first.');
    }
  }
}

createReceivableEntry();
