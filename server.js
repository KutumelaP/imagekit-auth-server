const express = require('express');
const ImageKit = require('imagekit');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Allow all origins (or restrict in production)
app.use(cors());
app.use(express.json());

// Validate ImageKit configuration
const validateImageKitConfig = () => {
  const publicKey = process.env.IMAGEKIT_PUBLIC_KEY || "public_tAO0SkfLl/37FQN+23c/bkAyfYg=";
  const privateKey = process.env.IMAGEKIT_PRIVATE_KEY || "private_cZ0y1MLeTaZbOYoxDAVI7fTIbTM=";
  const urlEndpoint = process.env.IMAGEKIT_URL_ENDPOINT || "https://ik.imagekit.io/tkhb6zllk";
  
  console.log('ImageKit Configuration:');
  console.log('Public Key:', publicKey.substring(0, 20) + '...');
  console.log('Private Key:', privateKey.substring(0, 20) + '...');
  console.log('URL Endpoint:', urlEndpoint);
  
  return { publicKey, privateKey, urlEndpoint };
};

const config = validateImageKitConfig();

const imagekit = new ImageKit({
  publicKey: config.publicKey,
  privateKey: config.privateKey,
  urlEndpoint: config.urlEndpoint
});

app.get('/auth', async (req, res) => {
  try {
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

app.listen(PORT, () => {
  console.log(`🚀 ImageKit Auth Server running at http://localhost:${PORT}`);
  console.log(`📡 Health check available at http://localhost:${PORT}/health`);
});
