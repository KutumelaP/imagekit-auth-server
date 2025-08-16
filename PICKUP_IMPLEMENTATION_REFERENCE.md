# 🚚 Pickup Points Implementation Reference

## 📋 **Overview**
This document describes the complete pickup points functionality implemented in `CheckoutScreen.dart` for the food marketplace app. The system allows users to select pickup instead of delivery and choose from nearby Pargo pickup points.

## 🏗️ **What Was Added**

### **1. New State Variables**
```dart
// Pickup points loading variables
bool _isLoadingPickupPoints = false;
List<Map<String, dynamic>> _pickupPoints = [];
Map<String, dynamic>? _selectedPickupPoint;
double _selectedLat = 0.0;
double _selectedLng = 0.0;
List<dynamic> _addressSuggestions = [];
bool _isSearchingAddress = false;
Timer? _addressSearchTimer;
```

### **2. Delivery Type Selection**
```dart
String _selectedDeliveryType = 'platform'; // 'platform', 'seller', 'pickup'
bool _isDelivery = true; // Keep for backward compatibility
bool _sellerDeliveryAvailable = false; // Track if seller offers delivery
```

## 🔧 **Core Methods Added**

### **1. Load Pickup Points for Current Location**
```dart
Future<void> _loadPickupPointsForCurrentLocation() async
```
- Gets user's GPS location using `Geolocator.getCurrentPosition()`
- Falls back to Pretoria coordinates if GPS fails
- Automatically loads pickup points for the location

### **2. Load Pickup Points for Coordinates**
```dart
Future<void> _loadPickupPointsForCoordinates(double lat, double lng) async
```
- Calls `CourierQuoteService.getPickupPoints()`
- Converts service response to local format
- Auto-selects first pickup point
- Updates UI state

### **3. Address Search for Pickup**
```dart
void _searchAddressesInline(String query)
```
- Debounced address search (500ms delay)
- Uses `locationFromAddress()` for geocoding
- Automatically loads pickup points for searched address
- Only works when pickup mode is selected

## 🎨 **UI Components Added**

### **1. Delivery Type Toggle**
- **Platform Delivery**: Uses platform drivers
- **Seller Delivery**: Uses seller's own delivery (if available)
- **Pickup**: Shows pickup points selection

### **2. Pickup Points Section**
- **Header**: "Pickup Points" with location icon
- **Info Box**: Instructions for finding nearest Pargo points
- **Loading State**: Spinner while fetching points
- **Success Message**: Shows count of found points
- **Points List**: Selectable pickup point cards
- **No Points Message**: Fallback when no points found

### **3. Pickup Point Cards**
Each card shows:
- Radio button selection
- Point name
- Address
- Operating hours
- Pickup fee (in Rands)

## 🔄 **User Flow**

### **1. Select Pickup**
1. User clicks "Pickup" button
2. `_selectedDeliveryType` set to 'pickup'
3. `_isDelivery` set to false
4. Delivery fee cleared to R0.00
5. `_loadPickupPointsForCurrentLocation()` called automatically

### **2. Load Pickup Points**
1. GPS location obtained (or fallback used)
2. `CourierQuoteService.getPickupPoints()` called
3. Points converted to local format
4. First point auto-selected
5. UI updated to show points

### **3. Address Search (Optional)**
1. User types in address field
2. 500ms debounce timer
3. Address geocoded to coordinates
4. Pickup points loaded for new location
5. UI updated with new points

### **4. Select Pickup Point**
1. User taps on pickup point card
2. `_selectedPickupPoint` updated
3. Visual selection indicator shown
4. Point details highlighted

## 🗂️ **Data Structure**

### **Pickup Point Format**
```dart
{
  'id': 'unique_id',
  'name': 'Pickup Point Name',
  'address': 'Full Address',
  'latitude': 123.456,
  'longitude': -12.345,
  'type': 'pargo',
  'distance': 2.5,
  'fee': 15.00,
  'operatingHours': 'Mon-Fri 8AM-6PM',
  'isPargoPoint': true,
}
```

### **Integration with CourierQuoteService**
- Uses existing `CourierQuoteService.getPickupPoints()`
- Handles API deprecation gracefully
- Falls back to dummy data when API fails
- Maintains consistent data structure

## 🎯 **Key Features**

### **1. Automatic Location Detection**
- GPS location on pickup selection
- Fallback to default location (Pretoria)
- No manual location input required

### **2. Real-time Address Search**
- Debounced input to avoid excessive API calls
- Automatic pickup point loading for searched addresses
- Seamless integration with existing address field

### **3. Smart State Management**
- Clears pickup data when switching to delivery
- Clears delivery data when switching to pickup
- Maintains selected pickup point across UI updates

### **4. Responsive Design**
- Mobile-optimized layout
- Responsive padding and sizing
- Consistent with app's design system

## 🚨 **Error Handling**

### **1. GPS Failures**
- 10-second timeout for location requests
- Automatic fallback to Pretoria coordinates
- User-friendly error messages

### **2. API Failures**
- Graceful degradation to fallback data
- Loading states for better UX
- Clear error messages when points unavailable

### **3. Network Issues**
- Debounced API calls to reduce load
- Timeout handling for slow connections
- Fallback data ensures functionality

## 🔧 **Technical Implementation**

### **1. State Management**
- Uses `setState()` for UI updates
- Maintains consistent state across delivery types
- Proper cleanup in `dispose()` method

### **2. Async Operations**
- Proper async/await pattern
- Error handling with try-catch blocks
- Loading states for better UX

### **3. Performance Optimizations**
- Debounced address search (500ms)
- Avoids unnecessary API calls
- Efficient state updates

## 📱 **Mobile Considerations**

### **1. GPS Permissions**
- Handles location permission gracefully
- Fallback coordinates ensure functionality
- User-friendly permission flow

### **2. Touch Interactions**
- Large touch targets for pickup point selection
- Visual feedback for selections
- Smooth scrolling for long point lists

### **3. Responsive Layout**
- Adapts to different screen sizes
- Mobile-first design approach
- Consistent spacing and sizing

## 🎨 **UI/UX Features**

### **1. Visual Hierarchy**
- Clear section headers with icons
- Consistent color scheme using AppTheme
- Proper spacing and typography

### **2. Interactive Elements**
- Hover effects on pickup point cards
- Selection indicators (radio buttons)
- Loading animations

### **3. Accessibility**
- Proper contrast ratios
- Clear text labels
- Screen reader friendly

## 🔮 **Future Enhancements**

### **1. Real-time Updates**
- Live pickup point availability
- Dynamic pricing updates
- Real-time operating hours

### **2. Advanced Filtering**
- Filter by distance
- Filter by operating hours
- Filter by pickup point type

### **3. Integration Features**
- Direct navigation to pickup points
- Contact information for points
- Operating hours validation

## 📚 **Related Files**

### **1. Main Implementation**
- `lib/screens/CheckoutScreen.dart` - Complete pickup functionality

### **2. Supporting Services**
- `lib/services/courier_quote_service.dart` - Pickup points API

### **3. Dependencies**
- `geolocator` - GPS location services
- `geocoding` - Address geocoding
- `flutter` - Core framework

## ✅ **Testing Checklist**

### **1. Basic Functionality**
- [ ] Pickup button selects pickup mode
- [ ] GPS location is obtained
- [ ] Pickup points are loaded
- [ ] Points are displayed in UI
- [ ] Point selection works

### **2. Address Search**
- [ ] Address input triggers search
- [ ] Debouncing works correctly
- [ ] New pickup points load for address
- [ ] UI updates appropriately

### **3. State Management**
- [ ] Switching between delivery types works
- [ ] Data is cleared appropriately
- [ ] State is maintained correctly

### **4. Error Handling**
- [ ] GPS failures are handled
- [ ] API failures show fallback data
- [ ] Loading states work correctly

## 🎉 **Summary**

The pickup points implementation provides a complete, user-friendly system for:
- **Automatic location detection** with GPS
- **Address-based search** for pickup points
- **Visual selection** of pickup locations
- **Seamless integration** with existing checkout flow
- **Robust error handling** and fallbacks
- **Responsive design** for all devices

This system transforms the checkout experience by offering users a convenient pickup alternative to delivery, complete with location-based pickup point discovery and selection.
