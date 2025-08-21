# 🚚 PAXI Integration Implementation Guide

## 📋 Overview

This guide explains how to integrate PAXI pickup point services with your existing marketplace, using delivery speed-based pricing instead of bag size-based pricing.

## 🎯 What This Achieves

1. **Uses Your Store Database**: Shows stores from your `users` collection that offer PAXI
2. **Admin-Configurable Pricing**: Set PAXI prices through your admin dashboard
3. **Delivery Speed Selection**: Buyers can choose between Standard (7-9 days) and Express (3-5 days)
4. **PAXI Store Locator Integration**: Embeds PAXI's official store locator
5. **Balanced Service Mix**: Ensures both Pargo and PAXI options are available

## 🗄️ Database Structure

### Store Collection (`users` with `role: 'seller'`)

Add a new field to stores that offer PAXI:

```json
{
  "role": "seller",
  "storeName": "Example Store",
  "paxiEnabled": true,  // NEW: Indicates store offers PAXI
  "latitude": -26.2041,
  "longitude": 28.0473,
  "address": "123 Main St, Johannesburg",
  "operatingHours": "Mon-Sun 8AM-8PM"
}
```

### PAXI Pricing Collection (`admin_settings/paxi_pricing`)

```json
{
  "standard": 59.95,
  "express": 109.95,
  "standardDays": "7-9",
  "expressDays": "3-5",
  "updatedAt": "2024-01-15T10:30:00Z",
  "updatedBy": "admin"
}
```

## 🔧 Implementation Steps

### Step 1: Update Your Store Database

For each store that offers PAXI services, add:

```dart
// In your store creation/update logic
await FirebaseFirestore.instance
    .collection('users')
    .doc(storeId)
    .update({
  'paxiEnabled': true,
  'latitude': storeLatitude,
  'longitude': storeLongitude,
  'address': storeAddress,
  'operatingHours': 'Mon-Sun 8AM-8PM',
});
```

### Step 2: Add PAXI Pricing Management to Admin Dashboard

Import and add the `PaxiPricingManagement` widget to your admin dashboard:

```dart
// In your admin dashboard
import '../widgets/paxi_pricing_management.dart';

// Add to your dashboard layout
PaxiPricingManagement(),
```

### Step 3: Update Checkout Screen

The checkout screen now automatically:
- Finds stores from your database that offer PAXI
- Uses your admin-configured pricing
- Shows both Pargo and PAXI options
- Allows buyers to select delivery speed when PAXI is chosen

### Step 4: Add PAXI Store Locator Widget

Use the `PaxiStoreLocatorWidget` in your checkout or store selection screens:

```dart
// Navigate to PAXI store locator
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => PaxiStoreLocatorWidget(
      initialAddress: userAddress,
      onLocationSelected: (address, lat, lng) {
        // Handle location selection
        print('Selected PAXI location: $address at $lat, $lng');
      },
    ),
  ),
);
```

## 📱 User Experience Flow

### 1. Customer Selects PAXI at Checkout
- Taps PAXI button
- System shows stores from your database that offer PAXI
- **NEW**: Customer can choose delivery speed (Standard vs Express)
- Prices come from your admin configuration

### 2. Customer Chooses Delivery Speed
- **Standard Delivery**: R59.95 (7-9 business days)
- **Express Delivery**: R109.95 (3-5 business days)
- Same bag size (10kg) for both options
- Price difference reflects delivery time priority

### 3. Customer Uses PAXI Store Locator
- Taps "Find PAXI Stores" button
- Opens PAXI's official store locator in WebView
- Can search for specific locations
- Selects preferred pickup point

### 4. Store Selection
- Customer sees list of nearby PAXI-enabled stores
- Each store shows:
  - Store name and address
  - Distance from customer
  - PAXI service pricing (based on selected speed)
  - Operating hours

## 🛠️ Admin Configuration

### Setting PAXI Pricing

1. Go to Admin Dashboard → PAXI Service Pricing
2. Configure two delivery speeds:
   - **Standard**: R59.95 (7-9 business days)
   - **Express**: R109.95 (3-5 business days)

### Enabling PAXI for Stores

1. Go to Store Management
2. Select a store
3. Toggle "PAXI Enabled" to true
4. Ensure store has coordinates and address

## 🔍 Testing the Integration

### Test PAXI Button
1. Go to checkout screen
2. Tap PAXI button
3. Should show stores from your database with PAXI enabled

### Test Delivery Speed Selection
1. Select PAXI service
2. Choose between Standard and Express delivery
3. Verify pricing updates correctly

### Test Admin Pricing
1. Go to admin dashboard
2. Update PAXI pricing
3. Verify changes reflect in checkout

## 📊 Pricing Structure

| Delivery Speed | Price | Delivery Time | Bag Size |
|----------------|-------|---------------|----------|
| **Standard** | R59.95 | 7-9 business days | 10kg |
| **Express** | R109.95 | 3-5 business days | 10kg |

## 🎨 UI Components

### PaxiDeliverySpeedSelector
A widget that allows buyers to choose between delivery speeds:

```dart
PaxiDeliverySpeedSelector(
  selectedSpeed: 'standard',
  onSpeedSelected: (speed, price) {
    // Handle speed selection
    print('Selected $speed delivery for R$price');
  },
  customPricing: {
    'standard': 59.95,
    'express': 109.95,
  },
)
```

### PaxiPricingManagement
Admin widget for configuring PAXI pricing in the admin dashboard.

## 🔄 Integration Points

### Checkout Screen
- **File**: `lib/screens/CheckoutScreen.dart`
- **Integration**: Add PAXI delivery speed selector when PAXI is selected

### Admin Dashboard
- **File**: `admin_dashboard/lib/widgets/admin_dashboard_content.dart`
- **Integration**: Add PAXI pricing management section

### Services
- **File**: `lib/services/courier_quote_service.dart`
- **Integration**: Updated to use speed-based pricing structure

## 🚀 Benefits

### For Buyers
- **Choice**: Select delivery speed based on urgency and budget
- **Transparency**: Clear pricing for each delivery option
- **Flexibility**: Same bag size, different delivery times

### For Sellers
- **Revenue**: Additional service options increase order value
- **Customer Satisfaction**: More delivery choices for customers
- **Competitive Edge**: PAXI integration differentiates from competitors

### For Platform
- **Service Diversity**: More delivery options increase platform value
- **Revenue Growth**: Higher order values through premium services
- **Market Position**: Comprehensive delivery solution provider

## 🔧 Troubleshooting

### Common Issues
1. **PAXI points not showing**: Check if stores have `paxiEnabled: true`
2. **Pricing not updating**: Verify admin pricing configuration
3. **Speed selector not working**: Check widget integration in checkout

### Debug Steps
1. Check Firestore for PAXI-enabled stores
2. Verify admin pricing configuration
3. Test delivery speed selection flow
4. Check console for any error messages

---

This implementation provides a complete PAXI integration with delivery speed selection, giving buyers the choice between standard and express delivery while maintaining the same bag size for both options.
