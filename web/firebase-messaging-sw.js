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
      console.log('🔥 Received background message:', payload);
      
      const data = payload?.data || {};
      const title = payload?.notification?.title || 'Mzansi Marketplace';
      const body = payload?.notification?.body || '';
      const type = data.type || 'general';

      // Map to URL for deep linking
      let url = '/#/'
      if (type === 'chat_message' && data.chatId) {
        url = `/#/chat?chatId=${encodeURIComponent(data.chatId)}`;
      } else if ((type === 'order_status' || type === 'new_order_seller' || type === 'new_order_buyer') && data.orderId && data.orderId.trim() !== '') {
        url = `/#/seller-order-detail?orderId=${encodeURIComponent(data.orderId)}`;
      }

      // 🚀 AWESOME NOTIFICATION OPTIONS
      const options = {
        body,
        data: { 
          url,
          type,
          timestamp: Date.now(),
          ...data
        },
        icon: getNotificationIcon(type),
        badge: '/icons/Icon-192.png',
        tag: `${type}_${data.orderId || data.chatId || Date.now()}`, // Unique tags
        
        // 🎨 Visual Enhancements
        image: getNotificationImage(type, data),
        
        // 🔔 Interaction & Behavior
        requireInteraction: isHighPriority(type),
        silent: false,
        
        // 📱 Mobile Features
        vibrate: getVibrationPattern(type),
        
        // 🎯 Action Buttons
        actions: getNotificationActions(type, data),
        
        // 🏷️ Rich Metadata
        dir: 'ltr',
        lang: 'en',
        renotify: true,
        
        // 🌟 Advanced Features
        timestamp: Date.now(),
      };
      
      console.log('🚀 Showing awesome notification:', options);
      self.registration.showNotification(title, options);
      
      // 📊 Analytics
      logNotificationEvent('background_notification_shown', { type, title });
      
    } catch (error) {
      console.error('❌ Error handling background message:', error);
    }
  });
}

// 🎨 Get dynamic notification icon based on type
function getNotificationIcon(type) {
  const iconMap = {
    'chat_message': '/icons/chat-icon.png',
    'new_order_seller': '/icons/order-icon.png',
    'new_order_buyer': '/icons/cart-icon.png',
    'order_status': '/icons/delivery-icon.png',
    'payment_success': '/icons/success-icon.png',
    'payment_failed': '/icons/error-icon.png',
    'promotion': '/icons/promo-icon.png',
    'system': '/icons/system-icon.png'
  };
  return iconMap[type] || '/icons/Icon-192.png';
}

// 🖼️ Get notification image for rich display
function getNotificationImage(type, data) {
  if (type === 'new_order_seller' && data.productImage) {
    return data.productImage;
  }
  if (type === 'promotion' && data.promoImage) {
    return data.promoImage;
  }
  // Default rich image
  return '/icons/notification-hero.png';
}

// ⚡ Get vibration pattern based on notification type
function getVibrationPattern(type) {
  const patterns = {
    'chat_message': [100, 50, 100], // Quick double buzz
    'new_order_seller': [200, 100, 200, 100, 200], // Triple buzz for orders
    'new_order_buyer': [300, 200, 300], // Strong buzz for buyer notifications
    'order_status': [150, 100, 150], // Medium buzz
    'payment_success': [50, 25, 50, 25, 50, 25, 200], // Success melody
    'payment_failed': [400, 200, 400], // Alert pattern
    'promotion': [100, 50, 100, 50, 100], // Attention pattern
  };
  return patterns[type] || [200, 100, 200];
}

// 🎯 Get action buttons for notification
function getNotificationActions(type, data) {
  const actions = {
    'chat_message': [
      { action: 'reply', title: '💬 Reply', icon: '/icons/reply-icon.png' },
      { action: 'view', title: '👀 View Chat', icon: '/icons/view-icon.png' }
    ],
    'new_order_seller': [
      { action: 'accept', title: '✅ Accept Order', icon: '/icons/accept-icon.png' },
      { action: 'view', title: '📋 View Details', icon: '/icons/view-icon.png' }
    ],
    'new_order_buyer': [
      { action: 'track', title: '📍 Track Order', icon: '/icons/track-icon.png' },
      { action: 'view', title: '📋 View Order', icon: '/icons/view-icon.png' }
    ],
    'order_status': [
      { action: 'track', title: '📍 Track', icon: '/icons/track-icon.png' },
      { action: 'contact', title: '📞 Contact Seller', icon: '/icons/contact-icon.png' }
    ],
    'payment_success': [
      { action: 'receipt', title: '🧾 View Receipt', icon: '/icons/receipt-icon.png' },
      { action: 'share', title: '📤 Share', icon: '/icons/share-icon.png' }
    ],
    'promotion': [
      { action: 'shop', title: '🛒 Shop Now', icon: '/icons/shop-icon.png' },
      { action: 'save', title: '💾 Save Offer', icon: '/icons/save-icon.png' }
    ]
  };
  return actions[type] || [
    { action: 'view', title: '👀 View', icon: '/icons/view-icon.png' }
  ];
}

// 🔥 Check if notification should require interaction
function isHighPriority(type) {
  const highPriorityTypes = ['payment_failed', 'order_cancelled', 'urgent_message'];
  return highPriorityTypes.includes(type);
}

// 📊 Log notification events for analytics
function logNotificationEvent(event, data) {
  try {
    console.log(`📊 Notification Analytics: ${event}`, data);
    // Could send to analytics service here
  } catch (error) {
    console.error('❌ Error logging notification event:', error);
  }
}

// 🚀 AWESOME NOTIFICATION CLICK HANDLER
self.addEventListener('notificationclick', function(event) {
  try {
    console.log('🎯 Notification clicked:', event.notification);
    console.log('🎯 Action clicked:', event.action);
    
    const data = event.notification.data || {};
    const notificationType = data.type || 'general';
    const action = event.action;
    
    // Close the notification
    event.notification.close();
    
    // 📊 Log click analytics
    logNotificationEvent('notification_clicked', { type: notificationType, action });
    
    // Handle different actions
    if (action === 'reply' && notificationType === 'chat_message') {
      // Open chat with reply interface
      event.waitUntil(handleChatReply(data));
    } else if (action === 'accept' && notificationType === 'new_order_seller') {
      // Quick accept order
      event.waitUntil(handleQuickOrderAccept(data));
    } else if (action === 'track') {
      // Open tracking page
      event.waitUntil(openAppPage(`/#/track-order?orderId=${data.orderId}`));
    } else if (action === 'shop' && notificationType === 'promotion') {
      // Open promo page
      event.waitUntil(openAppPage(`/#/promotions?promoId=${data.promoId}`));
    } else {
      // Default action - open the main URL
      const url = data.url || '/#/';
      event.waitUntil(openAppPage(url));
    }
    
  } catch (error) {
    console.error('❌ Error handling notification click:', error);
    // Fallback: open main app
    event.waitUntil(openAppPage('/#/'));
  }
});

// 🚀 Handle notification action button clicks
self.addEventListener('notificationclose', function(event) {
  try {
    console.log('🔔 Notification closed:', event.notification);
    const data = event.notification.data || {};
    logNotificationEvent('notification_closed', { type: data.type });
  } catch (error) {
    console.error('❌ Error handling notification close:', error);
  }
});

// 💬 Handle chat reply action
async function handleChatReply(data) {
  try {
    console.log('💬 Handling chat reply for:', data.chatId);
    
    // Show a quick reply notification or open chat directly
    await openAppPage(`/#/chat?chatId=${data.chatId}&action=reply`);
    
    // Could also show a quick reply interface here
    showQuickReplyNotification(data);
    
  } catch (error) {
    console.error('❌ Error handling chat reply:', error);
  }
}

// ✅ Handle quick order accept
async function handleQuickOrderAccept(data) {
  try {
    console.log('✅ Quick accepting order:', data.orderId);
    
    // Show confirmation notification
    self.registration.showNotification('Order Processing...', {
      body: `Processing order ${data.orderId}`,
      icon: '/icons/processing-icon.png',
      tag: 'order_processing',
      silent: true,
      actions: [
        { action: 'view', title: '📋 View Details', icon: '/icons/view-icon.png' }
      ]
    });
    
    // Open order details
    await openAppPage(`/#/seller-order-detail?orderId=${data.orderId}&action=accept`);
    
  } catch (error) {
    console.error('❌ Error handling quick order accept:', error);
  }
}

// 📱 Smart app page opening
async function openAppPage(url) {
  try {
    console.log('📱 Opening app page:', url);
    
    // Try to focus existing window first
    const windowClients = await clients.matchAll({
      type: 'window',
      includeUncontrolled: true
    });
    
    // Check if app is already open
    for (const client of windowClients) {
      if (client.url.includes(self.location.origin)) {
        console.log('🎯 Focusing existing window');
        await client.focus();
        
        // Navigate to the specific page
        if (client.navigate) {
          await client.navigate(url);
        } else {
          // Fallback: post message to navigate
          client.postMessage({
            type: 'NAVIGATE',
            url: url
          });
          
          // 🏪 Special handling for store URLs
          if (url.includes('/store/')) {
            console.log('🏪 Store URL detected, ensuring proper routing');
          }
        }
        return;
      }
    }
    
    // No existing window, open new one
    console.log('🆕 Opening new window');
    await clients.openWindow(url);
    
  } catch (error) {
    console.error('❌ Error opening app page:', error);
    // Fallback
    try {
      await clients.openWindow('/#/');
    } catch (fallbackError) {
      console.error('❌ Fallback error:', fallbackError);
    }
  }
}

// 💬 Show quick reply notification
function showQuickReplyNotification(data) {
  try {
    self.registration.showNotification('Quick Reply', {
      body: 'Tap to reply quickly or open chat for full conversation',
      icon: '/icons/quick-reply-icon.png',
      tag: 'quick_reply',
      requireInteraction: true,
      actions: [
        { action: 'quick_reply', title: '⚡ Quick Reply', icon: '/icons/quick-icon.png' },
        { action: 'open_chat', title: '💬 Open Chat', icon: '/icons/chat-icon.png' }
      ],
      data: {
        type: 'quick_reply',
        originalChatId: data.chatId
      }
    });
  } catch (error) {
    console.error('❌ Error showing quick reply notification:', error);
  }
}



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

