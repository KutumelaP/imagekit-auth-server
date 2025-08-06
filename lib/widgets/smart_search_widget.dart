import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../utils/smart_search_engine.dart';

class SmartSearchWidget extends StatefulWidget {
  final String? initialQuery;
  final String? category;
  final Function(String)? onSearch;
  final bool showFilters;
  final bool showSuggestions;

  const SmartSearchWidget({
    Key? key,
    this.initialQuery,
    this.category,
    this.onSearch,
    this.showFilters = true,
    this.showSuggestions = true,
  }) : super(key: key);

  @override
  State<SmartSearchWidget> createState() => _SmartSearchWidgetState();
}

class _SmartSearchWidgetState extends State<SmartSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  List<String> _suggestions = [];
  List<String> _trendingSearches = [];
  bool _showSuggestions = false;
  bool _isLoading = false;
  Position? _userLocation;

  // Filter states
  double? _maxPrice;
  double? _minPrice;
  double? _maxDistance;
  bool? _inStock;
  String _sortBy = 'relevance';

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery ?? '';
    _loadTrendingSearches();
    _getUserLocation();
    
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && widget.showSuggestions) {
        _showSuggestions = true;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        return;
      }

      _userLocation = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting user location: $e');
    }
  }

  Future<void> _loadTrendingSearches() async {
    try {
      _trendingSearches = await SmartSearchEngine.getTrendingSearches();
      setState(() {});
    } catch (e) {
      print('Error loading trending searches: $e');
    }
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    try {
      _suggestions = await SmartSearchEngine.getSearchSuggestions(query);
      setState(() {
        _showSuggestions = true;
      });
    } catch (e) {
      print('Error getting search suggestions: $e');
    }
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _showSuggestions = false;
    });

    // Save search query
    SmartSearchEngine.saveSearchQuery(query);

    // Perform search with filters
    widget.onSearch?.call(query);

    setState(() {
      _isLoading = false;
    });
  }

  void _selectSuggestion(String suggestion) {
    _searchController.text = suggestion;
    _performSearch(suggestion);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cloud.withOpacity(0.3)),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Search products, stores, or categories...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.cloud),
                    suffixIcon: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            onPressed: () => _performSearch(_searchController.text),
                            icon: const Icon(Icons.search, color: AppTheme.deepTeal),
                          ),
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: _performSearch,
                ),
              ),
            ],
          ),
        ),

        // Filters (if enabled)
        if (widget.showFilters) ...[
          const SizedBox(height: 12),
          _buildFilters(),
        ],

        // Suggestions
        if (_showSuggestions && widget.showSuggestions) ...[
          const SizedBox(height: 8),
          _buildSuggestions(),
        ],
      ],
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All', null, Icons.all_inclusive),
          const SizedBox(width: 8),
          _buildFilterChip('Price Low', 'price_low', Icons.arrow_downward),
          const SizedBox(width: 8),
          _buildFilterChip('Price High', 'price_high', Icons.arrow_upward),
          const SizedBox(width: 8),
          _buildFilterChip('Rating', 'rating', Icons.star),
          const SizedBox(width: 8),
          if (_userLocation != null)
            _buildFilterChip('Nearby', 'distance', Icons.location_on),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value, IconData icon) {
    final isSelected = _sortBy == (value ?? 'relevance');
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = value ?? 'relevance';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.deepTeal : AppTheme.cloud.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.deepTeal : AppTheme.cloud.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppTheme.deepTeal,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.deepTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cloud.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_suggestions.isNotEmpty) ...[
            _buildSuggestionSection('Suggestions', _suggestions),
          ],
          if (_trendingSearches.isNotEmpty) ...[
            if (_suggestions.isNotEmpty)
              const Divider(height: 1),
            _buildSuggestionSection('Trending', _trendingSearches),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.cloud,
            ),
          ),
        ),
        ...items.take(5).map((item) => ListTile(
          dense: true,
          leading: const Icon(Icons.search, size: 16),
          title: Text(
            item,
            style: const TextStyle(fontSize: 14),
          ),
          onTap: () => _selectSuggestion(item),
        )),
      ],
    );
  }
} 