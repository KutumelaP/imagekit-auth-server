import 'package:cloud_firestore/cloud_firestore.dart';

class SubcategorySuggestionsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _docPath = 'admin_settings';
  static const String _docId = 'subcategory_suggestions';

  static Future<List<String>> fetchForCategory(String category) async {
    final String key = (category).trim();
    try {
      final doc = await _db.collection(_docPath).doc(_docId).get();
      final data = doc.data();
      if (data == null) return <String>[];
      final dynamic list = data[key];
      if (list is List) {
        final set = <String>{...list.cast<String>()};
        final out = set.toList()..sort((a,b)=>a.toLowerCase().compareTo(b.toLowerCase()));
        return out;
      }
      return <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  static Future<void> addSuggestion(String category, String subcategory) async {
    final String key = (category).trim();
    final String value = (subcategory).trim();
    if (key.isEmpty || value.isEmpty) return;
    await _db.collection(_docPath).doc(_docId).set({
      key: FieldValue.arrayUnion([value])
    }, SetOptions(merge: true));
  }
}


