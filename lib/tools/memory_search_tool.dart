import 'friday_tool.dart';
import '../agent/agent_models.dart';
import '../services/memory_service.dart';

class MemorySearchTool extends FridayTool {
  final MemoryService _memoryService;

  MemorySearchTool({MemoryService? memoryService})
    : _memoryService = memoryService ?? MemoryService();

  @override
  String get name => 'search_memory';

  @override
  String get description =>
      'Search the user\'s personal memory vault for stored facts, preferences, past conversations, or any information the user has previously shared. Use this before answering personal questions about the user.';

  @override
  int get riskLevel => 0;

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'query': {
        'type': 'string',
        'description': 'The search query to find relevant memories',
      },
    },
    'required': ['query'],
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
    final query = args['query'] as String?;

    if (query == null || query.trim().isEmpty) {
      return ToolResult.failure(
        toolName: name,
        message: 'Search query is required',
        errorCode: 'MISSING_QUERY',
      );
    }

    try {
      final result = await _memoryService.retrieveContext(query);
      final hasRelevant = result.isNotEmpty && !result.contains('No relevant');

      return ToolResult.success(
        toolName: name,
        message: result,
        data: {'query': query, 'hasRelevantMemories': hasRelevant},
      );
    } catch (e) {
      return ToolResult.failure(
        toolName: name,
        message: 'Memory search failed: $e',
        errorCode: 'SEARCH_ERROR',
      );
    }
  }
}
