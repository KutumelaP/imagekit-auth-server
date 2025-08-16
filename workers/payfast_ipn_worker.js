// Cloudflare Worker: PayFast IPN + dynamic OG
// Usage: deploy to Workers, set route like yourdomain.com/api/ipn -> worker
// and yourdomain.com/meta/store -> worker

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/api/ipn' && request.method === 'POST') {
      return handlePayfastIPN(request, env);
    }
    if (url.pathname === '/checkout' && request.method === 'GET') {
      return handleCheckout(request, env);
    }
    if (url.pathname === '/meta/store' && request.method === 'GET') {
      return handleMeta(request, env);
    }
    return new Response('Not found', { status: 404 });
  }
}

async function handlePayfastIPN(request, env) {
  const clientIp = request.headers.get('CF-Connecting-IP') || request.headers.get('x-forwarded-for') || '';
  const whitelist = (env.PAYFAST_IP_WHITELIST || '').split(',').map((s) => s.trim()).filter(Boolean);
  if (whitelist.length && !ipWhitelisted(clientIp, whitelist)) {
    return new Response('Forbidden', { status: 403 });
  }

  const form = await request.formData();
  const data = Object.fromEntries(form.entries());
  const merchantId = env.PAYFAST_MERCHANT_ID || '';
  if (merchantId && data['merchant_id'] && data['merchant_id'] !== merchantId) {
    return new Response('Bad merchant', { status: 400 });
  }

  // Server-side validation with PayFast (authoritative)
  const validateUrl = env.PAYFAST_VALIDATE_URL || 'https://www.payfast.co.za/eng/query/validate';
  const bodyEncoded = new URLSearchParams();
  for (const [k, v] of Object.entries(data)) bodyEncoded.append(k, v);
  const pfResp = await fetch(validateUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'User-Agent': 'CloudflareWorker/1.0' },
    body: bodyEncoded.toString(),
  });
  const pfText = (await pfResp.text()).trim().toUpperCase();
  if (!pfResp.ok || !pfText.includes('VALID')) {
    return new Response('Invalid IPN', { status: 400 });
  }

  // At this point IP + merchant + remote VALID passed; update Firestore
  const orderId = data['m_payment_id'];
  const status = data['payment_status'];
  try {
    const project = env.FIREBASE_PROJECT;
    const doc = encodeURIComponent(`orders/${orderId}`);
    const update = { status, payfast: data, ipnValidatedAt: new Date().toISOString() };
    const resp = await fetch(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/${doc}?updateMask.fieldPaths=status&updateMask.fieldPaths=payfast&updateMask.fieldPaths=ipnValidatedAt`, {
      method: 'PATCH',
      headers: { 'Authorization': `Bearer ${env.FIREBASE_BEARER}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields: mapToFields(update) })
    });
    if (!resp.ok) return new Response('Error', { status: 500 });
    return new Response('OK');
  } catch (e) {
    return new Response('Error', { status: 500 });
  }
}

async function handleMeta(request, env) {
  const id = new URL(request.url).searchParams.get('id');
  if (!id) return new Response('Missing id', { status: 400 });
  try {
    const project = env.FIREBASE_PROJECT;
    const doc = await fetch(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/users/${id}`);
    if (!doc.ok) return new Response('Not found', { status: 404 });
    const json = await doc.json();
    const data = fieldsToObj(json.fields || {});
    const name = data.storeName || 'Store';
    const desc = (data.story || '').toString().slice(0, 160);
    const image = data.profileImageUrl || '';
    const base = env.PUBLIC_BASE_URL || 'https://marketplace-8d6bd.web.app';
    const url = `${base}/store/${id}`;
    const html = `<!doctype html><html><head><meta charset="utf-8" />
    <title>${name} – Mzansi Marketplace</title>
    <meta name="description" content="${escapeHtml(desc)}" />
    <meta property="og:title" content="${escapeHtml(name)} – Mzansi Marketplace" />
    <meta property="og:description" content="${escapeHtml(desc)}" />
    <meta property="og:type" content="website" />
    <meta property="og:url" content="${url}" />
    ${image ? `<meta property=\"og:image\" content=\"${image}\" />` : ''}
    <meta http-equiv="refresh" content="0; url=${url}" />
    <link rel="canonical" href="${url}" />
    </head><body>Redirecting…</body></html>`;
    return new Response(html, { headers: { 'Content-Type': 'text/html' } });
  } catch (e) {
    return new Response('Error', { status: 500 });
  }
}

function mapToFields(obj) {
  const out = {};
  for (const [k, v] of Object.entries(obj)) {
    out[k] = typeof v === 'string' ? { stringValue: v } : Array.isArray(v) ? { arrayValue: { values: v.map((x) => ({ stringValue: String(x) })) } } : { stringValue: JSON.stringify(v) };
  }
  return out;
}

function ipWhitelisted(ip, list) {
  for (const entry of list) {
    if (entry.includes('/')) {
      const [base, mask] = entry.split('/');
      if (mask === '24' && ip.startsWith(base.substring(0, base.lastIndexOf('.') + 1))) return true;
    } else if (ip === entry) {
      return true;
    }
  }
  return false;
}

function fieldsToObj(fields) {
  const out = {};
  for (const [k, v] of Object.entries(fields)) {
    out[k] = v.stringValue ?? v.integerValue ?? v.doubleValue ?? '';
  }
  return out;
}

function escapeHtml(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

async function handleCheckout(request, env) {
  try {
    const orderId = new URL(request.url).searchParams.get('orderId');
    if (!orderId) return new Response('Missing orderId', { status: 400 });
    const project = env.FIREBASE_PROJECT;
    const doc = await fetch(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/orders/${orderId}`, {
      headers: { 'Authorization': `Bearer ${env.FIREBASE_BEARER}` }
    });
    if (!doc.ok) return new Response('Order not found', { status: 404 });
    const json = await doc.json();
    const fields = json.fields || {};
    const amount = parseFloat(fields.total?.doubleValue ?? fields.totalPrice?.doubleValue ?? '0');
    const buyerName = (fields.buyerName?.stringValue || 'Customer').substring(0, 30);
    const itemName = (fields.sellerName?.stringValue || 'Order').substring(0, 50);

    const merchantId = env.PAYFAST_MERCHANT_ID;
    const merchantKey = env.PAYFAST_MERCHANT_KEY;
    const passphrase = env.PAYFAST_PASSPHRASE || '';
    const mode = (env.PAYFAST_MODE || 'sandbox').toLowerCase();
    const endpoint = mode === 'live' ? 'https://www.payfast.co.za/eng/process' : 'https://sandbox.payfast.co.za/eng/process';
    const returnUrl = env.RETURN_URL;
    const cancelUrl = env.CANCEL_URL;
    const notifyUrl = env.NOTIFY_URL; // should point to /api/ipn

    const params = new URLSearchParams();
    params.append('merchant_id', merchantId);
    params.append('merchant_key', merchantKey);
    params.append('return_url', returnUrl);
    params.append('cancel_url', cancelUrl);
    params.append('notify_url', notifyUrl);
    params.append('m_payment_id', orderId);
    params.append('amount', amount.toFixed(2));
    params.append('item_name', itemName);
    params.append('name_first', buyerName);

    // Signature
    const pairs = [];
    for (const [k, v] of params.entries()) {
      if (v) pairs.push(`${encodeURIComponent(k)}=${encodeURIComponent(v)}`);
    }
    let sigStr = pairs.join('&');
    if (passphrase) sigStr += `&passphrase=${encodeURIComponent(passphrase)}`;
    const signature = await md5(sigStr);
    params.append('signature', signature);

    const html = `<!doctype html><html><body>
      <form id="pf" action="${endpoint}" method="post">
        ${[...params.entries()].map(([k,v]) => `<input type=hidden name="${k}" value="${v}">`).join('\n')}
      </form>
      <script>document.getElementById('pf').submit();</script>
    </body></html>`;
    return new Response(html, { headers: { 'Content-Type': 'text/html' } });
  } catch (e) {
    return new Response('Error', { status: 500 });
  }
}

async function md5(str) {
  const data = new TextEncoder().encode(str);
  const digest = await crypto.subtle.digest('MD5', data);
  const bytes = Array.from(new Uint8Array(digest));
  return bytes.map((b) => b.toString(16).padStart(2, '0')).join('');
}


