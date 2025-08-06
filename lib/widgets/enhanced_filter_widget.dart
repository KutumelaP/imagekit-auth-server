import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EnhancedFilterWidget extends StatefulWidget {
  final String? selectedCategory;
  final String? selectedSubcategory;
  final Function(String?) onCategoryChanged;
  final Function(String?) onSubcategoryChanged;
  final Function() onClearFilters;
  final Function(double, double) onPriceRangeChanged;
  final Function(bool) onStockFilterChanged;
  final Function(String) onSortByChanged;
  final Function(String) onSearchChanged;
  final bool showClearButton;
  final List<Map<String, dynamic>> products;
  final double minPrice;
  final double maxPrice;
  final bool inStockOnly;
  final String sortBy;
  final String searchQuery;

  const EnhancedFilterWidget({
    Key? key,
    this.selectedCategory,
    this.selectedSubcategory,
    required this.onCategoryChanged,
    required this.onSubcategoryChanged,
    required this.onClearFilters,
    required this.onPriceRangeChanged,
    required this.onStockFilterChanged,
    required this.onSortByChanged,
    required this.onSearchChanged,
    required this.products,
    this.showClearButton = true,
    this.minPrice = 0.0,
    this.maxPrice = 1000.0,
    this.inStockOnly = false,
    this.sortBy = 'name',
    this.searchQuery = '',
  }) : super(key: key);

  @override
  State<EnhancedFilterWidget> createState() => _EnhancedFilterWidgetState();
}

class _EnhancedFilterWidgetState extends State<EnhancedFilterWidget>
    with TickerProviderStateMixin {
  late AnimationController _expandController;
  late AnimationController _fadeController;
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeAnimation;
  bool _isExpanded = false;

  // Advanced filter state
  RangeValues _priceRange = const RangeValues(0, 1000);
  bool _inStockOnly = false;
  String _sortBy = 'name';

  // Category-subcategory mapping
  static const Map<String, List<String>> categorySubcategoryMap = {
    'Food': [
      'Baked Goods', 'Fresh Produce', 'Dairy & Eggs', 'Meat & Poultry',
      'Pantry Items', 'Snacks', 'Beverages', 'Frozen Foods', 'Organic Foods',
      'Candy & Sweets', 'Condiments', 'Other Food Items'
    ],
    'Electronics': [
      'Phones', 'Laptops', 'Tablets', 'Computers', 'Cameras', 'Headphones',
      'Speakers', 'Gaming', 'Smart Home', 'Wearables', 'Accessories', 'Other Electronics'
    ],
    'Clothes': [
      'T-Shirts', 'Jeans', 'Dresses', 'Shirts', 'Pants', 'Shorts', 'Skirts',
      'Jackets', 'Sweaters', 'Hoodies', 'Shoes', 'Hats', 'Accessories', 'Underwear', 'Socks', 'Other Clothing'
    ],
    'Other': [
      'Handmade', 'Vintage', 'Collectibles', 'Books', 'Toys', 'Home & Garden',
      'Sports', 'Beauty', 'Health', 'Automotive', 'Tools', 'Miscellaneous'
    ]
  };

  static List<String> get allCategories => categorySubcategoryMap.keys.toList();

  static List<String> getSubcategoriesForCategory(String category) {
    return categorySubcategoryMap[category] ?? [];
  }

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    // Initialize with widget values
    _inStockOnly = widget.inStockOnly;
    _sortBy = widget.sortBy;
    
    // Initialize price range with safe defaults
    _priceRange = RangeValues(widget.minPrice, widget.maxPrice);
  }

  @override
  void didUpdateWidget(EnhancedFilterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update price range when products change
    if (oldWidget.products != widget.products) {
      _initializePriceRange();
    }
  }

  void _initializePriceRange() {
    if (widget.products.isEmpty) {
      _priceRange = RangeValues(widget.minPrice, widget.maxPrice);
      return;
    }
    
    final priceRange = _getPriceRangeFromProducts();
    final minPrice = priceRange.start;
    final maxPrice = priceRange.end;
    
    // Ensure the current values are within the valid range
    double startValue = _priceRange.start;
    double endValue = _priceRange.end;
    
    // Clamp values to valid range
    startValue = startValue.clamp(minPrice, maxPrice);
    endValue = endValue.clamp(minPrice, maxPrice);
    
    // Ensure start is not greater than end
    if (startValue > endValue) {
      startValue = minPrice;
      endValue = maxPrice;
    }
    
    setState(() {
      _priceRange = RangeValues(startValue, endValue);
    });
  }

  @override
  void dispose() {
    _expandController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
        _fadeController.forward();
      } else {
        _expandController.reverse();
        _fadeController.reverse();
      }
    });
  }

  // Get subcategories that have products in stock
  List<String> _getSubcategoriesInStock(String category) {
    final subcategoriesInStock = <String>{};
    
    print('🔍 DEBUG: Getting subcategories for category: $category');
    print('🔍 DEBUG: Total products to check: ${widget.products.length}');
    
    for (final product in widget.products) {
      final productCategory = product['category'] as String?;
      final productSubcategory = product['subcategory'] as String?;
      final quantity = product['quantity'] as int? ?? 0;
      final stock = product['stock'] as int? ?? quantity;
      
      print('🔍 DEBUG: Product ${product['name']}: category=$productCategory, subcategory=$productSubcategory, stock=$stock');
      
      if (productCategory == category && 
          productSubcategory != null && 
          stock > 0) {
        subcategoriesInStock.add(productSubcategory);
        print('🔍 DEBUG: Added subcategory: $productSubcategory');
      }
    }
    
    final result = subcategoriesInStock.toList()..sort();
    print('🔍 DEBUG: Final subcategories in stock: $result');
    return result;
  }

  // Get price range from products
  RangeValues _getPriceRangeFromProducts() {
    if (widget.products.isEmpty) return const RangeValues(0, 1000);
    
    double minPrice = double.infinity;
    double maxPrice = 0;
    
    for (final product in widget.products) {
      final price = (product['price'] as num?)?.toDouble() ?? 0.0;
      if (price > 0) { // Only consider products with valid prices
        if (price < minPrice) minPrice = price;
        if (price > maxPrice) maxPrice = price;
      }
    }
    
    // Handle edge cases
    if (minPrice == double.infinity || maxPrice == 0) {
      return const RangeValues(0, 1000);
    }
    
    // Ensure min is not greater than max
    if (minPrice > maxPrice) {
      return const RangeValues(0, 1000);
    }
    
    // Add some padding to the range
    final padding = (maxPrice - minPrice) * 0.1;
    return RangeValues(
      (minPrice - padding).clamp(0, double.infinity),
      (maxPrice + padding).clamp(0, double.infinity),
    );
  }

  Widget _buildSectionTitle(String title, bool isSmallScreen) {
    return Text(
      title,
      style: TextStyle(
        fontSize: isSmallScreen ? 12 : 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.deepTeal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate responsive height based on screen size
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 600 || screenWidth < 400;
    
    // Adjust max height for different screen sizes
    final maxHeight = isSmallScreen 
        ? screenHeight * 0.5  // Smaller screens get less height
        : screenHeight * 0.6; // Larger screens get more height
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.angel,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            decoration: BoxDecoration(
              color: AppTheme.deepTeal,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.angel,
                    size: isSmallScreen ? 20 : 24,
                  ),
                  onPressed: _toggleExpanded,
                  padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                ),
                SizedBox(width: isSmallScreen ? 4 : 8),
                Expanded(
                  child: Text(
                    'Advanced Filters',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.angel,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.onClearFilters,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 8 : 12,
                      vertical: isSmallScreen ? 4 : 8,
                    ),
                  ),
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      color: AppTheme.primaryOrange,
                      fontWeight: FontWeight.w600,
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Expandable content
          AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              return SizeTransition(
                sizeFactor: _expandAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: maxHeight,
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        isSmallScreen ? 12 : 16, 
                        0, 
                        isSmallScreen ? 12 : 16, 
                        isSmallScreen ? 12 : 16
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          
                          // Search field
                          Container(
                            padding: EdgeInsets.fromLTRB(
                              isSmallScreen ? 12 : 16, 
                              isSmallScreen ? 6 : 8, 
                              isSmallScreen ? 12 : 16, 
                              isSmallScreen ? 6 : 8
                            ),
                            child: TextField(
                              onChanged: widget.onSearchChanged,
                              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                              decoration: InputDecoration(
                                hintText: 'Search products by name...',
                                hintStyle: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: AppTheme.breeze,
                                  size: isSmallScreen ? 18 : 20,
                                ),
                                suffixIcon: widget.searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear,
                                          color: AppTheme.breeze,
                                          size: isSmallScreen ? 18 : 20,
                                        ),
                                        onPressed: () => widget.onSearchChanged(''),
                                        padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                                      )
                                    : null,
                                filled: true,
                                fillColor: AppTheme.angel,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppTheme.breeze.withOpacity(0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppTheme.deepTeal, width: 2),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 12 : 16,
                                  vertical: isSmallScreen ? 8 : 12,
                                ),
                              ),
                            ),
                          ),
                          
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          
                          // Category filter
                          _buildSectionTitle('Category', isSmallScreen),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          _buildCategoryChips(),
                          
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          
                          // Subcategory filter
                          _buildSectionTitle('Subcategory (In Stock)', isSmallScreen),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          _buildSubcategoryChips(),
                          
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          
                          // Price range
                          _buildSectionTitle('Price Range', isSmallScreen),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          _buildPriceRangeSlider(),
                          
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          
                          // Stock filter
                          _buildSectionTitle('Stock Status', isSmallScreen),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          _buildStockFilter(),
                          
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          
                          // Sort options
                          _buildSectionTitle('Sort By', isSmallScreen),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          _buildSortOptions(),
                          
                          SizedBox(height: isSmallScreen ? 12 : 16),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    // Get actual categories from products
    final Set<String> actualCategories = <String>{};
    for (final product in widget.products) {
      final category = product['category'] as String?;
      if (category != null && category.isNotEmpty) {
        actualCategories.add(category);
      }
    }
    
    final availableCategories = actualCategories.toList()..sort();
    
    print('🔍 DEBUG: Building category chips');
    print('🔍 DEBUG: Available categories from products: $availableCategories');
    print('🔍 DEBUG: Selected category: ${widget.selectedCategory}');
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFilterChip(
          'All Categories',
          widget.selectedCategory == null,
          () => widget.onCategoryChanged(null),
        ),
        ...availableCategories.map((category) =>
          _buildFilterChip(
            category,
            widget.selectedCategory == category,
            () => widget.onCategoryChanged(category),
          ),
        ),
      ],
    );
  }

  Widget _buildSubcategoryChips() {
    // Only show subcategories if a category is selected
    if (widget.selectedCategory == null) {
      return const SizedBox.shrink();
    }
    
    final subcategoriesInStock = _getSubcategoriesInStock(widget.selectedCategory!);
    
    print('🔍 DEBUG: Building subcategory chips for category: ${widget.selectedCategory}');
    print('🔍 DEBUG: Subcategories in stock: $subcategoriesInStock');
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFilterChip(
          'All ${widget.selectedCategory}',
          widget.selectedSubcategory == null,
          () => widget.onSubcategoryChanged(null),
        ),
        ...subcategoriesInStock.map((subcategory) =>
          _buildFilterChip(
            subcategory,
            widget.selectedSubcategory == subcategory,
            () => widget.onSubcategoryChanged(subcategory),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRangeSlider() {
    final priceRange = _getPriceRangeFromProducts();
    
    // Ensure current values are within bounds
    final safeStart = _priceRange.start.clamp(priceRange.start, priceRange.end);
    final safeEnd = _priceRange.end.clamp(priceRange.start, priceRange.end);
    final safeValues = RangeValues(safeStart, safeEnd);
    
    return Column(
      children: [
        RangeSlider(
          values: safeValues,
          min: priceRange.start,
          max: priceRange.end,
          divisions: 20,
          activeColor: AppTheme.deepTeal,
          inactiveColor: AppTheme.cloud,
          labels: RangeLabels(
            'R${safeValues.start.round()}',
            'R${safeValues.end.round()}',
          ),
          onChanged: (values) {
            setState(() {
              _priceRange = values;
            });
            widget.onPriceRangeChanged(values.start, values.end);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'R${safeValues.start.round()}',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.deepTeal,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'R${safeValues.end.round()}',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.deepTeal,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStockFilter() {
    return Row(
      children: [
        Checkbox(
          value: _inStockOnly,
          onChanged: (value) {
            setState(() {
              _inStockOnly = value ?? false;
            });
            widget.onStockFilterChanged(_inStockOnly);
          },
          activeColor: AppTheme.deepTeal,
        ),
        Text(
          'Show only in-stock items',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.deepTeal,
          ),
        ),
      ],
    );
  }

  Widget _buildSortOptions() {
    final sortOptions = [
      {'value': 'name', 'label': 'Name A-Z'},
      {'value': 'name_desc', 'label': 'Name Z-A'},
      {'value': 'price', 'label': 'Price Low-High'},
      {'value': 'price_desc', 'label': 'Price High-Low'},
      {'value': 'newest', 'label': 'Newest First'},
      {'value': 'oldest', 'label': 'Oldest First'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sortOptions.map((option) =>
        _buildFilterChip(
          option['label']!,
          _sortBy == option['value'],
          () {
            setState(() {
              _sortBy = option['value']!;
            });
            widget.onSortByChanged(_sortBy);
          },
        ),
      ).toList(),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    final isSmallScreen = MediaQuery.of(context).size.height < 600 || MediaQuery.of(context).size.width < 400;
    
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: isSmallScreen ? 11 : 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppTheme.angel : AppTheme.deepTeal,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: AppTheme.angel,
      selectedColor: AppTheme.deepTeal,
      checkmarkColor: AppTheme.angel,
      side: BorderSide(
        color: isSelected ? AppTheme.deepTeal : AppTheme.breeze.withOpacity(0.5),
        width: 1,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 12,
        vertical: isSmallScreen ? 4 : 6,
      ),
      labelPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 4 : 6,
        vertical: isSmallScreen ? 2 : 4,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
} 