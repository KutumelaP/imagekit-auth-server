# 🏪 Marketplace Payment System Documentation (Updated 2024)

## **Overview**

This document outlines the **current marketplace payment system** for the South African marketplace, including **ledger-based payouts**, **platform fees**, **returns handling**, and **seller payment management**. The old escrow/holdback system has been completely replaced with a more transparent approach.

## **💰 Current Payment Flow (2024)**

### **1. Customer Payment Process**
```
Customer → Pays via PayFast → Platform Processes → Order Completed → 
Money Available for Payout → Seller Requests Payout → Admin Approves → 
Money Sent to Seller's Bank
```

### **2. Fee Structure**
- **Platform Fee**: Handled separately by admin (not deducted from seller earnings)
- **PayFast Fee**: 3.5% + R2.00 per transaction (handled by admin)
- **Delivery Fee**: Variable based on distance/zone (goes to delivery service)
- **Seller Earnings**: 100% of order total (minus any returns)

### **3. Payment Breakdown Example**
```
Order Total: R150.00
Delivery Fee: R25.00 (goes to delivery service)
Platform Fee: Handled separately by admin
PayFast Fee: Handled separately by admin

Customer Pays: R175.00 (R150 + R25 delivery)
Seller Receives: R150.00 (full order amount)
Available for Payout: R150.00 (immediately after order completion)
```

## **💳 Current Payout System**

### **Payout Collections in Firestore**

#### **1. platform_receivables**
```javascript
{
  sellerId: "seller_456",
  entries: [
    {
      orderId: "order_123",
      amount: 150.00,
      status: "available", // available, locked, settled
      createdAt: Timestamp,
      availableAt: Timestamp,
      orderCompletedAt: Timestamp
    }
  ],
  settlements: [
    {
      payoutId: "payout_789",
      amount: 150.00,
      status: "paid",
      createdAt: Timestamp,
      paidAt: Timestamp
    }
  ],
  balances: {
    totalEarnings: 1500.00,
    availableBalance: 300.00,
    totalPaidOut: 1200.00
  }
}
```

#### **2. payouts**
```javascript
{
  payoutId: "payout_789",
  sellerId: "seller_456",
  amount: 300.00,
  status: "requested", // requested, processing, paid, failed, cancelled
  createdAt: Timestamp,
  approvedAt: Timestamp,
  paidAt: Timestamp,
  bankDetails: {
    accountNumber: "1234567890",
    bankName: "Standard Bank",
    accountType: "savings"
  }
}
```

#### **3. payout_locks**
```javascript
{
  sellerId: "seller_456",
  lockedAmount: 300.00,
  lockedBy: "payout_789",
  lockedAt: Timestamp,
  expiresAt: Timestamp
}
```

## **🔄 Returns Management (Current)**

### **Return Process Flow**
```
Customer Requests Return → Admin Reviews → If Valid: Return Approved → 
Customer Gets Refund → Seller's Available Balance Reduced → 
Product Returned
```

### **Return Collections**

#### **1. returns**
```javascript
{
  returnId: "return_123",
  orderId: "order_123",
  customerId: "customer_789",
  sellerId: "seller_456",
  refundAmount: 150.00,
  reason: "defective_product",
  returnNotes: "Product arrived damaged",
  status: "approved", // requested, pending, approved, rejected, completed
  createdAt: Timestamp,
  approvedAt: Timestamp,
  completedAt: Timestamp
}
```

#### **2. Return Impact on Payouts**
- **Valid Returns**: Reduce seller's available balance
- **Invalid Returns**: No impact on seller earnings
- **Admin Review**: All returns reviewed for fairness
- **Balance Adjustment**: Automatic balance updates

## **📊 Seller Financial Dashboard**

### **What Sellers See**
- **Available Balance**: Money ready for payout
- **Total Earnings**: All-time earnings from completed orders
- **Pending Payouts**: Payouts waiting for admin approval
- **Payout History**: All payout requests and their status

### **Balance Calculation**
```
Available Balance = Sum of all completed orders - Sum of all paid out amounts - Sum of all returns
```

### **When Money Becomes Available**
- **Immediately**: After order status becomes 'delivered', 'completed', or 'confirmed'
- **No Waiting**: No holdback period
- **Full Amount**: 100% of order total (minus any returns)

## **🎯 Payout Process**

### **1. Payout Request**
1. Seller checks available balance
2. Seller requests payout (minimum R100)
3. System locks available amount
4. Payout status becomes 'requested'

### **2. Admin Review**
1. Admin sees payout request in dashboard
2. Admin reviews seller details and amount
3. Admin approves or rejects payout
4. If approved: status becomes 'processing'
5. If rejected: amount unlocked, status becomes 'cancelled'

### **3. Payment Processing**
1. Approved payouts processed by admin
2. Money sent to seller's bank account
3. Payout status becomes 'paid'
4. Locked amount becomes 'settled'

## **🔐 Security Features**

### **Admin Controls**
- **Payout Approval**: Only admins can approve payouts
- **Return Review**: All returns reviewed by admin
- **User Management**: Admin control over seller accounts
- **Audit Trail**: All actions logged and tracked

### **Data Protection**
- **Bank Details**: Encrypted and secure storage
- **Access Control**: Role-based permissions
- **Validation**: Input sanitization and verification
- **Secure Deletion**: Proper data cleanup procedures

## **📱 User Experience**

### **For Sellers**
- **Transparent**: See exactly where money is
- **Control**: Request payouts when you want
- **No Surprises**: Clear balance and payout status
- **Support**: 24/7 platform assistance

### **For Admins**
- **Full Control**: Manage all payouts and returns
- **Efficiency**: Batch processing capabilities
- **Monitoring**: Real-time financial oversight
- **Automation**: Scheduled payout processing

## **🚀 Benefits of New System**

### **Transparency**
- **Clear Balances**: Sellers see exact available amounts
- **No Hidden Fees**: Platform fees handled separately
- **Real-time Updates**: Instant balance adjustments
- **Full Control**: Sellers decide when to get paid

### **Efficiency**
- **No Holdbacks**: Money available immediately
- **Simplified Process**: Direct payout requests
- **Admin Oversight**: Centralized financial management
- **Automated Processing**: Scheduled batch payouts

### **Security**
- **Admin Approval**: All payouts reviewed
- **Return Protection**: Fair return handling
- **Audit Trail**: Complete transaction history
- **Secure Banking**: Encrypted financial data

## **📋 Implementation Status**

| Component | Status | Details |
|-----------|--------|---------|
| **Payout System** | ✅ Complete | Ledger-based with admin approval |
| **Return System** | ✅ Complete | Admin-reviewed returns |
| **Financial Dashboard** | ✅ Complete | Real-time balance tracking |
| **Admin Interface** | ✅ Complete | Comprehensive payout management |
| **Cloud Functions** | ✅ Complete | Automated processing |
| **Security Rules** | ✅ Complete | Role-based access control |

## **🔄 Migration from Old System**

### **What Changed**
- **Old**: 90% immediate + 10% holdback for 30 days
- **New**: 100% available after order completion

- **Old**: Complex escrow calculations
- **New**: Simple ledger system

- **Old**: Automatic payments
- **New**: Manual payout requests

- **Old**: Returns affect holdback
- **New**: Returns affect available balance

### **Benefits of Migration**
- **Simpler**: Easier to understand and manage
- **Transparent**: Clear financial visibility
- **Flexible**: Sellers control payout timing
- **Secure**: Admin oversight and approval

## **📞 Support & Documentation**

### **For Sellers**
- **SELLER_RETURN_GUIDE.md**: Complete payout and return guide
- **Onboarding**: Step-by-step platform introduction
- **Dashboard**: Real-time financial information
- **Support**: 24/7 platform assistance

### **For Admins**
- **Admin Dashboard**: Comprehensive management interface
- **Cloud Functions**: Backend automation tools
- **Security Rules**: Firestore access control
- **Monitoring**: Performance and error tracking

---

**This document reflects the current marketplace payment system as of 2024. The old escrow/holdback system has been completely replaced with a more transparent, efficient, and user-friendly ledger-based approach.**

*For technical implementation details, see the Cloud Functions and Firestore security rules documentation.* 