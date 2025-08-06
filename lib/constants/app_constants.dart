class AppConstants {
  // App Information
  static const String appName = 'Mzansi Marketplace';
  static const String appVersion = '1.0.0';
  
  // Image Configuration
  static const String defaultImageUrl = 'assets/images/placeholder.png';
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const List<String> supportedImageFormats = ['jpg', 'jpeg', 'png', 'webp'];
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1080;
  
  // API Configuration
  static const String backendUrl = 'https://imagekit-auth-server-f4te.onrender.com/auth';
  static const String imageKitUploadUrl = 'https://upload.imagekit.io/api/v1/files/upload';
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String productsCollection = 'products';
  static const String categoriesCollection = 'categories';
  static const String reviewsCollection = 'reviews';
  static const String ordersCollection = 'orders';
  static const String chatsCollection = 'chats';
  
  // User Roles
  static const String roleUser = 'user';
  static const String roleSeller = 'seller';
  static const String roleAdmin = 'admin';
  
  // Product Categories
  static const Map<String, List<String>> categoryMap = {
    'Food': ['Fruits', 'Vegetables', 'Snacks', 'Drinks', 'Baked Goods'],
    'Drinks': ['Beverages', 'Juices', 'Smoothies', 'Coffee', 'Tea'],
    'Bakery': ['Bread', 'Cakes', 'Pastries', 'Cookies', 'Pies'],
    'Fruits': ['Fresh Fruits', 'Dried Fruits', 'Organic Fruits'],
    'Vegetables': ['Fresh Vegetables', 'Organic Vegetables', 'Root Vegetables'],
    'Snacks': ['Chips', 'Nuts', 'Crackers', 'Popcorn', 'Candy'],
    'Electronics': ['Phones', 'Laptops', 'Tablets', 'Accessories'],
    'Clothes': ['T-Shirts', 'Jeans', 'Jackets', 'Dresses', 'Shoes'],
    'Other': ['Misc', 'Handmade', 'Vintage'],
  };
  
  // Categories list for dropdowns
  static const List<String> categories = [
    'Food',
    'Drinks', 
    'Bakery',
    'Fruits',
    'Vegetables',
    'Snacks',
    'Electronics',
    'Clothes',
    'Other',
  ];
  
  // Quantity Management
  static const int minProductQuantity = 1;
  static const int maxProductQuantity = 9999;
  static const int defaultProductQuantity = 1;
  
  // Validation Rules
  static const int minPasswordLength = 6;
  static const int maxProductNameLength = 100;
  static const int maxProductDescriptionLength = 500;
  static const double minProductPrice = 0.01;
  static const double maxProductPrice = 999999.99;
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 12.0;
  static const double defaultElevation = 3.0;
  static const int defaultAnimationDuration = 300;
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;
  
  // Error Messages
  static const String networkErrorMessage = 'Network error. Please check your connection.';
  static const String authenticationErrorMessage = 'Authentication failed. Please try again.';
  static const String uploadErrorMessage = 'Upload failed. Please try again.';
  static const String generalErrorMessage = 'Something went wrong. Please try again.';
  
  // Success Messages
  static const String uploadSuccessMessage = 'Product uploaded successfully!';
  static const String profileUpdateSuccessMessage = 'Profile updated successfully!';
  static const String orderPlacedSuccessMessage = 'Order placed successfully!';
  
  // Loading Messages
  static const String uploadingMessage = 'Uploading...';
  static const String loadingMessage = 'Loading...';
  static const String processingMessage = 'Processing...';

  // Baker Profile Enhancement Fields
  static const List<String> bakerExperienceLevels = [
    'Hobbyist (1-2 years)',
    'Experienced (3-5 years)', 
    'Professional (5-10 years)',
    'Master Baker (10+ years)',
  ];
  
  static const List<String> bakingCertifications = [
    'Food Safety Certified',
    'Culinary Arts Degree',
    'Pastry Chef Certification',
    'Artisan Bread Certification',
    'Cake Decorating Specialist',
    'Organic Baking Certified',
  ];
  
  static const Map<String, List<String>> bakerPersonalityTraits = {
    'Creative': ['🎨', 'Innovative designs', 'Unique flavor combinations'],
    'Traditional': ['👴', 'Classic recipes', 'Time-honored techniques'],
    'Health-Conscious': ['🥗', 'Organic ingredients', 'Dietary accommodations'],
    'Experimental': ['🧪', 'New techniques', 'Fusion flavors'],
    'Family-Oriented': ['👨‍👩‍👧‍👦', 'Family recipes', 'Community focused'],
  };
  
  static const Map<String, String> bakerQuickFacts = {
    'yearsOfExperience': 'Years of Experience',
    'favoriteIngredient': 'Favorite Ingredient',
    'signatureDish': 'Signature Creation',
    'bakingPhilosophy': 'Baking Philosophy',
    'funFact': 'Fun Fact',
    'favoriteTime': 'Favorite Baking Time',
  };
} 