const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.sendNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    
    if (!notification.to || !notification.notification) {
      console.log('Invalid notification data');
      return null;
    }

    const message = {
      token: notification.to,
      notification: {
        title: notification.notification.title,
        body: notification.notification.body,
      },
      data: notification.data || {},
      android: {
        notification: {
          channelId: 'chat_messages',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);
      console.log('Successfully sent notification:', response);
      
      // Clean up the notification document
      await snap.ref.delete();
      
      return response;
    } catch (error) {
      console.error('Error sending notification:', error);
      return null;
    }
  });

// Function to send notification when a new message is added to a chat
exports.onNewMessage = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const chatId = context.params.chatId;
    
    // Don't send notification if it's the first message in the chat
    if (!message.senderId) return null;

    try {
      // Get chat details
      const chatDoc = await admin.firestore()
        .collection('chats')
        .doc(chatId)
        .get();

      if (!chatDoc.exists) return null;

      const chatData = chatDoc.data();
      const recipientId = message.senderId === chatData.sellerId ? 
                         chatData.buyerId : chatData.sellerId;

      // Get sender's name
      const senderDoc = await admin.firestore()
        .collection('users')
        .doc(message.senderId)
        .get();

      const senderName = senderDoc.data()?.displayName || 
                        senderDoc.data()?.email?.split('@')[0] || 
                        'Someone';

      // Get recipient's FCM token
      const recipientDoc = await admin.firestore()
        .collection('users')
        .doc(recipientId)
        .get();

      const fcmToken = recipientDoc.data()?.fcmToken;
      if (!fcmToken) {
        console.log('Recipient has no FCM token');
        return null;
      }

      // Send notification
      const notificationMessage = {
        token: fcmToken,
        notification: {
          title: `New message from ${senderName}`,
          body: message.text || '[Image]',
        },
        data: {
          type: 'chat_message',
          chatId: chatId,
          senderId: message.senderId,
        },
        android: {
          notification: {
            channelId: 'chat_messages',
            priority: 'high',
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      const response = await admin.messaging().send(notificationMessage);
      console.log('Successfully sent chat notification:', response);
      
      return response;
    } catch (error) {
      console.error('Error sending chat notification:', error);
      return null;
    }
  }); 