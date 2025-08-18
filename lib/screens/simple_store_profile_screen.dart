import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' show ImageByteFormat;
import 'dart:async';
import '../theme/app_theme.dart';
import '../widgets/safe_network_image.dart';
import 'store_reviews_page.dart';
// Removed zoom view import
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart'; // Added import for share package
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/services.dart'; // Added import for Clipboard
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'stunning_product_browser.dart';

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
  bool _isFollowing = false; // Used by Follow button
  String? _utmSource; // optional in-app UTM overrides
  String? _utmMedium;
  String? _utmCampaign;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  // Responsive design variables
  bool get isMobile => MediaQuery.of(context).size.width < 600;
  bool get isTablet => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 900;
  
  late AnimationController _fadeController;
  // late Animation<double> _fadeAnimation; // Removed - not used in modern design
  
  // Performance optimization variables
  final ScrollController _scrollController = ScrollController();
  // bool _isScrolling = false; // removed - no longer used
  Timer? _scrollTimer;
  
  // Cache for gallery data to prevent unnecessary rebuilds
  Map<String, dynamic>? _cachedStoreData;
  bool _isLoadingGalleryData = false;
  
  // Cache for live stats to prevent unnecessary rebuilds (reserved for future use)
  // Map<String, dynamic>? _cachedLiveStats; // Unused - removed
  Timer? _statsDebounceTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeVideo();
    _loadGalleryData(); // Load fresh data when navigating to the screen
    _loadFollowState();
  }

  // Share store profile
  void _shareStore() async {
    final storeName = widget.store['storeName'] as String? ?? 'Store';
    final storeId = widget.store['storeId'] as String?;
    final description = widget.store['tagline'] as String? ?? widget.store['category'] as String? ?? '';
    // Optional UTM parameters for tracking
    final envUtmSource = const String.fromEnvironment('UTM_SOURCE', defaultValue: '');
    final envUtmMedium = const String.fromEnvironment('UTM_MEDIUM', defaultValue: '');
    final envUtmCampaign = const String.fromEnvironment('UTM_CAMPAIGN', defaultValue: '');
    // Web fallback
    final webBase = const String.fromEnvironment('PUBLIC_BASE_URL', defaultValue: 'https://marketplace-8d6bd.web.app');
    final deepLink = (storeId != null) ? '$webBase/store/$storeId' : webBase;
    // Try lightweight Firebase Dynamic Links (no SDK) if LINKS_DOMAIN is provided
    final linksDomain = const String.fromEnvironment('DYNAMIC_LINKS_DOMAIN', defaultValue: ''); // e.g. https://links.yourdomain
    final androidPackage = const String.fromEnvironment('ANDROID_PACKAGE', defaultValue: '');
    final iosBundleId = const String.fromEnvironment('IOS_BUNDLE_ID', defaultValue: '');

    // Attach UTM params if provided
    Uri deepUri = Uri.parse(deepLink);
    final utmParams = <String, String>{
      if (((_utmSource ?? envUtmSource)).isNotEmpty) 'utm_source': (_utmSource ?? envUtmSource),
      if (((_utmMedium ?? envUtmMedium)).isNotEmpty) 'utm_medium': (_utmMedium ?? envUtmMedium),
      if (((_utmCampaign ?? envUtmCampaign)).isNotEmpty) 'utm_campaign': (_utmCampaign ?? envUtmCampaign),
    };
    if (utmParams.isNotEmpty) {
      deepUri = deepUri.replace(queryParameters: {
        ...deepUri.queryParameters,
        ...utmParams,
      });
    }

    String shareUrl = deepUri.toString();
    if (linksDomain.isNotEmpty && storeId != null) {
      final encodedLink = Uri.encodeComponent(shareUrl);
      final storeName = widget.store['storeName'] as String? ?? 'Store';
      final descriptionShort = (widget.store['story'] as String?)?.trim();
      final imageUrl = (widget.store['profileImageUrl'] as String?)?.trim();
      final params = <String, String>{
        'link': encodedLink,
        if (androidPackage.isNotEmpty) 'apn': androidPackage,
        if (iosBundleId.isNotEmpty) 'ibi': iosBundleId,
        'efr': '1', // force redirect
        // Social meta for previews
        'st': storeName,
        if (descriptionShort != null && descriptionShort.isNotEmpty) 'sd': descriptionShort,
        if (imageUrl != null && imageUrl.isNotEmpty) 'si': imageUrl,
        'ofl': deepUri.toString(),
      };
      final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
      shareUrl = '$linksDomain/?$query';
    }

    final message = description.isNotEmpty
        ? 'Check out $storeName on Mzansi Marketplace – $description\n$shareUrl'
        : 'Check out $storeName on Mzansi Marketplace\n$shareUrl';
    try {
      await Share.share(message);
      // Offer QR code dialog
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Share via QR', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                QrImageView(
                  data: shareUrl,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 12),
                SelectableText(
                  shareUrl,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: shareUrl));
                        if (context.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copied')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy link'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share sheet opened')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to share: $e')),
      );
    }
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    //   CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    // ); // Removed - not used in modern design
    
    _fadeController.forward();
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
    _videoController?.dispose();
    _chewieController?.dispose();
    _scrollController.dispose();
    _scrollTimer?.cancel();
    _statsDebounceTimer?.cancel();
    super.dispose();
  }

  // Video pause/scroll handling removed - not used in modern design

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
      body: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildStunningAppBar(),
                SliverToBoxAdapter(child: _buildModernHeroSection()),
                SliverToBoxAdapter(child: _buildModernStatsDashboard()),
                SliverToBoxAdapter(child: _buildModernStorySection()),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(child: _buildModernSpecialtiesSection()),
                SliverToBoxAdapter(child: _buildModernGallerySection()),
                // Reviews summary and entry point
                SliverToBoxAdapter(child: _buildReviewsSummaryCard()),
                SliverToBoxAdapter(child: _buildVideoSection()),
                const SliverToBoxAdapter(child: SizedBox(height: 100)), // Padding for FAB
              ],
            ),
      bottomNavigationBar: _buildStickyBottomBar(),
    );
  }

  // Modern glass morphism app bar with enhanced design
  Widget _buildStunningAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      title: Row(
        children: [
          const Icon(Icons.storefront_rounded, size: 20, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.store['storeName'] ?? 'Store',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4),
                ],
              ),
            ),
          ),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.deepTeal.withOpacity(0.95),
                AppTheme.primaryGreen.withOpacity(0.85),
                AppTheme.deepTeal.withOpacity(0.90),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.deepTeal.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        // QR next to share
        Container(
          margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
          child: _buildGlassButton(
            icon: Icons.qr_code_rounded,
            onPressed: _showQrDialog,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
          child: _buildGlassButton(
            icon: Icons.share_rounded,
            onPressed: _openCampaignBuilder,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          child: _buildFollowButton(),
        ),
        // Campaign builder launcher (optional)
        // Container(
        //   margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
        //   child: _buildGlassButton(
        //     icon: Icons.campaign_rounded,
        //     onPressed: _openCampaignBuilder,
        //   ),
        // ),
      ],
    );
  }

  // Show QR dialog with share URL
  Future<void> _showQrDialog() async {
    final shareUrl = (() {
      final storeId = widget.store['storeId'] as String?;
      final webBase = const String.fromEnvironment('PUBLIC_BASE_URL', defaultValue: 'https://marketplace-8d6bd.web.app');
      final deepLink = (storeId != null) ? '$webBase/store/$storeId' : webBase;
      final utmSource = const String.fromEnvironment('UTM_SOURCE', defaultValue: '');
      final utmMedium = const String.fromEnvironment('UTM_MEDIUM', defaultValue: '');
      final utmCampaign = const String.fromEnvironment('UTM_CAMPAIGN', defaultValue: '');
      Uri deepUri = Uri.parse(deepLink);
      final utmParams = <String, String>{
        if (utmSource.isNotEmpty) 'utm_source': utmSource,
        if (utmMedium.isNotEmpty) 'utm_medium': utmMedium,
        if (utmCampaign.isNotEmpty) 'utm_campaign': utmCampaign,
      };
      if (utmParams.isNotEmpty) {
        deepUri = deepUri.replace(queryParameters: {
          ...deepUri.queryParameters,
          ...utmParams,
        });
      }
      final linksDomain = const String.fromEnvironment('DYNAMIC_LINKS_DOMAIN', defaultValue: '');
      final androidPackage = const String.fromEnvironment('ANDROID_PACKAGE', defaultValue: '');
      final iosBundleId = const String.fromEnvironment('IOS_BUNDLE_ID', defaultValue: '');
      String out = deepUri.toString();
      if (linksDomain.isNotEmpty && storeId != null) {
        final encoded = Uri.encodeComponent(out);
        final params = <String, String>{
          'link': encoded,
          if (androidPackage.isNotEmpty) 'apn': androidPackage,
          if (iosBundleId.isNotEmpty) 'ibi': iosBundleId,
          'efr': '1',
        };
        final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
        out = '$linksDomain/?$query';
      }
      return out;
    })();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Store QR', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Builder(
                builder: (_) {
                  final qrKey = GlobalKey();
                  return Column(
                    children: [
                      RepaintBoundary(
                        key: qrKey,
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(8),
                          child: QrImageView(
                            data: shareUrl,
                            size: 200,
                            backgroundColor: Colors.white,
                            // Center logo: use app icon asset if available
                            embeddedImage: const AssetImage('assets/app_icon_fixed.png'),
                            embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(40, 40)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _downloadQrPng(qrKey, 'store_qr.png'),
                          icon: const Icon(Icons.download),
                          label: const Text('Download PNG'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              SelectableText(
                shareUrl,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: shareUrl));
                      if (context.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy link'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadQrPng(GlobalKey boundaryKey, String filename) async {
    try {
      final ctx = boundaryKey.currentContext;
      if (ctx == null) return;
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes);
      await Share.shareFiles([file.path], mimeTypes: ['image/png']);
      await _analytics.logEvent(name: 'qr_download', parameters: {'store_id': widget.store['storeId']});
    } catch (_) {}
  }

  // Modern glass morphism button
  Widget _buildGlassButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onPressed,
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  // Enhanced follow button with modern design
  Widget _buildFollowButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: _isFollowing 
          ? LinearGradient(
              colors: [Colors.red.shade400, Colors.red.shade600],
            )
          : LinearGradient(
              colors: [Colors.white, Colors.grey.shade50],
            ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: _isFollowing ? Colors.red.shade300 : Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isFollowing ? Colors.red : Colors.black).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: _toggleFollow,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    _isFollowing ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey(_isFollowing),
                    size: 16,
                    color: _isFollowing ? Colors.white : AppTheme.deepTeal,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isFollowing ? 'Following' : 'Follow',
          style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isFollowing ? Colors.white : AppTheme.deepTeal,
                    letterSpacing: 0.3,
                  ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Future<void> _loadFollowState() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final String? storeId = widget.store['storeId'] as String?;
      if (currentUser == null || storeId == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('follows')
          .doc(storeId)
          .get();
      if (!mounted) return;
      setState(() => _isFollowing = doc.exists);
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final String? storeId = widget.store['storeId'] as String?;
      final String storeName = widget.store['storeName'] as String? ?? 'Store';
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to follow stores')),
        );
        return;
      }
      if (storeId == null) return;

      final followRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('follows')
          .doc(storeId);

      final storeRef = FirebaseFirestore.instance
          .collection('users')
          .doc(storeId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final followSnap = await tx.get(followRef);
        final storeSnap = await tx.get(storeRef);
        final currentFollowers = (storeSnap.data()?['followers'] as num?)?.toInt() ?? 0;

        if (followSnap.exists) {
          // Unfollow
          tx.delete(followRef);
          tx.update(storeRef, {'followers': (currentFollowers - 1).clamp(0, 1 << 31)});
          if (mounted) setState(() => _isFollowing = false);
        } else {
          // Follow
          tx.set(followRef, {
            'storeId': storeId,
            'storeName': storeName,
            'createdAt': FieldValue.serverTimestamp(),
            'notify': true, // auto-enable alerts on follow
          });
          tx.update(storeRef, {'followers': currentFollowers + 1});
          if (mounted) setState(() => _isFollowing = true);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update follow: $e')),
      );
    }
  }

  // Modern stats dashboard section
  Widget _buildModernStatsDashboard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppTheme.cloud.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepTeal.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        border: Border.all(
          color: AppTheme.deepTeal.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
          children: [
          Row(
            children: [
              Expanded(child: _buildLiveRatingStatCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildLiveFollowersStatCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildLiveProductsStatCard()),
            ],
          ),
          const SizedBox(height: 16),
          _buildOpenStatusCard(),
        ],
      ),
    );
  }

  // Rating stat card that listens to live reviews and computes average/count
  Widget _buildLiveRatingStatCard() {
    final String? storeId = widget.store['storeId'] as String?;
    return StreamBuilder<QuerySnapshot>(
      stream: storeId == null
          ? const Stream.empty()
          : FirebaseFirestore.instance
              .collection('reviews')
              .where('storeId', isEqualTo: storeId)
              .snapshots(),
      builder: (context, snapshot) {
        double avg = 0;
        int count = 0;
        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          count = docs.length;
          if (count > 0) {
            double sum = 0;
            for (final d in docs) {
              final data = d.data() as Map<String, dynamic>;
              final num ratingNum = (data['rating'] ?? 0) as num;
              sum += ratingNum.toDouble();
            }
            avg = sum / count;
          }
        } else {
          // Fallback to provided values if any
          final num? fallback = widget.store['rating'] as num?;
          avg = fallback?.toDouble() ?? 0;
          count = (widget.store['reviewCount'] as num?)?.toInt() ?? 0;
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.amber.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                count > 0 ? avg.toStringAsFixed(1) : '0.0',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
              Text(
                'Rating',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (count > 0)
                Text(
                  '($count reviews)',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Followers stat card (live from store doc)
  Widget _buildLiveFollowersStatCard() {
    final String? storeId = widget.store['storeId'] as String?;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: storeId == null
          ? const Stream.empty()
          : FirebaseFirestore.instance.collection('users').doc(storeId).snapshots(),
      builder: (context, snapshot) {
        int followers = 0;
        if (snapshot.hasData && snapshot.data?.data() != null) {
          final data = snapshot.data!.data()!;
          followers = (data['followers'] as num?)?.toInt() ?? 0;
        } else {
          followers = (widget.store['followers'] as num?)?.toInt() ?? 0;
        }

        return _buildStatShell(
          icon: Icons.favorite_rounded,
          color: Colors.red,
          valueText: '$followers',
          labelText: 'Followers',
        );
      },
    );
  }

  // Products stat card (live from products collection)
  Widget _buildLiveProductsStatCard() {
    final String? storeId = widget.store['storeId'] as String?;
    return StreamBuilder<QuerySnapshot>(
      stream: storeId == null
          ? const Stream.empty()
          : FirebaseFirestore.instance
              .collection('products')
              // Many existing products use 'ownerId' for the seller
              .where('ownerId', isEqualTo: storeId)
              .where('status', isEqualTo: 'active')
              .snapshots(),
      builder: (context, snapshot) {
        int total = 0;
        if (snapshot.hasData) {
          total = snapshot.data!.docs.length;
        } else {
          total = (widget.store['totalProducts'] as num?)?.toInt() ?? 0;
        }

        return _buildStatShell(
          icon: Icons.shopping_bag_rounded,
          color: AppTheme.primaryGreen,
          valueText: '$total',
          labelText: 'Products',
        );
      },
    );
  }

  // Shared stat shell for uniform look
  Widget _buildStatShell({
    required IconData icon,
    required Color color,
    required String valueText,
    required String labelText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            valueText,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            labelText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.deepTeal.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.deepTeal.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.deepTeal),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.deepTeal, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // (Removed unused legacy stat card)

  // Modern open status card with computed open/closed state
  Widget _buildOpenStatusCard() {
    final String? openStr = widget.store['storeOpenHour'] as String?;
    final String? closeStr = widget.store['storeCloseHour'] as String?;
    final bool? explicitOpen = widget.store['isStoreOpen'] as bool?; // optional override
    final int tzOffsetHours = (widget.store['timezoneOffsetHours'] as num?)?.toInt() ?? 2; // SAST default
    final List<dynamic> holidayList = (widget.store['holidayClosures'] as List<dynamic>?) ?? const [];

    bool computedOpen = false;
    if (explicitOpen != null) {
      computedOpen = explicitOpen;
    } else if (openStr != null && closeStr != null) {
      computedOpen = _isNowWithin(openStr, closeStr, tzOffsetHours, holidayList);
    }

    final String hours = (openStr != null && closeStr != null)
        ? '$openStr - $closeStr'
        : (widget.store['openingHours'] as String? ?? 'Hours not specified');

    String subline = hours;
    if (!computedOpen && openStr != null && closeStr != null) {
      final mins = _minutesUntilOpen(openStr, closeStr, tzOffsetHours, holidayList);
      if (mins != null) {
        subline = 'Opens in ${mins > 60 ? '${(mins / 60).floor()}h ${mins % 60}m' : '${mins}m'} • $hours';
      }
      if (_isHolidayToday(tzOffsetHours, holidayList)) {
        subline = 'Closed today (Public holiday) • $hours';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
          colors: computedOpen 
            ? [AppTheme.primaryGreen.withOpacity(0.1), AppTheme.primaryGreen.withOpacity(0.05)]
            : [Colors.orange.withOpacity(0.1), Colors.orange.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: computedOpen ? AppTheme.primaryGreen.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: computedOpen ? AppTheme.primaryGreen : Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              computedOpen ? Icons.store_rounded : Icons.access_time_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  computedOpen ? 'Open Now' : 'Closed',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: computedOpen ? AppTheme.primaryGreen : Colors.orange,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subline,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  bool _isNowWithin(String open, String close, int tzOffsetHours, List<dynamic> holidayList) {
    // open/close in HH:mm (24h)
    TimeOfDay? parse(String s) {
      final parts = s.split(':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return TimeOfDay(hour: h, minute: m);
    }

    final openTod = parse(open);
    final closeTod = parse(close);
    if (openTod == null || closeTod == null) return false;

    final nowDt = DateTime.now().toUtc().add(Duration(hours: tzOffsetHours));
    if (_isHolidayDate(nowDt, holidayList)) return false;
    final now = TimeOfDay(hour: nowDt.hour, minute: nowDt.minute);
    bool isAfterOrEqual(TimeOfDay a, TimeOfDay b) => a.hour > b.hour || (a.hour == b.hour && a.minute >= b.minute);
    bool isBeforeOrEqual(TimeOfDay a, TimeOfDay b) => a.hour < b.hour || (a.hour == b.hour && a.minute <= b.minute);

    // Handle overnight hours (e.g., 22:00 - 06:00)
    final overnight = (closeTod.hour < openTod.hour) || (closeTod.hour == openTod.hour && closeTod.minute < openTod.minute);
    if (!overnight) {
      return isAfterOrEqual(now, openTod) && isBeforeOrEqual(now, closeTod);
    } else {
      // Now is after open OR before close
      return isAfterOrEqual(now, openTod) || isBeforeOrEqual(now, closeTod);
    }
  }

  int? _minutesUntilOpen(String open, String close, int tzOffsetHours, List<dynamic> holidayList) {
    TimeOfDay? parse(String s) {
      final parts = s.split(':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return TimeOfDay(hour: h, minute: m);
    }
    final openTod = parse(open);
    final closeTod = parse(close);
    if (openTod == null || closeTod == null) return null;
    final now = DateTime.now().toUtc().add(Duration(hours: tzOffsetHours));
    if (_isHolidayDate(now, holidayList)) return null;
    final todayOpen = DateTime(now.year, now.month, now.day, openTod.hour, openTod.minute);
    final todayClose = DateTime(now.year, now.month, now.day, closeTod.hour, closeTod.minute);
    if (todayClose.isBefore(todayOpen)) {
      // overnight close -> treat close as next day
      if (now.isBefore(todayOpen)) {
        return todayOpen.difference(now).inMinutes;
      }
      // already after open, next opening is tomorrow's open
      final tomorrowOpen = todayOpen.add(const Duration(days: 1));
      return now.isAfter(todayClose) ? tomorrowOpen.difference(now).inMinutes : 0;
    } else {
      if (now.isBefore(todayOpen)) return todayOpen.difference(now).inMinutes;
      // already within or after close -> next open tomorrow
      if (now.isAfter(todayClose)) {
        final tomorrowOpen = todayOpen.add(const Duration(days: 1));
        return tomorrowOpen.difference(now).inMinutes;
      }
    }
    return 0;
  }

  bool _isHolidayToday(int tzOffsetHours, List<dynamic> holidayList) {
    final now = DateTime.now().toUtc().add(Duration(hours: tzOffsetHours));
    return _isHolidayDate(now, holidayList);
  }

  bool _isHolidayDate(DateTime date, List<dynamic> holidayList) {
    final todayStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return holidayList.map((e) => e.toString()).contains(todayStr);
  }

  Future<void> _openCampaignBuilder() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        String? source = _utmSource;
        String? medium = _utmMedium;
        String? campaign = _utmCampaign;
        final sourceOptions = ['whatsapp', 'instagram', 'facebook', 'twitter', 'flyer', 'referral'];
        final mediumOptions = ['social', 'qr', 'referral', 'paid'];
        final controller = TextEditingController(text: campaign ?? '');
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (ctx, setStateSheet) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Campaign Builder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Source'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in sourceOptions)
                        ChoiceChip(
                          label: Text(s),
                          selected: source == s,
                          onSelected: (_) => setStateSheet(() => source = s),
                        )
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Medium'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final m in mediumOptions)
                        ChoiceChip(
                          label: Text(m),
                          selected: medium == m,
                          onSelected: (_) => setStateSheet(() => medium = m),
                        )
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'Campaign (optional)'),
                    onChanged: (v) => campaign = v.trim(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            setState(() {
                              _utmSource = source;
                              _utmMedium = medium;
                              _utmCampaign = campaign?.isEmpty == true ? null : campaign;
                            });
                            _showQrDialog();
                            _analytics.logEvent(name: 'qr_open', parameters: {'store_id': widget.store['storeId'] ?? '', 'src': source ?? '', 'med': medium ?? ''});
                          },
                          icon: const Icon(Icons.qr_code),
                          label: const Text('QR'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            setState(() {
                              _utmSource = source;
                              _utmMedium = medium;
                              _utmCampaign = campaign?.isEmpty == true ? null : campaign;
                            });
                            _shareStore();
                            _analytics.logEvent(name: 'share_click', parameters: {'store_id': widget.store['storeId'] ?? '', 'src': source ?? '', 'med': medium ?? ''});
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('Share'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewsSummaryCard() {
    final String? storeId = widget.store['storeId'] as String?;
    return RepaintBoundary(
              child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.complementaryElevation,
          border: Border.all(color: AppTheme.deepTeal.withOpacity(0.15), width: 1),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: storeId == null
              ? const Stream.empty()
              : FirebaseFirestore.instance
                  .collection('reviews')
                  .where('storeId', isEqualTo: storeId)
                  .snapshots(),
          builder: (context, snapshot) {
            double avg = 0;
            int count = 0;
            if (snapshot.hasData) {
              final docs = snapshot.data!.docs;
              count = docs.length;
              if (count > 0) {
                double sum = 0;
                for (final d in docs) {
                  final data = d.data() as Map<String, dynamic>;
                  final num ratingNum = (data['rating'] ?? 0) as num;
                  sum += ratingNum.toDouble();
                }
                avg = sum / count;
              }
            } else {
              final num? fallback = widget.store['rating'] as num?;
              avg = fallback?.toDouble() ?? 0;
              count = (widget.store['reviewCount'] as num?)?.toInt() ?? 0;
            }

            return Row(
              children: [
                Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.deepTeal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.deepTeal.withOpacity(0.2)),
              ),
              child: const Icon(Icons.star, color: AppTheme.deepTeal, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        count > 0 ? 'Rated ${avg.toStringAsFixed(1)}' : 'No ratings yet',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.deepTeal),
                      ),
                      Text(
                        count > 0 ? '$count reviews' : 'Be the first to review',
                        style: TextStyle(color: AppTheme.cloud, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final storeId = widget.store['storeId'] as String?;
                    final storeName = widget.store['storeName'] as String? ?? 'Store';
                    if (storeId != null) {
                      _navigateToReviewsPage(storeId, storeName);
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: AppTheme.deepTeal),
                  child: const Text('See all'),
                )
              ],
            );
          },
        ),
      ),
    );
  }

  // Bottom action bar (original simple buttons)
  Widget _buildStickyBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
                  boxShadow: [
                    BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border(
            top: BorderSide(color: AppTheme.deepTeal.withOpacity(0.08), width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _handleChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Chat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.deepTeal,
                    side: BorderSide(color: AppTheme.deepTeal.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _handleShop,
                  icon: const Icon(Icons.storefront, size: 18),
                  label: const Text('Shop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deepTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modern action button with enhanced styling
  // (Removed unused modern action button)

  void _handleShop() {
    final storeId = widget.store['storeId'] as String?;
    final storeName = widget.store['storeName'] as String? ?? 'Store';
    if (storeId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StunningProductBrowser(
            storeId: storeId,
            storeName: storeName,
          ),
        ),
      );
    }
  }

  void _handleChat() async {
    final contact = (widget.store['contact'] as String?)?.trim();
    if (contact == null || contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No WhatsApp contact found for this store')),
      );
      return;
    }

    // Normalize to international format, assume ZA if no +
    String phone = contact.replaceAll(RegExp(r'[^\d+]'), '');
    if (!phone.startsWith('+')) {
      if (phone.startsWith('0')) phone = phone.substring(1);
      phone = '+27$phone';
    }
    final phoneDigits = phone.replaceAll('+', '');

    final storeName = widget.store['storeName'] as String? ?? 'Store';
    final preset = 'Hi $storeName, I found your store on Mzansi Marketplace and would like to chat.';
    
    // 1) Try native WhatsApp scheme
    final whatsappUri = Uri.parse('whatsapp://send?phone=$phoneDigits&text=${Uri.encodeComponent(preset)}');
    if (await canLaunchUrl(whatsappUri)) {
      final ok = await launchUrl(whatsappUri, mode: LaunchMode.externalNonBrowserApplication);
      if (ok) return;
    }

    // 2) Try wa.me link
    final waMeUri = Uri.https('wa.me', '/$phoneDigits', {'text': preset});
    if (await canLaunchUrl(waMeUri)) {
      final ok = await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
      if (ok) return;
    }

    // 3) Try api.whatsapp.com fallback
    final apiUri = Uri.https('api.whatsapp.com', '/send', {'phone': phoneDigits, 'text': preset});
    if (await canLaunchUrl(apiUri)) {
      final ok = await launchUrl(apiUri, mode: LaunchMode.externalApplication);
      if (ok) return;
    }

    // 4) Offer store install links as a last resort
    final playStoreUri = Uri.parse('market://details?id=com.whatsapp');
    if (await canLaunchUrl(playStoreUri)) {
      final ok = await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
      if (ok) return;
    }
    final playStoreHttp = Uri.parse('https://play.google.com/store/apps/details?id=com.whatsapp');
    if (await canLaunchUrl(playStoreHttp)) {
      final ok = await launchUrl(playStoreHttp, mode: LaunchMode.externalApplication);
      if (ok) return;
    }
    final appStoreUri = Uri.parse('https://apps.apple.com/app/whatsapp-messenger/id310633997');
    if (await canLaunchUrl(appStoreUri)) {
      final ok = await launchUrl(appStoreUri, mode: LaunchMode.externalApplication);
      if (ok) return;
    }

    // 5) Give user a copy option if nothing handled the URL
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open WhatsApp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('We couldn\'t open WhatsApp automatically.'),
            const SizedBox(height: 8),
            SelectableText('Number: $phone'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: phone));
              if (context.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Number copied')));
              }
            },
            child: const Text('Copy number'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Modern hero section with enhanced design
  Widget _buildModernHeroSection() {
    final storeName = widget.store['storeName'] as String? ?? 'Store Name';
    final category = widget.store['category'] as String? ?? 'General';
    final isVerified = widget.store['isVerified'] as bool? ?? false;
    final String? profileImageUrl = widget.store['profileImageUrl'] as String?;
    
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile image (angular avatar)
                if (profileImageUrl != null && profileImageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: isMobile ? 48 : 56,
                      height: isMobile ? 48 : 56,
                      child: SafeNetworkImage(
                        imageUrl: profileImageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    width: isMobile ? 48 : 56,
                    height: isMobile ? 48 : 56,
                    decoration: BoxDecoration(
                      color: AppTheme.deepTeal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.deepTeal.withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.storefront, color: AppTheme.deepTeal),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                        const Icon(
                          Icons.verified,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        const Text(
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

  // (Removed unused modern hero section duplicate)
  // Keeping signature to avoid large refactor; not referenced.
  // ignore: unused_element
  Widget _buildModernHeroSectionComplete() {
    final storeName = widget.store['storeName'] as String? ?? 'Store Name';
    final category = widget.store['category'] as String? ?? 'General';
    final isVerified = widget.store['isVerified'] as bool? ?? false;
    final String? profileImageUrl = widget.store['profileImageUrl'] as String?;
    final String? coverImageUrl = widget.store['coverImageUrl'] as String?;
    
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepTeal.withOpacity(0.1),
              blurRadius: 25,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Cover image with gradient overlay
            if (coverImageUrl != null && coverImageUrl.isNotEmpty)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      SafeNetworkImage(
                        imageUrl: coverImageUrl,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.deepTeal.withOpacity(0.8),
                                AppTheme.primaryGreen.withOpacity(0.6),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.storefront_rounded,
                              size: 60,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ),
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
                    ],
                  ),
                ),
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.deepTeal.withOpacity(0.9),
                      AppTheme.primaryGreen.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.storefront_rounded,
                    size: 60,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            // Profile content overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Profile picture with modern styling
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.deepTeal.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: profileImageUrl != null && profileImageUrl.isNotEmpty
                          ? SafeNetworkImage(
                              imageUrl: profileImageUrl,
                              fit: BoxFit.cover,
                              errorWidget: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppTheme.deepTeal, AppTheme.primaryGreen],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.storefront_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppTheme.deepTeal, AppTheme.primaryGreen],
                                ),
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Store information
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  storeName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.deepTeal,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              if (isVerified)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withOpacity(0.8)],
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryGreen.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        'Verified',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.3,
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
                              color: AppTheme.deepTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.deepTeal.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.category_rounded,
                                  size: 16,
                                  color: AppTheme.deepTeal,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  category,
                                  style: TextStyle(
                                    color: AppTheme.deepTeal,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildTrustSignalsRow(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustSignalsRow() {
    final String? storeId = widget.store['storeId'] as String?;
    final int? avgResponse = (widget.store['avgResponseMinutes'] as num?)?.toInt();
    return Row(
      children: [
        // Orders volume chip (live)
        if (storeId != null)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('sellerId', isEqualTo: storeId)
                .snapshots(),
            builder: (context, snap) {
              final count = snap.hasData ? snap.data!.docs.length : 0;
              return _smallPill(icon: Icons.shopping_bag_rounded, label: _formatOrders(count));
            },
          )
        else
          _smallPill(icon: Icons.shopping_bag_rounded, label: 'Orders —'),
        const SizedBox(width: 8),
        // Response time chip (live from seller doc)
        if (storeId != null)
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').doc(storeId).snapshots(),
            builder: (context, snap) {
              final data = snap.data?.data();
              final liveAvg = (data?['avgResponseMinutes'] as num?)?.toInt() ?? avgResponse;
              final label = liveAvg == null
                  ? 'Response —'
                  : (liveAvg <= 10
                      ? 'Response: Fast'
                      : liveAvg <= 60
                          ? 'Response: ~${liveAvg}m'
                          : 'Response: ${_hoursMinutes(liveAvg)}');
              return _smallPill(icon: Icons.bolt_rounded, label: label);
            },
          )
        else
          _smallPill(icon: Icons.bolt_rounded, label: 'Response —'),
      ],
    );
  }

  String _formatOrders(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k orders';
    if (n == 1) return '1 order';
    return '$n orders';
  }

  String _hoursMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  // Alias functions for modern sections
  Widget _buildModernStorySection() => _buildStorySection();
  Widget _buildModernSpecialtiesSection() => _buildSpecialtiesSection();
  Widget _buildModernGallerySection() => _buildGallerySection();

  // Modern specialties section
  Widget _buildSpecialtiesSection() {
    final specialties = widget.store['specialties'];
    if (specialties == null || (specialties is List && specialties.isEmpty)) {
      return const SizedBox.shrink();
    }

    List<String> specialtyList = [];
    if (specialties is String) {
      specialtyList = specialties.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } else if (specialties is List) {
      specialtyList = specialties.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }

    if (specialtyList.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.complementaryElevation,
        border: Border.all(color: AppTheme.deepTeal.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.stars_rounded,
                color: AppTheme.deepTeal,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Specialties',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: specialtyList.map((specialty) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGreen.withOpacity(0.1),
                      AppTheme.primaryGreen.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  specialty,
                  style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // (Removed unused legacy info section)
  // ignore: unused_element
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.complementaryElevation,
              ),
              child: _ExpandableText(
                text: displayStory,
                maxLines: 4,
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
    // Removed unused: photoCaptions, behindTheScenes
    
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
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 2 : 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                  itemCount: displayPhotos.length,
                  itemBuilder: (context, index) {
                    final photoUrl = displayPhotos[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                        child: SafeNetworkImage(
                          imageUrl: photoUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: AppTheme.cloud,
                        child: Icon(Icons.image, color: AppTheme.deepTeal, size: 36),
                        ),
                      ),
                    );
                  },
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



  // Removed unused: _showImageZoom (zoom handled within image components if needed)

  // Helper method to generate sample photos
  // Removed unused: _fetchProductImages

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

  // Removed unused: _buildVideoPlayer

  // Removed unused: _buildFeaturedProducts

  // Helper method to build reviews section
  // (Removed unused legacy reviews section)
  // ignore: unused_element
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
  
  // Removed unused: _formatTimestamp

  // Removed unused functions: _getStoreType, _buildStatCard (duplicate), _buildQuickActions
}

// _ExpandableText widget for expandable story section
class _ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;

  const _ExpandableText({
    required this.text,
    this.maxLines = 3,
  });

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        AnimatedCrossFade(
          firstChild: Text(
            widget.text,
            maxLines: widget.maxLines,
            overflow: TextOverflow.ellipsis,
                  style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              height: 1.5,
            ),
          ),
          secondChild: Text(
            widget.text,
                style: TextStyle(
              color: Colors.grey[700],
                  fontSize: 14,
              height: 1.5,
            ),
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
        if (widget.text.length > 100)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Text(
                _isExpanded ? 'Show less' : 'Read more',
                style: const TextStyle(
                  color: AppTheme.deepTeal,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
            ),
        ),
      ],
    );
  }
} 
