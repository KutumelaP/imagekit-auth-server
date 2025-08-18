class ImageKitConfig {
  // ImageKit credentials - Update these with your actual values
  static const String privateKey = 'your_private_key_here'; // Get from ImageKit dashboard
  static const String publicKey = 'public_tAO0SkfLl/37FQN+23c/bkAyfYg='; // Already configured
  static const String urlEndpoint = 'https://ik.imagekit.io/tkhb6zllk'; // Already configured
  
  // Authentication server URL
  static const String authServerUrl = 'https://imagekit-auth-server-f4te.onrender.com/auth';
  
  // API endpoints
  static const String apiBaseUrl = 'https://api.imagekit.io/v1';
  static const String uploadUrl = 'https://upload.imagekit.io/api/v1/files/upload';
  
  // File paths for organization
  static const String productsPath = 'products/';
  static const String profileImagesPath = 'profile_images/';
  static const String storeImagesPath = 'store_images/';
  static const String chatImagesPath = 'chat_images/';
  
  // Rate limiting
  static const int maxRequestsPerSecond = 10;
  static const int requestDelayMs = 100;
  
  // Cleanup settings
  static const int maxImagesPerPage = 1000;
  static const bool enableAutomaticCleanup = false; // Set to true for automatic cleanup
  static const Duration cleanupInterval = Duration(hours: 24); // How often to run cleanup
  
  // Authentication timeout settings
  static const int authTimeoutSeconds = 30;
  static const int uploadTimeoutSeconds = 60;
  
  // Retry configuration
  static const int maxRetries = 3;
  static const int retryDelaySeconds = 2;
}
