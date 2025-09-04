import 'package:cloud_firestore/cloud_firestore.dart';
import 'category_normalizer.dart';

class SubcategorySuggestionsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _docPath = 'admin_settings';
  static const String _docId = 'subcategory_suggestions';

  static Future<List<String>> fetchForCategory(String category) async {
    final String key = CategoryNormalizer.normalizeCategory(category);
    try {
      final doc = await _db.collection(_docPath).doc(_docId).get();
      final data = doc.data();
      if (data == null) return <String>[];
      final dynamic list = data[key];
      if (list is List) {
        return CategoryNormalizer.canonicalizeList(list.cast<String>());
      }
      return <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  static Future<void> addSuggestion(String category, String subcategory) async {
    final String key = CategoryNormalizer.normalizeCategory(category);
    final String value = CategoryNormalizer.normalizeSubcategory(subcategory);
    if (key.isEmpty || value.isEmpty) return;
    await _db.collection(_docPath).doc(_docId).set({
      key: FieldValue.arrayUnion([value])
    }, SetOptions(merge: true));
  }
}


