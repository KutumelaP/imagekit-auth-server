import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../services/address_search_service.dart';
import '../theme/app_theme.dart';

class AddressInputField extends StatefulWidget {
  final String? initialValue;
  final String? labelText;
  final String? hintText;
  final Function(String address)? onAddressSelected;
  final Function(String address, double? latitude, double? longitude)? onAddressWithCoords;
  final bool enabled;
  final TextEditingController? controller;
  final bool showUseMyLocation;

  const AddressInputField({
    Key? key,
    this.initialValue,
    this.labelText = 'Address',
    this.hintText = 'Enter your address',
    this.onAddressSelected,
    this.onAddressWithCoords,
    this.enabled = true,
    this.controller,
    this.showUseMyLocation = true,
  }) : super(key: key);

  @override
  State<AddressInputField> createState() => _AddressInputFieldState();
}

class _AddressInputFieldState extends State<AddressInputField> {
  final AddressSearchService _searchService = AddressSearchService();
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  bool _showSuggestions = false;
  bool _isLoading = false;
  bool _isReverseGeocoding = false;

  @override
  void initState() {
    super.initState();
    _textController.text = widget.initialValue ?? '';
    _focusNode.addListener(_onFocusChanged);
    
    // Listen to search service changes
    _searchService.addListener(_onSearchResultsChanged);
    
    // Removed auto-test query to avoid unexpected API calls in production
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _searchService.removeListener(_onSearchResultsChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    print('🔍 Focus change - Has focus: ${_focusNode.hasFocus}, Show suggestions: $_showSuggestions');
    final controller = widget.controller ?? _textController;
    
    // Show suggestions when gaining focus and there's text
    if (_focusNode.hasFocus && controller.text.length >= 2) {
      setState(() {
        _showSuggestions = true;
      });
      // Trigger search if we have text
      if (controller.text.isNotEmpty) {
        _searchService.searchAddresses(controller.text);
      }
    } else if (!_focusNode.hasFocus) {
      // Add a small delay before hiding suggestions to allow for taps
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() {
            _showSuggestions = false;
          });
        }
      });
    }
  }

  void _onSearchResultsChanged() {
    print('🔍 Search update - Loading: ${_searchService.isSearching}, Suggestions: ${_searchService.suggestions.length}, Show: $_showSuggestions');
    setState(() {
      _isLoading = _searchService.isSearching;
      // Keep suggestions visible if we have results or are still searching
      if (_focusNode.hasFocus && (_searchService.suggestions.isNotEmpty || _searchService.isSearching)) {
        _showSuggestions = true;
      }
    });
  }

  void _onTextChanged(String value) {
    print('🔍 Text changed: "$value"');
    print('🔍 Text length: ${value.length}');
    print('🔍 Has focus: ${_focusNode.hasFocus}');
    
    // Trigger search
    _searchService.searchAddresses(value);
    
    // Update UI state - show suggestions if we have focus and enough text
    if (_focusNode.hasFocus && value.length >= 2) {
      setState(() {
        _showSuggestions = true;
      });
    } else if (value.length < 2) {
      setState(() {
        _showSuggestions = false;
      });
    }
  }

  Future<void> _useMyLocation() async {
    // Skip geolocation on web platform
    if (kIsWeb) {
      print('🔍 Geolocation not supported on web platform');
      // Show a helpful message for web users
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your address manually on web platform'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      setState(() { _isReverseGeocoding = true; });
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        setState(() { _isReverseGeocoding = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 6));
      // Use Nominatim reverse via AddressSearchService's public method if added in future
      // For now, create a suggestion with coordinates and let parent do map confirm
      final approx = 'Current location (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})';
      final controller = widget.controller ?? _textController;
      controller.text = approx;
      widget.onAddressWithCoords?.call(approx, pos.latitude, pos.longitude);
    } catch (e) {
      // Ignore errors silently; user can still type
    } finally {
      if (mounted) setState(() { _isReverseGeocoding = false; });
    }
  }

  int _getItemCount() {
    if (_searchService.suggestions.isEmpty && !_searchService.isSearching) {
      return 1; // Only show "No results" option
    }
    return _searchService.suggestions.length + 1; // +1 for "Use entered address"
  }

  Widget _buildNoResultsOption() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.search_off,
              size: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No address suggestions found',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onAddressSelected(String address) {
    print('🔍 Address selected: $address');
    
    // Use the correct controller (external or internal)
    final controller = widget.controller ?? _textController;
    print('🔍 Controller type: ${controller.runtimeType}');
    print('🔍 Controller text before: "${controller.text}"');
    
    controller.text = address;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: address.length),
    );
    
    print('🔍 Controller text after: "${controller.text}"');
    
    // Hide suggestions immediately
    setState(() {
      _showSuggestions = false;
    });
    
    // Remove focus to prevent further focus changes
    _focusNode.unfocus();
    
    print('🔍 Calling onAddressSelected callback');
    widget.onAddressSelected?.call(address);
    // Try to pass coordinates if we can match the suggestion label
    try {
      final suggestion = _searchService.suggestions.firstWhere(
        (s) => s.label == address,
        orElse: () => AddressSuggestion(
          label: address,
          street: address,
          locality: '',
          administrativeArea: '',
          postalCode: '',
          latitude: null,
          longitude: null,
        ),
      );
      widget.onAddressWithCoords?.call(address, suggestion.latitude, suggestion.longitude);
    } catch (_) {}
    print('🔍 Address selection completed');
  }

  void _onUseEnteredAddress() {
    final controller = widget.controller ?? _textController;
    final enteredAddress = controller.text.trim();
    if (enteredAddress.isNotEmpty) {
      widget.onAddressSelected?.call(enteredAddress);
      setState(() {
        _showSuggestions = false;
      });
      // Remove focus to prevent further focus changes
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the bottom padding to account for keyboard
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Address Input Field
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focusNode.hasFocus ? AppTheme.deepTeal : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: widget.controller ?? _textController,
            focusNode: _focusNode,
            enabled: widget.enabled,
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              prefixIcon: Icon(
                Icons.location_on,
                color: _focusNode.hasFocus ? AppTheme.deepTeal : Colors.grey.shade600,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showUseMyLocation)
                    IconButton(
                      tooltip: 'Use my location',
                      icon: _isReverseGeocoding 
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal)))
                        : const Icon(Icons.my_location, color: AppTheme.deepTeal, size: 20),
                      onPressed: _isReverseGeocoding ? null : _useMyLocation,
                    ),
                  _buildSuffixIcon(),
                ],
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            onChanged: _onTextChanged,
            onTap: () {
              if (_searchService.suggestions.isNotEmpty) {
                setState(() {
                  _showSuggestions = true;
                });
              }
            },
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Suggestions Dropdown - Only show if keyboard is not covering too much
        if (_showSuggestions && bottomPadding < 200) _buildSuggestionsDropdown(),
      ],
    );
  }

  Widget _buildSuffixIcon() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
          ),
        ),
      );
    }
    
    final controller = widget.controller ?? _textController;
    if (controller.text.isNotEmpty) {
      return IconButton(
        icon: const Icon(Icons.clear, color: Colors.grey),
        onPressed: () {
          controller.clear();
          _searchService.clearSearch();
          setState(() {
            _showSuggestions = false;
          });
        },
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildSuggestionsDropdown() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.deepTeal.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: 16,
                  color: AppTheme.deepTeal,
                ),
                const SizedBox(width: 8),
                Text(
                  'Address Suggestions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.deepTeal,
                  ),
                ),
              ],
            ),
          ),
          
          // Suggestions List
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _getItemCount(),
              itemBuilder: (context, index) {
                if (_searchService.suggestions.isEmpty && !_searchService.isSearching) {
                  // No results found
                  return _buildNoResultsOption();
                } else if (index == _searchService.suggestions.length) {
                  // "Use entered address" option
                  return _buildUseEnteredAddressOption();
                }
                
                 final suggestion = _searchService.suggestions[index];
                 final address = suggestion.label;
                return _buildSuggestionItem(address);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatPlacemark(Placemark placemark) {
    final parts = <String>[];
    if (placemark.street?.isNotEmpty == true) parts.add(placemark.street!);
    if (placemark.locality?.isNotEmpty == true) parts.add(placemark.locality!);
    if (placemark.administrativeArea?.isNotEmpty == true) parts.add(placemark.administrativeArea!);
    if (placemark.country?.isNotEmpty == true) parts.add(placemark.country!);
    return parts.join(', ');
  }

  Widget _buildSuggestionItem(String address) {
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          print('🔍 InkWell tap detected on address suggestion: $address');
          // Prevent focus loss during tap
          _focusNode.requestFocus();
          // Small delay to ensure tap is processed
          Future.delayed(const Duration(milliseconds: 50), () {
            _onAddressSelected(address);
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.deepTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.location_on,
                  size: 16,
                  color: AppTheme.deepTeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUseEnteredAddressOption() {
    final controller = widget.controller ?? _textController;
    final enteredAddress = controller.text.trim();
    if (enteredAddress.isEmpty) return const SizedBox.shrink();
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          print('🔍 InkWell tap detected on "Use entered address"');
          // Prevent focus loss during tap
          _focusNode.requestFocus();
          // Small delay to ensure tap is processed
          Future.delayed(const Duration(milliseconds: 50), () {
            _onUseEnteredAddress();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit_location,
                  size: 16,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Use entered address',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      enteredAddress,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 