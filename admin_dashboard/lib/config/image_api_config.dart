class ImageApiConfig {
  // Set this to your deployed serverless base URL (e.g., Vercel):
  // Example: https://your-project.vercel.app/api/imagekit
  static const String baseUrl = String.fromEnvironment(
    'IMAGE_API_BASE',
    // Set to your deployed endpoint; fallback to Cloud Function proxy if set
    defaultValue: 'https://us-central1-marketplace-8d6bd.cloudfunctions.net',
  );
  
  static String listUrl({int limit = 100, int skip = 0, String? path, String? searchQuery}) {
    final params = <String, String>{
      'limit': '$limit',
      'skip': '$skip',
    };
    if (path != null) params['path'] = path;
    if (searchQuery != null) params['searchQuery'] = searchQuery;
    final qp = params.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
    // If using Cloud Function proxy, adjust paths accordingly; else assume /api/imagekit
    final isCf = baseUrl.contains('cloudfunctions.net');
    return isCf ? '$baseUrl/listImagesHttp?$qp' : '$baseUrl/api/imagekit/list?$qp';
  }
  
  static String batchDeleteUrl() {
    final isCf = baseUrl.contains('cloudfunctions.net');
    return isCf ? '$baseUrl/batchDeleteImagesHttp' : '$baseUrl/api/imagekit/batchDelete';
  }
}
