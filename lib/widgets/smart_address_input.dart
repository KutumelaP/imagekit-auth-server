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
    
    // Cancel previous search
    _searchTimer?.cancel();
    
    if (query.length < 3) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isLoading = false;
      });
      return;
    }
    
    // Debounce search
    _searchTimer = Timer(Duration(milliseconds: 500), () {
      _searchAddresses(query);
    });
    
    setState(() {
      _isLoading = true;
      _showSuggestions = true;
    });
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _controller.text.length >= 3) {
      setState(() {
        _showSuggestions = true;
      });
    }
  }

  Future<void> _searchAddresses(String query) async {
    try {
      final results = await HereMapsAddressService.searchAddresses(
        query: query,
        countryCode: 'ZA',
        limit: 8,
        latitude: -25.7461, // Default South Africa location (Pretoria)
        longitude: 28.1881,
      );
      
      // Filter for valid South African addresses
      final validAddresses = results.where((address) => 
          HereMapsAddressService.isValidSouthAfricanAddress(address)
      ).toList();
      
      if (mounted) {
        setState(() {
          _suggestions = validAddresses;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Address search error: $e');
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
      }
    }
  }

  void _selectAddress(Map<String, dynamic> address) {
    setState(() {
      _selectedAddress = address;
      _controller.text = HereMapsAddressService.formatAddressForDisplay(address);
      _showSuggestions = false;
    });
    
    _focusNode.unfocus();
    widget.onAddressSelected(address);
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
              hintText: widget.hintText ?? 'Enter your delivery address',
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
          ),
        ),
        
        // Address suggestions
        if (_showSuggestions && _suggestions.isNotEmpty)
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
                  onTap: () => _selectAddress(address),
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