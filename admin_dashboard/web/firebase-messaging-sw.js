/* Firebase Messaging service worker */
importScripts('https://www.gstatic.com/firebasejs/9.22.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.2/firebase-messaging-compat.js');

// Configure with your project's web app config
self.firebaseConfig = {
  apiKey: self?.FIREBASE_API_KEY || undefined,
  authDomain: self?.FIREBASE_AUTH_DOMAIN || undefined,
  projectId: self?.FIREBASE_PROJECT_ID || 'marketplace-8d6bd',
  messagingSenderId: self?.FIREBASE_MESSAGING_SENDER_ID || '103953800507',
  appId: self?.FIREBASE_APP_ID || undefined,
};

try {
  firebase.initializeApp(self.firebaseConfig);
  const messaging = firebase.messaging();
  messaging.onBackgroundMessage((payload) => {
    const title = payload.notification?.title || 'Notification';
    const options = {
      body: payload.notification?.body,
      icon: payload.notification?.icon || '/icons/Icon-192.png',
    };
    self.registration.showNotification(title, options);
  });
} catch (e) {
  // no-op
}


