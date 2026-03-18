import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  // Supabase Configuration
  // These should be set in .env file or environment variables
  static String get supabaseUrl {
    return _getConfig('SUPABASE_URL');
  }

  static String get supabaseAnonKey {
    return _getConfig('SUPABASE_ANON_KEY');
  }

  // API Keys - MUST be set in .env file for security
  static String get groqApiKey {
    return _getConfig('GROQ_API_KEY', required: true);
  }

  static String get hfToken {
    return _getConfig('HF_TOKEN', required: true);
  }

  static String get tavilyApiKey {
    return _getConfig('TAVILY_API_KEY', required: true);
  }

  static String _getConfig(String key, {bool required = false}) {
    final value = dotenv.env[key];

    if (required && (value == null || value.isEmpty)) {
      final errorMsg =
          """
❌ Missing required environment variable: $key

Please create a .env file in the project root with:
$key=your_value_here""";
      debugPrint(errorMsg);
      throw Exception(
        "Configuration Error: $key not found in environment variables",
      );
    }

    return value ?? '';
  }

  // Application Settings
  static const bool kIsDebugMode = kDebugMode;

  // API Configuration
  static const String groqModel = 'llama-3.3-70b-versatile';
  static const int groqMaxTokens = 512; // Reduced to save tokens
  static const double groqTemperature = 0.1;

  // Private constructor to prevent instantiation
  Config._();
}
