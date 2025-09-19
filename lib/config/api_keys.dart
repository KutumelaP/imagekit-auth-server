/// API Keys configuration for the food marketplace app
/// 
/// IMPORTANT: Never commit real API keys to version control!
/// Use environment variables or secure storage for production.
class ApiKeys {
  // Google Cloud Text-to-Speech API Key
  // Get this from: https://console.cloud.google.com/apis/credentials
  
  // Use environment variables for security
  // Set these in your environment or build configuration
  static const String googleTtsApiKey = String.fromEnvironment(
    'GOOGLE_TTS_API_KEY',
    defaultValue: '', // Empty string if not provided
  );
  
  // OpenAI API Key (for GPT models)
  // Get this from: https://platform.openai.com/api-keys
  static const String openAiApiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '', // Empty string if not provided
  );
  
  // Google Generative AI (Gemini) API Key
  // Get this from: https://aistudio.google.com/app/apikey
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '', // Empty string if not provided
  );

  /// Check if Google TTS API key is available
  static bool get isGoogleTtsAvailable => googleTtsApiKey.isNotEmpty;

  /// Get the API key (returns empty string if not available)
  static String get googleTtsKey => googleTtsApiKey;

  /// LLM keys accessors
  static String get openAiKey => openAiApiKey;
  static String get geminiKey => geminiApiKey;
}
