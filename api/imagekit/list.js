const axios = require('axios');
const admin = require('firebase-admin');
require('dotenv').config();

// Initialize Firebase Admin with service account from env if provided
if (!admin.apps.length) {
  try {
    const svc = process.env.FIREBASE_SERVICE_ACCOUNT
      ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
      : null;
    if (svc) {
      admin.initializeApp({ credential: admin.credential.cert(svc) });
    } else {
      admin.initializeApp();
    }
  } catch (e) {
    admin.initializeApp();
  }
}

const IK_API_BASE = 'https://api.imagekit.io/v1';

function allowCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
}

module.exports = async (req, res) => {
  allowCors(res);
  if (req.method === 'OPTIONS') return res.status(204).send('');
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  // Optional auth for local dev
  const skipAuth = process.env.SKIP_AUTH === 'true';
  if (!skipAuth) {
    const authHeader = req.headers.authorization || '';
    const idToken = authHeader.startsWith('Bearer ') ? authHeader.substring(7) : null;
    try {
      if (!idToken) throw new Error('Missing ID token');
      const decoded = await admin.auth().verifyIdToken(idToken);
      if (!decoded || !decoded.uid) throw new Error('Invalid ID token');
    } catch (e) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
  }

  const privateKey = process.env.IMAGEKIT_PRIVATE_KEY;
  if (!privateKey) return res.status(500).json({ error: 'Server not configured' });

  const { path, limit = 100, skip = 0, searchQuery } = req.query || {};

  try {
    const params = new URLSearchParams();
    params.append('limit', String(limit));
    params.append('skip', String(skip));
    if (path) params.append('path', path);
    if (searchQuery) params.append('searchQuery', searchQuery);

    const ikRes = await axios.get(`${IK_API_BASE}/files`, {
      params,
      headers: {
        Authorization: `Basic ${Buffer.from(`${privateKey}:`).toString('base64')}`,
      },
      timeout: 20000,
    });

    return res.status(200).json({ files: ikRes.data });
  } catch (e) {
    console.error('imagekit list error', e?.response?.status, e?.response?.data || e.message);
    return res.status(500).json({ error: 'Failed to list images' });
  }
};
