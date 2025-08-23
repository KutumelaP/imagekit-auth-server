class HereConfig {
  // HERE API Configuration
  // Get your free API key at: https://developer.here.com/
  // Free tier: 250,000 requests per month
  
  static const String apiKey = 'F2ZQ7Djp9L9lUHpw4qvxlrgCePbtSgD7efexLP_kU_A';
  
  // API Endpoints
  static const String discoverUrl = 'https://discover.search.hereapi.com/v1/discover';
  static const String geocodeUrl = 'https://geocode.search.hereapi.com/v1/geocode';
  static const String autocompleteUrl = 'https://autocomplete.search.hereapi.com/v1/autocomplete';
  
  // Rate limiting
  static const int maxRequestsPerSecond = 10;
  static const int maxRequestsPerMinute = 600;
  
  // Search settings
  static const int defaultSearchLimit = 10;
  static const int maxSearchLimit = 100;
  static const int defaultRadius = 50000; // 50km in meters
  
  // Country focus
  static const String defaultCountry = 'ZA'; // South Africa
  static const String defaultLanguage = 'en';
  
  // Check if API key is configured
  static bool get isConfigured => apiKey != 'YOUR_HERE_API_KEY';
  
  // Get API key with validation
  static String get validatedApiKey {
    if (!isConfigured) {
      throw Exception('HERE API key not configured. Please set your API key in HereConfig.apiKey');
    }
    return apiKey;
  }
}
