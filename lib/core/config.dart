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

  // Optional backup LLM (Gemini free-tier Flash). Empty if not configured.
  static String get geminiApiKey {
    try {
      return _getConfig('GEMINI_API_KEY');
    } catch (_) {
      return '';
    }
  }

  static String _getConfig(String key, {bool required = false}) {
    final raw = dotenv.env[key]?.trim() ?? '';
    // flutter_dotenv may report "KEY = value" under a key with a trailing
    // space; also handle a bare "KEY=" line by looking up the trimmed key.
    final value =
        raw.isNotEmpty ? raw : (dotenv.env[key.trim()]?.trim() ?? '');

    if (required && value.isEmpty) {
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

    return value;
  }

  // Application Settings
  static const bool kIsDebugMode = kDebugMode;

  // API Configuration
  // Model tiering: fast model for normal conversation + tool selection,
  // more capable model for complex reasoning queries.
  static const String groqModelFast = 'openai/gpt-oss-120b';   // Primary LLM for conversation + tools
  static const String groqModelSmart = 'qwen/qwen3.8-27b';    // Complex reasoning + planning
  static const String sttModel = 'whisper-large-v3';           // Speech-to-Text model
  static const int groqMaxTokens = 2048; // Headroom for tool-calling + response
  static const double groqTemperature = 0.1;

  // Private constructor to prevent instantiation
  Config._();
}
