import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/performance_service.dart';
import '../widgets/optimized_image.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';

class OptimizedProductList extends StatefulWidget {
  final String? category;
  final String? storeId;
  final Function(Map<String, dynamic>)? onProductTap;
  final EdgeInsetsGeometry? padding;
  final bool isGridView;
  final int crossAxisCount;

  const OptimizedProductList({
    Key? key,
    this.category,
    this.storeId,
    this.onProductTap,
    this.padding,
    this.isGridView = false,
    this.crossAxisCount = 2,
  }) : super(key: key);

  @override
  State<OptimizedProductList> createState() => _OptimizedProductListState();
}

class _OptimizedProductListState extends State<OptimizedProductList>
    with AutomaticKeepAliveClientMixin {
  final List<Map<String, dynamic>> _products = [];
  final ScrollController _scrollController = ScrollController();
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMoreData = true;
  bool _initialLoad = true;
  
  static const int _pageSize = 20;
  final PerformanceService _performanceService = PerformanceService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialProducts();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreProducts();
    }
  }

  String _getCacheKey() {
    return 'products_${widget.category ?? ''}_${widget.storeId ?? ''}_list';
  }

  Future<void> _loadInitialProducts() async {
    if (_isLoading) return;

    PerformanceMonitor.startMeasurement('initial_product_load');
    
    setState(() {
      _isLoading = true;
      _initialLoad = true;
    });

    try {
      // Check cache first
      final cacheKey = _getCacheKey();
      final cachedData = _performanceService.getCachedPaginationData(cacheKey);
      
      if (cachedData['docs'] != null && cachedData['docs'].isNotEmpty) {
        final docs = cachedData['docs'] as List<DocumentSnapshot>;
        await _processProducts(docs);
        _lastDocument = cachedData['lastDoc'] as DocumentSnapshot?;
        
        setState(() {
          _isLoading = false;
          _initialLoad = false;
        });
        
        PerformanceMonitor.endMeasurement('initial_product_load');
        return;
      }

      // Load from Firestore
      final query = _buildQuery();
      final snapshot = await query.get();
      
      if (snapshot.docs.isNotEmpty) {
        await _processProducts(snapshot.docs);
        _lastDocument = snapshot.docs.last;
        _hasMoreData = snapshot.docs.length == _pageSize;
        
        // Cache the results
        _performanceService.cachePaginationData(cacheKey, snapshot.docs, _lastDocument);
      } else {
        _hasMoreData = false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading products: $e');
      }
      _showErrorSnackBar('Failed to load products');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _initialLoad = false;
        });
      }
      PerformanceMonitor.endMeasurement('initial_product_load');
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoading || !_hasMoreData || _lastDocument == null) return;

    PerformanceMonitor.startMeasurement('load_more_products');
    
    setState(() {
      _isLoading = true;
    });

    try {
      final query = _buildQuery().startAfterDocument(_lastDocument!);
      final snapshot = await query.get();
      
      if (snapshot.docs.isNotEmpty) {
        await _processProducts(snapshot.docs);
        _lastDocument = snapshot.docs.last;
        _hasMoreData = snapshot.docs.length == _pageSize;
      } else {
        _hasMoreData = false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading more products: $e');
      }
      _showErrorSnackBar('Failed to load more products');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      PerformanceMonitor.endMeasurement('load_more_products');
    }
  }

  Query _buildQuery() {
    Query query = FirebaseFirestore.instance
        .collection('products')
        .orderBy('timestamp', descending: true)
        .limit(_pageSize);

    if (widget.category != null) {
      query = query.where('category', isEqualTo: widget.category);
    }

    if (widget.storeId != null) {
      query = query.where('ownerId', isEqualTo: widget.storeId);
    }

    return query;
  }

  Future<void> _processProducts(List<DocumentSnapshot> docs) async {
    final newProducts = <Map<String, dynamic>>[];
    final futures = <Future<void>>[];

    for (final doc in docs) {
      futures.add(_processProduct(doc, newProducts));
    }

    await Future.wait(futures);
    
    if (mounted) {
      setState(() {
        _products.addAll(newProducts);
      });
    }

    // Preload images for better UX
    final imageUrls = newProducts
        .map((product) => product['imageUrl'] as String?)
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .take(5) // Only preload first 5 images
        .toList();
    
    if (imageUrls.isNotEmpty && mounted) {
      ImagePreloader.preloadImages(context, imageUrls);
    }
  }

  Future<void> _processProduct(
    DocumentSnapshot doc,
    List<Map<String, dynamic>> productList,
  ) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final ownerId = data['ownerId'] ?? data['sellerId'];
      
      if (ownerId == null) return;

      // Check if seller is paused (use cache if available)
      final sellerCacheKey = 'seller_$ownerId';
      Map<String, dynamic>? sellerData = _performanceService.getCachedData(sellerCacheKey);
      
      if (sellerData == null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerId)
            .get();
        
        if (userDoc.exists) {
          sellerData = userDoc.data() as Map<String, dynamic>;
          _performanceService.cacheData(sellerCacheKey, sellerData);
        }
      }

      if (sellerData?['paused'] == true) return;

      final sellerName = sellerData?['name'] ?? 
                       sellerData?['storeName'] ?? 
                       'Unknown Seller';

      productList.add({
        'id': doc.id,
        ...data,
        'sellerName': sellerName,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error processing product ${doc.id}: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
    }
  }

  Future<void> _refresh() async {
    _products.clear();
    _lastDocument = null;
    _hasMoreData = true;
    
    // Clear cache for fresh data
    _performanceService.clearCache(_getCacheKey());
    
    await _loadInitialProducts();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_initialLoad) {
      return _buildLoadingWidget();
    }

    if (_products.isEmpty && !_isLoading) {
      return _buildEmptyWidget();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: widget.isGridView ? _buildGridView() : _buildListView(),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      padding: widget.padding ?? const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: widget.isGridView
                ? _buildLoadingGrid()
                : _buildLoadingList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => _buildLoadingCard(),
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) => _buildLoadingCard(isListItem: true),
    );
  }

  Widget _buildLoadingCard({bool isListItem = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        height: isListItem ? 80 : 200,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or check back later',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return PerformanceUtils.optimizedGridView(
      itemCount: _products.length + (_hasMoreData ? 1 : 0),
      padding: widget.padding ?? const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      controller: _scrollController,
      itemBuilder: (context, index) {
        if (index >= _products.length) {
          return _buildLoadingIndicator();
        }
        return _buildProductGridItem(_products[index]);
      },
    );
  }

  Widget _buildListView() {
    return PerformanceUtils.optimizedListView(
      itemCount: _products.length + (_hasMoreData ? 1 : 0),
      padding: widget.padding ?? const EdgeInsets.all(8),
      controller: _scrollController,
      itemExtent: 120, // Fixed height for better performance
      itemBuilder: (context, index) {
        if (index >= _products.length) {
          return _buildLoadingIndicator();
        }
        return _buildProductListItem(_products[index]);
      },
    );
  }

  Widget _buildLoadingIndicator() {
    if (!_isLoading) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
        ),
      ),
    );
  }

  Widget _buildProductGridItem(Map<String, dynamic> product) {
    final imageSize = ImageSizeUtils.getOptimalGridImageSize(context, widget.crossAxisCount);
    
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => widget.onProductTap?.call(product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OptimizedProductImage(
                imageUrl: product['imageUrl'],
                width: imageSize['width'],
                height: imageSize['height'],
                isListItem: false,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? 'Unknown Product',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'R ${(product['price'] ?? 0.0).toStringAsFixed(2)}',
                    style: TextStyle(
                      color: AppTheme.deepTeal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductListItem(Map<String, dynamic> product) {
    final imageSize = ImageSizeUtils.getOptimalListImageSize(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => widget.onProductTap?.call(product),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              OptimizedProductImage(
                imageUrl: product['imageUrl'],
                width: imageSize['width'],
                height: imageSize['height'],
                isListItem: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] ?? 'Unknown Product',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product['sellerName'] ?? 'Unknown Seller',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'R ${(product['price'] ?? 0.0).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppTheme.deepTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 