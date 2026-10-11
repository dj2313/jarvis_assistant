import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'agent_models.dart';

class IntentRouter {
  static const String _groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  // Use central config — do NOT hardcode model names here
  static String get _model => Config.groqModelFast;

  static const Map<String, List<String>> _keywordMap = {
    'time_query': [
      'what time',
      'current time',
      'time now',
      'what\'s the time',
      'tell me the time',
    ],
    'date_query': ['what date', 'today\'s date', 'current date', 'what day'],
    'set_reminder': [
      'set reminder',
      'remind me',
      'create reminder',
      'add reminder',
    ],
    'open_app': ['open ', 'launch ', 'start ', 'run '],
    'send_message': [
      'message',
      'text',
      'send',
      'whatsapp',
      'snapchat',
      'telegram',
      'sms',
      'email',
    ],
    'gps_navigation': [
      'navigate to',
      'directions to',
      'take me to',
      'route to',
      'how do i get to',
      'gps to',
    ],
    'location_query': [
      'where am i',
      'my location',
      'what is my location',
      'current location',
      'where are we',
      'locate me',
      'gps location',
    ],
    'web_search': [
      'search for',
      'look up',
      'find out',
      'google',
      'who is',
      'what is',
      'how to',
      'when did',
      'near me',
      'nearby',
      'best places',
      'places to visit',
      'restaurants',
      'traffic',
      'news',
      'latest',
      'current price',
      'opening hours',
    ],
    'memory_save': ['remember', 'save this', 'note that', 'store this'],
    'memory_search': ['recall', 'what did i', 'do you remember', 'what was'],
    'weather_query': ['weather', 'temperature', 'forecast', 'rain'],
    'system_status': [
      'battery',
      'system status',
      'device info',
      'phone status',
    ],
  };

  Future<IntentResult> route(String input) async {
    final lowerInput = input.toLowerCase().trim();

    final keywordResult = _matchKeywords(lowerInput);
    if (keywordResult != null) {
      return keywordResult;
    }

    return _llmFallbackRoute(lowerInput);
  }

  IntentResult? _matchKeywords(String input) {
    for (final entry in _keywordMap.entries) {
      for (final keyword in entry.value) {
        if (input.contains(keyword)) {
          return _buildIntentResult(entry.key, 0.95);
        }
      }
    }
    return null;
  }

  IntentResult _buildIntentResult(String intent, double confidence) {
    switch (intent) {
      case 'time_query':
      case 'date_query':
        return IntentResult(
          intent: intent,
          confidence: confidence,
          suggestedTools: ['current_time'],
          requiresWeb: false,
          requiresMemory: false,
          requiresTool: true,
          requiresPlanning: false,
          requiresConfirmation: false,
        );
      case 'set_reminder':
        return IntentResult(
          intent: intent,
          confidence: confidence,
          suggestedTools: ['save_memory'],
          requiresWeb: false,
          requiresMemory: true,
          requiresTool: true,
          requiresPlanning: false,
          requiresConfirmation: true,
        );
      case 'open_app':
        return IntentResult(
          intent: intent,
          confidence: confidence,
          suggestedTools: ['open_app'],
          requiresWeb: false,
          requiresMemory: false,
          requiresTool: true,
          requiresPlanning: false,
          requiresConfirmation: true,
        );
      case 'send_message':
        return IntentResult(
          intent: intent,
          confidence: confidence,
          suggestedTools: ['send_message'],
          requiresWeb: false,
          requiresMemory: false,
          requiresTool: true,
          requiresPlanning: false,
          requiresConfirmation: true,
        );
      case 'gps_navigation':
        return IntentResult(
          intent: intent,
          confidence: confidence,
          suggestedTools: ['navigate'],
          requiresWeb: false,
          requiresMemory: false,
          requiresTool: true,
          requiresPlanning: false,
          requiresConfirmation: false,
        );
      case 'location_query':
        return IntentResult(
          intent: intent,
          confidence: confidence,
          suggestedTools: ['get_location'],
          requiresWeb: false,
          requiresMemory: false,
          requiresTool: true,
          requiresPlanning: false,
          requiresConfirmation: false,
        );
      case 'web_search':
        return IntentResult(
          intent: intent,
          confidence: confidence,
          suggestedTools: ['web_search'],
          requiresWeb: true,
          requiresMemory: false,
          requiresTool: true,
          requiresPlanning: false,
          requiresConfirmation: false,
        );
      case 'memory_save':
        return IntentResult(
          intent: intent,
          confidence: confidence,
          suggestedTools: ['save_memory'],
          requiresWeb: false,
          requiresMemory: true,
          requiresTool: true,
          requiresPlanning: false,
          requiresConfirmation: true,
        );
      case 'memory_search':
        return IntentResult(
          intent: intent,
          confidence: confidence,
          suggestedTools: ['search_memory'],
          requiresWeb: false,
          requiresMemory: true,
          requiresTool: true,
          requiresPlanning: false,
          requiresConfirmation: false,
        );
      case 'weather_query':
        return IntentResult(
          intent: intent,
          confidence: confidence,
          suggestedTools: ['get_location', 'get_weather'],
          requiresWeb: false,
          requiresMemory: false,
          requiresTool: true,
          requiresPlanning: false,
          requiresConfirmation: false,
        );
      case 'system_status':
        return IntentResult(
          intent: intent,
          confidence: confidence,
          suggestedTools: ['get_battery'],
          requiresWeb: false,
          requiresMemory: false,
          requiresTool: true,
          requiresPlanning: false,
          requiresConfirmation: false,
        );
      default:
        return IntentResult.unknown();
    }
  }

  Future<IntentResult> _llmFallbackRoute(String input) async {
    try {
      final apiKey = Config.groqApiKey;
      if (apiKey.isEmpty) return IntentResult.unknown();

      final prompt =
          '''Classify the user's intent. Return ONLY a JSON object with these fields:
- intent: string (one of: time_query, date_query, set_reminder, open_app, send_message, gps_navigation, location_query, web_search, memory_save, memory_search, weather_query, system_status, general_chat, unknown)
- confidence: number (0.0-1.0)
- suggestedTools: array of strings (tool names: current_time, open_app, send_message, navigate, get_location, get_weather, search_memory, save_memory, web_search, get_battery)
- requiresWeb: boolean
- requiresMemory: boolean
- requiresTool: boolean
- requiresPlanning: boolean
- requiresConfirmation: boolean

User input: "$input"

Examples:
- "What time is it?" -> {"intent":"time_query","confidence":0.99,"suggestedTools":["current_time"],"requiresWeb":false,"requiresMemory":false,"requiresTool":true,"requiresPlanning":false,"requiresConfirmation":false}
- "Remind me to call mom at 5" -> {"intent":"set_reminder","confidence":0.95,"suggestedTools":["save_memory"],"requiresWeb":false,"requiresMemory":true,"requiresTool":true,"requiresPlanning":false,"requiresConfirmation":true}
- "Open Spotify" -> {"intent":"open_app","confidence":0.9,"suggestedTools":["open_app"],"requiresWeb":false,"requiresMemory":false,"requiresTool":true,"requiresPlanning":false,"requiresConfirmation":true}
- "Send a WhatsApp message to John saying I'm running late" -> {"intent":"send_message","confidence":0.95,"suggestedTools":["send_message"],"requiresWeb":false,"requiresMemory":false,"requiresTool":true,"requiresPlanning":false,"requiresConfirmation":true}
- "Who won the super bowl 2024?" -> {"intent":"web_search","confidence":0.95,"suggestedTools":["web_search"],"requiresWeb":true,"requiresMemory":false,"requiresTool":true,"requiresPlanning":false,"requiresConfirmation":false}
- "What's my schedule today?" -> {"intent":"memory_search","confidence":0.9,"suggestedTools":["search_memory"],"requiresWeb":false,"requiresMemory":true,"requiresTool":true,"requiresPlanning":false,"requiresConfirmation":false}
- "How are you?" -> {"intent":"general_chat","confidence":0.9,"suggestedTools":[],"requiresWeb":false,"requiresMemory":false,"requiresTool":false,"requiresPlanning":false,"requiresConfirmation":false}''';

      return await _callGroqForIntent(prompt);
    } catch (e) {
      return IntentResult.unknown();
    }
  }

  Future<IntentResult> _callGroqForIntent(String prompt) async {
    try {
      final apiKey = Config.groqApiKey;
      if (apiKey.isEmpty) return IntentResult.unknown();

      final headers = {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

      final body = jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'system',
            'content': 'You are an intent classifier. Output ONLY valid JSON.',
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.1,
        'response_format': {'type': 'json_object'},
        'max_tokens': 200,
      });

      final response = await http
          .post(Uri.parse(_groqEndpoint), headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] ?? '{}';
        final json = jsonDecode(content) as Map<String, dynamic>;
        return IntentResult(
          intent: json['intent'] ?? 'unknown',
          confidence: (json['confidence'] ?? 0.5).toDouble(),
          suggestedTools: List<String>.from(json['suggestedTools'] ?? []),
          requiresWeb: json['requiresWeb'] ?? false,
          requiresMemory: json['requiresMemory'] ?? false,
          requiresTool: json['requiresTool'] ?? false,
          requiresPlanning: json['requiresPlanning'] ?? false,
          requiresConfirmation: json['requiresConfirmation'] ?? false,
        );
      }
      return IntentResult.unknown();
    } catch (e) {
      return IntentResult.unknown();
    }
  }
}
