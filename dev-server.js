const express = require('express');
const bodyParser = require('body-parser');
const listHandler = require('./api/imagekit/list');
const deleteHandler = require('./api/imagekit/batchDelete');

const app = express();
app.use(bodyParser.json());

app.get('/api/imagekit/list', (req, res) => listHandler(req, res));
app.post('/api/imagekit/batchDelete', (req, res) => deleteHandler(req, res));

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`Local ImageKit API running at http://localhost:${port}/api/imagekit`);
});
