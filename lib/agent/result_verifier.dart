import 'agent_models.dart';

class ResultVerifier {
  bool verify(ToolResult result) {
    if (!result.success) {
      return false;
    }

    if (result.message.trim().isEmpty) {
      return false;
    }

    if (result.errorCode != null && result.errorCode!.isNotEmpty) {
      return false;
    }

    return true;
  }

  VerificationResult verifyDetailed(ToolResult result) {
    final issues = <String>[];

    if (!result.success) {
      issues.add('Tool reported failure');
    }

    if (result.message.trim().isEmpty) {
      issues.add('Empty result message');
    }

    if (result.errorCode != null && result.errorCode!.isNotEmpty) {
      issues.add('Error code present: ${result.errorCode}');
    }

    final duration = result.completedAt
        .difference(result.startedAt)
        .inMilliseconds;
    if (duration > 30000) {
      issues.add('Tool execution exceeded 30s timeout');
    }

    return VerificationResult(
      isValid: issues.isEmpty,
      issues: issues,
      toolName: result.toolName,
    );
  }

  List<VerificationResult> verifyBatch(List<ToolResult> results) {
    return results.map(verifyDetailed).toList();
  }
}

class VerificationResult {
  final bool isValid;
  final List<String> issues;
  final String toolName;

  VerificationResult({
    required this.isValid,
    required this.issues,
    required this.toolName,
  });

  @override
  String toString() {
    if (isValid) {
      return '✓ $toolName: Valid';
    }
    return '✗ $toolName: ${issues.join(', ')}';
  }
}
