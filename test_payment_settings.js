// Test script to verify payment settings are working correctly
// Run with: node test_payment_settings.js

const admin = require('firebase-admin');

// Initialize Firebase Admin (use your service account key)
if (!admin.apps.length) {
  try {
    const serviceAccount = require('./serviceAccountKey.json');
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log('✅ Firebase Admin initialized');
  } catch (error) {
    console.log('❌ Failed to initialize Firebase Admin:', error.message);
    process.exit(1);
  }
}

const db = admin.firestore();

async function testPaymentSettings() {
  try {
    console.log('\n🔍 Testing Payment Settings Configuration...\n');
    
    // 1. Check if payment settings document exists
    const settingsDoc = await db.collection('admin_settings').doc('payment_settings').get();
    
    if (!settingsDoc.exists) {
      console.log('❌ Payment settings document does not exist!');
      console.log('   Create it in your admin dashboard first.');
      return;
    }
    
    const settings = settingsDoc.data();
    console.log('✅ Payment settings document found');
    
    // 2. Display current settings
    console.log('\n📊 Current Payment Settings:');
    console.log('═══════════════════════════════════');
    console.log(`Platform Fee: ${settings.platformFeePercentage || 'NOT SET'}%`);
    console.log(`PayFast Fee: ${settings.payfastFeePercentage || 'NOT SET'}% + R${settings.payfastFixedFee || 'NOT SET'}`);
    console.log(`Holdback: ${settings.holdbackPercentage || 'NOT SET'}% for ${settings.holdbackPeriodDays || 'NOT SET'} days`);
    
    console.log('\n💰 Commission Rates:');
    console.log(`Pickup: ${settings.pickupPct || 'NOT SET'}%`);
    console.log(`Merchant Delivery: ${settings.merchantDeliveryPct || 'NOT SET'}%`);
    console.log(`Platform Delivery: ${settings.platformDeliveryPct || 'NOT SET'}%`);
    
    console.log('\n🧾 Buyer Fees:');
    console.log(`Service Fee: ${settings.buyerServiceFeePct || 'NOT SET'}% + R${settings.buyerServiceFeeFixed || 'NOT SET'}`);
    console.log(`Small Order Fee: R${settings.smallOrderFee || 'NOT SET'} (threshold: R${settings.smallOrderThreshold || 'NOT SET'})`);
    
    // 3. Test commission calculation function
    console.log('\n🧮 Testing Commission Calculation...');
    
    const testOrder = {
      totalPrice: 200,
      orderType: 'pickup',
      deliveryModelPreference: 'merchant'
    };
    
    // Simulate the commission calculation logic from functions/index.js
    const isDelivery = String(testOrder.orderType || '').toLowerCase() === 'delivery';
    const deliveryPref = String(testOrder.deliveryModelPreference || '').toLowerCase();
    const isPlatformDelivery = isDelivery && (deliveryPref === 'system');
    
    let pct = null;
    if (!isDelivery) {
      pct = Number(settings.pickupPct);
    } else if (isPlatformDelivery) {
      pct = Number(settings.platformDeliveryPct);
    } else {
      pct = Number(settings.merchantDeliveryPct);
    }
    
    if (isNaN(pct) || pct < 0 || pct > 50) {
      pct = Number(settings.platformFeePercentage) || 5.0;
      console.log(`⚠️  Using fallback rate: ${pct}%`);
    }
    
    const subtotal = Number(testOrder.totalPrice);
    let commission = subtotal * (pct / 100);
    
    // Apply min/caps
    const cmin = Number(settings.commissionMin);
    if (!isNaN(cmin) && cmin > 0) commission = Math.max(commission, cmin);
    
    let cap = null;
    if (!isDelivery) {
      cap = Number(settings.commissionCapPickup);
    } else if (isPlatformDelivery) {
      cap = Number(settings.commissionCapDeliveryPlatform);
    } else {
      cap = Number(settings.commissionCapDeliveryMerchant);
    }
    if (!isNaN(cap) && cap > 0) commission = Math.min(commission, cap);
    
    commission = Math.round(commission * 100) / 100;
    const net = Math.round((subtotal - commission) * 100) / 100;
    
    console.log(`Order: R${subtotal} (${testOrder.orderType})`);
    console.log(`Commission: R${commission} (${pct}%)`);
    console.log(`Seller receives: R${net}`);
    
    // 4. Test PayFast fee calculation
    console.log('\n💳 Testing PayFast Fee Calculation...');
    const payfastFeePercentage = Number(settings.payfastFeePercentage) || 3.5;
    const payfastFixedFee = Number(settings.payfastFixedFee) || 2.0;
    const payfastFee = (subtotal * (payfastFeePercentage / 100)) + payfastFixedFee;
    
    console.log(`PayFast Fee: R${payfastFee.toFixed(2)} (${payfastFeePercentage}% + R${payfastFixedFee})`);
    
    console.log('\n✅ Payment settings test completed successfully!');
    
    // 5. Check for missing critical settings
    console.log('\n🔍 Checking for Missing Settings...');
    const requiredSettings = [
      'platformFeePercentage',
      'payfastFeePercentage', 
      'payfastFixedFee',
      'pickupPct',
      'merchantDeliveryPct',
      'platformDeliveryPct'
    ];
    
    const missingSettings = requiredSettings.filter(key => 
      settings[key] === undefined || settings[key] === null
    );
    
    if (missingSettings.length > 0) {
      console.log('⚠️  Missing settings:');
      missingSettings.forEach(setting => console.log(`   - ${setting}`));
      console.log('\n💡 Recommendation: Set these values in your admin dashboard');
    } else {
      console.log('✅ All critical settings are configured');
    }
    
  } catch (error) {
    console.log('❌ Error testing payment settings:', error.message);
  }
}

// Run the test
testPaymentSettings().then(() => {
  console.log('\n🏁 Test completed. Exiting...');
  process.exit(0);
}).catch(error => {
  console.log('❌ Test failed:', error.message);
  process.exit(1);
});
