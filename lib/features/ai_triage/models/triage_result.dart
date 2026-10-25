enum TriageCategory {
  immediate, // Red: Life-threatening, immediate intervention required
  delayed,   // Yellow: Serious, but stable for a short duration
  minimal,   // Green: Minor injuries ("walking wounded")
  expectant, // Black: Deceased or non-salvageable
}

class TriageResult {
  final TriageCategory category;
  final String assessment;
  final List<String> recommendedActions;
  final bool requiresEvacuation;
  final String rawResponse;

  const TriageResult({
    required this.category,
    required this.assessment,
    required this.recommendedActions,
    required this.requiresEvacuation,
    required this.rawResponse,
  });

  String get categoryLabel {
    switch (category) {
      case TriageCategory.immediate:
        return 'RED - IMMEDIATE';
      case TriageCategory.delayed:
        return 'YELLOW - DELAYED';
      case TriageCategory.minimal:
        return 'GREEN - MINIMAL';
      case TriageCategory.expectant:
        return 'BLACK - EXPECTANT';
    }
  }
}
