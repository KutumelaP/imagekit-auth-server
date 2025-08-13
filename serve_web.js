const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3000;

const server = http.createServer((req, res) => {
  let filePath = path.join(__dirname, 'build', 'web', req.url === '/' ? 'index.html' : req.url);
  
  // Handle file extensions
  if (!path.extname(filePath)) {
    filePath = path.join(filePath, 'index.html');
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      // If file not found, serve index.html for SPA routing
      fs.readFile(path.join(__dirname, 'build', 'web', 'index.html'), (err, data) => {
        if (err) {
          res.writeHead(404);
          res.end('File not found');
        } else {
          res.writeHead(200, { 'Content-Type': 'text/html' });
          res.end(data);
        }
      });
    } else {
      // Determine content type
      const ext = path.extname(filePath);
      let contentType = 'text/html';
      
      switch (ext) {
        case '.js':
          contentType = 'text/javascript';
          break;
        case '.css':
          contentType = 'text/css';
          break;
        case '.json':
          contentType = 'application/json';
          break;
        case '.png':
          contentType = 'image/png';
          break;
        case '.jpg':
          contentType = 'image/jpg';
          break;
        case '.ico':
          contentType = 'image/x-icon';
          break;
      }
      
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(data);
    }
  });
});

server.listen(PORT, () => {
  console.log(`🚀 Web server running at http://localhost:${PORT}`);
  console.log(`📱 Access from iOS Safari: http://YOUR_IP_ADDRESS:${PORT}`);
  console.log(`💡 To find your IP: ipconfig (Windows) or ifconfig (Mac/Linux)`);
  console.log(`🌐 Make sure your phone and computer are on the same WiFi network`);
}); 