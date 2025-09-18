import 'package:flutter/material.dart';
import 'voice_assistant_service.dart';

/// Onboarding Voice Guide for new users
/// Explains the app's purpose and how to use it
class OnboardingVoiceGuide {
  static final VoiceAssistantService _voiceAssistant = VoiceAssistantService();
  
  /// Start comprehensive onboarding for new users
  static Future<void> startOnboarding({
    required String userName,
    required BuildContext context,
  }) async {
    await _voiceAssistant.initialize(
      userName: userName,
      isNewUser: true,
    );
    
    // Set context to home for onboarding
    _voiceAssistant.setContext('home');
    
    // Start the onboarding sequence
    await _runOnboardingSequence(context);
  }
  
  /// Run the complete onboarding sequence
  static Future<void> _runOnboardingSequence(BuildContext context) async {
    // Wait a moment for the UI to settle
    await Future.delayed(const Duration(seconds: 2));
    
    // Step 1: Welcome and app purpose
    await _voiceAssistant.speak(
      "Welcome to OmniaSA! I'm Nathan, your little shopping buddy! "
      "I'm so excited to show you around our amazing marketplace where you can discover "
      "delicious food, trendy electronics, beautiful clothing, and so much more from local sellers right here in South Africa."
    );
    
    await Future.delayed(const Duration(seconds: 3));
    
    // Step 2: Explain the main features
    await _voiceAssistant.speak(
      "Let me walk you through all the wonderful things you can do here. You can browse our beautiful product categories, "
      "add items to your cart with just a tap, place orders easily, and track your deliveries in real-time. "
      "And if you're feeling entrepreneurial, you can even become a seller and share your own amazing products with the community."
    );
    
    await Future.delayed(const Duration(seconds: 3));
    
    // Step 3: Explain the home screen
    await _voiceAssistant.speak(
      "You're now on the home screen. Here you can see different product categories. "
      "Tap on any category to browse products. The categories include Food, Clothing, "
      "Electronics, and Other items."
    );
    
    await Future.delayed(const Duration(seconds: 3));
    
    // Step 4: Explain navigation
    await _voiceAssistant.speak(
      "At the bottom of the screen, you'll find navigation tabs. "
      "The home tab shows categories, the cart tab shows your selected items, "
      "the orders tab shows your purchase history, and the profile tab has your account settings."
    );
    
    await Future.delayed(const Duration(seconds: 3));
    
    // Step 5: Explain the floating mic
    await _voiceAssistant.speak(
      "See the floating microphone button in the bottom-right corner? "
      "That's me! You can tap it anytime to ask questions or get help. "
      "I'm here to guide you through the app and answer any questions you have."
    );
    
    await Future.delayed(const Duration(seconds: 3));
    
    // Step 6: Explain shopping process
    await _voiceAssistant.speak(
      "To start shopping, tap on a category like Food or Electronics. "
      "Browse through the products, tap on any item to see details, "
      "and use the plus button to add items to your cart. "
      "When you're ready, go to the cart to checkout."
    );
    
    await Future.delayed(const Duration(seconds: 3));
    
    // Step 7: Explain selling
    await _voiceAssistant.speak(
      "Want to sell your own products? You can become a seller by going to your profile "
      "and following the seller registration process. Once approved, you can upload "
      "your products and start earning money from sales."
    );
    
    await Future.delayed(const Duration(seconds: 3));
    
    // Step 8: Explain delivery and payment
    await _voiceAssistant.speak(
      "We offer flexible delivery options including home delivery and pickup points. "
      "You can pay using various methods including credit cards, mobile payments, "
      "and cash on delivery. All transactions are secure and protected."
    );
    
    await Future.delayed(const Duration(seconds: 3));
    
    // Step 9: Final encouragement
    await _voiceAssistant.speak(
      "And that's everything! You're all set to start your amazing shopping journey with OmniaSA. "
      "Remember, I'm Nathan, and I'm always here to help you! Just tap the mic button anytime and ask me anything. "
      "I'm so excited to help you discover wonderful products. Happy shopping, and welcome to the family!"
    );
  }
  
  /// Provide context-specific help based on current screen
  static Future<void> provideContextualHelp({
    required String screenName,
    required BuildContext context,
  }) async {
    switch (screenName.toLowerCase()) {
      case 'home':
        await _explainHomeScreen();
        break;
      case 'products':
        await _explainProductsScreen();
        break;
      case 'cart':
        await _explainCartScreen();
        break;
      case 'checkout':
        await _explainCheckoutScreen();
        break;
      case 'orders':
        await _explainOrdersScreen();
        break;
      case 'profile':
        await _explainProfileScreen();
        break;
      case 'seller':
        await _explainSellerScreen();
        break;
      default:
        await _explainGeneralApp();
    }
  }
  
  /// Explain the home screen
  static Future<void> _explainHomeScreen() async {
    await _voiceAssistant.speak(
      "This is your home screen. Here you can see different product categories. "
      "Tap on any category to browse products. You can also use the search bar "
      "to find specific items. The floating mic button is always available for help."
    );
  }
  
  /// Explain the products screen
  static Future<void> _explainProductsScreen() async {
    await _voiceAssistant.speak(
      "You're browsing products. You can filter by price, rating, or availability. "
      "Tap on any product to see detailed information, photos, and reviews. "
      "Use the plus button to add items to your cart."
    );
  }
  
  /// Explain the cart screen
  static Future<void> _explainCartScreen() async {
    await _voiceAssistant.speak(
      "This is your shopping cart. Review your selected items and quantities. "
      "You can remove items or change quantities. When you're ready, "
      "tap checkout to proceed with your purchase."
    );
  }
  
  /// Explain the checkout screen
  static Future<void> _explainCheckoutScreen() async {
    await _voiceAssistant.speak(
      "You're at checkout. Choose your delivery method and address. "
      "Select your payment method. Review your order details and total. "
      "Tap place order to complete your purchase."
    );
  }
  
  /// Explain the orders screen
  static Future<void> _explainOrdersScreen() async {
    await _voiceAssistant.speak(
      "This shows all your orders. You can see order status, track deliveries, "
      "view receipts, and reorder items. Tap on any order for detailed information."
    );
  }
  
  /// Explain the profile screen
  static Future<void> _explainProfileScreen() async {
    await _voiceAssistant.speak(
      "This is your profile. You can update your information, change settings, "
      "view your order history, and manage your account. You can also become a seller here."
    );
  }
  
  /// Explain the seller screen
  static Future<void> _explainSellerScreen() async {
    await _voiceAssistant.speak(
      "This is your seller dashboard. You can manage your products, view orders, "
      "track sales, and handle customer inquiries. Upload new products and manage your inventory here."
    );
  }
  
  /// Explain the general app
  static Future<void> _explainGeneralApp() async {
    await _voiceAssistant.speak(
      "OmniaSA is a marketplace app where you can buy and sell products. "
      "Browse categories, add items to cart, place orders, and track deliveries. "
      "You can also become a seller and list your own products. "
      "I'm here to help you navigate and use all the features."
    );
  }
  
  /// Answer common questions about the app
  static Future<void> answerCommonQuestion(String question) async {
    final q = question.toLowerCase();
    
    if (q.contains('what') && q.contains('app')) {
      await _voiceAssistant.speak(
        "OmniaSA is a marketplace app where you can buy and sell products. "
        "It's like an online shopping mall where local sellers can list their items "
        "and customers can browse and purchase them. You can find food, electronics, "
        "clothing, and many other products from sellers in South Africa."
      );
    } else if (q.contains('how') && q.contains('buy')) {
      await _voiceAssistant.speak(
        "To buy products, browse categories or search for items. Tap on any product "
        "to see details, then use the plus button to add it to your cart. "
        "Go to the cart tab, review your items, and tap checkout. "
        "Choose delivery method and payment, then place your order."
      );
    } else if (q.contains('how') && q.contains('sell')) {
      await _voiceAssistant.speak(
        "To become a seller, go to your profile and look for the seller registration option. "
        "Fill out the required information and wait for approval. Once approved, "
        "you can upload your products, set prices, and start selling to customers."
      );
    } else if (q.contains('delivery')) {
      await _voiceAssistant.speak(
        "We offer flexible delivery options. You can choose home delivery to your address "
        "or pickup from our partner locations. Delivery times vary by location and seller. "
        "You can track your delivery in real-time through the orders tab."
      );
    } else if (q.contains('payment')) {
      await _voiceAssistant.speak(
        "We accept various payment methods including credit cards, debit cards, "
        "mobile payments like SnapScan or Zapper, and cash on delivery. "
        "All payments are processed securely and your information is protected."
      );
    } else if (q.contains('help') || q.contains('support')) {
      await _voiceAssistant.speak(
        "I'm here to help! You can ask me about shopping, selling, orders, delivery, "
        "payments, or how to use any feature. You can also contact our support team "
        "through the help section in your profile."
      );
    } else {
      await _voiceAssistant.speak(
        "I understand you're asking about $question. Let me help you with that. "
        "Could you be more specific about what you'd like to know about the app?"
      );
    }
  }
  
  /// Check if user needs onboarding
  static bool shouldShowOnboarding({
    required DateTime? userRegistrationDate,
    required bool hasPlacedOrder,
    required bool hasBrowsedProducts,
  }) {
    // Show onboarding if user is new (registered within last 7 days)
    if (userRegistrationDate != null) {
      final daysSinceRegistration = DateTime.now().difference(userRegistrationDate).inDays;
      if (daysSinceRegistration <= 7) return true;
    }
    
    // Show onboarding if user hasn't placed an order or browsed products
    if (!hasPlacedOrder && !hasBrowsedProducts) return true;
    
    return false;
  }
  
  /// Get onboarding status
  static Map<String, dynamic> getOnboardingStatus({
    required DateTime? userRegistrationDate,
    required bool hasPlacedOrder,
    required bool hasBrowsedProducts,
  }) {
    final shouldShow = shouldShowOnboarding(
      userRegistrationDate: userRegistrationDate,
      hasPlacedOrder: hasPlacedOrder,
      hasBrowsedProducts: hasBrowsedProducts,
    );
    
    return {
      'shouldShowOnboarding': shouldShow,
      'isNewUser': userRegistrationDate != null && 
                   DateTime.now().difference(userRegistrationDate).inDays <= 7,
      'hasPlacedOrder': hasPlacedOrder,
      'hasBrowsedProducts': hasBrowsedProducts,
      'daysSinceRegistration': userRegistrationDate != null ? 
                              DateTime.now().difference(userRegistrationDate).inDays : null,
    };
  }
}
