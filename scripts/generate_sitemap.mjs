import fs from 'fs';
import path from 'path';

async function main() {
  const project = process.env.FIREBASE_PROJECT;
  const serviceJson = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!project || !serviceJson) {
    console.error('Missing FIREBASE_PROJECT or FIREBASE_SERVICE_ACCOUNT');
    process.exit(1);
  }
  const sa = JSON.parse(serviceJson);
  const token = await getAccessToken(sa);
  const sellers = await fetch(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents:runQuery`, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'users' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'role' },
            op: 'EQUAL',
            value: { stringValue: 'seller' }
          }
        },
        limit: 10000
      }
    })
  }).then((r) => r.json());

  const base = process.env.BASE_URL || 'https://marketplace-8d6bd.web.app';
  const urls = [
    { loc: `${base}/`, changefreq: 'daily', priority: '0.8' }
  ];
  for (const row of sellers) {
    const doc = row.document;
    if (!doc) continue;
    const name = doc.name;
    const id = name.substring(name.lastIndexOf('/') + 1);
    urls.push({ loc: `${base}/store/${id}`, changefreq: 'daily', priority: '0.7' });
  }
  const xml = buildSitemap(urls);
  const out = path.join(process.cwd(), 'web', 'sitemap.xml');
  fs.writeFileSync(out, xml, 'utf8');
}

function buildSitemap(urls) {
  const items = urls.map((u) => `  <url>\n    <loc>${u.loc}</loc>\n    <changefreq>${u.changefreq}</changefreq>\n    <priority>${u.priority}</priority>\n  </url>`).join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${items}\n</urlset>\n`;
}

async function getAccessToken(sa) {
  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const now = Math.floor(Date.now() / 1000);
  const claim = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600
  }));
  const toSign = `${header}.${claim}`;
  const signature = await sign(toSign, sa.private_key);
  const jwt = `${toSign}.${signature}`;
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`
  });
  const json = await res.json();
  return json.access_token;
}

function base64url(str) {
  return Buffer.from(str).toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

async function sign(data, pem) {
  const crypto = await import('crypto');
  const sign = crypto.createSign('RSA-SHA256');
  sign.update(data);
  sign.end();
  const signature = sign.sign(pem);
  return signature.toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

main().catch((e) => { console.error(e); process.exit(1); });


