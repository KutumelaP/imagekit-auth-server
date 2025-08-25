// Generate a PayFast payload with signature for curl testing
// Usage: node scripts/pf_curl_test.js [sandbox|live] [doc|alpha] [usepass|nopass]

function pfEncode(value) {
  return encodeURIComponent(String(value))
    .replace(/%20/g, '+')
    .replace(/%0D%0A/g, '%0A')
    .replace(/!/g, '%21')
    .replace(/'/g, '%27')
    .replace(/\(/g, '%28')
    .replace(/\)/g, '%29')
    .replace(/\*/g, '%2A');
}

const mode = (process.argv[2] || 'sandbox').toLowerCase();
const orderMode = (process.argv[3] || 'doc').toLowerCase(); // 'doc' or 'alpha'
const passMode = (process.argv[4] || 'usepass').toLowerCase(); // 'usepass' or 'nopass'

const isSandbox = mode !== 'live';

const data = {
  // Merchant details
  merchant_id: isSandbox ? '10000100' : '23918934',
  merchant_key: isSandbox ? '46f0cd694581a' : 'fxuj8ymlgqwra',
  return_url: 'https://example.com/success',
  cancel_url: 'https://example.com/cancel',
  notify_url: 'https://example.com/notify',
  // Customer details
  name_first: 'John',
  name_last: 'Doe',
  email_address: 'john@doe.com',
  // Transaction details
  amount: '5.00',
  item_name: 'Test Item'
};

// Preferred field order per PayFast Custom Integration docs
const preferredOrder = [
  'merchant_id', 'merchant_key', 'return_url', 'cancel_url', 'notify_url',
  'name_first', 'name_last', 'email_address', 'cell_number',
  'm_payment_id', 'amount', 'item_name', 'item_description',
  'custom_int1', 'custom_int2', 'custom_int3', 'custom_int4', 'custom_int5',
  'custom_str1', 'custom_str2', 'custom_str3', 'custom_str4', 'custom_str5',
  'email_confirmation', 'confirmation_address',
  'payment_method'
];

let orderedKeys = [];
if (orderMode === 'alpha') {
  orderedKeys = Object.keys(data)
    .filter((k) => data[k] !== undefined && data[k] !== null && String(data[k]) !== '')
    .sort();
} else {
  const seen = new Set();
  for (const k of preferredOrder) {
    if (k === 'signature') continue;
    const v = data[k];
    if (v !== undefined && v !== null && String(v) !== '') {
      orderedKeys.push(k); seen.add(k);
    }
  }
  for (const k of Object.keys(data)) {
    if (k === 'signature') continue;
    if (seen.has(k)) continue;
    const v = data[k];
    if (v !== undefined && v !== null && String(v) !== '') {
      orderedKeys.push(k); seen.add(k);
    }
  }
}

const encoded = orderedKeys.map((k) => `${k}=${pfEncode(data[k])}`).join('&');

const passphrase = isSandbox ? 'jt7NOE43FZPn' : 'PeterKutumela2025';
const usePass = passMode !== 'nopass';
const toSign = usePass ? `${encoded}&passphrase=${pfEncode(passphrase)}` : encoded;
const signature = require('crypto').createHash('md5').update(toSign).digest('hex');

process.stdout.write(encoded + `&signature=${signature}`);


