import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../security/permission_guard.dart';
import '../security/action_risk_level.dart';

class ApprovalSheet extends StatelessWidget {
  final PendingConfirmation confirmation;
  final VoidCallback onApprove;
  final VoidCallback onCancel;

  const ApprovalSheet({
    super.key,
    required this.confirmation,
    required this.onApprove,
    required this.onCancel,
  });

  static Future<bool> show({
    required BuildContext context,
    required PendingConfirmation confirmation,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => ApprovalSheet(
        confirmation: confirmation,
        onApprove: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: _getRiskColor().withOpacity(0.3),
              width: 1,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHandle(),
                const SizedBox(height: 16),
                _buildHeader(),
                const SizedBox(height: 20),
                _buildActionDetails(),
                const SizedBox(height: 24),
                _buildButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getRiskColor().withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(_getRiskIcon(), color: _getRiskColor(), size: 32),
        ),
        const SizedBox(height: 12),
        Text(
          'CONFIRMATION REQUIRED',
          style: GoogleFonts.orbitron(
            color: _getRiskColor(),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          confirmation.decision.message ??
              'This action requires your approval.',
          textAlign: TextAlign.center,
          style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildActionDetails() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Action', confirmation.toolName.toUpperCase()),
          const SizedBox(height: 8),
          _buildDetailRow('Risk Level', confirmation.decision.riskLevel.label),
          const SizedBox(height: 8),
          _buildDetailRow('Parameters', _formatArgs()),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 11),
        ),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.shareTechMono(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  String _formatArgs() {
    if (confirmation.args.isEmpty) return 'None';
    final entries = confirmation.args.entries
        .take(3)
        .map((e) => '${e.key}: ${e.value}');
    return entries.join(', ');
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildButton(
            label: 'CANCEL',
            color: Colors.redAccent,
            onPressed: onCancel,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildButton(
            label: 'APPROVE',
            color: Colors.greenAccent,
            onPressed: onApprove,
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.orbitron(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Color _getRiskColor() {
    switch (confirmation.decision.riskLevel) {
      case ActionRiskLevel.readOnly:
        return Colors.blueAccent;
      case ActionRiskLevel.reversible:
        return Colors.cyanAccent;
      case ActionRiskLevel.sensitive:
        return Colors.orangeAccent;
      case ActionRiskLevel.critical:
        return Colors.redAccent;
    }
  }

  IconData _getRiskIcon() {
    switch (confirmation.decision.riskLevel) {
      case ActionRiskLevel.readOnly:
        return Icons.visibility;
      case ActionRiskLevel.reversible:
        return Icons.sync;
      case ActionRiskLevel.sensitive:
        return Icons.warning_amber;
      case ActionRiskLevel.critical:
        return Icons.error_outline;
    }
  }
}
