const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
const { create } = require('xmlbuilder2');

admin.initializeApp();
const db = admin.firestore();
// --- PayFast IPN/Return handlers ---
exports.payfastNotify = functions.https.onRequest(async (req, res) => {
  try {
    const data = req.method === 'POST' ? req.body : req.query;
    // Verify signature
    const passphrase = process.env.PAYFAST_PASSPHRASE || 'test_passphrase';
    const entries = Object.keys(data)
      .filter((k) => k !== 'signature' && data[k] !== undefined && data[k] !== null)
      .sort()
      .map((k) => `${k}=${encodeURIComponent(data[k])}`)
      .join('&');
    const toSign = passphrase ? `${entries}&passphrase=${passphrase}` : entries;
    const expected = crypto.createHash('md5').update(toSign).digest('hex');
    const received = String(data.signature || '').toLowerCase();
    if (expected !== received) {
      console.warn('PayFast IPN invalid signature');
      res.status(400).send('invalid');
      return;
    }

    const orderId = data.custom_str1;
    const paymentStatus = String(data.payment_status || '').toUpperCase();
    const pfPaymentId = data.pf_payment_id || '';

    if (!orderId) {
      res.status(400).send('missing order');
      return;
    }

    const updates = {
      paymentGateway: 'payfast',
      pfPaymentId,
      paymentStatus:
        paymentStatus === 'COMPLETE' ? 'paid' : paymentStatus === 'PENDING' ? 'processing_payfast' : 'failed',
      status: paymentStatus === 'COMPLETE' ? 'confirmed' : admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      trackingUpdates: admin.firestore.FieldValue.arrayUnion({
        by: 'system',
        description:
          paymentStatus === 'COMPLETE'
            ? 'Payment received via PayFast'
            : paymentStatus === 'FAILED'
            ? 'Payment failed via PayFast'
            : 'Payment pending via PayFast',
        timestamp: new Date().toISOString(),
      }),
    };
    await db.collection('orders').doc(orderId).set(updates, { merge: true });
    res.status(200).send('ok');
  } catch (e) {
    console.error('payfastNotify error', e);
    res.status(500).send('error');
  }
});

exports.payfastReturn = functions.https.onRequest(async (req, res) => {
  try {
    const orderId = req.query.custom_str1 || req.query.order_id;
    const base = process.env.PUBLIC_BASE_URL || 'https://marketplace-8d6bd.web.app';
    if (!orderId) {
      res.redirect(base);
      return;
    }
    // Redirect to app web route that shows order tracking. Mobile apps should intercept this link.
    res.redirect(`${base}/order/${orderId}`);
  } catch (e) {
    res.status(500).send('error');
  }
});

exports.payfastCancel = functions.https.onRequest(async (req, res) => {
  try {
    const base = process.env.PUBLIC_BASE_URL || 'https://marketplace-8d6bd.web.app';
    res.redirect(base);
  } catch (e) {
    res.status(500).send('error');
  }
});

// Dynamic OG meta for stores
exports.storeMeta = functions.https.onRequest(async (req, res) => {
  try {
    const storeId = req.query.id;
    if (!storeId) {
      res.status(400).send('Missing id');
      return;
    }
    const doc = await db.collection('users').doc(storeId).get();
    if (!doc.exists) {
      res.status(404).send('Store not found');
      return;
    }
    const data = doc.data() || {};
    const name = data.storeName || 'Store';
    const desc = (data.story || '').toString().slice(0, 160);
    const image = data.profileImageUrl || '';
    const base = process.env.PUBLIC_BASE_URL || 'https://marketplace-8d6bd.web.app';
    const url = `${base}/store/${storeId}`;
    res.set('Cache-Control', 'public, max-age=600');
    res.status(200).send(`<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>${name} – Mzansi Marketplace</title>
  <meta name="description" content="${desc}">
  <meta property="og:title" content="${name} – Mzansi Marketplace" />
  <meta property="og:description" content="${desc}" />
  <meta property="og:type" content="website" />
  <meta property="og:url" content="${url}" />
  ${image ? `<meta property="og:image" content="${image}" />` : ''}
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${name} – Mzansi Marketplace" />
  <meta name="twitter:description" content="${desc}" />
  ${image ? `<meta name="twitter:image" content="${image}" />` : ''}
  <meta http-equiv="refresh" content="0; url=${url}" />
  <link rel="canonical" href="${url}" />
</head>
<body>Redirecting…</body>
</html>`);
  } catch (e) {
    res.status(500).send('Error');
  }
});

// Basic sitemap.xml (stores only for now)
exports.sitemap = functions.https.onRequest(async (req, res) => {
  try {
    const base = process.env.PUBLIC_BASE_URL || 'https://marketplace-8d6bd.web.app';
    const sellers = await db.collection('users').where('role', '==', 'seller').get();
    const urls = [
      { loc: `${base}/`, changefreq: 'daily', priority: '0.8' },
    ];
    sellers.forEach((d) => {
      const id = d.id;
      urls.push({ loc: `${base}/store/${id}`, changefreq: 'daily', priority: '0.7' });
    });
    const root = create({ version: '1.0', encoding: 'UTF-8' })
      .ele('urlset', { xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9' });
    urls.forEach((u) => {
      const node = root.ele('url');
      node.ele('loc').txt(u.loc);
      node.ele('changefreq').txt(u.changefreq);
      node.ele('priority').txt(u.priority);
    });
    const xml = root.end({ prettyPrint: true });
    res.set('Content-Type', 'application/xml');
    res.set('Cache-Control', 'public, max-age=3600');
    res.status(200).send(xml);
  } catch (e) {
    res.status(500).send('Error');
  }
});

// ImageKit functions
const axios = require('axios');

const IK_API_BASE = 'https://api.imagekit.io/v1';

function isAdmin(context) {
  const token = context.auth && context.auth.token;
  return token && (token.admin === true || token.role === 'admin');
}

exports.listImages = functions.https.onCall(async (data, context) => {
  if (!isAdmin(context)) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { privateKey, path, limit = 100, skip = 0, searchQuery } = data || {};
  if (!privateKey) throw new functions.https.HttpsError('invalid-argument', 'Missing private key');

  try {
    const params = new URLSearchParams();
    params.append('limit', String(limit));
    params.append('skip', String(skip));
    if (path) params.append('path', path);
    if (searchQuery) params.append('searchQuery', searchQuery);

    const res = await axios.get(`${IK_API_BASE}/files`, {
      params,
      headers: {
        Authorization: `Basic ${Buffer.from(`${privateKey}:`).toString('base64')}`,
      },
      timeout: 20000,
    });

    // ImageKit returns an array
    return { files: res.data };
  } catch (e) {
    console.error('listImages error', e?.response?.status, e?.response?.data || e.message);
    throw new functions.https.HttpsError('internal', 'Failed to list images');
  }
});

exports.batchDeleteImages = functions.https.onCall(async (data, context) => {
  if (!isAdmin(context)) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { privateKey, fileIds } = data || {};
  if (!privateKey) throw new functions.https.HttpsError('invalid-argument', 'Missing private key');
  if (!Array.isArray(fileIds) || fileIds.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'fileIds is required');
  }

  try {
    const res = await axios.post(`${IK_API_BASE}/files/batch/deleteByFileIds`, { fileIds }, {
      headers: {
        Authorization: `Basic ${Buffer.from(`${privateKey}:`).toString('base64')}`,
        'Content-Type': 'application/json',
      },
      timeout: 20000,
    });

    return res.data;
  } catch (e) {
    console.error('batchDeleteImages error', e?.response?.status, e?.response?.data || e.message);
    throw new functions.https.HttpsError('internal', 'Failed to delete images');
  }
});

// keep existing exports below
async function sendWithRetry(message, maxAttempts = 3) {
  let attempt = 0;
  let delayMs = 250;
  while (attempt < maxAttempts) {
    try {
      const response = await admin.messaging().send(message);
      return { ok: true, response };
    } catch (error) {
      attempt += 1;
      if (attempt >= maxAttempts) {
        return { ok: false, error: String(error) };
      }
      await new Promise((r) => setTimeout(r, delayMs));
      delayMs *= 2;
    }
  }
}

exports.sendNotification = functions.runWith({ minInstances: 1, timeoutSeconds: 60, memory: '256MB' }).firestore
  .document('push_notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    
    if (!notification.to || !notification.notification) {
      console.log('Invalid notification data');
      return null;
    }

    const channelId = notification?.data?.type === 'chat_message'
      ? 'chat_channel'
      : (['order_status', 'new_order_seller', 'new_order_buyer'].includes(notification?.data?.type)
          ? 'order_channel'
          : 'basic_channel');

    const message = {
      token: notification.to,
      notification: {
        title: notification.notification.title,
        body: notification.notification.body,
      },
      data: notification.data || {},
      android: {
        notification: {
          channelId: channelId,
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: Number(notification?.data?.badge || 1),
            'content-available': 1,
          },
        },
      },
    };

    try {
      const result = await sendWithRetry(message, 3);
      if (result.ok) {
        console.log(JSON.stringify({ level: 'info', type: 'push_sent', notificationId: context.params.notificationId }));
        await admin.firestore().collection('push_status').doc(context.params.notificationId).set({
          status: 'sent',
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          to: notification.to,
          type: notification?.data?.type || 'general',
        }, { merge: true });
        await snap.ref.delete();
        return result.response;
      } else {
        console.error(JSON.stringify({ level: 'error', type: 'push_failed', notificationId: context.params.notificationId, error: result.error }));
        await admin.firestore().collection('push_notifications_dead_letter').doc(context.params.notificationId).set({
          original: notification,
          error: result.error,
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
          attempts: 3,
        });
        await snap.ref.delete();
        return null;
      }
    } catch (error) {
      console.error('Error sending notification:', error);
      return null;
    }
  });

exports.onNewMessage = functions.runWith({ minInstances: 1, timeoutSeconds: 60, memory: '256MB' }).firestore
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
      const sellerId = chatData.sellerId;
      const buyerId = chatData.buyerId;

      // Guard: ensure sender is a chat participant and IDs exist
      if (!sellerId || !buyerId) {
        console.log('Chat missing participant IDs, skipping notification');
        return null;
      }
      if (message.senderId !== sellerId && message.senderId !== buyerId) {
        console.log('Sender is not a participant of the chat, skipping notification');
        return null;
      }

      const recipientId = message.senderId === sellerId ? buyerId : sellerId;

      // Idempotency: avoid duplicate sends per message
      const idempotencyKey = `${chatId}_${context.params.messageId}`;
      const alreadySent = await admin.firestore().collection('notifications_sent').doc(idempotencyKey).get();
      if (alreadySent.exists) {
        console.log('Notification already sent for this message, skipping');
        return null;
      }

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
            channelId: 'chat_channel',
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

      const result = await sendWithRetry(notificationMessage, 3);
      if (result.ok) {
        console.log('Successfully sent chat notification');
        await admin.firestore().collection('notifications_sent').doc(idempotencyKey).set({
          chatId,
          messageId: context.params.messageId,
          recipientId,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return result.response;
      } else {
        console.error('Failed to send chat notification:', result.error);
        await admin.firestore().collection('chat_notifications_dead_letter').doc(idempotencyKey).set({
          chatId,
          messageId: context.params.messageId,
          recipientId,
          error: result.error,
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
          attempts: 3,
        });
        return null;
      }
    } catch (error) {
      console.error('Error sending chat notification:', error);
      return null;
    }
  }); 

// Mark delivered/opened status
exports.markNotificationDelivered = functions.https.onCall(async (data, context) => {
  const { notificationId, userId } = data || {};
  if (!notificationId || !userId) return { ok: false };
  await admin.firestore().collection('push_status').doc(notificationId).set({
    delivered: true,
    deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
    userId,
  }, { merge: true });
  return { ok: true };
});

exports.markNotificationOpened = functions.https.onCall(async (data, context) => {
  const { notificationId, userId } = data || {};
  if (!notificationId || !userId) return { ok: false };
  await admin.firestore().collection('push_status').doc(notificationId).set({
    opened: true,
    openedAt: admin.firestore.FieldValue.serverTimestamp(),
    userId,
  }, { merge: true });
  return { ok: true };
});

// Scheduled cleanup for old in-app notifications (>30 days)
exports.cleanupOldNotifications = functions.pubsub.schedule('every 24 hours').onRun(async () => {
  const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const snap = await admin.firestore().collection('notifications')
    .where('timestamp', '<', admin.firestore.Timestamp.fromDate(cutoff))
    .get();
  const batch = admin.firestore().batch();
  snap.docs.forEach(doc => batch.delete(doc.ref));
  await batch.commit();
  console.log(`Deleted ${snap.size} old notifications`);
  return null;
});