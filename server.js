const express = require('express');
const ImageKit = require('imagekit');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Allow all origins (or restrict in production)
app.use(cors());

const imagekit = new ImageKit({
  publicKey: process.env.IMAGEKIT_PUBLIC_KEY || "public_tAO0SkfLl/37FQN+23c/bkAyfYg=",
  privateKey: process.env.IMAGEKIT_PRIVATE_KEY || "private_cZ0y1MLeTaZbOYoxDAVI7fTIbTM=", // Provided private key
  urlEndpoint: process.env.IMAGEKIT_URL_ENDPOINT || "https://ik.imagekit.io/tkhb6zllk"
});

app.get('/auth', (req, res) => {
  const authParams = imagekit.getAuthenticationParameters();
  res.json(authParams);
});

app.listen(PORT, () => {
  console.log(`ImageKit Auth Server running at http://localhost:${PORT}`);
});
