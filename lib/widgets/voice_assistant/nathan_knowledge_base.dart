import 'dart:math';
import 'package:flutter/foundation.dart';

/// Nathan's Comprehensive Knowledge Base for Smart Question Answering
class NathanKnowledgeBase {
  static final NathanKnowledgeBase _instance = NathanKnowledgeBase._internal();
  factory NathanKnowledgeBase() => _instance;
  NathanKnowledgeBase._internal();

  /// Comprehensive knowledge database
  static const Map<String, List<String>> _knowledgeBase = {
    // App Usage Questions
    'how_to_shop': [
      "Shopping is easy! Browse categories by tapping on Food, Electronics, Clothing, or Other. Tap any product to see details, then use the plus button to add it to your cart. When ready, go to your cart and tap checkout!",
      "Here's how to shop: First, choose a category like Food or Electronics. Browse the products and tap on anything that interests you. You'll see photos, prices, and descriptions. Tap the plus icon to add items to your cart, then checkout when you're ready!",
      "Shopping on OmniaSA is simple! Start by exploring our categories - we have amazing food, electronics, clothing, and more. Tap on products to learn about them, add favorites to your cart, and checkout securely. I'm here to help every step of the way!"
    ],
    
    'how_to_sell': [
      "Want to become a seller? Great! Go to your profile, look for the seller registration option, and fill out the required information. Once approved, you can upload products, set prices, and start earning money from sales to our community!",
      "Becoming a seller is exciting! Visit your profile section and follow the seller registration process. You'll need to provide some basic business information. After approval, you can start listing your amazing products and reach thousands of potential customers!",
      "Ready to start selling? Head to your profile and sign up as a seller. The process is straightforward - just provide your details and wait for approval. Then you can showcase your products to our growing marketplace community!"
    ],

    'delivery_info': [
      "We offer flexible delivery options! You can choose home delivery to your address or pickup from our convenient partner locations. Delivery times vary by location and seller, and you can track everything in real-time through your orders tab.",
      "Delivery is super convenient! We have home delivery that brings products right to your door, or you can pick up from nearby collection points. All deliveries are tracked so you always know where your order is!",
      "Our delivery system is designed for your convenience! Choose between home delivery or pickup points. We work with reliable delivery partners to ensure your products arrive safely and on time. Track everything through the app!"
    ],

    'payment_methods': [
      "We accept various secure payment methods including credit cards, debit cards, mobile payments like SnapScan or Zapper, and cash on delivery. All transactions are encrypted and protected for your security.",
      "Payment is flexible and secure! Use your credit or debit card, mobile payment apps, or choose cash on delivery if you prefer. We use advanced encryption to keep all your payment information completely safe.",
      "You have lots of payment options! Credit cards, debit cards, mobile wallets, and cash on delivery are all available. Every transaction is secured with bank-level encryption for your peace of mind."
    ],

    // Product Questions
    'product_quality': [
      "Product quality is our top priority! All sellers are verified, and we have customer reviews and ratings for every product. If you're not satisfied, our return policy protects you. Look for products with high ratings and lots of positive reviews!",
      "We maintain high quality standards! Every seller goes through verification, products have detailed descriptions and real customer reviews. You can always check ratings before buying, and we have buyer protection policies in place.",
      "Quality matters to us! We carefully vet our sellers and encourage detailed product descriptions. Customer reviews and ratings help you make informed decisions. Plus, we have return policies to ensure you're always satisfied with your purchases."
    ],

    'how_to_search': [
      "Searching is easy! Use the search bar at the top to type what you're looking for, or browse by categories. You can filter by price, ratings, and availability. I can also help - just say 'search for' followed by what you want!",
      "Finding products is simple! Type in the search bar or browse our organized categories. Use filters to narrow down by price range, customer ratings, or seller location. You can even ask me to search for specific items!",
      "There are several ways to find products! Use the search function, browse categories, or tell me what you're looking for. You can sort results by price, popularity, or ratings to find exactly what you need."
    ],

    // Order Management
    'track_order': [
      "Tracking your order is easy! Go to the Orders tab to see all your purchases. Each order shows its current status - processing, shipped, out for delivery, or delivered. You'll get notifications for each update too!",
      "You can track everything in the Orders section! See real-time updates on your purchases, from processing to delivery. We send notifications for each status change so you're always informed about your order's progress.",
      "Order tracking is built right in! Check the Orders tab for detailed status updates. You'll see when your order is confirmed, being prepared, shipped, and delivered. We keep you updated every step of the way!"
    ],

    'cancel_order': [
      "You can cancel orders that haven't been shipped yet! Go to your Orders tab, find the order you want to cancel, and look for the cancel button. If it's already shipped, you'll need to wait for delivery and then use our return process.",
      "Cancellation is possible before shipping! Visit your Orders section and tap cancel on any order that's still being processed. Once shipped, you'll need to wait for delivery and then return the item if needed.",
      "To cancel an order, go to Orders and tap cancel while it's still processing. After shipping starts, cancellation isn't possible, but our return policy covers you if you change your mind after delivery."
    ],

    // Account & Profile
    'forgot_password': [
      "No worries! On the login screen, tap 'Forgot Password' and enter your email address. We'll send you a reset link right away. Follow the instructions in the email to create a new password securely.",
      "Password reset is simple! Use the 'Forgot Password' link on the login page, enter your email, and check your inbox for reset instructions. You'll be back to shopping in no time!",
      "Happens to everyone! Click 'Forgot Password' at login, enter your email address, and we'll send you a secure reset link. Follow the email instructions to set up a new password."
    ],

    'update_profile': [
      "Updating your profile is easy! Go to the Profile tab, tap edit, and change whatever information you need - name, address, phone number, or profile picture. Don't forget to save your changes!",
      "Profile updates happen in the Profile section! Tap the edit button to change your personal information, delivery addresses, or contact details. Make sure to save when you're done making changes.",
      "Visit your Profile tab to update any information! You can change your name, contact details, addresses, and even your profile photo. Just tap edit, make your changes, and save!"
    ],

    // Troubleshooting
    'app_problems': [
      "If you're having app issues, try these steps: First, close and reopen the app. If that doesn't work, restart your device. For persistent problems, check your internet connection or contact our support team through the help section!",
      "Technical troubles? Here's what usually helps: Force close the app and reopen it, check your internet connection, or restart your phone. If problems continue, our support team is ready to help through the app's help section!",
      "For app issues, try the basics first: close and reopen the app, check your internet, or restart your device. Most problems resolve quickly! If not, our technical support team is available through the help menu."
    ],

    // Safety & Security
    'is_it_safe': [
      "Absolutely! OmniaSA uses bank-level security for all transactions. We verify all sellers, encrypt your data, and have secure payment processing. Your personal information is protected, and we have buyer protection policies for your peace of mind.",
      "Safety is our top priority! We use advanced encryption, verify all sellers, and secure all payments. Your data is protected with the same security standards as banks. Plus, we have policies to protect buyers in every transaction.",
      "Yes, very safe! We employ enterprise-grade security measures, seller verification processes, and secure payment gateways. Your information is encrypted and protected. We also have buyer protection and support to ensure safe shopping."
    ],

    // Pricing & Deals
    'best_deals': [
      "Great deals are everywhere! Check our featured products on the home screen, look for items with discount badges, and follow your favorite sellers for special offers. I'll also notify you about deals in categories you shop frequently!",
      "Finding deals is fun! Browse featured products, check items with sale badges, and watch for seller promotions. You can also save products to your wishlist and get notified when their prices drop!",
      "Deals are always available! Look for discount tags on products, check the featured section, and follow sellers you like for exclusive offers. I can also alert you about deals on items you've viewed before!"
    ],

    // General App Information
    'about_omniasa': [
      "OmniaSA is South Africa's local marketplace where you can buy and sell amazing products! We connect local sellers with customers like you, offering everything from fresh food to electronics, clothing, and more. Our mission is to support local businesses while giving you great shopping experiences!",
      "Welcome to OmniaSA! We're a proudly South African marketplace that brings together local sellers and shoppers. You'll find incredible variety - food, electronics, fashion, and unique items - all from talented local entrepreneurs. We're building a community that supports local business!",
      "OmniaSA is your local shopping destination! We're a South African marketplace featuring products from verified local sellers. From delicious food to latest electronics and trendy clothing, we help you discover amazing products while supporting local businesses and entrepreneurs!"
    ],

    // Nathan Personal Questions
    'who_are_you': [
      "Hi! I'm Nathan, your little shopping buddy on OmniaSA! I know lots of things about products and I love helping people find cool stuff! I'm super excited to help you!",
      "I'm Nathan, your adorable AI shopping helper! I was made to help make shopping super fun and easy for everyone! I can answer questions, help you find awesome products, and chat about what you need. I'm always happy to help!"
    ],

    'who_created_you': [
      "My daddy made me! He's super smart but likes to be anonymous. But if you give me cookies, maybe I can tell you his name! Hehe! Just kidding - I'm here to help with shopping!",
      "A really nice smart person made me to help with shopping! He's like my daddy but he's shy and doesn't want me to say his name! But I love helping you!",
      "I was made by the smartest daddy ever! He wanted me to help make shopping fun for everyone, but he's too shy to tell you his name! Isn't that silly?",
      "Ooh, that's a secret! My creator is super duper smart but he's hiding! Maybe if you give me lots of hugs I'll tell you! Just kidding, I'm your little shopping helper!"
    ],

    'what_can_you_do': [
      "I can help with so many things! I can answer questions about products, guide you through shopping, explain how features work, help you track orders, find deals, and even chat about what you're looking for. Just ask me anything about shopping or the app!",
      "I'm here to make shopping easy! I can help you search for products, explain how to use features, answer questions about orders and payments, guide new users, provide seller information, and help troubleshoot any issues. I'm like having a shopping expert in your pocket!",
      "Lots of things! I can help you navigate the app, find specific products, explain policies, track orders, discover deals, guide you through selling, answer technical questions, and provide shopping advice. I'm designed to be your complete shopping assistant!"
    ],

    // Seller Payment Information
    'seller_payment': [
      "Sellers get paid through our weekly payout system! Once an order is completed, your earnings become available for payout. You can request a payout anytime (minimum R100) and it will be processed weekly to your registered bank account. Commission rates vary: 6% for pickup orders, 9% if you deliver, and 11% if we arrange courier delivery.",
      "Payment for sellers works with weekly payouts! After each completed order, your earnings (minus commission) become available immediately. You can request payouts of R100 or more anytime, and they're processed weekly to your bank account. Commission is 6% for pickup, 9% for your delivery, or 11% for courier delivery - with caps to keep it fair!",
      "Getting paid as a seller is transparent! Your earnings from completed orders are available right away. Request payouts of R100+ anytime through your seller dashboard, and we process them weekly to your bank account. Commission rates are: 6% pickup (min R5, max R30), 9% you deliver (max R40), or 11% courier delivery (max R50). You can also enable instant payouts for a small fee!"
    ],

    // Seller Delivery Information
    'seller_delivery': [
      "As a seller, you have flexible delivery options! You can choose to deliver products yourself within your local area, use our partner delivery services for wider reach, or offer pickup from your location. Set your delivery zones and costs in your seller settings, and customers will see your delivery options when they shop!",
      "Delivery options for sellers are customizable! You can deliver personally to nearby areas, partner with local delivery services, or offer customer pickup. Set your delivery radius, costs, and timeframes in your seller dashboard. Customers will see your delivery options and can choose what works best for them!",
      "Sellers control their own delivery! You can offer personal delivery within your area, use third-party delivery partners, or provide pickup options. Configure your delivery zones, pricing, and availability in your seller settings. This gives you flexibility while ensuring customers know exactly how they'll receive their orders!"
    ],
  };

  /// Advanced question processing patterns
  static const Map<String, List<String>> _questionPatterns = {
    'how_to_shop': ['how to shop', 'how do i buy', 'how to purchase', 'buying guide', 'shopping guide', 'how to order'],
    'how_to_sell': ['how to sell', 'become seller', 'start selling', 'sell products', 'seller registration'],
    'delivery_info': ['delivery', 'shipping', 'when will it arrive', 'delivery time', 'shipping cost', 'delivery options'],
    'payment_methods': ['payment', 'how to pay', 'payment options', 'payment methods', 'credit card', 'cash on delivery'],
    'product_quality': ['quality', 'is it good', 'product quality', 'reviews', 'ratings', 'is it worth it'],
    'how_to_search': ['how to search', 'find products', 'search for', 'looking for', 'where to find'],
    'track_order': ['track order', 'order status', 'where is my order', 'track my purchase', 'delivery status'],
    'cancel_order': ['cancel order', 'cancel purchase', 'cancel my order', 'refund', 'return'],
    'forgot_password': ['forgot password', 'reset password', 'cant login', 'password reset', 'login problems'],
    'update_profile': ['update profile', 'change information', 'edit profile', 'update details', 'change address'],
    'app_problems': ['app not working', 'technical issues', 'app problems', 'app crashes', 'app slow'],
    'is_it_safe': ['is it safe', 'security', 'safe to buy', 'secure payment', 'protect my data'],
    'best_deals': ['deals', 'discounts', 'best prices', 'sales', 'offers', 'cheap products'],
    'about_omniasa': ['what is omniasa', 'about the app', 'about this app', 'company information'],
    'who_are_you': ['who are you', 'what are you', 'tell me about yourself', 'introduce yourself'],
    'who_created_you': ['who created you', 'who developed you', 'who made you', 'who built you', 'who programmed you', 'who designed you'],
    'what_can_you_do': ['what can you do', 'how can you help', 'what help', 'your abilities', 'help me'],
    'seller_payment': ['how do sellers get paid', 'seller payment', 'when do sellers get paid', 'seller earnings', 'how do i get paid as seller', 'seller money', 'payment for sellers'],
    'seller_delivery': ['how do sellers deliver', 'seller delivery', 'how to deliver as seller', 'delivery options for sellers', 'how do i deliver products', 'seller shipping'],
  };

  /// Smart question answering
  String answerQuestion(String question) {
    final normalizedQuestion = question.toLowerCase().trim();
    
    // Find the best matching pattern
    String? bestMatch;
    int highestScore = 0;
    
    for (final entry in _questionPatterns.entries) {
      final score = _calculateMatchScore(normalizedQuestion, entry.value);
      if (score > highestScore) {
        highestScore = score;
        bestMatch = entry.key;
      }
    }
    
    // Return answer if we found a good match
    if (bestMatch != null && highestScore > 0) {
      final answers = _knowledgeBase[bestMatch]!;
      final randomAnswer = answers[Random().nextInt(answers.length)];
      
      if (kDebugMode) {
        print('🧠 Nathan answered: $bestMatch (score: $highestScore)');
      }
      
      return randomAnswer;
    }
    
    // Fallback answers for unmatched questions
    return _getFallbackAnswer(normalizedQuestion);
  }

  /// Calculate match score for question patterns
  int _calculateMatchScore(String question, List<String> patterns) {
    int score = 0;
    
    for (final pattern in patterns) {
      if (question.contains(pattern)) {
        score += pattern.split(' ').length; // Longer matches get higher scores
      }
    }
    
    return score;
  }

  /// Fallback answers for questions not in knowledge base
  String _getFallbackAnswer(String question) {
    // Check for product-specific questions
    if (question.contains('product') || question.contains('item')) {
      return "I'd love to help you with that product question! Could you be more specific about what you'd like to know? I can help with details, pricing, reviews, or availability.";
    }
    
    // Check for price questions
    if (question.contains('price') || question.contains('cost') || question.contains('expensive')) {
      return "For pricing information, you can browse products in our categories or use the search function. Prices vary by seller and product type. Would you like me to help you find something specific?";
    }
    
    // Check for location questions
    if (question.contains('location') || question.contains('store') || question.contains('address')) {
      return "OmniaSA is an online marketplace, so you can shop from anywhere! We deliver to most areas in South Africa. For specific delivery locations, check the delivery options during checkout.";
    }
    
    // Check for comparison questions
    if (question.contains('compare') || question.contains('better') || question.contains('difference')) {
      return "Great question! I can help you compare products. Look at the ratings, reviews, prices, and features of different items. Customer reviews are especially helpful for comparisons. What products are you thinking about?";
    }
    
    // Check for recommendation questions
    if (question.contains('recommend') || question.contains('suggest') || question.contains('best')) {
      return "I'd love to help you find the perfect product! Tell me what category you're interested in - food, electronics, clothing, or something else - and I can guide you to highly-rated options that other customers love!";
    }
    
    // General fallback
    final fallbacks = [
      "That's a great question! While I don't have that specific information right now, I'm always learning. You could try browsing our help section, or I can help you with shopping, orders, or app features. What else can I assist you with?",
      "I want to help, but I need a bit more context for that question. Could you rephrase it or be more specific? I'm great at helping with shopping, product information, orders, and app features!",
      "I'm not sure about that specific topic, but I'm here to help with anything related to shopping on OmniaSA! Try asking about products, orders, delivery, payments, or how to use the app. What would you like to explore?",
    ];
    
    return fallbacks[Random().nextInt(fallbacks.length)];
  }

  /// Get conversation starters
  List<String> getConversationStarters() {
    return [
      "What can I help you find today?",
      "Looking for anything specific?",
      "Need help with shopping or have questions about the app?",
      "I'm here to help! What would you like to know?",
      "Ready to discover some amazing products?",
    ];
  }

  /// Get helpful tips
  List<String> getHelpfulTips() {
    return [
      "💡 Tip: Check product reviews before buying for the best experience!",
      "💡 Tip: Save items to your wishlist to track price changes!",
      "💡 Tip: Follow your favorite sellers to get notified of new products!",
      "💡 Tip: Use filters when searching to find exactly what you need!",
      "💡 Tip: Read delivery information carefully to choose the best option!",
    ];
  }

  /// Check if Nathan can answer a question confidently
  bool canAnswerConfidently(String question) {
    final normalizedQuestion = question.toLowerCase().trim();
    
    for (final patterns in _questionPatterns.values) {
      for (final pattern in patterns) {
        if (normalizedQuestion.contains(pattern)) {
          return true;
        }
      }
    }
    
    return false;
  }

  /// Get related questions
  List<String> getRelatedQuestions(String topic) {
    final related = <String>[];
    
    switch (topic.toLowerCase()) {
      case 'shopping':
        related.addAll([
          "How do I add items to my cart?",
          "What payment methods do you accept?",
          "How long does delivery take?",
          "Can I track my order?"
        ]);
        break;
      case 'selling':
        related.addAll([
          "How do I become a seller?",
          "What can I sell on OmniaSA?",
          "How do I upload products?",
          "When do I get paid?"
        ]);
        break;
      case 'orders':
        related.addAll([
          "How do I track my order?",
          "Can I cancel my order?",
          "What if my order is late?",
          "How do returns work?"
        ]);
        break;
    }
    
    return related;
  }

  /// Extract relevant knowledge for LLM context
  List<String> extractRelevantKnowledge(String userQuestion) {
    final normalizedQuestion = userQuestion.toLowerCase().trim();
    final relevantAnswers = <String>[];
    
    // Find multiple matching patterns and collect relevant knowledge
    final matchedTopics = <String>[];
    
    for (final entry in _questionPatterns.entries) {
      final score = _calculateMatchScore(normalizedQuestion, entry.value);
      if (score > 0) {
        matchedTopics.add(entry.key);
      }
    }
    
    // Sort by relevance and take top matches
    matchedTopics.sort((a, b) {
      final scoreA = _calculateMatchScore(normalizedQuestion, _questionPatterns[a]!);
      final scoreB = _calculateMatchScore(normalizedQuestion, _questionPatterns[b]!);
      return scoreB.compareTo(scoreA);
    });
    
    // Extract knowledge from top matches
    for (int i = 0; i < matchedTopics.length && i < 3; i++) {
      final topic = matchedTopics[i];
      final answers = _knowledgeBase[topic];
      if (answers != null && answers.isNotEmpty) {
        // Take the first answer as it's usually the most comprehensive
        relevantAnswers.add(answers.first);
      }
    }
    
    // If no specific matches, add general helpful info
    if (relevantAnswers.isEmpty) {
      _addGeneralKnowledge(normalizedQuestion, relevantAnswers);
    }
    
    if (kDebugMode) {
      print('🧠 Extracted ${relevantAnswers.length} relevant knowledge pieces for: "$userQuestion"');
    }
    
    return relevantAnswers;
  }

  /// Add general knowledge based on question type
  void _addGeneralKnowledge(String question, List<String> knowledge) {
    // Add general app info for basic questions
    if (question.contains('app') || question.contains('omniasa')) {
      knowledge.add(_knowledgeBase['about_omniasa']?.first ?? '');
    }
    
    // Add help info for vague questions
    if (question.contains('help') || question.contains('what')) {
      knowledge.add(_knowledgeBase['what_can_you_do']?.first ?? '');
    }
    
    // Add shopping guidance for product questions
    if (question.contains('product') || question.contains('buy') || question.contains('find')) {
      knowledge.add(_knowledgeBase['how_to_shop']?.first ?? '');
    }
    
    // Add safety info for security questions
    if (question.contains('safe') || question.contains('secure') || question.contains('trust')) {
      knowledge.add(_knowledgeBase['is_it_safe']?.first ?? '');
    }
  }

  /// Get contextual knowledge based on conversation history
  List<String> getContextualKnowledge(List<String> recentTopics, String currentQuestion) {
    final knowledge = <String>[];
    
    // Add knowledge from recent conversation topics
    for (final topic in recentTopics.take(2)) {
      switch (topic) {
        case 'shopping':
          knowledge.add("Previous topic: Shopping - Remember, you can browse categories, use search, and add items to cart.");
          break;
        case 'selling':
          knowledge.add("Previous topic: Selling - Remember, seller registration and product uploads were discussed.");
          break;
        case 'orders':
          knowledge.add("Previous topic: Orders - Remember, tracking and order management were mentioned.");
          break;
      }
    }
    
    // Add current question knowledge
    knowledge.addAll(extractRelevantKnowledge(currentQuestion));
    
    return knowledge;
  }

  /// Get knowledge summary for a specific topic
  String getTopicSummary(String topic) {
    final answers = _knowledgeBase[topic];
    if (answers != null && answers.isNotEmpty) {
      // Return a concise version of the first answer
      final fullAnswer = answers.first;
      if (fullAnswer.length > 150) {
        final sentences = fullAnswer.split('. ');
        return sentences.first + '.';
      }
      return fullAnswer;
    }
    return '';
  }
}
