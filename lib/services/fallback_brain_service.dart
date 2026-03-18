import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FallbackBrainService - Local Ollama Integration
///
/// This service provides offline/backup AI capabilities using Ollama.
///
/// IMPORTANT NOTE FOR MOBILE:
/// Ollama runs on your PC/Desktop, NOT directly on mobile devices.
/// For mobile fallback to work, your phone must connect to Ollama
/// running on a computer on the same network.
///
/// SETUP INSTRUCTIONS:
/// 1. Install Ollama on your PC: https://ollama.ai
/// 2. Run: ollama pull llama3.2 (or phi3 for faster inference)
/// 3. Allow Ollama to accept external connections:
///    - Windows: Set OLLAMA_HOST=0.0.0.0 in environment variables
///    - Then restart Ollama
/// 4. Find your PC's local IP (e.g., 192.168.1.100)
/// 5. Set the Ollama URL in Friday settings to: http://192.168.1.100:11434
class FallbackBrainService {
  // Default Ollama URL - can be configured for network access
  String _ollamaBaseUrl;
  String _model;

  // Configurable timeout for local inference
  final Duration timeout;

  // Preference keys for storing configuration
  static const String _ollamaUrlKey = 'ollama_url';
  static const String _ollamaModelKey = 'ollama_model';

  FallbackBrainService({
    String ollamaUrl = "http://localhost:11434",
    String model = "llama3.2",
    this.timeout = const Duration(seconds: 120),
  }) : _ollamaBaseUrl = ollamaUrl,
       _model = model;

  /// Initialize from saved preferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _ollamaBaseUrl = prefs.getString(_ollamaUrlKey) ?? _ollamaBaseUrl;
      _model = prefs.getString(_ollamaModelKey) ?? _model;
      debugPrint(
        "FallbackService initialized: $_ollamaBaseUrl with model $_model",
      );
    } catch (e) {
      debugPrint("FallbackService init error: $e");
    }
  }

  /// Save Ollama configuration
  Future<void> setOllamaConfig({String? url, String? model}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url != null) {
        _ollamaBaseUrl = url;
        await prefs.setString(_ollamaUrlKey, url);
      }
      if (model != null) {
        _model = model;
        await prefs.setString(_ollamaModelKey, model);
      }
      debugPrint(
        "FallbackService config updated: $_ollamaBaseUrl with model $_model",
      );
    } catch (e) {
      debugPrint("FallbackService config save error: $e");
    }
  }

  /// Get current configuration
  Map<String, String> getConfig() => {'url': _ollamaBaseUrl, 'model': _model};

  /// System prompt for local Ollama model
  static const String _localSystemPrompt =
      '''You are Friday, a helpful AI assistant.
You are currently running on a local neural network as the primary cloud connection is unavailable.
Respond with the same refined, efficient, and loyal tone. Use "Sir" or "Ma'am".
Keep responses concise but helpful.''';

  /// Get response from Ollama server (local or network)
  ///
  /// Returns a fallback response when the primary Groq API is unavailable.
  /// This ensures Friday remains functional even when cloud is down.
  Future<String> getOfflineResponse(String prompt) async {
    try {
      debugPrint(
        "Local Neural Link: Connecting to Ollama at $_ollamaBaseUrl...",
      );

      final response = await http
          .post(
            Uri.parse('$_ollamaBaseUrl/api/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "model": _model,
              "prompt": "$_localSystemPrompt\n\nUser: $prompt\n\nAssistant:",
              "stream": false,
              "options": {"temperature": 0.7, "top_p": 0.9},
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String responseText = data['response'] ?? '';

        if (responseText.isNotEmpty) {
          debugPrint("Local Neural Link: Response received successfully.");
          return responseText.trim();
        }
        return "Local core responded with empty data, Sir.";
      } else if (response.statusCode == 404) {
        return "Model '$_model' not found, Sir. Please run: ollama pull $_model";
      } else {
        debugPrint("Ollama Error: ${response.statusCode} - ${response.body}");
        return "Local core returned status ${response.statusCode}, Sir.";
      }
    } on http.ClientException catch (e) {
      debugPrint("Ollama Connection Error: $e");
      return _getConnectionErrorMessage();
    } catch (e) {
      debugPrint("Fallback Service Error: $e");
      return _getConnectionErrorMessage();
    }
  }

  String _getConnectionErrorMessage() {
    if (_ollamaBaseUrl.contains('localhost') ||
        _ollamaBaseUrl.contains('127.0.0.1')) {
      return '''Unable to reach local Ollama server, Sir.

For mobile devices, Ollama must run on your PC:
1. Ensure Ollama is running on your computer
2. Set OLLAMA_HOST=0.0.0.0 in environment variables
3. Find your PC's IP address (e.g., 192.168.1.100)
4. Update the Ollama URL in settings to: http://YOUR_PC_IP:11434

Current URL: $_ollamaBaseUrl''';
    }
    return "Unable to reach Ollama at $_ollamaBaseUrl, Sir. Please verify the server is running and accessible.";
  }

  /// Check if Ollama server is available
  Future<bool> isOllamaAvailable() async {
    try {
      final response = await http
          .get(Uri.parse("$_ollamaBaseUrl/api/tags"))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Ollama availability check failed: $e");
      return false;
    }
  }

  /// Get connection status with details
  Future<Map<String, dynamic>> getConnectionStatus() async {
    try {
      final response = await http
          .get(Uri.parse("$_ollamaBaseUrl/api/tags"))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models =
            (data['models'] as List?)
                ?.map((m) => m['name'].toString())
                .toList() ??
            [];
        return {
          'connected': true,
          'url': _ollamaBaseUrl,
          'models': models,
          'currentModel': _model,
          'modelAvailable': models.contains(_model),
        };
      }
      return {
        'connected': false,
        'url': _ollamaBaseUrl,
        'error': 'Server returned ${response.statusCode}',
      };
    } catch (e) {
      return {'connected': false, 'url': _ollamaBaseUrl, 'error': e.toString()};
    }
  }

  /// Get list of available models from Ollama
  Future<List<String>> getAvailableModels() async {
    try {
      final response = await http
          .get(Uri.parse("$_ollamaBaseUrl/api/tags"))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> models = data['models'] ?? [];
        return models.map((m) => m['name'].toString()).toList();
      }
    } catch (e) {
      debugPrint("Failed to get Ollama models: $e");
    }
    return [];
  }
}
