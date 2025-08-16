class ImageKitConfig {
  // TODO: Replace with your actual ImageKit credentials
  static const String privateKey = 'private_'; // Your private key from ImageKit dashboard
  static const String publicKey = 'public_tAO0SkfLl/37FQN+23c/bkAyfYg='; // Your public key
  static const String urlEndpoint = 'https://ik.imagekit.io/your_endpoint'; // Your URL endpoint
  
  // API endpoints
  static const String apiBaseUrl = 'https://api.imagekit.io/v1';
  
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
}
