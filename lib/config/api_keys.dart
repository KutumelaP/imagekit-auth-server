/// API Keys configuration for the food marketplace app
/// 
/// IMPORTANT: Never commit real API keys to version control!
/// Use environment variables or secure storage for production.
class ApiKeys {
  // Google Cloud Text-to-Speech API Key
  // Get this from: https://console.cloud.google.com/apis/credentials
  
  // For development - using hardcoded key
  // ⚠️ WARNING: Only use this for development, never for production!
  static const String googleTtsApiKey = 'AIzaSyC3-wknN1djCXg27d6uFyV480jBxagvn7o';
  
  // For production - use environment variable instead:
  // static const String googleTtsApiKey = String.fromEnvironment(
  //   'GOOGLE_TTS_API_KEY',
  //   defaultValue: '', // Empty string if not provided
  // );

  /// Check if Google TTS API key is available
  static bool get isGoogleTtsAvailable => googleTtsApiKey.isNotEmpty;

  /// Get the API key (returns empty string if not available)
  static String get googleTtsKey => googleTtsApiKey;
}
