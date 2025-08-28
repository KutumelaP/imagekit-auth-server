const https = require('https');

const data = JSON.stringify({
  data: {
    userId: "cKXh5nQSZ3SW2bNXFz7669srXH93"
  }
});

const options = {
  hostname: 'us-central1-marketplace-8d6bd.cloudfunctions.net',
  path: '/getSellerAvailableBalance',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

console.log('🔄 Testing getSellerAvailableBalance function...');

const req = https.request(options, (res) => {
  let responseData = '';
  
  res.on('data', (chunk) => {
    responseData += chunk;
  });
  
  res.on('end', () => {
    console.log('📊 Response Status:', res.statusCode);
    console.log('📋 Response Data:');
    try {
      const parsed = JSON.parse(responseData);
      console.log(JSON.stringify(parsed, null, 2));
    } catch (e) {
      console.log('Raw response:', responseData);
    }
  });
});

req.on('error', (e) => {
  console.error('❌ Error:', e.message);
});

req.write(data);
req.end();
