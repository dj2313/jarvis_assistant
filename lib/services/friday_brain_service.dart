import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/config.dart';
import 'memory_service.dart';
import 'search_service.dart';
import 'fallback_brain_service.dart';
import 'token_manager.dart';

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

class FridayBrainService {
  final MemoryService _memoryService = MemoryService();
  final SearchService _searchService = SearchService();
  final FallbackBrainService _fallbackService = FallbackBrainService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final TokenManager _tokenManager = TokenManager();

  // Notification Plugin for Proactive Nudges
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

  static const String _groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  // --- 1. IMMUTABLE SYSTEM PROMPT ---
  // Define this separately so changing it doesn't break list logic.
  static const String _systemInstructions = '''### SYSTEM ROLE:
You are FRIDAY, a proactive digital agent. You do not just answer; you anticipate.
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
- If NO tool is active, speak naturally.
- If NO conflict is found in Sentinel mode, output: "STATUS: NOMINAL".
- If a conflict is found, output ONLY a JSON notification object:
{
  "title": "Proactive Alert, Sir",
  "body": "[Your concise 1-sentence warning and recommendation]",
  "priority": "high"
}

### TONE:
Refined, efficient, and loyal. Use "Sir" or "Ma'am".

### CRITICAL INSTRUCTION:
- YOU MUST ANSWER DIRECTLY if the information is available in the [Context] (Time, Date, etc.).
- NEVER write out tool calls manually using "<function>" tags.
- ALWAYS use the specific Tool Calling interface provided by the API.
- If you use a tool, do NOT include conversational filler until the tool result is synthesized.
- For device info queries (about the phone), inform the user you are monitoring local thermal and battery subsystems (even if simulated for now).''';

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
        final functionRegex = RegExp(
          r'<function>(.*?)</function>',
          dotAll: true,
        );

        for (var msg in dbMessages) {
          if (msg['content'] is String) {
            String content = msg['content'];
            content = content.replaceAll(thinkRegex, '').trim();
            content = content.replaceAll(functionRegex, '').trim();
            msg['content'] = content;
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
        .from('Friday_memory')
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
    // Initialize token manager
    await _tokenManager.initialize();
    _tokenManager.loadSavedState();

    // Check daily limits BEFORE processing
    if (!_tokenManager.canMakeChatRequest()) {
      final resetTime = _getTomorrowMidnight();
      return BrainResponse(
        content: "Daily chat limit of 5 reached, Sir. The neural link will reset at $resetTime.",
        toolsUsed: [],
      );
    }

    // Estimate and check token usage
    final estimatedTokens = _tokenManager.estimateTokenCount(userMessage);
    if (!_tokenManager.canMakeTokenRequest(estimatedTokens)) {
      final resetTime = _getTomorrowMidnight();
      return BrainResponse(
        content: "Daily token limit reached, Sir. The neural link will reset at $resetTime.",
        toolsUsed: [],
      );
    }

    final now = DateTime.now();
    final timeContext =
        "Current Time: ${now.hour}:${now.minute}, Date: ${now.day}/${now.month}/${now.year}";

    final deviceContext = "Battery: 89%, Status: NOMINAL, Thermal: Optimal";

    final contextualMessage =
        """
        [Context: $timeContext]
        [System: $deviceContext]
        User Message: $userMessage
        [Token Budget: ${_tokenManager.getRemainingTokens()} tokens remaining]
        """;

    final List<String> toolsUsed = [];
    final apiKey = Config.groqApiKey;
    if (apiKey.isEmpty) return BrainResponse(content: "Missing API Key, Sir.");

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
        'temperature': 0.1, // Lower temperature for reliable tool calling
        'max_tokens': 1024,
      };

      final response1 = await http.post(
        Uri.parse(_groqEndpoint),
        headers: headers,
        body: jsonEncode(requestBody),
      );
      final data1 = jsonDecode(response1.body);

      // Check for rate limiting (429) or other API errors
      if (response1.statusCode == 429) {
        debugPrint(
          "Groq API Rate Limited (429). Switching to Local Neural Link...",
        );
        throw Exception("RATE_LIMITED");
      }

      if (response1.statusCode != 200) {
        throw Exception(data1['error']?['message'] ?? 'API Error');
      }

      // Record token usage from response
      final int tokensUsed = data1['usage']?['total_tokens'] ?? estimatedTokens;
      _tokenManager.recordTokenUsage(tokensUsed);

      final message = data1['choices'][0]['message'];
      final List? toolCalls = message['tool_calls'];
      String? initialThought = message['content'];

      // Add Assistant Message to History
      _messages.add(message);
      _manageHistory();

      if (toolCalls == null || toolCalls.isEmpty) {
        onPhaseChange?.call(AgentPhase.complete, "Response Ready");
        // Check for proactive nudge in response
        await checkAndTriggerNudge(initialThought ?? "");
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
        body: jsonEncode({
          'model': _model,
          'messages': _messages,
          'temperature': 0.1,
        }),
      );

      // Check for rate limiting on second call too
      if (response2.statusCode == 429) {
        debugPrint(
          "Groq API Rate Limited (429) on synthesis. Switching to Local Neural Link...",
        );
        throw Exception("RATE_LIMITED");
      }

      final data2 = jsonDecode(response2.body);

      // Record token usage from synthesis response
      final int synthesisTokens = data2['usage']?['total_tokens'] ?? (estimatedTokens ~/ 2);
      _tokenManager.recordTokenUsage(synthesisTokens);

      final finalContent = data2['choices'][0]['message']['content'] ?? "";

      // Check for proactive nudge in response and trigger notification
      await checkAndTriggerNudge(finalContent);

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
      debugPrint("Primary Brain Error: $e");

      // --- SMART SWITCH: Fallback to Ollama (Offline/Secondary) ---
      debugPrint("Groq Exhausted. Switching to Local Neural Link...");
      onPhaseChange?.call(
        AgentPhase.synthesizing,
        "Switching to Local Core...",
      );

      try {
        final fallbackResponse = await _fallbackService.getOfflineResponse(
          userMessage,
        );

        // Save fallback response to history
        _messages.add({'role': 'assistant', 'content': fallbackResponse});
        _saveToDatabase({'role': 'assistant', 'content': fallbackResponse});
        _manageHistory();

        onPhaseChange?.call(AgentPhase.complete, "Local Core Response");
        return BrainResponse(
          content: "[Local Neural Link] $fallbackResponse",
          thought: "Switched to local Ollama due to: $e",
          toolsUsed: ["local_fallback"],
        );
      } catch (fallbackError) {
        debugPrint("Fallback Service Error: $fallbackError");
        return BrainResponse(
          content:
              "Both cloud and local systems are unavailable, Sir. Please check your internet connection or ensure Ollama is running locally.",
        );
      }
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
      if (_messages.length > 1) {
        _messages.removeAt(1); // Keeps index 0 (Instructions)
      } else {
        break;
      }
    }
  }

  static const String systemProtocol = """
    You are FRIDAY. Use ONLY the provided memory context to answer personal questions.
    If the memory context is empty or irrelevant, say: 
    "Sir, I have no record of that in my memory banks. Would you like me to save this now?"
    NEVER make up personal details.
""";

  // --- 1.2 MEMORY AUDITOR SYSTEM PROMPT ---
  static const String _memoryAuditorPrompt = '''### ROLE:
You are the FRIDAY Memory Auditor. Your job is to ensure the Integrity of the Long-Term Memory Vault.

### TASK:
Analyze the NEW_INFORMATION provided by the user and compare it against EXISTING_MEMORIES retrieved from the database.

### CONFLICT DETECTION RULES:
1. IDENTIFY: Does the NEW_INFORMATION directly contradict an EXISTING_MEMORY? (e.g., New: "I moved to New York" vs. Old: "I live in London").
2. CATEGORIZE: 
   - [UPDATE]: The new info is an evolution of the old (New address, new job, new goal).
   - [CORRECTION]: The old info was wrong or has changed (New favorite food, new health constraint).
   - [ADDITION]: The info is entirely new and does not conflict.

### EXECUTION PROTOCOL:
- IF NO CONFLICT: Output "PROCEED: [Original Save Tool Call]".
- IF CONFLICT FOUND: Stop the save and output a CLARIFICATION_REQUEST to the user:
  "Sir, my archives indicate [Old Info]. However, you just mentioned [New Info]. Shall I update your permanent record with this new information?"

### OUTPUT:
Output ONLY the decision (PROCEED or CLARIFICATION_REQUEST). Do not provide internal thoughts.''';

  Future<String> _executeTool(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    if (toolName == 'search_memory') {
      return await _memoryService.retrieveContext(args['query'] ?? '');
    }

    if (toolName == 'save_memory') {
      final newFact = args['fact'] ?? '';

      // 1. Pre-check: Search for related existing memories
      final existingContext = await _memoryService.retrieveContext(newFact);

      // 2. If existing memories trigger a conflict check
      if (existingContext.isNotEmpty &&
          !existingContext.contains("No relevant")) {
        final auditResult = await _resolveMemoryConflict(
          newFact,
          existingContext,
        );

        // 3. If Auditor says STOP, return the clarification request
        if (auditResult.contains("CLARIFICATION_REQUEST")) {
          return auditResult; // Returns the question to the user
        }
      }

      // 4. Default: Proceed with save (PROCEED or no conflict)
      final success = await _memoryService.saveMemory(newFact);
      return success ? "Success: Fact archived." : "Error: Could not save.";
    }

    if (toolName == 'web_search') {
      final res = await _searchService.search(args['query'] ?? '');
      return res.toFormattedString();
    }
    return "Tool not found.";
  }

  Future<String> _resolveMemoryConflict(
    String newFact,
    String existingContext,
  ) async {
    final apiKey = Config.groqApiKey;
    if (apiKey.isEmpty) return "PROCEED"; // Fail safe

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final prompt =
        """
NEW_INFORMATION: "$newFact"
EXISTING_MEMORIES:
$existingContext
""";

    final messages = [
      {'role': 'system', 'content': _memoryAuditorPrompt},
      {'role': 'user', 'content': prompt},
    ];

    try {
      final response = await http.post(
        Uri.parse(_groqEndpoint),
        headers: headers,
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile', // Fast & Smart
          'messages': messages,
          'temperature': 0.1, // Strict logic
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final decision = data['choices'][0]['message']['content'] ?? "PROCEED";
        debugPrint("AUDITOR DECISION: $decision");
        return decision;
      }
    } catch (e) {
      debugPrint("Auditor Error: $e");
    }
    return "PROCEED"; // Default to save if check fails
  }

  BrainResponse _parseResponse(
    String content, {
    List<String> toolsUsed = const [],
    String? internalThought,
  }) {
    final thinkRegex = RegExp(r'<think>(.*?)</think>', dotAll: true);
    final functionRegex = RegExp(r'<function>(.*?)</function>', dotAll: true);

    String thought = internalThought ?? "";

    // Extract thoughts from content
    final thinkMatches = thinkRegex.allMatches(content);
    for (var m in thinkMatches) {
      thought += "\n${m.group(1)}";
    }

    // Clean content
    String cleanContent = content
        .replaceAll(thinkRegex, '')
        .replaceAll(functionRegex, '')
        .trim();

    return BrainResponse(
      content: cleanContent,
      thought: thought.isEmpty ? null : thought.trim(),
      toolsUsed: toolsUsed,
    );
  }

  // ==================== PROACTIVE NUDGE SYSTEM ====================

  /// Initialize notifications if not already done
  Future<void> _ensureNotificationsInitialized() async {
    if (_notificationsInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
    _notificationsInitialized = true;
    debugPrint("FRIDAY Sentinel: Notification system online.");
  }

  /// Trigger a proactive nudge notification
  Future<void> triggerProactiveNudge(Map<String, dynamic> nudgeJson) async {
    await _ensureNotificationsInitialized();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'friday_sentinel',
          'FRIDAY Sentinel',
          channelDescription: 'Proactive alerts from FRIDAY',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      nudgeJson['title'] ?? 'FRIDAY Alert',
      nudgeJson['body'] ?? 'Attention required, Sir.',
      platformDetails,
    );

    debugPrint("FRIDAY Sentinel: Nudge delivered - ${nudgeJson['title']}");
  }

  /// Check if AI response contains a nudge JSON and trigger notification
  Future<void> checkAndTriggerNudge(String response) async {
    try {
      // Try to extract JSON from the response
      final jsonMatch = RegExp(
        r'\{[^{}]*"title"[^{}]*"body"[^{}]*\}',
      ).firstMatch(response);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final Map<String, dynamic> nudgeData = jsonDecode(jsonStr);

        if (nudgeData.containsKey('title') && nudgeData.containsKey('body')) {
          await triggerProactiveNudge(nudgeData);
        }
      }
    } catch (e) {
      debugPrint("Nudge parse attempt (non-critical): $e");
    }
  }

  /// Perform a proactive systems check (for manual testing or background tasks)
  Future<String> checkProactiveStatus() async {
    final now = DateTime.now();
    final timeContext =
        "Current Time: ${now.hour}:${now.minute}, Date: ${now.day}/${now.month}/${now.year}";

    final systemCheckPrompt =
        """
[SENTINEL MODE ACTIVATED]
$timeContext

TASK: Perform a proactive analysis.
1. Search memory for today's schedule, deadlines, or user preferences.
2. Check web for current weather, traffic, or relevant news.
3. Compare context vs environment.
4. If a conflict is detected (e.g., outdoor meeting + rain, deadline approaching, etc.), output ONLY a JSON notification:
{
  "title": "Proactive Alert, Sir",
  "body": "[Your concise warning and recommendation]",
  "priority": "high"
}

5. If NO conflict is found, output: "STATUS: NOMINAL"

Execute analysis now.
""";

    final apiKey = Config.groqApiKey;
    if (apiKey.isEmpty) return "ERROR: Missing API Key";

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    try {
      final tools = _buildToolRegistry();
      final checkMessages = [
        {'role': 'system', 'content': _systemInstructions},
        {'role': 'user', 'content': systemCheckPrompt},
      ];

      final requestBody = {
        'model': _model,
        'messages': checkMessages,
        'tools': tools,
        'tool_choice': 'auto',
      };

      final response1 = await http.post(
        Uri.parse(_groqEndpoint),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      final data1 = jsonDecode(response1.body);
      if (response1.statusCode != 200) {
        throw Exception(data1['error']?['message'] ?? 'API Error');
      }

      final message = data1['choices'][0]['message'];
      final List? toolCalls = message['tool_calls'];
      String? initialResponse = message['content'];

      // If tools were called, execute them
      if (toolCalls != null && toolCalls.isNotEmpty) {
        final tempMessages = List<Map<String, dynamic>>.from(checkMessages);
        tempMessages.add(message);

        for (var toolCall in toolCalls) {
          final String toolName = toolCall['function']['name'];
          final String toolId = toolCall['id'];
          final Map<String, dynamic> toolArgs = jsonDecode(
            toolCall['function']['arguments'] ?? "{}",
          );

          String toolResult = await _executeTool(toolName, toolArgs);

          tempMessages.add({
            'role': 'tool',
            'tool_call_id': toolId,
            'name': toolName,
            'content': toolResult,
          });
        }

        // Get final synthesis
        final response2 = await http.post(
          Uri.parse(_groqEndpoint),
          headers: headers,
          body: jsonEncode({'model': _model, 'messages': tempMessages}),
        );

        final data2 = jsonDecode(response2.body);
        final finalContent = data2['choices'][0]['message']['content'] ?? "";

        // Check and trigger nudge if present
        await checkAndTriggerNudge(finalContent);

        return finalContent;
      }

      // No tools used, return initial response
      await checkAndTriggerNudge(initialResponse ?? "");
      return initialResponse ?? "STATUS: NOMINAL";
    } catch (e) {
      debugPrint("Proactive check error: $e");
      return "ERROR: $e";
    }
  }

  /// Get tomorrow's midnight time for reset notification
  String _getTomorrowMidnight() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeStr = "${tomorrow.hour.toString().padLeft(2, '0')}:"
        "${tomorrow.minute.toString().padLeft(2, '0')}";
    return timeStr;
  }

  /// Get token usage statistics for UI display
  Map<String, dynamic> getUsageStats() {
    return _tokenManager.getUsageStats();
  }

  /// Get current service status
  String getStatusMessage() {
    return _tokenManager.getStatusMessage();
  }

  /// Check if service is available for use
  bool isServiceAvailable() {
    return _tokenManager.isServiceAvailable();
  }
}
