/* Firebase Messaging Service Worker for background web push */
importScripts('https://www.gstatic.com/firebasejs/9.6.10/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.6.10/firebase-messaging-compat.js');

// Your Firebase web config (public)
firebase.initializeApp({
  apiKey: 'AIzaSyB7r9Z3sDO_aqjZNGSoi6jVAfSrDt-wFys',
  appId: '1:578732094610:web:d11867f5b450935dea624b',
  messagingSenderId: '578732094610',
  projectId: 'marketplace-8d6bd',
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
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
  };
  self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || '/#/'
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      for (const client of clientList) {
        if ('focus' in client) {
          client.navigate(url);
          return client.focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(url);
      }
    })
  );
});

