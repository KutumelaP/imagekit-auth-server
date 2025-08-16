const axios = require('axios');
const admin = require('firebase-admin');
require('dotenv').config();

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
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
}

module.exports = async (req, res) => {
  allowCors(res);
  if (req.method === 'OPTIONS') return res.status(204).send('');
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

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

  const body = req.body || {};
  const { fileIds } = body;
  if (!Array.isArray(fileIds) || fileIds.length === 0) {
    return res.status(400).json({ error: 'fileIds is required' });
  }

  try {
    const ikRes = await axios.post(`${IK_API_BASE}/files/batch/deleteByFileIds`, { fileIds }, {
      headers: {
        Authorization: `Basic ${Buffer.from(`${privateKey}:`).toString('base64')}`,
        'Content-Type': 'application/json',
      },
      timeout: 20000,
    });

    return res.status(200).json(ikRes.data);
  } catch (e) {
    console.error('imagekit delete error', e?.response?.status, e?.response?.data || e.message);
    return res.status(500).json({ error: 'Failed to delete images' });
  }
};
