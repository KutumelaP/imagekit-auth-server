/**
 * Canonicalize product subcategories in Firestore.
 * Usage: node scripts/canonicalize_subcategories.js
 */
const admin = require('firebase-admin');
const path = require('path');

// Load service account from project root
const serviceAccount = require(path.join(process.cwd(), 'serviceAccountKey.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

function toTitleCase(input) {
  return input.split(/\s+/).map(w => w ? w[0].toUpperCase() + w.slice(1) : w).join(' ');
}

const canonical = new Map();
function add(canon, arr) { arr.forEach(v => canonical.set(v.toLowerCase().trim(), canon)); }
add('Hoodie', ['hoodie', 'hoodies', 'hooded sweater', 'hooded sweatshirts']);
add('T-Shirt', ['t shirt', 't-shirt', 'tee', 'tees', 'tshirts']);
add('Sneakers', ['sneaker', 'sneakers', 'trainer', 'trainers']);
add('Jacket', ['jacket', 'jackets']);

function normalize(word) {
  const raw = (word || '').trim();
  if (!raw) return '';
  const lower = raw.toLowerCase();
  if (canonical.has(lower)) return canonical.get(lower);
  let singular = lower;
  if (singular.endsWith('ies') && singular.length > 3) {
    singular = singular.slice(0, -3) + 'y';
  } else if (singular.endsWith('s') && !singular.endsWith('ss')) {
    singular = singular.slice(0, -1);
  }
  if (canonical.has(singular)) return canonical.get(singular);
  return toTitleCase(singular);
}

async function run() {
  const batchSize = 300;
  let updated = 0;
  const snap = await db.collection('products').get();
  const docs = snap.docs;
  console.log(`Scanning ${docs.length} products...`);
  let batch = db.batch();
  let ops = 0;
  for (const doc of docs) {
    const data = doc.data();
    const sub = data.subcategory || '';
    const norm = normalize(sub);
    if (norm && norm !== sub) {
      batch.update(doc.ref, { subcategory: norm });
      ops++;
      updated++;
      if (ops >= batchSize) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
        console.log(`Committed ${updated} updates so far...`);
      }
    }
  }
  if (ops > 0) await batch.commit();
  console.log(`Done. Updated ${updated} documents.`);
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});


