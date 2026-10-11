import 'agent_models.dart';

class IntentRouter {
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

    // No keyword match -> general chat. Deliberately NOT calling an LLM
    // classifier here: it cost a full extra Groq round-trip before the real
    // answer even started. The brain's own tool loop already decides when to
    // call search_memory / web_search etc., so a miss needs no pre-routing.
    return IntentResult.generalChat();
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
}
