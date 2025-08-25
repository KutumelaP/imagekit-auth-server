const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
const { create } = require('xmlbuilder2');
const nodemailer = require('nodemailer');
// Helper: PHP-style urlencode (spaces as '+') for PayFast signature
function pfEncode(value) {
  return encodeURIComponent(String(value))
    .replace(/%20/g, '+')
    .replace(/%0D%0A/g, '%0A'); // normalize CRLF to LF as per PayFast notes
}
// WebAuthn (Passkeys)
const {
  generateRegistrationOptions,
  verifyRegistrationResponse,
  generateAuthenticationOptions,
  verifyAuthenticationResponse,
} = require('@simplewebauthn/server');

admin.initializeApp();
const db = admin.firestore();
const axios = require('axios');
// --- PayFast IPN/Return handlers ---
exports.payfastNotify = functions.https.onRequest(async (req, res) => {
  try {
    const data = req.method === 'POST' ? req.body : req.query;
    const passphrase = process.env.PAYFAST_PASSPHRASE || 'PeterKutumela2025';
    // Verify signature (PayFast requires signature even if dashboard toggle shows Off for some accounts)
    const entries = Object.keys(data)
      .filter((k) => k !== 'signature' && data[k] !== undefined && data[k] !== null)
      .sort()
      .map((k) => `${k}=${pfEncode(data[k])}`)
      .join('&');
    const toSign = passphrase ? `${entries}&passphrase=${passphrase}` : entries;
    const expected = crypto.createHash('md5').update(toSign).digest('hex');
    const received = String(data.signature || '').toLowerCase();
    console.log('[payfastNotify] entries=', entries);
    console.log('[payfastNotify] expected_sig=', expected, 'received_sig=', received);
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
    if (paymentStatus === 'COMPLETE') {
      try {
        // Wallet top-up handling
        const customType = String(data.custom_str4 || '');
        if (orderId.startsWith('WALLET_') || customType === 'wallet_topup') {
          const buyerUid = String(data.custom_str3 || '').trim();
          const sellerIdForDues = String(data.custom_str2 || '').trim();
          const amountGross = Number(data.amount_gross || 0);
          if (buyerUid) {
            const wref = db.collection('seller_wallet').doc(buyerUid);
            await db.runTransaction(async (tx) => {
              const snap = await tx.get(wref);
              const bal = snap.exists ? Number(snap.data().balance || 0) : 0;
              tx.set(wref, { balance: bal + amountGross, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
            });
            // Auto-settle dues for referenced sellerId (if provided)
            if (sellerIdForDues) {
              const dueSnap = await db.collection('platform_receivables').doc(sellerIdForDues)
                .collection('entries').where('status','==','due').get();
              let remaining = amountGross;
              const batch = db.batch();
              dueSnap.docs.forEach(doc => {
                const d = doc.data() || {};
                const amt = Number(d.amount || 0);
                if (remaining > 0 && amt > 0) {
                  const pay = Math.min(remaining, amt);
                  remaining -= pay;
                  batch.update(doc.ref, { status: 'collected', collectedAt: admin.firestore.FieldValue.serverTimestamp(), collectedVia: 'wallet_topup' });
                }
              });
              if (dueSnap.size > 0) await batch.commit();
            }
          }
          res.status(200).send('ok');
          return;
        }

        const orderSnap = await db.collection('orders').doc(orderId).get();
        const order = orderSnap.data() || {};
        const sellerId = order.sellerId;
        const buyerId = order.buyerId;
        const totalPrice = order.totalPrice || 0;
        // Net-off any COD receivables for this seller
        try {
          if (sellerId) {
            const dueSnap = await db.collection('platform_receivables').doc(sellerId)
              .collection('entries').where('status','==','due').get();
            let totalDue = 0;
            const batch = db.batch();
            dueSnap.docs.forEach(doc => {
              const d = doc.data() || {};
              const amt = Number(d.amount || 0);
              if (amt > 0) {
                totalDue += amt;
                batch.update(doc.ref, { status: 'collected', collectedAt: admin.firestore.FieldValue.serverTimestamp(), collectedVia: 'net_off_payfast' });
              }
            });
            if (dueSnap.size > 0) {
              await batch.commit();
              await db.collection('platform_receivables').doc(sellerId).collection('settlements').add({
                method: 'net_off_payfast',
                amountCollected: totalDue,
                onOrderId: orderId,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              console.log(`[cod] Net-off collected R${totalDue.toFixed(2)} from seller ${sellerId} on PayFast COMPLETE order ${orderId}`);
            }
          }
        } catch (e) {
          console.warn('[cod] Net-off failed', e);
        }
        const sellerDoc = sellerId ? await db.collection('users').doc(sellerId).get() : null;
        const sellerName = sellerDoc && sellerDoc.exists ? (sellerDoc.data().storeName || sellerDoc.data().name || 'Store') : 'Store';
        // Lightweight notifications collection write for seller and buyer
        if (sellerId) {
          await db.collection('notifications').add({
            userId: sellerId,
            title: 'New Order Received',
            body: `A paid order has been placed for R${Number(totalPrice).toFixed(2)}`,
            type: 'new_order_seller',
            orderId,
            read: false,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        if (buyerId) {
          await db.collection('notifications').add({
            userId: buyerId,
            title: 'Order Confirmed',
            body: `Your order has been confirmed. Seller: ${sellerName}`,
            type: 'order_status',
            orderId,
            read: false,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // 3) Ledger entry (escrow/receivable) for online (PayFast) payments
        try {
          if (sellerId && Number(totalPrice) > 0) {
            // Commission percent from admin settings (fallback to env)
            let commissionPct = Number(process.env.PLATFORM_COMMISSION_PCT || 0.1);
            try {
              const feeDoc = await db.collection('admin_settings').doc('payment_settings').get();
              const feeData = feeDoc.exists ? feeDoc.data() : {};
              const cfgPct = Number(feeData?.platformFeePercentage);
              if (!isNaN(cfgPct) && cfgPct >= 0 && cfgPct <= 0.5) {
                commissionPct = cfgPct / 100; // stored as percent in UI
              }
            } catch (_) {}
            const gross = Math.round(Number(totalPrice) * 100) / 100;
            const commission = Math.round(gross * commissionPct * 100) / 100;
            const net = Math.round((gross - commission) * 100) / 100;
            const eref = db
              .collection('platform_receivables')
              .doc(sellerId)
              .collection('entries')
              .doc(orderId);
            await eref.set(
              {
                orderId,
                orderRef: db.collection('orders').doc(orderId),
                paymentGateway: 'payfast',
                pfPaymentId: pfPaymentId || null,
                source: 'online',
                status: 'held', // becomes 'available' on delivery/confirmation
                gross,
                commission,
                net,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
          }
        } catch (e) {
          console.warn('[ledger] Failed to write receivable entry', e);
        }
      } catch (e) {
        console.warn('notify on paid error', e);
      }
    }
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

// HTML bridge: convert query params to a POST form submission to PayFast
exports.payfastFormRedirect = functions.https.onRequest(async (req, res) => {
  try {
    const target = (req.query.sandbox === 'true')
      ? 'https://sandbox.payfast.co.za/eng/process'
      : 'https://www.payfast.co.za/eng/process';
    const data = req.method === 'POST' ? req.body : req.query;

    // Basic allowlist of expected fields to avoid echoing arbitrary input
    const allowed = new Set([
      'merchant_id','merchant_key','return_url','cancel_url','notify_url',
      'amount','item_name','item_description','email_address','name_first','name_last','cell_number',
      'm_payment_id','custom_str1','custom_str2','custom_str3','custom_str4','custom_str5','signature'
    ]);

    const postData = {};
    Object.keys(data).forEach((k) => {
      if (!allowed.has(k)) return;
      const v = data[k];
      if (v === undefined || v === null || v === '') return;
      postData[k] = String(v);
    });

    try {
      // Compute signature server-side (override any client-provided value)
      const passphrase = process.env.PAYFAST_PASSPHRASE || 'PeterKutumela2025';
      const merchantId = String(postData.merchant_id || '');
      const usePassphrase = merchantId !== '10000100' && !!passphrase; // Sandbox merchant uses no passphrase
      const keys = Object.keys(postData).filter((k) => k !== 'signature').sort();
      const encoded = keys.map((k) => `${k}=${pfEncode(postData[k])}`).join('&');
      const toSignWith = `${encoded}&passphrase=${passphrase}`;
      const sigWith = crypto.createHash('md5').update(toSignWith).digest('hex');
      const sigNo = crypto.createHash('md5').update(encoded).digest('hex');
      // Choose signature mode: query param sig=with|none (default: with, matching dashboard setting)
      const sigMode = String(data.sig || 'with');
      postData.signature = sigMode === 'with' ? sigWith : sigNo;
      console.log('[payfastFormRedirect] sig_set=true mode=', sigMode, ' merchant_id=', merchantId);
      console.log('[payfastFormRedirect] encoded=', encoded);
      console.log('[payfastFormRedirect] computed_signature_no_pass=', sigNo);
      console.log('[payfastFormRedirect] computed_signature_with_pass=', sigWith);
    } catch (e) {
      console.warn('[payfastFormRedirect] sig_compute_failed', e?.message || e);
    }

    const inputs = Object.keys(postData)
      .map((k) => {
        const v = postData[k];
        return `<input type="hidden" name="${k}" value="${v.replace(/"/g,'&quot;')}">`;
      })
      .join('\n');

    const debug = String(data.debug || '0') === '1';
    const html = `<!doctype html>
<html><head><meta charset="utf-8"><title>Redirecting to PayFast...</title></head>
<body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
  <h2>Redirecting to PayFast...</h2>
  <p>Please wait while we redirect you to complete your payment.</p>
  <form id="payfastForm" method="post" action="${target}">
    ${inputs}
    <button type="submit" style="padding: 10px 20px; background: #007cba; color: white; border: none; border-radius: 5px; cursor: pointer;">Continue to PayFast</button>
  </form>
  <script>
    // Auto-submit after a short delay to ensure all inputs are loaded
    setTimeout(function(){ var f = document.getElementById('payfastForm'); if (f) f.submit(); }, 150);
  </script>
</body></html>`;

    res.set('Cache-Control', 'no-store');
    res.status(200).send(html);
  } catch (e) {
    console.error('payfastFormRedirect error', e);
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

// === WebAuthn (Passkeys) minimal endpoints ===
// Store per-user WebAuthn credentials in Firestore under users/{uid}/webauthn_credentials/{credId}
function getRp() {
  const rpID = process.env.WEBAUTHN_RPID || (process.env.PUBLIC_BASE_URL ? new URL(process.env.PUBLIC_BASE_URL).hostname : 'marketplace-8d6bd.web.app');
  const rpName = process.env.WEBAUTHN_RPNAME || 'Mzansi Marketplace';
  const origin = process.env.WEBAUTHN_ORIGIN || process.env.PUBLIC_BASE_URL || 'https://marketplace-8d6bd.web.app';
  return { rpID, rpName, origin };
}

exports.webauthnRegistrationOptions = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  const uid = context.auth.uid;
  const { rpID, rpName } = getRp();
  const userDoc = await db.collection('users').doc(uid).get();
  const user = userDoc.exists ? userDoc.data() : {};
  const userName = user.displayName || user.storeName || user.email || uid;
  // Pull existing credential IDs to exclude
  const credsSnap = await db.collection('users').doc(uid).collection('webauthn_credentials').get();
  const excludeCredentials = credsSnap.docs.map((d) => ({ id: Buffer.from(d.id, 'base64url'), type: 'public-key' }));
  const options = generateRegistrationOptions({
    rpID,
    rpName,
    userID: uid,
    userName,
    attestationType: 'none',
    excludeCredentials,
    authenticatorSelection: { userVerification: 'preferred', residentKey: 'preferred' },
  });
  await db.collection('users').doc(uid).collection('webauthn_challenges').doc('register').set({
    challenge: options.challenge,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  return options;
});

exports.webauthnVerifyRegistration = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  const uid = context.auth.uid;
  const { origin, rpID } = getRp();
  const expectedChallengeDoc = await db.collection('users').doc(uid).collection('webauthn_challenges').doc('register').get();
  const expectedChallenge = expectedChallengeDoc.exists ? expectedChallengeDoc.data().challenge : undefined;
  if (!expectedChallenge) throw new functions.https.HttpsError('failed-precondition', 'No registration challenge');
  try {
    const verification = await verifyRegistrationResponse({
      expectedChallenge,
      expectedOrigin: origin,
      expectedRPID: rpID,
      response: data,
    });
    if (!verification.verified) throw new Error('Verification failed');
    const { credentialID, credentialPublicKey, counter } = verification.registrationInfo;
    const credIdB64u = Buffer.from(credentialID).toString('base64url');
    await db.collection('users').doc(uid).collection('webauthn_credentials').doc(credIdB64u).set({
      publicKey: Buffer.from(credentialPublicKey).toString('base64url'),
      counter: Number(counter || 0),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { ok: true, credentialId: credIdB64u };
  } catch (e) {
    console.error('webauthnVerifyRegistration error', e);
    throw new functions.https.HttpsError('invalid-argument', 'Passkey registration verification failed');
  }
});

exports.webauthnAuthenticationOptions = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  const uid = context.auth.uid;
  const { rpID } = getRp();
  const credsSnap = await db.collection('users').doc(uid).collection('webauthn_credentials').get();
  const allowCredentials = credsSnap.docs.map((d) => ({ id: Buffer.from(d.id, 'base64url'), type: 'public-key' }));
  const options = generateAuthenticationOptions({ rpID, allowCredentials, userVerification: 'preferred' });
  await db.collection('users').doc(uid).collection('webauthn_challenges').doc('auth').set({
    challenge: options.challenge,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  return options;
});

exports.webauthnVerifyAuthentication = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  const uid = context.auth.uid;
  const { origin, rpID } = getRp();
  const challengeDoc = await db.collection('users').doc(uid).collection('webauthn_challenges').doc('auth').get();
  const expectedChallenge = challengeDoc.exists ? challengeDoc.data().challenge : undefined;
  if (!expectedChallenge) throw new functions.https.HttpsError('failed-precondition', 'No authentication challenge');
  try {
    const verification = await verifyAuthenticationResponse({
      expectedChallenge,
      expectedOrigin: origin,
      expectedRPID: rpID,
      response: data,
      authenticator: async (credIdB64u) => {
        const credSnap = await db.collection('users').doc(uid).collection('webauthn_credentials').doc(credIdB64u).get();
        if (!credSnap.exists) return null;
        const c = credSnap.data();
        return {
          credentialID: Buffer.from(credIdB64u, 'base64url'),
          credentialPublicKey: Buffer.from(c.publicKey, 'base64url'),
          counter: Number(c.counter || 0),
        };
      },
      // Update counter after successful verification
      updateAuthenticatorCounter: async (credIdB64u, counter) => {
        await db.collection('users').doc(uid).collection('webauthn_credentials').doc(credIdB64u).set({
          counter: Number(counter || 0),
          lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      },
    });
    if (!verification.verified) throw new Error('Verification failed');
    return { ok: true };
  } catch (e) {
    console.error('webauthnVerifyAuthentication error', e);
    throw new functions.https.HttpsError('permission-denied', 'Passkey authentication failed');
  }
});

// === Email sender (safe: creds from env) ===
const cfg = (functions && functions.config && functions.config()) ? functions.config() : {};
const mailCfg = (cfg && cfg.mail) ? cfg.mail : {};
const mailUser = process.env.MAIL_USER || mailCfg.user || '';
const mailPass = process.env.MAIL_PASS || mailCfg.pass || '';
const mailHostCfg = process.env.MAIL_HOST || mailCfg.host || '';
const mailPortCfg = process.env.MAIL_PORT || mailCfg.port || '';
const mailSecureCfg = (process.env.MAIL_SECURE || mailCfg.secure || 'true').toString();
const mailFromCfg = process.env.MAIL_FROM || mailCfg.from || '';
let mailTransporter = null;
function createMailTransporter() {
  if (!mailUser || !mailPass) return null;
  const host = mailHostCfg || '';
  if (host) {
    return nodemailer.createTransport({
      host,
      port: Number(mailPortCfg || 465),
      secure: String(mailSecureCfg || 'true') !== 'false',
      auth: { user: mailUser, pass: mailPass },
    });
  }
  return nodemailer.createTransport({
    service: 'gmail',
    auth: { user: mailUser, pass: mailPass },
  });
}
mailTransporter = createMailTransporter();

// Ensure transporter exists; if not configured, fall back to Ethereal test account
async function ensureTransporter() {
  if (mailTransporter) return mailTransporter;
  if (mailUser && mailPass) {
    mailTransporter = createMailTransporter();
    return mailTransporter;
  }
  try {
    const test = await nodemailer.createTestAccount();
    mailTransporter = nodemailer.createTransport({
      host: test.smtp.host,
      port: test.smtp.port,
      secure: test.smtp.secure,
      auth: { user: test.user, pass: test.pass },
    });
    if (!process.env.MAIL_FROM && !mailFromCfg) {
      process.env.MAIL_FROM = `Mzansi Marketplace (Test) <${test.user}>`;
    }
    console.log('[mail] Using Ethereal test account');
    return mailTransporter;
  } catch (e) {
    console.error('[mail] Failed to create Ethereal account', e);
    return null;
  }
}

function renderBrandedEmail({
  title = 'Mzansi Marketplace',
  heading = 'Mzansi Marketplace',
  intro = '',
  bodyHtml = '',
  ctaText = '',
  ctaUrl = '',
  footer = 'If you did not request this, you can safely ignore this email.',
}) {
  const brandColor = '#1F4654';
  const bgLight = '#F2F7F9';
  const cardBg = '#FFFFFF';
  const textColor = '#222222';
  const muted = '#6B7280';
  const buttonBg = brandColor;
  const buttonText = '#FFFFFF';
  const base = process.env.PUBLIC_BASE_URL || 'https://marketplace-8d6bd.web.app';
  const year = new Date().getFullYear();
  return `
  <!doctype html>
  <html>
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width" />
      <title>${title}</title>
    </head>
    <body style="margin:0;padding:0;background:${bgLight};font-family:Arial,Helvetica,sans-serif;color:${textColor}">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:${bgLight};padding:24px 0;">
        <tr>
          <td align="center">
            <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="background:${cardBg};border-radius:12px;box-shadow:0 8px 16px rgba(0,0,0,0.06);overflow:hidden">
              <tr>
                <td style="background:${brandColor};padding:20px 24px;color:#fff;font-size:20px;font-weight:700;text-align:left;">
                  ${heading}
                </td>
              </tr>
              <tr>
                <td style="padding:24px">
                  <p style="margin:0 0 12px 0;color:${textColor};font-size:16px;line-height:1.5">${intro}</p>
                  ${bodyHtml}
                  ${ctaText && ctaUrl ? `
                    <div style="margin:24px 0">
                      <a href="${ctaUrl}"
                        style="display:inline-block;background:${buttonBg};color:${buttonText};text-decoration:none;padding:12px 20px;border-radius:8px;font-weight:600">
                        ${ctaText}
                      </a>
                    </div>
                    <p style="margin:8px 0 0 0;font-size:12px;color:${muted}">
                      If the button doesn’t work, copy and paste this link into your browser:<br/>
                      <a href="${ctaUrl}" style="color:${brandColor};word-break:break-all">${ctaUrl}</a>
                    </p>
                  ` : ''}
                  <p style="margin:24px 0 0 0;color:${muted};font-size:12px;line-height:1.6">${footer}</p>
                </td>
              </tr>
              <tr>
                <td style="background:${bgLight};padding:16px 24px;color:${muted};font-size:12px;text-align:center">
                  © ${year} Mzansi Marketplace • <a href="${base}" style="color:${brandColor};text-decoration:none">${base.replace('https://','')}</a>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
  </html>`;
}

exports.sendOrderEmail = functions.https.onCall(async (data, context) => {
  try {
    const transporter = await ensureTransporter();
    if (!transporter) throw new functions.https.HttpsError('failed-precondition', 'Email not configured');
    const toEmail = (data && data.toEmail) || '';
    const subject = (data && data.subject) || 'Notification';
    const html = (data && data.html) || '';
    const cc = (data && data.cc) || '';
    if (!toEmail || !html) {
      throw new functions.https.HttpsError('invalid-argument', 'toEmail and html are required');
    }
    const from = process.env.MAIL_FROM || mailUser;
    const wrapped = renderBrandedEmail({ title: subject, heading: 'Mzansi Marketplace', intro: '', bodyHtml: html });
    const primary = await transporter.sendMail({ from, to: toEmail, subject, html: wrapped, headers: { 'List-Unsubscribe': `<mailto:${from}>` } });
    let ccResult = null;
    if (cc) {
      ccResult = await transporter.sendMail({ from, to: cc, subject: `[Admin] ${subject}` , html: wrapped });
    }
    const preview = nodemailer.getTestMessageUrl(primary) || null;
    if (preview) console.log('[mail][preview]', preview);
    return { ok: true, id: primary.messageId, ccId: ccResult?.messageId || null, preview };
  } catch (e) {
    console.error('sendOrderEmail error', e);
    throw new functions.https.HttpsError('internal', 'Failed to send email');
  }
});

// === Email OTP (create and verify) ===
exports.createEmailOtp = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  try {
    const transporter = await ensureTransporter();
    if (!transporter) throw new functions.https.HttpsError('failed-precondition', 'Email not configured');
    const uid = context.auth.uid;
    let email = (data && data.email) || '';
    if (!email) {
      const userDoc = await db.collection('users').doc(uid).get();
      email = (userDoc.exists && (userDoc.data().email || '')) || '';
    }
    if (!email) {
      throw new functions.https.HttpsError('invalid-argument', 'No email found for user');
    }

    // Generate 6-digit code
    const code = String(crypto.randomInt(0, 1000000)).padStart(6, '0');
    const hash = crypto.createHash('sha256').update(code).digest('hex');
    const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 10 * 60 * 1000));

    await db.collection('email_otps').doc(uid).set({
      hash,
      expiresAt,
      attempts: 0,
      used: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    const from = process.env.MAIL_FROM || mailUser;
    const html = renderBrandedEmail({
      title: 'Your verification code',
      heading: 'Verify your sign-in',
      intro: 'Use the code below to verify your action. For your security, it expires in 10 minutes.',
      bodyHtml: `<div style="font-size:28px;font-weight:700;letter-spacing:4px;margin:12px 0;color:#1F4654">${code}</div>`,
      footer: 'Do not share this code with anyone. If you did not initiate this, please secure your account.'
    });
    const info = await transporter.sendMail({ from, to: email, subject: 'Your verification code', html });
    const preview = nodemailer.getTestMessageUrl(info) || null;
    if (preview) console.log('[mail][preview]', preview);

    return { ok: true, preview };
  } catch (e) {
    console.error('createEmailOtp error', e);
    throw new functions.https.HttpsError('internal', 'Failed to create OTP');
  }
});

// === Branded password reset email ===
exports.sendPasswordResetEmail = functions.https.onCall(async (data, context) => {
  try {
    const transporter = await ensureTransporter();
    if (!transporter) throw new functions.https.HttpsError('failed-precondition', 'Email not configured');
    const email = (data && data.email) || '';
    if (!email) {
      throw new functions.https.HttpsError('invalid-argument', 'Email is required');
    }
    const base = process.env.PUBLIC_BASE_URL || 'https://marketplace-8d6bd.web.app';
    const dynamicLinkDomain = process.env.DYNAMIC_LINK_DOMAIN || undefined; // optional
    const action = await admin.auth().generatePasswordResetLink(email, {
      url: `${base}/login?email=${encodeURIComponent(email)}`,
      handleCodeInApp: true,
      dynamicLinkDomain,
    });
    // Build branded page URL using the generated oobCode
    let brandedUrl = action;
    try {
      const u = new URL(action);
      const oob = u.searchParams.get('oobCode');
      if (oob) {
        brandedUrl = `${base}/reset-password.html?mode=resetPassword&oobCode=${encodeURIComponent(oob)}`;
      }
    } catch (_) {}

    const subject = 'Reset your Mzansi Marketplace password';
    const html = renderBrandedEmail({
      title: subject,
      heading: 'Password reset',
      intro: 'We received a request to reset your password. Click the button below to choose a new password.',
      bodyHtml: '',
      ctaText: 'Reset password',
      ctaUrl: brandedUrl,
      footer: 'If you did not request a password reset, you can safely ignore this email.',
    });
    const from = process.env.MAIL_FROM || mailUser;
    const info = await transporter.sendMail({
      from,
      to: email,
      subject,
      html,
      headers: { 'List-Unsubscribe': `<mailto:${from}>` },
      text: `Reset your password:\n${action}\n\nIf you did not request this, ignore this email.`,
    });
    const preview = nodemailer.getTestMessageUrl(info) || null;
    if (preview) console.log('[mail][preview]', preview);
    return { ok: true, preview };
  } catch (e) {
    console.error('sendPasswordResetEmail error', e);
    throw new functions.https.HttpsError('internal', 'Failed to send password reset email');
  }
});

exports.verifyEmailOtp = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  try {
    const uid = context.auth.uid;
    const code = (data && data.code) ? String(data.code).trim() : '';
    if (!code || code.length !== 6) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid code');
    }
    const hash = crypto.createHash('sha256').update(code).digest('hex');
    const ref = db.collection('email_otps').doc(uid);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'No OTP found');
    }
    const dataDoc = snap.data();
    if (dataDoc.used) {
      throw new functions.https.HttpsError('failed-precondition', 'Code already used');
    }
    const now = admin.firestore.Timestamp.now();
    if (dataDoc.expiresAt && now.toMillis() > dataDoc.expiresAt.toMillis()) {
      throw new functions.https.HttpsError('deadline-exceeded', 'Code expired');
    }
    const attempts = Number(dataDoc.attempts || 0);
    if (attempts >= 5) {
      throw new functions.https.HttpsError('resource-exhausted', 'Too many attempts');
    }
    if (dataDoc.hash !== hash) {
      await ref.set({ attempts: attempts + 1, lastAttempt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      throw new functions.https.HttpsError('permission-denied', 'Incorrect code');
    }

    await ref.set({ used: true, verifiedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    return { ok: true };
  } catch (e) {
    console.error('verifyEmailOtp error', e);
    throw e instanceof functions.https.HttpsError ? e : new functions.https.HttpsError('internal', 'Verification failed');
  }
});

// ImageKit functions
// axios already required above

const IK_API_BASE = 'https://api.imagekit.io/v1';

async function isAdmin(context) {
  const token = context.auth && context.auth.token;
  
  // Check custom claims first
  if (token && (token.admin === true || token.role === 'admin')) {
    return true;
  }
  
  // Fallback: check Firestore if custom claims not set
  if (context.auth && context.auth.uid) {
    try {
      const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        const role = (userData.role || '').toString().toLowerCase();
        return role === 'admin';
      }
    } catch (e) {
      console.warn('Failed to check Firestore for admin role:', e.message);
    }
  }
  
  return false;
}

// === ImageKit helper functions ===
function getImageKitCredentials() {
  // Try to get from Firebase Functions config first
  const cfg = (functions && functions.config && functions.config()) ? functions.config() : {};
  const imagekitCfg = (cfg && cfg.imagekit) ? cfg.imagekit : {};
  
  const privateKey = imagekitCfg.private_key || process.env.IMAGEKIT_PRIVATE_KEY || 'private_cZ0y1MLeTaZbOYoxDAVI7fTIbTM=';
  const publicKey = imagekitCfg.public_key || process.env.IMAGEKIT_PUBLIC_KEY || 'public_tAO0SkfLl/37FQN+23cAyfYg=';
  const urlEndpoint = imagekitCfg.url_endpoint || process.env.IMAGEKIT_URL_ENDPOINT || 'https://ik.imagekit.io/tkhb6zllk';
  
  return { privateKey, publicKey, urlEndpoint };
}

// Helper: verify admin from Authorization: Bearer <idToken>
async function verifyAdminFromRequest(req) {
  try {
    const authHeader = req.headers['authorization'] || req.headers['Authorization'] || '';
    const parts = String(authHeader).split(' ');
    if (parts.length === 2 && parts[0] === 'Bearer' && parts[1]) {
      const decoded = await admin.auth().verifyIdToken(parts[1]);
      console.log('Token decoded:', { uid: decoded?.uid, email: decoded?.email, admin: decoded?.admin, role: decoded?.role });
      
      if (decoded && (decoded.admin === true || decoded.role === 'admin')) {
        console.log('Admin access granted via token claims');
        return true;
      }
      
      // Fallback: check Firestore role
      if (decoded && decoded.uid) {
        console.log('Checking Firestore for user:', decoded.uid);
        const userDoc = await admin.firestore().collection('users').doc(decoded.uid).get();
        console.log('User doc exists:', userDoc.exists);
        if (userDoc.exists) {
          const userData = userDoc.data();
          const role = (userData.role || '').toString().toLowerCase();
          console.log('User role from Firestore:', role);
          return role === 'admin';
        } else {
          console.log('User document not found in Firestore');
        }
      }
    } else {
      console.log('Invalid authorization header format');
    }
  } catch (e) {
    console.error('verifyAdminFromRequest failed:', e.message);
  }
  return false;
}

// HTTP version for admin dashboard (GET with CORS)
exports.listImagesHttp = functions.https.onRequest(async (req, res) => {
  // Basic CORS headers (adjust origin as needed)
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }

  if (req.method !== 'GET') { res.status(405).json({ error: 'Method not allowed' }); return; }

  // Require admin
  const isAdminReq = await verifyAdminFromRequest(req);
  if (!isAdminReq) { res.status(403).json({ error: 'Admin access required' }); return; }

  try {
    const limit = Math.max(1, Math.min(1000, Number(req.query.limit || 100)));
    const skip = Math.max(0, Number(req.query.skip || 0));
    const path = req.query.path ? String(req.query.path) : undefined;
    const searchQuery = req.query.searchQuery ? String(req.query.searchQuery) : undefined;

    const { privateKey } = getImageKitCredentials();
    if (!privateKey) { res.status(500).json({ error: 'ImageKit not configured' }); return; }

    const params = new URLSearchParams();
    params.append('limit', String(limit));
    params.append('skip', String(skip));
    if (path) params.append('path', path);
    if (searchQuery) params.append('searchQuery', searchQuery);

    const ikRes = await axios.get(`${IK_API_BASE}/files`, {
      params,
      headers: { Authorization: `Basic ${Buffer.from(`${privateKey}:`).toString('base64')}` },
      timeout: 30000,
    });

    res.status(200).json({ files: ikRes.data || [], count: Array.isArray(ikRes.data) ? ikRes.data.length : 0 });
  } catch (e) {
    console.error('listImagesHttp error:', e?.response?.status, e?.response?.data || e.message);
    if (e?.response?.status) {
      res.status(e.response.status).json({ error: e.response.data || e.message });
    } else {
      res.status(500).json({ error: e.message });
    }
  }
});

exports.listImages = functions.https.onCall(async (data, context) => {
  try {
    // Check authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    // Check admin status
    if (!(await isAdmin(context))) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }

    const { privateKey: userPrivateKey, path, limit = 100, skip = 0, searchQuery } = data || {};
    
    // Use provided private key or fall back to default
    const { privateKey } = getImageKitCredentials();
    const finalPrivateKey = userPrivateKey || privateKey;
    
    // Validate required parameters
    if (!finalPrivateKey) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing private key for ImageKit');
    }

    // Validate limit and skip
    if (limit < 1 || limit > 1000) {
      throw new functions.https.HttpsError('invalid-argument', 'Limit must be between 1 and 1000');
    }

    if (skip < 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Skip must be non-negative');
    }

    console.log('listImages called with:', { path, limit, skip, searchQuery: !!searchQuery });
    console.log('User authenticated:', context.auth.uid, context.auth.token?.email);
    console.log('Using ImageKit private key:', finalPrivateKey ? 'Present' : 'Missing');

    const params = new URLSearchParams();
    params.append('limit', String(limit));
    params.append('skip', String(skip));
    if (path) params.append('path', path);
    if (searchQuery) params.append('searchQuery', searchQuery);

    const res = await axios.get(`${IK_API_BASE}/files`, {
      params,
      headers: {
        Authorization: `Basic ${Buffer.from(`${finalPrivateKey}:`).toString('base64')}`,
      },
      timeout: 30000, // Increased timeout
    });

    console.log('ImageKit response status:', res.status);
    
    // ImageKit returns an array
    return { 
      files: res.data || [],
      success: true,
      count: Array.isArray(res.data) ? res.data.length : 0
    };
  } catch (e) {
    console.error('listImages error:', {
      message: e.message,
      status: e?.response?.status,
      data: e?.response?.data,
      code: e.code
    });

    // Handle specific error types
    if (e.code === 'ECONNABORTED') {
      throw new functions.https.HttpsError('deadline-exceeded', 'Request timeout - ImageKit service unavailable');
    }
    
    if (e?.response?.status === 401) {
      throw new functions.https.HttpsError('unauthenticated', 'Invalid ImageKit credentials');
    }
    
    if (e?.response?.status === 403) {
      throw new functions.https.HttpsError('permission-denied', 'ImageKit access denied');
    }

    // Generic error
    throw new functions.https.HttpsError('internal', `Failed to list images: ${e.message}`);
  }
});

// Test ImageKit connectivity
exports.testImageKitConnection = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  if (!(await isAdmin(context))) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }
  
  try {
    const { privateKey, urlEndpoint } = getImageKitCredentials();
    if (!privateKey) {
      return { 
        success: false, 
        error: 'ImageKit private key not configured',
        message: 'Please set IMAGEKIT_PRIVATE_KEY environment variable'
      };
    }
    
    // Test a simple API call
    const testRes = await axios.get(`${IK_API_BASE}/files`, {
      params: { limit: 1 },
      headers: { Authorization: `Basic ${Buffer.from(`${privateKey}:`).toString('base64')}` },
      timeout: 10000,
    });
    
    return {
      success: true,
      message: 'ImageKit connection successful',
      endpoint: urlEndpoint,
      testResponse: {
        status: testRes.status,
        dataLength: Array.isArray(testRes.data) ? testRes.data.length : 'unknown',
        hasFiles: Array.isArray(testRes.data) && testRes.data.length > 0
      }
    };
  } catch (e) {
    console.error('testImageKitConnection error:', e.message);
    return {
      success: false,
      error: e.message,
      message: 'ImageKit connection failed',
      details: {
        status: e?.response?.status,
        statusText: e?.response?.statusText,
        data: e?.response?.data
      }
    };
  }
});

// Provide client-side upload auth for ImageKit (token, expire, signature)
exports.getImageKitUploadAuth = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  try {
    const { privateKey, publicKey, urlEndpoint } = getImageKitCredentials();
    if (!privateKey || !publicKey) {
      throw new functions.https.HttpsError('failed-precondition', 'ImageKit not configured');
    }
    const token = crypto.randomBytes(16).toString('hex');
    const expire = Math.floor(Date.now() / 1000) + 5 * 60; // 5 minutes
    const signature = crypto
      .createHmac('sha1', privateKey)
      .update(token + expire)
      .digest('hex');
    return { token, expire, signature, publicKey, urlEndpoint };
  } catch (e) {
    console.error('getImageKitUploadAuth error:', e.message);
    throw e instanceof functions.https.HttpsError
      ? e
      : new functions.https.HttpsError('internal', 'Failed to generate upload auth');
  }
});

// === Firestore mirror of ImageKit assets ===
async function syncImageAssetsOnce({ pathPrefix = undefined, pageSize = 1000 } = {}) {
  const { privateKey, urlEndpoint } = getImageKitCredentials();
  if (!privateKey) throw new Error('ImageKit not configured');

  let skip = 0;
  let totalUpserts = 0;
  for (;;) {
    const params = new URLSearchParams();
    params.append('limit', String(pageSize));
    params.append('skip', String(skip));
    if (pathPrefix) params.append('path', pathPrefix);

    const ikRes = await axios.get(`${IK_API_BASE}/files`, {
      params,
      headers: { Authorization: `Basic ${Buffer.from(`${privateKey}:`).toString('base64')}` },
      timeout: 60000,
    });

    const files = Array.isArray(ikRes.data) ? ikRes.data : [];
    if (files.length === 0) break;

    const batch = db.batch();
    files.forEach((f) => {
      try {
        const fileId = f.fileId || f.file_id || f.id;
        if (!fileId) return;
        const filePath = String(f.filePath || f.file_path || f.path || '').trim();
        const firstSegment = filePath.split('/')[0] || '';
        const ref = db.collection('image_assets').doc(String(fileId));
        batch.set(ref, {
          fileId: String(fileId),
          name: f.name || '',
          filePath,
          size: Number(f.size || 0),
          url: f.url || (urlEndpoint ? `${urlEndpoint}/${filePath}` : ''),
          type: firstSegment,
          thumbnailUrl: f.thumbnailUrl || null,
          height: Number(f.height || 0) || null,
          width: Number(f.width || 0) || null,
          lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: f.createdAt ? admin.firestore.Timestamp.fromDate(new Date(f.createdAt)) : admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        totalUpserts += 1;
      } catch (_) {}
    });
    await batch.commit();

    if (files.length < pageSize) break;
    skip += files.length;
  }
  return { upserts: totalUpserts };
}

exports.syncImageAssetsNow = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  if (!(await isAdmin(context))) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }
  try {
    const pathPrefix = data && data.path ? String(data.path) : undefined;
    
    // Check ImageKit credentials first
    const { privateKey, urlEndpoint } = getImageKitCredentials();
    if (!privateKey) {
      throw new Error('ImageKit private key not configured. Please set IMAGEKIT_PRIVATE_KEY environment variable.');
    }
    
    console.log('Starting ImageKit sync with endpoint:', urlEndpoint);
    const result = await syncImageAssetsOnce({ pathPrefix });
    console.log('ImageKit sync completed successfully:', result);
    return { success: true, synced: result.upserts, ...result };
  } catch (e) {
    console.error('syncImageAssetsNow error:', e.message, e.stack);
    
    // Provide more specific error messages
    if (e.message.includes('ImageKit private key not configured')) {
      throw new functions.https.HttpsError('failed-precondition', 'ImageKit not configured. Contact administrator.');
    } else if (e.message.includes('timeout') || e.message.includes('ECONNRESET')) {
      throw new functions.https.HttpsError('unavailable', 'ImageKit service temporarily unavailable. Please try again.');
    } else if (e.message.includes('401') || e.message.includes('Unauthorized')) {
      throw new functions.https.HttpsError('permission-denied', 'Invalid ImageKit credentials. Contact administrator.');
    } else {
      throw new functions.https.HttpsError('internal', `Sync failed: ${e.message}`);
    }
  }
});

exports.syncImageAssetsScheduled = functions.pubsub.schedule('every 24 hours').onRun(async () => {
  try {
    const result = await syncImageAssetsOnce({ pathPrefix: undefined, pageSize: 1000 });
    console.log(`[image_assets_sync] upserts=${result.upserts}`);
  } catch (e) {
    console.error('[image_assets_sync] failed', e.message);
  }
  return null;
});

// Batch delete images from ImageKit and mirror collection
exports.batchDeleteImages = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  if (!(await isAdmin(context))) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }
  try {
    console.log('batchDeleteImages called');
    const fileIds = Array.isArray(data?.fileIds) ? data.fileIds.map(String) : [];
    if (fileIds.length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'fileIds required');
    }
    console.log('batchDeleteImages count:', fileIds.length, 'first', fileIds[0]);

    const { privateKey } = getImageKitCredentials();
    if (!privateKey) {
      throw new functions.https.HttpsError('failed-precondition', 'ImageKit not configured');
    }

    // Delete from ImageKit (best-effort) and Firestore mirror
    const headers = { Authorization: `Basic ${Buffer.from(`${privateKey}:`).toString('base64')}` };
    const results = {};
    const errors = {};
    const batch = db.batch();
    for (const id of fileIds) {
      results[id] = false;
      try {
        const delRes = await axios.delete(`${IK_API_BASE}/files/${encodeURIComponent(id)}`, { headers, timeout: 20000 });
        console.log('IK delete ok', id, delRes.status);
        results[id] = true;
      } catch (e) {
        const status = e?.response?.status || 0;
        const msg = e?.response?.data || e?.message || 'unknown';
        console.warn('IK delete error', id, status, msg);
        // Idempotent success if file already gone
        if (status === 404) {
          results[id] = true;
        } else {
          results[id] = false;
          errors[id] = { status, message: msg };
        }
      }
      // Only remove from mirror if IK deletion succeeded (or 404)
      if (results[id] === true) {
        batch.delete(db.collection('image_assets').doc(id));
      }
    }
    await batch.commit();
    const allOk = Object.values(results).every((v) => v === true);
    return { success: allOk, results, errors: Object.keys(errors).length ? errors : null };
  } catch (e) {
    console.error('batchDeleteImages error:', e?.message || e);
    // Return structured error instead of throwing to avoid client [internal]
    return { success: false, error: e?.message || String(e) };
  }
});

// Test function to debug batchDeleteImages
exports.testBatchDelete = functions.https.onCall(async (data, context) => {
  console.log('testBatchDelete: Starting test...');
  
  if (!context.auth) {
    console.error('testBatchDelete: No auth context');
    throw new functions.https.HttpsError('unauthenticated', 'No auth context');
  }
  
  console.log('testBatchDelete: User authenticated:', context.auth.uid);
  
  try {
    const isAdminResult = await isAdmin(context);
    console.log('testBatchDelete: isAdmin result:', isAdminResult);
    
    if (!isAdminResult) {
      console.error('testBatchDelete: User is not admin');
      throw new functions.https.HttpsError('permission-denied', 'Not admin');
    }
    
    console.log('testBatchDelete: User is admin, proceeding...');
    
    // Test ImageKit credentials
    const { privateKey } = getImageKitCredentials();
    console.log('testBatchDelete: Private key exists:', !!privateKey);
    
    if (!privateKey) {
      throw new functions.https.HttpsError('failed-precondition', 'No private key');
    }
    
    // Test a simple ImageKit API call
    try {
      const testResponse = await axios.get(`${IK_API_BASE}/files`, {
        headers: { Authorization: `Basic ${Buffer.from(`${privateKey}:`).toString('base64')}` },
        params: { limit: 1 },
        timeout: 10000,
      });
      console.log('testBatchDelete: ImageKit API test successful, status:', testResponse.status);
    } catch (ikError) {
      console.error('testBatchDelete: ImageKit API test failed:', ikError.message);
      if (ikError.response) {
        console.error('testBatchDelete: ImageKit response status:', ikError.response.status);
        console.error('testBatchDelete: ImageKit response data:', ikError.response.data);
      }
      throw new functions.https.HttpsError('internal', `ImageKit test failed: ${ikError.message}`);
    }
    
    return { 
      success: true, 
      message: 'All tests passed',
      userId: context.auth.uid,
      isAdmin: true,
      imageKitWorking: true
    };
    
  } catch (error) {
    console.error('testBatchDelete: Error during test:', error);
    throw error;
  }
});

// === Risk gatekeeper: IP info + simple rate limits ===
exports.riskGate = functions.https.onRequest(async (req, res) => {
  try {
    const ip = (req.headers['x-forwarded-for'] || req.ip || '').toString().split(',')[0].trim();
    const path = (req.query.path || req.body.path || 'unknown').toString(); // e.g., signup/login/reset/checkout
    const deviceId = (req.query.deviceId || req.body.deviceId || '').toString();
    const now = Date.now();

    // 1) Rate limit per IP+path per minute
    const minuteKey = `${ip}_${path}_${new Date(now).toISOString().slice(0,16)}`; // YYYY-MM-DDTHH:MM
    const ref = db.collection('rate_limits').doc(minuteKey);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const current = snap.exists ? (snap.data().count || 0) : 0;
      tx.set(ref, { count: current + 1, ip, path, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    });
    const after = await ref.get();
    const count = after.exists ? (after.data().count || 0) : 0;
    const limit = path === 'signup' ? 3 : path === 'password_reset' ? 5 : 30; // per minute
    if (count > limit) {
      res.status(429).json({ ok: false, reason: 'rate_limited', limit, count });
      return;
    }

    // 2) IP intel (optional vendor)
    let ipInfo = { country: null, asn: null, org: null, vpn: false, risk: 0 };
    try {
      const API = process.env.IPINFO_API || '';
      if (API && ip) {
        const r = await axios.get(`https://ipinfo.io/${ip}?token=${API}`, { timeout: 3000 });
        const data = r.data || {};
        ipInfo.country = data.country || null;
        ipInfo.org = data.org || null;
        ipInfo.asn = data.org ? String(data.org).split(' ')[0] : null;
      }
    } catch (e) {
      console.warn('ipinfo error', e.message);
    }

    // 3) Simple VPN/proxy heuristic fallback: reserved/private ranges
    const privateRanges = ['10.', '172.16.', '192.168.', '127.'];
    if (privateRanges.some((p) => ip.startsWith(p))) ipInfo.vpn = true;

    // 4) Log event
    await db.collection('risk_events').add({
      type: 'gate', ip, path, deviceId, ipInfo, ts: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({ ok: true, ipInfo });
  } catch (e) {
    console.error('riskGate error', e);
    res.status(500).json({ ok: false, error: 'internal' });
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

exports.sendNotification = functions.runWith({ timeoutSeconds: 60, memory: '256MB' }).firestore
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

exports.onNewMessage = functions.runWith({ timeoutSeconds: 60, memory: '256MB' }).firestore
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

// Auto-cancel stale EFT awaiting_payment orders after 48 hours
exports.autoCancelStaleEftOrders = functions.pubsub.schedule('every 24 hours').onRun(async () => {
  try {
    const cutoff = new Date(Date.now() - 48 * 60 * 60 * 1000);
    const q = await db.collection('orders')
      .where('paymentStatus', '==', 'awaiting_payment')
      .where('timestamp', '<', admin.firestore.Timestamp.fromDate(cutoff))
      .get();
    let processed = 0;
    const batch = db.batch();
    q.docs.forEach(doc => {
      const d = doc.data() || {};
      const pm = String(d.paymentMethod || '').toLowerCase();
      if (!pm.includes('eft') && !pm.includes('bank transfer')) return;
      batch.update(doc.ref, {
        status: 'cancelled',
        paymentStatus: 'cancelled',
        cancelReason: 'eft_timeout',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        trackingUpdates: admin.firestore.FieldValue.arrayUnion({
          by: 'system',
          description: 'Order auto-cancelled: EFT payment not received within 48 hours',
          timestamp: new Date().toISOString(),
        }),
      });
      processed += 1;
    });
    if (processed > 0) await batch.commit();
    console.log(`[eft] Auto-cancelled ${processed} stale EFT orders`);
    return null;
  } catch (e) {
    console.error('autoCancelStaleEftOrders error', e);
    return null;
  }
});

// Optional: auto-release receivables after holdback days (OFF by default; enable via env)
exports.autoReleaseReceivables = functions.pubsub.schedule('every 24 hours').onRun(async () => {
  try {
    const enabled = String(process.env.AUTO_RELEASE_ENABLED || 'false').toLowerCase() === 'true';
    if (!enabled) return null;
    const holdbackDays = Number(process.env.HOLDBACK_DAYS || 7);
    const cutoff = new Date(Date.now() - holdbackDays * 24 * 60 * 60 * 1000);
    // Find entries that are available and older than cutoff but not locked/settled
    const sellersSnap = await db.collection('platform_receivables').get();
    let flipped = 0;
    for (const sellerDoc of sellersSnap.docs) {
      const entriesSnap = await sellerDoc.ref
        .collection('entries')
        .where('status', '==', 'available')
        .where('availableAt', '<=', admin.firestore.Timestamp.fromDate(cutoff))
        .get();
      const batch = db.batch();
      entriesSnap.docs.forEach((e) => {
        batch.update(e.ref, { status: 'available', // already available; retained for extensibility
          updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      });
      if (entriesSnap.size > 0) {
        await batch.commit();
        flipped += entriesSnap.size;
      }
    }
    console.log(`[autoRelease] verified ${flipped} entries remain available after holdback`);
  } catch (e) {
    console.error('[autoRelease] error', e);
  }
  return null;
});

// Notify seller via branded email when admin approves their store
exports.onSellerApproved = functions.runWith({ timeoutSeconds: 60, memory: '256MB' }).firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data() || {};
      const after = change.after.data() || {};

      // Only proceed for sellers whose status changed to approved
      const role = String(after.role || '').toLowerCase();
      const prevStatus = String(before.status || '').toLowerCase();
      const currStatus = String(after.status || '').toLowerCase();
      if (role !== 'seller') return null;
      if (prevStatus === 'approved' || currStatus !== 'approved') return null;

      // Idempotency: if we've already marked as notified, skip
      if (after.approvalEmailSentAt) return null;

      const email = (after.email || '').toString().trim();
      if (!email || !email.includes('@')) {
        console.log('[seller_approved_email] No valid email for user', context.params.userId);
        return null;
      }

      const transporter = await ensureTransporter();
      if (!transporter) {
        console.warn('[seller_approved_email] Mail transporter not configured');
        return null;
      }

      const base = process.env.PUBLIC_BASE_URL || 'https://marketplace-8d6bd.web.app';
      const storeUrl = `${base}/store/${context.params.userId}`;
      const subject = 'Your store has been approved';
      const html = renderBrandedEmail({
        title: subject,
        heading: 'Store approved',
        intro: 'Congratulations! Your seller account and store have been approved. You can now start listing products and receiving orders.',
        bodyHtml: `
          <div style="margin: 16px 0; color:#111; font-size:14px; line-height:1.6">
            <p style="margin:0 0 8px 0">Here are a few suggestions to get started:</p>
            <ul style="margin:0 0 8px 20px; padding:0">
              <li>Add clear product photos and accurate pricing</li>
              <li>Set delivery or pickup options that work for you</li>
              <li>Respond quickly to customer chats and orders</li>
            </ul>
          </div>
        `,
        ctaText: 'Open your store',
        ctaUrl: storeUrl,
        footer: 'If you have any questions, simply reply to this email and we’ll help you get set up.'
      });

      const from = process.env.MAIL_FROM || mailUser;
      const info = await transporter.sendMail({
        from,
        to: email,
        subject,
        html,
        headers: { 'List-Unsubscribe': `<mailto:${from}>` },
      });
      const preview = nodemailer.getTestMessageUrl(info) || null;
      if (preview) console.log('[mail][preview][seller_approved]', preview);

      // Mark as notified
      await change.after.ref.set({ approvalEmailSentAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      return null;
    } catch (e) {
      console.error('onSellerApproved error', e);
      return null;
    }
  });

// === Flip receivable to available when order is finalized (delivered/completed/confirmed) ===
exports.onOrderFinalized = functions.runWith({ timeoutSeconds: 60, memory: '256MB' }).firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data() || {};
      const after = change.after.data() || {};
      const finalized = ['delivered', 'completed', 'confirmed'];
      const wasFinal = finalized.includes(String(before.status || '').toLowerCase());
      const isFinal = finalized.includes(String(after.status || '').toLowerCase());
      if (isFinal && !wasFinal) {
        const sellerId = after.sellerId;
        const orderId = context.params.orderId;
        if (sellerId) {
          const eref = db.collection('platform_receivables').doc(sellerId).collection('entries').doc(orderId);
          await eref.set({ status: 'available', availableAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        }
      }
      return null;
    } catch (e) {
      console.error('[ledger] onOrderFinalized failed', e);
      return null;
    }
  });

// === Set user custom claims based on Firestore role ===
exports.setUserCustomClaims = functions.https.onCall(async (data, context) => {
  try {
    // Only allow admins to set custom claims
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    // Check if the caller is admin
    const callerUid = context.auth.uid;
    const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
    if (!callerDoc.exists || callerDoc.data().role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Only admins can set custom claims');
    }

    const { userId } = data;
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'userId is required');
    }

    // Get user's role from Firestore
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }

    const userData = userDoc.data();
    const role = userData.role || 'customer';

    // Set custom claims
    const customClaims = {
      role: role,
      admin: role === 'admin',
      seller: role === 'seller',
      customer: role === 'customer'
    };

    await admin.auth().setCustomUserClaims(userId, customClaims);

    console.log(`Set custom claims for user ${userId}:`, customClaims);

    return {
      success: true,
      message: `Custom claims set for user ${userId}`,
      claims: customClaims
    };

  } catch (e) {
    console.error('setUserCustomClaims error:', e);
    throw new functions.https.HttpsError('internal', `Failed to set custom claims: ${e.message}`);
  }
});

// ===== Seller payouts (bank details already stored under users/{uid}/payout/bank) =====
async function getCommissionPct() {
  let pct = Number(process.env.PLATFORM_COMMISSION_PCT || 0.1);
  try {
    const doc = await db.collection('admin_settings').doc('payment_settings').get();
    const data = doc.exists ? (doc.data() || {}) : {};
    const cfgPct = Number(data.platformFeePercentage);
    if (!isNaN(cfgPct) && cfgPct >= 0 && cfgPct <= 50) {
      pct = cfgPct / 100;
    }
  } catch (_) {}
  return pct;
}
const COMMISSION_PCT_FALLBACK = Number(process.env.PLATFORM_COMMISSION_PCT || 0.1);
const MIN_PAYOUT_AMOUNT = Number(process.env.MIN_PAYOUT_AMOUNT || 50); // R50 default

function toRand(n) { return Math.round(Number(n || 0) * 100) / 100; }

// Ledger-driven available balance: sum receivable entries marked 'available' and not locked
async function computeSellerAvailableBalance(sellerId) {
  const entriesSnap = await db
    .collection('platform_receivables')
    .doc(sellerId)
    .collection('entries')
    .where('status', '==', 'available')
    .get();
  let gross = 0;
  let commission = 0;
  let net = 0;
  const orderIds = [];
  const entryIds = [];
  entriesSnap.docs.forEach((doc) => {
    const e = doc.data() || {};
    // Skip if locked to a payout
    if (e.payoutLockId) return;
    const g = Number(e.gross || 0);
    const c = Number(e.commission || 0);
    const n = Number(e.net || (g - c));
    if (n > 0) {
      gross += g;
      commission += c;
      net += n;
      if (e.orderId) orderIds.push(e.orderId);
      entryIds.push(doc.id);
    }
  });
  return { gross: toRand(gross), commission: toRand(commission), net: toRand(net), count: entryIds.length, orderIds, entryIds };
}

// Internal: get eligible receivable entries for seller (available and not locked)
async function getEligibleReceivablesForSeller(sellerId) {
  const snap = await db
    .collection('platform_receivables')
    .doc(sellerId)
    .collection('entries')
    .where('status', '==', 'available')
    .get();
  const entryIds = [];
  let gross = 0, commission = 0, net = 0;
  const orders = [];
  snap.docs.forEach((d) => {
    const e = d.data() || {};
    if (e.payoutLockId) return; // skip locked
    const g = Number(e.gross || 0);
    const c = Number(e.commission || 0);
    const n = Number(e.net || (g - c));
    if (n > 0) {
      entryIds.push(d.id);
      gross += g; commission += c; net += n;
      if (e.orderId) orders.push(e.orderId);
    }
  });
  return { entryIds, gross: toRand(gross), commission: toRand(commission), net: toRand(net), orderIds: orders };
}

exports.getSellerAvailableBalance = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  const callerUid = context.auth.uid;
  const targetUid = String(data?.userId || callerUid);

  // Only admin can query others' balances
  if (targetUid !== callerUid) {
    const isAdmin = context.auth.token?.admin === true || context.auth.token?.role === 'admin';
    if (!isAdmin) throw new functions.https.HttpsError('permission-denied', 'Not allowed');
  }

  const result = await computeSellerAvailableBalance(targetUid);
  const cpct = await getCommissionPct().catch(() => COMMISSION_PCT_FALLBACK);
  return { ...result, minPayoutAmount: MIN_PAYOUT_AMOUNT, commissionPct: cpct };
});

exports.requestPayout = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  const sellerId = context.auth.uid;
  // Prevent concurrent requests and duplicates
  const lockRef = db.collection('payout_locks').doc(sellerId);
  const existingLock = await lockRef.get();
  if (existingLock.exists) {
    throw new functions.https.HttpsError('resource-exhausted', 'Please wait before trying again');
  }
  const inProgress = await db.collection('payouts')
    .where('sellerId', '==', sellerId)
    .where('status', 'in', ['requested','processing'])
    .limit(1)
    .get();
  if (!inProgress.empty) {
    throw new functions.https.HttpsError('failed-precondition', 'A payout request is already in progress');
  }
  const { net, gross, commission, orderIds, entryIds, count } = await computeSellerAvailableBalance(sellerId);
  if (net <= 0 || count === 0) {
    throw new functions.https.HttpsError('failed-precondition', 'No funds available to payout');
  }
  if (net < MIN_PAYOUT_AMOUNT) {
    throw new functions.https.HttpsError('failed-precondition', `Minimum payout amount is R${MIN_PAYOUT_AMOUNT.toFixed(2)}`);
  }

  // Fetch bank snapshot
  const bankDoc = await db.collection('users').doc(sellerId).collection('payout').doc('bank').get();
  if (!bankDoc.exists) {
    throw new functions.https.HttpsError('failed-precondition', 'Bank details missing');
  }
  const bank = bankDoc.data();

  // Create payout request and lock orders to this payout
  const payoutRef = db.collection('payouts').doc();
  const userPayoutRef = db.collection('users').doc(sellerId).collection('payouts').doc(payoutRef.id);

  await db.runTransaction(async (tx) => {
    const now = admin.firestore.FieldValue.serverTimestamp();
    // short-lived lock
    tx.set(lockRef, { createdAt: now }, { merge: true });
    const base = {
      id: payoutRef.id,
      sellerId,
      currency: 'ZAR',
      amount: net,
      gross,
      commission,
      status: 'requested',
      orderIds,
      entryIds,
      bankSnapshot: {
        accountHolder: bank.accountHolder || null,
        bankName: bank.bankName || null,
        accountNumber: bank.accountNumber || null,
        branchCode: bank.branchCode || null,
        accountType: bank.accountType || null,
      },
      createdAt: now,
      updatedAt: now,
    };

    tx.set(payoutRef, base, { merge: true });
    tx.set(userPayoutRef, base, { merge: true });

    // Lock receivable entries to this payout to prevent double counting
    if (Array.isArray(entryIds)) {
      entryIds.forEach((eid) => {
        const eref = db.collection('platform_receivables').doc(sellerId).collection('entries').doc(eid);
        tx.set(eref, { status: 'locked', payoutLockId: payoutRef.id, lockedAt: now, updatedAt: now }, { merge: true });
      });
    }
    // Mark orders for UI traceability (best effort)
    if (Array.isArray(orderIds)) {
      orderIds.forEach((id) => {
        const oref = db.collection('orders').doc(id);
        tx.set(oref, { payoutRequestId: payoutRef.id, updatedAt: now }, { merge: true });
      });
    }
  });

  // best-effort lock expiry
  try { setTimeout(() => lockRef.delete().catch(() => {}), 30000); } catch (_) {}

  return { ok: true, payoutId: payoutRef.id, amount: net, orderCount: count };
});

exports.adminUpdatePayoutStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  const isAdmin = context.auth.token?.admin === true || context.auth.token?.role === 'admin';
  if (!isAdmin) throw new functions.https.HttpsError('permission-denied', 'Admin only');

  const payoutId = String(data?.payoutId || '').trim();
  const status = String(data?.status || '').toLowerCase(); // requested|processing|paid|failed|cancelled
  const reference = String(data?.reference || '').trim() || null;
  if (!payoutId || !status) {
    throw new functions.https.HttpsError('invalid-argument', 'payoutId and status are required');
  }
  const allowed = ['requested','processing','paid','failed','cancelled'];
  if (!allowed.includes(status)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid status');
  }

  const pref = db.collection('payouts').doc(payoutId);
  const psnap = await pref.get();
  if (!psnap.exists) throw new functions.https.HttpsError('not-found', 'Payout not found');
  const pdata = psnap.data() || {};
  const sellerId = pdata.sellerId;
  const userPayoutRef = db.collection('users').doc(sellerId).collection('payouts').doc(payoutId);

  await db.runTransaction(async (tx) => {
    const now = admin.firestore.FieldValue.serverTimestamp();
    tx.set(pref, { status, reference, updatedAt: now }, { merge: true });
    tx.set(userPayoutRef, { status, reference, updatedAt: now }, { merge: true });

    if (status === 'paid') {
      const orderIds = Array.isArray(pdata.orderIds) ? pdata.orderIds : [];
      const entryIds = Array.isArray(pdata.entryIds) ? pdata.entryIds : [];
      orderIds.forEach(id => {
        const oref = db.collection('orders').doc(id);
        tx.set(oref, { disbursedToSeller: true, disbursedAt: now, payoutId }, { merge: true });
      });
      if (sellerId && entryIds.length > 0) {
        entryIds.forEach((eid) => {
          const eref = db.collection('platform_receivables').doc(sellerId).collection('entries').doc(eid);
          tx.set(eref, { status: 'settled', settledAt: now, payoutId, updatedAt: now }, { merge: true });
        });
      }
      if (sellerId && typeof pdata.amount === 'number') {
        const sref = db.collection('platform_receivables').doc(sellerId).collection('settlements').doc();
        tx.set(sref, {
          method: 'payout_manual',
          amountPaid: Number(pdata.amount) || 0,
          payoutId,
          reference: reference || null,
          createdAt: now,
        });
      }
    }

    if (status === 'failed' || status === 'cancelled') {
      const orderIds = Array.isArray(pdata.orderIds) ? pdata.orderIds : [];
      const entryIds = Array.isArray(pdata.entryIds) ? pdata.entryIds : [];
      orderIds.forEach(id => {
        const oref = db.collection('orders').doc(id);
        tx.set(oref, { payoutRequestId: admin.firestore.FieldValue.delete(), updatedAt: now }, { merge: true });
      });
      if (sellerId && entryIds.length > 0) {
        entryIds.forEach((eid) => {
          const eref = db.collection('platform_receivables').doc(sellerId).collection('entries').doc(eid);
          tx.set(eref, { status: 'available', payoutLockId: admin.firestore.FieldValue.delete(), updatedAt: now }, { merge: true });
        });
      }
    }
  });

  return { ok: true };
});

// === Admin: delete a user (Auth + Firestore doc + subcollections + tokens)
exports.adminDeleteUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  let isAdminCaller = context.auth.token?.admin === true || context.auth.token?.role === 'admin';
  if (!isAdminCaller) {
    // Fallback to Firestore role check to support dashboards that gate by users/{uid}.role
    try {
      const callerDoc = await db.collection('users').doc(context.auth.uid).get();
      if (callerDoc.exists && (callerDoc.data()?.role === 'admin')) {
        isAdminCaller = true;
      }
    } catch (e) {
      // ignore and use claims-only result
    }
  }
  if (!isAdminCaller) {
    throw new functions.https.HttpsError('permission-denied', 'Admin only');
  }
  const userId = String(data?.userId || '').trim();
  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'userId is required');
  }

  // 1) Delete subcollections under users/{uid}
  const userRef = db.collection('users').doc(userId);
  try {
    const subcollections = await userRef.listCollections();
    for (const col of subcollections) {
      // Delete in batches of 500
      let lastDoc = null;
      for (;;) {
        let q = col.limit(500);
        if (lastDoc) q = q.startAfter(lastDoc);
        const snap = await q.get();
        if (snap.empty) break;
        const batch = db.batch();
        snap.docs.forEach((d) => batch.delete(d.ref));
        await batch.commit();
        lastDoc = snap.docs[snap.docs.length - 1];
        if (snap.size < 500) break;
      }
    }
  } catch (e) {
    console.warn('[adminDeleteUser] subcollections cleanup failed (continuing):', e?.message || e);
  }

  // 2) Delete top-level FCM tokens owned by user
  try {
    const tokenSnap = await db.collection('fcm_tokens').where('userId', '==', userId).get();
    if (!tokenSnap.empty) {
      const batch = db.batch();
      tokenSnap.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }
  } catch (e) {
    console.warn('[adminDeleteUser] token cleanup failed (continuing):', e?.message || e);
  }

  // 3) Delete seller stores
  try {
    let lastStore = null;
    for (;;) {
      let q = db.collection('stores').where('sellerId', '==', userId).limit(500);
      if (lastStore) q = q.startAfter(lastStore);
      const snap = await q.get();
      if (snap.empty) break;
      const batch = db.batch();
      snap.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
      lastStore = snap.docs[snap.docs.length - 1];
      if (snap.size < 500) break;
    }
  } catch (e) {
    console.warn('[adminDeleteUser] stores cleanup failed (continuing):', e?.message || e);
  }

  // 4) Delete seller products
  try {
    let lastProduct = null;
    for (;;) {
      let q = db.collection('products').where('ownerId', '==', userId).limit(500);
      if (lastProduct) q = q.startAfter(lastProduct);
      const snap = await q.get();
      if (snap.empty) break;
      const batch = db.batch();
      snap.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
      lastProduct = snap.docs[snap.docs.length - 1];
      if (snap.size < 500) break;
    }
  } catch (e) {
    console.warn('[adminDeleteUser] products cleanup failed (continuing):', e?.message || e);
  }

  // 5) Delete orders where seller is this user OR buyer is this user
  try {
    const deleteOrdersWhere = async (field) => {
      let lastDoc = null;
      for (;;) {
        let q = db.collection('orders').where(field, '==', userId).limit(300);
        if (lastDoc) q = q.startAfter(lastDoc);
        const snap = await q.get();
        if (snap.empty) break;
        const batch = db.batch();
        snap.docs.forEach((d) => batch.delete(d.ref));
        await batch.commit();
        lastDoc = snap.docs[snap.docs.length - 1];
        if (snap.size < 300) break;
      }
    };
    await deleteOrdersWhere('sellerId');
    await deleteOrdersWhere('buyerId');
  } catch (e) {
    console.warn('[adminDeleteUser] orders cleanup failed (continuing):', e?.message || e);
  }

  // 6) Delete chats where user is buyer or seller (include messages subcollection)
  try {
    let lastChat = null;
    for (;;) {
      let q = db.collection('chats').where('sellerId', '==', userId).limit(200);
      if (lastChat) q = q.startAfter(lastChat);
      const snap = await q.get();
      if (snap.empty) break;
      for (const d of snap.docs) {
        // delete messages subcollection in batches
        const msgCol = d.ref.collection('messages');
        let lastMsg = null;
        for (;;) {
          let mq = msgCol.limit(500);
          if (lastMsg) mq = mq.startAfter(lastMsg);
          const ms = await mq.get();
          if (ms.empty) break;
          const mb = db.batch();
          ms.docs.forEach((m) => mb.delete(m.ref));
          await mb.commit();
          lastMsg = ms.docs[ms.docs.length - 1];
          if (ms.size < 500) break;
        }
        await d.ref.delete();
      }
      lastChat = snap.docs[snap.docs.length - 1];
      if (snap.size < 200) break;
    }
    // Chats where user is buyer
    lastChat = null;
    for (;;) {
      let q = db.collection('chats').where('buyerId', '==', userId).limit(200);
      if (lastChat) q = q.startAfter(lastChat);
      const snap = await q.get();
      if (snap.empty) break;
      for (const d of snap.docs) {
        const msgCol = d.ref.collection('messages');
        let lastMsg = null;
        for (;;) {
          let mq = msgCol.limit(500);
          if (lastMsg) mq = mq.startAfter(lastMsg);
          const ms = await mq.get();
          if (ms.empty) break;
          const mb = db.batch();
          ms.docs.forEach((m) => mb.delete(m.ref));
          await mb.commit();
          lastMsg = ms.docs[ms.docs.length - 1];
          if (ms.size < 500) break;
        }
        await d.ref.delete();
      }
      lastChat = snap.docs[snap.docs.length - 1];
      if (snap.size < 200) break;
    }
  } catch (e) {
    console.warn('[adminDeleteUser] chats cleanup failed (continuing):', e?.message || e);
  }

  // 7) Delete the user document
  try {
    await userRef.delete();
  } catch (e) {
    console.warn('[adminDeleteUser] user doc delete failed:', e?.message || e);
  }

  // 8) Delete Auth user
  try {
    await admin.auth().deleteUser(userId);
  } catch (e) {
    // If already deleted, ignore
    if (String(e?.errorInfo?.code || e?.code || '').includes('auth/user-not-found')) {
      console.log('[adminDeleteUser] auth user not found; continuing');
    } else {
      console.warn('[adminDeleteUser] auth delete failed:', e?.message || e);
    }
  }

  // Note: We purposely do not delete historical orders/chats for auditability.
  return { ok: true };
});

// === Admin: reconcile EFT CSV (manual upload paste) ===
exports.reconcileEftCsv = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  const isAdminCaller = context.auth.token?.admin === true || context.auth.token?.role === 'admin';
  if (!isAdminCaller) throw new functions.https.HttpsError('permission-denied', 'Admin only');
  const csv = String(data?.csv || '').trim();
  const delimiter = String(data?.delimiter || ',');
  if (!csv) throw new functions.https.HttpsError('invalid-argument', 'csv is required');

  const lines = csv.split(/\r?\n/).filter(l => l.trim().length > 0);
  const header = lines[0];
  const rows = lines.slice(1);
  const headers = header.split(delimiter).map(h => h.trim().toLowerCase());
  const idxRef = headers.findIndex(h => h.includes('reference') || h === 'ref' || h === 'orderid' || h === 'order_id');
  const idxAmt = headers.findIndex(h => h.includes('amount') || h === 'amt' || h === 'value' || h === 'gross');
  if (idxRef < 0 || idxAmt < 0) {
    throw new functions.https.HttpsError('invalid-argument', 'CSV must include reference and amount columns');
  }

  const matched = [];
  const unmatched = [];
  for (const line of rows) {
    const cols = line.split(delimiter);
    const refRaw = (cols[idxRef] || '').toString().trim();
    const amtRaw = (cols[idxAmt] || '').toString().trim().replace(/[,\s]/g, '');
    const amount = Number(amtRaw);
    const orderId = refRaw; // Expect exact order ID in reference
    if (!orderId || !isFinite(amount) || amount <= 0) {
      unmatched.push({ reference: refRaw, amount });
      continue;
    }
    try {
      const oref = db.collection('orders').doc(orderId);
      const osnap = await oref.get();
      if (!osnap.exists) { unmatched.push({ reference: refRaw, amount, reason: 'order_not_found' }); continue; }
      const odata = osnap.data() || {};
      const status = String(odata.status || '').toLowerCase();
      const paymentStatus = String(odata.paymentStatus || '').toLowerCase();
      const total = Number(odata.totalPrice || odata.total || 0);
      if (paymentStatus === 'paid') { matched.push({ orderId, amount, note: 'already_paid' }); continue; }
      if (Math.abs(total - amount) > 0.01) { unmatched.push({ orderId, amount, expected: total, reason: 'amount_mismatch' }); continue; }
      await oref.set({ paymentMethod: 'eft', paymentStatus: 'paid', updatedAt: admin.firestore.FieldValue.serverTimestamp(), trackingUpdates: admin.firestore.FieldValue.arrayUnion({ by: 'admin', description: 'EFT payment received and reconciled', timestamp: new Date().toISOString() }) }, { merge: true });
      await db.collection('recent_payments').add({ orderId, method: 'eft', amount, reconciledAt: admin.firestore.FieldValue.serverTimestamp(), by: context.auth.uid });
      matched.push({ orderId, amount });
    } catch (e) {
      unmatched.push({ reference: refRaw, amount, error: String(e.message || e) });
    }
  }
  return { ok: true, matched, unmatched, totalRows: rows.length };
});

// === Admin: mark single EFT paid (manual) ===
exports.adminMarkEftPaid = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  const isAdminCaller = context.auth.token?.admin === true || context.auth.token?.role === 'admin';
  if (!isAdminCaller) throw new functions.https.HttpsError('permission-denied', 'Admin only');
  const orderId = String(data?.orderId || '').trim();
  const amount = Number(data?.amount || 0);
  const override = Boolean(data?.override === true);
  if (!orderId || amount <= 0) throw new functions.https.HttpsError('invalid-argument', 'orderId and amount required');
  const oref = db.collection('orders').doc(orderId);
  const osnap = await oref.get();
  if (!osnap.exists) throw new functions.https.HttpsError('not-found', 'Order not found');
  const odata = osnap.data() || {};
  const total = Number(odata.totalPrice || odata.total || 0);
  if (!override && Math.abs(total - amount) > 0.01) {
    throw new functions.https.HttpsError('failed-precondition', 'Amount mismatch; enable override to force');
  }
  await oref.set({ paymentMethod: 'eft', paymentStatus: 'paid', updatedAt: admin.firestore.FieldValue.serverTimestamp(), trackingUpdates: admin.firestore.FieldValue.arrayUnion({ by: 'admin', description: 'EFT payment marked paid', timestamp: new Date().toISOString() }) }, { merge: true });
  await db.collection('recent_payments').add({ orderId, method: 'eft', amount, reconciledAt: admin.firestore.FieldValue.serverTimestamp(), by: context.auth.uid, override });
  return { ok: true };
});

// === Admin: create payout batch for all eligible sellers, email CSV ===
exports.createPayoutBatch = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  const isAdminCaller = context.auth.token?.admin === true || context.auth.token?.role === 'admin';
  if (!isAdminCaller) throw new functions.https.HttpsError('permission-denied', 'Admin only');
  const minAmount = Number(data?.minAmount || MIN_PAYOUT_AMOUNT);
  const maxSellers = Number(data?.maxSellers || 1000);
  const batchLabel = data?.label ? String(data.label) : new Date().toISOString().slice(0,10);

  const adminEmail = process.env.ADMIN_PAYOUT_EMAIL || '';
  const transporter = await ensureTransporter().catch(() => null);

  const sellersSnap = await db.collection('platform_receivables').get();
  let processed = 0;
  let created = 0;
  const csvRows = [['payoutId','sellerId','amount','gross','commission','orders','accountHolder','bankName','accountNumber','branchCode','reference']];

  for (const sellerDoc of sellersSnap.docs) {
    if (processed >= maxSellers) break;
    const sellerId = sellerDoc.id;
    const elig = await getEligibleReceivablesForSeller(sellerId);
    if (elig.net < minAmount || elig.entryIds.length === 0) { processed += 1; continue; }

    // fetch bank snapshot
    const bankDoc = await db.collection('users').doc(sellerId).collection('payout').doc('bank').get();
    if (!bankDoc.exists) { processed += 1; continue; }
    const bank = bankDoc.data() || {};

    const payoutRef = db.collection('payouts').doc();
    const userPayoutRef = db.collection('users').doc(sellerId).collection('payouts').doc(payoutRef.id);

    await db.runTransaction(async (tx) => {
      const now = admin.firestore.FieldValue.serverTimestamp();
      const base = {
        id: payoutRef.id,
        sellerId,
        currency: 'ZAR',
        amount: elig.net,
        gross: elig.gross,
        commission: elig.commission,
        status: 'processing', // directly to processing for batch
        orderIds: elig.orderIds,
        entryIds: elig.entryIds,
        batchLabel,
        bankSnapshot: {
          accountHolder: bank.accountHolder || null,
          bankName: bank.bankName || null,
          accountNumber: bank.accountNumber || null,
          branchCode: bank.branchCode || null,
          accountType: bank.accountType || null,
        },
        createdAt: now,
        updatedAt: now,
      };
      tx.set(payoutRef, base, { merge: true });
      tx.set(userPayoutRef, base, { merge: true });
      // lock entries
      elig.entryIds.forEach((eid) => {
        const eref = db.collection('platform_receivables').doc(sellerId).collection('entries').doc(eid);
        tx.set(eref, { status: 'locked', payoutLockId: payoutRef.id, lockedAt: now, updatedAt: now }, { merge: true });
      });
      // mark orders with payoutRef (best-effort trace)
      elig.orderIds.forEach((oid) => {
        const oref = db.collection('orders').doc(oid);
        tx.set(oref, { payoutRequestId: payoutRef.id, updatedAt: now }, { merge: true });
      });
    });

    created += 1;
    processed += 1;
    csvRows.push([
      payoutRef.id,
      sellerId,
      String(elig.net.toFixed(2)),
      String(elig.gross.toFixed(2)),
      String(elig.commission.toFixed(2)),
      String(elig.orderIds.length),
      bank.accountHolder || '',
      bank.bankName || '',
      bank.accountNumber || '',
      bank.branchCode || '',
      '',
    ]);
  }

  // Build CSV
  const csv = csvRows.map((r) => r.map((c) => {
    const s = String(c ?? '');
    return /[",\n]/.test(s) ? '"' + s.replace(/"/g,'""') + '"' : s;
  }).join(','))
  .join('\n');

  // Email CSV (best effort)
  if (transporter && adminEmail) {
    try {
      const from = process.env.MAIL_FROM || '';
      await transporter.sendMail({
        from: from || undefined,
        to: adminEmail,
        subject: `[Payout Batch] ${batchLabel} (${created} payouts)`,
        text: csv,
        attachments: [{ filename: `payout_batch_${batchLabel}.csv`, content: csv, contentType: 'text/csv' }],
      });
    } catch (e) {
      console.warn('[batch email] failed', e);
    }
  }

  return { ok: true, created, processed, csv };
});

// Weekly auto-batch (disabled unless env set)
exports.autoCreatePayoutBatch = functions.pubsub.schedule('0 8 * * 1').onRun(async () => {
  try {
    const enabled = String(process.env.AUTO_BATCH_ENABLED || 'false').toLowerCase() === 'true';
    if (!enabled) return null;
    const minAmount = Number(process.env.MIN_PAYOUT_AMOUNT || 50);
    const result = await exports.createPayoutBatch.run({ data: { minAmount, label: 'auto_weekly' } });
    console.log('[autoCreatePayoutBatch] result', result);
  } catch (e) {
    console.error('[autoCreatePayoutBatch] error', e);
  }
  return null;
});