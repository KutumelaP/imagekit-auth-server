class PargoConfig {
  // Pargo Simba API Configuration
  static const String businessEmail = 'pietbruce48@gmail.com';
  static const String businessPassword = 'Piet@1993'; // Set this to your actual password
  
  // API URLs - Updated for 2024
  static const String productionBaseUrl = 'https://api.pargo.co.za'; // Main production API
  static const String stagingBaseUrl = 'https://api.staging.pargo.co.za'; // For testing only
  static const String simbaApiUrl = 'https://simba.pargo.co.za/api'; // New Simba API
  static const String publicPickupUrl = 'https://www.pargo.co.za/pickup-points'; // Public pickup points
  
  // Use public pickup points by default (no authentication needed)
  static const bool useStaging = false;
  static const bool useSimbaApi = false; // Disable until you get real credentials
  static const bool usePublicPickup = true; // Use public pickup points
  
  // Rate limiting
  static const int maxRequestsPerMinute = 60;
  
  // Token refresh settings
  static const int tokenRefreshThresholdMinutes = 5;
  
  // Get the appropriate API URL
  static String get apiUrl {
    if (useSimbaApi) return simbaApiUrl;
    if (useStaging) return stagingBaseUrl;
    return productionBaseUrl;
  }
  
  // Check if authentication is required
  static bool get requiresAuth => !usePublicPickup;
}
