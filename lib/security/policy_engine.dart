import 'action_risk_level.dart';
import '../tools/friday_tool.dart';

class PolicyDecision {
  final bool autoExecute;
  final bool requiresConfirmation;
  final bool requiresBiometric;
  final ActionRiskLevel riskLevel;
  final String? message;

  const PolicyDecision({
    required this.autoExecute,
    required this.requiresConfirmation,
    required this.requiresBiometric,
    required this.riskLevel,
    this.message,
  });

  factory PolicyDecision.autoExecute(ActionRiskLevel riskLevel) =>
      PolicyDecision(
        autoExecute: true,
        requiresConfirmation: false,
        requiresBiometric: false,
        riskLevel: riskLevel,
      );

  factory PolicyDecision.needsConfirmation(
    ActionRiskLevel riskLevel, {
    String? message,
  }) => PolicyDecision(
    autoExecute: false,
    requiresConfirmation: true,
    requiresBiometric: false,
    riskLevel: riskLevel,
    message: message,
  );

  factory PolicyDecision.needsBiometric(
    ActionRiskLevel riskLevel, {
    String? message,
  }) => PolicyDecision(
    autoExecute: false,
    requiresConfirmation: true,
    requiresBiometric: true,
    riskLevel: riskLevel,
    message: message,
  );
}

class PolicyEngine {
  PolicyDecision evaluate(FridayTool tool) {
    final riskLevel = ActionRiskLevel.fromLevel(tool.riskLevel);
    return evaluateRisk(riskLevel, tool.name);
  }

  PolicyDecision evaluateRisk(ActionRiskLevel riskLevel, String toolName) {
    switch (riskLevel) {
      case ActionRiskLevel.readOnly:
        return PolicyDecision.autoExecute(riskLevel);

      case ActionRiskLevel.reversible:
        return PolicyDecision.autoExecute(riskLevel);

      case ActionRiskLevel.sensitive:
        return PolicyDecision.needsConfirmation(
          riskLevel,
          message: 'This action requires your approval before executing.',
        );

      case ActionRiskLevel.critical:
        return PolicyDecision.needsBiometric(
          riskLevel,
          message:
              'This is a critical action. Biometric verification required.',
        );
    }
  }

  PolicyDecision evaluateToolCall(String toolName, Map<String, dynamic> args) {
    final riskLevel = _assessRiskFromArgs(toolName, args);
    return evaluateRisk(riskLevel, toolName);
  }

  ActionRiskLevel _assessRiskFromArgs(
    String toolName,
    Map<String, dynamic> args,
  ) {
    // Default risk levels based on tool type
    switch (toolName) {
      case 'get_battery':
      case 'current_time':
      case 'search_memory':
        return ActionRiskLevel.readOnly;

      case 'web_search':
        return ActionRiskLevel.readOnly;

      case 'save_memory':
        return ActionRiskLevel.reversible;

      case 'open_app':
        return ActionRiskLevel.sensitive;

      case 'delete_memory':
      case 'send_message':
      case 'make_call':
        return ActionRiskLevel.critical;

      default:
        return ActionRiskLevel.sensitive;
    }
  }
}
