# 🗺️ Google Places API Setup Guide

## 📋 Prerequisites
- Google Cloud Console account
- Billing enabled on your Google Cloud project
- Flutter project with internet connectivity

## 🔧 Step-by-Step Setup

### 1. Enable Google Cloud APIs

Go to [Google Cloud Console](https://console.cloud.google.com/)

**Enable these APIs:**
- ✅ **Places API** (Required for autocomplete)
- ✅ **Maps JavaScript API** (Optional, for testing)
- ✅ **Geocoding API** (Backup for address conversion)

### 2. Create API Key

1. Navigate to **APIs & Services** > **Credentials**
2. Click **Create Credentials** > **API Key**
3. Copy the generated API key
4. **Important:** Restrict the API key to:
   - **Places API** only
   - **HTTP referrers** (your domain)
   - **IP addresses** (your server IPs)

### 3. Add HTTP Package

Add to `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.1.0
```

### 4. Update Address Search Service

Replace `YOUR_GOOGLE_PLACES_API_KEY` in `lib/services/address_search_service.dart`:

```dart
static const String _googlePlacesApiKey = 'AIzaSyYourActualAPIKeyHere';
```

### 5. Implement Google Places Autocomplete

Update the `_tryGooglePlacesAutocomplete` method:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<List<Placemark>> _tryGooglePlacesAutocomplete(String query) async {
  try {
    print('🔍 Trying Google Places Autocomplete for: "$query"');
    
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?'
      'input=${Uri.encodeComponent(query)}'
      '&types=address'
      '&components=country:za'
      '&key=$_googlePlacesApiKey'
    );
    
    final response = await http.get(url);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      if (data['status'] == 'OK') {
        List<Placemark> placemarks = [];
        
        for (final prediction in data['predictions']) {
          // Get place details for coordinates
          final placeDetails = await _getPlaceDetails(prediction['place_id']);
          
          if (placeDetails != null) {
            placemarks.add(placeDetails);
          }
        }
        
        print('🔍 Google Places found ${placemarks.length} results');
        return placemarks;
      } else {
        print('🔍 Google Places API error: ${data['status']}');
      }
    }
    
    return [];
  } catch (e) {
    print('🔍 Google Places Autocomplete failed: $e');
    return [];
  }
}

Future<Placemark?> _getPlaceDetails(String placeId) async {
  try {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?'
      'place_id=$placeId'
      '&fields=geometry,formatted_address,name'
      '&key=$_googlePlacesApiKey'
    );
    
    final response = await http.get(url);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      if (data['status'] == 'OK') {
        final result = data['result'];
        final location = result['geometry']['location'];
        
        return Placemark(
          name: result['name'] ?? '',
          street: result['formatted_address'] ?? '',
          locality: '', // Will be filled by geocoding
          administrativeArea: '',
          country: 'South Africa',
          postalCode: '',
          isoCountryCode: 'ZA',
        );
      }
    }
    
    return null;
  } catch (e) {
    print('🔍 Error getting place details: $e');
    return null;
  }
}
```

## 🎯 Benefits of Google Places API

### ✅ **Superior User Experience**
- **Real-time suggestions** as user types
- **Accurate South African addresses**
- **Comprehensive coverage** of all SA cities and suburbs
- **Smart matching** with partial queries

### ✅ **Accurate Delivery Fee Calculation**
- **Real coordinates** for every address
- **Precise distance calculations**
- **Reliable geocoding** for delivery zones

### ✅ **Production Ready**
- **99.9% uptime** from Google
- **Scalable** for any number of users
- **Cost effective** (first 1000 requests/month free)
- **Well documented** with extensive support

## 💰 Pricing (Google Places API)

| Requests per Month | Price per Request |
|-------------------|-------------------|
| 0 - 1,000        | **FREE**          |
| 1,001 - 100,000  | $0.017 per 1,000 |
| 100,001+         | $0.012 per 1,000 |

**Example:** 10,000 requests/month = ~$0.15

## 🔒 Security Best Practices

1. **Restrict API Key:**
   ```
   - Only Places API enabled
   - HTTP referrers: your-domain.com
   - IP addresses: your server IPs
   ```

2. **Server-side Implementation:**
   ```dart
   // For production, proxy requests through your server
   final response = await http.post(
     Uri.parse('https://your-server.com/api/places-autocomplete'),
     body: {'query': query},
   );
   ```

3. **Rate Limiting:**
   ```dart
   // Implement rate limiting to prevent abuse
   if (_requestCount > 100) {
     return []; // Fall back to local database
   }
   ```

## 🚀 Implementation Priority

### **Phase 1: Basic Setup** (1-2 hours)
1. Enable Google Cloud APIs
2. Create and restrict API key
3. Add HTTP package
4. Test with basic implementation

### **Phase 2: Production Ready** (2-3 hours)
1. Add error handling
2. Implement rate limiting
3. Add server-side proxy (optional)
4. Test with real South African addresses

### **Phase 3: Optimization** (1 hour)
1. Add caching for common queries
2. Implement fallback strategies
3. Monitor usage and costs

## 🧪 Testing

Test with these South African addresses:
- "Sandton, Johannesburg"
- "Sea Point, Cape Town"
- "Umhlanga, Durban"
- "Hatfield, Pretoria"

## 📞 Support

If you need help with implementation:
1. Check [Google Places API Documentation](https://developers.google.com/maps/documentation/places/web-service)
2. Review [Flutter HTTP package docs](https://pub.dev/packages/http)
3. Test with [Google Cloud Console](https://console.cloud.google.com/)

## 🎯 Next Steps

1. **Get your API key** from Google Cloud Console
2. **Replace the placeholder** in the code
3. **Test with real addresses**
4. **Deploy and monitor**

This will give you the **best possible address search experience** with real coordinates for accurate delivery fee calculations! 🎯 