import 'dart:convert';
import 'package:http/http.dart' as http;

class MeiliSearchService {
  MeiliSearchService._();
  static final MeiliSearchService instance = MeiliSearchService._();

  final String _host = const String.fromEnvironment('MEILI_HOST', defaultValue: '');
  final String _publicKey = const String.fromEnvironment('MEILI_PUBLIC_KEY', defaultValue: '');
  final String _index = const String.fromEnvironment('MEILI_PRODUCTS_INDEX', defaultValue: 'products');

  bool get isConfigured => _host.isNotEmpty && _publicKey.isNotEmpty;

  // Basic synonym expansion for SA slang/abbreviations
  String _expandSynonyms(String query) {
    final q = query.toLowerCase();
    final map = <String, List<String>>{
      'joburg': ['johannesburg', 'jozi', 'jhb'],
      'jozi': ['johannesburg', 'jhb'],
      'pta': ['pretoria'],
      'durbs': ['durban'],
      'cpt': ['cape town'],
      'ct': ['cape town'],
      'sarmie': ['sandwich'],
      'sarmies': ['sandwiches'],
      'boerie': ['boerewors'],
      'koeksister': ['koesister'],
      'akesh': ['akesh', 'akesh cake'],
    };
    final expanded = <String>{q};
    map.forEach((k, vals) {
      if (q.contains(k)) {
        expanded.addAll(vals.map((e) => q.replaceAll(k, e)));
      }
    });
    return expanded.join(' ');
  }

  Future<List<Map<String, dynamic>>> searchProducts(String query, {int limit = 20}) async {
    if (!isConfigured) return [];
    final url = Uri.parse('$_host/indexes/$_index/search');
    final body = {
      'q': _expandSynonyms(query),
      'limit': limit,
      'attributesToHighlight': ['name', 'description']
    };
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_publicKey',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final hits = (data['hits'] as List).cast<Map<String, dynamic>>();
      return hits;
    }
    return [];
  }
}


