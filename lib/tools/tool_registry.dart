import 'package:flutter/foundation.dart';
import 'friday_tool.dart';

class ToolRegistry {
  final Map<String, FridayTool> _tools = {};

  void register(FridayTool tool) {
    _tools[tool.name] = tool;
    debugPrint('Tool registered: ${tool.name} (risk: ${tool.riskLevel})');
  }

  void unregister(String name) {
    _tools.remove(name);
  }

  FridayTool? get(String name) {
    return _tools[name];
  }

  bool has(String name) {
    return _tools.containsKey(name);
  }

  List<String> get registeredToolNames => _tools.keys.toList();

  List<FridayTool> get allTools => _tools.values.toList();

  List<Map<String, dynamic>> toGroqToolList() {
    final List<Map<String, dynamic>> groqTools = [];
    for (final tool in _tools.values) {
      groqTools.addAll(tool.groqToolDefinition);
    }
    return groqTools;
  }

  List<FridayTool> getToolsByRiskLevel(int maxRiskLevel) {
    return _tools.values.where((t) => t.riskLevel <= maxRiskLevel).toList();
  }

  List<FridayTool> getToolsByNames(List<String> names) {
    return names
        .where((n) => _tools.containsKey(n))
        .map((n) => _tools[n]!)
        .toList();
  }

  void clear() {
    _tools.clear();
  }

  int get count => _tools.length;
}
