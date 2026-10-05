import '../agent/agent_models.dart';

abstract class FridayTool {
  String get name;
  String get description;
  int get riskLevel;
  Map<String, dynamic> get inputSchema;
  List<Map<String, dynamic>> get groqToolDefinition;

  Future<ToolResult> execute(Map<String, dynamic> args, ToolContext context);
}

class ToolContext {
  final String requestId;
  final Map<String, dynamic> contextData;

  ToolContext({required this.requestId, this.contextData = const {}});
}
