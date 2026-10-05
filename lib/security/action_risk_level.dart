enum ActionRiskLevel {
  readOnly(0, 'Read Only'),
  reversible(1, 'Reversible'),
  sensitive(2, 'Sensitive'),
  critical(3, 'Critical');

  final int level;
  final String label;

  const ActionRiskLevel(this.level, this.label);

  static ActionRiskLevel fromLevel(int level) {
    switch (level) {
      case 0:
        return ActionRiskLevel.readOnly;
      case 1:
        return ActionRiskLevel.reversible;
      case 2:
        return ActionRiskLevel.sensitive;
      case 3:
        return ActionRiskLevel.critical;
      default:
        return ActionRiskLevel.readOnly;
    }
  }
}
