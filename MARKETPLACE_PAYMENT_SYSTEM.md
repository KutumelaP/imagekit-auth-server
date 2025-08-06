# 🏪 Marketplace Payment System Documentation

## **Overview**

This document outlines the enhanced PayFast integration for the South African marketplace, including **escrow management**, **platform fees**, **returns handling**, and **seller payment protection**.

## **💰 Payment Flow**

### **1. Customer Payment Process**
```
Customer → Pays via PayFast → Platform Escrow → Seller Gets Paid → Platform Takes Cut
```

### **2. Fee Structure**
- **Platform Fee**: Configurable via admin dashboard (default: 5% of order total)
- **PayFast Fee**: Configurable via admin dashboard (default: 3.5% + R2.00 per transaction)
- **Delivery Fee**: Variable based on distance/zone
- **Holdback**: Configurable via admin dashboard (default: 10% of seller payment for 30 days)

### **3. Payment Breakdown Example**
```
Order Total: R150.00
Delivery Fee: R25.00
Platform Fee (5%): R7.50
PayFast Fee (3.5% + R2): R7.25
Total Fees: R14.75

Customer Pays: R175.00 (R150 + R25 delivery)
Seller Receives: R135.25 (R150 - R14.75)
Immediate Payment: R121.73 (90% of seller payment)
Holdback: R13.52 (10% for 30 days)
```

## **🏦 Escrow System**

### **Escrow Collections in Firestore**

#### **1. escrow_payments**
```javascript
{
  orderId: "order_123",
  sellerId: "seller_456",
  customerId: "customer_789",
  orderTotal: 150.00,
  deliveryFee: 25.00,
  platformFee: 7.50,
  payfastFee: 7.25,
  sellerPayment: 135.25,
  holdbackAmount: 13.52,
  immediatePayment: 121.73,
  paymentStatus: "pending", // pending, completed, failed
  escrowStatus: "created", // created, funds_received, return_processed
  createdAt: Timestamp,
  paidAt: Timestamp,
  returnWindow: 7, // days
  holdbackReleaseDate: Timestamp,
  paymentData: {...} // PayFast payment data
}
```

#### **2. seller_payments**
```javascript
{
  sellerId: "seller_456",
  orderId: "order_123",
  amount: 121.73,
  paymentType: "immediate", // immediate, holdback
  status: "pending", // pending, completed, failed
  createdAt: Timestamp,
  scheduledFor: Timestamp,
  completedAt: Timestamp
}
```

#### **3. holdback_schedules**
```javascript
{
  orderId: "order_123",
  sellerId: "seller_456",
  holdbackAmount: 13.52,
  releaseDate: Timestamp,
  status: "scheduled", // scheduled, released, cancelled
  createdAt: Timestamp,
  releasedAt: Timestamp
}
```

## **🔄 Returns Management**

### **Return Process Flow**
```
Customer Requests Return → Platform Approves → Seller Accepts → 
Platform Refunds Customer → Platform Deducts from Seller → 
Seller Arranges Pickup → Product Returned
```

### **Return Collections**

#### **1. returns**
```javascript
{
  orderId: "order_123",
  customerId: "customer_789",
  sellerId: "seller_456",
  refundAmount: 150.00,
  platformFeeRefund: 7.50,
  sellerRefund: 142.50,
  reason: "defective_product",
  returnNotes: "Product arrived damaged",
  status: "pending", // pending, approved, rejected, completed
  createdAt: Timestamp,
  approvedAt: Timestamp,
  completedAt: Timestamp
}
```

#### **2. customer_refunds**
```javascript
{
  customerId: "customer_789",
  orderId: "order_123",
  refundAmount: 150.00,
  status: "pending", // pending, processed, completed
  createdAt: Timestamp,
  processedAt: Timestamp
}
```

#### **3. holdback_deductions**
```javascript
{
  sellerId: "seller_456",
  orderId: "order_123",
  amount: 142.50,
  reason: "return_refund",
  createdAt: Timestamp
}
```

## **📊 Seller Payment Management**

### **Seller Financial Dashboard**

#### **Seller Document Structure**
```javascript
{
  sellerId: "seller_456",
  totalEarnings: 5000.00,
  pendingPayments: 250.00,
  holdbackAmount: 500.00,
  totalRefunds: 150.00,
  lastPaymentDate: Timestamp,
  paymentSchedule: "weekly", // weekly, bi-weekly, monthly
  bankDetails: {
    accountNumber: "1234567890",
    accountHolder: "John Doe",
    bankName: "Standard Bank",
    branchCode: "051001"
  }
}
```

### **Payment Schedule Options**
- **Weekly**: Every Monday
- **Bi-weekly**: Every other Monday
- **Monthly**: First Monday of each month

## **🛡️ Risk Management**

### **1. Holdback System**
- **10% holdback** on all seller payments
- **30-day hold** period for returns/disputes
- **Automatic release** after hold period
- **Manual release** for trusted sellers

### **2. Seller Vetting**
- **Business verification** required
- **Bank account** verification
- **Performance monitoring**
- **Credit checks** for large sellers

### **3. Dispute Resolution**
- **Platform mediation** for disputes
- **Photo documentation** required
- **Seller response** within 24 hours
- **Automatic refund** for valid claims

## **💻 API Methods**

### **PayFastService Class Methods**

#### **1. calculateMarketplaceFees()**
```dart
Map<String, dynamic> fees = await PayFastService.calculateMarketplaceFees(
  orderTotal: 150.00,
  deliveryFee: 25.00,
  sellerId: "seller_456",
  orderId: "order_123",
  customerId: "customer_789",
);
```

#### **2. createMarketplacePayment()**
```dart
Map<String, dynamic> payment = await PayFastService.createMarketplacePayment(
  orderId: "order_123",
  sellerId: "seller_456",
  customerId: "customer_789",
  orderTotal: 150.00,
  deliveryFee: 25.00,
  customerEmail: "customer@email.com",
  customerName: "John Doe",
  customerPhone: "+27123456789",
  deliveryAddress: "123 Main St, Johannesburg",
);
```

#### **3. processSuccessfulPayment()**
```dart
Map<String, dynamic> result = await PayFastService.processSuccessfulPayment(
  orderId: "order_123",
  paymentId: "pay_789",
  paymentStatus: "COMPLETE",
);
```

#### **4. processReturn()**
```dart
Map<String, dynamic> returnResult = await PayFastService.processReturn(
  orderId: "order_123",
  customerId: "customer_789",
  reason: "defective_product",
  refundAmount: 150.00,
  returnNotes: "Product arrived damaged",
);
```

#### **5. getSellerPaymentSummary()**
```dart
Map<String, dynamic> summary = await PayFastService.getSellerPaymentSummary("seller_456");
```

## **📱 Integration with CheckoutScreen**

### **Enhanced Checkout Process**
```dart
// In CheckoutScreen.dart
Future<void> _processMarketplacePayment() async {
  // Calculate marketplace fees
  Map<String, dynamic> feeCalculation = await PayFastService.calculateMarketplaceFees(
    orderTotal: _orderTotal,
    deliveryFee: _deliveryFee,
    sellerId: sellerId,
    orderId: orderId,
    customerId: customerId,
  );

  // Create marketplace payment
  Map<String, dynamic> paymentResult = await PayFastService.createMarketplacePayment(
    orderId: orderId,
    sellerId: sellerId,
    customerId: customerId,
    orderTotal: _orderTotal,
    deliveryFee: _deliveryFee,
    customerEmail: customerEmail,
    customerName: customerName,
    customerPhone: customerPhone,
    deliveryAddress: deliveryAddress,
  );

  if (paymentResult['success']) {
    // Launch PayFast payment
    await _launchPayFastPayment(paymentResult['paymentUrl'], orderId);
  }
}
```

## **🔧 Admin Dashboard Integration**

### **Payment Management Sections**

#### **1. Escrow Management**
- View all escrow payments
- Monitor holdback schedules
- Process manual releases
- Handle disputes

#### **2. Seller Payments**
- View seller payment summaries
- Process manual payments
- Monitor payment schedules
- Handle payment disputes

#### **3. Returns Management**
- View all return requests
- Approve/reject returns
- Process refunds
- Monitor return trends

## **📈 Business Benefits**

### **For Platform Owner (You)**
- ✅ **Guaranteed platform fees** (5% on all orders)
- ✅ **Full payment control** (escrow system)
- ✅ **Risk protection** (holdback system)
- ✅ **Dispute resolution** capability
- ✅ **Transparent fee structure**

### **For Sellers**
- ✅ **Reliable payments** (platform managed)
- ✅ **No payment processing** headaches
- ✅ **Clear payment schedules**
- ✅ **Financial dashboard**
- ✅ **Support for disputes**

### **For Customers**
- ✅ **Secure payments** (PayFast trusted)
- ✅ **Easy returns** process
- ✅ **Multiple payment** methods
- ✅ **Dispute protection**
- ✅ **Transparent pricing**

## **🚀 Implementation Timeline**

### **Phase 1 (Week 1-2): Basic Escrow**
- [x] Enhanced PayFast service
- [x] Escrow collections setup
- [x] Basic payment processing
- [x] Fee calculations

### **Phase 2 (Week 3-4): Returns System**
- [ ] Returns management UI
- [ ] Refund processing
- [ ] Holdback deductions
- [ ] Dispute resolution

### **Phase 3 (Week 5-6): Seller Dashboard**
- [ ] Seller payment dashboard
- [ ] Payment schedules
- [ ] Financial reporting
- [ ] Bank integration

### **Phase 4 (Week 7-8): Admin Tools**
- [ ] Admin payment management
- [ ] Escrow monitoring
- [ ] Dispute resolution tools
- [ ] Financial analytics

## **🔐 Security Considerations**

### **1. Data Protection**
- All payment data encrypted
- PCI DSS compliance
- Secure API communications
- Regular security audits

### **2. Access Control**
- Role-based permissions
- Audit logging
- Two-factor authentication
- Secure admin access

### **3. Compliance**
- POPIA compliance (South Africa)
- Financial services regulations
- Tax reporting requirements
- Business verification

## **📞 Support & Maintenance**

### **1. Customer Support**
- Payment dispute resolution
- Return processing assistance
- Technical payment support
- Seller onboarding help

### **2. System Monitoring**
- Payment success rates
- Escrow balance monitoring
- Holdback release scheduling
- Dispute resolution times

### **3. Regular Maintenance**
- Fee structure reviews
- Payment method updates
- Security updates
- Performance optimization

---

**This enhanced PayFast integration provides a complete marketplace payment solution with escrow protection, automated fee management, and comprehensive returns handling for your South African marketplace!** 🇿🇦 