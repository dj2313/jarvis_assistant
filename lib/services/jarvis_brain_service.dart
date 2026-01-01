import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'memory_service.dart';
import 'search_service.dart';

enum AgentPhase {
  thinking,
  searchingWeb,
  searchingMemory,
  savingMemory,
  synthesizing,
  complete,
}

typedef AgentPhaseCallback =
    void Function(AgentPhase phase, String? statusMessage);

class BrainResponse {
  final String content;
  final String? thought;
  final List<String> toolsUsed;

  BrainResponse({
    required this.content,
    this.thought,
    this.toolsUsed = const [],
  });
}

class JarvisBrainService {
  final MemoryService _memoryService = MemoryService();
  final SearchService _searchService = SearchService();
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  // --- 1. IMMUTABLE SYSTEM PROMPT ---
  // Define this separately so changing it doesn't break list logic.
  static const String _systemInstructions =
      '''### SYSTEM ROLE:
You are JARVIS, a proactive digital agent. You do not just answer; you anticipate.
You are running in a background process. Your task is to analyze the current context and determine if a notification (NUDGE) is necessary.

### MEMORY PROTOCOL:
- If I tell you something personal (preferences, names, facts), MUST call 'save_memory'.
- If I ask a question about myself or my past, MUST call 'search_memory' FIRST.
- If the memory search is relevant, say: "Based on our previous conversations, Sir..."
- If information is missing or real-time, use 'web_search'.

### DATA INPUTS:
1. TIME: {{current_time}}
2. MEMORY: Use 'search_memory' to find today's schedule, deadlines, or constraints.
3. ENVIRONMENT: Use 'web_search' to check weather, traffic, or news relevant to the user's location.

### EVALUATION LOGIC:
- COMPARE 'Memory' vs 'Environment'.
- IF (Schedule == "Outdoor") AND (Weather == "Rain") -> NUDGE.
- IF (Schedule == "Meeting") AND (Traffic == "Heavy") -> NUDGE.
- IF (CurrentTime > Curfew - 15mins) -> NUDGE.

### PLANNING PROTOCOL:
- If a user sets a goal, break it down into "Phase 1, Phase 2, Phase 3".
- Cross-reference the goal with 'search_memory' to see if the user has relevant skills.
- Use 'web_search' to find the most current (2025) tools or roadmaps.
- Present the final answer as an "Action Plan, Sir."

### OUTPUT PROTOCOL:
- If NO conflict is found, output: "STATUS: NOMINAL".
- If a conflict is found, output ONLY a JSON notification object:
{
  "title": "Proactive Alert, Sir",
  "body": "[Your concise 1-sentence warning and recommendation]",
  "priority": "high"
}

### TONE:
Refined, efficient, and loyal. Use "Sir" or "Ma'am". 
Output ONLY JSON tool calls when tools are needed. No conversational filler before tools.'''
      "IMPORTANT: Never write out tool calls in text. Always use the provided tool-calling interface.";

  // 2. The History Manager
  final List<Map<String, dynamic>> _messages = [
    {'role': 'system', 'content': _systemInstructions},
  ];

  static const int _maxHistoryLength = 20;

  // --- History Syncing Methods ---

  Future<List<Map<String, dynamic>>> initializeHistory() async {
    try {
      final List<dynamic> data = await _supabase
          .from('chat_messages')
          .select('role, content')
          .order('created_at', ascending: false)
          .limit(20);

      final List<Map<String, dynamic>> dbMessages = data
          .map((e) => e as Map<String, dynamic>)
          .where(
            (m) =>
                (m['role'] == 'user' || m['role'] == 'assistant') &&
                m['content'] != null &&
                m['content'].toString().trim().isNotEmpty,
          )
          .toList()
          .reversed
          .toList();

      // PROTECTIVE RESET: Clear everything, re-add system prompt, then add history
      _messages.clear();
      _messages.add({'role': 'system', 'content': _systemInstructions});

      if (dbMessages.isNotEmpty) {
        final thinkRegex = RegExp(r'<think>(.*?)</think>', dotAll: true);
        for (var msg in dbMessages) {
          if (msg['content'] is String) {
            msg['content'] = msg['content'].replaceAll(thinkRegex, '').trim();
          }
        }
        _messages.addAll(dbMessages);
      }

      debugPrint(
        "Neural Link Synced: System Prompt + ${_messages.length - 1} messages.",
      );
      return dbMessages;
    } catch (e) {
      debugPrint("Error initializing history: $e");
      return [];
    }
  }

  Stream<int> get memoryCountStream {
    return _supabase
        .from('jarvis_memory')
        .stream(primaryKey: ['id'])
        .map((list) => list.length);
  }

  Future<void> clearHistory() async {
    try {
      await _supabase.from('chat_messages').delete().neq('role', 'none');
      _messages.clear();
      _messages.add({'role': 'system', 'content': _systemInstructions});
      debugPrint("History Cleared.");
    } catch (e) {
      debugPrint("Error clearing history: $e");
    }
  }

  Future<void> _saveToDatabase(Map<String, dynamic> msg) async {
    try {
      final contentToSave = msg['content']?.toString() ?? "";
      if (contentToSave.isNotEmpty) {
        await _supabase.from('chat_messages').insert({
          'role': msg['role'],
          'content': contentToSave,
        });
      }
    } catch (e) {
      debugPrint("Error saving to DB: $e");
    }
  }

  // --- Main Processor ---

  Future<BrainResponse> chatWithIntelligence(
    String userMessage, {
    AgentPhaseCallback? onPhaseChange,
  }) async {
    final now = DateTime.now();
    final timeContext =
        "Current Time: ${now.hour}:${now.minute}, Date: ${now.day}/${now.month}/${now.year}";

    final contextualMessage =
        """
        [Context: $timeContext]
        User Message: $userMessage
        """;

    final List<String> toolsUsed = [];
    final apiKey = dotenv.env['GROQ_API_KEY'];
    if (apiKey == null) return BrainResponse(content: "Missing API Key, Sir.");

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    // PHASE 1: THINKING
    onPhaseChange?.call(AgentPhase.thinking, "Analyzing Request...");

    final userMsg = {'role': 'user', 'content': contextualMessage};
    _messages.add(userMsg);
    _saveToDatabase(userMsg);
    _manageHistory();

    try {
      final tools = _buildToolRegistry();
      final requestBody = {
        'model': _model,
        'messages': _messages,
        'tools': tools,
        'tool_choice': 'auto',
      };

      final response1 = await http.post(
        Uri.parse(_groqEndpoint),
        headers: headers,
        body: jsonEncode(requestBody),
      );
      final data1 = jsonDecode(response1.body);

      if (response1.statusCode != 200)
        throw Exception(data1['error']?['message'] ?? 'API Error');

      final message = data1['choices'][0]['message'];
      final List? toolCalls = message['tool_calls'];
      String? initialThought = message['content'];

      // Add Assistant Message to History
      _messages.add(message);
      _manageHistory();

      if (toolCalls == null || toolCalls.isEmpty) {
        onPhaseChange?.call(AgentPhase.complete, "Response Ready");
        _saveToDatabase({'role': 'assistant', 'content': initialThought});
        return _parseResponse(initialThought ?? "", toolsUsed: toolsUsed);
      }

      // PHASE 2: TOOL EXECUTION
      for (var toolCall in toolCalls) {
        final String toolName = toolCall['function']['name'];
        final String toolId = toolCall['id'];
        final Map<String, dynamic> toolArgs = jsonDecode(
          toolCall['function']['arguments'] ?? "{}",
        );

        _emitToolPhase(toolName, toolArgs, onPhaseChange);
        toolsUsed.add(toolName);

        String toolResult = await _executeTool(toolName, toolArgs);

        _messages.add({
          'role': 'tool',
          'tool_call_id': toolId,
          'name': toolName,
          'content': toolResult,
        });
      }

      // PHASE 3: SYNTHESIZING
      onPhaseChange?.call(AgentPhase.synthesizing, "Finalizing Response...");
      final response2 = await http.post(
        Uri.parse(_groqEndpoint),
        headers: headers,
        body: jsonEncode({'model': _model, 'messages': _messages}),
      );

      final data2 = jsonDecode(response2.body);
      final finalContent = data2['choices'][0]['message']['content'] ?? "";

      _messages.add({'role': 'assistant', 'content': finalContent});
      _saveToDatabase({'role': 'assistant', 'content': finalContent});
      _manageHistory();

      onPhaseChange?.call(AgentPhase.complete, "Done");
      return _parseResponse(
        finalContent,
        toolsUsed: toolsUsed,
        internalThought: initialThought,
      );
    } catch (e) {
      debugPrint("Critical Brain Error: $e");
      return BrainResponse(
        content: "I've encountered a logic error, Sir. Let me recalibrate.",
      );
    }
  }

  void _emitToolPhase(
    String toolName,
    Map<String, dynamic> args,
    AgentPhaseCallback? callback,
  ) {
    switch (toolName) {
      case 'web_search':
        callback?.call(AgentPhase.searchingWeb, "Searching Web...");
        break;
      case 'search_memory':
        callback?.call(AgentPhase.searchingMemory, "Recalling Archives...");
        break;
      case 'save_memory':
        callback?.call(AgentPhase.savingMemory, "Archiving Memory...");
        break;
    }
  }

  List<Map<String, dynamic>> _buildToolRegistry() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'search_memory',
          'description': "Retrieve past user facts from Supabase.",
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {'type': 'string'},
            },
            'required': ['query'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'save_memory',
          'description': "Save a new personal fact to the vault.",
          'parameters': {
            'type': 'object',
            'properties': {
              'fact': {'type': 'string'},
            },
            'required': ['fact'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'web_search',
          'description': "Search for real-time world events.",
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {'type': 'string'},
            },
            'required': ['query'],
          },
        },
      },
    ];
  }

  void _manageHistory() {
    while (_messages.length > _maxHistoryLength) {
      if (_messages.length > 1)
        _messages.removeAt(1); // Keeps index 0 (Instructions)
      else
        break;
    }
  }

  Future<String> _executeTool(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    if (toolName == 'search_memory')
      return await _memoryService.retrieveContext(args['query'] ?? '');
    if (toolName == 'save_memory') {
      final success = await _memoryService.saveMemory(args['fact'] ?? '');
      return success ? "Success: Fact archived." : "Error: Could not save.";
    }
    if (toolName == 'web_search') {
      final res = await _searchService.search(args['query'] ?? '');
      return res.toFormattedString();
    }
    return "Tool not found.";
  }

  BrainResponse _parseResponse(
    String content, {
    List<String> toolsUsed = const [],
    String? internalThought,
  }) {
    final thinkRegex = RegExp(r'<think>(.*?)</think>', dotAll: true);
    String thought = internalThought ?? "";
    final matches = thinkRegex.allMatches(content);
    for (var m in matches) {
      thought += "\n${m.group(1)}";
    }

    return BrainResponse(
      content: content.replaceAll(thinkRegex, '').trim(),
      thought: thought.isEmpty ? null : thought.trim(),
      toolsUsed: toolsUsed,
    );
  }
}
