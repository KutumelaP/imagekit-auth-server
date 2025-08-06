import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../theme/app_theme.dart';

class EnhancedAddressInput extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final Function(String)? onAddressSelected;
  final bool showCurrentLocationButton;
  final bool showSuggestions;

  const EnhancedAddressInput({
    Key? key,
    required this.controller,
    this.hintText = 'Enter your address',
    this.onAddressSelected,
    this.showCurrentLocationButton = true,
    this.showSuggestions = true,
  }) : super(key: key);

  @override
  State<EnhancedAddressInput> createState() => _EnhancedAddressInputState();
}

class _EnhancedAddressInputState extends State<EnhancedAddressInput> {
  List<String> _suggestions = [];
  bool _isLoadingLocation = false;
  bool _showSuggestions = false;
  FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && widget.showSuggestions) {
        _showSuggestions = true;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackBar('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackBar('Location permission permanently denied');
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = _formatAddress(place);
        widget.controller.text = address;
        widget.onAddressSelected?.call(address);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to get current location: $e');
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  String _formatAddress(Placemark place) {
    List<String> parts = [];
    
    if (place.street?.isNotEmpty == true) {
      parts.add(place.street!);
    }
    if (place.subLocality?.isNotEmpty == true) {
      parts.add(place.subLocality!);
    }
    if (place.locality?.isNotEmpty == true) {
      parts.add(place.locality!);
    }
    if (place.administrativeArea?.isNotEmpty == true) {
      parts.add(place.administrativeArea!);
    }
    if (place.postalCode?.isNotEmpty == true) {
      parts.add(place.postalCode!);
    }

    return parts.join(', ');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _onAddressChanged(String value) async {
    if (value.length < 3) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    try {
      List<Location> locations = await locationFromAddress(value);
      List<String> suggestions = [];
      
      for (Location location in locations.take(5)) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          suggestions.add(_formatAddress(placemarks[0]));
        }
      }

      setState(() {
        _suggestions = suggestions;
        _showSuggestions = true;
      });
    } catch (e) {
      // Handle geocoding errors silently
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
    }
  }

  void _selectSuggestion(String address) {
    widget.controller.text = address;
    widget.onAddressSelected?.call(address);
    setState(() {
      _showSuggestions = false;
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  controller: widget.controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: widget.showCurrentLocationButton
                        ? IconButton(
                            onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                            icon: _isLoadingLocation
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location),
                          )
                        : null,
                  ),
                  onChanged: _onAddressChanged,
                ),
              ),
            ],
          ),
        ),
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
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
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on, size: 16),
                  title: Text(
                    _suggestions[index],
                    style: const TextStyle(fontSize: 14),
                  ),
                  onTap: () => _selectSuggestion(_suggestions[index]),
                );
              },
            ),
          ),
      ],
    );
  }
} 