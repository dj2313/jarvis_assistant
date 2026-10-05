import 'friday_tool.dart';
import '../agent/agent_models.dart';
import '../services/memory_service.dart';

class MemorySaveTool extends FridayTool {
  final MemoryService _memoryService;

  MemorySaveTool({MemoryService? memoryService})
    : _memoryService = memoryService ?? MemoryService();

  @override
  String get name => 'save_memory';

  @override
  String get description =>
      'Save a new personal fact, preference, or information to the user\'s permanent memory vault. Use this when the user tells you something about themselves, their preferences, or any fact they want you to remember.';

  @override
  int get riskLevel => 1;

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'fact': {
        'type': 'string',
        'description': 'The fact or information to save to memory',
      },
    },
    'required': ['fact'],
  };

  @override
  List<Map<String, dynamic>> get groqToolDefinition => [
    {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': inputSchema,
      },
    },
  ];

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> args,
    ToolContext context,
  ) async {
    final fact = args['fact'] as String?;

    if (fact == null || fact.trim().isEmpty) {
      return ToolResult.failure(
        toolName: name,
        message: 'Fact to save is required',
        errorCode: 'MISSING_FACT',
      );
    }

    try {
      final success = await _memoryService.saveMemory(fact);
      if (success) {
        return ToolResult.success(
          toolName: name,
          message: 'Memory saved successfully',
          data: {'fact': fact},
        );
      } else {
        return ToolResult.failure(
          toolName: name,
          message: 'Failed to save memory',
          errorCode: 'SAVE_FAILED',
        );
      }
    } catch (e) {
      return ToolResult.failure(
        toolName: name,
        message: 'Memory save failed: $e',
        errorCode: 'SAVE_ERROR',
      );
    }
  }
}
