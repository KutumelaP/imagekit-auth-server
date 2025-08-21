import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/product_detail_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../widgets/optimized_image.dart';
import '../services/performance_service.dart';
import '../constants/app_constants.dart';
import '../providers/cart_provider.dart';
import '../widgets/enhanced_filter_widget.dart';

const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY'; // TODO: Replace with your real key

Future<int> _getRealisticDeliveryTime(double storeLat, double storeLng, double userLat, double userLng) async {
  if (googleMapsApiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
    // Fallback: 5 min per km
    final distance = Geolocator.distanceBetween(userLat, userLng, storeLat, storeLng) / 1000;
    return (distance * 5).round();
  }
  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/distancematrix/json?origins=$storeLat,$storeLng&destinations=$userLat,$userLng&mode=driving&key=$googleMapsApiKey',
  );
  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final duration = data['rows'][0]['elements'][0]['duration']['value']; // seconds
    return (duration / 60).round();
  } else {
    // Fallback: 5 min per km
    final distance = Geolocator.distanceBetween(userLat, userLng, storeLat, storeLng) / 1000;
    return (distance * 5).round();
  }
}

class ProductBrowsingScreen extends StatefulWidget {
  final String? categoryFilter;
  final String? storeId;

  const ProductBrowsingScreen({Key? key, this.categoryFilter, this.storeId})
      : super(key: key);

  @override
  State<ProductBrowsingScreen> createState() => _ProductBrowsingScreenState();
}

class _ProductBrowsingScreenState extends State<ProductBrowsingScreen> 
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  User? user;
  String? userRole;
  Set<String> _favoriteIds = {};
  String? _storeName;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Advanced filter state variables
  String? _filterSubcategory;
  String _searchQuery = '';
  double _minPrice = 0.0;
  double _maxPrice = 50000.0; // Increased to accommodate higher-priced electronics
  bool _inStockOnly = false;
  String _sortBy = 'name';

  QuerySnapshot? _latestSnapshot;
  DocumentSnapshot? _lastProductDoc;
  List<DocumentSnapshot> _allLoadedProducts = [];
  bool _hasMoreProducts = true;
  bool _isLoadingMore = false;
  bool _isGridView = false;

  final PerformanceService _performanceService = PerformanceService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    
    user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      fetchUserRole();
      _fetchFavoriteIds();
    }
    
    // Load store name if storeId is provided
    if (widget.storeId != null) {
      _loadStoreName();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreName() async {
    if (widget.storeId == null) return;
    
    try {
      final storeDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.storeId)
          .get();
      
      if (storeDoc.exists) {
        final data = storeDoc.data()!;
        setState(() {
          _storeName = data['storeName'] ?? data['name'] ?? 'Store';
        });
      }
    } catch (e) {
      print('Error loading store name: $e');
    }
  }

  Future<void> fetchUserRole() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    setState(() {
      userRole = doc.exists ? (doc.data()?['role'] ?? 'buyer') : 'buyer';
    });
  }

  Future<void> _fetchFavoriteIds() async {
    try {
      // Check if user is authenticated
      if (user == null) {
        print('User not authenticated, skipping favorites fetch');
        return;
      }
      
      final favDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('favorites')
          .get()
          .timeout(const Duration(seconds: 3));
      final ids = <String>{};
      for (final doc in favDoc.docs) {
        ids.add(doc.id);
      }
      if (mounted) {
        setState(() {
          _favoriteIds = ids;
        });
      }
    } catch (e) {
      print('Error fetching favorite IDs: $e');
      // Continue without favorites
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: AppTheme.whisper,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                // Make filter widget more compact on small screens
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: EnhancedFilterWidget(
                    selectedCategory: widget.categoryFilter,
                    selectedSubcategory: _filterSubcategory,
                    onCategoryChanged: (category) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductBrowsingScreen(
                            categoryFilter: category,
                            storeId: widget.storeId,
                          ),
                        ),
                      );
                    },
                    onSubcategoryChanged: (subcategory) {
                      setState(() {
                        _filterSubcategory = subcategory;
                      });
                    },
                    onClearFilters: _clearFilters,
                    onPriceRangeChanged: _onPriceRangeChanged,
                    onStockFilterChanged: _onStockFilterChanged,
                    onSortByChanged: _onSortByChanged,
                    onSearchChanged: _onSearchChanged,
                    products: _allLoadedProducts.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return {
                        'id': doc.id,
                        ...data,
                      };
                    }).toList(),
                    minPrice: _minPrice,
                    maxPrice: _maxPrice,
                    inStockOnly: _inStockOnly,
                    sortBy: _sortBy,
                    searchQuery: _searchQuery,
                  ),
                ),
                Expanded(
                  child: _buildProductsList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppTheme.deepTeal,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _storeName ?? (widget.categoryFilter ?? 'Products'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          if (widget.storeId != null && _storeName != null)
            Text(
              'Store Products',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
        ],
      ),
        actions: [
          // Cart icon
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
        // Grid/List toggle
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list : Icons.grid_view,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.heroSectionGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.complementaryElevation,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.angel.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.storeId != null ? Icons.store : Icons.category,
              color: AppTheme.angel,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                Text(
                  widget.storeId != null 
                      ? 'Browse Store Products'
                      : 'Browse ${widget.categoryFilter ?? 'All'} Products',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.angel,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Discover amazing local products from your community',
                  style: TextStyle(
                    color: AppTheme.angel.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    // Only show filters if we have a storeId (to prevent mixing stores)
    if (widget.storeId == null) {
      return const SizedBox.shrink();
    }
    
    // Get actual categories from loaded products
    final Set<String> actualCategories = <String>{};
    final Set<String> actualSubcategories = <String>{};
    
    for (final doc in _allLoadedProducts) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null) {
        final category = data['category'] as String?;
        final subcategory = data['subcategory'] as String?;
        
        if (category != null && category.isNotEmpty) {
          actualCategories.add(category);
        }
        if (subcategory != null && subcategory.isNotEmpty) {
          actualSubcategories.add(subcategory);
        }
      }
    }
    
    // Convert to sorted lists
    final availableCategories = actualCategories.toList()..sort();
    List<String> availableSubcategories = <String>[];
    if (widget.categoryFilter != null) {
      availableSubcategories = actualSubcategories
          .where((sub) => getSubcategoriesForCategory(widget.categoryFilter!).contains(sub))
          .toList()..sort();
    }
    
    print('🔍 DEBUG: Building filter chips with actual subcategories: $availableSubcategories');
    print('🔍 DEBUG: Building filter chips with actual categories: $availableCategories');
    
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              'All Categories',
              widget.categoryFilter == null,
              () {
                // Reset to show all categories
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductBrowsingScreen(
                      categoryFilter: null,
                      storeId: widget.storeId,
                    ),
                  ),
                );
              },
            ),
            // Add category filter chips
              ...availableCategories.map((category) =>
                _buildFilterChip(
                  category,
                  widget.categoryFilter == category,
                () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductBrowsingScreen(
                          categoryFilter: category,
                          storeId: widget.storeId,
                        ),
                      ),
                    );
                },
                ),
              ),
            const SizedBox(width: 8),
            // Add subcategory filter chips if we have a category selected
            if (widget.categoryFilter != null && availableSubcategories.isNotEmpty) ...[
              Container(
                height: 30,
                width: 1,
                color: AppTheme.cloud,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              _buildFilterChip(
                'All ${widget.categoryFilter}',
                _filterSubcategory == null,
                () => setState(() => _filterSubcategory = null),
              ),
              ...availableSubcategories.map((value) =>
                _buildFilterChip(
                  value,
                  _filterSubcategory == value,
                  () => setState(() => _filterSubcategory = value),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.angel : AppTheme.deepTeal,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedColor: AppTheme.deepTeal,
        backgroundColor: AppTheme.angel,
        checkmarkColor: AppTheme.angel,
        side: BorderSide(
          color: isSelected ? AppTheme.deepTeal : AppTheme.cloud,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _buildProductsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getProductsQuery(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          print('❌ ERROR: Stream error: ${snapshot.error}');
          return Center(
            child: Text('Error loading products: ${snapshot.error}'),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }
        
        final docs = snapshot.data!.docs;
        
        // Update the loaded products list
        _allLoadedProducts = docs;
        
        // Apply client-side filters
        final filteredDocs = _applyFilters(docs);
        
        if (filteredDocs.isEmpty) {
          return _buildEmptyState();
        }
        
        return _buildGridView(filteredDocs);
      },
    );
  }

  Widget _buildGridView(List<DocumentSnapshot> docs) {
    // Calculate responsive grid settings
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 2 : 3;
    final childAspectRatio = screenWidth < 600 ? 0.75 : 0.8;
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      addSemanticIndexes: false,
      cacheExtent: 1200,
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        
        return RepaintBoundary(
          child: BeautifulProductCard(
            productId: doc.id,
            data: data,
            isBuyer: userRole == 'buyer',
            favoriteIds: _favoriteIds,
            onFavoriteToggle: _toggleFavorite,
            isGridView: true,
          ),
        );
      },
    );
  }

  Widget _buildListView(List<DocumentSnapshot> docs) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      addSemanticIndexes: false,
      cacheExtent: 1000,
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        
        return RepaintBoundary(
          child: BeautifulProductCard(
            productId: doc.id,
            data: data,
            isBuyer: userRole == 'buyer',
            favoriteIds: _favoriteIds,
            onFavoriteToggle: _toggleFavorite,
            isGridView: false,
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    // Calculate responsive grid settings
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 2 : 3;
    final childAspectRatio = screenWidth < 600 ? 0.75 : 0.8;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: 6,
              itemBuilder: (context, index) => _buildLoadingCard(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppTheme.primaryRed,
          ),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepTeal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unable to load products. This might be due to:\n• No internet connection\n• Database connection issues\n• Missing products in database',
            style: TextStyle(
              color: AppTheme.cloud,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.deepTeal,
              foregroundColor: AppTheme.angel,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              // Add some sample products for testing
              _addSampleProducts();
            },
            child: const Text('Add Sample Products (Debug)'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              // Fix existing product image
              _fixExistingProductImage();
            },
            child: const Text('Fix Existing Product Image (Debug)'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: AppTheme.cloud,
          ),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepTeal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.storeId != null 
                ? 'This store hasn\'t added any products yet'
                : 'Try adjusting your filters',
            style: TextStyle(
              color: AppTheme.cloud,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getProductsQuery() {
    var q = FirebaseFirestore.instance
        .collection('products')
        .limit(12);
    
    if (widget.storeId != null && widget.storeId != 'all') {
      q = q.where('ownerId', isEqualTo: widget.storeId);
    }
    
    if (widget.categoryFilter != null && widget.categoryFilter!.isNotEmpty) {
      q = q.where('category', isEqualTo: widget.categoryFilter);
    }
    
    if (_filterSubcategory != null && _filterSubcategory!.isNotEmpty) {
      q = q.where('subcategory', isEqualTo: _filterSubcategory);
    }
    
    return q.snapshots();
  }

  List<DocumentSnapshot> _applyFilters(List<DocumentSnapshot> docs) {
    final filteredDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final productName = data['name']?.toString().toLowerCase() ?? '';
        if (!productName.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }
      
      // Apply category filter
      if (widget.categoryFilter != null && widget.categoryFilter!.isNotEmpty) {
        final productCategory = (data['category'] as String?) ?? '';
        if (productCategory.toLowerCase() != widget.categoryFilter!.toLowerCase()) {
          return false;
        }
      }
      
      // Apply subcategory filter
      if (_filterSubcategory != null && data['subcategory'] != _filterSubcategory) {
        return false;
      }
      
      // Apply advanced filters
      final price = (data['price'] as num?)?.toDouble() ?? 0.0;
      if (price < _minPrice || price > _maxPrice) {
        return false;
      }
      
      if (_inStockOnly) {
        final quantity = data['quantity'] as int? ?? 0;
        final stock = data['stock'] as int? ?? quantity;
        if (stock <= 0) {
          return false;
        }
      }
      
      return true;
    }).toList();
    
    // Sort the filtered results
    return _sortProducts(filteredDocs);
  }

  List<DocumentSnapshot> _sortProducts(List<DocumentSnapshot> docs) {
    final sortedDocs = List<DocumentSnapshot>.from(docs);
    
    sortedDocs.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;
      
      switch (_sortBy) {
        case 'name':
          final nameA = (dataA['name'] as String?) ?? '';
          final nameB = (dataB['name'] as String?) ?? '';
          return nameA.compareTo(nameB);
          
        case 'name_desc':
          final nameA = (dataA['name'] as String?) ?? '';
          final nameB = (dataB['name'] as String?) ?? '';
          return nameB.compareTo(nameA);
          
        case 'price':
          final priceA = (dataA['price'] as num?)?.toDouble() ?? 0.0;
          final priceB = (dataB['price'] as num?)?.toDouble() ?? 0.0;
          return priceA.compareTo(priceB);
          
        case 'price_desc':
          final priceA = (dataA['price'] as num?)?.toDouble() ?? 0.0;
          final priceB = (dataB['price'] as num?)?.toDouble() ?? 0.0;
          return priceB.compareTo(priceA);
          
        case 'newest':
          final timestampA = dataA['timestamp'] as Timestamp?;
          final timestampB = dataB['timestamp'] as Timestamp?;
          if (timestampA == null && timestampB == null) return 0;
          if (timestampA == null) return 1;
          if (timestampB == null) return -1;
          return timestampB.compareTo(timestampA);
          
        case 'oldest':
          final timestampA = dataA['timestamp'] as Timestamp?;
          final timestampB = dataB['timestamp'] as Timestamp?;
          if (timestampA == null && timestampB == null) return 0;
          if (timestampA == null) return 1;
          if (timestampB == null) return -1;
          return timestampA.compareTo(timestampB);
          
        default:
          return 0;
      }
    });
    
    return sortedDocs;
  }

  Future<List<DocumentSnapshot>> _filterOutPausedStoreProducts(List<DocumentSnapshot> docs) async {
    print('🔍 DEBUG: Starting to filter ${docs.length} products for paused stores');
    
    // TEMPORARY: Skip paused store filtering for debugging
    print('🔍 DEBUG: TEMPORARILY SKIPPING PAUSED STORE FILTERING - returning all ${docs.length} products');
    return docs;
    
    List<DocumentSnapshot> result = [];
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ownerId = data['ownerId'] ?? data['sellerId'];
      print('🔍 DEBUG: Checking product ${doc.id} with ownerId: $ownerId');
      
      if (ownerId == null || ownerId.toString().isEmpty) {
        print('🔍 DEBUG: Skipping product ${doc.id} - no ownerId');
        continue;
      }
      
      // Use cached seller data if available
      final sellerCacheKey = 'seller_$ownerId';
      Map<String, dynamic>? sellerData = _performanceService.getCachedData(sellerCacheKey);
      
      if (sellerData == null) {
        print('🔍 DEBUG: Fetching seller data for $ownerId');
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerId)
            .get();
        if (userDoc.exists) {
          sellerData = userDoc.data() as Map<String, dynamic>;
          _performanceService.cacheData(sellerCacheKey, sellerData);
          print('🔍 DEBUG: Seller data for $ownerId - paused: ${sellerData['paused']}');
        } else {
          print('🔍 DEBUG: No seller document found for $ownerId');
        }
      } else {
        print('🔍 DEBUG: Using cached seller data for $ownerId - paused: ${sellerData['paused']}');
      }
      
      if (sellerData?['paused'] != true) {
        print('🔍 DEBUG: Adding product ${doc.id} to results');
      result.add(doc);
      } else {
        print('🔍 DEBUG: Skipping product ${doc.id} - store is paused');
      }
    }
    print('🔍 DEBUG: Filtered products: ${result.length} out of ${docs.length}');
    return result;
  }

  Set<String> _getUniqueValues(String field) {
    final values = <String>{};
    for (final doc in _allLoadedProducts) {
      final data = doc.data() as Map<String, dynamic>;
      final value = data[field];
      if (value != null && value.toString().isNotEmpty) {
        values.add(value.toString());
      }
    }
    return values;
  }

  Set<String> _getAvailableSubcategories() {
    final values = <String>{};
    
    // Get subcategories from current snapshot if available
    if (_latestSnapshot != null) {
      for (final doc in _latestSnapshot!.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final subcategory = data['subcategory'];
        if (subcategory != null && subcategory.toString().isNotEmpty) {
          values.add(subcategory.toString());
        }
      }
    }
    
    // Also check from all loaded products for consistency
    for (final doc in _allLoadedProducts) {
      final data = doc.data() as Map<String, dynamic>;
      final subcategory = data['subcategory'];
      if (subcategory != null && subcategory.toString().isNotEmpty) {
        values.add(subcategory.toString());
      }
    }
    
    print('🔍 DEBUG: Available subcategories: $values');
    return values;
  }

  Set<String> _getAvailableCategories() {
    final values = <String>{};
    
    // Get categories from current snapshot if available
    if (_latestSnapshot != null) {
      for (final doc in _latestSnapshot!.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final category = data['category'];
        if (category != null && category.toString().isNotEmpty) {
          values.add(category.toString());
        }
      }
    }
    
    // Also check from all loaded products for consistency
    for (final doc in _allLoadedProducts) {
      final data = doc.data() as Map<String, dynamic>;
      final category = data['category'];
      if (category != null && category.toString().isNotEmpty) {
        values.add(category.toString());
      }
    }
    
    // Only add common categories if we have no actual categories (for empty stores)
    if (values.isEmpty) {
              values.addAll(['Food', 'Drinks', 'Bakery', 'Electronics', 'Clothing', 'Other']);
    }
    
    print('🔍 DEBUG: Available categories: $values');
    return values;
  }

  // Enhanced category-subcategory mapping for your app
  static const Map<String, List<String>> categorySubcategoryMap = {
    'Food': [
      'Baked Goods',      // Bread, Cakes, Donuts, Muffins
      'Fresh Produce',     // Fruits, Vegetables
      'Dairy & Eggs',      // Milk, Cheese, Yogurt, Eggs
      'Meat & Poultry',    // Chicken, Beef, Pork, Fish
      'Pantry Items',      // Rice, Pasta, Flour, Sugar
      'Snacks',            // Chips, Nuts, Crackers
      'Beverages',         // Coffee, Tea, Juices, Water
      'Frozen Foods',      // Ice Cream, Frozen Vegetables
      'Organic Foods',     // Organic Products
      'Candy & Sweets',    // Chocolate, Candy
      'Condiments',        // Sauces, Ketchup, Mustard
      'Other Food Items'
    ],
    'Electronics': [
      'Phones',            // iPhone, Samsung, etc.
      'Laptops',           // MacBook, Dell, HP
      'Tablets',           // iPad, Android tablets
      'Computers',         // Desktop PCs, Monitors
      'Cameras',           // DSLR, Point & Shoot
      'Headphones',        // AirPods, Sony, etc.
      'Speakers',          // Bluetooth speakers
      'Gaming',            // Consoles, Games
      'Smart Home',        // Smart bulbs, Alexa
      'Wearables',         // Smartwatches, Fitbit
      'Accessories',       // Chargers, Cases, Cables
      'Other Electronics'
    ],
    'Clothing': [
      'T-Shirts',          // Cotton shirts, Graphic tees
      'Jeans',             // Denim pants
      'Dresses',           // Summer dresses, Formal
      'Shirts',            // Button-down shirts
      'Pants',             // Khakis, Slacks
      'Shorts',            // Summer shorts
      'Skirts',            // Mini skirts, Maxi skirts
      'Jackets',           // Denim jackets, Blazers
      'Sweaters',          // Wool sweaters, Cardigans
      'Hoodies',           // Pullover hoodies
      'Shoes',             // Sneakers, Boots, Sandals
      'Hats',              // Baseball caps, Beanies
      'Accessories',       // Belts, Scarves, Jewelry
      'Underwear',         // Bras, Underwear
      'Socks',             // Athletic socks, Dress socks
      'Other Clothing'
    ],
    'Other': [
      'Handmade',          // Crafts, DIY items
      'Vintage',           // Antique items
      'Collectibles',      // Trading cards, Figurines
      'Books',             // Fiction, Non-fiction
      'Toys',              // Children's toys
      'Home & Garden',     // Plants, Tools
      'Sports',            // Equipment, Jerseys
      'Beauty',            // Makeup, Skincare
      'Health',            // Vitamins, Supplements
      'Automotive',        // Car parts, Accessories
      'Tools',             // Hardware, DIY tools
      'Miscellaneous'      // Everything else
    ]
  };

  // Get all available categories
  static List<String> get allCategories => categorySubcategoryMap.keys.toList();

  // Get subcategories for a specific category
  static List<String> getSubcategoriesForCategory(String category) {
    return categorySubcategoryMap[category] ?? [];
  }

  // Get all subcategories across all categories
  static List<String> get allSubcategories {
    final allSubs = <String>{};
    for (final subs in categorySubcategoryMap.values) {
      allSubs.addAll(subs);
    }
    return allSubs.toList()..sort();
  }

  // Enhanced helper method to categorize products by name
  String _categorizeProductByName(String productName) {
    final name = productName.toLowerCase();
    
    // Food categories
    if (name.contains('bread') || name.contains('donut') || name.contains('muffin') || 
        name.contains('cake') || name.contains('cookie') || name.contains('pie') ||
        name.contains('croissant') || name.contains('pastry') || name.contains('bun') ||
        name.contains('milk') || name.contains('cheese') || name.contains('apple') ||
        name.contains('chicken') || name.contains('rice') || name.contains('juice') ||
        name.contains('coffee') || name.contains('tea') || name.contains('water') ||
        name.contains('meat') || name.contains('fish') || name.contains('egg') ||
        name.contains('fruit') || name.contains('vegetable') || name.contains('snack') ||
        name.contains('chocolate') || name.contains('candy') || name.contains('sweet')) {
      return 'Food';
    }
    
    // Electronics categories
    if (name.contains('phone') || name.contains('laptop') || name.contains('computer') ||
        name.contains('camera') || name.contains('headphone') || name.contains('charger') ||
        name.contains('tablet') || name.contains('ipad') || name.contains('iphone') ||
        name.contains('samsung') || name.contains('macbook') || name.contains('dell') ||
        name.contains('speaker') || name.contains('game') || name.contains('console') ||
        name.contains('smart') || name.contains('watch') || name.contains('fitbit')) {
      return 'Electronics';
    }
    
    // Clothes categories
    if (name.contains('shirt') || name.contains('dress') || name.contains('jeans') ||
        name.contains('shoes') || name.contains('hat') || name.contains('jacket') ||
        name.contains('pants') || name.contains('short') || name.contains('skirt') ||
        name.contains('sweater') || name.contains('hoodie') || name.contains('sneaker') ||
        name.contains('cap') || name.contains('belt') || name.contains('scarf') ||
        name.contains('underwear') || name.contains('sock') || name.contains('bra')) {
      return 'Clothing';
    }
    
    // Default to Other for everything else
    return 'Other';
    }
    
  // Helper method to suggest subcategory based on product name
  String? _suggestSubcategory(String productName, String category) {
    final name = productName.toLowerCase();
    
    switch (category) {
      case 'Food':
        if (name.contains('bread') || name.contains('cake') || name.contains('donut') || 
            name.contains('muffin') || name.contains('croissant') || name.contains('pastry')) 
          return 'Baked Goods';
        if (name.contains('apple') || name.contains('banana') || name.contains('fruit') ||
            name.contains('vegetable') || name.contains('tomato') || name.contains('carrot')) 
          return 'Fresh Produce';
        if (name.contains('milk') || name.contains('cheese') || name.contains('egg') ||
            name.contains('yogurt') || name.contains('butter')) 
          return 'Dairy & Eggs';
        if (name.contains('chicken') || name.contains('beef') || name.contains('meat') ||
            name.contains('pork') || name.contains('fish') || name.contains('salmon')) 
          return 'Meat & Poultry';
        if (name.contains('rice') || name.contains('pasta') || name.contains('flour') ||
            name.contains('sugar') || name.contains('oil')) 
          return 'Pantry Items';
        if (name.contains('chip') || name.contains('snack') || name.contains('crack') ||
            name.contains('popcorn') || name.contains('nut')) 
          return 'Snacks';
        if (name.contains('coffee') || name.contains('tea') || name.contains('juice') ||
            name.contains('water') || name.contains('soda') || name.contains('drink')) 
          return 'Beverages';
        if (name.contains('frozen') || name.contains('ice cream')) 
          return 'Frozen Foods';
        if (name.contains('organic')) 
          return 'Organic Foods';
        if (name.contains('chocolate') || name.contains('candy') || name.contains('sweet')) 
          return 'Candy & Sweets';
        if (name.contains('sauce') || name.contains('ketchup') || name.contains('mustard')) 
          return 'Condiments';
        return 'Other Food Items';
        
      case 'Electronics':
        if (name.contains('phone') || name.contains('iphone') || name.contains('samsung')) 
          return 'Phones';
        if (name.contains('laptop') || name.contains('macbook')) 
          return 'Laptops';
        if (name.contains('tablet') || name.contains('ipad')) 
          return 'Tablets';
        if (name.contains('computer') || name.contains('pc') || name.contains('desktop')) 
          return 'Computers';
        if (name.contains('camera')) 
          return 'Cameras';
        if (name.contains('headphone') || name.contains('airpod') || name.contains('earphone')) 
          return 'Headphones';
        if (name.contains('speaker')) 
          return 'Speakers';
        if (name.contains('game') || name.contains('console')) 
          return 'Gaming';
        if (name.contains('smart') || name.contains('home')) 
          return 'Smart Home';
        if (name.contains('watch') || name.contains('fitbit')) 
          return 'Wearables';
        if (name.contains('charger') || name.contains('cable') || name.contains('case')) 
          return 'Accessories';
        return 'Other Electronics';
        
      case 'Clothing':
        if (name.contains('t-shirt') || name.contains('tshirt')) 
          return 'T-Shirts';
        if (name.contains('jean')) 
          return 'Jeans';
        if (name.contains('dress')) 
          return 'Dresses';
        if (name.contains('shirt')) 
          return 'Shirts';
        if (name.contains('pant')) 
          return 'Pants';
        if (name.contains('short')) 
          return 'Shorts';
        if (name.contains('skirt')) 
          return 'Skirts';
        if (name.contains('jacket')) 
          return 'Jackets';
        if (name.contains('sweater')) 
          return 'Sweaters';
        if (name.contains('hoodie')) 
          return 'Hoodies';
        if (name.contains('shoe') || name.contains('sneaker')) 
          return 'Shoes';
        if (name.contains('hat') || name.contains('cap')) 
          return 'Hats';
        if (name.contains('accessory') || name.contains('belt') || name.contains('scarf')) 
          return 'Accessories';
        if (name.contains('underwear') || name.contains('bra')) 
          return 'Underwear';
        if (name.contains('sock')) 
          return 'Socks';
        return 'Other Clothing';
        
      case 'Other':
        if (name.contains('handmade') || name.contains('craft')) 
          return 'Handmade';
        if (name.contains('vintage') || name.contains('antique')) 
          return 'Vintage';
        if (name.contains('collectible') || name.contains('trading')) 
          return 'Collectibles';
        if (name.contains('book')) 
          return 'Books';
        if (name.contains('toy')) 
          return 'Toys';
        if (name.contains('plant') || name.contains('garden') || name.contains('tool')) 
          return 'Home & Garden';
        if (name.contains('sport') || name.contains('jersey')) 
          return 'Sports';
        if (name.contains('makeup') || name.contains('beauty') || name.contains('skincare')) 
          return 'Beauty';
        if (name.contains('vitamin') || name.contains('health') || name.contains('supplement')) 
          return 'Health';
        if (name.contains('car') || name.contains('automotive')) 
          return 'Automotive';
        if (name.contains('tool') || name.contains('hardware')) 
          return 'Tools';
        return 'Miscellaneous';
        
      default:
        return null;
    }
  }

  Future<void> _refreshProducts() async {
    setState(() {
      _allLoadedProducts.clear();
      _lastProductDoc = null;
      _hasMoreProducts = true;
    });
    _performanceService.clearAllCache();
  }

  Future<void> _addSampleProducts() async {
    try {
      print('🔧 DEBUG: Adding sample products...');
      
      // Get current user as seller
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ ERROR: No user logged in');
        return;
      }

                                    // Sample products data with high-quality, reliable image URLs
             final sampleProducts = [
               {
                 'name': 'Fresh Baked Bread',
                 'description': 'Artisan sourdough bread made fresh daily',
                 'price': 25.99,
                 'category': _categorizeProductByName('Fresh Baked Bread'),
                 'subcategory': 'Baked Goods',
                 'imageUrl': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                 'stock': 50,
                 'ownerId': user.uid,
                 'timestamp': FieldValue.serverTimestamp(),
               },
               {
                 'name': 'Chocolate Croissant',
                 'description': 'Buttery croissant filled with dark chocolate',
                 'price': 15.50,
                 'category': _categorizeProductByName('Chocolate Croissant'),
                 'subcategory': 'Baked Goods',
                 'imageUrl': 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                 'stock': 75,
                 'ownerId': user.uid,
                 'timestamp': FieldValue.serverTimestamp(),
               },
               {
                 'name': 'Organic Apple Pie',
                 'description': 'Homemade apple pie with organic ingredients',
                 'price': 45.00,
                 'category': _categorizeProductByName('Organic Apple Pie'),
                 'subcategory': 'Baked Goods',
                 'imageUrl': 'https://images.unsplash.com/photo-1535920527003-bc9c2c2f5c?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                 'stock': 25,
                 'ownerId': user.uid,
                 'timestamp': FieldValue.serverTimestamp(),
               },
               {
                 'name': 'Fresh Orange Juice',
                 'description': 'Freshly squeezed orange juice, no additives',
                 'price': 12.99,
                 'category': _categorizeProductByName('Fresh Orange Juice'),
                 'subcategory': 'Juices',
                 'imageUrl': 'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                 'stock': 30,
                 'ownerId': user.uid,
                 'timestamp': FieldValue.serverTimestamp(),
               },
               {
                 'name': 'Cotton T-Shirt',
                 'description': 'Comfortable 100% cotton t-shirt in various colors',
                 'price': 89.99,
                 'category': _categorizeProductByName('Cotton T-Shirt'),
                 'subcategory': 'T-Shirts',
                 'imageUrl': 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                 'stock': 40,
                 'ownerId': user.uid,
                 'timestamp': FieldValue.serverTimestamp(),
               },
             ];

      // Add products to Firestore
      final batch = FirebaseFirestore.instance.batch();
      for (final product in sampleProducts) {
        final docRef = FirebaseFirestore.instance.collection('products').doc();
        batch.set(docRef, product);
      }
      
      await batch.commit();
      print('✅ DEBUG: Sample products added successfully');
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample products added! Refresh to see them.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ ERROR: Failed to add sample products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add sample products: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fixExistingProductImage() async {
    try {
      print('🔧 DEBUG: Fixing existing product image...');
      
      // Get current user as seller
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ ERROR: No user logged in');
        return;
      }

      // Find and update the existing product with placeholder image
      final productsRef = FirebaseFirestore.instance.collection('products');
      
      // Find products with placeholder images
      final query = await productsRef
          .where('imageUrl', isEqualTo: 'https://via.placeholder.com/300x300?text=Product+Image')
          .get();
      
      print('Found ${query.docs.length} products with placeholder images');
      
      for (final doc in query.docs) {
        final data = doc.data();
        final productName = data['name'] ?? 'Unknown';
        final category = data['category'] ?? 'Food';
        
        // Choose appropriate image based on category and product name
        String newImageUrl;
        final name = productName.toLowerCase();
        
        if (name.contains('donut') || name.contains('muffin') || name.contains('bread')) {
          newImageUrl = 'https://images.unsplash.com/photo-1509440159596-0249088772ff?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80';
        } else if (name.contains('juice')) {
          newImageUrl = 'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80';
        } else if (name.contains('shirt') || name.contains('clothing')) {
          newImageUrl = 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80';
        } else {
          // Default food image
          newImageUrl = 'https://images.unsplash.com/photo-1509440159596-0249088772ff?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80';
        }
        
        // Update the product
        await doc.reference.update({
          'imageUrl': newImageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        print('Updated product: $productName with new image: $newImageUrl');
      }
      
      print('✅ Successfully updated all products with placeholder images');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Fixed existing product images'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ ERROR: Failed to fix product images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to fix product images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleFavorite(String productId) async {
    if (user == null) return;
    
    final favRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('favorites')
        .doc(productId);
    
    if (_favoriteIds.contains(productId)) {
      await favRef.delete();
      setState(() {
        _favoriteIds.remove(productId);
      });
    } else {
      await favRef.set({'addedAt': FieldValue.serverTimestamp()});
      setState(() {
        _favoriteIds.add(productId);
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _filterSubcategory = null;
      _searchQuery = '';
      _minPrice = 0.0;
              _maxPrice = 50000.0; // Increased to accommodate higher-priced electronics
      _inStockOnly = false;
      _sortBy = 'name';
    });
  }

  void _onPriceRangeChanged(double min, double max) {
    setState(() {
      _minPrice = min;
      _maxPrice = max;
    });
  }

  void _onStockFilterChanged(bool inStockOnly) {
    setState(() {
      _inStockOnly = inStockOnly;
    });
  }

  void _onSortByChanged(String sortBy) {
    setState(() {
      _sortBy = sortBy;
    });
  }

  void _onSearchChanged(String searchQuery) {
    setState(() {
      _searchQuery = searchQuery;
    });
  }
}

class BeautifulProductCard extends StatelessWidget {
  final String productId;
  final Map<String, dynamic> data;
  final bool isBuyer;
  final Set<String> favoriteIds;
  final Function(String) onFavoriteToggle;
  final bool isGridView;

  const BeautifulProductCard({
    Key? key,
    required this.productId,
    required this.data,
    required this.isBuyer,
    required this.favoriteIds,
    required this.onFavoriteToggle,
    required this.isGridView,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isFavorite = favoriteIds.contains(productId);
    // Check multiple possible stock fields - prioritize quantity over stock
    final stock = data['quantity'] ?? data['stock'] ?? 0;
    final isLowStock = stock < 10;
    final isOutOfStock = stock <= 0;
    
    // Debug stock information
    print('🔍 DEBUG: Product ${data['name']} stock info:');
    print('  - stock field: ${data['stock']}');
    print('  - quantity field: ${data['quantity']}');
    print('  - final stock value: $stock');
    print('  - isOutOfStock: $isOutOfStock');

    return Container(
      margin: EdgeInsets.only(bottom: isGridView ? 0 : 12),
      decoration: BoxDecoration(
        gradient: AppTheme.cardBackgroundGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.complementaryElevation,
        border: Border.all(
          color: AppTheme.breeze.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
      child: InkWell(
          onTap: isOutOfStock ? null : () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: {
                'id': productId,
                ...data,
              }),
            ),
          );
        },
          borderRadius: BorderRadius.circular(16),
          child: isGridView ? _buildGridLayout() : _buildListLayout(),
        ),
      ),
    );
  }

  Widget _buildGridLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product Image
        Expanded(
          flex: 3,
        child: Stack(
          children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: OptimizedProductImage(
                  imageUrl: data['imageUrl'],
                  width: double.infinity,
                  height: double.infinity,
                  isListItem: false,
                ),
              ),
              _buildStatusBadges(),
              if (isBuyer) _buildFavoriteButton(),
            ],
          ),
        ),
        // Product Info
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  data['name'] ?? 'Unknown Product',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.deepTeal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _buildConditionBadge(),
                const SizedBox(height: 4),
                // Description in grid layout
                if (data['description'] != null && data['description'].toString().isNotEmpty)
                  Expanded(
                    child: Text(
                      data['description'],
                      style: TextStyle(
                        color: AppTheme.cloud,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ),
                const SizedBox(height: 4),
                Text(
                  'R ${(data['price'] ?? 0.0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 8),
                // Action Buttons for Grid Layout
                if (isBuyer)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFavoriteButtonWithCount(),
                      Builder(
                        builder: (context) => _buildIconButton(
                          icon: Icons.add_shopping_cart,
                          color: AppTheme.deepTeal,
                          onPressed: () => _addToCart(context),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListLayout() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Product Image
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: OptimizedProductImage(
                  imageUrl: data['imageUrl'],
                  width: 100,
                  height: 100,
                  isListItem: true,
                ),
              ),
              _buildStatusBadges(),
            ],
          ),
          const SizedBox(width: 12),
          // Product Info
                Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                  data['name'] ?? 'Unknown Product',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.deepTeal,
                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                const SizedBox(height: 8),
                        _buildConditionBadge(),
                const SizedBox(height: 8),
                        Text(
                  'R ${(data['price'] ?? 0.0).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 8),
                // Enhanced description display
                if (data['description'] != null && data['description'].toString().isNotEmpty)
                  Expanded(
                    child: Text(
                    data['description'],
                    style: TextStyle(
                      color: AppTheme.cloud,
                      fontSize: 14,
                    ),
                      maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          // Action Buttons
                        if (isBuyer)
            Column(
                            children: [
                _buildFavoriteButtonWithCount(),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) => _buildIconButton(
                    icon: Icons.add_shopping_cart,
                    color: AppTheme.deepTeal,
                    onPressed: () => _addToCart(context),
                  ),
                ),
                            ],
                          ),
                      ],
                    ),
    );
  }

  Widget _buildStatusBadges() {
    // Use the same stock calculation as in build method - prioritize quantity over stock
    final stock = data['quantity'] ?? data['stock'] ?? 0;
    final isLowStock = stock < 10;
    final isOutOfStock = stock <= 0;

    return Positioned(
      top: 8,
      left: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isOutOfStock)
            _buildBadge('OUT OF STOCK', AppTheme.primaryRed)
          else if (isLowStock)
            _buildBadge('LOW STOCK', AppTheme.warning),
          if (data['featured'] == true) ...[
            const SizedBox(height: 4),
            _buildBadge('FEATURED', AppTheme.primaryGreen),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.angel,
          fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
    );
  }

  Widget _buildFavoriteButton() {
    final loveCount = data['favoriteCount'] ?? 0;
    final isFavorite = favoriteIds.contains(productId);
    
    return Positioned(
      top: 8,
      right: 8,
      child: Stack(
        children: [
          _buildIconButton(
            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? AppTheme.primaryRed : AppTheme.angel,
        backgroundColor: AppTheme.deepTeal.withOpacity(0.8),
        onPressed: () => onFavoriteToggle(productId),
          ),
          if (loveCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  loveCount.toString(),
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
  }

  Widget _buildFavoriteButtonWithCount() {
    final loveCount = data['favoriteCount'] ?? 0;
    final isFavorite = favoriteIds.contains(productId);
    
    return Column(
      children: [
        _buildIconButton(
          icon: isFavorite ? Icons.favorite : Icons.favorite_border,
          color: isFavorite ? AppTheme.primaryRed : AppTheme.cloud,
          onPressed: () => onFavoriteToggle(productId),
        ),
        if (loveCount > 0)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              loveCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    Color? backgroundColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
        iconSize: 20,
        constraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _addToCart(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    // Check if user is authenticated
    if (!cartProvider.isAuthenticated) {
      // Show a friendly message and add to local cart
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Item added to cart! Log in to save your cart.'),
          backgroundColor: AppTheme.primaryGreen,
          action: SnackBarAction(
            label: 'Login',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
          ),
        ),
      );
    }
    
    // Check multiple possible stock fields
    final stock = data['stock'] ?? data['quantity'] ?? 0;
    
    if (stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${data['name'] ?? 'This product'} is out of stock!'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Text('Adding ${data['name'] ?? 'product'} to cart...'),
          ],
        ),
        backgroundColor: AppTheme.deepTeal,
        duration: const Duration(seconds: 1),
      ),
    );

    cartProvider.addItem(
      productId,
      data['name'] ?? 'Unknown Product',
      (data['price'] ?? 0.0).toDouble(),
      data['imageUrl'] ?? '',
      data['ownerId'] ?? data['sellerId'] ?? '',
      data['storeName'] ?? 'Unknown Store',
      data['storeCategory'] ?? 'Other',
      availableStock: stock,
    ).then((success) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('${data['name'] ?? 'Product'} added to cart!'),
              ],
            ),
            backgroundColor: AppTheme.primaryGreen,
            action: SnackBarAction(
              label: 'View Cart',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pushNamed(context, '/cart');
              },
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // Show specific error message from cart provider
        final errorMessage = cartProvider.lastAddError ?? 'Cannot add more ${data['name'] ?? 'items'} - insufficient stock!';
        final backgroundColor = cartProvider.lastAddBlocked ? Colors.red : Colors.orange;
        final icon = cartProvider.lastAddBlocked ? Icons.block : Icons.warning;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Text('Failed to add to cart: ${error.toString()}'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  Widget _buildConditionBadge() {
    final condition = data['condition'] as String?;
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        badgeText,
        style: const TextStyle(
          color: AppTheme.angel,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

