class ImageApiConfig {
  // Set this to your deployed serverless base URL (e.g., Vercel):
  // Example: https://your-project.vercel.app/api/imagekit
  static const String baseUrl = String.fromEnvironment(
    'IMAGE_API_BASE',
    defaultValue: 'https://your-vercel-domain.vercel.app/api/imagekit',
  );
  
  static String listUrl({int limit = 100, int skip = 0, String? path, String? searchQuery}) {
    final params = <String, String>{
      'limit': '$limit',
      'skip': '$skip',
    };
    if (path != null) params['path'] = path;
    if (searchQuery != null) params['searchQuery'] = searchQuery;
    final qp = params.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
    return '$baseUrl/list?$qp';
  }
  
  static String batchDeleteUrl() => '$baseUrl/batchDelete';
}
