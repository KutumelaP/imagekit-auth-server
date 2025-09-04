import 'dart:collection';

class CategoryNormalizer {
  static final Map<String, String> _canonicalMap = _buildCanonicalMap();

  static Map<String, String> _buildCanonicalMap() {
    final Map<String, String> map = {};
    void add(String canonical, List<String> variants) {
      for (final v in variants) {
        map[v.toLowerCase().trim()] = canonical;
      }
    }
    // Clothing examples
    add('Hoodie', ['hoodie', 'hoodies', 'hooded sweater', 'hooded sweatshirts']);
    add('T-Shirt', ['t shirt', 't-shirt', 'tee', 'tees', 'tshirts']);
    add('Sneakers', ['sneaker', 'sneakers', 'trainer', 'trainers']);
    add('Jacket', ['jacket', 'jackets']);
    // Generic plural-singular fallback handled in normalizeWord
    return map;
  }

  static String normalizeCategory(String? value) {
    return _normalizeWord(value);
  }

  static String normalizeSubcategory(String? value) {
    return _normalizeWord(value);
  }

  static String _normalizeWord(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '';
    final lower = raw.toLowerCase();
    // Direct canonical map
    final direct = _canonicalMap[lower];
    if (direct != null) return direct;
    // Simple plural -> singular (naive) for common cases
    String singular = lower;
    if (singular.endsWith('ies') && singular.length > 3) {
      singular = singular.substring(0, singular.length - 3) + 'y';
    } else if (singular.endsWith('s') && !singular.endsWith('ss')) {
      singular = singular.substring(0, singular.length - 1);
    }
    final mapped = _canonicalMap[singular];
    if (mapped != null) return mapped;
    // Title case fallback
    return _toTitleCase(singular);
  }

  static String _toTitleCase(String input) {
    return input.split(RegExp(r"\s+")).map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : '');
    }).join(' ');
  }

  // Utilities for sets/lists
  static List<String> canonicalizeList(Iterable<String> values) {
    final LinkedHashSet<String> set = LinkedHashSet<String>();
    for (final v in values) {
      final n = normalizeSubcategory(v);
      if (n.isNotEmpty) set.add(n);
    }
    return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }
}


