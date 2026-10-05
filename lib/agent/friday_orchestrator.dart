import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'agent_models.dart';
import 'intent_router.dart';
import 'context_engine.dart';
import 'result_verifier.dart';
import '../services/friday_brain_service.dart';
import '../services/memory_service.dart';
import '../services/token_manager.dart';
import '../tools/tool_bootstrap.dart';
import '../security/policy_engine.dart';
import '../security/permission_guard.dart';

class FridayOrchestrator extends ChangeNotifier {
  final FridayBrainService _brainService;
  final IntentRouter _intentRouter;
  final ContextEngine _contextEngine;
  final ResultVerifier _resultVerifier;
  final MemoryService _memoryService;
  final TokenManager _tokenManager;
  final PolicyEngine _policyEngine;
  final PermissionGuard _permissionGuard;

  final StreamController<AgentState> _stateController =
      StreamController<AgentState>.broadcast();
  final StreamController<AgentResponse> _responseController =
      StreamController<AgentResponse>.broadcast();
  final StreamController<PendingConfirmation> _confirmationController =
      StreamController<PendingConfirmation>.broadcast();

  AgentState _currentState = AgentState.received;

  FridayOrchestrator({
    FridayBrainService? brainService,
    IntentRouter? intentRouter,
    ContextEngine? contextEngine,
    ResultVerifier? resultVerifier,
    MemoryService? memoryService,
    TokenManager? tokenManager,
    PolicyEngine? policyEngine,
    PermissionGuard? permissionGuard,
  }) : _brainService = brainService ?? FridayBrainService(),
       _intentRouter = intentRouter ?? IntentRouter(),
       _contextEngine = contextEngine ?? ContextEngine(),
       _resultVerifier = resultVerifier ?? ResultVerifier(),
       _memoryService = memoryService ?? MemoryService(),
       _tokenManager = tokenManager ?? TokenManager(),
       _policyEngine = policyEngine ?? PolicyEngine(),
       _permissionGuard = permissionGuard ?? PermissionGuard() {
    _tokenManager.initialize();
    _initializeTools();
  }

  Stream<AgentState> get stateStream => _stateController.stream;
  Stream<AgentResponse> get responseStream => _responseController.stream;
  Stream<PendingConfirmation> get confirmationStream =>
      _confirmationController.stream;
  AgentState get currentState => _currentState;

  FridayBrainService get brainService => _brainService;
  PolicyEngine get policyEngine => _policyEngine;
  PermissionGuard get permissionGuard => _permissionGuard;

  void _initializeTools() {
    debugPrint('FridayOrchestrator: Initializing tools...');

    for (final tool in buildDefaultTools()) {
      if (!_brainService.toolRegistry.has(tool.name)) {
        _brainService.toolRegistry.register(tool);
      }
    }

    _brainService.approvalGate = (tool, args) {
      return requestToolConfirmation(toolName: tool.name, args: args);
    };

    debugPrint(
      'FridayOrchestrator: Tools ready (${_brainService.toolRegistry.count}), approval gate wired.',
    );
  }

  Future<AgentResponse> processRequest(String userInput) async {
    final requestId = const Uuid().v4();

    await _initializeTokenManager();

    if (!_tokenManager.canMakeChatRequest()) {
      return _failRequest(
        requestId,
        'Daily chat limit reached. Resets at midnight.',
      );
    }

    final estimatedTokens = _tokenManager.estimateTokenCount(userInput);
    if (!_tokenManager.canMakeTokenRequest(estimatedTokens)) {
      return _failRequest(
        requestId,
        'Daily token limit reached. Resets at midnight.',
      );
    }

    try {
      _transition(AgentState.classifying);
      final IntentResult intent = await _intentRouter.route(userInput);

      _transition(AgentState.collectingContext);
      final context = await _contextEngine.getSnapshot(
        includeLocation: _needsLocation(userInput, intent),
      );

      _transition(AgentState.retrievingMemory);
      String memoryContext = '';
      if (intent.requiresMemory) {
        memoryContext = await _memoryService.retrieveContext(userInput);
      }

      _transition(AgentState.planning);
      final enrichedInput = _buildEnrichedInput(
        userInput,
        context,
        memoryContext,
        intent,
      );

      _transition(AgentState.executing);
      final brainResponse = await _brainService.chatWithIntelligence(
        enrichedInput,
        requiredToolName: _requiredToolFor(intent),
        onPhaseChange: _mapBrainPhaseToOrchestratorState,
      );

      _transition(AgentState.verifying);
      final toolResults = _extractToolResults(brainResponse);
      final verificationResults = _resultVerifier.verifyBatch(toolResults);
      final allValid = verificationResults.every((r) => r.isValid);

      if (!allValid) {
        debugPrint(
          'Verification failed: ${verificationResults.where((r) => !r.isValid).join(", ")}',
        );
      }

      _transition(AgentState.completed);
      final response = AgentResponse(
        requestId: requestId,
        text: brainResponse.content,
        toolResults: toolResults,
        status: RequestStatus.done,
        thought: brainResponse.thought,
      );

      _responseController.add(response);
      return response;
    } catch (e) {
      _transition(AgentState.failed);
      return _failRequest(requestId, 'Processing error: $e');
    }
  }

  bool _needsLocation(String userInput, IntentResult intent) {
    if (intent.intent == 'gps_navigation' ||
        intent.intent == 'weather_query' ||
        intent.intent == 'location_query') {
      return true;
    }
    final input = userInput.toLowerCase();
    return input.contains('near me') ||
        input.contains('nearby') ||
        input.contains('around me') ||
        input.contains('my location');
  }

  String? _requiredToolFor(IntentResult intent) {
    // Force `get_weather` directly for weather queries — the WeatherTool
    // accepts optional lat/lng and falls back gracefully if none are provided.
    // Forcing `get_location` first caused the model to stop before calling
    // `get_weather`, resulting in a location-only response with no weather data.
    if (intent.intent == 'weather_query') return 'get_weather';
    if (intent.intent == 'time_query' || intent.intent == 'date_query') {
      return 'current_time';
    }
    if (intent.requiresWeb) return 'web_search';
    if (intent.intent == 'gps_navigation') return 'navigate';
    if (intent.intent == 'location_query') return 'get_location';
    return null;
  }

  Future<void> _initializeTokenManager() async {
    await _tokenManager.initialize();
    _tokenManager.loadSavedState();
  }

  AgentResponse _failRequest(String requestId, String message) {
    final response = AgentResponse(
      requestId: requestId,
      text: message,
      toolResults: [],
      status: RequestStatus.error,
    );
    _responseController.add(response);
    return response;
  }

  void _transition(AgentState newState) {
    _currentState = newState;
    _stateController.add(newState);
    notifyListeners();
  }

  void _mapBrainPhaseToOrchestratorState(AgentPhase phase, String? message) {
    switch (phase) {
      case AgentPhase.thinking:
        _transition(AgentState.planning);
        break;
      case AgentPhase.searchingWeb:
      case AgentPhase.searchingMemory:
      case AgentPhase.savingMemory:
        _transition(AgentState.executing);
        break;
      case AgentPhase.synthesizing:
        _transition(AgentState.verifying);
        break;
      case AgentPhase.complete:
        _transition(AgentState.completed);
        break;
    }
  }

  String _buildEnrichedInput(
    String userInput,
    ContextSnapshot context,
    String memoryContext,
    IntentResult intent,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('[Context]');
    buffer.writeln(
      'Time: ${context.now.hour}:${context.now.minute.toString().padLeft(2, '0')}',
    );
    buffer.writeln(
      'Date: ${context.now.day}/${context.now.month}/${context.now.year}',
    );
    buffer.writeln('Timezone: ${context.timezone}');
    buffer.writeln('Battery: ${context.batteryPercent}%');
    buffer.writeln('Network: ${context.networkType}');
    if (context.location != null)
      buffer.writeln('Location: ${context.location}');
    if (context.nextCalendarEvent != null) {
      buffer.writeln('Next Event: ${context.nextCalendarEvent}');
    }
    buffer.writeln();

    if (memoryContext.isNotEmpty) {
      buffer.writeln('[Memory Context]');
      buffer.writeln(memoryContext);
      buffer.writeln();
    }

    buffer.writeln('[Intent Analysis]');
    buffer.writeln('Detected Intent: ${intent.intent}');
    buffer.writeln('Confidence: ${(intent.confidence * 100).toInt()}%');
    buffer.writeln('Suggested Tools: ${intent.suggestedTools.join(", ")}');
    buffer.writeln();

    buffer.writeln(
      '[Token Budget: ${_tokenManager.getRemainingTokens()} tokens remaining]',
    );
    buffer.writeln();
    buffer.writeln('User Message: $userInput');

    return buffer.toString();
  }

  List<ToolResult> _extractToolResults(BrainResponse brainResponse) {
    if (brainResponse.toolResults.isNotEmpty) {
      return brainResponse.toolResults;
    }

    return brainResponse.toolsUsed.map((toolName) {
      return ToolResult.success(
        toolName: toolName,
        message: 'Tool executed successfully',
      );
    }).toList();
  }

  Future<bool> requestToolConfirmation({
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    final tool = _brainService.toolRegistry.get(toolName);
    if (tool == null) return true;

    final decision = _policyEngine.evaluate(tool);

    if (decision.autoExecute) {
      debugPrint(
        'Tool $toolName auto-approved (risk: ${decision.riskLevel.label})',
      );
      return true;
    }

    _transition(AgentState.waitingForConfirmation);

    final token = _permissionGuard.createConfirmation(
      toolName: toolName,
      args: args,
      decision: decision,
    );

    final confirmation = _permissionGuard.get(token)!;
    _confirmationController.add(confirmation);

    final approved = await _permissionGuard.waitForConfirmation(token);

    if (approved) {
      _transition(AgentState.executing);
    } else {
      _transition(AgentState.failed);
    }

    return approved;
  }

  void approveConfirmation(String token) {
    _permissionGuard.approve(token);
  }

  void cancelConfirmation(String token) {
    _permissionGuard.cancel(token);
  }

  @override
  void dispose() {
    _stateController.close();
    _responseController.close();
    _confirmationController.close();
    _permissionGuard.clear();
    super.dispose();
  }
}
