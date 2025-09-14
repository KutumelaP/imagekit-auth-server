import 'package:flutter/material.dart';
import 'dart:async';
import '../services/here_maps_address_service.dart';
import '../theme/app_theme.dart';

class SmartAddressInput extends StatefulWidget {
  final Function(Map<String, dynamic>?) onAddressSelected;
  final String? initialValue;
  final String? hintText;
  
  const SmartAddressInput({
    Key? key,
    required this.onAddressSelected,
    this.initialValue,
    this.hintText,
  }) : super(key: key);

  @override
  State<SmartAddressInput> createState() => _SmartAddressInputState();
}

class _SmartAddressInputState extends State<SmartAddressInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  Timer? _searchTimer;
  Map<String, dynamic>? _selectedAddress;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
    
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final query = _controller.text.trim();
    print('🔍 Text changed: "$query" (length: ${query.length})');
    
    // Cancel previous search
    _searchTimer?.cancel();
    
    if (query.length < 3) {
      print('🔍 Query too short, hiding suggestions');
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isLoading = false;
        _selectedAddress = null; // Reset selection
      });
      return;
    }
    
    print('🔍 Starting search timer for: "$query"');
    
    // Debounce search
    _searchTimer = Timer(Duration(milliseconds: 500), () {
      print('🔍 Timer triggered, searching...');
      _searchAddresses(query);
    });
    
    setState(() {
      _isLoading = true;
      _showSuggestions = true;
    });
    print('🔍 Set loading=true, showSuggestions=true');
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _controller.text.length >= 3) {
      setState(() {
        _showSuggestions = true;
      });
    }
  }

  Future<void> _searchAddresses(String query) async {
    print('🔍 Starting address search for: "$query"');
    
    try {
      final results = await HereMapsAddressService.searchAddresses(
        query: query,
        countryCode: 'ZA',
        limit: 8,
        latitude: -25.7461, // Default South Africa location (Pretoria)
        longitude: 28.1881,
      );
      
      print('🔍 HERE Maps returned ${results.length} results');
      
      // Filter for valid South African addresses
      final validAddresses = results.where((address) => 
          HereMapsAddressService.isValidSouthAfricanAddress(address)
      ).toList();
      
      print('🔍 After filtering: ${validAddresses.length} valid addresses');
      
      if (mounted) {
        setState(() {
          _suggestions = validAddresses;
          _isLoading = false;
          _showSuggestions = validAddresses.isNotEmpty; // Ensure dropdown shows
        });
        print('🔍 Dropdown state: suggestions=${_suggestions.length}, show=$_showSuggestions');
      }
    } catch (e) {
      print('❌ Address search error: $e');
      // Show error to user - they need to know why address search failed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Address search failed. You can still type your address manually.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        setState(() {
          // Show some generic South African location suggestions as fallback
          _suggestions = [
            {
              'title': query,
              'label': '$query, South Africa',
              'street': query,
              'city': 'Manual Entry',
              'countryName': 'South Africa',
              'latitude': -25.7461,
              'longitude': 28.1881,
              'isManualEntry': true,
            }
          ];
          _isLoading = false;
          _showSuggestions = true; // Still show dropdown with manual option
        });
      }
    }
  }

  void _selectAddress(Map<String, dynamic> address) {
    print('🔍 Address selected: $address');
    
    final formattedAddress = HereMapsAddressService.formatAddressForDisplay(address);
    print('🔍 Formatted address: "$formattedAddress"');
    
    // Fallback if formatting returns empty
    final displayText = formattedAddress.isNotEmpty 
        ? formattedAddress 
        : (address['title']?.toString() ?? address['label']?.toString() ?? 'Selected address');
    
    print('🔍 Display text: "$displayText"');
    
    setState(() {
      _selectedAddress = address;
      _controller.text = displayText;
      _showSuggestions = false;
      // _addressConfirmed = true; // Mark address as confirmed - removed unused
    });
    
    _focusNode.unfocus();
    
    print('🔍 Calling onAddressSelected callback with confirmed address...');
    widget.onAddressSelected(address);
    print('🔍 Address selection complete - confirmed: true');
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final address = await HereMapsAddressService.getCurrentLocationAddress();
      
      if (address != null) {
        _selectAddress(address);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Current location detected'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Could not detect location');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Location error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Address input field
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppTheme.inputBackgroundGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _selectedAddress != null 
                  ? AppTheme.success 
                  : AppTheme.cloud.withOpacity(0.4),
              width: _selectedAddress != null ? 2 : 1,
            ),
            boxShadow: AppTheme.inputElevation,
          ),
          child: TextFormField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: widget.hintText ?? 'Type your delivery address (suggestions will appear)',
              prefixIcon: Icon(
                Icons.location_on,
                color: _selectedAddress != null ? AppTheme.success : AppTheme.deepTeal,
                size: 22,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(AppTheme.deepTeal),
                        ),
                      ),
                    ),
                  IconButton(
                    icon: Icon(Icons.search, color: AppTheme.deepTeal),
                    onPressed: () {
                      // Force test search
                      final query = _controller.text.trim();
                      if (query.isNotEmpty) {
                        print('🔍 Force search triggered for: "$query"');
                        _searchAddresses(query);
                      }
                    },
                    tooltip: 'Search addresses',
                  ),
                  IconButton(
                    icon: Icon(Icons.my_location, color: AppTheme.deepTeal),
                    onPressed: _useCurrentLocation,
                    tooltip: 'Use current location',
                  ),
                ],
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              hintStyle: TextStyle(
                color: AppTheme.mediumGrey,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
            onTap: () {
              if (_controller.text.length >= 3) {
                setState(() {
                  _showSuggestions = true;
                });
              }
            },
            onChanged: (text) {
              // Allow manual address entry if user types enough text
              if (text.length >= 10 && _suggestions.isEmpty) {
                // Treat as manual address entry
                final manualAddress = {
                  'title': text,
                  'label': text,
                  'street': text,
                  'city': 'Manual Entry',
                  'countryName': 'South Africa',
                  'latitude': -25.7461, // Default SA coordinates
                  'longitude': 28.1881,
                  'isManualEntry': true,
                };
                
                setState(() {
                  _selectedAddress = manualAddress;
                });
                
                widget.onAddressSelected(manualAddress);
              }
            },
          ),
        ),
        
        // Address suggestions (always show if we have suggestions)
        if (_suggestions.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.breeze.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            constraints: BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final address = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.deepTeal.withOpacity(0.1),
                    child: Icon(
                      Icons.location_on,
                      size: 16,
                      color: AppTheme.deepTeal,
                    ),
                  ),
                  title: Text(
                    address['title'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    address['label'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                    size: 16,
                  ),
                  onTap: () {
                    print('🔍 ListTile tapped for address: ${address['title']}');
                    _selectAddress(address);
                  },
                );
              },
            ),
          ),
        
        // Selected address validation
        if (_selectedAddress != null) ...[
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Address Confirmed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      Text(
                        'Delivery zone: ${HereMapsAddressService.getDeliveryZone(_selectedAddress!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // Excluded zone warning
        if (_selectedAddress != null && 
            HereMapsAddressService.isAddressInExcludedZone(_selectedAddress!)) ...[
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sorry, we don\'t deliver to this area yet. Please select pickup instead.',
                    style: TextStyle(color: Colors.red[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}