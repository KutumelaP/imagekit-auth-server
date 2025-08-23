import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';

class PaxiStoreLocatorWidget extends StatefulWidget {
  final String? initialAddress;
  final Function(String address, double lat, double lng)? onLocationSelected;
  
  const PaxiStoreLocatorWidget({
    Key? key,
    this.initialAddress,
    this.onLocationSelected,
  }) : super(key: key);

  @override
  State<PaxiStoreLocatorWidget> createState() => _PaxiStoreLocatorWidgetState();
}

class _PaxiStoreLocatorWidgetState extends State<PaxiStoreLocatorWidget> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  String? _selectedAddress;
  double? _selectedLat;
  double? _selectedLng;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            // Handle navigation requests
            if (request.url.contains('paxi.co.za')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.paxi.co.za/pickup-points'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PAXI Store Locator',
          style: TextStyle(
            color: AppTheme.deepTeal,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.angel,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.deepTeal),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_selectedAddress != null)
            TextButton(
              onPressed: _confirmSelection,
              child: Text(
                'Select Location',
                style: TextStyle(
                  color: AppTheme.deepTeal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // PAXI Information Header
          Container(
            padding: EdgeInsets.all(16),
            color: AppTheme.whisper,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.deepTeal),
                    SizedBox(width: 8),
                    Text(
                      'PAXI Pickup Points',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepTeal,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Find the nearest PAXI pickup point. PAXI is available at PEP, Shoe City, Tekkie Town, and other partner stores nationwide.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.deepTeal.withOpacity(0.8),
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.store, color: AppTheme.cloud, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'PEP, Shoe City, Tekkie Town',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.deepTeal.withOpacity(0.7),
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.access_time, color: AppTheme.cloud, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '7-9 business days',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.deepTeal.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // WebView for PAXI Store Locator
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _webViewController),
                if (_isLoading)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepTeal),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading PAXI Store Locator...',
                          style: TextStyle(
                            color: AppTheme.deepTeal,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Manual Location Input (Fallback)
          Container(
            padding: EdgeInsets.all(16),
            color: AppTheme.angel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Or enter location manually:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.deepTeal,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Enter your address or suburb',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _selectedAddress = value;
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _searchManualLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.deepTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Search'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _searchManualLocation() {
    if (_selectedAddress != null && _selectedAddress!.isNotEmpty) {
      // Here you would typically geocode the address
      // For now, we'll use placeholder coordinates
      _selectedLat = -26.2041; // Johannesburg coordinates as example
      _selectedLng = 28.0473;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location set to: $_selectedAddress'),
          backgroundColor: AppTheme.deepTeal,
        ),
      );
    }
  }

  void _confirmSelection() {
    if (_selectedAddress != null && _selectedLat != null && _selectedLng != null) {
      widget.onLocationSelected?.call(_selectedAddress!, _selectedLat!, _selectedLng!);
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a location first'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
