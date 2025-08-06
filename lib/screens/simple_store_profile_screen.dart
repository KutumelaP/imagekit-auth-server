import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:math' as math;
import 'dart:async';
import '../theme/app_theme.dart';
import '../widgets/safe_network_image.dart';
import 'store_reviews_page.dart';
import 'image_zoom_view.dart'; // Added import for ImageZoomView
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart'; // Added import for share package
import 'package:flutter/services.dart'; // Added import for Clipboard

class SimpleStoreProfileScreen extends StatefulWidget {
  final Map<String, dynamic> store;

  const SimpleStoreProfileScreen({super.key, required this.store});

  @override
  State<SimpleStoreProfileScreen> createState() => _SimpleStoreProfileScreenState();
}

class _SimpleStoreProfileScreenState extends State<SimpleStoreProfileScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  bool _isVideoPlaying = false;
  
  // Responsive design variables
  bool get isMobile => MediaQuery.of(context).size.width < 600;
  bool get isTablet => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 900;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  // Performance optimization variables
  final ScrollController _scrollController = ScrollController();
  bool _isScrolling = false;
  Timer? _scrollTimer;
  
  // Cache for gallery data to prevent unnecessary rebuilds
  Map<String, dynamic>? _cachedStoreData;
  bool _isLoadingGalleryData = false;
  
  // Cache for live stats to prevent unnecessary rebuilds (kept for function compatibility)
  Map<String, dynamic>? _cachedLiveStats;
  Timer? _statsDebounceTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeVideo();
    _loadGalleryData(); // Load fresh data when navigating to the screen
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  void _initializeVideo() {
    final videoUrl = widget.store['storyVideoUrl'] ?? widget.store['introVideoUrl'] as String?;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      _videoController = VideoPlayerController.network(videoUrl);
      _videoController?.initialize().then((_) {
        if (mounted && _videoController != null) {
          setState(() {
            _isVideoInitialized = true;
            _chewieController = ChewieController(
              videoPlayerController: _videoController!,
              autoPlay: false,
              looping: false,
              allowFullScreen: true,
              allowMuting: true,
              showControls: true,
              materialProgressColors: ChewieProgressColors(
                playedColor: AppTheme.deepTeal,
                handleColor: AppTheme.deepTeal,
                backgroundColor: AppTheme.cloud,
                bufferedColor: AppTheme.deepTeal.withOpacity(0.5),
              ),
            );
          });
          
          // Listen to video state changes for performance optimization
          _videoController!.addListener(_onVideoStateChanged);
        }
      }).catchError((error) {
        print('❌ Error initializing video: $error');
        _videoController?.dispose();
        _videoController = null;
      });
    }
  }

  Future<void> _loadGalleryData() async {
    if (_cachedStoreData != null || _isLoadingGalleryData) return;
    
    final storeId = widget.store['storeId'] as String?;
    if (storeId == null) return;
    
    setState(() {
      _isLoadingGalleryData = true;
    });
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(storeId).get();
      if (doc.exists) {
        setState(() {
          _cachedStoreData = doc.data();
          _isLoadingGalleryData = false;
        });
      }
    } catch (e) {
      print('🔍 DEBUG: Error loading gallery data: $e');
      setState(() {
        _isLoadingGalleryData = false;
      });
    }
  }

  void _onVideoStateChanged() {
    if (_videoController != null) {
      final isPlaying = _videoController!.value.isPlaying;
      if (isPlaying != _isVideoPlaying) {
        setState(() {
          _isVideoPlaying = isPlaying;
        });
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    _scrollController.dispose();
    _scrollTimer?.cancel();
    _statsDebounceTimer?.cancel();
    super.dispose();
  }

  void _pauseVideoIfScrolling() {
    if (_isScrolling && _isVideoPlaying) {
      _videoController?.pause();
      setState(() {
        _isVideoPlaying = false;
      });
    }
  }

  void _handleScroll() {
    _isScrolling = true;
    _pauseVideoIfScrolling();
    
    _scrollTimer?.cancel();
    _scrollTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _isScrolling = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    // Debug: Print the store data being passed
    print('🔍 DEBUG: SimpleStoreProfileScreen build with store data:');
    print('  - storeName: ${widget.store['storeName']}');
    print('  - story: ${widget.store['story']}');
    print('  - storyPhotoUrls: ${widget.store['storyPhotoUrls']}');
    print('  - extraPhotoUrls: ${widget.store['extraPhotoUrls']}');
    print('  - storyVideoUrl: ${widget.store['storyVideoUrl']}');
    print('  - introVideoUrl: ${widget.store['introVideoUrl']}');
    print('  - passion: ${widget.store['passion']}');
    print('  - specialties: ${widget.store['specialties']}');
    
    return Scaffold(
      backgroundColor: AppTheme.angel,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              _handleScroll();
              return false;
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildStunningAppBar(),
                SliverToBoxAdapter(child: _buildHeroSection()),
                SliverToBoxAdapter(child: _buildStoreInfo()),
                SliverToBoxAdapter(child: _buildStorySection()),
                SliverToBoxAdapter(child: _buildSpecialtiesSection()),
                SliverToBoxAdapter(child: _buildGallerySection()),
                SliverToBoxAdapter(child: _buildVideoSection()),
                SliverToBoxAdapter(child: _buildReviewsSection()),
                SliverToBoxAdapter(child: _buildQuickActions()),
                // SliverToBoxAdapter(child: _buildLiveStats()), // Live stats removed
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStunningAppBar() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return SliverAppBar(
      expandedHeight: isMobile ? 250 : (isTablet ? 300 : 350),
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.deepTeal,
      foregroundColor: AppTheme.angel,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            setState(() {
              _cachedStoreData = null; // Clear cache
            });
            _loadGalleryData(); // Reload fresh data
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Refreshing store data...'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          tooltip: 'Refresh Data',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.store['storeName'] ?? 'Store',
          style: TextStyle(
            color: AppTheme.angel,
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 16 : 18,
            shadows: [
              Shadow(
                color: Colors.black54,
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Store image with gradient overlay
            if (widget.store['profileImageUrl'] != null)
              SafeStoreImage(
                imageUrl: widget.store['profileImageUrl'],
                width: double.infinity,
                height: double.infinity,
                borderRadius: BorderRadius.zero,
              ),
            
            // Gradient overlay for better text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            
            // Floating action elements
            Positioned(
              top: 60,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _getStoreType(),
                  style: const TextStyle(
                    color: AppTheme.angel,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final storeName = widget.store['storeName'] as String? ?? 'Store Name';
    final category = widget.store['category'] as String? ?? 'General';
    final isVerified = widget.store['isVerified'] as bool? ?? false;
    
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    storeName,
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepTeal,
                    ),
                  ),
                ),
                if (isVerified)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreInfo() {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppTheme.cardBackgroundGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepTeal.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Store Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Location', widget.store['location'] ?? 'Not specified', Icons.location_on),
            _buildInfoRow('Contact', widget.store['contact'] ?? 'Not specified', Icons.phone),
            
            // Store Status and Delivery Information
            const SizedBox(height: 12),
            Row(
              children: [
                // Store Status Badge
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: (widget.store['isStoreOpen'] == true) 
                        ? AppTheme.primaryGreen.withOpacity(0.1)
                        : AppTheme.primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (widget.store['isStoreOpen'] == true) 
                          ? AppTheme.primaryGreen
                          : AppTheme.primaryRed,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (widget.store['isStoreOpen'] == true) 
                            ? Icons.store
                            : Icons.store_mall_directory,
                          size: 14,
                          color: (widget.store['isStoreOpen'] == true) 
                            ? AppTheme.primaryGreen
                            : AppTheme.primaryRed,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (widget.store['isStoreOpen'] == true) ? 'Store Open' : 'Store Closed',
                          style: TextStyle(
                            color: (widget.store['isStoreOpen'] == true) 
                              ? AppTheme.primaryGreen
                              : AppTheme.primaryRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Delivery Range Badge
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: (widget.store['deliveryAvailable'] == true) 
                        ? AppTheme.deepTeal.withOpacity(0.1)
                        : AppTheme.mediumGrey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (widget.store['deliveryAvailable'] == true) 
                          ? AppTheme.deepTeal
                          : AppTheme.mediumGrey,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (widget.store['deliveryAvailable'] == true)
                            ? Icons.delivery_dining
                            : Icons.store,
                          size: 14,
                          color: (widget.store['deliveryAvailable'] == true) 
                            ? AppTheme.deepTeal
                            : AppTheme.mediumGrey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (widget.store['deliveryAvailable'] == true) 
                            ? '${(widget.store['distance'] != null ? widget.store['distance'].toStringAsFixed(1) : (widget.store['deliveryRange'] ?? 1000).toStringAsFixed(0))}km away'
                            : 'Pick up',
                          style: TextStyle(
                            color: (widget.store['deliveryAvailable'] == true) 
                              ? AppTheme.deepTeal
                              : AppTheme.mediumGrey,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Operating Hours Section
            if (widget.store['storeOpenHour'] != null && widget.store['storeCloseHour'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.deepTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.deepTeal,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: AppTheme.deepTeal,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Operating Hours: ${widget.store['storeOpenHour']} - ${widget.store['storeCloseHour']}',
                      style: TextStyle(
                        color: AppTheme.deepTeal,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.cloud),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.cloud,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.deepTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorySection() {
    final story = widget.store['story'] as String?;
    final storyPhotoUrls = widget.store['storyPhotoUrls'] as List<dynamic>?;
    final storyVideoUrl = widget.store['storyVideoUrl'] as String?;
    
    final displayStory = story?.isNotEmpty == true ? story! : 'No story available';
    final hasStoryData = story?.isNotEmpty == true || (storyPhotoUrls?.isNotEmpty == true) || (storyVideoUrl?.isNotEmpty == true);
    
    print('🔍 DEBUG: Story section data:');
    print('  - story: $story');
    print('  - displayStory: $displayStory');
    print('  - storyPhotoUrls: $storyPhotoUrls');
    print('  - storyVideoUrl: $storyVideoUrl');
    print('  - hasStoryData: $hasStoryData');
    print('  - Will show story section: $hasStoryData');
    
    if (!hasStoryData) return const SizedBox.shrink();
    
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.book, color: AppTheme.deepTeal, size: 20),
                const SizedBox(width: 8),
                Text('Our Story', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.deepTeal)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cloud,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                displayStory,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: AppTheme.deepTeal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGallerySection() {
    final storeId = widget.store['storeId'] as String?;
    final category = widget.store['category'] as String?;
    
    if (storeId == null) return const SizedBox.shrink();
    
    // Load gallery data if not cached
    if (_cachedStoreData == null && !_isLoadingGalleryData) {
      _loadGalleryData();
    }
    
    // Show loading indicator while fetching data
    if (_isLoadingGalleryData) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Use cached data or fallback to widget.store data
    final storeData = _cachedStoreData ?? widget.store;
    
    final storyPhotoUrls = storeData['storyPhotoUrls'] as List?;
    final extraPhotoUrls = storeData['extraPhotoUrls'] as List?;
    final photoCaptions = storeData['photoCaptions'] as List?;
    final behindTheScenes = storeData['behindTheScenes'] as Map<String, dynamic>?;
    
    List<String> displayPhotos = [];
    
    // First priority: story photos from store data
    if (storyPhotoUrls?.isNotEmpty == true) {
      displayPhotos = storyPhotoUrls!.map((url) => url.toString()).toList();
    }
    // Second priority: extraPhotoUrls from store data (max 2)
    else if (extraPhotoUrls?.isNotEmpty == true) {
      displayPhotos = extraPhotoUrls!
          .map((url) => url.toString())
          .where((url) => url.isNotEmpty)
          .take(2) // Limit to 2 images
          .toList();
    }
    // Last resort: sample photos only if no real images
    else {
      displayPhotos = _generateSamplePhotos(category);
    }
        
        // Always show gallery if we have photos or video
        final hasGalleryData = displayPhotos.isNotEmpty || 
                              (storeData['storyVideoUrl'] != null && storeData['storyVideoUrl'].toString().isNotEmpty);
        
        print('🔍 DEBUG: hasGalleryData: $hasGalleryData');
        print('🔍 DEBUG: Will show gallery section: $hasGalleryData');
        
        if (!hasGalleryData) return const SizedBox.shrink();
    
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.deepTeal.withOpacity(0.1),
              AppTheme.primaryGreen.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.deepTeal.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.deepTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.photo_library,
                    color: AppTheme.deepTeal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Behind the Scenes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (displayPhotos.isNotEmpty) ...[
              SizedBox(
                height: ResponsiveUtils.isMobile(context) ? 150 : 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: displayPhotos.length,
                  itemBuilder: (context, index) {
                    final photoUrl = displayPhotos[index];
                    print('🔍 DEBUG: Displaying photo $index: $photoUrl');
                    return Container(
                      width: ResponsiveUtils.isMobile(context) ? 150 : 200,
                      margin: EdgeInsets.only(right: ResponsiveUtils.isMobile(context) ? 8 : 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SafeNetworkImage(
                          imageUrl: photoUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: AppTheme.cloud,
                            child: Icon(
                              Icons.image,
                              color: AppTheme.deepTeal,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.cloud,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.deepTeal.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        color: AppTheme.deepTeal,
                        size: 48,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No photos available yet',
                        style: TextStyle(
                          color: AppTheme.deepTeal,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }



  void _showImageZoom(String currentImageUrl, List<String> allImages, int currentIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImageZoomView(
          images: allImages,
          initialIndex: currentIndex,
        ),
      ),
    );
  }

  // Helper method to generate sample photos
  Future<List<String>> _fetchProductImages(String storeId) async {
    try {
      print('🔍 DEBUG: _fetchProductImages called with storeId: $storeId');
      
      // Get user document to access extraPhotoUrls
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(storeId)
          .get();

      if (!userDoc.exists) {
        print('🔍 DEBUG: User document not found for storeId: $storeId');
        return [];
      }

      final userData = userDoc.data()!;
      final extraPhotoUrls = userData['extraPhotoUrls'] as List<dynamic>?;
      
      print('🔍 DEBUG: Found extraPhotoUrls: $extraPhotoUrls');
      
      if (extraPhotoUrls == null || extraPhotoUrls.isEmpty) {
        print('🔍 DEBUG: No extraPhotoUrls found for store $storeId');
        return [];
      }

      // Convert to List<String> and take max 2 images
      final List<String> photoImages = extraPhotoUrls
          .map((url) => url.toString())
          .where((url) => url.isNotEmpty)
          .take(2) // Limit to 2 images
          .toList();

      print('🔍 DEBUG: Fetched ${photoImages.length} extra photo images for store $storeId');
      print('🔍 DEBUG: Photo images: $photoImages');
      return photoImages;
    } catch (e) {
      print('🔍 DEBUG: Error fetching extra photo images: $e');
      return [];
    }
  }

  List<String> _generateSamplePhotos(String? category) {
    // Generate placeholder images based on category
    switch (category?.toLowerCase()) {
      case 'food':
      case 'groceries':
        return [
          'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=400&h=300&fit=crop',
          'https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=400&h=300&fit=crop',
        ];
      case 'clothes':
      case 'fashion':
        return [
          'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400&h=300&fit=crop',
          'https://images.unsplash.com/photo-1558769132-cb1aea458c5e?w=400&h=300&fit=crop',
        ];
      case 'electronics':
        return [
          'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=400&h=300&fit=crop',
          'https://images.unsplash.com/photo-1526738549149-8e07eca6c147?w=400&h=300&fit=crop',
        ];
      default:
        return [
          'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=400&h=300&fit=crop',
          'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=400&h=300&fit=crop',
        ];
    }
  }

  Widget _buildVideoSection() {
    // Check for both storyVideoUrl and introVideoUrl
    final videoUrl = widget.store['storyVideoUrl'] ?? widget.store['introVideoUrl'];
    if (videoUrl == null || videoUrl.toString().isEmpty) {
      print('🔍 DEBUG: No video found in store data');
      print('  - storyVideoUrl: ${widget.store['storyVideoUrl']}');
      print('  - introVideoUrl: ${widget.store['introVideoUrl']}');
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryGreen.withOpacity(0.1),
              AppTheme.deepTeal.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryGreen.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.play_circle_outline,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Our Story in Motion',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: isMobile ? 150 : 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _isVideoInitialized && _chewieController != null
                    ? Chewie(controller: _chewieController!)
                    : Container(
                        color: AppTheme.deepTeal.withOpacity(0.1),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_circle_outline,
                                size: 48,
                                color: AppTheme.deepTeal,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Loading Video...',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  color: AppTheme.deepTeal,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Please wait',
                                style: TextStyle(
                                  fontSize: isMobile ? 10 : 12,
                                  color: AppTheme.cloud,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(String videoUrl) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.play_circle_filled,
                color: AppTheme.deepTeal,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Our Story',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _isVideoInitialized && _chewieController != null
                  ? Chewie(controller: _chewieController!)
                  : Container(
                      color: AppTheme.cloud,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_circle_outline,
                              size: 48,
                              color: AppTheme.deepTeal,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to play our story',
                              style: TextStyle(
                                color: AppTheme.deepTeal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedProducts() {
    final productImages = widget.store['productImages'] as List?;
    
    if (productImages == null || productImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.deepTeal.withOpacity(0.1),
              AppTheme.primaryGreen.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.deepTeal.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.deepTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.shopping_bag,
                    color: AppTheme.deepTeal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Featured Products',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMobile ? 2 : (isTablet ? 3 : 4),
                crossAxisSpacing: isMobile ? 8 : 12,
                mainAxisSpacing: isMobile ? 8 : 12,
                childAspectRatio: isMobile ? 0.9 : 1,
              ),
              itemCount: productImages.length,
              itemBuilder: (context, index) {
                final photoUrl = productImages[index];
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SafeNetworkImage(
                      imageUrl: photoUrl,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: BorderRadius.circular(16),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build reviews section
  Widget _buildReviewsSection() {
    final storeId = widget.store['storeId'] as String?;
    final storeName = widget.store['storeName'] as String? ?? 'Store';
    
    if (storeId == null) return const SizedBox.shrink();
    
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.star,
                    color: AppTheme.deepTeal,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reviews',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepTeal,
                    ),
                  ),
                ],
              ),
            ),
            // View Reviews Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  _navigateToReviewsPage(storeId, storeName);
                },
                icon: const Icon(Icons.rate_review, size: 18),
                label: const Text('View Reviews'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.deepTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _navigateToReviewsPage(String storeId, String storeName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoreReviewsPage(
          storeId: storeId,
          storeName: storeName,
        ),
      ),
    );
  }
  
  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final reviewDate = timestamp.toDate();
    final difference = now.difference(reviewDate);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  String _getStoreType() {
    final category = widget.store['category'] as String?;
    switch (category?.toLowerCase()) {
      case 'food':
      case 'groceries':
        return 'Food Business';
              case 'clothes':
      case 'fashion':
        return 'Fashion Store';
      case 'electronics':
        return 'Electronics Store';
      case 'home':
      case 'home & living':
        return 'Home & Living';
      case 'beauty':
        return 'Beauty Store';
      case 'books':
        return 'Bookstore';
      case 'toys':
        return 'Toy Store';
      case 'sports':
        return 'Sports Store';
      default:
        return 'Local Business';
    }
  }

  Widget _buildLiveStats() {
    // Debounce stats updates to prevent excessive rebuilds during scrolling
    if (_statsDebounceTimer?.isActive == true) {
      return RepaintBoundary(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics,
                    color: AppTheme.deepTeal,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Live Stats',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepTeal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Show cached stats while debouncing
              if (_cachedLiveStats != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.shopping_bag,
                        title: 'Orders',
                        value: _cachedLiveStats!['orders']?.toString() ?? '0',
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.star,
                        title: 'Rating',
                        value: _cachedLiveStats!['rating']?.toString() ?? '0.0',
                        color: AppTheme.deepTeal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.rate_review,
                        title: 'Reviews',
                        value: _cachedLiveStats!['reviews']?.toString() ?? '0',
                        color: AppTheme.cloud,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Center(
                  child: CircularProgressIndicator(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: AppTheme.deepTeal,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Live Stats',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('sellerId', isEqualTo: widget.store['storeId'])
                  .where('status', whereIn: ['completed', 'delivered'])
                  .snapshots(),
              builder: (context, snapshot) {
                // Handle permission denied or other errors gracefully
                int completedOrders = 0;
                bool hasOrderError = false;
                
                if (snapshot.hasError) {
                  hasOrderError = true;
                  print('🔍 DEBUG: Orders query error: ${snapshot.error}');
                } else if (snapshot.hasData) {
                  completedOrders = snapshot.data!.docs.length;
                }
                
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reviews')
                      .where('sellerId', isEqualTo: widget.store['storeId'])
                      .snapshots(),
                  builder: (context, reviewSnapshot) {
                    int totalReviews = 0;
                    double avgRating = 0.0;
                    bool hasReviewError = false;
                    
                    if (reviewSnapshot.hasError) {
                      hasReviewError = true;
                      print('🔍 DEBUG: Reviews query error: ${reviewSnapshot.error}');
                    } else if (reviewSnapshot.hasData && reviewSnapshot.data!.docs.isNotEmpty) {
                      totalReviews = reviewSnapshot.data!.docs.length;
                      double totalRating = 0.0;
                      for (var doc in reviewSnapshot.data!.docs) {
                        totalRating += (doc.data() as Map<String, dynamic>)['rating'] ?? 0.0;
                      }
                      avgRating = totalRating / reviewSnapshot.data!.docs.length;
                    }
                    
                    // Show demo data if there are permission errors
                    if (hasOrderError || hasReviewError) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.shopping_bag,
                                  title: 'Orders',
                                  value: 'Demo',
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.star,
                                  title: 'Rating',
                                  value: '4.5',
                                  color: AppTheme.deepTeal,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.rate_review,
                                  title: 'Reviews',
                                  value: 'Demo',
                                  color: AppTheme.cloud,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.deepTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.deepTeal.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline, size: 14, color: AppTheme.deepTeal),
                                const SizedBox(width: 6),
                                Text(
                                  'Demo mode - Login to see real stats',
                                  style: TextStyle(fontSize: 11, color: AppTheme.deepTeal, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    
                    // Cache the stats and debounce updates
                    final newStats = {
                      'orders': completedOrders,
                      'rating': avgRating,
                      'reviews': totalReviews,
                    };
                    
                    // Only update if stats have changed
                    if (_cachedLiveStats == null || 
                        _cachedLiveStats!['orders'] != completedOrders ||
                        _cachedLiveStats!['rating'] != avgRating ||
                        _cachedLiveStats!['reviews'] != totalReviews) {
                      
                      // Cancel existing timer
                      _statsDebounceTimer?.cancel();
                      
                      // Set new timer to update stats after a delay
                      _statsDebounceTimer = Timer(const Duration(milliseconds: 500), () {
                        if (mounted) {
                          setState(() {
                            _cachedLiveStats = newStats;
                          });
                        }
                      });
                    }
                    
                    return Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.shopping_bag,
                            title: 'Orders',
                            value: completedOrders.toString(),
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.star,
                            title: 'Rating',
                            value: avgRating.toStringAsFixed(1),
                            color: AppTheme.deepTeal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.rate_review,
                            title: 'Reviews',
                            value: totalReviews.toString(),
                            color: AppTheme.cloud,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flash_on,
                  color: AppTheme.deepTeal,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.phone,
                    label: 'Call',
                    onTap: () => _handleCall(),
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.chat,
                    label: 'WhatsApp',
                    onTap: () => _handleWhatsApp(),
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.share,
                    label: 'Share',
                    onTap: () => _handleShare(),
                    color: AppTheme.cloud,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCall() async {
    final contact = widget.store['contact'] as String?;
    if (contact != null && contact.isNotEmpty) {
      // Remove any non-numeric characters and ensure it starts with country code
      String cleanContact = contact.replaceAll(RegExp(r'[^\d+]'), '');
      
      // If it doesn't start with +, assume it's a local number and add country code
      if (!cleanContact.startsWith('+')) {
        cleanContact = '+27$cleanContact'; // Assuming South Africa (+27)
      }
      
      final phoneUrl = Uri.parse('tel:$cleanContact');
      
      try {
        if (await canLaunchUrl(phoneUrl)) {
          await launchUrl(phoneUrl);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Calling $contact...'),
              backgroundColor: AppTheme.primaryGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to make phone call'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error making call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact information not available'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _handleWhatsApp() async {
    final contact = widget.store['contact'] as String?;
    if (contact != null && contact.isNotEmpty) {
      // Clean the phone number - remove spaces, dashes, parentheses
      String cleanContact = contact.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      
      // Remove any non-numeric characters except +
      cleanContact = cleanContact.replaceAll(RegExp(r'[^\d+]'), '');
      
      // If it doesn't start with +, assume it's a local number and add country code
      if (!cleanContact.startsWith('+')) {
        cleanContact = '+27$cleanContact'; // Assuming South Africa (+27)
      }
      
      // Format for WhatsApp URL - remove + and any leading zeros
      String whatsappNumber = cleanContact.replaceFirst('+', '');
      // Remove leading zeros after country code
      if (whatsappNumber.startsWith('27')) {
        whatsappNumber = '27' + whatsappNumber.substring(2).replaceFirst(RegExp(r'^0+'), '');
      }
      
      final whatsappUrl = Uri.parse('https://wa.me/$whatsappNumber');
      
      try {
        // Debug: Show the URL being generated
        print('WhatsApp URL: $whatsappUrl');
        print('Original contact: $contact');
        print('Cleaned contact: $cleanContact');
        print('WhatsApp number: $whatsappNumber');
        
        // Try launching WhatsApp directly without checking first
        bool launched = false;
        
        // Try web URL first
        try {
          await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
          launched = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening WhatsApp...'),
              backgroundColor: AppTheme.primaryGreen,
            ),
          );
        } catch (e) {
          print('Web URL failed: $e');
        }
        
        // If web URL failed, try app protocol
        if (!launched) {
          final whatsappAppUrl = Uri.parse('whatsapp://send?phone=$whatsappNumber');
          try {
            await launchUrl(whatsappAppUrl, mode: LaunchMode.externalApplication);
            launched = true;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening WhatsApp...'),
                backgroundColor: AppTheme.primaryGreen,
              ),
            );
          } catch (e) {
            print('App protocol failed: $e');
          }
        }
        
        // If both failed, show dialog
        if (!launched) {
          // Show dialog with options when WhatsApp is not available
          showDialog(
              context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('WhatsApp Not Available'),
                content: const Text(
                  'WhatsApp is not installed on this device. Would you like to:\n\n'
                  '• Call the store directly\n'
                  '• Copy the phone number\n'
                  '• Install WhatsApp from Play Store',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _handleCall(); // Fallback to call
                    },
                    child: const Text('Call Store'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Copy to clipboard
                      Clipboard.setData(ClipboardData(text: cleanContact));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Phone number copied: $cleanContact'),
                          backgroundColor: AppTheme.cloud,
                        ),
                      );
                    },
                    child: const Text('Copy Number'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Open Play Store to install WhatsApp
                      final playStoreUrl = Uri.parse(
                        'https://play.google.com/store/apps/details?id=com.whatsapp'
                      );
                      launchUrl(playStoreUrl, mode: LaunchMode.externalApplication);
                    },
                    child: const Text('Install WhatsApp'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening WhatsApp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact information not available'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _handleShare() async {
    final storeName = widget.store['storeName'] as String? ?? 'Store';
    final storeId = widget.store['storeId'] as String?;
    final contact = widget.store['contact'] as String?;
    final location = widget.store['location'] as String?;
    
    if (storeId != null) {
      // Create share text
      String shareText = 'Check out $storeName!';
      if (contact != null && contact.isNotEmpty) {
        shareText += '\n📞 Contact: $contact';
      }
      if (location != null && location.isNotEmpty) {
        shareText += '\n📍 Location: $location';
      }
      shareText += '\n\nDiscover amazing products and services!';
      
      // Create share URL (you can replace this with your app's deep link)
      final shareUrl = 'https://your-app.com/store/$storeId';
      
      // Combine text and URL
      final fullShareText = '$shareText\n\n$shareUrl';
      
      try {
        // Use the share package to share content
        await Share.share(
          fullShareText,
          subject: 'Check out $storeName',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sharing $storeName...'),
            backgroundColor: AppTheme.cloud,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSpecialtiesSection() {
    final specialties = widget.store['specialties'] as List<dynamic>?;
    if (specialties == null || specialties.isEmpty) return const SizedBox.shrink();
    
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: AppTheme.deepTeal, size: 20),
                const SizedBox(width: 8),
                Text('Specialties', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.deepTeal)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: specialties.map((specialty) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                  ),
                  child: Text(
                    specialty.toString(),
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
} 