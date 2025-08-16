import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/safe_network_image.dart';
import '../widgets/home_navigation_button.dart';
import '../constants/app_constants.dart';
import '../providers/cart_provider.dart';
import 'ChatScreen.dart';

class StunningProductDetail extends StatefulWidget {
  final Map<String, dynamic> product;

  const StunningProductDetail({
    super.key,
    required this.product,
  });

  @override
  State<StunningProductDetail> createState() => _StunningProductDetailState();
}

class _StunningProductDetailState extends State<StunningProductDetail>
    with TickerProviderStateMixin {
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _imageController;
  
  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _imageAnimation;
  
  // State
  bool isFavorite = false;
  int quantity = 1;
  String selectedImageUrl = '';
  bool showFullDescription = false;
  
  // Controllers
  final ScrollController _scrollController = ScrollController();
  final PageController _imagePageController = PageController();

  @override
  void initState() {
    super.initState();
    selectedImageUrl = widget.product['imageUrl'] ?? '';
    _initializeAnimations();
    _checkIfFavorite();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _imageController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _imageAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _imageController, curve: Curves.easeOutBack),
    );
    
    // Start animations with staggered timing
    _imageController.forward();
    Future.delayed(const Duration(milliseconds: 200), () => _fadeController.forward());
    Future.delayed(const Duration(milliseconds: 400), () => _slideController.forward());
    Future.delayed(const Duration(milliseconds: 600), () => _scaleController.forward());
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _imageController.dispose();
    _scrollController.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  Future<void> _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(widget.product['id'])
          .get();
      
      if (mounted) {
        setState(() {
          isFavorite = doc.exists;
        });
      }
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please login to add favorites', AppTheme.warning);
      return;
    }

    try {
      final favDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(widget.product['id']);

      if (isFavorite) {
        await favDocRef.delete();
        _showSnackBar('Removed from favorites', AppTheme.error);
      } else {
        await favDocRef.set({
          'name': widget.product['name'],
          'imageUrl': widget.product['imageUrl'],
          'price': widget.product['price'],
          'timestamp': FieldValue.serverTimestamp(),
        });
        _showSnackBar('Added to favorites', AppTheme.success);
      }

      setState(() => isFavorite = !isFavorite);
      
      // Animate favorite button
      _scaleController.reset();
      _scaleController.forward();
      
    } catch (e) {
      _showSnackBar('Failed to update favorites', AppTheme.error);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  int _getProductStock() {
    final stock = widget.product['stock'];
    final productQuantity = widget.product['quantity'];
    
    if (stock != null) {
      return int.tryParse(stock.toString()) ?? 0;
    } else if (productQuantity != null) {
      return int.tryParse(productQuantity.toString()) ?? 0;
    }
    
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 768;
    final stock = _getProductStock();
    final isOutOfStock = stock <= 0;

    return Scaffold(
      backgroundColor: AppTheme.angel,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(isMobile, screenHeight),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildProductInfo(isMobile, isOutOfStock, stock),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isMobile, isOutOfStock),
    );
  }

  Widget _buildSliverAppBar(bool isMobile, double screenHeight) {
    return SliverAppBar(
      expandedHeight: isMobile ? screenHeight * 0.4 : screenHeight * 0.5,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.deepTeal,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
              actions: [
          // Cart with count
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              final itemCount = cartProvider.itemCount;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.shopping_cart,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/cart');
                      },
                    ),
                    if (itemCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            itemCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _toggleFavorite,
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : Colors.white,
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Hero(
          tag: 'product-${widget.product['id']}',
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.1),
                  Colors.black.withOpacity(0.3),
                ],
              ),
            ),
            child: ScaleTransition(
              scale: _imageAnimation,
                          child: SafeNetworkImage(
              imageUrl: selectedImageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductInfo(bool isMobile, bool isOutOfStock, int stock) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 20 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Header
            _buildProductHeader(isMobile, isOutOfStock, stock),
            
            const SizedBox(height: 24),
            
            // Price Section
            _buildPriceSection(isMobile),
            
            const SizedBox(height: 24),
            
            // Description
            _buildDescriptionSection(isMobile),
            
            const SizedBox(height: 24),
            
            // Product Details
            _buildProductDetails(isMobile),
            
            const SizedBox(height: 24),
            
            // Quantity Selector
            if (!isOutOfStock) _buildQuantitySelector(isMobile),
            
            const SizedBox(height: 100), // Space for bottom bar
          ],
        ),
      ),
    );
  }

  Widget _buildProductHeader(bool isMobile, bool isOutOfStock, int stock) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product Name
        Text(
          widget.product['name'] ?? 'Unnamed Product',
          style: AppTheme.displaySmall.copyWith(
            fontSize: isMobile ? 22 : 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Category and Stock Row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.deepTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.product['category'] ?? 'Unknown',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.deepTeal,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            _buildConditionBadge(),
            
            const SizedBox(width: 12),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isOutOfStock 
                    ? AppTheme.error.withOpacity(0.1)
                    : AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOutOfStock ? Icons.close : Icons.check,
                    size: 16,
                    color: isOutOfStock ? AppTheme.error : AppTheme.success,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOutOfStock ? 'Out of Stock' : 'In Stock ($stock)',
                    style: TextStyle(
                      color: isOutOfStock ? AppTheme.error : AppTheme.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConditionBadge() {
    final condition = widget.product['condition'] as String?;
    if (condition == null || condition.isEmpty) {
      return const SizedBox.shrink();
    }

    Color badgeColor;
    String badgeText;

    switch (condition.toLowerCase()) {
      case 'new':
        badgeColor = AppTheme.primaryGreen;
        badgeText = 'New';
        break;
      case 'second hand':
        badgeColor = AppTheme.warning;
        badgeText = 'Used';
        break;
      case 'refurbished':
        badgeColor = AppTheme.deepTeal;
        badgeText = 'Refurbished';
        break;
      default:
        badgeColor = AppTheme.cloud;
        badgeText = condition;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPriceSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.cardGradient,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.receipt,
            color: AppTheme.deepTeal,
            size: isMobile ? 28 : 32,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Price',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.cloud,
                ),
              ),
              Text(
                'R${(widget.product['price'] ?? 0.0).toStringAsFixed(2)}',
                style: AppTheme.displaySmall.copyWith(
                  fontSize: isMobile ? 24 : 28,
                  color: AppTheme.deepTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(bool isMobile) {
    final description = widget.product['description']?.toString() ?? '';
    if (description.isEmpty) return const SizedBox.shrink();

    final shouldShowMoreButton = description.length > 150;
    final displayText = shouldShowMoreButton && !showFullDescription
        ? '${description.substring(0, 150)}...'
        : description;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: AppTheme.whisper.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: AppTheme.deepTeal,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Description',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Text(
            displayText,
            style: AppTheme.bodyLarge.copyWith(
              height: 1.5,
              color: AppTheme.mediumGrey,
            ),
          ),
          
          if (shouldShowMoreButton) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => showFullDescription = !showFullDescription),
              child: Text(
                showFullDescription ? 'Show Less' : 'Show More',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.deepTeal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductDetails(bool isMobile) {
    final details = [
      {'label': 'Product ID', 'value': widget.product['id'] ?? 'N/A'},
      {'label': 'Category', 'value': widget.product['category'] ?? 'Unknown'},
      {'label': 'Subcategory', 'value': widget.product['subcategory'] ?? 'Unknown'},
      {'label': 'Added', 'value': _formatTimestamp(widget.product['timestamp'])},
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cloud.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.deepTeal,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Product Details',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          ...details.map((detail) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(
                  '${detail['label']}: ',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.cloud,
                  ),
                ),
                Expanded(
                  child: Text(
                    detail['value']!,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.deepTeal,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: AppTheme.whisper.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                color: AppTheme.deepTeal,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Quantity',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.deepTeal,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: quantity > 1 ? () => setState(() => quantity--) : null,
                  icon: const Icon(Icons.remove, color: Colors.white),
                  iconSize: 20,
                ),
              ),
              
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cloud),
                ),
                child: Text(
                  quantity.toString(),
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.deepTeal,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: quantity < _getProductStock() 
                      ? () => setState(() => quantity++) 
                      : null,
                  icon: const Icon(Icons.add, color: Colors.white),
                  iconSize: 20,
                ),
              ),
              
              const Spacer(),
              
              Text(
                'Total: R${((widget.product['price'] ?? 0.0) * quantity).toStringAsFixed(2)}',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepTeal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isMobile, bool isOutOfStock) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Purchase Buttons Row
            Row(
              children: [
                if (!isOutOfStock) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async => await _contactSeller(),
                      icon: const Icon(Icons.message),
                      label: const Text('Contact Seller'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.deepTeal,
                        side: BorderSide(color: AppTheme.deepTeal, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _buyNow(),
                      icon: const Icon(Icons.flash_on),
                      label: const Text('Buy Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.deepTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.error),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: AppTheme.error),
                          const SizedBox(width: 8),
                          Text(
                            'Out of Stock',
                            style: TextStyle(
                              color: AppTheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }



  void _buyNow() {
    // Add current item to cart first
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    // Check if user is authenticated
    if (!cartProvider.isAuthenticated) {
      _showSnackBar('Please login to proceed with purchase', AppTheme.warning);
      return;
    }
    
    // Check stock availability
    final stock = _getProductStock();
    if (stock <= 0) {
      _showSnackBar('This product is out of stock!', AppTheme.error);
      return;
    }
    
    // Check if selected quantity is available
    if (quantity > stock) {
      _showSnackBar('Selected quantity exceeds available stock!', AppTheme.error);
      return;
    }
    
    // Add to cart with selected quantity
    cartProvider.addItem(
      widget.product['id'],
      widget.product['name'] ?? 'Unknown Product',
      (widget.product['price'] ?? 0.0).toDouble(),
      widget.product['imageUrl'] ?? '',
      widget.product['ownerId'] ?? widget.product['sellerId'] ?? '',
      widget.product['storeName'] ?? 'Unknown Store',
      widget.product['storeCategory'] ?? 'Other',
      quantity: quantity, // Include the selected quantity
      availableStock: stock,
    );
    
    // Show success message
    _showSnackBar('Product added to cart!', AppTheme.primaryGreen);
    
    // Navigate to cart
    Navigator.pushNamed(context, '/cart');
  }

  Future<void> _contactSeller() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showSnackBar('Please login to contact the seller', AppTheme.warning);
      return;
    }

    final sellerId = widget.product['ownerId'] ?? widget.product['storeId'];
    if (sellerId == null) {
      _showSnackBar('Unable to contact seller - seller information not available', AppTheme.error);
      return;
    }

    // Show dialog to get user's name and number
    final result = await _showContactInfoDialog();
    if (result == null) return; // User cancelled

    final userName = result['name'] as String;
    final userNumber = result['number'] as String;

    try {
      // Check if chat already exists
      final query = await FirebaseFirestore.instance
          .collection('chats')
          .where('buyerId', isEqualTo: currentUser.uid)
          .where('sellerId', isEqualTo: sellerId)
          .where('productId', isEqualTo: widget.product['id'])
          .limit(1)
          .get();

      String chatId;
      if (query.docs.isNotEmpty) {
        chatId = query.docs.first.id;
        // Update existing chat with new contact info
        await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
          'buyerName': userName,
          'buyerNumber': userNumber,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new chat
        final newChat = await FirebaseFirestore.instance.collection('chats').add({
          'buyerId': currentUser.uid,
          'sellerId': sellerId,
          'productId': widget.product['id'],
          'productName': widget.product['name'] ?? 'Product',
          'productImage': widget.product['imageUrl'],
          'productPrice': widget.product['price'],
          'buyerName': userName,
          'buyerNumber': userNumber,
          'lastMessage': '',
          'timestamp': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
          'participants': [currentUser.uid, sellerId],
          'unreadCount': 0,
        });
        chatId = newChat.id;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              otherUserId: sellerId,
              otherUserName: widget.product['sellerName'] ?? 'Seller',
            ),
          ),
        );
      }
    } catch (e) {
      _showSnackBar('Failed to start chat: $e', AppTheme.error);
    }
  }

  Future<Map<String, String>?> _showContactInfoDialog() async {
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    
    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Get keyboard height and screen dimensions
        final mediaQuery = MediaQuery.of(context);
        final keyboardHeight = mediaQuery.viewInsets.bottom;
        final screenHeight = mediaQuery.size.height;
        final screenWidth = mediaQuery.size.width;
        
        // Calculate dynamic constraints based on keyboard
        final maxHeight = keyboardHeight > 0 
            ? screenHeight - keyboardHeight - 100 // Leave space for padding
            : screenHeight * 0.8;
        
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              maxWidth: screenWidth * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fixed Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.deepTeal,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.contact_phone, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Contact Seller',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Scrollable Content Area
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Please provide your contact information so the seller can reach you:',
                          style: TextStyle(
                            color: AppTheme.darkGrey,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        
                        // Name Field
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Your Name *',
                            hintText: 'Enter your full name',
                            prefixIcon: Icon(Icons.person, color: AppTheme.deepTeal),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Phone Number Field
                        TextFormField(
                          controller: numberController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number *',
                            hintText: 'Enter your phone number',
                            prefixIcon: Icon(Icons.phone, color: AppTheme.deepTeal),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your phone number';
                            }
                            return null;
                          },
                        ),
                        
                        // Add extra padding at bottom for keyboard
                        if (keyboardHeight > 0) const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                
                // Fixed Action Buttons
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppTheme.mediumGrey,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final name = nameController.text.trim();
                            final number = numberController.text.trim();
                            
                            if (name.isEmpty || number.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please fill in both name and phone number'),
                                  backgroundColor: AppTheme.primaryRed,
                                ),
                              );
                              return;
                            }
                            
                            Navigator.of(context).pop({
                              'name': name,
                              'number': number,
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.deepTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Start Chat',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year}';
      }
      return timestamp.toString();
    } catch (e) {
      return 'Unknown';
    }
  }
} 