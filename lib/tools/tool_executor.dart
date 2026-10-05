import 'dart:async';
import 'package:flutter/foundation.dart';
import 'friday_tool.dart';
import '../agent/agent_models.dart';

class ToolExecutor {
  final Duration defaultTimeout;

  ToolExecutor({this.defaultTimeout = const Duration(seconds: 30)});

  Future<ToolResult> execute(
    FridayTool tool,
    Map<String, dynamic> args,
    ToolContext context,
  ) async {
    final startTime = DateTime.now();
    debugPrint('Executing tool: ${tool.name} with args: $args');

    try {
      if (!_validateArgs(tool, args)) {
        return ToolResult.failure(
          toolName: tool.name,
          message: 'Invalid arguments for ${tool.name}',
          errorCode: 'INVALID_ARGS',
        );
      }

      final result = await tool.execute(args, context).timeout(defaultTimeout);

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('Tool ${tool.name} completed in ${duration}ms');

      return result;
    } on TimeoutException {
      debugPrint(
        'Tool ${tool.name} timed out after ${defaultTimeout.inSeconds}s',
      );
      return ToolResult.failure(
        toolName: tool.name,
        message: 'Tool execution timed out',
        errorCode: 'TIMEOUT',
      );
    } catch (e) {
      debugPrint('Tool ${tool.name} error: $e');
      return ToolResult.failure(
        toolName: tool.name,
        message: 'Tool execution failed: $e',
        errorCode: 'EXECUTION_ERROR',
      );
    }
  }

  bool _validateArgs(FridayTool tool, Map<String, dynamic> args) {
    final schema = tool.inputSchema;
    final required = schema['required'] as List<String>? ?? [];

    for (final field in required) {
      if (!args.containsKey(field) || args[field] == null) {
        debugPrint('Missing required argument: $field for tool ${tool.name}');
        return false;
      }
    }

    return true;
  }
}
