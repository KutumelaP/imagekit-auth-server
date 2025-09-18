/*
  Analyze distinct categories and subcategories for a given store (sellerId).
  Usage:
    node scripts/analyze_store_subcategories.js <sellerId>

  Requires serviceAccountKey.json at project root with appropriate Firestore access.
*/

const admin = require('firebase-admin');
const path = require('path');

async function main() {
  const sellerId = process.argv[2];
  if (!sellerId) {
    console.error('Usage: node scripts/analyze_store_subcategories.js <sellerId>');
    process.exit(1);
  }

  // Initialize Firebase Admin
  try {
    const serviceAccountPath = path.resolve(process.cwd(), 'serviceAccountKey.json');
    admin.initializeApp({
      credential: admin.credential.cert(require(serviceAccountPath)),
    });
  } catch (e) {
    console.error('Failed to initialize Firebase Admin. Ensure serviceAccountKey.json exists at project root.');
    console.error(e);
    process.exit(1);
  }

  const db = admin.firestore();

  try {
    console.log(`🔎 Analyzing products for sellerId: ${sellerId}`);
    const snap = await db
      .collection('products')
      .where('ownerId', '==', sellerId)
      .get();

    console.log(`📦 Found ${snap.size} product(s)`);

    const categorySet = new Set();
    const subcategorySet = new Set();
    const byCategory = new Map(); // category -> Set(subcategories)

    for (const doc of snap.docs) {
      const data = doc.data() || {};
      const rawCategory = (data.category || '').toString();
      const rawSubcategory = (data.subcategory || data.subCategory || '').toString();

      const category = rawCategory.trim();
      const subcategory = rawSubcategory.trim();

      if (category) {
        categorySet.add(category);
        if (!byCategory.has(category)) byCategory.set(category, new Set());
      }
      if (subcategory) {
        subcategorySet.add(subcategory);
        if (category) byCategory.get(category).add(subcategory);
      }
    }

    console.log(`
📚 Summary for sellerId ${sellerId}:
  • Categories: ${categorySet.size}
  • Distinct subcategories (all): ${subcategorySet.size}
`);

    if (byCategory.size > 0) {
      console.log('🔎 Subcategories by category:');
      for (const [cat, subs] of byCategory.entries()) {
        const list = Array.from(subs).sort((a, b) => a.localeCompare(b));
        console.log(`  - ${cat} (${list.length}): ${list.join(', ')}`);
      }
    } else {
      console.log('No category/subcategory data present on products.');
    }
  } catch (e) {
    console.error('❌ Error analyzing subcategories:', e);
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

main();



