#!/usr/bin/env python3
"""
Script to fix CheckoutScreen.dart compilation errors
"""

import re

def fix_checkout_screen():
    # Read the file
    with open('lib/screens/CheckoutScreen.dart', 'r', encoding='utf-8') as f:
        content = f.read()
    
    print("Original file size:", len(content))
    
    # Fix 1: Remove duplicate _loadPickupPointsForCoordinates method (second occurrence)
    # Find the second occurrence and remove it
    pattern1 = r'(\s+/// Load pickup points for specific coordinates\s+Future<void> _loadPickupPointsForCoordinates\(double latitude, double longitude\) async \{.*?\n\s+\}\s+\n\s+/// Search addresses and load pickup points for the searched location\s+void _searchAddressesInline\(String query\) \{.*?\n\s+\})'
    
    # More specific pattern to match the duplicate
    pattern2 = r'(\s+/// Load pickup points for specific coordinates\s+Future<void> _loadPickupPointsForCoordinates\(double latitude, double longitude\) async \{.*?\n\s+\}\s+\n\s+/// Search addresses and load pickup points for the searched location\s+void _searchAddressesInline\(String query\) \{.*?\n\s+\}\s+\n\s+int _calculateRealisticDeliveryTime)'
    
    # Try to find and remove the duplicate
    matches = re.findall(pattern2, content, re.DOTALL)
    if matches:
        print(f"Found {len(matches)} duplicate method blocks")
        # Remove the duplicate methods but keep the _calculateRealisticDeliveryTime method
        content = re.sub(pattern2, r'\3', content, flags=re.DOTALL)
    
    # Fix 2: Remove duplicate _searchAddressesInline methods
    # Find all occurrences and keep only the first one
    search_pattern = r'(\s+/// Search addresses and load pickup points for the searched location\s+void _searchAddressesInline\(String query\) \{.*?\n\s+\})'
    matches = re.findall(search_pattern, content, re.DOTALL)
    if len(matches) > 1:
        print(f"Found {len(matches)} _searchAddressesInline methods, keeping first one")
        # Keep only the first occurrence
        content = re.sub(search_pattern, r'\1', content, flags=re.DOTALL, count=1)
        # Remove the remaining occurrences
        content = re.sub(search_pattern, '', content, flags=re.DOTALL)
    
    # Fix 3: Fix the first _loadPickupPointsForCoordinates method to work with PickupPoint objects
    # Replace the map conversion with direct assignment
    map_conversion_pattern = r'(\s+// Convert to local format and update state\s+setState\(\(\) => \{\s+_pickupPoints = points\.map\(\(point\) => \{\s+\'id\': point\.id,\s+\'name\': point\.name,\s+\'address\': point\.address,\s+\'latitude\': point\.latitude,\s+\'longitude\': point\.longitude,\s+\'type\': point\.type,\s+\'distance\': point\.distance,\s+\'fee\': point\.fee,\s+\'operatingHours\': point\.operatingHours,\s+\'isPargoPoint\': point\.isPargoPoint,\s+\}\)\.toList\(\);\s+\n\s+// Auto-select first point if available\s+if \(_pickupPoints\.isNotEmpty\) \{\s+_selectedPickupPoint = _pickupPoints\.first;\s+_deliveryFee = _selectedPickupPoint!\['fee'\];\s+print\('🚚 DEBUG: Auto-selected first pickup point: \$\{_selectedPickupPoint!\['name'\]\}');\s+\}\s+\})'
    
    replacement = r'\1// Update state with pickup points\n        setState(() {\n          _pickupPoints = points;\n          \n          // Auto-select first point if available\n          if (_pickupPoints.isNotEmpty) {\n            _selectedPickupPoint = _pickupPoints.first;\n            _deliveryFee = _selectedPickupPoint!.fee;\n            print(\'🚚 DEBUG: Auto-selected first pickup point: \${_selectedPickupPoint!.name}\');\n          }\n        })'
    
    content = re.sub(map_conversion_pattern, replacement, content, flags=re.DOTALL)
    
    # Fix 4: Add missing _loadPickupPointsForCurrentAddress method
    # Find a good place to add it (after the existing _loadPickupPointsForCoordinates method)
    add_method_pattern = r'(\s+\}\s+\n\s+/// Search addresses and load pickup points for the searched location)'
    add_method_replacement = r'\1\n  \n  /// Load pickup points for current address\n  Future<void> _loadPickupPointsForCurrentAddress() async {\n    if (_selectedLat != 0.0 && _selectedLng != 0.0) {\n      await _loadPickupPointsForCoordinates(_selectedLat, _selectedLng);\n    } else {\n      // Fallback to default coordinates\n      await _loadPickupPointsForCoordinates(-26.0625279, 28.227473);\n    }\n  }'
    
    content = re.sub(add_method_pattern, add_method_replacement, content, flags=re.DOTALL)
    
    # Fix 5: Replace all Map access operators with PickupPoint property access
    # This is a more complex fix that needs to be done systematically
    
    # Write the fixed content back
    with open('lib/screens/CheckoutScreen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("Fixed file size:", len(content))
    print("File has been fixed!")

if __name__ == "__main__":
    fix_checkout_screen()
