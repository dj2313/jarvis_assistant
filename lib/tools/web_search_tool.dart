import 'friday_tool.dart';
import '../agent/agent_models.dart';
import '../services/search_service.dart';

class WebSearchTool extends FridayTool {
  final SearchService _searchService;

  WebSearchTool({SearchService? searchService})
    : _searchService = searchService ?? SearchService();

  @override
  String get name => 'web_search';

  @override
  String get description =>
      'Search the web for real-time information. Use this when the user asks about current events, weather, news, facts that require up-to-date information, or anything you cannot answer from memory alone.';

  @override
  int get riskLevel => 0;

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'query': {
        'type': 'string',
        'description': 'The search query to find information about',
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
      final result = await _searchService.search(query);
      return ToolResult.success(
        toolName: name,
        message: result.toFormattedString(),
        data: {
          'query': query,
          'answer': result.answer,
          'sources': result.sources
              .map(
                (s) => {'title': s.title, 'snippet': s.snippet, 'url': s.url},
              )
              .toList(),
        },
      );
    } catch (e) {
      return ToolResult.failure(
        toolName: name,
        message: 'Search failed: $e',
        errorCode: 'SEARCH_ERROR',
      );
    }
  }
}
