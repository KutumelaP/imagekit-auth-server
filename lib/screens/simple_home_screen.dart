import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import 'store_page.dart';
import 'login_screen.dart';
import '../providers/cart_provider.dart';
import '../providers/user_provider.dart';
import 'ProfileEditScreen.dart';
import 'OrderHistoryScreen.dart';
import 'ChatListScreen.dart';
import 'NotificationListScreen.dart';
import 'SellerOrdersListScreen.dart';
import 'SellerRegistrationScreen.dart';
import 'seller_onboarding_screen.dart';
import 'stunning_product_upload.dart';
import 'seller_product_management.dart';
// import 'fcm_test_screen.dart'; // Removed - test screen deleted


import 'dart:async'; // Added import for StreamSubscription
import '../services/global_message_listener.dart';
import '../services/notification_service.dart'; // Added import for NotificationService
import '../widgets/notification_badge.dart';
import '../widgets/chat_badge.dart';
import 'package:geolocator/geolocator.dart';

class SimpleHomeScreen extends StatefulWidget {
  const SimpleHomeScreen({super.key});

  @override
  State<SimpleHomeScreen> createState() => _SimpleHomeScreenState();
}

class _SimpleHomeScreenState extends State<SimpleHomeScreen> 
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription<QuerySnapshot>? _messageListener;
  Map<String, String> _lastMessageIds = {}; // Track last message ID for each chat
  
  // Smooth animations
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isDriver = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeScreen();
    _setupMessageListener();
    _checkDriverStatus();
    
    // Start global message listener for chat notifications
    GlobalMessageListener().startListening();
    
    // Initialize user provider data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.loadUserData();
    });
    
    // Request location permission when app starts
    _requestLocationPermission();
  }
  
  Future<void> _requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          print('🔍 DEBUG: Requesting location permission from home screen...');
          await Geolocator.requestPermission();
        }
      }
    } catch (e) {
      print('🔍 DEBUG: Error requesting location permission: $e');
    }
  }

  Future<void> _checkDriverStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final driverDoc = await FirebaseFirestore.instance
            .collection('drivers')
            .doc(user.uid)
            .get();
        
        setState(() {
          _isDriver = driverDoc.exists;
        });
      }
    } catch (e) {
      print('Error checking driver status: $e');
    }
  }

  void _setupMessageListener() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Listen for new messages in user's chats (simplified approach)
    _messageListener = FirebaseFirestore.instance
        .collection('chats')
        .where('buyerId', isEqualTo: currentUser.uid)
        .snapshots()
        .listen((snapshot) {
      for (final chatDoc in snapshot.docs) {
        _listenForNewMessagesInChat(chatDoc.id, currentUser.uid);
      }
    });

    // Also listen for seller chats
    FirebaseFirestore.instance
        .collection('chats')
        .where('sellerId', isEqualTo: currentUser.uid)
        .snapshots()
        .listen((snapshot) {
      for (final chatDoc in snapshot.docs) {
        _listenForNewMessagesInChat(chatDoc.id, currentUser.uid);
      }
    });
  }

  void _listenForNewMessagesInChat(String chatId, String currentUserId) {
    FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final latestMessage = snapshot.docs.first;
        final messageData = latestMessage.data();
        final senderId = messageData['senderId'] as String?;
        
        // Only show notification if the message is from someone else and is new
        if (senderId != null && 
            senderId != currentUserId && 
            latestMessage.id != _lastMessageIds[chatId]) {
          _lastMessageIds[chatId] = latestMessage.id;
          // _showIncomingMessageNotification(messageData, chatId);
        }
      }
    });
  }

  // void _showIncomingMessageNotification(Map<String, dynamic> messageData, String chatId) {
  //   final messageText = messageData['text'] ?? '';
  //   final imageUrl = messageData['imageUrl'];
  //   final senderId = messageData['senderId'] as String?;
  //   
  //   if (senderId == null) return;

  //   // Get sender's name and chat info
  //   FirebaseFirestore.instance
  //       .collection('users')
  //       .doc(senderId)
  //       .get()
  //       .then((senderDoc) {
  //     FirebaseFirestore.instance
  //         .collection('chats')
  //         .doc(chatId)
  //         .get()
  //         .then((chatDoc) {
  //       final senderName = senderDoc.data()?['displayName'] ?? 
  //                         senderDoc.data()?['email']?.split('@')[0] ?? 
  //                         'Someone';
  //       final chatData = chatDoc.data();
  //       final productName = chatData?['productName'] ?? 'Product';

  //       // Show snackbar notification for incoming message
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Row(
  //               children: [
  //                 Icon(Icons.message, color: Colors.white, size: 20),
  //                 const SizedBox(width: 8),
  //                 Expanded(
  //                   child: Column(
  //                     mainAxisSize: MainAxisSize.min,
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       Text(
  //                         'New message from $senderName',
  //                         style: const TextStyle(fontWeight: FontWeight.bold),
  //                       ),
  //                       Text(
  //                         'Re: $productName',
  //                         style: const TextStyle(fontSize: 12),
  //                       ),
  //                       Text(
  //                         imageUrl != null ? '[Image]' : messageText,
  //                         maxLines: 1,
  //                         overflow: TextOverflow.ellipsis,
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             backgroundColor: AppTheme.deepTeal,
  //             duration: const Duration(seconds: 4),
  //             behavior: SnackBarBehavior.floating,
  //             margin: const EdgeInsets.all(16),
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //             action: SnackBarAction(
  //               label: 'View',
  //               textColor: Colors.white,
  //               onPressed: () {
  //                 Navigator.push(
  //                   context,
  //                   MaterialPageRoute(
  //                     builder: (_) => ChatScreen(
  //                       chatId: chatId,
  //                       buyerId: chatData?['buyerId'] ?? '',
  //                       sellerId: chatData?['sellerId'] ?? '',
  //                     ),
  //                   ),
  //                 );
  //               },
  //             ),
  //           ),
  //         );
  //       }
  //     });
  //   });
  // }

  void _initializeAnimations() {
    // Smooth fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    // Smooth slide animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _messageListener?.cancel(); // Cancel the listener
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    try {
      await _loadCategories();
      
      if (mounted) {
        setState(() {
          // _isInitialized = true; // Removed unused field
        });
      }
    } catch (e) {
      print('❌ Screen initialization error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load categories. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      print('📱 Loading categories...');
      
      final snapshot = await FirebaseFirestore.instance
          .collection('categories')
          .limit(8) // Increased for better UX
          .get()
          .timeout(const Duration(seconds: 10));
      
      print('✅ Categories loaded: ${snapshot.docs.length} categories');
      
      if (mounted) {
        setState(() {
          _categories = snapshot.docs.map((doc) {
            final data = doc.data();
            String imageUrl = data['imageUrl'] ?? '';
            
            // If no image URL is provided, use a default image based on category name
            if (imageUrl.isEmpty) {
              imageUrl = _getDefaultCategoryImage(data['name'] ?? '');
            }
            
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'imageUrl': imageUrl,
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading categories: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load categories. Please check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  void _goToCategory(String category) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StoreSelectionScreen(category: category)),
      );
    } catch (e) {
      print('❌ Navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Navigation failed. Please try again.'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
    }
  }

  void _showPlatformFeeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Platform Fee Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepTeal,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Before you register as a seller, please note our platform fee structure:',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.darkGrey,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.receipt,
                          color: AppTheme.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Orders R50 and above:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.deepTeal,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '5%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.angel,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.receipt,
                          color: AppTheme.deepTeal,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Orders below R50:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.deepTeal,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.deepTeal,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '3%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.angel,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This fee helps us maintain the platform and provide support to all sellers.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.mediumGrey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppTheme.mediumGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SellerOnboardingScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: AppTheme.angel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Continue',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
    return Scaffold(
      backgroundColor: AppTheme.angel,
          floatingActionButton: userProvider.isSeller ? FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StunningProductUpload(
                        storeId: 'all',
                        storeName: 'My Store',
                      )),
              );
            },
            backgroundColor: AppTheme.deepTeal,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add_shopping_cart),
            tooltip: 'Upload Product',
          ) : null,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildBody(),
          ),
        ),
      ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return _buildStunningMainContent();
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.deepTeal, AppTheme.cloud],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated logo
            TweenAnimationBuilder<double>(
              duration: const Duration(seconds: 2),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                                              child: Image.asset(
                          'assets/logo.png',
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print('🔍 DEBUG: Loading screen logo failed to load: $error');
                            return const Icon(
                      Icons.shopping_bag,
                      color: AppTheme.deepTeal,
                      size: 50,
                            );
                          },
                        ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            const Text(
              'Mzansi Marketplace',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            const Text(
              'Loading amazing experiences...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.deepTeal, AppTheme.cloud],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Oops! Something went wrong',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadCategories();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.deepTeal,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStunningMainContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildStunningAppBar(),
            _buildWelcomeHero(),
            _buildCategoriesSection(),
            _buildMyPurchasesSection(),
            // Add bottom padding to prevent overflow
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).size.height * 0.05),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStunningAppBar() {
    return SliverAppBar(
      expandedHeight: _getResponsiveAppBarHeight(),
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.deepTeal,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.deepTeal, AppTheme.cloud],
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles - only on larger screens
              if (MediaQuery.of(context).size.width > 600) ...[
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -30,
                  left: -30,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
              // Content
              Padding(
                padding: _getResponsivePadding(),
                child: _buildResponsiveHeaderContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Responsive height based on screen size
  double _getResponsiveAppBarHeight() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    if (screenWidth < 600) {
      // Mobile: Very compact height - further reduced to eliminate overflow
      return screenHeight * 0.05;
    } else if (screenWidth < 900) {
      // Tablet: Medium height
      return screenHeight * 0.1;
    } else {
      // Desktop: Larger height
      return screenHeight * 0.12;
    }
  }

  // Responsive padding based on screen size
  EdgeInsets _getResponsivePadding() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    if (screenWidth < 600) {
      // Mobile: Very compact padding
      return EdgeInsets.fromLTRB(
        screenWidth * 0.03,
        screenHeight * 0.015,
        screenWidth * 0.03,
        screenHeight * 0.005,
      );
    } else if (screenWidth < 900) {
      // Tablet: Medium padding
      return EdgeInsets.fromLTRB(
        screenWidth * 0.04,
        screenHeight * 0.03,
        screenWidth * 0.04,
        screenHeight * 0.015,
      );
    } else {
      // Desktop: Larger padding
      return EdgeInsets.fromLTRB(
        screenWidth * 0.05,
        screenHeight * 0.04,
        screenWidth * 0.05,
        screenHeight * 0.02,
      );
    }
  }

  // Responsive header content
  Widget _buildResponsiveHeaderContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth < 600) {
      // Mobile: Compact layout
      return _buildMobileHeader();
    } else if (screenWidth < 900) {
      // Tablet: Medium layout
      return _buildTabletHeader();
    } else {
      // Desktop: Full layout
      return _buildDesktopHeader();
    }
  }

  // Mobile header layout
  Widget _buildMobileHeader() {
    return Row(
      children: [
        // Logo - smaller for mobile
        Container(
          width: MediaQuery.of(context).size.width * 0.1,
          height: MediaQuery.of(context).size.width * 0.1,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/logo.png',
              width: MediaQuery.of(context).size.width * 0.1,
              height: MediaQuery.of(context).size.width * 0.1,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.shopping_bag,
                  color: Colors.white,
                  size: 20,
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Title only - removed subtitle for mobile
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Mzansi Marketplace',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: MediaQuery.of(context).size.width * 0.04,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Buttons - include notification and chat for mobile
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNotificationButton(),
            const SizedBox(width: 4),
            _buildChatButton(),
            const SizedBox(width: 4),
            _buildAccountMenu(),
            const SizedBox(width: 4),
            _buildCartButton(),
          ],
        ),
      ],
    );
  }

  // Tablet header layout
  Widget _buildTabletHeader() {
    return Row(
      children: [
        // Logo - medium size for tablet
        Container(
          width: MediaQuery.of(context).size.width * 0.08,
          height: MediaQuery.of(context).size.width * 0.08,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.asset(
              'assets/logo.png',
              width: MediaQuery.of(context).size.width * 0.08,
              height: MediaQuery.of(context).size.width * 0.08,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.shopping_bag,
                  color: Colors.white,
                  size: 28,
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Title only - removed subtitle for tablet
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Mzansi Marketplace',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: MediaQuery.of(context).size.width * 0.04,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Buttons - more buttons for tablet
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNotificationButton(),
            const SizedBox(width: 4),
            _buildChatButton(),
            const SizedBox(width: 4),
            if (FirebaseAuth.instance.currentUser != null) _buildMyOrdersButton(),
            const SizedBox(width: 4),
            _buildAccountMenu(),
            const SizedBox(width: 4),
            _buildCartButton(),
          ],
        ),
      ],
    );
  }

  // Desktop header layout
  Widget _buildDesktopHeader() {
    return Row(
      children: [
        // Logo - larger for desktop
        Container(
          width: MediaQuery.of(context).size.width * 0.06,
          height: MediaQuery.of(context).size.width * 0.06,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/logo.png',
              width: MediaQuery.of(context).size.width * 0.06,
              height: MediaQuery.of(context).size.width * 0.06,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.shopping_bag,
                  color: Colors.white,
                  size: 32,
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 20),
        // Title only - removed subtitle for desktop
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'Mzansi Marketplace',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: MediaQuery.of(context).size.width * 0.035,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Buttons - all buttons for desktop
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNotificationButton(),
            const SizedBox(width: 8),
            _buildChatButton(),
            const SizedBox(width: 8),
            if (FirebaseAuth.instance.currentUser != null) _buildMyOrdersButton(),
            const SizedBox(width: 8),
            _buildAccountMenu(),
            const SizedBox(width: 8),
            _buildCartButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth < 600 ? 16.0 : screenWidth < 900 ? 18.0 : 20.0;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    return Container(
      margin: EdgeInsets.only(right: screenWidth < 600 ? 4.0 : screenWidth < 900 ? 6.0 : 8.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(screenWidth < 600 ? 10.0 : 12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: currentUserId != null
          ? NotificationBadge(
              key: ValueKey('notification_badge_$currentUserId'), // Force rebuild when user changes
              child: IconButton(
                icon: Icon(Icons.notifications, color: AppTheme.deepTeal, size: iconSize),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationListScreen()),
                  );
                },
              ),
            )
          : IconButton(
              icon: Icon(Icons.notifications, color: AppTheme.deepTeal, size: iconSize),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
    );
  }

  Widget _buildChatButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth < 600 ? 16.0 : screenWidth < 900 ? 18.0 : 20.0;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    return Container(
      margin: EdgeInsets.only(right: screenWidth < 600 ? 4.0 : screenWidth < 900 ? 6.0 : 8.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(screenWidth < 600 ? 10.0 : 12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: currentUserId != null
          ? ChatBadge(
              key: ValueKey('chat_badge_$currentUserId'), // Force rebuild when user changes
              child: IconButton(
                icon: Icon(Icons.chat_outlined, color: AppTheme.deepTeal, size: iconSize),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatListScreen()),
                  );
                },
              ),
            )
          : IconButton(
              icon: Icon(Icons.chat_outlined, color: AppTheme.deepTeal, size: iconSize),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
    );
  }

  Widget _buildAccountMenu() {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth < 600 ? 16.0 : screenWidth < 900 ? 18.0 : 20.0;
    
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        return Container(
          margin: EdgeInsets.only(right: screenWidth < 600 ? 4.0 : screenWidth < 900 ? 6.0 : 8.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(screenWidth < 600 ? 10.0 : 12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: PopupMenuButton<String>(
            tooltip: 'Account',
            elevation: 12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: AppTheme.angel,
            offset: const Offset(0, 8),
            icon: Icon(Icons.account_circle, color: AppTheme.deepTeal, size: iconSize),
            onSelected: (value) async {
              if (value == 'login') {
                // Check if user is already authenticated but UserProvider is still loading
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null && userProvider.isLoading) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please wait while we load your account...'),
                      backgroundColor: AppTheme.deepTeal,
                    ),
                  );
                  return;
                }
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              } else if (value == 'logout') {
                try {
                  await FirebaseAuth.instance.signOut();
                  GlobalMessageListener().dispose();
                  userProvider.clearUser();
                  
                  // Clear cart when user logs out
                  final cartProvider = Provider.of<CartProvider>(context, listen: false);
                  cartProvider.clearCart();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Logged out successfully'),
                        backgroundColor: AppTheme.primaryGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to logout: $e'),
                        backgroundColor: AppTheme.primaryRed,
                      ),
                    );
                  }
                }
              } else if (value == 'profile') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditScreen()));
              } else if (value == 'register') {
                print('🔍 DEBUG: Start Selling button pressed');
                print('🔍 DEBUG: Navigating to SellerRegistrationScreen');
                try {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SellerOnboardingScreen()));
                print('🔍 DEBUG: Navigation completed successfully');
                } catch (e) {
                  print('🔍 DEBUG: Navigation error: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Navigation error: $e'),
                      backgroundColor: AppTheme.primaryRed,
                    ),
                  );
                }
              } else if (value == 'orders') {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => SellerOrdersListScreen(sellerId: user.uid),
                  ));
                }
              } else if (value == 'order_history') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen()));
              } else if (value == 'upload_product') {
                print('🔍 DEBUG: Navigating to StunningProductUpload');
                Navigator.push(context, MaterialPageRoute(builder: (_) {
                  print('🔍 DEBUG: Creating StunningProductUpload widget');
                  return const StunningProductUpload(
                    storeId: 'all',
                    storeName: 'My Store',
                  );
                }));
              } else if (value == 'driver_app') {
                Navigator.pushNamed(context, '/driver-app');
              } else if (value == 'my_products') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SellerProductManagement()));
              } else if (value == 'fcm_test') {
                // FCMTestScreen removed - test functionality no longer needed
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('FCM Test screen removed during cleanup')),
                );
              }
            },
            itemBuilder: (context) => [
              if (userProvider.isLoading) ...[
                PopupMenuItem(
                  value: 'loading',
                  enabled: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.deepTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Loading...',
                          style: TextStyle(
                            color: AppTheme.deepTeal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (userProvider.user == null) ...[
                PopupMenuItem(
                  value: 'login',
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.deepTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.login, size: 18, color: AppTheme.deepTeal),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Login',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Access your account',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.cloud,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Edit Profile
                PopupMenuItem(
                  value: 'profile',
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.deepTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.edit, size: 18, color: AppTheme.deepTeal),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Profile',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Update your information',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.cloud,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Order History (for buyers)
                if (!userProvider.isSeller)
                  PopupMenuItem(
                    value: 'order_history',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.history, size: 18, color: AppTheme.primaryGreen),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order History',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'View past orders',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.cloud,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Register as Seller (for buyers)
                if (!userProvider.isSeller)
                  PopupMenuItem(
                    value: 'register',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.store, size: 18, color: AppTheme.primaryOrange),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Become a Seller',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Start selling on Mzansi',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.cloud,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Manage Orders (for sellers)
                if (userProvider.isSeller)
                  PopupMenuItem(
                    value: 'orders',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.list_alt, size: 18, color: AppTheme.primaryGreen),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manage Orders',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Handle customer orders',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.cloud,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // My Products (for sellers)
                if (userProvider.isSeller)
                  PopupMenuItem(
                    value: 'my_products',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.deepTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.inventory, size: 18, color: AppTheme.deepTeal),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Products',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Manage your products',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.cloud,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Upload Product (for sellers)
                if (userProvider.isSeller)
                  PopupMenuItem(
                    value: 'upload_product',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.deepTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.add_shopping_cart, size: 18, color: AppTheme.deepTeal),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload Product',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Add new products to sell',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.cloud,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                

                

                
                // FCM Test removed during cleanup

                // Driver App (for registered drivers)
                if (_isDriver)
                  PopupMenuItem(
                    value: 'driver_app',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.delivery_dining, size: 18, color: AppTheme.warning),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Driver App',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Manage deliveries',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.cloud,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // Logout
                PopupMenuItem(
                  value: 'logout',
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.logout, size: 18, color: AppTheme.primaryRed),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Logout',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Sign out of your account',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.cloud,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth < 600 ? 16.0 : screenWidth < 900 ? 18.0 : 20.0;
    
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        return Stack(
          children: [
            Container(
              margin: EdgeInsets.only(right: screenWidth < 600 ? 4.0 : screenWidth < 900 ? 6.0 : 8.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(screenWidth < 600 ? 10.0 : 12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.shopping_cart, color: AppTheme.deepTeal, size: iconSize),
                onPressed: () {
                  Navigator.pushNamed(context, '/cart');
                },
              ),
            ),
            if (cart.itemCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    '${cart.itemCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMyOrdersButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth < 600 ? 16.0 : screenWidth < 900 ? 18.0 : 20.0;
    
    return Container(
      margin: EdgeInsets.only(right: screenWidth < 600 ? 4.0 : screenWidth < 900 ? 6.0 : 8.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(screenWidth < 600 ? 10.0 : 12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(Icons.history, color: AppTheme.primaryGreen, size: iconSize),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen()));
        },
      ),
    );
  }

  Widget _buildWelcomeHero() {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02), // Further reduced from 0.03
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03), // Further reduced from 0.04
        decoration: BoxDecoration(
          gradient: AppTheme.cardBackgroundGradient, // Use consistent card gradient
          borderRadius: BorderRadius.circular(16), // Reduced from 20
          boxShadow: AppTheme.complementaryElevation, // Use consistent elevation
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02), // Further reduced from 0.025
                  decoration: BoxDecoration(
                    color: AppTheme.deepTeal.withOpacity(0.1), // Use consistent color scheme
                    borderRadius: BorderRadius.circular(10), // Reduced from 12
                  ),
                  child: Icon(
                    Icons.local_mall_rounded,
                    color: AppTheme.deepTeal, // Use consistent color
                    size: MediaQuery.of(context).size.width * 0.04, // Further reduced from 0.05
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.025), // Further reduced from 0.03
                Expanded(
                  child: Text(
                    'Welcome to Mzansi',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width * 0.035, // Further reduced from 0.045
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepTeal, // Use consistent color
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.008), // Further reduced from 0.01
            Text(
              'Discover local businesses and fresh products from your community. Support local, shop smart!',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.025, // Further reduced from 0.03
                color: AppTheme.cloud, // Use consistent color
                height: 1.3, // Reduced from 1.4
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.01), // Further reduced from 0.015
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.deepTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.category_rounded,
                    color: AppTheme.deepTeal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Browse Categories',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepTeal,
                  ),
                ),
              ],
            ),
          ),
          if (_categories.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      color: AppTheme.deepTeal,
                      size: 48,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No categories available',
                      style: TextStyle(
                        color: AppTheme.deepTeal,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Categories will appear here once added',
                      style: TextStyle(
                        color: AppTheme.cloud,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75, // Reduced from 0.85 to give more height
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return _buildStunningCategoryCard(category, index);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMyPurchasesSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.shopping_bag_rounded,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'My Purchases',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen()));
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryGreen.withOpacity(0.1),
                      AppTheme.primaryGreen.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        color: AppTheme.primaryGreen,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'View Order History',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.deepTeal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track your purchases and order status',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.cloud,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: AppTheme.primaryGreen,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStunningCategoryCard(Map<String, dynamic> category, int index) {
    return GestureDetector(
      onTap: () => _goToCategory(category['name']),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.whisper,
              AppTheme.angel,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepTeal.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.deepTeal.withOpacity(0.1),
                      AppTheme.cloud.withOpacity(0.05),
                    ],
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.deepTeal.withOpacity(0.1),
                          AppTheme.cloud.withOpacity(0.05),
                        ],
                      ),
                    ),
                                            child: _buildCategoryImage(category),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      category['name'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.deepTeal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.deepTeal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Explore',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.deepTeal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryImage(Map<String, dynamic> category) {
    final categoryName = category['name'] ?? '';
    final imageUrl = category['imageUrl'];
    
    print('🔍 DEBUG: Building image for category: "$categoryName" with URL: "$imageUrl"');
    
    // If no image URL or empty, use default image
    if (imageUrl == null || imageUrl.toString().isEmpty) {
      print('🔍 DEBUG: No image URL for category: $categoryName, using default');
      return _buildDefaultCategoryImage(categoryName);
    }
    
    // Try to load the original image first
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl.toString(),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('🔍 DEBUG: Category image failed to load: $categoryName - $error');
          // Try to use default image for specific categories
          return _buildDefaultCategoryImage(categoryName);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.breeze.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
              ),
            ),
          );
        },
        // Add cache headers for better performance
        headers: const {
          'Cache-Control': 'max-age=3600',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        // Add frameBuilder for better loading experience
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            child: child,
          );
        },
        // Add retry mechanism for mobile
        gaplessPlayback: true,
      ),
    );
  }

  Widget _buildDefaultCategoryImage(String categoryName) {
    final defaultImageUrl = _getDefaultCategoryImage(categoryName);
    print('🔍 DEBUG: Loading default image for category: $categoryName - URL: $defaultImageUrl');
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        defaultImageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('🔍 DEBUG: Default image also failed for category: $categoryName - $error');
          return _buildCategoryIconFallback(categoryName);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.breeze.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
              ),
            ),
          );
        },
        headers: const {
          'Cache-Control': 'max-age=3600',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            child: child,
          );
        },
        gaplessPlayback: true,
      ),
    );
  }

  String _getDefaultCategoryImage(String categoryName) {
    final name = categoryName.toLowerCase();
    print('🔍 DEBUG: Getting default image for category: "$categoryName" (normalized: "$name")');
    
    // Return placeholder images for common categories
    if (name.contains('food') || name.contains('restaurant') || name.contains('cafe')) {
      return 'https://images.unsplash.com/photo-1504674900240-9f883e8a6c3d?w=400&h=300&fit=crop';
    } else if (name.contains('clothes') || name.contains('fashion') || name.contains('apparel') || name.contains('clothing')) {
      print('🔍 DEBUG: Using clothing image for category: $categoryName');
      return 'https://picsum.photos/400/300?random=1';
    } else if (name.contains('electronics') || name.contains('tech') || name.contains('gadgets') || name.contains('electronic')) {
      print('🔍 DEBUG: Using electronics image for category: $categoryName');
      return 'https://picsum.photos/400/300?random=2';
    } else if (name.contains('home') || name.contains('furniture') || name.contains('decor')) {
      return 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=400&h=300&fit=crop';
    } else if (name.contains('beauty') || name.contains('cosmetics') || name.contains('skincare')) {
      return 'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=400&h=300&fit=crop';
    } else if (name.contains('sports') || name.contains('fitness') || name.contains('athletic')) {
      return 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop';
    } else if (name.contains('books') || name.contains('education') || name.contains('learning')) {
      return 'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=400&h=300&fit=crop';
    } else if (name.contains('automotive') || name.contains('car') || name.contains('vehicle')) {
      return 'https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?w=400&h=300&fit=crop';
    } else if (name.contains('health') || name.contains('medical') || name.contains('pharmacy')) {
      return 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1f?w=400&h=300&fit=crop';
    } else {
      print('🔍 DEBUG: Using generic image for category: $categoryName');
      // Generic category image
      return 'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=400&h=300&fit=crop';
    }
  }

  Widget _buildCategoryIconFallback(String categoryName) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.deepTeal.withOpacity(0.1),
            AppTheme.cloud.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: AppTheme.deepTeal.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          _getCategoryIcon(categoryName),
          color: AppTheme.deepTeal,
          size: 32,
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('food') || name.contains('restaurant')) {
      return Icons.restaurant;
    } else if (name.contains('clothes') || name.contains('fashion')) {
      return Icons.checkroom;
    } else if (name.contains('electronics')) {
      return Icons.devices;
    } else if (name.contains('home') || name.contains('furniture')) {
      return Icons.home;
    } else if (name.contains('beauty') || name.contains('cosmetics')) {
      return Icons.face;
    } else if (name.contains('sports') || name.contains('fitness')) {
      return Icons.sports_soccer;
    } else if (name.contains('books') || name.contains('education')) {
      return Icons.book;
    } else {
      return Icons.category;
    }
  }

  Widget _buildQuickActionCard(String title, IconData icon, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 