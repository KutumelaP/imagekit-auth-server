const express = require('express');
const ImageKit = require('imagekit');
const axios = require('axios');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;
const PARGO_MAP_TOKEN = process.env.PARGO_MAP_TOKEN || '';

// Allow all origins (or restrict in production)
app.use(cors());
app.use(express.json());

// Validate ImageKit configuration (optional for local dev)
const validateImageKitConfig = () => {
  const publicKey = process.env.IMAGEKIT_PUBLIC_KEY;
  const privateKey = process.env.IMAGEKIT_PRIVATE_KEY;
  const urlEndpoint = process.env.IMAGEKIT_URL_ENDPOINT;

  if (!publicKey || !privateKey || !urlEndpoint) {
    console.warn('ImageKit not configured: set IMAGEKIT_PUBLIC_KEY/IMAGEKIT_PRIVATE_KEY/IMAGEKIT_URL_ENDPOINT to enable /auth');
    return null;
  }

  console.log('ImageKit Configuration:');
  console.log('Public Key:', publicKey.substring(0, 20) + '...');
  console.log('Private Key:', privateKey.substring(0, 20) + '...');
  console.log('URL Endpoint:', urlEndpoint);

  return { publicKey, privateKey, urlEndpoint };
};

const config = validateImageKitConfig();

const imagekit = config
  ? new ImageKit({
      publicKey: config.publicKey,
      privateKey: config.privateKey,
      urlEndpoint: config.urlEndpoint,
    })
  : null;

app.get('/auth', async (req, res) => {
  try {
    if (!imagekit) {
      return res.status(503).json({ error: 'ImageKit not configured on server' });
    }
    console.log('🔐 Generating ImageKit authentication parameters...');
    const authParams = imagekit.getAuthenticationParameters();
    console.log('✅ Auth parameters generated successfully');
    res.json(authParams);
  } catch (error) {
    console.error('❌ Error generating auth parameters:', error);
    res.status(500).json({
      error: 'Failed to generate authentication parameters',
      details: error.message
    });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Pargo proxy for web (avoid CORS in browser)
app.get('/pargo/pickup-points', async (req, res) => {
  try {
    const { lat, lng, radius_km } = req.query || {};
    if (!lat || !lng) {
      return res.status(400).json({ error: 'lat and lng are required' });
    }
    if (!PARGO_MAP_TOKEN) {
      return res.status(500).json({ error: 'PARGO_MAP_TOKEN not configured on server' });
    }

    const url = 'https://api.pargo.co.za/api/v1/pickup-points';
    const { data } = await axios.get(url, {
      params: {
        lat,
        lng,
        radius_km: radius_km || '10.0',
      },
      headers: {
        Authorization: `Bearer ${PARGO_MAP_TOKEN}`,
        Accept: 'application/json',
        'User-Agent': 'Mozilla/5.0 (compatible; MzansiMarketplace/1.0)'
      },
      timeout: 15000,
    });
    res.json(data);
  } catch (e) {
    console.error('Pargo proxy error', e.response?.status, e.response?.data || e.message);
    res.status(e.response?.status || 500).json({ error: 'Pargo proxy failed', details: e.response?.data || e.message });
  }
});

// FCM HTTP v1 via service account (no Blaze Functions required)
const { GoogleAuth } = require('google-auth-library');
const FCM_PROJECT_ID = process.env.FCM_PROJECT_ID;
if (!FCM_PROJECT_ID) {
  console.warn('FCM_PROJECT_ID not set. /notify/send will fail until configured.');
}
const FCM_AUDIENCE = FCM_PROJECT_ID
  ? 'https://fcm.googleapis.com/google.firebase.fcm.v1/projects/' + FCM_PROJECT_ID + '/messages:send'
  : null;

async function getAccessToken() {
  const auth = new GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/firebase.messaging']
  });
  const client = await auth.getClient();
  const tokenResponse = await client.getAccessToken();
  return tokenResponse.token;
}

app.post('/notify/send', async (req, res) => {
  try {
    if (!FCM_PROJECT_ID) {
      return res.status(500).json({ error: 'FCM_PROJECT_ID not configured on server' });
    }
    const { token, title, body, data, image } = req.body || {};
    if (!token || !title || !body) {
      return res.status(400).json({ error: 'token, title, and body are required' });
    }

    const accessToken = await getAccessToken();
    const message = {
      message: {
        token,
        notification: { title, body, ...(image ? { image } : {}) },
        data: data || {},
        android: { notification: { channel_id: (data && data.type === 'chat_message') ? 'chat_channel' : 'order_channel', priority: 'high' } },
        apns: { payload: { aps: { sound: 'default' } } }
      }
    };

    const url = `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`;
    const { data: json } = await axios.post(url, message, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      timeout: 10000,
    });
    res.json({ ok: true, response: json });
  } catch (e) {
    console.error('notify/send error', e);
    res.status(500).json({ error: 'Internal error', details: e.message });
  }
});

app.listen(PORT, () => {
  console.log(`🚀 ImageKit Auth Server running at http://localhost:${PORT}`);
  console.log(`📡 Health check available at http://localhost:${PORT}/health`);
});
