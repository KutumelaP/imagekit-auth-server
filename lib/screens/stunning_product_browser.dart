import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/safe_network_image.dart';
import '../constants/app_constants.dart';
import '../providers/cart_provider.dart';
import 'stunning_product_detail.dart';

class StunningProductBrowser extends StatefulWidget {
  final String storeId;
  final String storeName;

  const StunningProductBrowser({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<StunningProductBrowser> createState() => _StunningProductBrowserState();
}

class _StunningProductBrowserState extends State<StunningProductBrowser>
    with TickerProviderStateMixin {
  // Controllers and State
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // State Variables
  String searchQuery = '';
  String selectedCategory = 'All';
  String? selectedSubcategory;
  String sortBy = 'name';
  bool isAscending = true;
  double minPrice = 0.0;
  double maxPrice = 50000.0; // Increased to accommodate higher-priced electronics
  bool inStockOnly = false;
  bool isLoading = true;
  bool showFilters = false;
  
  // Data
  List<QueryDocumentSnapshot> products = [];
  List<String> categories = [];
  Map<String, List<String>> subcategoriesMap = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadProducts();
    _scrollController.addListener(_onScroll);
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels > 100) {
      if (!showFilters) {
        setState(() => showFilters = true);
      }
    } else {
      if (showFilters) {
        setState(() => showFilters = false);
      }
    }
  }

  Future<void> _loadProducts() async {
    setState(() => isLoading = true);
    
    try {
      Query query = FirebaseFirestore.instance
          .collection(AppConstants.productsCollection);

      // Add store filter if not browsing all stores
      if (widget.storeId != 'all') {
        query = query.where('ownerId', isEqualTo: widget.storeId);
      }

      // Add category filter at database level
      if (selectedCategory != 'All' && selectedCategory.isNotEmpty) {
        query = query.where('category', isEqualTo: selectedCategory);
      }

      // Add subcategory filter at database level
      if (selectedSubcategory != null && selectedSubcategory!.isNotEmpty) {
        query = query.where('subcategory', isEqualTo: selectedSubcategory);
      }

      final snapshot = await query.get();
      
      // Process products and extract categories
      final Set<String> categorySet = <String>{};
      final Map<String, Set<String>> subcategorySet = <String, Set<String>>{};
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final category = data['category']?.toString();
        final subcategory = data['subcategory']?.toString();
        
        if (category != null) {
          categorySet.add(category);
          if (subcategory != null) {
            subcategorySet[category] ??= <String>{};
            subcategorySet[category]!.add(subcategory);
          }
        }
      }

      setState(() {
        products = snapshot.docs;
        categories = categorySet.toList()..sort();
        subcategoriesMap = subcategorySet.map(
          (key, value) => MapEntry(key, value.toList()..sort()),
        );
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading products: $e');
      setState(() => isLoading = false);
    }
  }

  List<QueryDocumentSnapshot> get filteredProducts {
    return products.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Search filter
      if (searchQuery.isNotEmpty) {
        final name = data['name']?.toString().toLowerCase() ?? '';
        final description = data['description']?.toString().toLowerCase() ?? '';
        if (!name.contains(searchQuery.toLowerCase()) && 
            !description.contains(searchQuery.toLowerCase())) {
          return false;
        }
      }
      
      // Category filter
      if (selectedCategory != 'All' && selectedCategory.isNotEmpty) {
        final productCategory = (data['category'] as String?) ?? '';
        if (productCategory.toLowerCase() != selectedCategory.toLowerCase()) {
          return false;
        }
      }
      
      // Subcategory filter
      if (selectedSubcategory != null && selectedSubcategory!.isNotEmpty) {
        final productSubcategory = (data['subcategory'] as String?) ?? '';
        if (productSubcategory.toLowerCase() != selectedSubcategory!.toLowerCase()) {
          return false;
        }
      }
      
      // Price filter
      final price = (data['price'] ?? 0.0).toDouble();
      if (price < minPrice || price > maxPrice) {
        return false;
      }
      
      // Stock filter
      if (inStockOnly) {
        final stock = data['quantity'] ?? data['stock'] ?? 0;
        if ((stock as num) <= 0) {
          return false;
        }
      }
      
      return true;
    }).toList()
      ..sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        
        int comparison = 0;
        switch (sortBy) {
          case 'name':
            comparison = (aData['name'] ?? '').toString()
                .compareTo((bData['name'] ?? '').toString());
            break;
          case 'price':
            comparison = ((aData['price'] ?? 0.0) as num)
                .compareTo((bData['price'] ?? 0.0) as num);
            break;
          case 'newest':
            final aTime = aData['timestamp'] as Timestamp?;
            final bTime = bData['timestamp'] as Timestamp?;
            comparison = (bTime?.millisecondsSinceEpoch ?? 0)
                .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
            break;
        }
        return isAscending ? comparison : -comparison;
      });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    
    return Scaffold(
      backgroundColor: AppTheme.angel,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(isMobile),
          _buildSearchAndFilters(isMobile),
          if (isLoading)
            _buildLoadingSliver()
          else if (filteredProducts.isEmpty)
            _buildEmptyStateSliver()
          else
            _buildProductGrid(isMobile, isTablet),
        ],
      ),
      floatingActionButton: _buildFilterFab(),
    );
  }

  Widget _buildSliverAppBar(bool isMobile) {
    return SliverAppBar(
      expandedHeight: isMobile ? 120 : 160,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.deepTeal,
      foregroundColor: Colors.white,
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
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppTheme.primaryGradient,
            ),
          ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        widget.storeName,
                        style: AppTheme.headlineLarge.copyWith(
                          color: Colors.white,
                          fontSize: isMobile ? 20 : 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${filteredProducts.length} products available',
                        style: AppTheme.bodyMedium.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isMobile) {
    return SliverToBoxAdapter(
      child: Container(
        color: AppTheme.whisper,
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          children: [
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.deepTeal.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: Icon(Icons.search, color: AppTheme.cloud),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => searchQuery = '');
                          },
                          icon: Icon(Icons.clear, color: AppTheme.cloud),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Category Chips
            if (categories.isNotEmpty) _buildCategoryChips(),
            
            // Sort and Filter Row
            Row(
              children: [
                Expanded(child: _buildSortDropdown()),
                const SizedBox(width: 12),
                _buildFilterButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildCategoryChip('All', selectedCategory == 'All'),
          ...categories.map((category) => _buildCategoryChip(
            category, 
            selectedCategory == category,
          )),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            selectedCategory = label;
            selectedSubcategory = null;
          });
          // Reload products when category changes
          _loadProducts();
        },
        backgroundColor: Colors.white,
        selectedColor: AppTheme.deepTeal,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.deepTeal,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide(color: AppTheme.cloud),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cloud),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: sortBy,
          icon: Icon(Icons.sort, color: AppTheme.deepTeal),
          items: const [
            DropdownMenuItem(value: 'name', child: Text('Name')),
            DropdownMenuItem(value: 'price', child: Text('Price')),
            DropdownMenuItem(value: 'newest', child: Text('Newest')),
          ],
          onChanged: (value) => setState(() => sortBy = value ?? 'name'),
        ),
      ),
    );
  }

  Widget _buildFilterButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.deepTeal,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: _showFilterBottomSheet,
        icon: const Icon(Icons.tune, color: Colors.white),
      ),
    );
  }

  Widget _buildProductGrid(bool isMobile, bool isTablet) {
    final crossAxisCount = isMobile ? 2 : (isTablet ? 3 : 4);
    final childAspectRatio = isMobile ? 0.75 : 0.8;
    
    return SliverPadding(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildProductCard(filteredProducts[index], isMobile),
          childCount: filteredProducts.length,
        ),
      ),
    );
  }

  Widget _buildProductCard(QueryDocumentSnapshot doc, bool isMobile) {
    final data = doc.data() as Map<String, dynamic>;
    final productData = {...data, 'id': doc.id};
    final stock = data['quantity'] ?? data['stock'] ?? 0;
    final isOutOfStock = (stock as num) <= 0;
    
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StunningProductDetail(product: productData),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepTeal.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image with Add to Cart Button
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.whisper,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: SafeNetworkImage(
                        imageUrl: data['imageUrl'] ?? '',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  
                  // Add to Cart Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _addToCart(doc.id, data),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isOutOfStock 
                              ? Colors.grey.withOpacity(0.8)
                              : AppTheme.deepTeal.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isOutOfStock ? Icons.remove_shopping_cart : Icons.add_shopping_cart,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  
                  // Favorite Button
                  Positioned(
                    top: 8,
                    left: 8,
                    child: GestureDetector(
                      onTap: () => _toggleFavorite(doc.id, data),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FutureBuilder<bool>(
                          future: _checkIfFavorite(doc.id),
                          builder: (context, snapshot) {
                            final isFavorite = snapshot.data ?? false;
                            return Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? Colors.red : Colors.grey,
                              size: 16,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Product Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 8 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? 'Unnamed Product',
                      style: AppTheme.titleMedium.copyWith(
                        fontSize: isMobile ? 12 : 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _buildConditionIndicator(data),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          'R${(data['price'] ?? 0.0).toStringAsFixed(2)}',
                          style: AppTheme.titleMedium.copyWith(
                            color: AppTheme.deepTeal,
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 14 : 16,
                          ),
                        ),
                        const Spacer(),
                        _buildStockIndicator(data),
                      ],
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

  Widget _buildConditionIndicator(Map<String, dynamic> data) {
    final condition = data['condition']?.toString() ?? '';
    
    switch (condition.toLowerCase()) {
      case 'new':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'New',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryGreen,
            ),
          ),
        );
      case 'second hand':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Used',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppTheme.warning,
            ),
          ),
        );
      case 'refurbished':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.deepTeal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Refurbished',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppTheme.deepTeal,
            ),
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.cloud.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            condition.isNotEmpty ? condition : 'N/A',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppTheme.cloud,
            ),
          ),
        );
    }
  }

  Widget _buildStockIndicator(Map<String, dynamic> data) {
    final stock = data['quantity'] ?? data['stock'] ?? 0;
    final isInStock = (stock as num) > 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isInStock 
            ? AppTheme.primaryGreen.withOpacity(0.1)
            : AppTheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isInStock ? 'In Stock' : 'Out of Stock',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: isInStock ? AppTheme.primaryGreen : AppTheme.error,
        ),
      ),
    );
  }

  Widget _buildLoadingSliver() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading amazing products...',
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.cloud),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateSliver() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: AppTheme.cloud,
            ),
            const SizedBox(height: 16),
            Text(
              widget.storeId != 'all' 
                  ? 'No products in this store'
                  : 'No products found',
              style: AppTheme.headlineMedium.copyWith(color: AppTheme.deepTeal),
            ),
            const SizedBox(height: 8),
            Text(
              widget.storeId != 'all'
                  ? 'This store has not added any products yet'
                  : 'Try adjusting your search or filters',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.cloud),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterFab() {
    return AnimatedOpacity(
      opacity: showFilters ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: FloatingActionButton(
        onPressed: _showFilterBottomSheet,
        backgroundColor: AppTheme.deepTeal,
        child: const Icon(Icons.filter_list, color: Colors.white),
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFilterBottomSheet(),
    );
  }

  Widget _buildFilterBottomSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Filters',
                  style: AppTheme.headlineMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedCategory = 'All';
                      selectedSubcategory = null;
                      minPrice = 0.0;
                      maxPrice = 10000.0;
                      inStockOnly = false;
                    });
                    this.setState(() {});
                  },
                  child: Text('Clear All', style: TextStyle(color: AppTheme.cloud)),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Price Range
            Text('Price Range', style: AppTheme.titleMedium),
            RangeSlider(
              values: RangeValues(minPrice, maxPrice),
              min: 0,
              max: 10000,
              divisions: 100,
              labels: RangeLabels(
                'R${minPrice.toStringAsFixed(0)}',
                'R${maxPrice.toStringAsFixed(0)}',
              ),
              onChanged: (values) {
                setState(() {
                  minPrice = values.start;
                  maxPrice = values.end;
                });
              },
            ),
            
            const SizedBox(height: 20),
            
            // Stock Filter
            CheckboxListTile(
              title: Text('In Stock Only'),
              value: inStockOnly,
              onChanged: (value) => setState(() => inStockOnly = value ?? false),
              activeColor: AppTheme.deepTeal,
            ),
            
            const SizedBox(height: 20),
            
            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  this.setState(() {});
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.deepTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Apply Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToCart(String productId, Map<String, dynamic> data) async {
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      
      // Check if user is authenticated
      if (!cartProvider.isAuthenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please login to add items to cart'),
            backgroundColor: AppTheme.warning,
            action: SnackBarAction(
              label: 'Login',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
            ),
          ),
        );
        return;
      }
      
      // Check stock availability
      final stock = data['quantity'] ?? data['stock'] ?? 0;
      if ((stock as num) <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${data['name'] ?? 'This product'} is out of stock!'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Adding ${data['name'] ?? 'product'} to cart...'),
          backgroundColor: AppTheme.deepTeal,
          duration: const Duration(seconds: 1),
        ),
      );

      final success = await cartProvider.addItem(
        productId,
        data['name'] ?? 'Unknown Product',
        (data['price'] ?? 0.0).toDouble(),
        data['imageUrl'] ?? '',
        data['ownerId'] ?? data['sellerId'] ?? '',
        data['storeName'] ?? 'Unknown Store',
        data['storeCategory'] ?? 'Other',
        availableStock: stock.toInt(),
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${data['name'] ?? 'Product'} added to cart!'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot add more ${data['name'] ?? 'items'} - insufficient stock!'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add to cart: ${e.toString()}'),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<bool> _checkIfFavorite(String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(productId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  Future<void> _toggleFavorite(String productId, Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please login to add favorites'),
          backgroundColor: AppTheme.warning,
          action: SnackBarAction(
            label: 'Login',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
          ),
        ),
      );
      return;
    }

    try {
      final favDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(productId);

      final favDoc = await favDocRef.get();
      
      if (favDoc.exists) {
        // Remove from favorites
        await favDocRef.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${data['name'] ?? 'product'} from favorites'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Add to favorites
        await favDocRef.set({
          'name': data['name'],
          'imageUrl': data['imageUrl'],
          'price': data['price'],
          'timestamp': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${data['name'] ?? 'product'} to favorites'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Trigger rebuild to update UI
      setState(() {});
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update favorites: $e'),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
} 