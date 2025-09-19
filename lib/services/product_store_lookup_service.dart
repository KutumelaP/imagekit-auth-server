import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/smart_search_engine.dart';

class ProductStoreLookupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate a friendly store suggestion for a user query by searching products.
  static Future<String?> suggestStoresForQuery(String query, {int maxStores = 3}) async {
    final keyword = _extractKeyword(query);
    if (keyword == null) return null;

    try {
      final products = await SmartSearchEngine.searchProducts(
        query: keyword,
        inStock: true,
        sortBy: 'relevance',
      );
      if (products.isEmpty) return null;

      // Group by store ownerId
      final Map<String, List<Map<String, dynamic>>> byStore = {};
      for (final p in products) {
        final ownerId = (p['ownerId'] ?? p['storeId'] ?? '').toString();
        if (ownerId.isEmpty) continue;
        (byStore[ownerId] ??= []).add(p);
      }
      if (byStore.isEmpty) return null;

      // Build store entries with price range, store name, and specific products
      final List<_StoreEntry> entries = [];
      for (final entry in byStore.entries) {
        final ownerId = entry.key;
        final items = entry.value;
        double minPrice = double.infinity;
        double maxPrice = 0.0;
        final List<String> productNames = [];
        
        for (final p in items) {
          final price = (p['price'] as num?)?.toDouble() ?? 0.0;
          if (price > 0) {
            if (price < minPrice) minPrice = price;
            if (price > maxPrice) maxPrice = price;
          }
          
          // Collect product names for this store
          final productName = (p['name'] ?? '').toString().trim();
          if (productName.isNotEmpty && !productNames.contains(productName)) {
            productNames.add(productName);
          }
        }
        
        if (minPrice == double.infinity) {
          // No valid prices, skip
          continue;
        }
        
        // Fetch store name
        String storeName = await _getStoreName(ownerId);
        entries.add(_StoreEntry(
          ownerId: ownerId, 
          name: storeName, 
          minPrice: minPrice, 
          maxPrice: maxPrice,
          products: productNames.take(2).toList(), // Take first 2 product names
        ));
      }

      if (entries.isEmpty) return null;
      // Sort by min price then name
      entries.sort((a, b) {
        final byPrice = a.minPrice.compareTo(b.minPrice);
        if (byPrice != 0) return byPrice;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      final picks = entries.take(maxStores).toList();
      if (picks.isEmpty) return null;


      // Build specific store suggestions with products
      final List<String> storeSuggestions = [];
      for (final store in picks) {
        if (store.products.isNotEmpty) {
          final productList = store.products.join(' and ');
          storeSuggestions.add('${store.name} (has $productList)');
        } else {
          storeSuggestions.add(store.name);
        }
      }

      final leadOptions = [
        "I found some stores with $keyword",
        "Here are stores that have $keyword",
        "Great! These stores carry $keyword",
      ];
      final lead = leadOptions[(query.hashCode.abs()) % leadOptions.length];
      final suggestion = storeSuggestions.join(', ');
      return "$lead — $suggestion. Want me to open search for \"$keyword\"?";
    } catch (e) {
      // Fail silently; we can fallback to generic reply
      return null;
    }
  }

  /// List a few store names, optionally filtered by category.
  /// Returns up to [maxStores] names, sorted by rating when available.
  static Future<List<String>> listStoreNames({String? category, int maxStores = 5}) async {
    try {
      final stores = await SmartSearchEngine.searchStores(
        query: '',
        category: category,
        verified: true,
        sortBy: 'rating',
      );

      final List<String> names = [];
      for (final s in stores) {
        final name = (s['storeName'] ?? s['displayName'] ?? s['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        names.add(name);
        if (names.length >= maxStores) break;
      }
      return names;
    } catch (_) {
      return [];
    }
  }

  static Future<String> _getStoreName(String ownerId) async {
    try {
      final doc = await _firestore.collection('users').doc(ownerId).get();
      final data = doc.data() ?? {};
      final name = (data['storeName'] ?? data['displayName'] ?? data['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
      final email = (data['email'] ?? '').toString();
      if (email.isNotEmpty && email.contains('@')) {
        return email.split('@').first;
      }
    } catch (_) {}
    return 'Store';
  }

  static String? _extractKeyword(String q) {
    final cleaned = q.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    final tokens = cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return null;
    final stop = {
      'i','want','to','find','buy','get','me','a','an','the','and','or','with','on','of','is','are','there','this','that','do','you','have','any','store','shop','sell','where','can','for'
    };
    for (int i = tokens.length - 1; i >= 0; i--) {
      final t = tokens[i];
      if (t.length >= 3 && !stop.contains(t)) return t;
    }
    return null;
  }
}

class _StoreEntry {
  final String ownerId;
  final String name;
  final double minPrice;
  final double maxPrice;
  final List<String> products;
  _StoreEntry({
    required this.ownerId, 
    required this.name, 
    required this.minPrice, 
    required this.maxPrice,
    required this.products,
  });
}


