import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CategoryService {
  static final CategoryService _instance = CategoryService._internal();
  factory CategoryService() => _instance;
  CategoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _cachedCategories = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Map<String, dynamic>> get categories => List.unmodifiable(_cachedCategories);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _cachedCategories.isNotEmpty;

  /// Load categories with caching
  Future<List<Map<String, dynamic>>> loadCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCategories.isNotEmpty) {
      return _cachedCategories;
    }

    if (_isLoading) {
      // Wait for current load to complete
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _cachedCategories;
    }

    _isLoading = true;
    _error = null;

    try {
      final snapshot = await _firestore
          .collection('categories')
          .limit(8)
          .get()
          .timeout(const Duration(seconds: 10));

      if (snapshot.docs.isEmpty) {
        _cachedCategories = getDefaultCategories();
      } else {
        _cachedCategories = snapshot.docs.map((doc) {
          final data = doc.data();
          String imageUrl = data['imageUrl'] ?? '';
          
          if (imageUrl.isEmpty) {
            imageUrl = getDefaultCategoryImage(data['name'] ?? '');
          }
          
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'imageUrl': imageUrl,
          };
        }).toList();
      }

      return _cachedCategories;
    } catch (e) {
      _error = 'Failed to load categories';
      _cachedCategories = getDefaultCategories();
      return _cachedCategories;
    } finally {
      _isLoading = false;
    }
  }

  /// Clear cache
  void clearCache() {
    _cachedCategories.clear();
    _error = null;
  }

  List<Map<String, dynamic>> getDefaultCategories() {
    return [
      {
        'id': 'clothing',
        'name': 'Clothing',
        'imageUrl': getDefaultCategoryImage('Clothing'),
      },
      {
        'id': 'electronics',
        'name': 'Electronics',
        'imageUrl': getDefaultCategoryImage('Electronics'),
      },
      {
        'id': 'food',
        'name': 'Food',
        'imageUrl': getDefaultCategoryImage('Food'),
      },
      {
        'id': 'other',
        'name': 'Other',
        'imageUrl': getDefaultCategoryImage('Other'),
      },
    ];
  }

  String getDefaultCategoryImage(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('clothing') || name.contains('fashion')) {
      return 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400&h=300&fit=crop';
    } else if (name.contains('electronics') || name.contains('tech')) {
      return 'https://images.unsplash.com/photo-1498049794561-7780e7231661?w=400&h=300&fit=crop';
    } else if (name.contains('food') || name.contains('restaurant')) {
      return 'https://images.unsplash.com/photo-1504674900240-9c9c0b1c6b8b?w=400&h=300&fit=crop';
    } else {
      return 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400&h=300&fit=crop';
    }
  }
}
