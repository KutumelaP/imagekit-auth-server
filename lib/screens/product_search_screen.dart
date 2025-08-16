import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/meili_search_service.dart';
import '../theme/app_theme.dart';
import '../widgets/safe_network_image.dart';
import 'stunning_product_detail.dart';

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    setState(() => _isLoading = true);
    final meili = MeiliSearchService.instance;
    if (meili.isConfigured) {
      final hits = await meili.searchProducts(q);
      setState(() {
        _results = hits;
        _isLoading = false;
      });
      return;
    }
    // Fallback Firestore simple search (name prefix)
    final snap = await FirebaseFirestore.instance
        .collection('products')
        .where('status', isEqualTo: 'active')
        .where('name', isGreaterThanOrEqualTo: q)
        .where('name', isLessThan: '$q\uf8ff')
        .limit(20)
        .get();
    setState(() {
      _results = snap.docs.map((d) => d.data()).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: Colors.white,
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search products…',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (v) => _runSearch(v.trim()),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _runSearch(_controller.text.trim()),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? const Center(child: Text('Type to search'))
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final p = _results[i];
                    final name = p['name'] as String? ?? 'Product';
                    final price = (p['price'] as num?)?.toDouble() ?? 0;
                    final img = (p['imageUrl'] ?? p['photoUrl'] ?? p['image']) as String?;
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: img == null || img.isEmpty
                              ? Container(color: AppTheme.deepTeal.withOpacity(0.08))
                              : SafeNetworkImage(imageUrl: img, fit: BoxFit.cover),
                        ),
                      ),
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('R ${price.toStringAsFixed(2)}'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StunningProductDetail(product: p),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}


