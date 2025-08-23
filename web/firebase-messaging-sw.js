/* Firebase Messaging Service Worker for background web push */
importScripts('https://www.gstatic.com/firebasejs/9.6.10/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.6.10/firebase-messaging-compat.js');

// Your Firebase web config (public)
const firebaseConfig = {
  apiKey: 'AIzaSyB7r9Z3sDO_aqjZNGSoi6jVAfSrDt-wFys',
  appId: '1:578732094610:web:d11867f5b450935dea624b',
  messagingSenderId: '578732094610',
  projectId: 'marketplace-8d6bd',
};

// Initialize Firebase with error handling
try {
  firebase.initializeApp(firebaseConfig);
  console.log('Firebase initialized successfully in service worker');
} catch (error) {
  console.error('Failed to initialize Firebase in service worker:', error);
}

// Initialize messaging with error handling
let messaging;
try {
  messaging = firebase.messaging();
  console.log('Firebase messaging initialized successfully');
} catch (error) {
  console.error('Failed to initialize Firebase messaging:', error);
}

// Handle background messages with error handling
if (messaging) {
  messaging.onBackgroundMessage((payload) => {
    try {
      console.log('Received background message:', payload);
      
      const data = payload?.data || {};
      const title = payload?.notification?.title || 'Notification';
      const body = payload?.notification?.body || '';
      const type = data.type || 'general';

      // Map to URL for deep linking
      let url = '/#/'
      if (type === 'chat_message' && data.chatId) {
        url = `/#/chat?chatId=${encodeURIComponent(data.chatId)}`;
      } else if ((type === 'order_status' || type === 'new_order_seller' || type === 'new_order_buyer') && data.orderId && data.orderId.trim() !== '') {
        url = `/#/seller-order-detail?orderId=${encodeURIComponent(data.orderId)}`;
      }

      const options = {
        body,
        data: { url },
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
        tag: type, // Group notifications by type
        requireInteraction: false,
        silent: false,
        vibrate: [200, 100, 200],
      };
      
      self.registration.showNotification(title, options);
    } catch (error) {
      console.error('Error handling background message:', error);
    }
  });
}

// Handle notification clicks with error handling
self.addEventListener('notificationclick', function(event) {
  try {
    console.log('Notification clicked:', event.notification);
    event.notification.close();
    
    const url = (event.notification.data && event.notification.data.url) || '/#/';
    
    event.waitUntil(
      self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
        // Try to focus existing window first
        for (const client of clientList) {
          if ('focus' in client) {
            client.navigate(url);
            return client.focus();
          }
        }
        
        // If no existing window, open a new one
        if (self.clients.openWindow) {
          return self.clients.openWindow(url);
        }
      }).catch(function(error) {
        console.error('Error handling notification click:', error);
        // Fallback: try to open window directly
        if (self.clients.openWindow) {
          return self.clients.openWindow(url);
        }
      })
    );
  } catch (error) {
    console.error('Error in notification click handler:', error);
  }
});

// Handle service worker installation
self.addEventListener('install', function(event) {
  console.log('FCM Service Worker installing...');
  self.skipWaiting();
});

// Handle service worker activation
self.addEventListener('activate', function(event) {
  console.log('FCM Service Worker activating...');
  event.waitUntil(self.clients.claim());
});

// Handle messages from main thread (for testing)
self.addEventListener('message', function(event) {
  try {
    console.log('Received message in service worker:', event.data);
    
    if (event.data && event.data.type === 'TEST_NOTIFICATION') {
      const { title, body, icon } = event.data;
      
      self.registration.showNotification(title, {
        body,
        icon: icon || '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
        tag: 'test',
        requireInteraction: false,
        silent: false,
        vibrate: [200, 100, 200],
      });
      
      // Send response back to main thread
      event.ports[0]?.postMessage({ success: true, message: 'Test notification shown' });
    }
  } catch (error) {
    console.error('Error handling message in service worker:', error);
    event.ports[0]?.postMessage({ success: false, error: error.message });
  }
});

// Handle service worker errors
self.addEventListener('error', function(event) {
  console.error('Service Worker error:', event.error);
});

// Handle unhandled promise rejections
self.addEventListener('unhandledrejection', function(event) {
  console.error('Service Worker unhandled rejection:', event.reason);
});

