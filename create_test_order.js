const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://marketplace-8d6bd.firebaseio.com'
  });
}

const db = admin.firestore();

async function createTestOrder() {
  console.log('🧪 Creating test order for PayFast navigation testing...');

  try {
    // Create a test order
    const testOrderId = 'TEST_' + Date.now();
    const testOrder = {
      orderId: testOrderId,
      buyerId: 'test_buyer_123',
      sellerId: 'test_seller_456',
      status: 'paid',
      paymentStatus: 'paid',
      payment: {
        method: 'payfast',
        status: 'paid',
        currency: 'ZAR',
        gateway: 'payfast',
      },
      totalPrice: 25.50,
      totalAmount: 25.50,
      subtotal: 20.00,
      deliveryFee: 5.50,
      items: [
        {
          productId: 'test_product_1',
          name: 'Test Product',
          price: 20.00,
          quantity: 1,
        }
      ],
      customerInfo: {
        firstName: 'Test',
        lastName: 'User',
        email: 'test@example.com',
        phone: '+27123456789',
      },
      deliveryAddress: '123 Test Street, Test City, 1234',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('orders').doc(testOrderId).set(testOrder);
    
    console.log('✅ Test order created successfully!');
    console.log('📋 Order ID:', testOrderId);
    console.log('🔗 Test URL: https://www.omniasa.co.za/#/payment-success?order_id=' + testOrderId + '&status=paid');
    console.log('💰 Order Total: R' + testOrder.totalPrice);
    console.log('');
    console.log('🧪 You can now test:');
    console.log('1. Navigate to the test URL above');
    console.log('2. Check if the payment success page loads correctly');
    console.log('3. Verify WhatsApp notification button works');
    console.log('4. Check if order details are displayed properly');

  } catch (error) {
    console.error('❌ Error creating test order:', error);
  }
}

createTestOrder();

