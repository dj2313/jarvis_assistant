enum AgentState {
  received,
  classifying,
  collectingContext,
  retrievingMemory,
  planning,
  waitingForConfirmation,
  executing,
  verifying,
  completed,
  failed,
  cancelled,
}

enum RequestStatus { pending, streaming, done, error }

class AgentRequest {
  final String requestId;
  final String userInput;
  final DateTime timestamp;

  AgentRequest({
    required this.requestId,
    required this.userInput,
    required this.timestamp,
  });
}

class AgentResponse {
  final String requestId;
  final String text;
  final List<ToolResult> toolResults;
  final RequestStatus status;
  final String? thought;

  AgentResponse({
    required this.requestId,
    required this.text,
    required this.toolResults,
    required this.status,
    this.thought,
  });
}

class IntentResult {
  final String intent;
  final double confidence;
  final List<String> suggestedTools;
  final bool requiresWeb;
  final bool requiresMemory;
  final bool requiresTool;
  final bool requiresPlanning;
  final bool requiresConfirmation;

  IntentResult({
    required this.intent,
    required this.confidence,
    required this.suggestedTools,
    required this.requiresWeb,
    required this.requiresMemory,
    required this.requiresTool,
    required this.requiresPlanning,
    required this.requiresConfirmation,
  });

  factory IntentResult.unknown() => IntentResult(
    intent: 'unknown',
    confidence: 0.0,
    suggestedTools: [],
    requiresWeb: false,
    requiresMemory: false,
    requiresTool: false,
    requiresPlanning: false,
    requiresConfirmation: false,
  );
}

class ContextSnapshot {
  final DateTime now;
  final String timezone;
  final int batteryPercent;
  final String networkType;
  final String? location;
  final DateTime? nextCalendarEvent;

  ContextSnapshot({
    required this.now,
    required this.timezone,
    required this.batteryPercent,
    required this.networkType,
    this.location,
    this.nextCalendarEvent,
  });

  factory ContextSnapshot.placeholder() => ContextSnapshot(
    now: DateTime.now(),
    timezone: DateTime.now().timeZoneName,
    batteryPercent: 0,
    networkType: 'unknown',
  );
}

class ToolResult {
  final String toolName;
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final String? errorCode;
  final DateTime startedAt;
  final DateTime completedAt;

  ToolResult({
    required this.toolName,
    required this.success,
    required this.message,
    this.data,
    this.errorCode,
    required this.startedAt,
    required this.completedAt,
  });

  factory ToolResult.success({
    required String toolName,
    required String message,
    Map<String, dynamic>? data,
  }) => ToolResult(
    toolName: toolName,
    success: true,
    message: message,
    data: data,
    startedAt: DateTime.now(),
    completedAt: DateTime.now(),
  );

  factory ToolResult.failure({
    required String toolName,
    required String message,
    String? errorCode,
  }) => ToolResult(
    toolName: toolName,
    success: false,
    message: message,
    errorCode: errorCode,
    startedAt: DateTime.now(),
    completedAt: DateTime.now(),
  );
}
