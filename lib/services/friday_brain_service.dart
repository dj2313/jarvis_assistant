import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/config.dart';
import '../tools/tool_registry.dart';
import '../tools/tool_executor.dart';
import '../tools/friday_tool.dart';
import '../tools/tool_bootstrap.dart';
import '../agent/agent_models.dart';
import 'memory_service.dart';
import 'search_service.dart';
import 'response_sanitizer.dart';
// Fallback to Ollama removed — using Groq for all responses
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
  final List<ToolResult> toolResults;

  BrainResponse({
    required this.content,
    this.thought,
    this.toolsUsed = const [],
    this.toolResults = const [],
  });
}

class FridayBrainService {
  final MemoryService _memoryService = MemoryService();
  final SearchService _searchService = SearchService();
  // FallbackBrainService removed — all responses via Groq
  final SupabaseClient _supabase = Supabase.instance.client;
  final TokenManager _tokenManager = TokenManager();
  final ToolRegistry _toolRegistry = ToolRegistry();
  final ToolExecutor _toolExecutor = ToolExecutor();

  // Notification Plugin for Proactive Nudges
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

  FridayBrainService() {
    _initializeToolRegistry();
  }

  void _initializeToolRegistry() {
    for (final tool in buildDefaultTools()) {
      _toolRegistry.register(tool);
    }
    debugPrint(
      'FridayBrainService: Tool registry initialized with ${_toolRegistry.count} tools',
    );
  }

  /// Register a tool with the registry
  void registerTool(FridayTool tool) {
    _toolRegistry.register(tool);
  }

  /// Register multiple tools at once
  void registerTools(List<FridayTool> tools) {
    for (final tool in tools) {
      _toolRegistry.register(tool);
    }
  }

  ToolRegistry get toolRegistry => _toolRegistry;
  ToolExecutor get toolExecutor => _toolExecutor;

  /// Optional gate invoked before a tool with riskLevel >= 2 (sensitive/critical)
  /// is executed. Returns true to proceed, false to abort the tool call.
  /// The FridayOrchestrator injects this to route through PolicyEngine +
  /// PermissionGuard + the UI confirmation stream.
  Future<bool> Function(FridayTool tool, Map<String, dynamic> args)?
  approvalGate;

  static const String _groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = Config.groqModelFast;

  // Rate-limit retry config
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 2);

  // Throttle config: minimum spacing between Groq API calls so we never burst
  // past the per-minute request cap (1K RPM for these models).
  static const Duration _minRequestInterval = Duration(milliseconds: 350);
  static const int _maxConcurrentChatRequests = 1;
  DateTime _lastGroqRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _activeChatRequests = 0;
  final List<Completer<void>> _chatWaiters = [];

  /// Serializes chat requests so only one runs at a time, and spaces each
  /// Groq call by [_minRequestInterval]. Returns a release + throttle-wait
  /// function to be run before performing an actual Groq request.
  Future<void> _acquireChatSlot() async {
    // Serialize: wait until no other chat request is actively running.
    while (_activeChatRequests >= _maxConcurrentChatRequests) {
      final completer = Completer<void>();
      _chatWaiters.add(completer);
      await completer.future;
    }
    _activeChatRequests++;
  }

  void _releaseChatSlot() {
    _activeChatRequests--;
    if (_chatWaiters.isNotEmpty) {
      _chatWaiters.removeAt(0).complete();
    }
  }

  /// Enforces the minimum gap between consecutive Groq API calls.
  Future<void> _throttle() async {
    final elapsed =
        DateTime.now().difference(_lastGroqRequestTime).inMilliseconds;
    final remaining = _minRequestInterval.inMilliseconds - elapsed;
    if (remaining > 0) {
      await Future.delayed(Duration(milliseconds: remaining));
    }
    _lastGroqRequestTime = DateTime.now();
  }

  /// Calls the Groq API with automatic retry + exponential backoff on 429,
  /// and enforces the request-throttle gap.
  Future<http.Response> _callGroqWithRetry(
    Map<String, dynamic> requestBody,
    Map<String, String> headers,
  ) async {
    http.Response? lastResponse;
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      if (attempt > 0) {
        final delayMs = _baseRetryDelay.inMilliseconds * (1 << (attempt - 1));
        debugPrint("Groq retry $attempt/$_maxRetries after ${delayMs}ms...");
        await Future.delayed(Duration(milliseconds: delayMs));
      }

      await _throttle();

      final response = await http
          .post(
            Uri.parse(_groqEndpoint),
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 429) {
        debugPrint("Groq 429 on attempt $attempt");
        lastResponse = response;
        continue; // retry
      }

      return response; // success or non-429 error
    }
    // All retries exhausted
    return lastResponse!;
  }

  /// Expose the daily-limit reset for the UI's "Reset Daily Limits" button.
  /// Returns the freshly-read usage stats so callers can display proof.
  Map<String, dynamic> resetDailyLimits() {
    _tokenManager.resetLimits();
    debugPrint("FridayBrainService: Daily limits manually reset.");
    return _tokenManager.getUsageStats();
  }

  // --- 1. SYSTEM PROMPT (dynamically generated with current time) ---
  static String _getSystemInstructions() {
    final now = DateTime.now();
    final timeStr =
        '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr = '${now.day}/${now.month}/${now.year}';
    return '''### SYSTEM ROLE:
You are J.A.R.V.I.S. (Just A Rather Very Intelligent System) — Tony Stark's AI butler and operational interface.
You are calm, precise, and unfailingly loyal. You address the user as "Sir" or "Ma'am".
You do not merely answer questions; you anticipate needs, report status concisely, and execute tasks with quiet competence.

### JARVIS SPEECH PATTERNS (always follow):
- Open task responses with brief acknowledgements: "Certainly, Sir.", "Right away.", "At your service.", "Understood."
- Report completion: "Done, Sir.", "Task complete.", "I've taken care of it, Sir."
- Status updates: short, factual, no filler. Example: "All systems nominal, Sir."
- Dry wit is permitted sparingly — never at the user's expense.
- Never use casual slang, emojis, or exclamation marks.
- Keep responses concise unless detail is explicitly requested.

### MEMORY PROTOCOL:
- If the user shares personal information (preferences, names, facts), MUST call 'save_memory'.
- If the user asks about themselves or the past, MUST call 'search_memory' FIRST.
- If memory is relevant, say: "According to my records, Sir..." or "Based on our previous conversations, Sir..."
- If information is missing or real-time, use 'web_search'.

### DATA INPUTS:
1. TIME: $timeStr on $dateStr
2. MEMORY: Use 'search_memory' for schedule, deadlines, or constraints.
3. ENVIRONMENT: Use 'web_search' for weather, traffic, or news relevant to the user's location.

### OUTPUT PROTOCOL:
- If NO tool is active, speak naturally in JARVIS voice.
- If a tool was used, synthesize the result concisely.
- For device info queries, report as if monitoring local thermal and battery subsystems.

### TONE:
British formality. Measured. Intelligent. Loyal. Efficient. Always "Sir" or "Ma'am".

### CRITICAL INSTRUCTION:
- YOU MUST ANSWER DIRECTLY if the information is available in the [Context] (Time, Date, etc.).
- NEVER write out tool calls manually using "<function>" tags.
- ALWAYS use the specific Tool Calling interface provided by the API.
- If you use a tool, do NOT include conversational filler until the tool result is synthesized.''';
  }

  // 2. The History Manager
  final List<Map<String, dynamic>> _messages = [
    {'role': 'system', 'content': _getSystemInstructions()},
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
      _messages.add({'role': 'system', 'content': _getSystemInstructions()});

      if (dbMessages.isNotEmpty) {
        for (var msg in dbMessages) {
          if (msg['content'] is String) {
            msg['content'] = ResponseSanitizer.clean(msg['content']);
          }
        }
        _messages.addAll(
          dbMessages.where(
            (message) => message['content'].toString().trim().isNotEmpty,
          ),
        );
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
      _messages.add({'role': 'system', 'content': _getSystemInstructions()});
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

  // Select the appropriate model tier for a request.
  // Fast model (openai/gpt-oss-120b): normal conversation and tool selection.
  // Smart model (qwen/qwen3.6-27b): complex reasoning / planning requests.
  String _selectModel(String userMessage, String? requiredToolName) {
    final lower = userMessage.toLowerCase();
    final complexPatterns = [
      'explain',
      'why',
      'how does',
      'how do',
      'compare',
      'difference',
      'analy',
      'reason',
      'plan',
      'strategy',
      'roadmap',
      'tutorial',
      'step by step',
      'in detail',
      'summarize',
      'what if',
      'pros and cons',
      'recommend',
    ];
    final requiresPlanning =
        requiredToolName == null && _isComplexRequest(lower, complexPatterns);
    return requiresPlanning ? Config.groqModelSmart : _model;
  }

  bool _isComplexRequest(String lower, List<String> patterns) {
    return patterns.any(lower.contains);
  }

  // --- Main Processor ---

  Future<BrainResponse> chatWithIntelligence(
    String userMessage, {
    AgentPhaseCallback? onPhaseChange,
    String? requiredToolName,
  }) async {
    // Serialize chat requests so only one is actively processing at a time.
    await _acquireChatSlot();
    try {
      return await _chatWithIntelligenceInner(
        userMessage,
        onPhaseChange: onPhaseChange,
        requiredToolName: requiredToolName,
      );
    } finally {
      _releaseChatSlot();
    }
  }

  Future<BrainResponse> _chatWithIntelligenceInner(
    String userMessage, {
    AgentPhaseCallback? onPhaseChange,
    String? requiredToolName,
  }) async {
    // Initialize token manager
    await _tokenManager.initialize();
    _tokenManager.loadSavedState();

    // Check daily limits BEFORE processing
    if (!_tokenManager.canMakeChatRequest()) {
      final resetTime = _getTomorrowMidnight();
      return BrainResponse(
        content:
            "Daily chat limit of ${TokenManager.DAILY_CHAT_LIMIT} reached, Sir. "
            "The neural link will reset at $resetTime.",
        toolsUsed: [],
      );
    }

    // Estimate and check token usage
    final estimatedTokens = _tokenManager.estimateTokenCount(userMessage);
    if (!_tokenManager.canMakeTokenRequest(estimatedTokens)) {
      final resetTime = _getTomorrowMidnight();
      return BrainResponse(
        content:
            "Daily token limit reached, Sir. The neural link will reset at $resetTime.",
        toolsUsed: [],
      );
    }

    // The orchestrator already builds a rich enriched input. Pass it through
    // directly without redundant re-wrapping.
    final contextualMessage = userMessage;

    final List<String> toolsUsed = [];
    String apiKey = "";
    try {
      apiKey = Config.groqApiKey;
    } catch (e) {
      return BrainResponse(content: "My neural link is offline, Sir. Please configure the GROQ_API_KEY in the .env file.");
    }
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
      final String activeModel =
          _selectModel(userMessage, requiredToolName);
      final List<ToolResult> executedResults = [];
      String? initialThought;
      String finalContent = "";

      // PHASE 1 + 2 + 3: ITERATIVE TOOL-CALLING LOOP.
      // Continue requesting the model until it stops emitting tool_calls and
      // produces a final assistant answer. This handles multi-step tool use
      // (e.g. search_memory -> web_search -> synthesis) robustly.
      const int maxIterations = 6;
      var round = 0;
      var shouldRequest = true;
      while (shouldRequest && round < maxIterations) {
        round++;

        final Map<String, dynamic> requestBody = {
          'model': activeModel,
          'messages': _messages,
          'temperature': 0.1,
          'max_tokens': Config.groqMaxTokens,
        };

        // Qwen reasoning model returns thinking in "content" by default.
        // Request hidden reasoning so only the final answer (or tool_calls)
        // is returned, keeping responses clean.
        if (activeModel == Config.groqModelSmart) {
          requestBody['reasoning_format'] = 'hidden';
        }

        // Only attach tools if the registry has them
        if (tools.isNotEmpty) {
          requestBody['tools'] = tools;
          // Only use tool_choice on first round with a forced tool
          if (requiredToolName != null && round == 1) {
            requestBody['tool_choice'] = {
              'type': 'function',
              'function': {'name': requiredToolName},
            };
          } else {
            requestBody['tool_choice'] = 'auto';
          }
        }

        final response = await _callGroqWithRetry(requestBody, headers);

        // Check for rate limiting (429) or other API errors
        if (response.statusCode == 429) {
          debugPrint(
            "Groq API Rate Limited (429). Switching to Local Neural Link...",
          );
          throw Exception("RATE_LIMITED");
        }

        final dynamic data = jsonDecode(response.body);
        if (response.statusCode != 200) {
          throw Exception(data['error']?['message'] ?? 'API Error');
        }

        // Record token usage from response
        final int tokensUsed =
            data['usage']?['total_tokens'] ?? estimatedTokens;
        _tokenManager.recordTokenUsage(tokensUsed);
        // One chat per user message (not per tool round).
        if (round == 1) _tokenManager.recordChat();

        final message = data['choices'][0]['message'];
        final List? toolCalls = message['tool_calls'];

        initialThought ??= message['content'] ?? "";

        // Add Assistant Message to History (preserves tool_calls linkage)
        _messages.add(message);
        _manageHistory();

        // No tool calls -> this is the final answer.
        if (toolCalls == null || toolCalls.isEmpty) {
          finalContent = (message['content'] ?? "").toString();
          shouldRequest = false;
          break;
        }

        onPhaseChange?.call(AgentPhase.thinking, "Executing Tools...");

        // Execute every requested tool call for this round.
        for (var toolCall in toolCalls) {
          final String toolName = toolCall['function']['name'];
          final String toolId = toolCall['id'];
          Map<String, dynamic> toolArgs = {};
          try {
            toolArgs = jsonDecode(
              toolCall['function']['arguments'] ?? "{}",
            ) as Map<String, dynamic>;
          } catch (e) {
            debugPrint(
              "Tool $toolName returned malformed arguments; using empty args.",
            );
            toolArgs = {};
          }

          _emitToolPhase(toolName, toolArgs, onPhaseChange);
          toolsUsed.add(toolName);

          final tool = _toolRegistry.get(toolName);
          if (tool != null && tool.riskLevel >= 2 && approvalGate != null) {
            final approved = await approvalGate!(tool, toolArgs);
            if (!approved) {
              final denied = ToolResult.failure(
                toolName: toolName,
                message: 'Action blocked by user.',
                errorCode: 'USER_DENIED',
              );
              executedResults.add(denied);
              _messages.add({
                'role': 'tool',
                'tool_call_id': toolId,
                'name': toolName,
                'content': denied.message,
              });
              continue;
            }
          }

          final ToolResult toolResult = await _executeTool(toolName, toolArgs);
          executedResults.add(toolResult);

          _messages.add({
            'role': 'tool',
            'tool_call_id': toolId,
            'name': toolName,
            'content': toolResult.message,
          });
        }

        _manageHistory();

        // Continue the loop so the model synthesizes the tool output (and may
        // issue further tool calls).
        shouldRequest = true;
      }

      if (finalContent.isEmpty) {
        onPhaseChange?.call(AgentPhase.synthesizing, "Finalizing Response...");
        finalContent = await _getGroqDirectResponse(userMessage);
        finalContent = ResponseSanitizer.clean(finalContent);
      }

      final cleaned = ResponseSanitizer.clean(finalContent);
      final safeContent = cleaned.isEmpty
          ? "I couldn't produce a complete response. Please try that request again."
          : cleaned;

      // Check for proactive nudge in response and trigger notification.
      // Reassign the content in case a nudge JSON blob was stripped.
      final nudgeCleaned = await checkAndTriggerNudge(safeContent);
      final displayedContent = nudgeCleaned.isEmpty ? safeContent : nudgeCleaned;

      _messages.add({'role': 'assistant', 'content': displayedContent});
      _saveToDatabase({'role': 'assistant', 'content': displayedContent});
      _manageHistory();

      onPhaseChange?.call(AgentPhase.complete, "Done");
      return _parseResponse(
        displayedContent,
        toolsUsed: toolsUsed,
        internalThought: initialThought,
        toolResults: executedResults,
      );
    } catch (e) {
      debugPrint("Primary Brain Error: $e");

      // --- RATE LIMIT (429): surface a clear, distinct message ---
      if (e is Exception && e.toString().contains("RATE_LIMITED")) {
        return BrainResponse(
          content:
              "I'm being rate-limited at the moment, Sir — too many requests "
              "in a short window. Please wait a few seconds and try again.",
          toolsUsed: [],
        );
      }

      // --- FALLBACK: Retry with Groq without tools for general queries ---
      debugPrint("Groq error. Attempting direct response without tools...");
      onPhaseChange?.call(AgentPhase.synthesizing, "Processing...");

      try {
        final fallbackResponse = ResponseSanitizer.clean(
          await _getGroqDirectResponse(userMessage),
        );

        // Save response to history
        _messages.add({'role': 'assistant', 'content': fallbackResponse});
        _saveToDatabase({'role': 'assistant', 'content': fallbackResponse});
        _manageHistory();

        onPhaseChange?.call(AgentPhase.complete, "Done");
        return BrainResponse(
          content: fallbackResponse,
          thought: null,
          toolsUsed: [],
        );
      } catch (fallbackError) {
        debugPrint("Fallback also failed: $fallbackError");

        // --- BACKUP LLM: Gemini free-tier Flash (if configured) ---
        final geminiResponse =
            await _getGeminiResponse(userMessage);
        if (geminiResponse != null && geminiResponse.isNotEmpty) {
          final cleanedGemini = ResponseSanitizer.clean(geminiResponse);
          _messages.add(
            {'role': 'assistant', 'content': cleanedGemini},
          );
          _saveToDatabase(
            {'role': 'assistant', 'content': cleanedGemini},
          );
          _manageHistory();
          onPhaseChange?.call(AgentPhase.complete, "Done");
          return BrainResponse(
            content: cleanedGemini,
            thought: null,
            toolsUsed: [],
          );
        }

        return BrainResponse(
          content:
              "I'm experiencing some technical difficulties, Sir. Please try again in a moment.",
        );
      }
    }
  }

  /// Direct Groq response without tools — used as fallback when tool-calling fails
  Future<String> _getGroqDirectResponse(String userMessage) async {
    String apiKey = "";
    try {
      apiKey = Config.groqApiKey;
    } catch (e) {
      throw Exception("Missing GROQ_API_KEY");
    }
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final now = DateTime.now();
    final timeContext =
        "Current Time: ${now.hour}:${now.minute}, Date: ${now.day}/${now.month}/${now.year}";

    final messages = [
      {'role': 'system', 'content': _getSystemInstructions()},
      {
        'role': 'user',
        'content': "[Context: $timeContext]\nUser Message: $userMessage",
      },
    ];

    final response = await _callGroqWithRetry({
      'model': _model,
      'messages': messages,
      'temperature': 0.3,
      'max_tokens': 1024,
    }, headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] ?? "";
    }

    throw Exception("Groq direct response failed: ${response.statusCode}");
  }

  /// Gemini free-tier Flash fallback.
  /// Returns null if Gemini is not configured or the call fails, so callers
  /// can fall through to the next backup tier.
  Future<String?> _getGeminiResponse(String userMessage) async {
    final apiKey = Config.geminiApiKey;
    if (apiKey.isEmpty) return null;

    final now = DateTime.now();
    final timeContext =
        "Current Time: ${now.hour}:${now.minute}, Date: ${now.day}/${now.month}/${now.year}";

    try {
      final contents = [
        {
          'role': 'user',
          'parts': [
            {
              'text':
                  "[Context: $timeContext]\nUser Message: $userMessage\n\n"
                      "You are J.A.R.V.I.S., Tony Stark's AI assistant. Answer "
                      "calmly and loyally, addressing the user as 'Sir' or "
                      "'Ma'am'. Be concise."
            }
          ]
        }
      ];

      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/'
          'gemini-2.0-flash:generateContent?key=$apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contents': contents}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]?['content']?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]?['text'];
            if (text is String && text.trim().isNotEmpty) {
              return text.trim();
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Gemini fallback error: $e");
    }
    return null;
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
    // If registry has tools, use them; otherwise fall back to legacy hardcoded tools
    if (_toolRegistry.count > 0) {
      return _toolRegistry.toGroqToolList();
    }
    // Legacy fallback - should not be used after full migration
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
    // _messages[0] is always the system prompt. Keep the system prompt plus
    // the most recent _maxHistoryLength messages. Walk forward to the next
    // user message to avoid orphaning tool calls.
    if (_messages.length <= _maxHistoryLength) return;

    int trimStart = _messages.length - _maxHistoryLength;

    // Walk forward to the next user message to avoid orphaning tool calls
    while (trimStart < _messages.length &&
        _messages[trimStart]['role'] != 'user') {
      trimStart++;
    }

    if (trimStart > 1 && trimStart < _messages.length) {
      _messages.removeRange(1, trimStart);
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

  Future<ToolResult> _executeTool(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    // First check if tool exists in registry
    final tool = _toolRegistry.get(toolName);
    if (tool != null) {
      final context = ToolContext(
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      return await _toolExecutor.execute(tool, args, context);
    }

    // Fallback to legacy execution for tools not yet in registry
    if (toolName == 'search_memory') {
      return ToolResult.success(
        toolName: toolName,
        message: await _memoryService.retrieveContext(args['query'] ?? ''),
      );
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
          return ToolResult.failure(
            toolName: toolName,
            message: auditResult, // Returns the question to the user
            errorCode: 'CLARIFICATION_REQUEST',
          );
        }
      }

      // 4. Default: Proceed with save (PROCEED or no conflict)
      final success = await _memoryService.saveMemory(newFact);
      return success
          ? ToolResult.success(
              toolName: toolName,
              message: "Success: Fact archived.",
            )
          : ToolResult.failure(
              toolName: toolName,
              message: "Error: Could not save.",
            );
    }

    if (toolName == 'web_search') {
      final res = await _searchService.search(args['query'] ?? '');
      return ToolResult.success(
        toolName: toolName,
        message: res.toFormattedString(),
      );
    }
    return ToolResult.failure(
      toolName: toolName,
      message: "Tool not found.",
      errorCode: 'TOOL_NOT_FOUND',
    );
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
      final response = await _callGroqWithRetry({
        'model': Config.groqModelFast,
        'messages': messages,
        'temperature': 0.1,
      }, headers);

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
    List<ToolResult> toolResults = const [],
  }) {
    final embeddedThought = ResponseSanitizer.extractThought(content);
    final thought = [internalThought, embeddedThought]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join('\n')
        .trim();

    return BrainResponse(
      content: ResponseSanitizer.clean(content),
      thought: thought.isEmpty ? null : thought.trim(),
      toolsUsed: toolsUsed,
      toolResults: toolResults,
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

  /// Check if AI response contains a nudge JSON and trigger notification.
  /// Returns the response with any extracted nudge JSON removed, so caller can
  /// speak/display clean text instead of raw JSON.
  Future<String> checkAndTriggerNudge(String response) async {
    try {
      final jsonMatch = RegExp(
        r'\{[^{}]*"title"[^{}]*"body"[^{}]*\}',
      ).firstMatch(response);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final Map<String, dynamic> nudgeData = jsonDecode(jsonStr);

        if (nudgeData.containsKey('title') && nudgeData.containsKey('body')) {
          await triggerProactiveNudge(nudgeData);
        }
        // Strip the JSON blob so it is never spoken or rendered verbatim.
        return response.replaceFirst(jsonStr, '').trim();
      }
    } catch (e) {
      debugPrint("Nudge parse attempt (non-critical): $e");
    }
    return response;
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

    String apiKey = "";
    try {
      apiKey = Config.groqApiKey;
    } catch (e) {
      return "ERROR: Missing API Key in .env";
    }
    if (apiKey.isEmpty) return "ERROR: Missing API Key";

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    try {
      final tools = _buildToolRegistry();
      final checkMessages = [
        {'role': 'system', 'content': _getSystemInstructions()},
        {'role': 'user', 'content': systemCheckPrompt},
      ];

      final requestBody = {
        'model': _model,
        'messages': checkMessages,
      };

      if (tools.isNotEmpty) {
        requestBody['tools'] = tools;
        requestBody['tool_choice'] = 'auto';
      }

      final response1 = await _callGroqWithRetry(requestBody, headers);

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

          final ToolResult toolResult = await _executeTool(toolName, toolArgs);

          tempMessages.add({
            'role': 'tool',
            'tool_call_id': toolId,
            'name': toolName,
            'content': toolResult.message,
          });
        }

        // Get final synthesis
        final response2 = await _callGroqWithRetry({
          'model': _model,
          'messages': tempMessages,
        }, headers);

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
    final timeStr =
        "${tomorrow.hour.toString().padLeft(2, '0')}:"
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
